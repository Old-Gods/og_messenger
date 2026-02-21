import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/network_constants.dart';
import '../../../../core/utils/color_utils.dart';
import '../../../messaging/providers/message_provider.dart';
import '../../../messaging/providers/color_assignment_provider.dart';
import '../../../discovery/providers/discovery_provider.dart';
import '../../../settings/providers/settings_provider.dart';

/// Main chat screen
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _messageFocusNode = FocusNode();
  bool _isInitialized = false;
  bool _isInitializing = false;
  int _previousMessageCount = 0;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    // Scroll to bottom after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animate = true}) {
    if (!_scrollController.hasClients) return;

    if (animate) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to start messaging server'),
              backgroundColor: Colors.red,
              action: SnackBarAction(
                label: 'Dismiss',
                textColor: Colors.white,
                onPressed: () {},
              ),
            ),
          );
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'UDP discovery failed: ${discoveryState.error ?? "Unknown error"}\n'
                  'Note: iOS Simulator has limited multicast support. Use real devices for full functionality.',
                ),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 8),
                action: SnackBarAction(
                  label: 'Dismiss',
                  textColor: Colors.white,
                  onPressed: () {},
                ),
              ),
            );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting services: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    // Validate message size
    final messageBytes = content.codeUnits.length;
    if (messageBytes > NetworkConstants.maxMessageSizeBytes) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Message too large: ${(messageBytes / 1024).toStringAsFixed(1)}KB (max: ${NetworkConstants.maxMessageSizeBytes / 1024}KB)',
          ),
          action: SnackBarAction(label: 'Dismiss', onPressed: () {}),
        ),
      );
      return;
    }

    _messageController.clear();
    await ref.read(messageProvider.notifier).sendMessage(content);

    // Scroll to bottom after sending
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    // Re-focus the text field so user can immediately type again
    _messageFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final messageState = ref.watch(messageProvider);
    final discoveryState = ref.watch(discoveryProvider);
    final settings = ref.watch(settingsProvider);

    // Auto-scroll when new messages arrive
    if (messageState.messages.length != _previousMessageCount) {
      _previousMessageCount = messageState.messages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('OG Messenger', style: TextStyle(fontSize: 20)),
            Text(
              settings.networkId,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          // Peer count indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Row(
                children: [
                  Icon(
                    Icons.people,
                    size: 20,
                    color: discoveryState.peers.isEmpty
                        ? Colors.grey
                        : Colors.green,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${discoveryState.peers.length}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
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
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.grey[400],
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
                          discoveryState.peers.isEmpty
                              ? 'Waiting for peers to connect...'
                              : 'Start a conversation!',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(8),
                    itemCount: messageState.messages.length,
                    itemBuilder: (context, index) {
                      final message = messageState.messages[index];
                      return _MessageBubble(
                        message: message,
                        isOwn: message.senderId == settings.deviceId,
                      );
                    },
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
