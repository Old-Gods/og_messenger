import '../../../storage/data/models/message_schema.dart';
import '../../../storage/data/services/database_service.dart';
import '../../domain/entities/message.dart';

/// Repository for managing messages
class MessageRepository {
  final DatabaseService _database;

  MessageRepository({DatabaseService? database})
    : _database = database ?? DatabaseService.instance;

  /// Save a message to the database
  Future<void> saveMessage(Message message, String localDeviceId) async {
    final schema = MessageSchema(
      uuid: message.uuid,
      timestampMicros: message.timestampMicros,
      senderId: message.senderId,
      senderName: message.senderName,
      content: message.content,
    );

    try {
      await _database.insertMessage(schema);
    } catch (e) {
      // Handle duplicate messages gracefully (already exists)
      rethrow;
    }
  }

  /// Get all messages as domain entities
  Future<List<Message>> getAllMessages(String localDeviceId) async {
    final schemas = await _database.getAllMessages();
    return schemas.map((schema) {
      return Message(
        uuid: schema.uuid,
        timestampMicros: schema.timestampMicros,
        senderId: schema.senderId,
        senderName: schema.senderName,
        content: schema.content,
        isOutgoing: schema.senderId == localDeviceId,
      );
    }).toList();
  }

  /// Get messages from a specific sender
  Future<List<Message>> getMessagesBySender(
    String senderId,
    String localDeviceId,
  ) async {
    final schemas = await _database.getMessagesBySender(senderId);
    return schemas.map((schema) {
      return Message(
        uuid: schema.uuid,
        timestampMicros: schema.timestampMicros,
        senderId: schema.senderId,
        senderName: schema.senderName,
        content: schema.content,
        isOutgoing: schema.senderId == localDeviceId,
      );
    }).toList();
  }

  /// Get messages after a specific timestamp
  Future<List<Message>> getMessagesAfterTimestamp(
    int timestampMicros,
    String localDeviceId,
  ) async {
    final schemas = await _database.getMessagesAfterTimestamp(timestampMicros);
    return schemas.map((schema) {
      return Message(
        uuid: schema.uuid,
        timestampMicros: schema.timestampMicros,
        senderId: schema.senderId,
        senderName: schema.senderName,
        content: schema.content,
        isOutgoing: schema.senderId == localDeviceId,
      );
    }).toList();
  }

  /// Get the latest message timestamp
  Future<int?> getLatestTimestamp() async {
    return await _database.getLatestTimestamp();
  }

  /// Delete expired messages based on retention period
  Future<int> deleteExpiredMessages() async {
    return await _database.deleteExpiredMessages();
  }

  /// Delete a specific message
  Future<void> deleteMessage(String uuid, String senderId) async {
    await _database.deleteMessage(uuid, senderId);
  }

  /// Get total message count
  Future<int> getMessageCount() async {
    return await _database.getMessageCount();
  }

  /// Clear all messages
  Future<void> clearAllMessages() async {
    await _database.clearAllMessages();
  }
}
