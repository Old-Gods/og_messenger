import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../settings/providers/settings_provider.dart';
import '../../rooms/domain/entities/room.dart';
import '../domain/entities/peer.dart';
import '../data/services/udp_discovery_service.dart';

/// Discovery state
class DiscoveryState {
  final Map<String, Peer> peers;
  final Map<String, Room> availableRooms; // Aggregated rooms from all peers
  final bool isRunning;
  final String? error;

  const DiscoveryState({
    this.peers = const {},
    this.availableRooms = const {},
    this.isRunning = false,
    this.error,
  });

  DiscoveryState copyWith({
    Map<String, Peer>? peers,
    Map<String, Room>? availableRooms,
    bool? isRunning,
    String? error,
  }) {
    return DiscoveryState(
      peers: peers ?? this.peers,
      availableRooms: availableRooms ?? this.availableRooms,
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
      final availableRooms = _aggregateRooms(peers);
      state = state.copyWith(peers: peers, availableRooms: availableRooms);
    });

    // Listen to errors
    _service.errorStream.listen((error) {
      state = state.copyWith(error: error);
    });

    return const DiscoveryState();
  }

  /// Aggregate rooms from all peers
  Map<String, Room> _aggregateRooms(Map<String, Peer> peers) {
    final roomMap = <String, Room>{};
    
    for (final peer in peers.values) {
      for (final roomInfo in peer.rooms) {
        // Create or update room with member count
        if (roomMap.containsKey(roomInfo.roomId)) {
          // Room already exists, increment member count
          final existingRoom = roomMap[roomInfo.roomId]!;
          roomMap[roomInfo.roomId] = Room(
            roomId: existingRoom.roomId,
            roomName: existingRoom.roomName,
            creatorDeviceId: existingRoom.creatorDeviceId,
            creatorName: existingRoom.creatorName,
            createdAt: existingRoom.createdAt,
            lastSeenAt: DateTime.now(),
            isCreator: existingRoom.isCreator,
            memberCount: existingRoom.memberCount + 1,
          );
        } else {
          // New room discovered
          roomMap[roomInfo.roomId] = Room(
            roomId: roomInfo.roomId,
            roomName: roomInfo.roomName,
            creatorDeviceId: '', // Not available from beacon
            creatorName: roomInfo.creatorName,
            createdAt: DateTime.now(),
            lastSeenAt: DateTime.now(),
            isCreator: false,
            memberCount: 1,
          );
        }
      }
    }
    
    return roomMap;
  }

  /// Get online members for a specific room
  List<Peer> getOnlineMembersForRoom(String roomId) {
    return state.peers.values
        .where((peer) => peer.rooms.any((room) => room.roomId == roomId))
        .toList();
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
