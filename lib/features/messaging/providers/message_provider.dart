import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:asn1lib/asn1lib.dart' as asn1;
import 'package:pointycastle/pointycastle.dart' as pc;
import '../../settings/providers/settings_provider.dart';
import '../../discovery/providers/discovery_provider.dart';
import '../../notifications/data/services/notification_service.dart';
import '../../security/data/services/security_service.dart';
import '../domain/entities/message.dart';
import '../data/repositories/message_repository.dart';
import '../data/services/tcp_server_service.dart';

/// Message state
class MessageState {
  final List<Message> messages;
  final bool isLoading;
  final String? error;
  final Map<String, DateTime> typingPeers; // deviceId -> last typing time

  const MessageState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
    this.typingPeers = const {},
  });

  MessageState copyWith({
    List<Message>? messages,
    bool? isLoading,
    String? error,
    Map<String, DateTime>? typingPeers,
  }) {
    return MessageState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      typingPeers: typingPeers ?? this.typingPeers,
    );
  }
}

/// Message notifier
class MessageNotifier extends Notifier<MessageState> {
  late MessageRepository _repository;
  late TcpServerService _tcpServer;
  ProviderSubscription? _peerSubscription;
  final Set<String> _syncedPeers = {};
  bool _isAppInForeground = true;
  Timer? _typingCleanupTimer;

  @override
  MessageState build() {
    _repository = MessageRepository();
    _tcpServer = TcpServerService.instance;

    // Listen to incoming messages
    _tcpServer.messageStream.listen(_handleIncomingMessage);
    _tcpServer.errorStream.listen(_handleError);
    _tcpServer.syncRequestStream.listen(_handleSyncRequest);
    _tcpServer.nameChangeStream.listen(_handleNameChange);
    _tcpServer.authRequestStream.listen(_handleAuthRequest);
    _tcpServer.typingIndicatorStream.listen(_handleTypingIndicator);

    // Listen to peer discoveries for auto-sync
    _peerSubscription = ref.listen(discoveryProvider, (previous, next) {
      _handlePeerChanges(previous?.peers ?? {}, next.peers);
    });

    // Start typing indicator cleanup timer
    _startTypingCleanupTimer();

    // Schedule async load after build completes
    Future.microtask(() => loadMessages());

    // Clean up timer when provider is disposed
    ref.onDispose(() {
      _typingCleanupTimer?.cancel();
    });

    return const MessageState();
  }

  /// Start periodic cleanup of expired typing indicators
  void _startTypingCleanupTimer() {
    _typingCleanupTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _cleanupExpiredTypingIndicators();
    });
  }

  /// Remove typing indicators that have expired
  void _cleanupExpiredTypingIndicators() {
    final now = DateTime.now();
    final updated = Map<String, DateTime>.from(state.typingPeers);
    var needsUpdate = false;

    updated.removeWhere((deviceId, lastTyping) {
      final isExpired =
          now.difference(lastTyping) >
          const Duration(seconds: 5); // Use NetworkConstants.typingTimeout
      if (isExpired) needsUpdate = true;
      return isExpired;
    });

    if (needsUpdate) {
      state = state.copyWith(typingPeers: updated);
    }
  }

  /// Handle typing indicator
  void _handleTypingIndicator(Map<String, dynamic> data) {
    final deviceId = data['device_id'] as String;
    final updated = Map<String, DateTime>.from(state.typingPeers);
    updated[deviceId] = DateTime.now();
    state = state.copyWith(typingPeers: updated);
  }

  /// Update app foreground state
  void setAppInForeground(bool inForeground) {
    _isAppInForeground = inForeground;
  }

  /// Load all messages from database
  Future<void> loadMessages() async {
    state = state.copyWith(isLoading: true);

    try {
      final settings = ref.read(settingsProvider);
      final deviceId = settings.deviceId ?? '';
      final networkId = settings.networkId;

      // Show warning if not on valid WiFi network
      if (networkId == 'Unknown' || networkId.isEmpty) {
        print('⚠️ Not on valid WiFi network - no messages available');
        state = MessageState(
          messages: const [],
          isLoading: false,
          error: 'WiFi network required',
        );
        return;
      }

      final messages = await _repository.getAllMessages(deviceId, networkId);

      print(
        '📚 Loaded ${messages.length} messages from database (network: $networkId)',
      );
      state = MessageState(messages: messages, isLoading: false);
    } catch (e) {
      print('❌ Failed to load messages: $e');
      state = MessageState(
        messages: state.messages,
        isLoading: false,
        error: 'Failed to load messages: $e',
      );
    }
  }

  /// Handle incoming message from TCP server
  Future<void> _handleIncomingMessage(Message message) async {
    try {
      final settings = ref.read(settingsProvider);
      final deviceId = settings.deviceId ?? '';
      final networkId = settings.networkId;

      // Reject messages when not on a valid WiFi network
      if (networkId == 'Unknown' || networkId.isEmpty) {
        print('⚠️ Rejecting message - not on valid WiFi network');
        return;
      }

      // Clear typing indicator for this sender
      final updated = Map<String, DateTime>.from(state.typingPeers);
      if (updated.remove(message.senderId) != null) {
        state = state.copyWith(typingPeers: updated);
      }

      // Check for duplicates (same UUID and sender)
      final isDuplicate = state.messages.any(
        (m) => m.uuid == message.uuid && m.senderId == message.senderId,
      );

      if (isDuplicate) {
        print(
          '⚠️ Skipping duplicate message: "${message.content}" from ${message.senderName}',
        );
        return;
      }

      print(
        '💾 Saving new message: "${message.content}" from ${message.senderName}',
      );

      // Save to database
      await _repository.saveMessage(message, deviceId, networkId);

      // Update state
      final updatedMessages = [...state.messages, message];
      updatedMessages.sort(
        (a, b) => a.timestampMicros.compareTo(b.timestampMicros),
      );
      state = state.copyWith(messages: updatedMessages);

      // Show notification only if app is in background
      if (!_isAppInForeground) {
        try {
          await NotificationService.instance.showMessageNotification(
            senderName: message.senderName,
            messageContent: message.content,
            messageId: message.uuid,
          );
          print('🔔 Notification shown for message from ${message.senderName}');
        } catch (e) {
          print('⚠️ Failed to show notification: $e');
        }
      } else {
        print('📱 App in foreground, skipping notification');
      }
    } catch (e) {
      print('❌ Failed to save message: $e');
      state = state.copyWith(error: 'Failed to save message: $e');
    }
  }

  /// Handle TCP server error
  void _handleError(String error) {
    state = state.copyWith(error: error);
  }

  /// Handle peer changes - sync with new peers
  Future<void> _handlePeerChanges(
    Map<String, dynamic> oldPeers,
    Map<String, dynamic> newPeers,
  ) async {
    // Find newly discovered peers
    for (final entry in newPeers.entries) {
      final peerId = entry.key;
      final peer = entry.value;

      // Skip if already synced
      if (_syncedPeers.contains(peerId)) continue;

      // Skip if peer existed before
      if (oldPeers.containsKey(peerId)) continue;

      print('🔄 New peer discovered: ${peer.deviceName}, requesting sync...');
      _syncedPeers.add(peerId);

      // Request message sync from new peer
      await _requestSync(peer.ipAddress, peer.tcpPort);
    }

    // Remove synced peers that disconnected
    _syncedPeers.removeWhere((id) => !newPeers.containsKey(id));
  }

  /// Request message sync from a peer
  Future<void> _requestSync(String peerAddress, int peerPort) async {
    try {
      final settings = ref.read(settingsProvider);
      final deviceId = settings.deviceId;

      if (deviceId == null) return;

      // Request sync with timestamp 0 to get all messages
      // The receiver will send all their messages and we'll deduplicate
      print('📊 Requesting full sync (all messages)');
      if (state.messages.isNotEmpty) {
        print(
          '   Our messages: ${state.messages.map((m) => '${m.timestampMicros}: "${m.content}"').join(', ')}',
        );
      }

      final sent = await _tcpServer.sendSyncRequest(
        peerAddress,
        peerPort,
        deviceId,
        0, // Request all messages
      );

      if (sent) {
        print('✅ Sync request sent to $peerAddress:$peerPort');
      } else {
        print(
          '⚠️ Sync request to $peerAddress:$peerPort deferred (peer still starting)',
        );
      }
    } catch (e) {
      print('⚠️ Failed to request sync: $e');
    }
  }

  /// Handle sync request from a peer
  Future<void> _handleSyncRequest(Map<String, dynamic> request) async {
    try {
      final peerAddress = request['address'] as String;
      final peerPort = request['port'] as int;
      final sinceTimestamp = request['since_timestamp'] as int;

      print(
        '🔄 Received sync request from $peerAddress:$peerPort (since: $sinceTimestamp)',
      );

      // Ensure messages are loaded
      if (state.isLoading) {
        print('⏳ Messages still loading, waiting...');
        await loadMessages();
      }

      print('📊 Current state has ${state.messages.length} messages');

      // Get messages newer than the requested timestamp
      final messagesToSync = state.messages
          .where((m) => m.timestampMicros > sinceTimestamp)
          .toList();

      if (state.messages.isNotEmpty) {
        print(
          '   All message timestamps: ${state.messages.map((m) => m.timestampMicros).join(', ')}',
        );
        print('   Requested since: $sinceTimestamp');
        print('   Messages to sync: ${messagesToSync.length}');
      }

      print('📤 Sending ${messagesToSync.length} messages for sync');

      if (messagesToSync.isNotEmpty) {
        print(
          '   Timestamp range: ${messagesToSync.first.timestampMicros} to ${messagesToSync.last.timestampMicros}',
        );
      }

      // Send each message
      for (final message in messagesToSync) {
        print('   Syncing: "${message.content}" (${message.timestampMicros})');
        await _tcpServer.sendMessage(peerAddress, peerPort, message);
      }

      print('✅ Sync completed with $peerAddress:$peerPort');
    } catch (e) {
      print('❌ Failed to handle sync request: $e');
    }
  }

  /// Handle name change notification from a peer
  Future<void> _handleNameChange(Map<String, dynamic> notification) async {
    try {
      final deviceId = notification['device_id'] as String;
      final newName = notification['new_name'] as String;

      print('👤 Processing name change: $deviceId → "$newName"');

      // Update all messages from this sender in database
      final settings = ref.read(settingsProvider);
      final networkId = settings.networkId;
      final updatedCount = await _repository.updateSenderName(
        deviceId,
        newName,
        networkId,
      );
      print('✅ Updated $updatedCount messages with new name');

      // Reload messages to reflect the change in UI
      await loadMessages();
    } catch (e) {
      print('❌ Failed to handle name change: $e');
    }
  }

  /// Broadcast name change to all peers
  Future<void> broadcastNameChange(String newName) async {
    try {
      final settings = ref.read(settingsProvider);
      final deviceId = settings.deviceId;

      if (deviceId == null) return;

      // Get all discovered peers
      final discoveryState = ref.read(discoveryProvider);
      final peers = discoveryState.peers.values;

      print(
        '📢 Broadcasting name change "$newName" to ${peers.length} peer(s)',
      );

      for (final peer in peers) {
        await _tcpServer.sendNameChange(
          peer.ipAddress,
          peer.tcpPort,
          deviceId,
          newName,
        );
      }

      print('✅ Name change broadcasted to all peers');
    } catch (e) {
      print('❌ Failed to broadcast name change: $e');
    }
  }

  /// Handle authentication request from a new peer
  Future<void> _handleAuthRequest(Map<String, dynamic> request) async {
    try {
      print('🔐 Received auth request');

      final peerAddress = request['peer_address'] as String;
      final peerPort = request['peer_port'] as int;
      final encryptedPasswordHash =
          request['encrypted_password_hash'] as String;
      final peerPublicKey = request['public_key'] as String;

      print('   From: $peerAddress:$peerPort');

      final securityService = SecurityService.instance;

      // Decrypt the password hash with our private key
      String decryptedPasswordHash;
      try {
        decryptedPasswordHash = securityService.decryptWithPrivateKey(
          encryptedPasswordHash,
        );
        print('🔓 Decrypted password hash');
      } catch (e) {
        print('❌ Failed to decrypt password hash: $e');
        await _tcpServer.sendAuthResponse(
          peerAddress: peerAddress,
          peerPort: peerPort,
          success: false,
          message: 'Failed to decrypt password hash',
        );
        return;
      }

      // Compare with our stored password hash
      final storedPasswordHash = securityService.passwordHash;
      if (storedPasswordHash == null) {
        print('❌ No stored password hash found');
        await _tcpServer.sendAuthResponse(
          peerAddress: peerAddress,
          peerPort: peerPort,
          success: false,
          message: 'Authentication not configured',
        );
        return;
      }

      if (decryptedPasswordHash != storedPasswordHash) {
        print('❌ Password hash mismatch');
        await _tcpServer.sendAuthResponse(
          peerAddress: peerAddress,
          peerPort: peerPort,
          success: false,
          message: 'Invalid password',
        );
        return;
      }

      print(
        '✅ Password verified! Encrypting AES key with peer\'s public key...',
      );

      // Get our AES key
      final aesKeyBase64 = securityService.aesKeyBase64;

      if (aesKeyBase64 == null) {
        print('❌ No AES key found');
        await _tcpServer.sendAuthResponse(
          peerAddress: peerAddress,
          peerPort: peerPort,
          success: false,
          message: 'Encryption key not available',
        );
        return;
      }

      // Parse peer's public key and encrypt AES key
      String encryptedAesKey;
      try {
        encryptedAesKey = await _encryptWithPeerPublicKey(
          aesKeyBase64,
          peerPublicKey,
        );
        print('🔐 AES key encrypted with peer\'s public key');
      } catch (e) {
        print('❌ Failed to encrypt AES key: $e');
        await _tcpServer.sendAuthResponse(
          peerAddress: peerAddress,
          peerPort: peerPort,
          success: false,
          message: 'Failed to encrypt key',
        );
        return;
      }

      // Send success response with encrypted AES key
      await _tcpServer.sendAuthResponse(
        peerAddress: peerAddress,
        peerPort: peerPort,
        success: true,
        encryptedAesKey: encryptedAesKey,
        message: 'Authentication successful',
      );

      print('✅ Auth response sent successfully');
    } catch (e) {
      print('❌ Failed to handle auth request: $e');
    }
  }

  /// Encrypt data with peer's RSA public key
  Future<String> _encryptWithPeerPublicKey(
    String plaintext,
    String peerPublicKeyPem,
  ) async {
    final securityService = SecurityService.instance;

    // Parse the PEM public key
    final base64String = peerPublicKeyPem.replaceAll('PUBLIC:', '');
    final bytes = base64Decode(base64String);
    final asn1Parser = asn1.ASN1Parser(bytes);
    final seq = asn1Parser.nextObject() as asn1.ASN1Sequence;

    final peerPublicKey = pc.RSAPublicKey(
      (seq.elements[0] as asn1.ASN1Integer).valueAsBigInteger, // modulus
      (seq.elements[1] as asn1.ASN1Integer).valueAsBigInteger, // exponent
    );

    // Encrypt with peer's public key
    return securityService.encryptWithPublicKey(plaintext, peerPublicKey);
  }

  /// Send a message to all peers
  Future<void> sendMessage(String content) async {
    final settings = ref.read(settingsProvider);
    final deviceId = settings.deviceId;
    final userName = settings.userName;
    final networkId = settings.networkId;

    if (deviceId == null || userName == null) {
      state = state.copyWith(error: 'Not configured properly');
      return;
    }

    // Prevent sending messages when not on a valid WiFi network
    if (networkId == 'Unknown' || networkId.isEmpty) {
      state = state.copyWith(
        error:
            'WiFi network required. Please connect to WiFi to send messages.',
      );
      return;
    }

    // Validate message size
    if (content.trim().isEmpty) {
      state = state.copyWith(error: 'Message cannot be empty');
      return;
    }

    try {
      // Create message with UUIDv7
      const uuid = Uuid();
      final message = Message(
        uuid: uuid.v7(),
        timestampMicros: DateTime.now().microsecondsSinceEpoch,
        senderId: deviceId,
        senderName: userName,
        content: content,
        isOutgoing: true,
      );

      print('📤 Sending message: "$content"');

      // Save to database first
      final settings = ref.read(settingsProvider);
      final networkId = settings.networkId;
      await _repository.saveMessage(message, deviceId, networkId);

      // Update local state
      final updatedMessages = [...state.messages, message];
      updatedMessages.sort(
        (a, b) => a.timestampMicros.compareTo(b.timestampMicros),
      );
      state = state.copyWith(messages: updatedMessages);

      // Send to all discovered peers
      final discoveryState = ref.read(discoveryProvider);
      final peers = discoveryState.peers.values;

      print('👥 Discovered ${peers.length} peer(s)');

      if (peers.isEmpty) {
        print('⚠️ No peers to send message to');
      }

      for (final peer in peers) {
        print(
          '   Sending to ${peer.deviceName} at ${peer.ipAddress}:${peer.tcpPort}',
        );
        await _tcpServer.sendMessage(peer.ipAddress, peer.tcpPort, message);
      }
    } catch (e) {
      print('❌ Error sending message: $e');
      state = state.copyWith(error: 'Failed to send message: $e');
    }
  }

  /// Send typing indicator to all peers
  Future<void> sendTypingIndicator() async {
    try {
      final settings = ref.read(settingsProvider);
      final deviceId = settings.deviceId;
      final userName = settings.userName;

      if (deviceId == null || userName == null) {
        print(
          '⚠️ Cannot send typing indicator: missing device ID or user name',
        );
        return;
      }

      // Send to all discovered peers
      final discoveryState = ref.read(discoveryProvider);
      final peers = discoveryState.peers.values;

      for (final peer in peers) {
        await _tcpServer.sendTypingIndicator(
          peer.ipAddress,
          peer.tcpPort,
          deviceId,
          userName,
        );
      }
    } catch (e) {
      // Silently fail for typing indicators - they're not critical
      print('⚠️ Error sending typing indicator: $e');
    }
  }

  /// Delete a message
  Future<void> deleteMessage(String uuid, String senderId) async {
    try {
      await _repository.deleteMessage(uuid, senderId);

      final updatedMessages = state.messages
          .where((m) => m.uuid != uuid || m.senderId != senderId)
          .toList();
      state = state.copyWith(messages: updatedMessages);
    } catch (e) {
      state = state.copyWith(error: 'Failed to delete message: $e');
    }
  }

  /// Clear all messages
  Future<void> clearAllMessages() async {
    try {
      final settings = ref.read(settingsProvider);
      final networkId = settings.networkId;
      await _repository.clearAllMessages(networkId);
      state = const MessageState();
    } catch (e) {
      state = state.copyWith(error: 'Failed to clear messages: $e');
    }
  }

  /// Clean up expired messages
  Future<void> cleanupExpiredMessages() async {
    try {
      final deletedCount = await _repository.deleteExpiredMessages();
      if (deletedCount > 0) {
        await loadMessages();
      }
    } catch (e) {
      state = state.copyWith(error: 'Failed to cleanup messages: $e');
    }
  }

  /// Start TCP server
  Future<bool> startServer() async {
    return await _tcpServer.start();
  }

  /// Stop TCP server
  Future<void> stopServer() async {
    _peerSubscription?.close();
    await _tcpServer.stop();
  }

  /// Get TCP server port
  int? get serverPort => _tcpServer.actualPort;
}

/// Provider for messages
final messageProvider = NotifierProvider<MessageNotifier, MessageState>(
  () => MessageNotifier(),
);
