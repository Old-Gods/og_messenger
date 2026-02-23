import 'package:og_messenger/features/rooms/domain/entities/room_info.dart';

/// Represents a peer device on the network
class Peer {
  final String deviceId;
  final String deviceName;
  final String ipAddress;
  final int tcpPort;
  final DateTime lastSeen;
  final String publicKey; // RSA public key in PEM format (required)
  final List<RoomInfo> rooms; // Rooms this peer is a member of

  Peer({
    required this.deviceId,
    required this.deviceName,
    required this.ipAddress,
    required this.tcpPort,
    required this.lastSeen,
    required this.publicKey,
    this.rooms = const [],
  });

  /// Create a Peer from JSON received via UDP multicast
  factory Peer.fromJson(Map<String, dynamic> json) {
    final roomsJson = json['rooms'] as List<dynamic>? ?? [];
    final rooms = roomsJson
        .map((r) => RoomInfo.fromJson(r as Map<String, dynamic>))
        .toList();

    return Peer(
      deviceId: json['device_id'] as String,
      deviceName: json['device_name'] as String,
      ipAddress: json['ip_address'] as String,
      tcpPort: json['tcp_port'] as int,
      lastSeen: DateTime.now(),
      publicKey: json['public_key'] as String,
      rooms: rooms,
    );
  }

  /// Convert Peer to JSON for UDP multicast broadcast
  Map<String, dynamic> toJson() {
    return {
      'device_id': deviceId,
      'device_name': deviceName,
      'ip_address': ipAddress,
      'tcp_port': tcpPort,
      'timestamp': DateTime.now().microsecondsSinceEpoch,
      'public_key': publicKey,
      'rooms': rooms.map((r) => r.toJson()).toList(),
    };
  }

  /// Create a copy with updated fields
  Peer copyWith({
    String? deviceId,
    String? deviceName,
    String? ipAddress,
    int? tcpPort,
    DateTime? lastSeen,
    String? publicKey,
    List<RoomInfo>? rooms,
  }) {
    return Peer(
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      ipAddress: ipAddress ?? this.ipAddress,
      tcpPort: tcpPort ?? this.tcpPort,
      lastSeen: lastSeen ?? this.lastSeen,
      publicKey: publicKey ?? this.publicKey,
      rooms: rooms ?? this.rooms,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Peer &&
          runtimeType == other.runtimeType &&
          deviceId == other.deviceId;

  @override
  int get hashCode => deviceId.hashCode;

  @override
  String toString() {
    return 'Peer{deviceId: $deviceId, deviceName: $deviceName, ipAddress: $ipAddress, tcpPort: $tcpPort}';
  }
}
