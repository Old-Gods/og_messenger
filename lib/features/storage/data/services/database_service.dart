import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/message_schema.dart';
import '../../../../core/constants/app_constants.dart';

/// SQLite database service for managing message storage
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
      version: 2, // Bump version for migration
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Create database tables
  Future<void> _onCreate(Database db, int version) async {
    await db.execute(MessageSchema.createTableSql);
  }

  /// Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add network_id column to existing messages table
      await db.execute(
        'ALTER TABLE ${MessageSchema.tableName} ADD COLUMN ${MessageSchema.columnNetworkId} TEXT NOT NULL DEFAULT "unknown"',
      );
      // Add index for network_id
      await db.execute(
        'CREATE INDEX idx_network ON ${MessageSchema.tableName}(${MessageSchema.columnNetworkId})',
      );
    }
  }

  /// Insert a new message
  Future<int> insertMessage(MessageSchema message) async {
    final db = await database;
    try {
      return await db.insert(
        MessageSchema.tableName,
        message.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      // Handle unique constraint violations gracefully
      rethrow;
    }
  }

  /// Get all messages for a specific network ordered by timestamp
  Future<List<MessageSchema>> getAllMessages(String networkId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      MessageSchema.tableName,
      where: '${MessageSchema.columnNetworkId} = ?',
      whereArgs: [networkId],
      orderBy: '${MessageSchema.columnTimestampMicros} ASC',
    );

    return List.generate(maps.length, (i) => MessageSchema.fromMap(maps[i]));
  }

  /// Get messages from a specific sender on a specific network
  Future<List<MessageSchema>> getMessagesBySender(
    String senderId,
    String networkId,
  ) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      MessageSchema.tableName,
      where:
          '${MessageSchema.columnSenderId} = ? AND ${MessageSchema.columnNetworkId} = ?',
      whereArgs: [senderId, networkId],
      orderBy: '${MessageSchema.columnTimestampMicros} ASC',
    );

    return List.generate(maps.length, (i) => MessageSchema.fromMap(maps[i]));
  }

  /// Get messages after a specific timestamp for a specific network
  Future<List<MessageSchema>> getMessagesAfterTimestamp(
    int timestampMicros,
    String networkId,
  ) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      MessageSchema.tableName,
      where:
          '${MessageSchema.columnTimestampMicros} > ? AND ${MessageSchema.columnNetworkId} = ?',
      whereArgs: [timestampMicros, networkId],
      orderBy: '${MessageSchema.columnTimestampMicros} ASC',
    );

    return List.generate(maps.length, (i) => MessageSchema.fromMap(maps[i]));
  }

  /// Get the most recent message timestamp for a specific network (for sync purposes)
  Future<int?> getLatestTimestamp(String networkId) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      MessageSchema.tableName,
      columns: [MessageSchema.columnTimestampMicros],
      where: '${MessageSchema.columnNetworkId} = ?',
      whereArgs: [networkId],
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

    return await db.delete(
      MessageSchema.tableName,
      where: '${MessageSchema.columnTimestampMicros} < ?',
      whereArgs: [cutoffTimestamp],
    );
  }

  /// Delete a specific message by UUID and sender ID
  Future<int> deleteMessage(String uuid, String senderId) async {
    final db = await database;
    return await db.delete(
      MessageSchema.tableName,
      where:
          '${MessageSchema.columnUuid} = ? AND ${MessageSchema.columnSenderId} = ?',
      whereArgs: [uuid, senderId],
    );
  }

  /// Get total message count for a specific network
  Future<int> getMessageCount(String networkId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${MessageSchema.tableName} WHERE ${MessageSchema.columnNetworkId} = ?',
      [networkId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Clear all messages for a specific network (for testing or reset purposes)
  Future<int> clearAllMessages(String networkId) async {
    final db = await database;
    return await db.delete(
      MessageSchema.tableName,
      where: '${MessageSchema.columnNetworkId} = ?',
      whereArgs: [networkId],
    );
  }

  /// Update sender name for all messages from a specific sender on a specific network
  Future<int> updateSenderName(
    String senderId,
    String newName,
    String networkId,
  ) async {
    final db = await database;
    return await db.update(
      MessageSchema.tableName,
      {MessageSchema.columnSenderName: newName},
      where:
          '${MessageSchema.columnSenderId} = ? AND ${MessageSchema.columnNetworkId} = ?',
      whereArgs: [senderId, networkId],
    );
  }

  /// Close the database
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
