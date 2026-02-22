import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../messaging/providers/message_provider.dart';
import '../../../discovery/providers/discovery_provider.dart';

/// Screen shown during initial message sync with peers
class SyncScreen extends ConsumerStatefulWidget {
  const SyncScreen({super.key});

  @override
  ConsumerState<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends ConsumerState<SyncScreen> {
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    print('🔧 Sync screen: initState called');

    // Start discovery to find peers for syncing
    // Setup may have stopped discovery after authentication
    _ensureDiscoveryRunning();

    // Wait for peers to be discovered and sync to start
    // Give discovery time to find peers (beacon interval is 2s, so 6s = 3 beacons)
    Future.delayed(const Duration(seconds: 6), () {
      if (mounted && !_hasNavigated) {
        print('⏰ Sync screen: 6 second timeout reached');
        _checkIfShouldNavigate();
      }
    });
  }

  Future<void> _ensureDiscoveryRunning() async {
    try {
      final discoveryState = ref.read(discoveryProvider);

      if (!discoveryState.isRunning) {
        print('🔧 Sync screen: Discovery not running, starting it...');
        final tcpPort = 8888; // Standard port
        await ref.read(discoveryProvider.notifier).start(tcpPort);
        print('✅ Sync screen: Discovery started');
      } else {
        print('✅ Sync screen: Discovery already running');
      }
    } catch (e) {
      print('⚠️ Sync screen: Failed to start discovery: $e');
    }
  }

  void _checkIfShouldNavigate() {
    if (!mounted || _hasNavigated) return;

    final messageState = ref.read(messageProvider);
    final discoveryState = ref.read(discoveryProvider);

    print(
      '🔍 Sync screen check: peers=${discoveryState.peers.length}, syncInProgress=${messageState.syncInProgress}, syncAckReceived=${messageState.syncAckReceived}',
    );

    // If no peers discovered and not syncing, go to chat
    if (discoveryState.peers.isEmpty && !messageState.syncInProgress) {
      print(
        '📭 No peers discovered and no sync in progress, navigating to chat screen',
      );
      _navigateToChat();
    } else {
      print('⏳ Peers or sync detected, staying on sync screen');
    }
  }

  void _navigateToChat() {
    if (!mounted || _hasNavigated) return;
    print('🚀 Sync screen: Navigating to chat');
    _hasNavigated = true;
    Navigator.of(context).pushReplacementNamed('/chat');
  }

  void _onSyncComplete() {
    if (!mounted || _hasNavigated) return;

    print('✅ Sync screen: Sync completed, processing...');

    final messageState = ref.read(messageProvider);

    if (messageState.syncFailedPeers.isEmpty) {
      // Sync successful - navigate to chat
      print('✅ Sync completed successfully, navigating to chat screen');
      _navigateToChat();
    } else {
      // Sync failed - show warning dialog
      print('⚠️ Sync completed with failures, showing warning dialog');
      _showSyncFailureDialog();
    }
  }

  void _showSyncFailureDialog() {
    if (_hasNavigated) return;

    final failedPeers = ref.read(messageProvider).syncFailedPeers;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Sync Warning'),
        content: Text(
          'Failed to sync with ${failedPeers.join(", ")}. '
          'Some messages may be missing. Continue anyway?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _navigateToChat();
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print('🔧 Sync screen: build() called');

    ref.listen<MessageState>(messageProvider, (previous, next) {
      print(
        '🔧 Sync screen: messageProvider changed - syncInProgress: ${previous?.syncInProgress} → ${next.syncInProgress}',
      );
      // Only react to sync completion (transition from syncing to not syncing)
      if (previous?.syncInProgress == true && !next.syncInProgress) {
        _onSyncComplete();
      }
    });

    final messageState = ref.watch(messageProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              messageState.syncInProgress
                  ? (messageState.syncAckReceived
                        ? 'Syncing messages...'
                        : 'Waiting for peer response...')
                  : 'Connecting to peers...',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (messageState.currentSyncPeer != null)
              Text(
                messageState.currentSyncPeer!,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              ),
          ],
        ),
      ),
    );
  }
}
