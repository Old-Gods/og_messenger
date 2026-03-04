import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../settings/providers/settings_provider.dart';
import '../../discovery/providers/discovery_provider.dart';
import '../../rooms/providers/room_provider.dart';
import '../domain/entities/reaction.dart';
import '../data/repositories/reaction_repository.dart';
import '../../../features/messaging/data/services/tcp_server_service.dart';

/// Reaction state
class ReactionState {
  /// Map of message key (uuid_senderId) to list of reactions
  final Map<String, List<Reaction>> reactionsByMessage;
  final bool isLoading;
  final String? error;

  const ReactionState({
    this.reactionsByMessage = const {},
    this.isLoading = false,
    this.error,
  });

  ReactionState copyWith({
    Map<String, List<Reaction>>? reactionsByMessage,
    bool? isLoading,
    String? error,
  }) {
    return ReactionState(
      reactionsByMessage: reactionsByMessage ?? this.reactionsByMessage,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Provider for reaction state management
final reactionProvider = NotifierProvider<ReactionNotifier, ReactionState>(
  () => ReactionNotifier(),
);

/// Notifier for managing reaction state
class ReactionNotifier extends Notifier<ReactionState> {
  final ReactionRepository _repository = ReactionRepository();
  final TcpServerService _tcpServer = TcpServerService.instance;
  StreamSubscription<Map<String, dynamic>>? _reactionSubscription;

  /// Expose repository for sync operations
  ReactionRepository get repository => _repository;

  @override
  ReactionState build() {
    // Listen to incoming reactions from TCP server
    _reactionSubscription = _tcpServer.reactionStream.listen(
      _handleIncomingReaction,
      onError: (error) {
        print('❌ Reaction stream error: $error');
      },
    );

    // Listen to room changes and reload reactions
    ref.listen(roomProvider, (previous, next) {
      if (previous?.activeRoomId != next.activeRoomId) {
        print('🔄 Room changed, clearing reactions');
        state = const ReactionState();
      }
    });

    // Cancel subscription when provider is disposed
    ref.onDispose(() {
      _reactionSubscription?.cancel();
    });

    return const ReactionState();
  }

  /// Load reactions for a list of messages (batch operation)
  Future<void> loadReactionsForMessages(
    List<String> messageKeys,
    String roomId,
  ) async {
    if (messageKeys.isEmpty) return;

    try {
      final reactions = await _repository.getReactionsForMessages(
        messageKeys: messageKeys,
        roomId: roomId,
      );

      // Merge with existing reactions
      final updatedReactions = Map<String, List<Reaction>>.from(
        state.reactionsByMessage,
      );
      updatedReactions.addAll(reactions);

      state = state.copyWith(reactionsByMessage: updatedReactions);
    } catch (e) {
      print('❌ Failed to load reactions: $e');
      state = state.copyWith(error: 'Failed to load reactions: $e');
    }
  }

  /// Add a reaction to a message
  Future<void> addReaction({
    required String messageUuid,
    required String messageSenderId,
    required String emoji,
    required String roomId,
  }) async {
    try {
      final settings = ref.read(settingsProvider);
      final deviceId = settings.deviceId ?? '';
      final userName = settings.userName ?? 'Unknown';

      final reaction = Reaction(
        messageUuid: messageUuid,
        messageSenderId: messageSenderId,
        reactorDeviceId: deviceId,
        reactorName: userName,
        emoji: emoji,
        timestampMicros: DateTime.now().microsecondsSinceEpoch,
        roomId: roomId,
      );

      // Save to local database (UPSERT - replaces existing reaction)
      await _repository.saveReaction(reaction);

      // Update local state optimistically
      _updateLocalReactionState(reaction, isAdd: true);

      // Broadcast to all online peers
      await _broadcastReaction(reaction, action: 'add');
    } catch (e) {
      print('❌ Failed to add reaction: $e');
      state = state.copyWith(error: 'Failed to add reaction: $e');
    }
  }

  /// Remove a reaction from a message
  Future<void> removeReaction({
    required String messageUuid,
    required String messageSenderId,
    required String roomId,
  }) async {
    try {
      final settings = ref.read(settingsProvider);
      final deviceId = settings.deviceId ?? '';

      // Delete from local database
      await _repository.deleteReaction(
        messageUuid: messageUuid,
        messageSenderId: messageSenderId,
        reactorDeviceId: deviceId,
        roomId: roomId,
      );

      // Update local state
      _removeLocalReactionState(messageUuid, messageSenderId, deviceId);

      // Broadcast removal to all online peers
      await _broadcastReactionRemoval(
        messageUuid: messageUuid,
        messageSenderId: messageSenderId,
        reactorDeviceId: deviceId,
        roomId: roomId,
      );
    } catch (e) {
      print('❌ Failed to remove reaction: $e');
      state = state.copyWith(error: 'Failed to remove reaction: $e');
    }
  }

  /// Toggle a reaction (add if not present, remove if present, or change if different)
  Future<void> toggleReaction({
    required String messageUuid,
    required String messageSenderId,
    required String emoji,
    required String roomId,
  }) async {
    final settings = ref.read(settingsProvider);
    final deviceId = settings.deviceId ?? '';

    // Check if user already has a reaction on this message
    final messageKey = '${messageUuid}_$messageSenderId';
    final reactions = state.reactionsByMessage[messageKey] ?? [];
    final existingReaction = reactions.firstWhere(
      (r) => r.reactorDeviceId == deviceId,
      orElse: () => Reaction(
        messageUuid: '',
        messageSenderId: '',
        reactorDeviceId: '',
        reactorName: '',
        emoji: '',
        timestampMicros: 0,
        roomId: '',
      ),
    );

    if (existingReaction.messageUuid.isEmpty) {
      // No existing reaction, add new one
      await addReaction(
        messageUuid: messageUuid,
        messageSenderId: messageSenderId,
        emoji: emoji,
        roomId: roomId,
      );
    } else if (existingReaction.emoji == emoji) {
      // Same emoji, remove it
      await removeReaction(
        messageUuid: messageUuid,
        messageSenderId: messageSenderId,
        roomId: roomId,
      );
    } else {
      // Different emoji, replace it (add will UPSERT)
      await addReaction(
        messageUuid: messageUuid,
        messageSenderId: messageSenderId,
        emoji: emoji,
        roomId: roomId,
      );
    }
  }

  /// Handle incoming reaction from network
  void _handleIncomingReaction(Map<String, dynamic> data) {
    try {
      final action = data['action'] as String;

      if (action == 'add') {
        final reaction = Reaction.fromJson(data);

        // Save to database
        _repository.saveReaction(reaction);

        // Update state
        _updateLocalReactionState(reaction, isAdd: true);

        print('✅ Reaction added from network: ${reaction.emoji}');
      } else if (action == 'remove') {
        final messageUuid = data['message_uuid'] as String;
        final messageSenderId = data['message_sender_id'] as String;
        final reactorDeviceId = data['reactor_device_id'] as String;
        final roomId = data['room_id'] as String;

        // Delete from database
        _repository.deleteReaction(
          messageUuid: messageUuid,
          messageSenderId: messageSenderId,
          reactorDeviceId: reactorDeviceId,
          roomId: roomId,
        );

        // Update state
        _removeLocalReactionState(
          messageUuid,
          messageSenderId,
          reactorDeviceId,
        );

        print('✅ Reaction removed from network');
      }
    } catch (e) {
      print('❌ Failed to handle incoming reaction: $e');
    }
  }

  /// Update local state with a new reaction
  void _updateLocalReactionState(Reaction reaction, {required bool isAdd}) {
    final messageKey = '${reaction.messageUuid}_${reaction.messageSenderId}';
    final updatedReactions = Map<String, List<Reaction>>.from(
      state.reactionsByMessage,
    );

    final currentReactions = List<Reaction>.from(
      updatedReactions[messageKey] ?? [],
    );

    // Remove any existing reaction from this user (enforce one-per-user rule)
    currentReactions.removeWhere(
      (r) => r.reactorDeviceId == reaction.reactorDeviceId,
    );

    // Add the new reaction
    currentReactions.add(reaction);

    updatedReactions[messageKey] = currentReactions;
    state = state.copyWith(reactionsByMessage: updatedReactions);
  }

  /// Remove a reaction from local state
  void _removeLocalReactionState(
    String messageUuid,
    String messageSenderId,
    String reactorDeviceId,
  ) {
    final messageKey = '${messageUuid}_$messageSenderId';
    final updatedReactions = Map<String, List<Reaction>>.from(
      state.reactionsByMessage,
    );

    if (updatedReactions.containsKey(messageKey)) {
      final currentReactions = List<Reaction>.from(
        updatedReactions[messageKey]!,
      );
      currentReactions.removeWhere((r) => r.reactorDeviceId == reactorDeviceId);

      if (currentReactions.isEmpty) {
        updatedReactions.remove(messageKey);
      } else {
        updatedReactions[messageKey] = currentReactions;
      }
    }

    state = state.copyWith(reactionsByMessage: updatedReactions);
  }

  /// Broadcast reaction to all online peers
  Future<void> _broadcastReaction(
    Reaction reaction, {
    required String action,
  }) async {
    final peers = ref.read(discoveryProvider).peers.values;

    for (final peer in peers) {
      await _tcpServer.sendReaction(
        peerAddress: peer.ipAddress,
        peerPort: peer.tcpPort,
        action: action,
        messageUuid: reaction.messageUuid,
        messageSenderId: reaction.messageSenderId,
        reactorDeviceId: reaction.reactorDeviceId,
        reactorName: reaction.reactorName,
        emoji: reaction.emoji,
        timestampMicros: reaction.timestampMicros,
        roomId: reaction.roomId,
      );
    }
  }

  /// Broadcast reaction removal to all online peers
  Future<void> _broadcastReactionRemoval({
    required String messageUuid,
    required String messageSenderId,
    required String reactorDeviceId,
    required String roomId,
  }) async {
    final peers = ref.read(discoveryProvider).peers.values;
    final settings = ref.read(settingsProvider);

    for (final peer in peers) {
      await _tcpServer.sendReaction(
        peerAddress: peer.ipAddress,
        peerPort: peer.tcpPort,
        action: 'remove',
        messageUuid: messageUuid,
        messageSenderId: messageSenderId,
        reactorDeviceId: reactorDeviceId,
        reactorName: settings.userName ?? 'Unknown',
        emoji: '', // Not needed for removal
        timestampMicros: DateTime.now().microsecondsSinceEpoch,
        roomId: roomId,
      );
    }
  }

  /// Clear all reactions (when changing rooms)
  void clearReactions() {
    state = const ReactionState();
  }
}
