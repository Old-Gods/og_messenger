import '../../../storage/data/models/message_schema.dart';
import '../../../storage/data/services/database_service.dart';
import '../../domain/entities/message.dart';

/// Repository for managing messages
class MessageRepository {
  final DatabaseService _database;

  MessageRepository({DatabaseService? database})
    : _database = database ?? DatabaseService.instance;

  /// Save a message to the database
  Future<void> saveMessage(
    Message message,
    String localDeviceId,
    String roomId,
  ) async {
    final schema = MessageSchema(
      uuid: message.uuid,
      timestampMicros: message.timestampMicros,
      senderId: message.senderId,
      senderName: message.senderName,
      content: message.content,
      roomId: roomId,
    );

    try {
      await _database.insertMessage(schema);
    } catch (e) {
      // Handle duplicate messages gracefully (already exists)
      rethrow;
    }
  }

  /// Get all messages for a specific network as domain entities
  @Deprecated('Use getInitialMessages() for paginated loading')
  Future<List<Message>> getAllMessages(
    String localDeviceId,
    String networkId,
  ) async {
    final schemas = await _database.getAllMessages(networkId);
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

  /// Get the most recent N messages (for initial load)
  Future<List<Message>> getInitialMessages(
    String localDeviceId,
    String networkId,
    int limit,
  ) async {
    final schemas = await _database.getInitialMessages(networkId, limit);
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

  /// Get messages before a specific timestamp (for loading older messages)
  Future<List<Message>> getMessagesBeforeTimestamp(
    String localDeviceId,
    String networkId,
    int beforeTimestamp,
    int limit,
  ) async {
    final schemas = await _database.getMessagesBeforeTimestamp(
      networkId,
      beforeTimestamp,
      limit,
    );
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

  /// Get messages after a specific timestamp with limit (for loading newer messages)
  Future<List<Message>> getMessagesAfterTimestampPaginated(
    String localDeviceId,
    String networkId,
    int afterTimestamp,
    int limit,
  ) async {
    final schemas = await _database.getMessagesAfterTimestampPaginated(
      networkId,
      afterTimestamp,
      limit,
    );
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

  /// Get messages from a specific sender on a specific network
  Future<List<Message>> getMessagesBySender(
    String senderId,
    String localDeviceId,
    String networkId,
  ) async {
    final schemas = await _database.getMessagesBySender(senderId, networkId);
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

  /// Get messages after a specific timestamp for a specific network
  Future<List<Message>> getMessagesAfterTimestamp(
    int timestampMicros,
    String localDeviceId,
    String networkId,
  ) async {
    final schemas = await _database.getMessagesAfterTimestamp(
      timestampMicros,
      networkId,
    );
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

  /// Get the latest message timestamp for a specific network
  Future<int?> getLatestTimestamp(String networkId) async {
    return await _database.getLatestTimestamp(networkId);
  }

  /// Delete expired messages based on retention period
  Future<int> deleteExpiredMessages() async {
    return await _database.deleteExpiredMessages();
  }

  /// Delete a specific message
  Future<void> deleteMessage(String uuid, String senderId) async {
    await _database.deleteMessage(uuid, senderId);
  }

  /// Check if a message exists by UUID and sender ID
  Future<Message?> getMessageByUuid(
    String uuid,
    String senderId,
    String roomId,
  ) async {
    try {
      final schema = await _database.getMessageByUuid(uuid, senderId, roomId);
      if (schema == null) return null;

      return Message(
        uuid: schema.uuid,
        timestampMicros: schema.timestampMicros,
        senderId: schema.senderId,
        senderName: schema.senderName,
        content: schema.content,
        isOutgoing: false, // Not relevant for duplicate check
      );
    } catch (e) {
      return null;
    }
  }

  /// Get total message count for a specific network
  Future<int> getMessageCount(String networkId) async {
    return await _database.getMessageCount(networkId);
  }

  /// Clear all messages for a specific network
  Future<void> clearAllMessages(String networkId) async {
    await _database.clearAllMessages(networkId);
  }

  /// Update sender name for all messages from a specific sender on a specific network
  Future<int> updateSenderName(
    String senderId,
    String newName,
    String networkId,
  ) async {
    return await _database.updateSenderName(senderId, newName, networkId);
  }
}
