import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../settings/providers/settings_provider.dart';
import '../../discovery/providers/discovery_provider.dart';
import '../../notifications/data/services/notification_service.dart';
import '../../../core/constants/network_constants.dart';
import '../domain/entities/message.dart';
import '../data/repositories/message_repository.dart';
import '../data/services/tcp_server_service.dart';
import '../../rooms/providers/room_provider.dart';

/// Message state
class MessageState {
  final List<Message> messages;
  final bool isLoading;
  final String? error;

  // Pagination fields
  final bool isLoadingMore; // Loading older messages
  final bool isLoadingNewer; // Loading newer messages
  final bool hasMoreOlder; // Can load older messages
  final bool hasMoreNewer; // Can load newer messages
  final bool isInLiveMode; // True if viewing latest messages
  final int? oldestTimestamp; // Timestamp of oldest message in window
  final int? newestTimestamp; // Timestamp of newest message in window

  // Sync fields
  final bool syncInProgress; // Currently syncing
  final String? currentSyncPeer; // Name of peer being synced
  final int? syncProgress; // Last synced timestamp for resumption
  final List<String> syncFailedPeers; // Peers that failed to sync
  final bool isInitialSync; // True for first sync, false for background
  final bool syncAckReceived; // True if peer acknowledged sync request
  final int
  syncExpectedMessages; // Number of messages expected in current sync batch
  final int
  syncReceivedMessages; // Number of messages received in current sync batch
  final Map<String, int>
  peerSyncExpected; // Expected messages per peer (concurrent syncs)
  final Map<String, int>
  peerSyncReceived; // Received messages per peer (concurrent syncs)

  const MessageState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
    this.isLoadingMore = false,
    this.isLoadingNewer = false,
    this.hasMoreOlder = false,
    this.hasMoreNewer = false,
    this.isInLiveMode = true,
    this.oldestTimestamp,
    this.newestTimestamp,
    this.syncInProgress = false,
    this.currentSyncPeer,
    this.syncProgress,
    this.syncFailedPeers = const [],
    this.isInitialSync = false,
    this.syncAckReceived = false,
    this.syncExpectedMessages = 0,
    this.syncReceivedMessages = 0,
    this.peerSyncExpected = const {},
    this.peerSyncReceived = const {},
  });

  MessageState copyWith({
    List<Message>? messages,
    bool? isLoading,
    String? error,
    bool? isLoadingMore,
    bool? isLoadingNewer,
    bool? hasMoreOlder,
    bool? hasMoreNewer,
    bool? isInLiveMode,
    int? oldestTimestamp,
    int? newestTimestamp,
    bool? syncInProgress,
    String? currentSyncPeer,
    int? syncProgress,
    List<String>? syncFailedPeers,
    bool? isInitialSync,
    bool? syncAckReceived,
    int? syncExpectedMessages,
    int? syncReceivedMessages,
    Map<String, int>? peerSyncExpected,
    Map<String, int>? peerSyncReceived,
  }) {
    return MessageState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isLoadingNewer: isLoadingNewer ?? this.isLoadingNewer,
      hasMoreOlder: hasMoreOlder ?? this.hasMoreOlder,
      hasMoreNewer: hasMoreNewer ?? this.hasMoreNewer,
      isInLiveMode: isInLiveMode ?? this.isInLiveMode,
      oldestTimestamp: oldestTimestamp ?? this.oldestTimestamp,
      newestTimestamp: newestTimestamp ?? this.newestTimestamp,
      syncInProgress: syncInProgress ?? this.syncInProgress,
      currentSyncPeer: currentSyncPeer ?? this.currentSyncPeer,
      syncProgress: syncProgress ?? this.syncProgress,
      syncFailedPeers: syncFailedPeers ?? this.syncFailedPeers,
      isInitialSync: isInitialSync ?? this.isInitialSync,
      syncAckReceived: syncAckReceived ?? this.syncAckReceived,
      syncExpectedMessages: syncExpectedMessages ?? this.syncExpectedMessages,
      syncReceivedMessages: syncReceivedMessages ?? this.syncReceivedMessages,
      peerSyncExpected: peerSyncExpected ?? this.peerSyncExpected,
      peerSyncReceived: peerSyncReceived ?? this.peerSyncReceived,
    );
  }
}

/// Typing indicator state - separate to avoid rebuilding TextField
class TypingIndicatorState {
  final Map<String, DateTime> typingPeers; // deviceId -> last typing time

  const TypingIndicatorState({this.typingPeers = const {}});

  TypingIndicatorState copyWith({Map<String, DateTime>? typingPeers}) {
    return TypingIndicatorState(typingPeers: typingPeers ?? this.typingPeers);
  }
}

/// Typing indicator notifier - manages typing state separately from messages
class TypingIndicatorNotifier extends Notifier<TypingIndicatorState> {
  Timer? _cleanupTimer;

  @override
  TypingIndicatorState build() {
    // Start cleanup timer
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _cleanupTypingPeers(),
    );

    // Cancel timer when provider is disposed
    ref.onDispose(() {
      _cleanupTimer?.cancel();
    });

    return const TypingIndicatorState();
  }

  /// Clean up expired typing indicators
  void _cleanupTypingPeers() {
    final now = DateTime.now();
    final updated = Map<String, DateTime>.from(state.typingPeers);
    bool needsUpdate = false;

    updated.removeWhere((deviceId, lastTyping) {
      final shouldRemove =
          now.difference(lastTyping) > NetworkConstants.typingTimeout;
      if (shouldRemove) needsUpdate = true;
      return shouldRemove;
    });

    if (needsUpdate) {
      state = state.copyWith(typingPeers: updated);
    }
  }

  /// Handle typing indicator from another peer
  void handleTypingIndicator(String deviceId) {
    final updated = Map<String, DateTime>.from(state.typingPeers);
    updated[deviceId] = DateTime.now();
    state = state.copyWith(typingPeers: updated);
  }

  /// Clear typing indicator for a specific device (e.g., when they send a message)
  void clearTypingIndicator(String deviceId) {
    final updated = Map<String, DateTime>.from(state.typingPeers);
    if (updated.remove(deviceId) != null) {
      state = state.copyWith(typingPeers: updated);
    }
  }

  /// Clear all typing indicators
  void clearAll() {
    state = const TypingIndicatorState();
  }
}

/// Provider for typing indicators - separate from message state
final typingIndicatorProvider =
    NotifierProvider<TypingIndicatorNotifier, TypingIndicatorState>(
      () => TypingIndicatorNotifier(),
    );

/// Message notifier
class MessageNotifier extends Notifier<MessageState> {
  late MessageRepository _repository;
  late TcpServerService _tcpServer;
  ProviderSubscription? _peerSubscription;
  final Set<String> _syncedPeers = {};
  bool _isAppInForeground = true;

  // Sync tracking
  bool _isFirstPeerDiscovered = false;
  final List<String> _peersToSync = [];

  @override
  MessageState build() {
    _repository = MessageRepository();
    _tcpServer = TcpServerService.instance;

    // Listen to incoming messages
    _tcpServer.messageStream.listen(_handleIncomingMessage);
    _tcpServer.errorStream.listen(_handleError);
    _tcpServer.syncRequestStream.listen(_handleSyncRequest);
    _tcpServer.syncReceivedStream.listen(_handleSyncReceived);
    _tcpServer.nameChangeStream.listen(_handleNameChange);
    // Auth removed - using room-based join requests instead
    // _tcpServer.authRequestStream.listen(_handleAuthRequest);
    _tcpServer.typingIndicatorStream.listen(_handleTypingIndicator);

    // Listen to peer discoveries for auto-sync
    _peerSubscription = ref.listen(discoveryProvider, (previous, next) {
      _handlePeerChanges(previous?.peers ?? {}, next.peers);
    });

    // Set up typing cleanup timer cancellation on dispose
    ref.onDispose(() {
      _peerSubscription?.close();
    });

    // Listen to active room changes - reload messages and sync when room changes
    ref.listen(roomProvider, (previous, next) {
      if (previous?.activeRoomId != next.activeRoomId &&
          next.activeRoomId != null) {
        print(
          '🔄 Active room changed, reloading messages for room: ${next.activeRoomId}',
        );
        Future.microtask(() async {
          await loadInitialMessages();
          // Trigger sync with all connected peers for this new room
          await _syncWithAllPeers();
        });
      }
    });

    // Schedule async load after build completes
    Future.microtask(() => loadInitialMessages());

    // Clean up timer when provider is disposed
    ref.onDispose(() {
      _peerSubscription?.close();
    });

    return const MessageState();
  }

  /// Handle typing indicator
  void _handleTypingIndicator(Map<String, dynamic> data) {
    final deviceId = data['device_id'] as String;
    ref.read(typingIndicatorProvider.notifier).handleTypingIndicator(deviceId);
  }

  /// Update app foreground state
  void setAppInForeground(bool inForeground) {
    _isAppInForeground = inForeground;
  }

  /// Load all messages from database
  @Deprecated('Use loadInitialMessages() for paginated loading')
  Future<void> loadMessages() async {
    state = state.copyWith(isLoading: true);

    try {
      final settings = ref.read(settingsProvider);
      final deviceId = settings.deviceId ?? '';
      final roomState = ref.read(roomProvider);
      final networkId = roomState.activeRoomId ?? 'default_room';

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

  /// Load initial messages (most recent 50) from database
  Future<void> loadInitialMessages() async {
    state = state.copyWith(isLoading: true);

    try {
      final settings = ref.read(settingsProvider);
      final deviceId = settings.deviceId ?? '';
      final roomState = ref.read(roomProvider);
      final networkId = roomState.activeRoomId ?? 'default_room';

      final messages = await _repository.getInitialMessages(
        deviceId,
        networkId,
        50,
      );

      final oldestTimestamp = messages.isNotEmpty
          ? messages.first.timestampMicros
          : null;
      final newestTimestamp = messages.isNotEmpty
          ? messages.last.timestampMicros
          : null;

      // Check if there are more older messages
      final hasMoreOlder = messages.length == 50;

      print(
        '📚 Loaded ${messages.length} initial messages from database (network: $networkId)',
      );

      state = MessageState(
        messages: messages,
        isLoading: false,
        isInLiveMode: true,
        hasMoreOlder: hasMoreOlder,
        hasMoreNewer: false,
        oldestTimestamp: oldestTimestamp,
        newestTimestamp: newestTimestamp,
      );
    } catch (e) {
      print('❌ Failed to load messages: $e');
      state = MessageState(
        messages: state.messages,
        isLoading: false,
        error: 'Failed to load messages: $e',
      );
    }
  }

  /// Load older messages (pagination backwards)
  Future<void> loadOlderMessages() async {
    // Don't load if already loading or no more messages
    if (state.isLoadingMore ||
        !state.hasMoreOlder ||
        state.oldestTimestamp == null) {
      return;
    }

    state = state.copyWith(isLoadingMore: true);

    try {
      final settings = ref.read(settingsProvider);
      final deviceId = settings.deviceId ?? '';
      final roomState = ref.read(roomProvider);
      final networkId = roomState.activeRoomId ?? 'default_room';

      final olderMessages = await _repository.getMessagesBeforeTimestamp(
        deviceId,
        networkId,
        state.oldestTimestamp!,
        25,
      );

      if (olderMessages.isEmpty) {
        print('📚 No more older messages');
        state = state.copyWith(isLoadingMore: false, hasMoreOlder: false);
        return;
      }

      print('📚 Loaded ${olderMessages.length} older messages');

      // Prepend older messages
      final updatedMessages = [...olderMessages, ...state.messages];

      // Evict newest 25 messages if window exceeds 200
      if (updatedMessages.length > 200) {
        updatedMessages.removeRange(
          updatedMessages.length - 25,
          updatedMessages.length,
        );
        print(
          '🗑️ Evicted 25 newest messages (window size: ${updatedMessages.length})',
        );
      }

      final oldestTimestamp = updatedMessages.isNotEmpty
          ? updatedMessages.first.timestampMicros
          : null;
      final newestTimestamp = updatedMessages.isNotEmpty
          ? updatedMessages.last.timestampMicros
          : null;
      final hasMoreOlder = olderMessages.length == 25;

      state = state.copyWith(
        messages: updatedMessages,
        isLoadingMore: false,
        isInLiveMode: false,
        hasMoreOlder: hasMoreOlder,
        oldestTimestamp: oldestTimestamp,
        newestTimestamp: newestTimestamp,
      );
    } catch (e) {
      print('❌ Failed to load older messages: $e');
      state = state.copyWith(
        isLoadingMore: false,
        error: 'Failed to load older messages: $e',
      );
    }
  }

  /// Load newer messages (pagination forwards)
  Future<void> loadNewerMessages() async {
    // Don't load if already loading or no more messages
    if (state.isLoadingNewer ||
        !state.hasMoreNewer ||
        state.newestTimestamp == null) {
      return;
    }

    state = state.copyWith(isLoadingNewer: true);

    try {
      final settings = ref.read(settingsProvider);
      final deviceId = settings.deviceId ?? '';
      final roomState = ref.read(roomProvider);
      final networkId = roomState.activeRoomId ?? 'default_room';

      final newerMessages = await _repository
          .getMessagesAfterTimestampPaginated(
            deviceId,
            networkId,
            state.newestTimestamp!,
            25,
          );

      if (newerMessages.isEmpty) {
        print('📚 No more newer messages - reached live end');
        state = state.copyWith(
          isLoadingNewer: false,
          hasMoreNewer: false,
          isInLiveMode: true,
        );
        return;
      }

      print('📚 Loaded ${newerMessages.length} newer messages');

      // Append newer messages
      final updatedMessages = [...state.messages, ...newerMessages];

      // Evict oldest 25 messages if window exceeds 200
      if (updatedMessages.length > 200) {
        updatedMessages.removeRange(0, 25);
        print(
          '🗑️ Evicted 25 oldest messages (window size: ${updatedMessages.length})',
        );
      }

      final oldestTimestamp = updatedMessages.isNotEmpty
          ? updatedMessages.first.timestampMicros
          : null;
      final newestTimestamp = updatedMessages.isNotEmpty
          ? updatedMessages.last.timestampMicros
          : null;

      // Check if we've reached the live end
      final hasMoreNewer = newerMessages.length == 25;
      final isInLiveMode = !hasMoreNewer;

      state = state.copyWith(
        messages: updatedMessages,
        isLoadingNewer: false,
        hasMoreNewer: hasMoreNewer,
        isInLiveMode: isInLiveMode,
        oldestTimestamp: oldestTimestamp,
        newestTimestamp: newestTimestamp,
      );
    } catch (e) {
      print('❌ Failed to load newer messages: $e');
      state = state.copyWith(
        isLoadingNewer: false,
        error: 'Failed to load newer messages: $e',
      );
    }
  }

  /// Handle incoming message from TCP server
  Future<void> _handleIncomingMessage(Message message) async {
    try {
      final settings = ref.read(settingsProvider);
      final deviceId = settings.deviceId ?? '';
      final roomState = ref.read(roomProvider);
      final activeRoomId = roomState.activeRoomId ?? 'default_room';
      final messageRoomId = message.roomId ?? 'default_room';

      // Check for duplicates FIRST - before any processing
      // This prevents duplicate notifications and unnecessary database operations
      final isDuplicateInMemory = state.messages.any(
        (m) => m.uuid == message.uuid && m.senderId == message.senderId,
      );

      // Also check database to catch duplicates from other rooms
      bool isDuplicateInDb = false;
      try {
        final existingMessages = await _repository.getMessageByUuid(
          message.uuid,
          message.senderId,
          messageRoomId,
        );
        isDuplicateInDb = existingMessages != null;
      } catch (e) {
        // If database check fails, continue (might be unique constraint error during save)
      }

      final isDuplicate = isDuplicateInMemory || isDuplicateInDb;

      if (isDuplicate) {
        print(
          '⚠️ Skipping duplicate message: "${message.content}" from ${message.senderName}',
        );

        // Track sync progress per peer for duplicates too
        if (state.peerSyncExpected.containsKey(message.senderId)) {
          final received = Map<String, int>.from(state.peerSyncReceived);
          received[message.senderId] = (received[message.senderId] ?? 0) + 1;
          state = state.copyWith(peerSyncReceived: received);

          // Also update global counter for backwards compatibility
          if (state.syncInProgress) {
            state = state.copyWith(
              syncReceivedMessages: state.syncReceivedMessages + 1,
            );
          }
        }

        return;
      }

      // Save to database with the message's actual room ID
      await _repository.saveMessage(message, deviceId, messageRoomId);

      // Track sync progress per peer
      if (state.peerSyncExpected.containsKey(message.senderId)) {
        final received = Map<String, int>.from(state.peerSyncReceived);
        received[message.senderId] = (received[message.senderId] ?? 0) + 1;
        state = state.copyWith(peerSyncReceived: received);

        // Also update global counter for backwards compatibility
        if (state.syncInProgress) {
          state = state.copyWith(
            syncReceivedMessages: state.syncReceivedMessages + 1,
          );
        }
      }

      // Check if message belongs to active room
      final isActiveRoom = messageRoomId == activeRoomId;

      // Show notification if:
      // - NOT during sync (synced messages shouldn't trigger notifications)
      // - AND (app is in background OR message is for different room)
      if (!state.syncInProgress && (!_isAppInForeground || !isActiveRoom)) {
        try {
          await NotificationService.instance.showMessageNotification(
            senderName: message.senderName,
            messageContent: message.content,
            messageId: message.uuid,
            roomId: messageRoomId,
          );
          print('🔔 Notification shown for message from ${message.senderName}');
        } catch (e) {
          print('⚠️ Failed to show notification: $e');
        }
      } else if (state.syncInProgress) {
        print('📥 Sync in progress, skipping notification');
      } else {
        print(
          '📱 App in foreground and viewing active room, skipping notification',
        );
      }

      // Only process for UI if message belongs to active room
      if (!isActiveRoom) {
        print(
          '📦 Message for different room ($messageRoomId), saved but not displaying (active: $activeRoomId)',
        );
        return;
      }

      // Clear typing indicator for this sender (they sent a message)
      ref
          .read(typingIndicatorProvider.notifier)
          .clearTypingIndicator(message.senderId);

      print(
        '💾 Saving new message: "${message.content}" from ${message.senderName}',
      );

      // Only update window if in live mode
      if (state.isInLiveMode) {
        final updatedMessages = [...state.messages];

        // Fast path: check if we can just append (most common case)
        if (updatedMessages.isEmpty ||
            updatedMessages.last.timestampMicros <= message.timestampMicros) {
          updatedMessages.add(message);
        } else {
          // Search backwards from the end to find insertion point
          int insertIndex = _findInsertIndexFromEnd(
            updatedMessages,
            message.timestampMicros,
          );
          updatedMessages.insert(insertIndex, message);
        }

        // Evict oldest 25 messages if window exceeds 200
        if (updatedMessages.length > 200) {
          updatedMessages.removeRange(0, 25);
          print(
            '🗑️ Evicted 25 oldest messages (window size: ${updatedMessages.length})',
          );
        }

        // Update timestamps
        final oldestTimestamp = updatedMessages.isNotEmpty
            ? updatedMessages.first.timestampMicros
            : null;
        final newestTimestamp = updatedMessages.isNotEmpty
            ? updatedMessages.last.timestampMicros
            : null;

        state = state.copyWith(
          messages: updatedMessages,
          oldestTimestamp: oldestTimestamp,
          newestTimestamp: newestTimestamp,
        );
      } else {
        print(
          '📥 Message saved to database (not in live mode, skipping window update)',
        );
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

  /// Find insertion index by searching backwards from the end - O(n) worst case, O(1) typical
  int _findInsertIndexFromEnd(List<Message> messages, int timestamp) {
    // Search backwards from the end
    for (int i = messages.length - 1; i >= 0; i--) {
      if (messages[i].timestampMicros <= timestamp) {
        return i + 1; // Insert after this message
      }
    }

    // Message is older than all existing messages
    return 0;
  }

  /// Sync with all currently connected peers
  Future<void> _syncWithAllPeers() async {
    final discoveryState = ref.read(discoveryProvider);
    final peers = discoveryState.peers;

    if (peers.isEmpty) {
      print('📭 No peers available for sync');
      return;
    }

    print('🔄 Syncing with ${peers.length} connected peers');

    for (final peer in peers.values) {
      await _syncWithPeer(
        peer.ipAddress,
        peer.tcpPort,
        peer.deviceName,
        peer.deviceId,
        isBackground: true,
      );
    }
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

      print('🔄 New peer discovered: ${peer.deviceName}');

      // Determine if this is initial or background sync
      final isInitialSync = !_isFirstPeerDiscovered;
      if (isInitialSync) {
        _isFirstPeerDiscovered = true;
      }

      // Mark as syncing
      _syncedPeers.add(peerId);
      _peersToSync.add(peerId);

      // Start sync based on mode
      if (isInitialSync) {
        print('📋 Initial sync mode - showing sync screen');
        state = state.copyWith(
          syncInProgress: true,
          isInitialSync: true,
          currentSyncPeer: peer.deviceName,
        );
        await _syncWithPeer(
          peer.ipAddress,
          peer.tcpPort,
          peer.deviceName,
          peer.deviceId,
          isBackground: false,
        );
      } else {
        print('📋 Background sync mode');
        state = state.copyWith(syncInProgress: true, isInitialSync: false);
        await _syncWithPeer(
          peer.ipAddress,
          peer.tcpPort,
          peer.deviceName,
          peer.deviceId,
          isBackground: true,
        );
      }
    }

    // Remove synced peers that disconnected
    _syncedPeers.removeWhere((id) => !newPeers.containsKey(id));
  }

  /// Sync with a peer using paginated requests
  Future<void> _syncWithPeer(
    String peerAddress,
    int peerPort,
    String peerName,
    String peerId, {
    required bool isBackground,
  }) async {
    try {
      final settings = ref.read(settingsProvider);
      final deviceId = settings.deviceId;

      if (deviceId == null) return;

      // Get our latest message timestamp, or request from timestamp - 5 messages
      final roomState = ref.read(roomProvider);
      final networkId = roomState.activeRoomId ?? 'default_room';
      final latestTimestamp = await _repository.getLatestTimestamp(networkId);
      int syncFromTimestamp = 0;

      if (latestTimestamp != null && latestTimestamp > 0) {
        // Get the 5th oldest message timestamp to provide overlap
        final recentMessages = await _repository.getInitialMessages(
          deviceId,
          networkId,
          5,
        );
        if (recentMessages.isNotEmpty) {
          syncFromTimestamp = recentMessages.first.timestampMicros;
        }
      }

      print(
        '📊 Starting paginated sync with $peerName (from timestamp: $syncFromTimestamp)',
      );

      int messagesReceived = 0;
      int batchCount = 0;
      bool hasMore = true;
      final List<String> failedBatches = [];

      while (hasMore) {
        batchCount++;
        print('📦 Requesting batch $batchCount from $peerName...');

        // Update sync progress
        state = state.copyWith(
          currentSyncPeer: peerName,
          syncProgress: syncFromTimestamp,
        );

        // Send sync request with timeout
        final syncRequestFuture = _tcpServer.sendSyncRequest(
          peerAddress,
          peerPort,
          deviceId,
          syncFromTimestamp,
          networkId,
        );

        bool sent;
        try {
          sent = await syncRequestFuture.timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              print('⏱️ Sync request batch $batchCount timed out');
              return false;
            },
          );
        } catch (e) {
          print('❌ Sync request batch $batchCount failed: $e');
          sent = false;
        }

        if (!sent) {
          failedBatches.add('batch $batchCount');
          print(
            '⚠️ Failed to send sync request batch $batchCount to $peerName',
          );
          break; // Abandon this peer and move to next
        }

        // Wait for sync acknowledgment first (5 seconds)
        print('⏳ Waiting for sync acknowledgment from $peerName...');

        // Initialize per-peer sync tracking
        final expectedMap = Map<String, int>.from(state.peerSyncExpected);
        final receivedMap = Map<String, int>.from(state.peerSyncReceived);
        expectedMap[peerId] = 0;
        receivedMap[peerId] = 0;

        state = state.copyWith(
          syncAckReceived: false,
          syncExpectedMessages: 0,
          syncReceivedMessages: 0,
          peerSyncExpected: expectedMap,
          peerSyncReceived: receivedMap,
        );
        await Future.delayed(const Duration(seconds: 5));

        if (!state.syncAckReceived) {
          print(
            '⚠️ No sync acknowledgment received from $peerName within 5 seconds',
          );
          failedBatches.add('batch $batchCount (no ack)');
          break;
        }

        // Now wait for messages to arrive, but check periodically if we've received all
        final expectedCount = state.peerSyncExpected[peerId] ?? 0;
        print(
          '⏳ Sync acknowledged, waiting for $expectedCount messages from $peerName...',
        );

        // Poll every 500ms for up to 30 seconds
        bool allReceived = false;
        for (int i = 0; i < 60; i++) {
          await Future.delayed(const Duration(milliseconds: 500));

          final receivedCount = state.peerSyncReceived[peerId] ?? 0;
          if (receivedCount >= expectedCount) {
            print(
              '✅ All $expectedCount messages received after ${(i + 1) * 500}ms',
            );
            allReceived = true;
            break;
          }

          // Log progress every 2 seconds
          if ((i + 1) % 4 == 0) {
            print(
              '📊 Sync progress: $receivedCount/$expectedCount messages received',
            );
          }
        }

        if (!allReceived) {
          final receivedCount = state.peerSyncReceived[peerId] ?? 0;
          print(
            '⚠️ Timeout: Only received $receivedCount/$expectedCount messages after 30 seconds',
          );
        }

        // Clean up per-peer tracking for this sync
        final cleanupExpectedMap = Map<String, int>.from(
          state.peerSyncExpected,
        );
        final cleanupReceivedMap = Map<String, int>.from(
          state.peerSyncReceived,
        );
        cleanupExpectedMap.remove(peerId);
        cleanupReceivedMap.remove(peerId);
        state = state.copyWith(
          peerSyncExpected: cleanupExpectedMap,
          peerSyncReceived: cleanupReceivedMap,
        );

        hasMore = false; // Single batch for now

        print('✅ Batch $batchCount completed');
      }

      // Sync completed
      print(
        '✅ Sync with $peerName completed ($batchCount batches, $messagesReceived messages)',
      );

      if (failedBatches.isEmpty) {
        // Success
        if (!isBackground) {
          // Initial sync - navigate to chat screen will happen in UI
          state = state.copyWith(
            syncInProgress: false,
            currentSyncPeer: null,
            syncProgress: null,
            syncAckReceived: false,
            syncExpectedMessages: 0,
            syncReceivedMessages: 0,
          );
        } else {
          // Background sync - show snackbar
          state = state.copyWith(
            syncInProgress: false,
            currentSyncPeer: null,
            syncProgress: null,
            syncAckReceived: false,
            syncExpectedMessages: 0,
            syncReceivedMessages: 0,
          );
          // Note: Snackbar will be shown in UI layer
        }
      } else {
        // Partial failure
        print('⚠️ Some sync batches failed: ${failedBatches.join(", ")}');
        final updatedFailedPeers = [...state.syncFailedPeers, peerName];
        state = state.copyWith(
          syncInProgress: false,
          currentSyncPeer: null,
          syncProgress: null,
          syncFailedPeers: updatedFailedPeers,
          syncAckReceived: false,
          syncExpectedMessages: 0,
          syncReceivedMessages: 0,
        );
      }
    } catch (e) {
      print('❌ Failed to sync with $peerName: $e');
      final updatedFailedPeers = [...state.syncFailedPeers, peerName];
      state = state.copyWith(
        syncInProgress: false,
        currentSyncPeer: null,
        syncProgress: null,
        syncFailedPeers: updatedFailedPeers,
        syncAckReceived: false,
        syncExpectedMessages: 0,
        syncReceivedMessages: 0,
      );
    }
  }

  /// Handle sync received acknowledgment from a peer
  void _handleSyncReceived(Map<String, dynamic> ack) {
    try {
      final peerAddress = ack['peer_address'] as String;
      final peerId = ack['peer_id'] as String?;
      final messageCount = ack['message_count'] as int? ?? 0;

      print(
        '✅ Peer $peerAddress acknowledged sync request ($messageCount messages to receive)',
      );

      // Update per-peer expected count
      final expectedMap = Map<String, int>.from(state.peerSyncExpected);
      if (peerId != null) {
        expectedMap[peerId] = messageCount;
      }

      state = state.copyWith(
        syncAckReceived: true,
        syncExpectedMessages: messageCount,
        peerSyncExpected: expectedMap,
      );
    } catch (e) {
      print('❌ Failed to handle sync acknowledgment: $e');
    }
  }

  /// Handle sync request from a peer (paginated)
  Future<void> _handleSyncRequest(Map<String, dynamic> request) async {
    try {
      final peerAddress = request['address'] as String;
      final peerPort = request['port'] as int;
      final sinceTimestamp = request['since_timestamp'] as int;
      final requestedRoomId = request['room_id'] as String?;

      print(
        '🔄 Received paginated sync request from $peerAddress:$peerPort (since: $sinceTimestamp, room: $requestedRoomId)',
      );

      final settings = ref.read(settingsProvider);
      final deviceId = settings.deviceId ?? '';
      // Use the room_id from the request, or fall back to active room
      final networkId =
          requestedRoomId ??
          (ref.read(roomProvider).activeRoomId ?? 'default_room');

      // Calculate overlap - get messages from (sinceTimestamp - 5 messages)
      int fromTimestamp = sinceTimestamp;
      if (sinceTimestamp > 0) {
        // Get messages before the requested timestamp to create overlap
        final overlapMessages = await _repository.getMessagesBeforeTimestamp(
          deviceId,
          networkId,
          sinceTimestamp,
          5,
        );
        if (overlapMessages.isNotEmpty) {
          fromTimestamp = overlapMessages.first.timestampMicros;
          print(
            '📊 Adjusted sync start with 5-message overlap: $fromTimestamp',
          );
        }
      }

      // Get messages after fromTimestamp with limit of 100
      final messagesToSync = await _repository
          .getMessagesAfterTimestampPaginated(
            deviceId,
            networkId,
            fromTimestamp,
            100,
          );

      final hasMore = messagesToSync.length == 100;

      print(
        '📤 Sending ${messagesToSync.length} messages for sync (hasMore: $hasMore)',
      );

      if (messagesToSync.isNotEmpty) {
        print(
          '   Timestamp range: ${messagesToSync.first.timestampMicros} to ${messagesToSync.last.timestampMicros}',
        );
      }

      // Send immediate acknowledgment so requester knows we received the sync request
      await _tcpServer.sendSyncReceived(
        peerAddress,
        peerPort,
        messagesToSync.length,
      );

      // Send each message
      for (final message in messagesToSync) {
        await _tcpServer.sendMessage(peerAddress, peerPort, message, networkId);
      }

      // TODO: Send sync_response with hasMore flag
      // In a full implementation, we'd send a sync_response message with:
      // - hasMore: bool
      // - messageCount: int
      // - lastTimestamp: int
      // For now, the peer will determine hasMore by checking if they received 100 messages

      print('✅ Sync batch completed with $peerAddress:$peerPort');
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
      final roomState = ref.read(roomProvider);
      final networkId = roomState.activeRoomId ?? 'default_room';
      final updatedCount = await _repository.updateSenderName(
        deviceId,
        newName,
        networkId,
      );
      print('✅ Updated $updatedCount messages with new name');

      // Reload messages to reflect the change in UI
      await loadInitialMessages();
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
  // Authentication removed - using room-based join requests instead
  /* 
  Future<void> _handleAuthRequest(Map<String, dynamic> request) async {
    // Old auth code removed - see git history if needed
  }

  Future<String> _encryptWithPeerPublicKey(
    String plaintext,
    String peerPublicKeyPem,
  ) async {
    // Old auth code removed - see git history if needed
    throw UnimplementedError('Auth removed');
  }
  */

  /// Send a message to all peers
  Future<void> sendMessage(String content) async {
    final settings = ref.read(settingsProvider);
    final deviceId = settings.deviceId;
    final userName = settings.userName;

    if (deviceId == null || userName == null) {
      state = state.copyWith(error: 'Not configured properly');
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
      final roomState = ref.read(roomProvider);
      final networkId = roomState.activeRoomId ?? 'default_room';
      await _repository.saveMessage(message, deviceId, networkId);

      // Update local state with optimized insertion
      final updatedMessages = [...state.messages];

      // Fast path: check if we can just append (most common case for sent messages)
      if (updatedMessages.isEmpty ||
          updatedMessages.last.timestampMicros <= message.timestampMicros) {
        updatedMessages.add(message);
      } else {
        // Search backwards from the end to find insertion point
        int insertIndex = _findInsertIndexFromEnd(
          updatedMessages,
          message.timestampMicros,
        );
        updatedMessages.insert(insertIndex, message);
      }

      // Evict oldest 25 messages if window exceeds 200
      if (updatedMessages.length > 200) {
        updatedMessages.removeRange(0, 25);
        print(
          '🗑️ Evicted 25 oldest messages (window size: ${updatedMessages.length})',
        );
      }

      // Update timestamps
      final oldestTimestamp = updatedMessages.isNotEmpty
          ? updatedMessages.first.timestampMicros
          : null;
      final newestTimestamp = updatedMessages.isNotEmpty
          ? updatedMessages.last.timestampMicros
          : null;

      state = state.copyWith(
        messages: updatedMessages,
        oldestTimestamp: oldestTimestamp,
        newestTimestamp: newestTimestamp,
      );

      // Send to peers in the same room
      final discoveryState = ref.read(discoveryProvider);
      final allPeers = discoveryState.peers.values;

      // Filter peers who are members of the active room
      final peersInRoom = allPeers.where((peer) {
        return peer.rooms.any((room) => room.roomId == networkId);
      }).toList();

      print(
        '👥 Discovered ${allPeers.length} peer(s), ${peersInRoom.length} in room "$networkId"',
      );

      if (peersInRoom.isEmpty) {
        print('⚠️ No peers in this room to send message to');
      }

      for (final peer in peersInRoom) {
        print(
          '   Sending to ${peer.deviceName} at ${peer.ipAddress}:${peer.tcpPort}',
        );
        await _tcpServer.sendMessage(
          peer.ipAddress,
          peer.tcpPort,
          message,
          networkId,
        );
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
      final roomState = ref.read(roomProvider);
      final networkId = roomState.activeRoomId ?? 'default_room';
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
