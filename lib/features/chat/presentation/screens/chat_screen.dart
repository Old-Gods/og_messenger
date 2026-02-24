import 'dart:async';
import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/network_constants.dart';
import '../../../../core/utils/color_utils.dart';
import '../../../../core/utils/dialog_utils.dart';
import '../../../messaging/providers/message_provider.dart';
import '../../../messaging/providers/color_assignment_provider.dart';
import '../../../discovery/providers/discovery_provider.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../../rooms/providers/room_provider.dart';

/// Main chat screen
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with WidgetsBindingObserver {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _messageFocusNode = FocusNode();
  bool _isInitialized = false;
  bool _isInitializing = false;
  int _previousMessageCount = 0;
  DateTime? _lastTypingIndicatorSent;
  Timer? _typingThrottleTimer;
  final Set<String> _shownJoinRequests = {}; // Track which requests we've shown

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
    // Add scroll listener for pagination
    _scrollController.addListener(_onScroll);
    // Scroll to bottom after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    _typingThrottleTimer?.cancel();
    super.dispose();
  }

  void _scrollToBottom({bool animate = true}) {
    if (!_scrollController.hasClients) return;

    // With reverse: true, position 0 is at the bottom (newest messages)
    if (animate) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(0);
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final messageNotifier = ref.read(messageProvider.notifier);
    final messageState = ref.read(messageProvider);

    // Load older messages when scrolling to bottom (top in reverse view)
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100) {
      if (messageState.hasMoreOlder && !messageState.isLoadingMore) {
        messageNotifier.loadOlderMessages();
      }
    }

    // Load newer messages when scrolling to top (bottom in reverse view)
    if (_scrollController.position.pixels <=
        _scrollController.position.minScrollExtent + 100) {
      if (messageState.hasMoreNewer && !messageState.isLoadingNewer) {
        messageNotifier.loadNewerMessages();
      }
    }
  }

  Future<void> _initializeServices() async {
    // Prevent multiple simultaneous initializations
    if (_isInitializing || _isInitialized) {
      print('⚠️ Services already initializing or initialized, skipping...');
      return;
    }

    _isInitializing = true;
    try {
      print('🚀 Starting services initialization...');

      // Start TCP server
      final messageNotifier = ref.read(messageProvider.notifier);
      final serverStarted = await messageNotifier.startServer();

      if (!serverStarted) {
        print('❌ Failed to start TCP server');
        if (mounted) {
          Flushbar(
            message: 'Failed to start messaging server',
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            flushbarPosition: FlushbarPosition.TOP,
            margin: const EdgeInsets.all(8),
            borderRadius: BorderRadius.circular(8),
          ).show(context);
        }
        return;
      }

      final tcpPort = messageNotifier.serverPort;
      print('✅ TCP server started on port: $tcpPort');

      // Start UDP discovery with actual TCP port
      if (tcpPort != null) {
        final discoveryNotifier = ref.read(discoveryProvider.notifier);
        final discoveryStarted = await discoveryNotifier.start(tcpPort);

        if (discoveryStarted) {
          print('✅ UDP discovery started');
        } else {
          print('❌ UDP discovery failed to start');
          final discoveryState = ref.read(discoveryProvider);
          if (discoveryState.error != null) {
            print('   Error: ${discoveryState.error}');
          }
          if (mounted) {
            Flushbar(
              message:
                  'UDP discovery failed: ${discoveryState.error ?? "Unknown error"}\n'
                  'Note: iOS Simulator has limited multicast support. Use real devices for full functionality.',
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 8),
              flushbarPosition: FlushbarPosition.TOP,
              margin: const EdgeInsets.all(8),
              borderRadius: BorderRadius.circular(8),
            ).show(context);
          }
        }
      } else {
        print('❌ No TCP port available for discovery');
      }

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isInitializing = false;
        });
      } else {
        _isInitializing = false;
      }
      print('✅ Services initialized successfully');
    } catch (e, stackTrace) {
      _isInitializing = false;
      print('❌ Error initializing services: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        Flushbar(
          message: 'Error starting services: $e',
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          flushbarPosition: FlushbarPosition.TOP,
          margin: const EdgeInsets.all(8),
          borderRadius: BorderRadius.circular(8),
        ).show(context);
      }
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    // Validate message size
    final messageBytes = content.codeUnits.length;
    if (messageBytes > NetworkConstants.maxMessageSizeBytes) {
      Flushbar(
        message:
            'Message too large: ${(messageBytes / 1024).toStringAsFixed(1)}KB (max: ${NetworkConstants.maxMessageSizeBytes / 1024}KB)',
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 3),
        flushbarPosition: FlushbarPosition.TOP,
        margin: const EdgeInsets.all(8),
        borderRadius: BorderRadius.circular(8),
      ).show(context);
      return;
    }

    _messageController.clear();

    // Reset typing indicator throttle when sending message
    _lastTypingIndicatorSent = null;
    _typingThrottleTimer?.cancel();

    await ref.read(messageProvider.notifier).sendMessage(content);

    // Scroll to bottom after sending
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    // Re-focus the text field so user can immediately type again
    _messageFocusNode.requestFocus();
  }

  void _onTextChanged(String text) {
    // Only send typing indicators if there's text and we have peers
    if (text.isEmpty) return;

    final now = DateTime.now();
    final shouldSend =
        _lastTypingIndicatorSent == null ||
        now.difference(_lastTypingIndicatorSent!) >=
            NetworkConstants.typingThrottleInterval;

    if (shouldSend) {
      _lastTypingIndicatorSent = now;
      ref.read(messageProvider.notifier).sendTypingIndicator();
    }
  }

  /// Show room information dialog with members list and leave option
  void _showRoomInfo(dynamic activeRoom, List<dynamic> onlineMembers) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              activeRoom.roomName,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Created by ${activeRoom.creatorName}',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const Divider(height: 32),
            Text(
              'Online Members (${onlineMembers.length})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (onlineMembers.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No members online',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: onlineMembers.length,
                  itemBuilder: (context, index) {
                    final member = onlineMembers[index];
                    return ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.person, size: 20),
                      ),
                      title: Text(member.deviceName),
                      trailing: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  },
                ),
              ),
            const Divider(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _leaveRoom(activeRoom.roomId);
                },
                icon: const Icon(Icons.exit_to_app),
                label: const Text('Leave Room'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Leave the current room
  void _leaveRoom(String roomId) {
    DialogUtils.showLeaveRoomDialog(
      context: context,
      ref: ref,
      roomId: roomId,
      onLeave: () => Navigator.pushReplacementNamed(context, '/'),
    );
  }

  /// Show join request dialog
  void _showJoinRequestDialog(dynamic request) {
    showDialog(
      context: context,
      barrierDismissible: false, // User must choose
      builder: (dialogContext) => Consumer(
        builder: (context, ref, child) {
          // Watch for changes to pending requests
          final roomState = ref.watch(roomProvider);

          // If request is no longer in pending requests, close dialog
          if (!roomState.pendingRequests.containsKey(request.requestId)) {
            // Close dialog after current frame
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (Navigator.canPop(dialogContext)) {
                Navigator.pop(dialogContext);
              }
            });
            return const SizedBox.shrink();
          }

          return AlertDialog(
            title: const Text('Join Request'),
            content: Text('${request.requesterName} wants to join this room.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  ref
                      .read(roomProvider.notifier)
                      .rejectJoinRequest(request.requestId);
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Reject'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  ref
                      .read(roomProvider.notifier)
                      .acceptJoinRequest(request.requestId);
                  Flushbar(
                    message: '${request.requesterName} has joined the room',
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 2),
                    flushbarPosition: FlushbarPosition.TOP,
                    margin: const EdgeInsets.all(8),
                    borderRadius: BorderRadius.circular(8),
                  ).show(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('Accept'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _buildTypingIndicatorText() {
    final typingPeers = ref.watch(messageProvider).typingPeers;
    final discoveryState = ref.read(discoveryProvider);

    if (typingPeers.isEmpty) return '';

    // Get names of typing peers
    final typingNames = <String>[];
    for (final deviceId in typingPeers.keys) {
      final peer = discoveryState.peers[deviceId];
      if (peer != null) {
        typingNames.add(peer.deviceName);
      }
    }

    if (typingNames.isEmpty) return '';

    // Format the text based on number of typers
    if (typingNames.length == 1) {
      return '${typingNames[0]} is typing';
    } else if (typingNames.length == 2) {
      return '${typingNames[0]} and ${typingNames[1]} are typing';
    } else {
      // Show first 2 names and count of others
      final othersCount =
          typingNames.length - NetworkConstants.typingDisplayLimit;
      return '${typingNames[0]}, ${typingNames[1]} and $othersCount others are typing';
    }
  }

  @override
  Widget build(BuildContext context) {
    final messageState = ref.watch(messageProvider);
    final settings = ref.watch(settingsProvider);
    final roomState = ref.watch(roomProvider);

    // Auto-scroll when new messages arrive, but only in live mode
    if (messageState.messages.length != _previousMessageCount &&
        messageState.isInLiveMode) {
      _previousMessageCount = messageState.messages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }

    // Get active room info
    final activeRoom = roomState.activeRoomId != null
        ? roomState.joinedRooms[roomState.activeRoomId]
        : null;

    // Check for new join requests for the active room
    if (activeRoom != null) {
      for (final request in roomState.pendingRequests.values) {
        if (request.roomId == activeRoom.roomId &&
            !_shownJoinRequests.contains(request.requestId)) {
          _shownJoinRequests.add(request.requestId);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showJoinRequestDialog(request);
          });
        }
      }
    }

    // Get online member count for active room
    final discoveryNotifier = ref.read(discoveryProvider.notifier);
    final onlineMembers = activeRoom != null
        ? discoveryNotifier.getOnlineMembersForRoom(activeRoom.roomId)
        : <dynamic>[];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back to rooms',
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              activeRoom?.roomName ?? 'No Room',
              style: const TextStyle(fontSize: 18),
            ),
            if (activeRoom != null)
              Text(
                'by ${activeRoom.creatorName} • ${onlineMembers.length} online',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        actions: [
          if (activeRoom != null)
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () => _showRoomInfo(activeRoom, onlineMembers),
              tooltip: 'Room info',
            ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).pushNamed('/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Connection status
          if (!_isInitialized)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.orange,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Starting services...',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),

          // Error banner
          if (messageState.error != null)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.red,
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      messageState.error!,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),

          // Messages list
          Expanded(
            child: messageState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : messageState.messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          Theme.of(context).brightness == Brightness.dark
                              ? 'images/og_messenger.dark.png'
                              : 'images/og_messenger.png',
                          width: 128,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          onlineMembers.isEmpty
                              ? 'Waiting for members to come online...'
                              : 'Start a conversation!',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.all(8),
                    itemCount:
                        messageState.messages.length +
                        (messageState.isLoadingMore ? 1 : 0) +
                        (messageState.isLoadingNewer ? 1 : 0),
                    itemBuilder: (context, index) {
                      // Show loading indicator at top (newer messages)
                      if (index == 0 && messageState.isLoadingNewer) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }

                      // Adjust index for loading indicator
                      final messageIndex = messageState.isLoadingNewer
                          ? index - 1
                          : index;

                      // Show loading indicator at bottom (older messages)
                      if (messageIndex >= messageState.messages.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }

                      // Reverse index since we're using reverse: true
                      final reversedIndex =
                          messageState.messages.length - 1 - messageIndex;
                      final message = messageState.messages[reversedIndex];
                      return _MessageBubble(
                        message: message,
                        isOwn: message.senderId == settings.deviceId,
                      );
                    },
                  ),
          ),

          // Typing indicator
          if (_buildTypingIndicatorText().isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                _buildTypingIndicatorText(),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),

          // Message input
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  offset: const Offset(0, -2),
                  blurRadius: 4,
                  color: Colors.black.withValues(alpha: 0.1),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    focusNode: _messageFocusNode,
                    enabled: true,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onChanged: _onTextChanged,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Message bubble widget
class _MessageBubble extends ConsumerWidget {
  final dynamic message;
  final bool isOwn;

  const _MessageBubble({required this.message, required this.isOwn});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get theme brightness
    final brightness = Theme.of(context).brightness;

    // Watch discovery state to check peer connection status
    final discoveryState = ref.watch(discoveryProvider);
    final isConnected = discoveryState.peers.containsKey(message.senderId);

    // Watch the color assignments map
    final colorAssignments = ref.watch(colorAssignmentProvider);

    // Get background color
    final Color backgroundColor;
    if (isOwn) {
      backgroundColor = Colors.blue[700]!;
    } else {
      // Check if color is already assigned
      if (colorAssignments.containsKey(message.senderId)) {
        final assignedColor = colorAssignments[message.senderId]!;
        backgroundColor = ColorUtils.adjustColorForTheme(
          assignedColor,
          brightness,
        );
      } else {
        // Assign color after build completes
        Future(() {
          ref
              .read(colorAssignmentProvider.notifier)
              .getColorForDeviceId(message.senderId);
        });
        // Use temporary color for this frame (will update next frame)
        final tempColor = ColorUtils.materialPalette[0];
        backgroundColor = ColorUtils.adjustColorForTheme(tempColor, brightness);
      }
    }

    // Get contrasting text colors
    final textColor = ColorUtils.getContrastingTextColor(backgroundColor);
    final secondaryTextColor = ColorUtils.getSecondaryTextColor(
      backgroundColor,
    );

    return Align(
      alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(18),
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isOwn)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Darker outline circle
                        Icon(
                          Icons.circle,
                          size: 12,
                          color: isConnected
                              ? Colors.green.shade800
                              : Colors.grey.shade700,
                        ),
                        // Main filled circle
                        Icon(
                          Icons.circle,
                          size: 10,
                          color: isConnected ? Colors.green : Colors.grey,
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      message.senderName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            SelectableText(
              message.content,
              style: TextStyle(color: textColor, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTimestamp(message.timestamp),
              style: TextStyle(color: secondaryTextColor, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }
}
