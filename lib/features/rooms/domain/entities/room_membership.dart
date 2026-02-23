/// Entity representing local membership in a room
class RoomMembership {
  final String roomId;
  final String roomName;
  final String creatorName;
  final DateTime joinedAt;

  const RoomMembership({
    required this.roomId,
    required this.roomName,
    required this.creatorName,
    required this.joinedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'room_id': roomId,
      'room_name': roomName,
      'creator_name': creatorName,
      'joined_at': joinedAt.microsecondsSinceEpoch,
    };
  }

  factory RoomMembership.fromJson(Map<String, dynamic> json) {
    return RoomMembership(
      roomId: json['room_id'] as String,
      roomName: json['room_name'] as String,
      creatorName: json['creator_name'] as String,
      joinedAt: DateTime.fromMicrosecondsSinceEpoch(json['joined_at'] as int),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RoomMembership && other.roomId == roomId;
  }

  @override
  int get hashCode => roomId.hashCode;

  @override
  String toString() {
    return 'RoomMembership(roomId: $roomId, roomName: $roomName, creatorName: $creatorName)';
  }
}
