/// Entity representing a user's reaction to a message.
///
/// Each reaction is uniquely identified by the combination of message_uuid,
/// message_sender_id, reactor_device_id, and room_id. Users can only have one
/// reaction per message (enforced by database constraint).
class Reaction {
  /// UUID of the message being reacted to
  final String messageUuid;

  /// Device ID of the message sender
  final String messageSenderId;

  /// Device ID of the user reacting
  final String reactorDeviceId;

  /// Display name of the user reacting
  final String reactorName;

  /// The emoji used for the reaction
  final String emoji;

  /// Timestamp in microseconds since epoch
  final int timestampMicros;

  /// Room ID where the reaction occurred
  final String roomId;

  const Reaction({
    required this.messageUuid,
    required this.messageSenderId,
    required this.reactorDeviceId,
    required this.reactorName,
    required this.emoji,
    required this.timestampMicros,
    required this.roomId,
  });

  /// Creates a Reaction from a JSON map (used for database and network)
  factory Reaction.fromJson(Map<String, dynamic> json) {
    return Reaction(
      messageUuid: json['message_uuid'] as String,
      messageSenderId: json['message_sender_id'] as String,
      reactorDeviceId: json['reactor_device_id'] as String,
      reactorName: json['reactor_name'] as String,
      emoji: json['emoji'] as String,
      timestampMicros: json['timestamp_micros'] as int,
      roomId: json['room_id'] as String,
    );
  }

  /// Converts the Reaction to a JSON map (used for database and network)
  Map<String, dynamic> toJson() {
    return {
      'message_uuid': messageUuid,
      'message_sender_id': messageSenderId,
      'reactor_device_id': reactorDeviceId,
      'reactor_name': reactorName,
      'emoji': emoji,
      'timestamp_micros': timestampMicros,
      'room_id': roomId,
    };
  }

  /// Creates a copy of this Reaction with some fields replaced
  Reaction copyWith({
    String? messageUuid,
    String? messageSenderId,
    String? reactorDeviceId,
    String? reactorName,
    String? emoji,
    int? timestampMicros,
    String? roomId,
  }) {
    return Reaction(
      messageUuid: messageUuid ?? this.messageUuid,
      messageSenderId: messageSenderId ?? this.messageSenderId,
      reactorDeviceId: reactorDeviceId ?? this.reactorDeviceId,
      reactorName: reactorName ?? this.reactorName,
      emoji: emoji ?? this.emoji,
      timestampMicros: timestampMicros ?? this.timestampMicros,
      roomId: roomId ?? this.roomId,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Reaction &&
        other.messageUuid == messageUuid &&
        other.messageSenderId == messageSenderId &&
        other.reactorDeviceId == reactorDeviceId &&
        other.roomId == roomId;
  }

  @override
  int get hashCode {
    return Object.hash(messageUuid, messageSenderId, reactorDeviceId, roomId);
  }

  @override
  String toString() {
    return 'Reaction(messageUuid: $messageUuid, messageSenderId: $messageSenderId, '
        'reactorDeviceId: $reactorDeviceId, reactorName: $reactorName, '
        'emoji: $emoji, timestampMicros: $timestampMicros, roomId: $roomId)';
  }
}
