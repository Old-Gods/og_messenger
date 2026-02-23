/// Room information for UDP beacon broadcasts
class RoomInfo {
  final String roomId;
  final String roomName;
  final String creatorName;
  final bool isMember;

  const RoomInfo({
    required this.roomId,
    required this.roomName,
    required this.creatorName,
    required this.isMember,
  });

  Map<String, dynamic> toJson() {
    return {
      'room_id': roomId,
      'room_name': roomName,
      'creator_name': creatorName,
      'is_member': isMember,
    };
  }

  factory RoomInfo.fromJson(Map<String, dynamic> json) {
    return RoomInfo(
      roomId: json['room_id'] as String,
      roomName: json['room_name'] as String,
      creatorName: json['creator_name'] as String,
      isMember: json['is_member'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RoomInfo && other.roomId == roomId;
  }

  @override
  int get hashCode => roomId.hashCode;

  @override
  String toString() {
    return 'RoomInfo(roomId: $roomId, roomName: $roomName, creatorName: $creatorName, isMember: $isMember)';
  }
}
