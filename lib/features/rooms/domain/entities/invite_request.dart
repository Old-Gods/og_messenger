/// Entity representing an invite to join a room
class InviteRequest {
  final String inviteId;
  final String roomId;
  final String roomName;
  final String inviterDeviceId;
  final String inviterName;
  final DateTime createdAt;

  const InviteRequest({
    required this.inviteId,
    required this.roomId,
    required this.roomName,
    required this.inviterDeviceId,
    required this.inviterName,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'invite_id': inviteId,
      'room_id': roomId,
      'room_name': roomName,
      'inviter_device_id': inviterDeviceId,
      'inviter_name': inviterName,
      'created_at': createdAt.microsecondsSinceEpoch,
    };
  }

  factory InviteRequest.fromJson(Map<String, dynamic> json) {
    return InviteRequest(
      inviteId: json['invite_id'] as String,
      roomId: json['room_id'] as String,
      roomName: json['room_name'] as String,
      inviterDeviceId: json['inviter_device_id'] as String,
      inviterName: json['inviter_name'] as String,
      createdAt: DateTime.fromMicrosecondsSinceEpoch(json['created_at'] as int),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InviteRequest && other.inviteId == inviteId;
  }

  @override
  int get hashCode => inviteId.hashCode;
}
