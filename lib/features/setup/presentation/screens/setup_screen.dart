import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../../discovery/data/services/udp_discovery_service.dart';

/// Screen for initial setup - collecting user's display name and password
class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _detectingPeers = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    // Pre-populate name field if user has a saved name
    final settings = ref.read(settingsProvider);
    if (settings.userName != null && settings.userName!.isNotEmpty) {
      _nameController.text = settings.userName!;
    }
  }

  Future<void> _detectPeers() async {
    setState(() {
      _detectingPeers = true;
    });

    try {
      final settings = ref.read(settingsProvider);
      final discoveryService = UdpDiscoveryService();

      // Start discovery temporarily
      await discoveryService.start(
        deviceId: settings.deviceId!,
        deviceName: _nameController.text.trim(),
        tcpPort: 8888, // Temporary port
        listenOnly: true,
      );

      // Wait 8 seconds to discover peers
      await Future.delayed(const Duration(seconds: 8));

      // Stop discovery
      await discoveryService.stop();

      // Complete setup regardless of peers found
      setState(() {
        _detectingPeers = false;
      });
      await _completeSaveName();
    } catch (e) {
      setState(() => _detectingPeers = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to detect peers: $e')));
      }
    }
  }

  Future<void> _completeSaveName() async {
    print('🔧 Completing setup - saving username...');
    await ref
        .read(settingsProvider.notifier)
        .setUserName(_nameController.text.trim(), skipBroadcast: true);

    print('🔧 Username saved, navigating to chat...');

    // Navigate to chat screen after setup is complete
    // Use root navigator and wait a frame to ensure state is updated
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          print('🚀 Attempting navigation to /chat');
          Navigator.of(
            context,
            rootNavigator: true,
          ).pushReplacementNamed('/chat');
        } else {
          print('❌ Widget not mounted, cannot navigate');
        }
      });
    } else {
      print('❌ Widget not mounted before postFrameCallback');
    }
  }

  Future<void> _saveName() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Detect peers first
      await _detectPeers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save name: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.asset(
                    Theme.of(context).brightness == Brightness.dark
                        ? 'images/og_messenger.dark.png'
                        : 'images/og_messenger.png',
                    height: 160,
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Welcome to OG Messenger',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'A serverless LAN messenger for secure local communication',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Your Display Name',
                      hintText: 'Enter your name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _saveName(),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your name';
                      }
                      if (value.trim().length < 2) {
                        return 'Name must be at least 2 characters';
                      }
                      if (value.trim().length > 50) {
                        return 'Name must be less than 50 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: (_isLoading || _detectingPeers)
                        ? null
                        : _saveName,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading || _detectingPeers
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _detectingPeers
                                ? 'Detecting peers...'
                                : 'Get Started',
                          ),
                  ),
                  if (_detectingPeers) ...[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(),
                    const SizedBox(height: 8),
                    Text(
                      'Detecting peers on network...',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
