/// Represents a peer device on the network
class Peer {
  final String deviceId;
  final String deviceName;
  final String ipAddress;
  final int tcpPort;
  final DateTime lastSeen;

  Peer({
    required this.deviceId,
    required this.deviceName,
    required this.ipAddress,
    required this.tcpPort,
    required this.lastSeen,
  });

  /// Create a Peer from JSON received via UDP multicast
  factory Peer.fromJson(Map<String, dynamic> json) {
    return Peer(
      deviceId: json['device_id'] as String,
      deviceName: json['device_name'] as String,
      ipAddress: json['ip_address'] as String,
      tcpPort: json['tcp_port'] as int,
      lastSeen: DateTime.now(),
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
    };
  }

  /// Create a copy with updated fields
  Peer copyWith({
    String? deviceId,
    String? deviceName,
    String? ipAddress,
    int? tcpPort,
    DateTime? lastSeen,
  }) {
    return Peer(
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      ipAddress: ipAddress ?? this.ipAddress,
      tcpPort: tcpPort ?? this.tcpPort,
      lastSeen: lastSeen ?? this.lastSeen,
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
