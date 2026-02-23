/// SQLite database schema for storing messages
class MessageSchema {
  static const String tableName = 'messages';

  // Column names
  static const String columnId = 'id';
  static const String columnUuid = 'uuid';
  static const String columnTimestampMicros = 'timestamp_micros';
  static const String columnSenderId = 'sender_id';
  static const String columnSenderName = 'sender_name';
  static const String columnContent = 'content';
  static const String columnRoomId = 'room_id';

  final int? id;
  final String uuid;
  final int timestampMicros;
  final String senderId;
  final String senderName;
  final String content;
  final String roomId;

  MessageSchema({
    this.id,
    required this.uuid,
    required this.timestampMicros,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.roomId,
  });

  /// Convert from Map (database row)
  factory MessageSchema.fromMap(Map<String, dynamic> map) {
    return MessageSchema(
      id: map[columnId] as int?,
      uuid: map[columnUuid] as String,
      timestampMicros: map[columnTimestampMicros] as int,
      senderId: map[columnSenderId] as String,
      senderName: map[columnSenderName] as String,
      content: map[columnContent] as String,
      roomId: map[columnRoomId] as String,
    );
  }

  /// Convert to Map (for database insertion)
  Map<String, dynamic> toMap() {
    return {
      columnId: id,
      columnUuid: uuid,
      columnTimestampMicros: timestampMicros,
      columnSenderId: senderId,
      columnSenderName: senderName,
      columnContent: content,
      columnRoomId: roomId,
    };
  }

  /// Convert to domain Message entity map
  Map<String, dynamic> toDomainMap(String localDeviceId) {
    return {
      'uuid': uuid,
      'timestampMicros': timestampMicros,
      'senderId': senderId,
      'senderName': senderName,
      'content': content,
      'isOutgoing': senderId == localDeviceId,
      'roomId': roomId,
    };
  }
}
