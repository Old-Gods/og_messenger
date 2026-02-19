import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../settings/providers/settings_provider.dart';
import '../domain/entities/peer.dart';
import '../data/services/udp_discovery_service.dart';

/// Discovery state
class DiscoveryState {
  final Map<String, Peer> peers;
  final bool isRunning;
  final String? error;

  const DiscoveryState({
    this.peers = const {},
    this.isRunning = false,
    this.error,
  });

  DiscoveryState copyWith({
    Map<String, Peer>? peers,
    bool? isRunning,
    String? error,
  }) {
    return DiscoveryState(
      peers: peers ?? this.peers,
      isRunning: isRunning ?? this.isRunning,
      error: error,
    );
  }
}

/// Discovery notifier
class DiscoveryNotifier extends Notifier<DiscoveryState> {
  late UdpDiscoveryService _service;

  @override
  DiscoveryState build() {
    _service = UdpDiscoveryService();

    // Listen to peer updates
    _service.peerStream.listen((peers) {
      state = state.copyWith(peers: peers);
    });

    // Listen to errors
    _service.errorStream.listen((error) {
      state = state.copyWith(error: error);
    });

    return const DiscoveryState();
  }

  /// Start discovery service
  Future<bool> start(int tcpPort) async {
    final settings = ref.read(settingsProvider);
    final deviceId = settings.deviceId;
    final userName = settings.userName;

    if (deviceId == null || userName == null) {
      state = state.copyWith(error: 'Device not properly configured');
      return false;
    }

    final success = await _service.start(
      deviceId: deviceId,
      deviceName: userName,
      tcpPort: tcpPort,
    );

    if (success) {
      state = state.copyWith(isRunning: true);
    } else {
      state = state.copyWith(error: 'Failed to start discovery service');
    }

    return success;
  }

  /// Stop discovery service
  Future<void> stop() async {
    await _service.stop();
    state = const DiscoveryState();
  }

  /// Update device name
  void updateDeviceName(String newName) {
    _service.updateDeviceName(newName);
  }

  /// Get a specific peer
  Peer? getPeer(String deviceId) {
    return _service.getPeer(deviceId);
  }
}

/// Provider for discovery
final discoveryProvider = NotifierProvider<DiscoveryNotifier, DiscoveryState>(
  () => DiscoveryNotifier(),
);
