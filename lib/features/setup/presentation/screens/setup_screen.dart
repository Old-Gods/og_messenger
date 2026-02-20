import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../../security/data/services/security_service.dart';
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
  String? _detectedPasswordHash;
  String? _detectedEncryptedKey;
  String? _detectedSalt;
  int _failedAttempts = 0;
  int _lockoutSeconds = 0;
  Timer? _lockoutTimer;

  @override
  void dispose() {
    _nameController.dispose();
    _lockoutTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Check lockout status on init
    final securityService = SecurityService.instance;
    if (securityService.isLockedOut) {
      _lockoutSeconds = securityService.lockoutRemainingSeconds;
      _startLockoutTimer();
    }
    _failedAttempts = securityService.failedAttempts;
  }

  void _startLockoutTimer() {
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_lockoutSeconds > 0) {
        setState(() => _lockoutSeconds--);
      } else {
        timer.cancel();
        _lockoutTimer = null;
      }
    });
  }

  Future<void> _detectPeers() async {
    setState(() {
      _detectingPeers = true;
    });

    try {
      final settings = ref.read(settingsProvider);
      final discoveryService = UdpDiscoveryService();

      // Start discovery temporarily (listen-only mode to avoid broadcasting unauthenticated)
      await discoveryService.start(
        deviceId: settings.deviceId!,
        deviceName: _nameController.text.trim(),
        tcpPort: 8888, // Temporary port
        listenOnly: true, // Don't broadcast while unauthenticated
      );

      // Wait 8 seconds to discover peers
      await Future.delayed(const Duration(seconds: 8));

      final peers = discoveryService.discoveredPeers;

      // Stop discovery
      await discoveryService.stop();

      if (peers.isEmpty) {
        // First peer - needs to create password
        setState(() {
          _detectingPeers = false;
        });
        _showPasswordCreationDialog();
      } else {
        // Subsequent peer - needs to enter password
        final firstPeer = peers.values.first;
        setState(() {
          _detectedPasswordHash = firstPeer.passwordHash;
          _detectedEncryptedKey = firstPeer.encryptedKey;
          _detectedSalt =
              firstPeer.deviceId; // Use first peer's device ID as salt
          _detectingPeers = false;
        });
        _showPasswordEntryDialog();
      }
    } catch (e) {
      setState(() => _detectingPeers = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to detect peers: $e')));
      }
    }
  }

  Future<void> _showPasswordCreationDialog() async {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();

    final password = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🔐 Create Room Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'You are the first peer on this network. Create a password to secure the room.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm Password',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline),
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
            onPressed: () {
              final pwd = passwordController.text;
              final confirm = confirmController.text;

              if (pwd.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password cannot be empty')),
                );
                return;
              }

              if (pwd != confirm) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Passwords do not match')),
                );
                return;
              }

              Navigator.of(context).pop(pwd);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (password != null && password.isNotEmpty) {
      await _setupRoomCreator(password);
    }
  }

  Future<void> _setupRoomCreator(String password) async {
    try {
      final securityService = SecurityService.instance;
      final settings = ref.read(settingsProvider);

      // Hash password
      final passwordHash = securityService.hashPassword(password);

      // Generate random AES encryption key
      final encryptionKey = securityService.generateRandomKey();

      // Encrypt the AES key with the password for broadcasting
      print('🔑 Encrypting key for broadcasting...');
      print('   Device ID (salt): ${settings.deviceId}');
      print('   Password length: ${password.length}');

      final encryptedKey = securityService.encryptKeyWithPassword(
        encryptionKey,
        password,
        settings.deviceId!, // Use device ID as salt
      );

      print('   Encrypted key: $encryptedKey');

      // Store credentials
      await securityService.setPasswordHash(passwordHash);
      await securityService.setEncryptionKey(encryptionKey);
      await securityService.setEncryptedKey(
        encryptedKey,
      ); // Store encrypted version
      await securityService.setIsRoomCreator(true);
      await securityService.setRoomCreatedTimestamp(
        DateTime.now().millisecondsSinceEpoch,
      );

      // Save name and complete setup
      await _completeSaveName();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to create room: $e')));
      }
    }
  }

  Future<void> _showPasswordEntryDialog() async {
    final securityService = SecurityService.instance;

    // Check if locked out
    if (securityService.isLockedOut) {
      _lockoutSeconds = securityService.lockoutRemainingSeconds;
      _startLockoutTimer();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Too many failed attempts. Locked out for ${_lockoutSeconds ~/ 60}:${(_lockoutSeconds % 60).toString().padLeft(2, '0')}',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    final passwordController = TextEditingController();

    final password = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('🔐 Enter Room Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'This room is password protected. Enter the password to join.',
                style: TextStyle(fontSize: 14),
              ),
              if (_failedAttempts > 0) ...[
                const SizedBox(height: 8),
                Text(
                  'Failed attempts: $_failedAttempts/5',
                  style: TextStyle(color: Colors.orange[700], fontSize: 12),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
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
              onPressed: () =>
                  Navigator.of(context).pop(passwordController.text),
              child: const Text('Join'),
            ),
          ],
        ),
      ),
    );

    if (password != null && password.isNotEmpty) {
      await _verifyAndJoinRoom(password);
    }
  }

  Future<void> _verifyAndJoinRoom(String password) async {
    try {
      final securityService = SecurityService.instance;

      // Hash entered password
      final enteredHash = securityService.hashPassword(password);

      // Verify against detected hash
      if (enteredHash != _detectedPasswordHash) {
        // Wrong password
        await securityService.incrementFailedAttempts();
        setState(() => _failedAttempts = securityService.failedAttempts);

        if (securityService.isLockedOut) {
          _lockoutSeconds = securityService.lockoutRemainingSeconds;
          _startLockoutTimer();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Too many failed attempts. Locked out for 5 minutes.',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Incorrect password'),
                backgroundColor: Colors.red,
              ),
            );
          }
          // Show dialog again
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) _showPasswordEntryDialog();
          });
        }
        return;
      }

      // Correct password - decrypt encryption key
      if (_detectedEncryptedKey != null && _detectedSalt != null) {
        print('🔑 Attempting to decrypt key...');
        print('   Encrypted key: $_detectedEncryptedKey');
        print('   Salt (device ID): $_detectedSalt');
        print('   Password length: ${password.length}');

        final decryptedKey = securityService.decryptKeyWithPassword(
          _detectedEncryptedKey!,
          password,
          _detectedSalt!,
        );

        if (decryptedKey != null) {
          print('✅ Successfully decrypted encryption key');

          // Store credentials
          await securityService.setPasswordHash(enteredHash);
          await securityService.setEncryptionKey(decryptedKey);
          await securityService.setEncryptedKey(
            _detectedEncryptedKey!,
          ); // Store encrypted version too
          await securityService.setIsRoomCreator(false);
          await securityService.resetFailedAttempts();

          print('✅ Credentials stored, completing setup...');

          // Save name and complete setup
          await _completeSaveName();
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to decrypt encryption key')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to join room: $e')));
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
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
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
                            onPressed:
                                (_isLoading ||
                                    _detectingPeers ||
                                    _lockoutSeconds > 0)
                                ? null
                                : _saveName,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: _isLoading || _detectingPeers
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : _lockoutSeconds > 0
                                ? Text(
                                    'Locked: ${_lockoutSeconds ~/ 60}:${(_lockoutSeconds % 60).toString().padLeft(2, '0')}',
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
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
