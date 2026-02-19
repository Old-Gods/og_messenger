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

  bool _isRunning = false;

  /// Stream of incoming messages
  Stream<Message> get messageStream => _messageController.stream;

  /// Stream of errors
  Stream<String> get errorStream => _errorController.stream;

  /// Get the actual TCP port the server is listening on
  int? get actualPort => _actualPort;

  /// Check if server is running
  bool get isRunning => _isRunning;

  /// Start the TCP server with auto-incrementing port
  Future<bool> start() async {
    if (_isRunning) return false;

    for (int attempt = 0;
        attempt < NetworkConstants.maxPortAttempts;
        attempt++) {
      final port = NetworkConstants.baseTcpPort + attempt;

      try {
        _serverSocket = await ServerSocket.bind(
          InternetAddress.anyIPv4,
          port,
        );

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

    print('❌ Failed to bind TCP server after ${NetworkConstants.maxPortAttempts} attempts');
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
        final parsedMessage = Message.fromJson(json);
        print('📨 Received message from ${parsedMessage.senderName}: ${parsedMessage.content}');

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
  Future<bool> sendMessage(String peerAddress, int peerPort, Message message) async {
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
      _errorController.add('Failed to send message to $peerAddress:$peerPort: $e');
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
  }
}
