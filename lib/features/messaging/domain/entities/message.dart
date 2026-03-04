/// Represents a chat message in the domain layer
class Message {
  final String uuid;
  final int timestampMicros;
  final String senderId;
  final String senderName;
  final String content;
  final bool isOutgoing;
  final String? roomId; // Room ID for multi-room support

  // Reply reference (stored in database)
  final String? repliedToUuid;
  final String? repliedToSenderId;

  // Reply preview data (runtime only, for display)
  final String? replyToPreviewContent;
  final String? replyToPreviewSenderName;

  Message({
    required this.uuid,
    required this.timestampMicros,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.isOutgoing,
    this.roomId,
    this.repliedToUuid,
    this.repliedToSenderId,
    this.replyToPreviewContent,
    this.replyToPreviewSenderName,
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
      roomId: json['room_id'] as String?,
      repliedToUuid: json['replied_to_uuid'] as String?,
      repliedToSenderId: json['replied_to_sender_id'] as String?,
      replyToPreviewContent: json['reply_to_preview_content'] as String?,
      replyToPreviewSenderName: json['reply_to_preview_sender_name'] as String?,
    );
  }

  /// Convert to JSON for TCP transmission
  Map<String, dynamic> toJson() {
    final json = {
      'uuid': uuid,
      'timestamp_micros': timestampMicros,
      'sender_id': senderId,
      'sender_name': senderName,
      'content': content,
    };

    // Include reply data if present
    if (repliedToUuid != null) {
      json['replied_to_uuid'] = repliedToUuid!;
    }
    if (repliedToSenderId != null) {
      json['replied_to_sender_id'] = repliedToSenderId!;
    }
    if (replyToPreviewContent != null) {
      json['reply_to_preview_content'] = replyToPreviewContent!;
    }
    if (replyToPreviewSenderName != null) {
      json['reply_to_preview_sender_name'] = replyToPreviewSenderName!;
    }

    return json;
  }

  /// Create a copy with updated fields
  Message copyWith({
    String? uuid,
    int? timestampMicros,
    String? senderId,
    String? senderName,
    String? content,
    bool? isOutgoing,
    String? roomId,
    String? repliedToUuid,
    String? repliedToSenderId,
    String? replyToPreviewContent,
    String? replyToPreviewSenderName,
  }) {
    return Message(
      uuid: uuid ?? this.uuid,
      timestampMicros: timestampMicros ?? this.timestampMicros,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      content: content ?? this.content,
      isOutgoing: isOutgoing ?? this.isOutgoing,
      roomId: roomId ?? this.roomId,
      repliedToUuid: repliedToUuid ?? this.repliedToUuid,
      repliedToSenderId: repliedToSenderId ?? this.repliedToSenderId,
      replyToPreviewContent:
          replyToPreviewContent ?? this.replyToPreviewContent,
      replyToPreviewSenderName:
          replyToPreviewSenderName ?? this.replyToPreviewSenderName,
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
