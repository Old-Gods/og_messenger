import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../../../../core/constants/network_constants.dart';
import '../../../messaging/domain/entities/message.dart';

/// TCP server for receiving messages from peers
class TcpServerService {
  ServerSocket? _serverSocket;
  int? _actualPort;
  final Map<String, Socket> _connectedPeers = {};
  final StreamController<Message> _messageController =
      StreamController<Message>.broadcast();
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();
  final StreamController<Map<String, dynamic>> _syncRequestController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _nameChangeController =
      StreamController<Map<String, dynamic>>.broadcast();

  bool _isRunning = false;

  /// Stream of incoming messages
  Stream<Message> get messageStream => _messageController.stream;

  /// Stream of errors
  Stream<String> get errorStream => _errorController.stream;

  /// Stream of sync requests
  Stream<Map<String, dynamic>> get syncRequestStream =>
      _syncRequestController.stream;

  /// Stream of name change notifications
  Stream<Map<String, dynamic>> get nameChangeStream =>
      _nameChangeController.stream;

  /// Get the actual TCP port the server is listening on
  int? get actualPort => _actualPort;

  /// Check if server is running
  bool get isRunning => _isRunning;

  /// Start the TCP server with auto-incrementing port
  Future<bool> start() async {
    if (_isRunning) return false;

    for (
      int attempt = 0;
      attempt < NetworkConstants.maxPortAttempts;
      attempt++
    ) {
      final port = NetworkConstants.baseTcpPort + attempt;

      try {
        _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, port);

        _actualPort = port;
        _isRunning = true;

        print('✅ TCP Server bound to port $port');

        _serverSocket!.listen(
          _handleConnection,
          onError: (error) {
            print('❌ TCP Server error: $error');
            _errorController.add('Server error: $error');
          },
          onDone: () {
            print('⚠️ TCP Server closed');
            _isRunning = false;
          },
        );

        return true;
      } catch (e) {
        // Port is in use, try next one
        continue;
      }
    }

    print(
      '❌ Failed to bind TCP server after ${NetworkConstants.maxPortAttempts} attempts',
    );
    _errorController.add(
      'Failed to bind TCP server after ${NetworkConstants.maxPortAttempts} attempts',
    );
    return false;
  }

  /// Handle incoming peer connection
  void _handleConnection(Socket socket) {
    final peerId = '${socket.remoteAddress.address}:${socket.remotePort}';
    _connectedPeers[peerId] = socket;
    print('🔗 New connection from $peerId');

    socket.listen(
      (data) => _handleData(socket, data),
      onError: (error) {
        _errorController.add('Connection error from $peerId: $error');
        _removePeer(peerId);
      },
      onDone: () => _removePeer(peerId),
      cancelOnError: true,
    );
  }

  /// Handle incoming data from peer
  void _handleData(Socket socket, List<int> data) {
    try {
      final message = utf8.decode(data);
      final lines = message.split('\n');

      for (final line in lines) {
        if (line.trim().isEmpty) continue;

        final json = jsonDecode(line);

        // Check if this is a sync request
        if (json['type'] == 'sync_request') {
          print('🔄 Received sync request');
          _syncRequestController.add({
            'address': socket.remoteAddress.address,
            'port': json['tcp_port'] as int,
            'since_timestamp': json['since_timestamp'] as int,
          });
          continue;
        }

        // Check if this is a name change notification
        if (json['type'] == 'name_change') {
          print('👤 Received name change notification');
          _nameChangeController.add({
            'device_id': json['device_id'] as String,
            'new_name': json['new_name'] as String,
          });
          continue;
        }

        // Otherwise, it's a regular message
        final parsedMessage = Message.fromJson(json);
        print(
          '📨 Received message from ${parsedMessage.senderName}: ${parsedMessage.content}',
        );

        // Validate message size
        final messageBytes = utf8.encode(line);
        if (messageBytes.length > NetworkConstants.maxMessageSizeBytes) {
          _errorController.add(
            'Rejected oversized message: ${messageBytes.length} bytes',
          );
          continue;
        }

        _messageController.add(parsedMessage);
      }
    } catch (e) {
      _errorController.add('Failed to parse message: $e');
    }
  }

  /// Send a message to a specific peer
  Future<bool> sendMessage(
    String peerAddress,
    int peerPort,
    Message message,
  ) async {
    try {
      final messageJson = jsonEncode(message.toJson());
      final messageBytes = utf8.encode(messageJson);

      // Validate message size before sending
      if (messageBytes.length > NetworkConstants.maxMessageSizeBytes) {
        print('❌ Message too large: ${messageBytes.length} bytes');
        _errorController.add(
          'Message too large: ${messageBytes.length} bytes (max: ${NetworkConstants.maxMessageSizeBytes})',
        );
        return false;
      }

      print('📤 Sending message to $peerAddress:$peerPort');
      final socket = await Socket.connect(peerAddress, peerPort);
      socket.write('$messageJson\n');
      await socket.flush();
      await socket.close();
      print('✅ Message sent successfully');

      return true;
    } catch (e) {
      print('❌ Failed to send message to $peerAddress:$peerPort: $e');
      _errorController.add(
        'Failed to send message to $peerAddress:$peerPort: $e',
      );
      return false;
    }
  }

  /// Send a sync request to a peer
  Future<bool> sendSyncRequest(
    String peerAddress,
    int peerPort,
    String deviceId,
    int sinceTimestamp,
  ) async {
    try {
      final request = {
        'type': 'sync_request',
        'device_id': deviceId,
        'tcp_port': _actualPort,
        'since_timestamp': sinceTimestamp,
      };

      final requestJson = jsonEncode(request);
      print('📤 Sending sync request to $peerAddress:$peerPort');

      final socket = await Socket.connect(peerAddress, peerPort);
      socket.write('$requestJson\n');
      await socket.flush();
      await socket.close();

      print('✅ Sync request sent successfully');
      return true;
    } catch (e) {
      print('❌ Failed to send sync request to $peerAddress:$peerPort: $e');
      _errorController.add('Failed to send sync request: $e');
      return false;
    }
  }

  /// Send a name change notification to a peer
  Future<bool> sendNameChange(
    String peerAddress,
    int peerPort,
    String deviceId,
    String newName,
  ) async {
    try {
      final notification = {
        'type': 'name_change',
        'device_id': deviceId,
        'new_name': newName,
      };

      final notificationJson = jsonEncode(notification);
      print('📤 Sending name change to $peerAddress:$peerPort');

      final socket = await Socket.connect(peerAddress, peerPort);
      socket.write('$notificationJson\n');
      await socket.flush();
      await socket.close();

      print('✅ Name change sent successfully');
      return true;
    } catch (e) {
      print('❌ Failed to send name change to $peerAddress:$peerPort: $e');
      _errorController.add('Failed to send name change: $e');
      return false;
    }
  }

  /// Broadcast a message to all connected peers
  Future<void> broadcastMessage(Message message) async {
    final messageJson = jsonEncode(message.toJson());
    final messageBytes = utf8.encode('$messageJson\n');

    // Validate message size
    if (messageBytes.length > NetworkConstants.maxMessageSizeBytes) {
      _errorController.add(
        'Message too large: ${messageBytes.length} bytes (max: ${NetworkConstants.maxMessageSizeBytes})',
      );
      return;
    }

    final peersToRemove = <String>[];

    for (final entry in _connectedPeers.entries) {
      try {
        entry.value.add(messageBytes);
        await entry.value.flush();
      } catch (e) {
        _errorController.add('Failed to send to ${entry.key}: $e');
        peersToRemove.add(entry.key);
      }
    }

    // Remove failed connections
    for (final peerId in peersToRemove) {
      _removePeer(peerId);
    }
  }

  /// Remove a peer connection
  void _removePeer(String peerId) {
    final socket = _connectedPeers.remove(peerId);
    socket?.close();
  }

  /// Get count of connected peers
  int get connectedPeerCount => _connectedPeers.length;

  /// Stop the TCP server
  Future<void> stop() async {
    if (!_isRunning) return;

    _isRunning = false;

    // Close all peer connections
    for (final socket in _connectedPeers.values) {
      await socket.close();
    }
    _connectedPeers.clear();

    // Close server socket
    await _serverSocket?.close();
    _serverSocket = null;
    _actualPort = null;
  }

  /// Dispose resources
  void dispose() {
    stop();
    _messageController.close();
    _errorController.close();
    _syncRequestController.close();
    _nameChangeController.close();
  }
}
