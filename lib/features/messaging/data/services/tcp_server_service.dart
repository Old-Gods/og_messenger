import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../../../../core/constants/network_constants.dart';
import '../../../messaging/domain/entities/message.dart';
import '../../../security/data/services/security_service.dart';

/// TCP server for receiving messages from peers
class TcpServerService {
  static final TcpServerService instance = TcpServerService._();

  TcpServerService._();

  ServerSocket? _serverSocket;
  int? _actualPort;
  final Map<String, Socket> _connectedPeers = {};
  final Map<String, StringBuffer> _peerBuffers =
      {}; // Buffer for incomplete messages
  final StreamController<Message> _messageController =
      StreamController<Message>.broadcast();
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();
  final StreamController<Map<String, dynamic>> _syncRequestController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _nameChangeController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _authRequestController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _authResponseController =
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

  /// Stream of auth requests
  Stream<Map<String, dynamic>> get authRequestStream =>
      _authRequestController.stream;

  /// Stream of auth responses
  Stream<Map<String, dynamic>> get authResponseStream =>
      _authResponseController.stream;

  /// Get the actual TCP port the server is listening on
  int? get actualPort => _actualPort;

  /// Check if server is running
  bool get isRunning => _isRunning;

  /// Start the TCP server with auto-incrementing port
  Future<bool> start() async {
    if (_isRunning) {
      print('✅ TCP server already running on port $_actualPort');
      return true; // Already running is success
    }

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
    _peerBuffers[peerId] = StringBuffer(); // Initialize buffer for this peer
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
    final peerId = '${socket.remoteAddress.address}:${socket.remotePort}';
    final buffer = _peerBuffers[peerId];

    if (buffer == null) return;

    try {
      // Append incoming data to buffer
      final chunk = utf8.decode(data, allowMalformed: true);
      buffer.write(chunk);

      // Process complete messages (separated by newlines)
      final bufferContent = buffer.toString();
      final lines = bufferContent.split('\n');

      // Keep the last incomplete line in the buffer
      buffer.clear();
      if (!bufferContent.endsWith('\n') && lines.isNotEmpty) {
        buffer.write(lines.last);
        lines.removeLast();
      }

      for (final line in lines) {
        if (line.trim().isEmpty) continue;

        try {
          final json = jsonDecode(line);
          _processMessage(socket, json);
        } catch (e) {
          print('⚠️  Failed to parse JSON: $e');
          print('   Line length: ${line.length} characters');
          // Don't show error to user - just log it
          continue;
        }
      }
    } catch (e) {
      print('❌ Error handling data from $peerId: $e');
      // Clear buffer on error to prevent corruption
      buffer.clear();
    }
  }

  /// Process a parsed JSON message
  void _processMessage(Socket socket, Map<String, dynamic> json) {
    try {
      // Check if this is a sync request
      if (json['type'] == 'sync_request') {
        print('🔄 Received sync request');
        _syncRequestController.add({
          'address': socket.remoteAddress.address,
          'port': json['tcp_port'] as int,
          'since_timestamp': json['since_timestamp'] as int,
        });
        return;
      }

      // Check if this is a name change notification
      if (json['type'] == 'name_change') {
        print('👤 Received name change notification');
        _nameChangeController.add({
          'device_id': json['device_id'] as String,
          'new_name': json['new_name'] as String,
        });
        return;
      }

      // Check if this is an auth request
      if (json['type'] == 'auth_request') {
        print('🔐 Received auth request');
        _authRequestController.add({
          'device_id': json['device_id'] as String,
          'device_name': json['device_name'] as String,
          'encrypted_password_hash': json['encrypted_password_hash'] as String,
          'public_key': json['public_key'] as String,
          'peer_address': socket.remoteAddress.address,
          'peer_port': json['tcp_port'] as int,
        });
        return;
      }

      // Check if this is an auth response
      if (json['type'] == 'auth_response') {
        print('✅ Received auth response');
        _authResponseController.add({
          'success': json['success'] as bool,
          'encrypted_aes_key': json['encrypted_aes_key'] as String?,
          'message': json['message'] as String?,
        });
        return;
      }

      // Otherwise, it's a regular message
      final parsedMessage = Message.fromJson(json);

      // Decrypt message if we're authenticated
      final securityService = SecurityService.instance;
      Message finalMessage = parsedMessage;

      if (securityService.hasAesKey) {
        try {
          final decryptedContent = securityService.decryptMessage(
            parsedMessage.content,
          );
          finalMessage = Message(
            uuid: parsedMessage.uuid,
            timestampMicros: parsedMessage.timestampMicros,
            senderId: parsedMessage.senderId,
            senderName: parsedMessage.senderName,
            content: decryptedContent,
            isOutgoing: parsedMessage.isOutgoing,
          );
        } catch (e) {
          print('⚠️ Failed to decrypt message: $e');
          // Keep original message if decryption fails
        }
      }

      print(
        '📨 Received message from ${finalMessage.senderName}: ${finalMessage.content}',
      );

      _messageController.add(finalMessage);
    } catch (e) {
      print('⚠️ Failed to process message: $e');
      // Don't add to error controller - this prevents showing errors to users
    }
  }

  /// Send a message to a specific peer
  Future<bool> sendMessage(
    String peerAddress,
    int peerPort,
    Message message,
  ) async {
    try {
      // Encrypt message if we're authenticated
      final securityService = SecurityService.instance;
      Message messageToSend = message;

      if (securityService.hasAesKey) {
        try {
          final encryptedContent = securityService.encryptMessage(
            message.content,
          );
          messageToSend = Message(
            uuid: message.uuid,
            timestampMicros: message.timestampMicros,
            senderId: message.senderId,
            senderName: message.senderName,
            content: encryptedContent,
            isOutgoing: message.isOutgoing,
          );
        } catch (e) {
          print('⚠️ Failed to encrypt message: $e');
          // Continue with unencrypted message
        }
      }

      final messageJson = jsonEncode(messageToSend.toJson());
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

  /// Send a generic message to a peer (for control messages like password proposals/votes)
  Future<bool> sendGenericMessage(
    String peerAddress,
    int peerPort,
    Map<String, dynamic> message,
  ) async {
    try {
      final messageJson = jsonEncode(message);
      print('📤 Sending ${message['type']} to $peerAddress:$peerPort');

      final socket = await Socket.connect(peerAddress, peerPort);
      socket.write('$messageJson\n');
      await socket.flush();
      await socket.close();

      print('✅ ${message['type']} sent successfully');
      return true;
    } catch (e) {
      print(
        '❌ Failed to send ${message['type']} to $peerAddress:$peerPort: $e',
      );
      _errorController.add('Failed to send ${message['type']}: $e');
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
    _peerBuffers.remove(peerId); // Clean up buffer
    print('🔌 Peer disconnected: $peerId');
  }

  /// Get count of connected peers
  int get connectedPeerCount => _connectedPeers.length;

  /// Send authentication request to a peer
  Future<bool> sendAuthRequest({
    required String peerAddress,
    required int peerPort,
    required String deviceId,
    required String deviceName,
    required String encryptedPasswordHash,
    required String publicKey,
    required int tcpPort,
  }) async {
    try {
      final request = {
        'type': 'auth_request',
        'device_id': deviceId,
        'device_name': deviceName,
        'encrypted_password_hash': encryptedPasswordHash,
        'public_key': publicKey,
        'tcp_port': tcpPort,
      };

      final requestJson = jsonEncode(request);
      print('📤 Sending auth request to $peerAddress:$peerPort');

      final socket = await Socket.connect(peerAddress, peerPort);
      socket.write('$requestJson\n');
      await socket.flush();
      await socket.close();

      print('✅ Auth request sent successfully');
      return true;
    } catch (e) {
      print('❌ Failed to send auth request to $peerAddress:$peerPort: $e');
      _errorController.add('Failed to send auth request: $e');
      return false;
    }
  }

  /// Send authentication response to a peer
  Future<bool> sendAuthResponse({
    required String peerAddress,
    required int peerPort,
    required bool success,
    String? encryptedAesKey,
    String? message,
  }) async {
    try {
      final response = {
        'type': 'auth_response',
        'success': success,
        if (encryptedAesKey != null) 'encrypted_aes_key': encryptedAesKey,
        if (message != null) 'message': message,
      };

      final responseJson = jsonEncode(response);
      print(
        '📤 Sending auth response to $peerAddress:$peerPort (success: $success)',
      );

      final socket = await Socket.connect(peerAddress, peerPort);
      socket.write('$responseJson\n');
      await socket.flush();
      await socket.close();

      print('✅ Auth response sent successfully');
      return true;
    } catch (e) {
      print('❌ Failed to send auth response to $peerAddress:$peerPort: $e');
      _errorController.add('Failed to send auth response: $e');
      return false;
    }
  }

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
    _authRequestController.close();
    _authResponseController.close();
  }
}
