/// Represents a chat message in the domain layer
class Message {
  final String uuid;
  final int timestampMicros;
  final String senderId;
  final String senderName;
  final String content;
  final bool isOutgoing;

  Message({
    required this.uuid,
    required this.timestampMicros,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.isOutgoing,
  });

  /// Get DateTime from microseconds timestamp
  DateTime get timestamp =>
      DateTime.fromMicrosecondsSinceEpoch(timestampMicros);

  /// Create from JSON received via TCP
  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      uuid: json['uuid'] as String,
      timestampMicros: json['timestamp_micros'] as int,
      senderId: json['sender_id'] as String,
      senderName: json['sender_name'] as String,
      content: json['content'] as String,
      isOutgoing: false, // Will be determined by comparing with local device ID
    );
  }

  /// Convert to JSON for TCP transmission
  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'timestamp_micros': timestampMicros,
      'sender_id': senderId,
      'sender_name': senderName,
      'content': content,
    };
  }

  /// Create a copy with updated fields
  Message copyWith({
    String? uuid,
    int? timestampMicros,
    String? senderId,
    String? senderName,
    String? content,
    bool? isOutgoing,
  }) {
    return Message(
      uuid: uuid ?? this.uuid,
      timestampMicros: timestampMicros ?? this.timestampMicros,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      content: content ?? this.content,
      isOutgoing: isOutgoing ?? this.isOutgoing,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Message &&
          runtimeType == other.runtimeType &&
          uuid == other.uuid &&
          senderId == other.senderId;

  @override
  int get hashCode => uuid.hashCode ^ senderId.hashCode;

  @override
  String toString() {
    return 'Message{uuid: $uuid, senderName: $senderName, content: ${content.substring(0, content.length > 20 ? 20 : content.length)}...}';
  }
}
