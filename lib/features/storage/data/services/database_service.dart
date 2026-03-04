import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/message_schema.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../rooms/domain/entities/room.dart';
import '../../../rooms/domain/entities/room_membership.dart';
import '../../../rooms/domain/entities/join_request.dart';
import '../../../rooms/domain/entities/invite_request.dart';

/// SQLite database service for managing message and room storage
class DatabaseService {
  static Database? _database;
  static final DatabaseService instance = DatabaseService._();

  DatabaseService._();

  /// Get database instance, initializing if needed
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize the database
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.databaseName);

    return await openDatabase(
      path,
      version: 3, // V3: Multi-room architecture
      onCreate: _onCreate,
    );
  }

  /// Create database tables (fresh start, no migration)
  Future<void> _onCreate(Database db, int version) async {
    // Create messages table with room_id
    await db.execute('''
      CREATE TABLE messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL,
        timestamp_micros INTEGER NOT NULL,
        sender_id TEXT NOT NULL,
        sender_name TEXT NOT NULL,
        content TEXT NOT NULL,
        room_id TEXT NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_timestamp ON messages(timestamp_micros)',
    );
    await db.execute('CREATE INDEX idx_sender ON messages(sender_id)');
    await db.execute('CREATE INDEX idx_room ON messages(room_id)');
    await db.execute(
      'CREATE UNIQUE INDEX idx_uuid_sender ON messages(uuid, sender_id)',
    );

    // Create rooms table
    await db.execute('''
      CREATE TABLE rooms (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        room_id TEXT NOT NULL UNIQUE,
        room_name TEXT NOT NULL,
        creator_device_id TEXT NOT NULL,
        creator_name TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        last_seen_at INTEGER NOT NULL,
        is_creator INTEGER NOT NULL
      )
    ''');

    // Create room_memberships table
    await db.execute('''
      CREATE TABLE room_memberships (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        room_id TEXT NOT NULL UNIQUE,
        room_name TEXT NOT NULL,
        creator_name TEXT NOT NULL,
        joined_at INTEGER NOT NULL
      )
    ''');

    // Create join_requests table
    await db.execute('''
      CREATE TABLE join_requests (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        request_id TEXT NOT NULL UNIQUE,
        room_id TEXT NOT NULL,
        room_name TEXT NOT NULL,
        requester_device_id TEXT NOT NULL,
        requester_name TEXT NOT NULL,
        requester_public_key TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    // Create invite_requests table
    await db.execute('''
      CREATE TABLE invite_requests (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invite_id TEXT NOT NULL UNIQUE,
        room_id TEXT NOT NULL,
        room_name TEXT NOT NULL,
        inviter_device_id TEXT NOT NULL,
        inviter_name TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    // Create message_reactions table
    await db.execute('''
      CREATE TABLE message_reactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        message_uuid TEXT NOT NULL,
        message_sender_id TEXT NOT NULL,
        reactor_device_id TEXT NOT NULL,
        reactor_name TEXT NOT NULL,
        emoji TEXT NOT NULL,
        timestamp_micros INTEGER NOT NULL,
        room_id TEXT NOT NULL,
        UNIQUE(message_uuid, message_sender_id, reactor_device_id, room_id)
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_reaction_message ON message_reactions(message_uuid, message_sender_id)',
    );
    await db.execute(
      'CREATE INDEX idx_reaction_room ON message_reactions(room_id)',
    );
  }

  /// Insert a new message
  Future<int> insertMessage(MessageSchema message) async {
    final db = await database;
    try {
      return await db.insert(
        MessageSchema.tableName,
        message.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    } catch (e) {
      // Handle unique constraint violations gracefully
      rethrow;
    }
  }

  /// Get all messages for a specific room ordered by timestamp
  Future<List<MessageSchema>> getAllMessages(String roomId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      MessageSchema.tableName,
      where: '${MessageSchema.columnRoomId} = ?',
      whereArgs: [roomId],
      orderBy: '${MessageSchema.columnTimestampMicros} ASC',
    );

    return List.generate(maps.length, (i) => MessageSchema.fromMap(maps[i]));
  }

  /// Get messages from a specific sender in a specific room
  Future<List<MessageSchema>> getMessagesBySender(
    String senderId,
    String roomId,
  ) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      MessageSchema.tableName,
      where:
          '${MessageSchema.columnSenderId} = ? AND ${MessageSchema.columnRoomId} = ?',
      whereArgs: [senderId, roomId],
      orderBy: '${MessageSchema.columnTimestampMicros} ASC',
    );

    return List.generate(maps.length, (i) => MessageSchema.fromMap(maps[i]));
  }

  /// Get messages after a specific timestamp for a specific room
  Future<List<MessageSchema>> getMessagesAfterTimestamp(
    int timestampMicros,
    String roomId,
  ) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      MessageSchema.tableName,
      where:
          '${MessageSchema.columnTimestampMicros} > ? AND ${MessageSchema.columnRoomId} = ?',
      whereArgs: [timestampMicros, roomId],
      orderBy: '${MessageSchema.columnTimestampMicros} ASC',
    );

    return List.generate(maps.length, (i) => MessageSchema.fromMap(maps[i]));
  }

  /// Get messages before a specific timestamp for a specific room (for pagination)
  Future<List<MessageSchema>> getMessagesBeforeTimestamp(
    String roomId,
    int beforeTimestamp,
    int limit,
  ) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      MessageSchema.tableName,
      where:
          '${MessageSchema.columnTimestampMicros} < ? AND ${MessageSchema.columnRoomId} = ?',
      whereArgs: [beforeTimestamp, roomId],
      orderBy: '${MessageSchema.columnTimestampMicros} DESC',
      limit: limit,
    );

    // Reverse to get ascending order
    final results = List.generate(
      maps.length,
      (i) => MessageSchema.fromMap(maps[i]),
    );
    return results.reversed.toList();
  }

  /// Get messages after a specific timestamp for a specific room with limit (for pagination)
  Future<List<MessageSchema>> getMessagesAfterTimestampPaginated(
    String roomId,
    int afterTimestamp,
    int limit,
  ) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      MessageSchema.tableName,
      where:
          '${MessageSchema.columnTimestampMicros} > ? AND ${MessageSchema.columnRoomId} = ?',
      whereArgs: [afterTimestamp, roomId],
      orderBy: '${MessageSchema.columnTimestampMicros} ASC',
      limit: limit,
    );

    return List.generate(maps.length, (i) => MessageSchema.fromMap(maps[i]));
  }

  /// Get the most recent N messages for a specific room (for initial load)
  Future<List<MessageSchema>> getInitialMessages(
    String roomId,
    int limit,
  ) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      MessageSchema.tableName,
      where: '${MessageSchema.columnRoomId} = ?',
      whereArgs: [roomId],
      orderBy: '${MessageSchema.columnTimestampMicros} DESC',
      limit: limit,
    );

    // Reverse to get ascending order (oldest to newest)
    final results = List.generate(
      maps.length,
      (i) => MessageSchema.fromMap(maps[i]),
    );
    return results.reversed.toList();
  }

  /// Get the most recent message timestamp for a specific room (for sync purposes)
  Future<int?> getLatestTimestamp(String roomId) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      MessageSchema.tableName,
      columns: [MessageSchema.columnTimestampMicros],
      where: '${MessageSchema.columnRoomId} = ?',
      whereArgs: [roomId],
      orderBy: '${MessageSchema.columnTimestampMicros} DESC',
      limit: 1,
    );

    if (result.isEmpty) return null;
    return result.first[MessageSchema.columnTimestampMicros] as int;
  }

  /// Delete messages older than the retention period
  Future<int> deleteExpiredMessages() async {
    final db = await database;
    final retentionMicros = AppConstants.retentionDays * 24 * 60 * 60 * 1000000;
    final cutoffTimestamp =
        DateTime.now().microsecondsSinceEpoch - retentionMicros;

    // First delete reactions for expired messages
    await db.delete(
      'message_reactions',
      where: 'timestamp_micros < ?',
      whereArgs: [cutoffTimestamp],
    );

    // Then delete the messages
    return await db.delete(
      MessageSchema.tableName,
      where: '${MessageSchema.columnTimestampMicros} < ?',
      whereArgs: [cutoffTimestamp],
    );
  }

  /// Delete a specific message by UUID and sender ID
  Future<int> deleteMessage(String uuid, String senderId) async {
    final db = await database;

    // First delete reactions for this message
    await db.delete(
      'message_reactions',
      where: 'message_uuid = ? AND message_sender_id = ?',
      whereArgs: [uuid, senderId],
    );

    // Then delete the message
    return await db.delete(
      MessageSchema.tableName,
      where:
          '${MessageSchema.columnUuid} = ? AND ${MessageSchema.columnSenderId} = ?',
      whereArgs: [uuid, senderId],
    );
  }

  /// Get a message by UUID, sender ID, and room ID (for duplicate checking)
  Future<MessageSchema?> getMessageByUuid(
    String uuid,
    String senderId,
    String roomId,
  ) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      MessageSchema.tableName,
      where:
          '${MessageSchema.columnUuid} = ? AND ${MessageSchema.columnSenderId} = ? AND ${MessageSchema.columnRoomId} = ?',
      whereArgs: [uuid, senderId, roomId],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return MessageSchema.fromMap(maps.first);
  }

  /// Get total message count for a specific room
  Future<int> getMessageCount(String roomId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${MessageSchema.tableName} WHERE ${MessageSchema.columnRoomId} = ?',
      [roomId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Clear all messages for a specific room
  Future<int> clearAllMessages(String roomId) async {
    final db = await database;

    // First delete all reactions for this room
    await db.delete(
      'message_reactions',
      where: 'room_id = ?',
      whereArgs: [roomId],
    );

    // Then delete all messages
    return await db.delete(
      MessageSchema.tableName,
      where: '${MessageSchema.columnRoomId} = ?',
      whereArgs: [roomId],
    );
  }

  /// Delete all messages for a specific room (used when leaving room)
  Future<int> deleteMessagesByRoom(String roomId) async {
    final db = await database;

    // First delete all reactions for this room
    await db.delete(
      'message_reactions',
      where: 'room_id = ?',
      whereArgs: [roomId],
    );

    // Then delete all messages
    return await db.delete(
      MessageSchema.tableName,
      where: '${MessageSchema.columnRoomId} = ?',
      whereArgs: [roomId],
    );
  }

  /// Update sender name for all messages from a specific sender in a specific room
  Future<int> updateSenderName(
    String senderId,
    String newName,
    String roomId,
  ) async {
    final db = await database;
    return await db.update(
      MessageSchema.tableName,
      {MessageSchema.columnSenderName: newName},
      where:
          '${MessageSchema.columnSenderId} = ? AND ${MessageSchema.columnRoomId} = ?',
      whereArgs: [senderId, roomId],
    );
  }

  // ==================== Room CRUD Methods ====================

  /// Insert a new room
  Future<int> insertRoom(Room room) async {
    final db = await database;
    return await db.insert(
      'rooms',
      room.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get room by ID
  Future<Room?> getRoomById(String roomId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'rooms',
      where: 'room_id = ?',
      whereArgs: [roomId],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return Room.fromJson(maps.first);
  }

  /// Delete a room
  Future<int> deleteRoom(String roomId) async {
    final db = await database;
    return await db.delete('rooms', where: 'room_id = ?', whereArgs: [roomId]);
  }

  // ==================== Room Membership Methods ====================

  /// Insert a room membership
  Future<int> insertRoomMembership(RoomMembership membership) async {
    final db = await database;
    return await db.insert(
      'room_memberships',
      membership.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get all room memberships
  Future<List<RoomMembership>> getRoomMemberships() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'room_memberships',
      orderBy: 'joined_at DESC',
    );

    return List.generate(maps.length, (i) => RoomMembership.fromJson(maps[i]));
  }

  /// Check if user is member of a room
  Future<bool> isRoomMember(String roomId) async {
    final db = await database;
    final result = await db.query(
      'room_memberships',
      where: 'room_id = ?',
      whereArgs: [roomId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  /// Delete a room membership
  Future<int> deleteMembership(String roomId) async {
    final db = await database;
    return await db.delete(
      'room_memberships',
      where: 'room_id = ?',
      whereArgs: [roomId],
    );
  }

  // ==================== Join Request Methods ====================

  /// Insert a join request
  Future<int> insertJoinRequest(JoinRequest request) async {
    final db = await database;
    return await db.insert(
      'join_requests',
      request.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get all pending join requests
  Future<List<JoinRequest>> getJoinRequests() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'join_requests',
      orderBy: 'created_at DESC',
    );

    return List.generate(maps.length, (i) => JoinRequest.fromJson(maps[i]));
  }

  /// Delete a join request
  Future<int> deleteJoinRequest(String requestId) async {
    final db = await database;
    return await db.delete(
      'join_requests',
      where: 'request_id = ?',
      whereArgs: [requestId],
    );
  }

  /// Delete all join requests for a specific room
  Future<int> deleteJoinRequestsByRoom(String roomId) async {
    final db = await database;
    return await db.delete(
      'join_requests',
      where: 'room_id = ?',
      whereArgs: [roomId],
    );
  }

  /// Upsert (insert or update) an invite request
  Future<int> upsertInviteRequest(InviteRequest invite) async {
    final db = await database;
    return await db.insert(
      'invite_requests',
      invite.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get all pending invite requests
  Future<List<InviteRequest>> getInviteRequests() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'invite_requests',
      orderBy: 'created_at DESC',
    );

    return List.generate(maps.length, (i) => InviteRequest.fromJson(maps[i]));
  }

  /// Delete an invite request
  Future<int> deleteInviteRequest(String inviteId) async {
    final db = await database;
    return await db.delete(
      'invite_requests',
      where: 'invite_id = ?',
      whereArgs: [inviteId],
    );
  }

  /// Delete all invite requests for a specific room
  Future<int> deleteInviteRequestsByRoom(String roomId) async {
    final db = await database;
    return await db.delete(
      'invite_requests',
      where: 'room_id = ?',
      whereArgs: [roomId],
    );
  }

  /// Close the database
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  /// Delete the database file (for testing)
  Future<void> deleteDatabase() async {
    if (_database != null) {
      await close();
    }
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.databaseName);
    await databaseFactory.deleteDatabase(path);
    _database = null;
  }
}
