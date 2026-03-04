import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:og_messenger/features/storage/data/services/database_service.dart';

void main() {
  // Initialize sqflite for testing
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late DatabaseService databaseService;

  setUp(() async {
    // Create a unique database instance for these tests
    databaseService = DatabaseService.forTest('reactions');
    
    // Clean up any existing test database
    try {
      await databaseService.deleteDatabase();
    } catch (_) {
      // Ignore if database doesn't exist
    }
    
    // Initialize fresh database
    await databaseService.database;
  });

  tearDown(() async {
    // Clean up after each test
    await databaseService.close();
    await databaseService.deleteDatabase();
  });

  group('DatabaseService - Reactions', () {
    test('message_reactions table is created with onCreate', () async {
      // Get database instance (will trigger onCreate if needed)
      final db = await databaseService.database;

      // Query table info
      final result = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='message_reactions'",
      );

      expect(result, hasLength(1));
      expect(result.first['name'], 'message_reactions');
    });

    test('message_reactions table has all required columns', () async {
      final db = await databaseService.database;

      final result = await db.rawQuery('PRAGMA table_info(message_reactions)');

      final columnNames = result.map((col) => col['name'] as String).toList();

      expect(columnNames, contains('message_uuid'));
      expect(columnNames, contains('message_sender_id'));
      expect(columnNames, contains('reactor_device_id'));
      expect(columnNames, contains('reactor_name'));
      expect(columnNames, contains('emoji'));
      expect(columnNames, contains('timestamp_micros'));
      expect(columnNames, contains('room_id'));
    });

    test(
      'message_reactions table has UNIQUE constraint on composite key',
      () async {
        final db = await databaseService.database;

        // Insert first reaction
        await db.insert('message_reactions', {
          'message_uuid': 'test-msg-unique',
          'message_sender_id': 'sender-unique',
          'reactor_device_id': 'reactor-unique',
          'reactor_name': 'Test User',
          'emoji': '👍',
          'timestamp_micros': DateTime.now().microsecondsSinceEpoch,
          'room_id': 'room-unique',
        });

        // Try to insert duplicate (same composite key, different emoji)
        // Should throw due to UNIQUE constraint
        expect(
          () async => await db.insert('message_reactions', {
            'message_uuid': 'test-msg-unique',
            'message_sender_id': 'sender-unique',
            'reactor_device_id': 'reactor-unique',
            'reactor_name': 'Test User',
            'emoji': '❤️', // Different emoji
            'timestamp_micros': DateTime.now().microsecondsSinceEpoch,
            'room_id': 'room-unique',
          }),
          throwsA(isA<Exception>()),
        );

        // Cleanup
        await db.delete(
          'message_reactions',
          where: 'message_uuid = ?',
          whereArgs: ['test-msg-unique'],
        );
      },
    );

    test('message_reactions table has indexes', () async {
      final db = await databaseService.database;

      final result = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='message_reactions'",
      );

      // Should have indexes on message reference and room_id
      expect(result.length, greaterThan(0));
    });

    // Note: Cascade deletion tests would require setting up messages first
    // and are better suited for integration tests that test the full
    // message and reaction lifecycle together.
  });
}
