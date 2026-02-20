import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/network_constants.dart';
import '../../../messaging/providers/message_provider.dart';
import '../../../discovery/providers/discovery_provider.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../../security/providers/password_provider.dart';
import '../../../security/data/services/security_service.dart';

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
  bool _isInitializing = false;
  int _previousMessageCount = 0;
  String? _lastProposalId;

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

    // Don't start services if not authenticated
    final securityService = SecurityService.instance;
    if (!securityService.hasPassword) {
      print(
        '⚠️ No password set - user not authenticated, skipping service initialization',
      );
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

    // Scroll to bottom after sending
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  Future<void> _showPasswordProposalDialog() async {
    final discoveryState = ref.read(discoveryProvider);
    final passwordController = TextEditingController();

    final newPassword = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🔐 Change Room Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'This requires approval from all ${discoveryState.peers.length + 1} connected peers (including you).',
              style: TextStyle(color: Colors.orange[700], fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(passwordController.text),
            child: const Text('Propose'),
          ),
        ],
      ),
    );

    if (newPassword != null && newPassword.isNotEmpty) {
      await ref
          .read(passwordProvider.notifier)
          .proposePasswordChange(newPassword);
    }
  }

  void _showPasswordVoteDialog(PasswordProposal proposal) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          final currentProposal = ref.watch(passwordProvider).activeProposal;

          // Close dialog if proposal is gone
          if (currentProposal == null || currentProposal.id != proposal.id) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            });
          }

          final activeProposal = currentProposal ?? proposal;

          return AlertDialog(
            title: const Text('🔐 Password Change Request'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${activeProposal.proposerName} wants to change the room password.',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock, size: 20, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'New password: ${activeProposal.newPassword}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'All ${activeProposal.requiredVoteCount} peers must approve.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value:
                      activeProposal.yesVotes /
                      activeProposal.requiredVoteCount,
                  backgroundColor: Colors.grey[300],
                  valueColor: const AlwaysStoppedAnimation(Colors.green),
                ),
                const SizedBox(height: 8),
                Text(
                  '${activeProposal.yesVotes}/${activeProposal.requiredVoteCount} approved',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  ref
                      .read(passwordProvider.notifier)
                      .voteOnProposal(activeProposal.id, false);
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Reject'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  ref
                      .read(passwordProvider.notifier)
                      .voteOnProposal(activeProposal.id, true);
                },
                child: const Text('Approve'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messageState = ref.watch(messageProvider);
    final discoveryState = ref.watch(discoveryProvider);
    final settings = ref.watch(settingsProvider);

    // Listen for password proposals
    ref.listen<PasswordState>(passwordProvider, (previous, next) {
      print('👂 Password state changed');
      print('   Previous proposal: ${previous?.activeProposal?.id}');
      print('   Next proposal: ${next.activeProposal?.id}');
      print('   Last proposal ID: $_lastProposalId');
      print('   Settings deviceId: ${settings.deviceId}');

      // Show proposal dialog for new proposals (not from us)
      if (next.activeProposal != null &&
          next.activeProposal!.id != _lastProposalId &&
          next.activeProposal!.proposerDeviceId != settings.deviceId) {
        print(
          '🔔 Showing password vote dialog for proposal: ${next.activeProposal!.id}',
        );
        _lastProposalId = next.activeProposal!.id;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showPasswordVoteDialog(next.activeProposal!);
        });
      } else if (next.activeProposal != null) {
        print('⚠️ Not showing dialog because:');
        print(
          '   ID matches last? ${next.activeProposal!.id == _lastProposalId}',
        );
        print(
          '   Is from us? ${next.activeProposal!.proposerDeviceId == settings.deviceId}',
        );
      }

      // Clear proposal tracking when proposal is done
      if (next.activeProposal == null && _lastProposalId != null) {
        _lastProposalId = null;
      }

      // Show error messages
      if (next.error != null && next.error != previous?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!), backgroundColor: Colors.red),
        );
        Future.microtask(
          () => ref.read(passwordProvider.notifier).clearError(),
        );
      }

      // Show success messages
      if (next.successMessage != null &&
          next.successMessage != previous?.successMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.successMessage!),
            backgroundColor: Colors.green,
          ),
        );
        Future.microtask(
          () => ref.read(passwordProvider.notifier).clearSuccess(),
        );
      }
    });

    // Auto-scroll when new messages arrive
    if (messageState.messages.length != _previousMessageCount) {
      _previousMessageCount = messageState.messages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }

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
            icon: const Icon(Icons.lock),
            tooltip: 'Change Room Password',
            onPressed: () => _showPasswordProposalDialog(),
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
