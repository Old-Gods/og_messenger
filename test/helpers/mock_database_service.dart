import 'package:sqflite/sqflite.dart';
import 'package:og_messenger/features/storage/data/models/message_schema.dart';
import 'package:og_messenger/features/storage/data/services/database_service.dart';

/// Creates a testable MessageRepository with in-memory storage
class TestMessageRepository {
  final _MockStorage _storage = _MockStorage();

  Future<void> saveMessage(
    String uuid,
    int timestampMicros,
    String senderId,
    String senderName,
    String content,
    String localDeviceId,
    String networkId,
  ) async {
    final schema = MessageSchema(
      uuid: uuid,
      timestampMicros: timestampMicros,
      senderId: senderId,
      senderName: senderName,
      content: content,
      networkId: networkId,
    );
    await _storage.insertMessage(schema);
  }

  Future<List<Map<String, dynamic>>> getAllMessages(
    String localDeviceId,
    String networkId,
  ) async {
    final schemas = await _storage.getAllMessages(networkId);
    return schemas.map((schema) {
      return {
        'uuid': schema.uuid,
        'timestampMicros': schema.timestampMicros,
        'senderId': schema.senderId,
        'senderName': schema.senderName,
        'content': schema.content,
        'isOutgoing': schema.senderId == localDeviceId,
        'networkId': schema.networkId,
      };
    }).toList();
  }

  Future<int> deleteExpiredMessages() async {
    return await _storage.deleteExpiredMessages();
  }

  Future<int> clearAllMessages(String networkId) async {
    return await _storage.clearAllMessages(networkId);
  }

  void clearStorage() {
    _storage.clear();
  }
}

class _MockStorage {
  final List<MessageSchema> _messages = [];

  Future<int> insertMessage(MessageSchema message) async {
    // Check for duplicates
    final existingIndex = _messages.indexWhere((m) => m.uuid == message.uuid);
    if (existingIndex != -1) {
      _messages[existingIndex] = message;
      return existingIndex;
    }

    _messages.add(message);
    return _messages.length - 1;
  }

  Future<List<MessageSchema>> getAllMessages(String networkId) async {
    return _messages.where((m) => m.networkId == networkId).toList()
      ..sort((a, b) => a.timestampMicros.compareTo(b.timestampMicros));
  }

  Future<int> deleteExpiredMessages() async {
    final retentionMicros = 30 * 24 * 60 * 60 * 1000000; // 30 days
    final cutoffTime = DateTime.now().microsecondsSinceEpoch - retentionMicros;

    final countBefore = _messages.length;
    _messages.removeWhere((m) => m.timestampMicros < cutoffTime);

    return countBefore - _messages.length;
  }

  Future<int> clearAllMessages(String networkId) async {
    final countBefore = _messages.length;
    _messages.removeWhere((m) => m.networkId == networkId);

    return countBefore - _messages.length;
  }

  void clear() {
    _messages.clear();
  }
}
