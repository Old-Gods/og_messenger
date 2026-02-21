import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pointycastle/export.dart' as pc;
import 'package:asn1lib/asn1lib.dart' as asn1;
import '../../../settings/providers/settings_provider.dart';
import '../../../discovery/data/services/udp_discovery_service.dart';
import '../../../discovery/domain/entities/peer.dart';
import '../../../security/data/services/security_service.dart';
import '../../../messaging/data/services/tcp_server_service.dart';

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
  StreamSubscription? _authResponseSubscription;
  Timer? _authTimeoutTimer;
  List<Peer> _discoveredPeers = [];
  final Map<String, int> _authAttempts = {}; // Track auth attempts per peer
  final Map<String, DateTime> _authLockouts = {}; // Track lockout times

  @override
  void dispose() {
    _nameController.dispose();
    _authResponseSubscription?.cancel();
    _authTimeoutTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    // Pre-populate name field if user has a saved name and check auth
    // Delayed to next frame to ensure widget tree is built and ref is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final settings = ref.read(settingsProvider);
        if (settings.userName != null && settings.userName!.isNotEmpty) {
          _nameController.text = settings.userName!;
        }
      }
    });

    // Check if already authenticated and skip to chat
    _checkExistingAuth();
  }

  Future<void> _checkExistingAuth() async {
    final securityService = SecurityService.instance;
    if (securityService.isAuthenticated) {
      print('🔐 Already authenticated, skipping to chat');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(
            context,
            rootNavigator: true,
          ).pushReplacementNamed('/chat');
        }
      });
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
        listenOnly: false, // Broadcast so other devices can see us
      );

      // Wait 15 seconds to discover peers (increased to handle separate starts)
      await Future.delayed(const Duration(seconds: 15));

      // Get discovered peers
      _discoveredPeers = discoveryService.discoveredPeers.values.toList();

      // Stop discovery
      await discoveryService.stop();

      setState(() {
        _detectingPeers = false;
      });

      // Check if peers were found
      if (_discoveredPeers.isEmpty) {
        // No peers found - first user flow
        print('👤 No peers found - setting up as first user');
        await _showPasswordCreationDialog();
      } else {
        // Peers found - check if any are authenticated with public keys
        final authenticatedPeers = _discoveredPeers
            .where((p) => p.isAuthenticated && p.publicKey != null)
            .toList();

        // Also check for unauthenticated peers (split-brain scenario)
        final unauthenticatedPeers = _discoveredPeers
            .where((p) => !p.isAuthenticated)
            .toList();

        if (authenticatedPeers.isEmpty && unauthenticatedPeers.isNotEmpty) {
          // Split-brain scenario: Multiple devices starting simultaneously
          // Use device ID tie-breaking: lowest device ID becomes first user
          print(
            '⚠️ Split-brain detected: ${unauthenticatedPeers.length + 1} devices starting simultaneously',
          );

          final settings = ref.read(settingsProvider);
          final myDeviceId = settings.deviceId ?? '';
          final allDeviceIds = [
            myDeviceId,
            ...unauthenticatedPeers.map((p) => p.deviceId),
          ];
          allDeviceIds.sort();

          if (allDeviceIds.first == myDeviceId) {
            print(
              '🎲 Tie-breaker: I have the lowest device ID, becoming first user',
            );
            await _showPasswordCreationDialog();
          } else {
            print(
              '🎲 Tie-breaker: Waiting for device ${allDeviceIds.first} to initialize...',
            );
            // Wait and re-detect with longer timeout
            await Future.delayed(const Duration(seconds: 5));
            await _detectPeers();
          }
        } else if (authenticatedPeers.isEmpty) {
          // Found unauthenticated peers but none authenticated yet
          // Wait for one to finish setup, then retry
          print(
            '⏳ Found unauthenticated peers, waiting for one to complete setup...',
          );
          await Future.delayed(const Duration(seconds: 5));
          await _detectPeers();
        } else {
          // Found authenticated peers - subsequent user flow
          print('👥 Found ${authenticatedPeers.length} authenticated peer(s)');
          await _showPasswordEntryDialog(authenticatedPeers.first);
        }
      }
    } catch (e) {
      setState(() => _detectingPeers = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to detect peers: $e'),
            action: SnackBarAction(label: 'Dismiss', onPressed: () {}),
          ),
        );
      }
    }
  }

  Future<void> _showPasswordCreationDialog() async {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Create Room Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'You are the first user. Create a password for this chat room.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmController,
              decoration: const InputDecoration(
                labelText: 'Confirm Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final password = passwordController.text;
              final confirm = confirmController.text;

              if (password.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Password cannot be empty'),
                    action: SnackBarAction(label: 'Dismiss', onPressed: () {}),
                  ),
                );
                return;
              }

              if (password != confirm) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Passwords do not match'),
                    action: SnackBarAction(label: 'Dismiss', onPressed: () {}),
                  ),
                );
                return;
              }

              Navigator.of(context).pop(password);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      await _setupFirstUser(result);
    }
  }

  Future<void> _setupFirstUser(String password) async {
    try {
      print('🔧 Setting up first user...');
      final securityService = SecurityService.instance;

      // Clear any old auth data
      await securityService.clearSecurityData();

      // Generate RSA key pair
      print('🔑 Generating RSA key pair...');
      await securityService.generateKeyPair();

      // Generate AES key for messages
      print('🔐 Generating AES key...');
      await securityService.generateAesKey();

      // Store password (both plain and hash)
      print('💾 Storing password...');
      await securityService.setPasswordHash(
        securityService.hashPassword(password),
      );

      // Mark as room creator
      print('👑 Marking as room creator...');
      await securityService.setIsRoomCreator(true);

      print('✅ First user setup complete!');

      await _completeSaveName();
    } catch (e) {
      print('❌ Failed to setup first user: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to setup: $e'),
            action: SnackBarAction(label: 'Dismiss', onPressed: () {}),
          ),
        );
      }
    }
  }

  Future<void> _showPasswordEntryDialog(Peer peer) async {
    final passwordController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Enter Room Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter the password to join the chat room with ${peer.deviceName}.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final password = passwordController.text;
              if (password.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Password cannot be empty'),
                    action: SnackBarAction(label: 'Dismiss', onPressed: () {}),
                  ),
                );
                return;
              }
              Navigator.of(context).pop(password);
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      await _authenticateWithPeer(result, peer);
    }
  }

  Future<void> _authenticateWithPeer(String password, Peer peer) async {
    try {
      // Check rate limit
      final peerKey = peer.deviceId;
      final lockoutTime = _authLockouts[peerKey];

      if (lockoutTime != null) {
        final timeSinceLockout = DateTime.now().difference(lockoutTime);
        if (timeSinceLockout.inMinutes < 5) {
          final remainingMinutes = 5 - timeSinceLockout.inMinutes;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Please wait $remainingMinutes more minute(s) before trying again.',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        } else {
          // Lockout expired, clear it
          _authLockouts.remove(peerKey);
          _authAttempts.remove(peerKey);
        }
      }

      print('🔐 Authenticating with peer ${peer.deviceName}...');
      final settings = ref.read(settingsProvider);
      final securityService = SecurityService.instance;
      final tcpServer = TcpServerService.instance;

      // Start TCP server to receive auth response
      if (!tcpServer.isRunning) {
        print('🚀 Starting TCP server...');
        final started = await tcpServer.start();
        if (!started) {
          throw Exception('Failed to start TCP server');
        }
        print('✅ TCP server started on port ${tcpServer.actualPort}');
      }

      // Generate our own RSA key pair
      print('🔑 Generating RSA key pair...');
      await securityService.generateKeyPair();

      // Hash the entered password
      final passwordHash = securityService.hashPassword(password);
      print('🔒 Password hashed');

      // Encrypt password hash with peer's public key
      print('🔐 Encrypting password hash with peer\'s public key...');
      final encryptedPasswordHash = _encryptWithPeerPublicKey(
        passwordHash,
        peer.publicKey!,
        securityService,
      );

      // Listen for auth response
      _authResponseSubscription = tcpServer.authResponseStream.listen((
        response,
      ) {
        _handleAuthResponse(response, password);
      });

      // Send auth request to peer
      print('📤 Sending auth request to ${peer.ipAddress}:${peer.tcpPort}');
      final success = await tcpServer.sendAuthRequest(
        peerAddress: peer.ipAddress,
        peerPort: peer.tcpPort,
        deviceId: settings.deviceId!,
        deviceName: _nameController.text.trim(),
        encryptedPasswordHash: encryptedPasswordHash,
        publicKey: securityService.publicKeyPem!,
        tcpPort: tcpServer.actualPort ?? 8888,
      );

      if (!success) {
        throw Exception('Failed to send auth request');
      }

      print('✅ Auth request sent, waiting for response...');

      // Set up 30-second timeout
      final timeoutTimer = Timer(const Duration(seconds: 30), () {
        if (mounted) {
          _authResponseSubscription?.cancel();
          Navigator.of(
            context,
            rootNavigator: true,
          ).pop(); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Authentication timed out. Please try again.',
              ),
              backgroundColor: Colors.orange,
              action: SnackBarAction(
                label: 'Dismiss',
                textColor: Colors.white,
                onPressed: () {},
              ),
            ),
          );
        }
      });

      // Store timer for cleanup
      _authTimeoutTimer = timeoutTimer;

      // Show loading dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text('Authenticating...'),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      print('❌ Authentication failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Authentication failed: $e'),
            action: SnackBarAction(label: 'Dismiss', onPressed: () {}),
          ),
        );
      }
    }
  }

  void _handleAuthResponse(
    Map<String, dynamic> response,
    String password,
  ) async {
    // Cancel timeout timer
    _authTimeoutTimer?.cancel();
    _authTimeoutTimer = null;

    // Cancel auth response subscription
    _authResponseSubscription?.cancel();
    _authResponseSubscription = null;

    // Close loading dialog
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    final success = response['success'] as bool;

    if (!success) {
      final message = response['message'] as String? ?? 'Authentication failed';
      print('❌ Auth failed: $message');

      // Track failed attempts for rate limiting
      final peerKey = _discoveredPeers.isNotEmpty
          ? _discoveredPeers.first.deviceId
          : 'unknown';
      _authAttempts[peerKey] = (_authAttempts[peerKey] ?? 0) + 1;

      // Check if rate limit exceeded (10 attempts)
      if (_authAttempts[peerKey]! >= 10) {
        _authLockouts[peerKey] = DateTime.now();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Too many failed attempts. Please wait 5 minutes.',
              ),
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
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$message (${_authAttempts[peerKey]}/10 attempts)'),
            backgroundColor: Colors.orange,
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

    try {
      print('✅ Authentication successful!');
      final encryptedAesKey = response['encrypted_aes_key'] as String?;

      if (encryptedAesKey == null) {
        throw Exception('No AES key received');
      }

      // Decrypt AES key with our private key
      print('🔓 Decrypting AES key...');
      final securityService = SecurityService.instance;
      final decryptedAesKeyBase64 = securityService.decryptWithPrivateKey(
        encryptedAesKey,
      );
      final aesKey = base64Decode(decryptedAesKeyBase64);

      // Store AES key
      print('💾 Storing AES key...');
      await securityService.setAesKey(aesKey);

      // Store password
      print('💾 Storing password...');
      await securityService.setPasswordHash(
        securityService.hashPassword(password),
      );

      // Mark as not room creator
      await securityService.setIsRoomCreator(false);

      print('✅ Authentication complete!');

      await _completeSaveName();
    } catch (e) {
      print('❌ Failed to process auth response: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process authentication: $e'),
            action: SnackBarAction(label: 'Dismiss', onPressed: () {}),
          ),
        );
      }
    } finally {
      _authResponseSubscription?.cancel();
    }
  }

  String _encryptWithPeerPublicKey(
    String plaintext,
    String peerPublicKeyPem,
    SecurityService securityService,
  ) {
    // Parse peer's public key from PEM format
    final base64String = peerPublicKeyPem.replaceAll('PUBLIC:', '');
    final bytes = base64Decode(base64String);
    final asn1Parser = asn1.ASN1Parser(bytes);
    final seq = asn1Parser.nextObject() as asn1.ASN1Sequence;

    final peerPublicKey = pc.RSAPublicKey(
      (seq.elements[0] as asn1.ASN1Integer).valueAsBigInteger, // modulus
      (seq.elements[1] as asn1.ASN1Integer).valueAsBigInteger, // exponent
    );

    // Encrypt with peer's public key
    return securityService.encryptWithPublicKey(plaintext, peerPublicKey);
  }

  Future<void> _completeSaveName() async {
    print('🔧 Completing setup - saving username...');
    await ref
        .read(settingsProvider.notifier)
        .setUserName(_nameController.text.trim(), skipBroadcast: true);

    print('🔧 Username saved, navigating to chat...');

    // Navigate to chat screen after setup is complete
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          print('🚀 Navigating to /chat');
          Navigator.of(
            context,
            rootNavigator: true,
          ).pushReplacementNamed('/chat');
        }
      });
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save name: $e'),
            action: SnackBarAction(label: 'Dismiss', onPressed: () {}),
          ),
        );
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
                        : const Text('Get Started'),
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
