import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/network_constants.dart';
import '../../../messaging/providers/message_provider.dart';
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
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    try {
      print('🚀 Starting services initialization...');

      // Start TCP server
      final messageNotifier = ref.read(messageProvider.notifier);
      final serverStarted = await messageNotifier.startServer();

      if (!serverStarted) {
        print('❌ Failed to start TCP server');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to start messaging server'),
              backgroundColor: Colors.red,
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
              ),
            );
          }
        }
      } else {
        print('❌ No TCP port available for discovery');
      }

      if (mounted) {
        setState(() => _isInitialized = true);
      }
      print('✅ Services initialized successfully');
    } catch (e, stackTrace) {
      print('❌ Error initializing services: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting services: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
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
        ),
      );
      return;
    }

    _messageController.clear();
    await ref.read(messageProvider.notifier).sendMessage(content);

    // Scroll to bottom
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final messageState = ref.watch(messageProvider);
    final discoveryState = ref.watch(discoveryProvider);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('OG Messenger'),
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
                  color: Theme.of(context).primaryColor,
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
class _MessageBubble extends StatelessWidget {
  final dynamic message;
  final bool isOwn;

  const _MessageBubble({required this.message, required this.isOwn});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: isOwn ? Colors.blue[700] : Colors.grey[300],
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
                child: Text(
                  message.senderName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isOwn ? Colors.white70 : Colors.black87,
                    fontSize: 12,
                  ),
                ),
              ),
            Text(
              message.content,
              style: TextStyle(
                color: isOwn ? Colors.white : Colors.black87,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTimestamp(message.timestamp),
              style: TextStyle(
                color: isOwn ? Colors.white70 : Colors.black54,
                fontSize: 10,
              ),
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
