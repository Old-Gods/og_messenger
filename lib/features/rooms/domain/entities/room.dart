/// Entity representing a chat room
class Room {
  final String roomId;
  final String roomName;
  final String creatorDeviceId;
  final String creatorName;
  final DateTime createdAt;
  final DateTime lastSeenAt;
  final bool isCreator;
  final int memberCount; // Calculated from online peers

  const Room({
    required this.roomId,
    required this.roomName,
    required this.creatorDeviceId,
    required this.creatorName,
    required this.createdAt,
    required this.lastSeenAt,
    required this.isCreator,
    this.memberCount = 0,
  });

  /// Display name with creator info
  String get displayName => '$roomName (created by $creatorName)';

  Room copyWith({
    String? roomId,
    String? roomName,
    String? creatorDeviceId,
    String? creatorName,
    DateTime? createdAt,
    DateTime? lastSeenAt,
    bool? isCreator,
    int? memberCount,
  }) {
    return Room(
      roomId: roomId ?? this.roomId,
      roomName: roomName ?? this.roomName,
      creatorDeviceId: creatorDeviceId ?? this.creatorDeviceId,
      creatorName: creatorName ?? this.creatorName,
      createdAt: createdAt ?? this.createdAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      isCreator: isCreator ?? this.isCreator,
      memberCount: memberCount ?? this.memberCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'room_id': roomId,
      'room_name': roomName,
      'creator_device_id': creatorDeviceId,
      'creator_name': creatorName,
      'created_at': createdAt.microsecondsSinceEpoch,
      'last_seen_at': lastSeenAt.microsecondsSinceEpoch,
      'is_creator': isCreator ? 1 : 0,
      // member_count is not stored in database - it's calculated from online peers
    };
  }

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      roomId: json['room_id'] as String,
      roomName: json['room_name'] as String,
      creatorDeviceId: json['creator_device_id'] as String,
      creatorName: json['creator_name'] as String,
      createdAt: DateTime.fromMicrosecondsSinceEpoch(json['created_at'] as int),
      lastSeenAt: DateTime.fromMicrosecondsSinceEpoch(
        json['last_seen_at'] as int,
      ),
      isCreator: (json['is_creator'] as int) == 1,
      memberCount: 0, // Always 0 from database, calculated from discovery
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Room && other.roomId == roomId;
  }

  @override
  int get hashCode => roomId.hashCode;

  @override
  String toString() {
    return 'Room(roomId: $roomId, roomName: $roomName, creatorName: $creatorName, memberCount: $memberCount)';
  }
}
