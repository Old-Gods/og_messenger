import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../../../../core/constants/network_constants.dart';
import '../../../messaging/domain/entities/message.dart';
import '../../../security/data/services/security_service.dart';
import '../../../rooms/data/services/room_service.dart';

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
  final StreamController<Map<String, dynamic>> _joinRequestController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _joinResponseController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _typingIndicatorController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _syncReceivedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _requestResolvedController =
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

  /// Stream of join requests
  Stream<Map<String, dynamic>> get joinRequestStream =>
      _joinRequestController.stream;

  /// Stream of join responses
  Stream<Map<String, dynamic>> get joinResponseStream =>
      _joinResponseController.stream;

  /// Stream of typing indicators
  Stream<Map<String, dynamic>> get typingIndicatorStream =>
      _typingIndicatorController.stream;

  /// Stream of sync received acknowledgments
  Stream<Map<String, dynamic>> get syncReceivedStream =>
      _syncReceivedController.stream;

  /// Stream of request resolved notifications
  Stream<Map<String, dynamic>> get requestResolvedStream =>
      _requestResolvedController.stream;

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

      // Check if this is a sync received acknowledgment
      if (json['type'] == 'sync_received') {
        print('✅ Received sync acknowledgment');
        _syncReceivedController.add({
          'peer_address': socket.remoteAddress.address,
          'message_count': json['message_count'] as int?,
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

      // Check if this is a join request
      if (json['type'] == 'join_request') {
        print('🔐 Received join request');
        _joinRequestController.add({
          'request_id': json['request_id'] as String,
          'room_id': json['room_id'] as String,
          'room_name': json['room_name'] as String,
          'requester_device_id': json['requester_device_id'] as String,
          'requester_name': json['requester_name'] as String,
          'requester_public_key': json['requester_public_key'] as String,
          'peer_address': socket.remoteAddress.address,
          'peer_port': json['tcp_port'] as int,
        });
        return;
      }

      // Check if this is a join response
      if (json['type'] == 'join_response') {
        print('✅ Received join response');
        _joinResponseController.add({
          'request_id': json['request_id'] as String,
          'success': json['success'] as bool,
          'room_id': json['room_id'] as String?,
          'room_name': json['room_name'] as String?,
          'creator_name': json['creator_name'] as String?,
          'encrypted_aes_key': json['encrypted_aes_key'] as String?,
          'message': json['message'] as String?,
        });
        return;
      }

      // Check if this is a request resolved notification
      if (json['type'] == 'request_resolved') {
        print('📥 Received request resolved notification');
        _requestResolvedController.add({
          'request_id': json['request_id'] as String,
          'room_id': json['room_id'] as String,
        });
        return;
      }

      // Check if this is a typing indicator
      if (json['type'] == 'typing_indicator') {
        _typingIndicatorController.add({
          'device_id': json['device_id'] as String,
          'device_name': json['device_name'] as String,
        });
        return;
      }

      // Otherwise, it's a regular message
      final parsedMessage = Message.fromJson(json);

      // Decrypt message if it has a room_id and we have the key
      final securityService = SecurityService.instance;
      Message finalMessage = parsedMessage;

      final messageRoomId = json['room_id'] as String?;
      if (messageRoomId != null) {
        final aesKey = RoomService.instance.getRoomAesKey(messageRoomId);
        if (aesKey != null) {
          try {
            final decryptedContent = securityService.decryptMessageForRoom(
              parsedMessage.content,
              messageRoomId,
            );
            finalMessage = Message(
              uuid: parsedMessage.uuid,
              timestampMicros: parsedMessage.timestampMicros,
              senderId: parsedMessage.senderId,
              senderName: parsedMessage.senderName,
              content: decryptedContent,
              isOutgoing: parsedMessage.isOutgoing,
              roomId: messageRoomId,
            );
            print('🔓 Decrypted message for room: $messageRoomId');
          } catch (e) {
            print('⚠️ Failed to decrypt message: $e');
            return; // Discard message that fails decryption
          }
        } else {
          print(
            '⚠️ Cannot decrypt message for room $messageRoomId - no AES key available',
          );
          return; // Discard message for room we don\'t have key for
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
    String? roomId,
  ) async {
    try {
      // Encrypt message if we have room key
      final securityService = SecurityService.instance;
      Message messageToSend = message;

      if (roomId != null &&
          RoomService.instance.getRoomAesKey(roomId) != null) {
        try {
          final encryptedContent = securityService.encryptMessageForRoom(
            message.content,
            roomId,
          );
          messageToSend = Message(
            uuid: message.uuid,
            timestampMicros: message.timestampMicros,
            senderId: message.senderId,
            senderName: message.senderName,
            content: encryptedContent,
            isOutgoing: message.isOutgoing,
          );
          print('🔐 Encrypted message for room: $roomId');
        } catch (e) {
          print('⚠️ Failed to encrypt message: $e');
        }
      }

      final messageData = messageToSend.toJson();
      if (roomId != null) {
        messageData['room_id'] = roomId;
      }
      final messageJson = jsonEncode(messageData);
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
    String roomId,
  ) async {
    try {
      final request = {
        'type': 'sync_request',
        'device_id': deviceId,
        'tcp_port': _actualPort,
        'since_timestamp': sinceTimestamp,
        'room_id': roomId,
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
      // Connection refused is expected during peer startup - peer discovered via
      // UDP but hasn't completed authentication/started TCP server yet.
      // This is a benign race condition that resolves when peer completes setup.
      // Don't show error to user, just log for debugging.
      print(
        '⚠️ Sync request to $peerAddress:$peerPort failed (peer may still be starting up): $e',
      );
      return false;
    }
  }

  /// Send a sync received acknowledgment to a peer
  Future<bool> sendSyncReceived(
    String peerAddress,
    int peerPort,
    int messageCount,
  ) async {
    try {
      final acknowledgment = {
        'type': 'sync_received',
        'message_count': messageCount,
      };

      final ackJson = jsonEncode(acknowledgment);
      print(
        '📤 Sending sync acknowledgment to $peerAddress:$peerPort (messages: $messageCount)',
      );

      final socket = await Socket.connect(peerAddress, peerPort);
      socket.write('$ackJson\n');
      await socket.flush();
      await socket.close();

      print('✅ Sync acknowledgment sent successfully');
      return true;
    } catch (e) {
      print(
        '❌ Failed to send sync acknowledgment to $peerAddress:$peerPort: $e',
      );
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

  /// Send a typing indicator to a peer
  Future<bool> sendTypingIndicator(
    String peerAddress,
    int peerPort,
    String deviceId,
    String deviceName,
  ) async {
    try {
      final indicator = {
        'type': 'typing_indicator',
        'device_id': deviceId,
        'device_name': deviceName,
      };

      final indicatorJson = jsonEncode(indicator);

      final socket = await Socket.connect(peerAddress, peerPort);
      socket.write('$indicatorJson\n');
      await socket.flush();
      await socket.close();

      return true;
    } catch (e) {
      // Silently fail for typing indicators - they're not critical
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

  /// Send join request to a peer (room member)
  Future<bool> sendJoinRequest({
    required String peerAddress,
    required int peerPort,
    required String requestId,
    required String roomId,
    required String roomName,
    required String requesterDeviceId,
    required String requesterName,
    required String requesterPublicKey,
    required int tcpPort,
  }) async {
    try {
      final request = {
        'type': 'join_request',
        'request_id': requestId,
        'room_id': roomId,
        'room_name': roomName,
        'requester_device_id': requesterDeviceId,
        'requester_name': requesterName,
        'requester_public_key': requesterPublicKey,
        'tcp_port': tcpPort,
      };

      final requestJson = jsonEncode(request);
      print('📤 Sending join request to $peerAddress:$peerPort');

      final socket = await Socket.connect(peerAddress, peerPort);
      socket.write('$requestJson\n');
      await socket.flush();
      await socket.close();

      print('✅ Join request sent successfully');
      return true;
    } catch (e) {
      print('❌ Failed to send join request to $peerAddress:$peerPort: $e');
      _errorController.add('Failed to send join request: $e');
      return false;
    }
  }

  /// Send join response to a peer
  Future<bool> sendJoinResponse({
    required String peerAddress,
    required int peerPort,
    required String requestId,
    required bool success,
    String? roomId,
    String? roomName,
    String? creatorName,
    String? encryptedAesKey,
    String? message,
  }) async {
    try {
      final response = {
        'type': 'join_response',
        'request_id': requestId,
        'success': success,
        'room_id': roomId,
        'room_name': roomName,
        'creator_name': creatorName,
        'encrypted_aes_key': encryptedAesKey,
        'message': message,
      }..removeWhere((key, value) => value == null);

      final responseJson = jsonEncode(response);
      print(
        '📤 Sending join response to $peerAddress:$peerPort (success: $success)',
      );

      final socket = await Socket.connect(peerAddress, peerPort);
      socket.write('$responseJson\n');
      await socket.flush();
      await socket.close();

      print('✅ Join response sent successfully');
      return true;
    } catch (e) {
      print('❌ Failed to send join response to $peerAddress:$peerPort: $e');
      _errorController.add('Failed to send join response: $e');
      return false;
    }
  }

  /// Send request resolved notification to a peer
  Future<bool> sendRequestResolved({
    required String peerAddress,
    required int peerPort,
    required String requestId,
    required String roomId,
  }) async {
    try {
      final notification = {
        'type': 'request_resolved',
        'request_id': requestId,
        'room_id': roomId,
      };

      final notificationJson = jsonEncode(notification);
      print('📤 Sending request resolved to $peerAddress:$peerPort');

      final socket = await Socket.connect(peerAddress, peerPort);
      socket.write('$notificationJson\n');
      await socket.flush();
      await socket.close();

      return true;
    } catch (e) {
      print('❌ Failed to send request resolved to $peerAddress:$peerPort: $e');
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
    _joinRequestController.close();
    _joinResponseController.close();
    _typingIndicatorController.close();
    _syncReceivedController.close();
  }
}
