import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../../../../core/constants/network_constants.dart';
import '../../../../core/services/multicast_lock_service.dart';
import '../../../discovery/domain/entities/peer.dart';
import '../../../security/data/services/security_service.dart';

/// UDP multicast discovery service for finding peers on the LAN
class UdpDiscoveryService {
  RawDatagramSocket? _udpSocket;
  Timer? _beaconTimer;
  Timer? _cleanupTimer;

  final Map<String, Peer> _discoveredPeers = {};
  final StreamController<Map<String, Peer>> _peerController =
      StreamController<Map<String, Peer>>.broadcast();
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();

  bool _isRunning = false;
  String? _deviceId;
  String? _deviceName;
  int? _tcpPort;
  bool _listenOnly = false;

  /// Stream of discovered peers
  Stream<Map<String, Peer>> get peerStream => _peerController.stream;

  /// Stream of errors
  Stream<String> get errorStream => _errorController.stream;

  /// Get current list of discovered peers
  Map<String, Peer> get discoveredPeers => Map.unmodifiable(_discoveredPeers);

  /// Check if service is running
  bool get isRunning => _isRunning;

  /// Start the UDP discovery service
  Future<bool> start({
    required String deviceId,
    required String deviceName,
    required int tcpPort,
    bool listenOnly = false,
  }) async {
    if (_isRunning) {
      print('✅ UDP discovery already running');
      return true; // Already running is success
    }

    _deviceId = deviceId;
    _deviceName = deviceName;
    _tcpPort = tcpPort;
    _listenOnly = listenOnly;

    try {
      print('🔍 Starting UDP discovery...');
      print('   Device ID: $deviceId');
      print('   Device Name: $deviceName');
      print('   TCP Port: $tcpPort');

      // List available network interfaces
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        includeLinkLocal: false,
        type: InternetAddressType.IPv4,
      );
      print('📶 Available network interfaces:');
      NetworkInterface? selectedInterface;
      InternetAddress? selectedAddress;
      NetworkInterface? fallbackInterface;
      InternetAddress? fallbackAddress;

      // First pass: look for preferred WiFi/Ethernet interfaces with LAN IPs
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          print('   ${interface.name}: ${addr.address}');

          // Skip VPN tunnels and other virtual interfaces
          if (interface.name.startsWith('utun') ||
              interface.name.startsWith('ipsec') ||
              interface.name.startsWith('tap') ||
              interface.name.startsWith('tun')) {
            continue;
          }

          // Skip mobile data interfaces (Android)
          if (interface.name.startsWith('rmnet') ||
              interface.name.startsWith('v4-rmnet') ||
              interface.name.startsWith('ccmni')) {
            print('   ⏭️ Skipping mobile data interface: ${interface.name}');
            continue;
          }

          // Prefer WiFi (en0, wlan0) or Ethernet (en1, eth0) interfaces
          // And prefer 192.168.x.x or 10.x.x.x networks (common LAN ranges)
          final ip = addr.address;
          if ((interface.name == 'en0' ||
                  interface.name == 'en1' ||
                  interface.name == 'wlan0' ||
                  interface.name == 'eth0') &&
              (ip.startsWith('192.168.') ||
                  ip.startsWith('10.') ||
                  ip.startsWith('172.'))) {
            selectedInterface = interface;
            selectedAddress = addr;
            break;
          }

          // Store first non-VPN, non-mobile interface as fallback
          if (fallbackInterface == null) {
            fallbackInterface = interface;
            fallbackAddress = addr;
          }
        }
        if (selectedInterface != null && selectedAddress != null) break;
      }

      // Use fallback only if no preferred interface found
      if (selectedInterface == null &&
          fallbackInterface != null &&
          fallbackAddress != null) {
        selectedInterface = fallbackInterface;
        selectedAddress = fallbackAddress;
      }

      if (selectedInterface != null && selectedAddress != null) {
        print(
          '✅ Selected interface: ${selectedInterface.name} (${selectedAddress.address})',
        );
      } else {
        print('❌ No suitable WiFi/Ethernet interface found');
        _errorController.add(
          'WiFi network required. Please connect to WiFi to use OG Messenger.',
        );
        return false;
      }

      // Acquire multicast lock on Android
      await MulticastLockService.instance.acquireLock();
      print('✅ Multicast lock acquired');

      // Bind to INADDR_ANY to receive multicast
      _udpSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        NetworkConstants.multicastPort,
        reuseAddress: true,
        reusePort: Platform.isMacOS || Platform.isWindows || Platform.isLinux,
      );
      print('✅ UDP socket bound to 0.0.0.0:${NetworkConstants.multicastPort}');

      // Join multicast group on specific interface
      final multicastAddress = InternetAddress(
        NetworkConstants.multicastAddress,
      );
      _udpSocket!.joinMulticast(multicastAddress, selectedInterface);
      print(
        '✅ Joined multicast group ${NetworkConstants.multicastAddress} on interface ${selectedInterface.name}',
      );

      // Configure multicast settings
      _udpSocket!.multicastLoopback = true; // Enable to help with debugging
      _udpSocket!.multicastHops = 2; // TTL for multicast packets
      _udpSocket!.broadcastEnabled = true;
      print('✅ Multicast configured (TTL=2, loopback=true)');

      // Listen for incoming beacons
      _udpSocket!.listen(
        _handleRawDatagram,
        onError: (error) => _errorController.add('UDP error: $error'),
      );

      // Start broadcasting beacons (unless in listen-only mode)
      if (!_listenOnly) {
        _beaconTimer = Timer.periodic(
          NetworkConstants.discoveryBeaconInterval,
          (_) => _broadcastBeacon(),
        );
      }

      // Start peer cleanup timer
      _cleanupTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _cleanupExpiredPeers(),
      );

      _isRunning = true;

      // Send initial beacon immediately (unless in listen-only mode)
      if (!_listenOnly) {
        _broadcastBeacon();
      }

      return true;
    } catch (e, stackTrace) {
      print('❌ UDP Discovery error: $e');
      print('Stack trace: $stackTrace');
      _errorController.add('Failed to start UDP discovery: $e');
      await stop();
      return false;
    }
  }

  /// Broadcast discovery beacon
  void _broadcastBeacon() {
    if (!_isRunning ||
        _udpSocket == null ||
        _deviceId == null ||
        _deviceName == null ||
        _tcpPort == null) {
      print('⚠️ Cannot broadcast beacon - service not ready');
      return;
    }

    try {
      final securityService = SecurityService.instance;
      final beacon = Peer(
        deviceId: _deviceId!,
        deviceName: _deviceName!,
        ipAddress: '', // Will be filled by receiver
        tcpPort: _tcpPort!,
        lastSeen: DateTime.now(),
        publicKey: securityService.publicKeyPem,
        isAuthenticated: securityService.isAuthenticated,
      );

      final beaconJson = jsonEncode(beacon.toJson());
      final beaconBytes = utf8.encode(beaconJson);

      _udpSocket!.send(
        beaconBytes,
        InternetAddress(NetworkConstants.multicastAddress),
        NetworkConstants.multicastPort,
      );
    } catch (e) {
      print('❌ Failed to broadcast beacon: $e');
      _errorController.add('Failed to broadcast beacon: $e');
    }
  }

  /// Handle incoming datagram from RawDatagramSocket
  void _handleRawDatagram(RawSocketEvent event) {
    if (event == RawSocketEvent.read) {
      final datagram = _udpSocket?.receive();
      if (datagram != null) {
        _handleBeacon(datagram);
      }
    }
  }

  /// Handle incoming beacon from peer
  void _handleBeacon(Datagram datagram) {
    try {
      final message = utf8.decode(datagram.data);
      final json = jsonDecode(message) as Map<String, dynamic>;
      final peer = Peer.fromJson(json);

      // Don't add ourselves
      if (peer.deviceId == _deviceId) return;

      print(
        '📡 Discovered peer: ${peer.deviceName} at ${datagram.address.address}:${peer.tcpPort}',
      );

      // Update peer with actual IP address
      final updatedPeer = Peer(
        deviceId: peer.deviceId,
        deviceName: peer.deviceName,
        ipAddress: datagram.address.address,
        tcpPort: peer.tcpPort,
        lastSeen: DateTime.now(),
        publicKey: peer.publicKey,
        isAuthenticated: peer.isAuthenticated,
      );

      // Add or update peer
      _discoveredPeers[peer.deviceId] = updatedPeer;

      // Notify listeners
      _peerController.add(Map.unmodifiable(_discoveredPeers));
    } catch (e) {
      _errorController.add('Failed to parse beacon: $e');
    }
  }

  /// Clean up peers that haven't been seen recently
  void _cleanupExpiredPeers() {
    final now = DateTime.now();
    final peersToRemove = <String>[];

    for (final entry in _discoveredPeers.entries) {
      final timeSinceLastSeen = now.difference(entry.value.lastSeen);
      if (timeSinceLastSeen > NetworkConstants.peerTimeout) {
        peersToRemove.add(entry.key);
      }
    }

    if (peersToRemove.isNotEmpty) {
      for (final peerId in peersToRemove) {
        _discoveredPeers.remove(peerId);
      }
      _peerController.add(Map.unmodifiable(_discoveredPeers));
    }
  }

  /// Update device name (for settings changes)
  void updateDeviceName(String newName) {
    _deviceName = newName;
    if (_isRunning) {
      _broadcastBeacon();
    }
  }

  /// Get a specific peer by device ID
  Peer? getPeer(String deviceId) {
    return _discoveredPeers[deviceId];
  }

  /// Stop the UDP discovery service
  Future<void> stop() async {
    if (!_isRunning) return;

    _isRunning = false;

    // Stop timers
    _beaconTimer?.cancel();
    _beaconTimer = null;

    _cleanupTimer?.cancel();
    _cleanupTimer = null;

    // Close UDP socket
    _udpSocket?.close();
    _udpSocket = null;

    // Release multicast lock
    await MulticastLockService.instance.releaseLock();

    // Clear peers
    _discoveredPeers.clear();
    _peerController.add({});
  }

  /// Dispose resources
  void dispose() {
    stop();
    _peerController.close();
    _errorController.close();
  }
}
