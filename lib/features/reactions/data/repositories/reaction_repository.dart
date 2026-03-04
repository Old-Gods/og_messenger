import 'package:sqflite/sqflite.dart';
import '../../../storage/data/services/database_service.dart';
import '../../domain/entities/reaction.dart';

/// Repository for managing message reactions
class ReactionRepository {
  final DatabaseService _database;

  ReactionRepository({DatabaseService? database})
    : _database = database ?? DatabaseService.instance;

  /// Save a reaction to the database (UPSERT - replaces if exists)
  /// Enforces one-reaction-per-user rule via UNIQUE constraint
  Future<void> saveReaction(Reaction reaction) async {
    final db = await _database.database;
    try {
      await db.insert(
        'message_reactions',
        reaction.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Delete a specific reaction
  Future<void> deleteReaction({
    required String messageUuid,
    required String messageSenderId,
    required String reactorDeviceId,
    required String roomId,
  }) async {
    final db = await _database.database;
    await db.delete(
      'message_reactions',
      where:
          'message_uuid = ? AND message_sender_id = ? AND reactor_device_id = ? AND room_id = ?',
      whereArgs: [messageUuid, messageSenderId, reactorDeviceId, roomId],
    );
  }

  /// Get all reactions for a specific message
  Future<List<Reaction>> getReactionsForMessage({
    required String messageUuid,
    required String messageSenderId,
    required String roomId,
  }) async {
    final db = await _database.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'message_reactions',
      where: 'message_uuid = ? AND message_sender_id = ? AND room_id = ?',
      whereArgs: [messageUuid, messageSenderId, roomId],
      orderBy: 'timestamp_micros ASC',
    );

    return maps.map((map) => Reaction.fromJson(map)).toList();
  }

  /// Get reactions for multiple messages (batch query for efficiency)
  /// Takes a list of message keys in format "uuid_senderId"
  Future<Map<String, List<Reaction>>> getReactionsForMessages({
    required List<String> messageKeys,
    required String roomId,
  }) async {
    if (messageKeys.isEmpty) {
      return {};
    }

    final db = await _database.database;
    final Map<String, List<Reaction>> result = {};

    // Build WHERE clause for batch query
    final placeholders = messageKeys
        .map((_) => '(message_uuid = ? AND message_sender_id = ?)')
        .join(' OR ');

    // Flatten message keys into uuid and senderId pairs
    final whereArgs = <String>[];
    for (final key in messageKeys) {
      final parts = key.split('_');
      if (parts.length >= 2) {
        whereArgs.add(parts[0]); // uuid
        whereArgs.add(
          parts.sublist(1).join('_'),
        ); // sender_id (in case it contains underscores)
      }
    }
    whereArgs.add(roomId);

    final List<Map<String, dynamic>> maps = await db.query(
      'message_reactions',
      where: '($placeholders) AND room_id = ?',
      whereArgs: whereArgs,
      orderBy: 'timestamp_micros ASC',
    );

    // Group reactions by message key
    for (final map in maps) {
      final reaction = Reaction.fromJson(map);
      final key = '${reaction.messageUuid}_${reaction.messageSenderId}';
      result.putIfAbsent(key, () => []).add(reaction);
    }

    return result;
  }

  /// Get all reactions in a room (for sync purposes)
  Future<List<Reaction>> getReactionsInRoom(String roomId) async {
    final db = await _database.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'message_reactions',
      where: 'room_id = ?',
      whereArgs: [roomId],
      orderBy: 'timestamp_micros ASC',
    );

    return maps.map((map) => Reaction.fromJson(map)).toList();
  }

  /// Delete all reactions for a specific message (cascade delete)
  Future<void> deleteReactionsForMessage({
    required String messageUuid,
    required String messageSenderId,
    required String roomId,
  }) async {
    final db = await _database.database;
    await db.delete(
      'message_reactions',
      where: 'message_uuid = ? AND message_sender_id = ? AND room_id = ?',
      whereArgs: [messageUuid, messageSenderId, roomId],
    );
  }

  /// Delete all reactions in a room
  Future<void> deleteReactionsInRoom(String roomId) async {
    final db = await _database.database;
    await db.delete(
      'message_reactions',
      where: 'room_id = ?',
      whereArgs: [roomId],
    );
  }

  /// Delete reactions older than a specific timestamp (for retention policy)
  Future<void> deleteReactionsOlderThan({
    required int timestampMicros,
    required String roomId,
  }) async {
    final db = await _database.database;
    await db.delete(
      'message_reactions',
      where: 'timestamp_micros < ? AND room_id = ?',
      whereArgs: [timestampMicros, roomId],
    );
  }
}
