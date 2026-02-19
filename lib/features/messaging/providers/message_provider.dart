import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../settings/providers/settings_provider.dart';
import '../../discovery/providers/discovery_provider.dart';
import '../domain/entities/message.dart';
import '../data/repositories/message_repository.dart';
import '../data/services/tcp_server_service.dart';

/// Message state
class MessageState {
  final List<Message> messages;
  final bool isLoading;
  final String? error;

  const MessageState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
  });

  MessageState copyWith({
    List<Message>? messages,
    bool? isLoading,
    String? error,
  }) {
    return MessageState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Message notifier
class MessageNotifier extends Notifier<MessageState> {
  late MessageRepository _repository;
  late TcpServerService _tcpServer;

  @override
  MessageState build() {
    _repository = MessageRepository();
    _tcpServer = TcpServerService();

    // Listen to incoming messages
    _tcpServer.messageStream.listen(_handleIncomingMessage);
    _tcpServer.errorStream.listen(_handleError);

    // Schedule async load after build completes
    Future.microtask(() => loadMessages());

    return const MessageState();
  }

  /// Load all messages from database
  Future<void> loadMessages() async {
    state = state.copyWith(isLoading: true);

    try {
      final settings = ref.read(settingsProvider);
      final deviceId = settings.deviceId ?? '';
      final messages = await _repository.getAllMessages(deviceId);

      state = MessageState(messages: messages, isLoading: false);
    } catch (e) {
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

      // Save to database
      await _repository.saveMessage(message, deviceId);

      // Update state
      final updatedMessages = [...state.messages, message];
      updatedMessages.sort((a, b) => a.timestampMicros.compareTo(b.timestampMicros));
      state = state.copyWith(messages: updatedMessages);
    } catch (e) {
      state = state.copyWith(error: 'Failed to save message: $e');
    }
  }

  /// Handle TCP server error
  void _handleError(String error) {
    state = state.copyWith(error: error);
  }

  /// Send a message to all peers
  Future<void> sendMessage(String content) async {
    final settings = ref.read(settingsProvider);
    final deviceId = settings.deviceId;
    final userName = settings.userName;

    if (deviceId == null || userName == null) {
      state = state.copyWith(error: 'Device not properly configured');
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
      await _repository.saveMessage(message, deviceId);

      // Update local state
      final updatedMessages = [...state.messages, message];
      updatedMessages.sort((a, b) => a.timestampMicros.compareTo(b.timestampMicros));
      state = state.copyWith(messages: updatedMessages);

      // Send to all discovered peers
      final discoveryState = ref.read(discoveryProvider);
      final peers = discoveryState.peers.values;
      
      print('👥 Discovered ${peers.length} peer(s)');

      if (peers.isEmpty) {
        print('⚠️ No peers to send message to');
      }

      for (final peer in peers) {
        print('   Sending to ${peer.deviceName} at ${peer.ipAddress}:${peer.tcpPort}');
        await _tcpServer.sendMessage(
          peer.ipAddress,
          peer.tcpPort,
          message,
        );
      }
    } catch (e) {
      print('❌ Error sending message: $e');
      state = state.copyWith(error: 'Failed to send message: $e');
    }
  }

  /// Delete a message
  Future<void> deleteMessage(String uuid, String senderId) async {
    try {
      await _repository.deleteMessage(uuid, senderId);

      final updatedMessages =
          state.messages.where((m) => m.uuid != uuid || m.senderId != senderId).toList();
      state = state.copyWith(messages: updatedMessages);
    } catch (e) {
      state = state.copyWith(error: 'Failed to delete message: $e');
    }
  }

  /// Clear all messages
  Future<void> clearAllMessages() async {
    try {
      await _repository.clearAllMessages();
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
    await _tcpServer.stop();
  }

  /// Get TCP server port
  int? get serverPort => _tcpServer.actualPort;
}

/// Provider for messages
final messageProvider = NotifierProvider<MessageNotifier, MessageState>(
  () => MessageNotifier(),
);
