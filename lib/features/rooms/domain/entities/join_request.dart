/// Entity representing a join request for a room
class JoinRequest {
  final String requestId;
  final String roomId;
  final String roomName;
  final String requesterDeviceId;
  final String requesterName;
  final String requesterPublicKey; // RSA public key in PEM format
  final DateTime createdAt;

  const JoinRequest({
    required this.requestId,
    required this.roomId,
    required this.roomName,
    required this.requesterDeviceId,
    required this.requesterName,
    required this.requesterPublicKey,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'request_id': requestId,
      'room_id': roomId,
      'room_name': roomName,
      'requester_device_id': requesterDeviceId,
      'requester_name': requesterName,
      'requester_public_key': requesterPublicKey,
      'created_at': createdAt.microsecondsSinceEpoch,
    };
  }

  factory JoinRequest.fromJson(Map<String, dynamic> json) {
    return JoinRequest(
      requestId: json['request_id'] as String,
      roomId: json['room_id'] as String,
      roomName: json['room_name'] as String,
      requesterDeviceId: json['requester_device_id'] as String,
      requesterName: json['requester_name'] as String,
      requesterPublicKey: json['requester_public_key'] as String,
      createdAt: DateTime.fromMicrosecondsSinceEpoch(json['created_at'] as int),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is JoinRequest && other.requestId == requestId;
  }

  @override
  int get hashCode => requestId.hashCode;

  @override
  String toString() {
    return 'JoinRequest(requestId: $requestId, requesterName: $requesterName, roomName: $roomName)';
  }
}
