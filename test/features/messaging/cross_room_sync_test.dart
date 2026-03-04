import 'package:flutter_test/flutter_test.dart';
import 'package:og_messenger/features/messaging/domain/entities/message.dart';
import 'package:og_messenger/features/storage/data/services/database_service.dart';
import 'package:og_messenger/features/messaging/data/repositories/message_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../helpers/test_helpers.dart';

/// Integration tests for cross-room message synchronization.
///
/// These tests verify that:
/// 1. Messages from different rooms are not cross-contaminated
/// 2. Sync responses filter messages by the requested room_id
/// 3. Duplicate detection works correctly within room boundaries
void main() {
  // Initialize FFI for testing
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Cross-Room Sync Integration Tests', () {
    late DatabaseService database;
    late MessageRepository repository;

    setUp(() async {
      TestHelpers.setupMockSharedPreferences();

      // Clean up any existing database first
      try {
        // Try to close any existing instance
        if (DatabaseService.instance != null) {
          try {
            await DatabaseService.instance.close();
          } catch (e) {
            // Ignore close errors
          }
        }
        await DatabaseService.instance.deleteDatabase();
      } catch (e) {
        // Ignore if database doesn't exist
      }
      // Wait longer for file system to release handles (extra time for CI)
      await Future.delayed(const Duration(milliseconds: 500));

      // Initialize services with fresh database
      database = DatabaseService.instance;
      repository = MessageRepository(database: database);
    });

    tearDown(() async {
      // Clean up - close and reset the database
      try {
        await database.close();
      } catch (e) {
        // Ignore errors during close
      }

      // Extra delay before deletion
      await Future.delayed(const Duration(milliseconds: 100));

      try {
        await DatabaseService.instance.deleteDatabase();
      } catch (e) {
        // Ignore errors during deletion
      }

      // Wait longer for file system to release handles (extra time for CI)
      await Future.delayed(const Duration(milliseconds: 500));
    });

    test('Messages from different rooms are not cross-contaminated', () async {
      // Setup: Create messages in two different rooms
      final room1 = 'room-alpha';
      final room2 = 'room-beta';
      final localDevice = 'test-device';

      final message1Room1 = Message(
        uuid: 'msg-1-room1',
        senderId: 'user-1',
        senderName: 'User 1',
        content: 'Message in Room Alpha',
        timestampMicros: DateTime.now()
            .subtract(const Duration(hours: 2))
            .microsecondsSinceEpoch,
        isOutgoing: false,
        roomId: room1,
      );

      final message2Room1 = Message(
        uuid: 'msg-2-room1',
        senderId: 'user-1',
        senderName: 'User 1',
        content: 'Another message in Room Alpha',
        timestampMicros: DateTime.now()
            .subtract(const Duration(hours: 1))
            .microsecondsSinceEpoch,
        isOutgoing: false,
        roomId: room1,
      );

      final message1Room2 = Message(
        uuid: 'msg-1-room2',
        senderId: 'user-2',
        senderName: 'User 2',
        content: 'Message in Room Beta',
        timestampMicros: DateTime.now()
            .subtract(const Duration(hours: 2))
            .microsecondsSinceEpoch,
        isOutgoing: false,
        roomId: room2,
      );

      final message2Room2 = Message(
        uuid: 'msg-2-room2',
        senderId: 'user-2',
        senderName: 'User 2',
        content: 'Another message in Room Beta',
        timestampMicros: DateTime.now()
            .subtract(const Duration(hours: 1))
            .microsecondsSinceEpoch,
        isOutgoing: false,
        roomId: room2,
      );

      // Save messages to database
      await repository.saveMessage(message1Room1, localDevice, room1);
      await repository.saveMessage(message2Room1, localDevice, room1);
      await repository.saveMessage(message1Room2, localDevice, room2);
      await repository.saveMessage(message2Room2, localDevice, room2);

      // Query messages for room1
      final room1Messages = await repository.getMessagesAfterTimestampPaginated(
        localDevice,
        room1,
        0,
        100,
      );

      // Query messages for room2
      final room2Messages = await repository.getMessagesAfterTimestampPaginated(
        localDevice,
        room2,
        0,
        100,
      );

      // Verify: Room1 messages only contain Room1 data
      expect(room1Messages.length, equals(2));
      expect(room1Messages.every((m) => m.roomId == room1), isTrue);
      expect(
        room1Messages.any((m) => m.content == 'Message in Room Alpha'),
        isTrue,
      );
      expect(
        room1Messages.any((m) => m.content == 'Another message in Room Alpha'),
        isTrue,
      );
      expect(room1Messages.any((m) => m.content.contains('Beta')), isFalse);

      // Verify: Room2 messages only contain Room2 data
      expect(room2Messages.length, equals(2));
      expect(room2Messages.every((m) => m.roomId == room2), isTrue);
      expect(
        room2Messages.any((m) => m.content == 'Message in Room Beta'),
        isTrue,
      );
      expect(
        room2Messages.any((m) => m.content == 'Another message in Room Beta'),
        isTrue,
      );
      expect(room2Messages.any((m) => m.content.contains('Alpha')), isFalse);
    });

    test('Duplicate message UUIDs are rejected across all rooms', () async {
      // This test verifies that the database constraint on (uuid, sender_id)
      // prevents the same message from being saved in multiple rooms

      final duplicateUuid = 'duplicate-uuid-123';
      final senderId = 'user-1';
      final localDevice = 'test-device';

      final messageRoom1 = Message(
        uuid: duplicateUuid,
        senderId: senderId,
        senderName: 'User 1',
        content: 'Original message in Room 1',
        timestampMicros: DateTime.now().microsecondsSinceEpoch,
        isOutgoing: false,
        roomId: 'room-1',
      );

      final messageRoom2 = Message(
        uuid: duplicateUuid, // Same UUID
        senderId: senderId, // Same sender
        senderName: 'User 1',
        content: 'Attempted duplicate in Room 2',
        timestampMicros: DateTime.now().microsecondsSinceEpoch,
        isOutgoing: false,
        roomId: 'room-2', // Different room
      );

      // Save first message
      await repository.saveMessage(messageRoom1, localDevice, 'room-1');

      // Attempt to save duplicate message in different room
      // This should fail due to the UNIQUE constraint on (uuid, sender_id)
      expect(
        () async =>
            await repository.saveMessage(messageRoom2, localDevice, 'room-2'),
        throwsException,
      );

      // Verify: Only the first message was saved
      final room1Messages = await repository.getMessagesAfterTimestampPaginated(
        localDevice,
        'room-1',
        0,
        100,
      );

      final room2Messages = await repository.getMessagesAfterTimestampPaginated(
        localDevice,
        'room-2',
        0,
        100,
      );

      expect(room1Messages.length, equals(1));
      expect(room1Messages.first.uuid, equals(duplicateUuid));
      expect(room2Messages.length, equals(0));
    });

    test(
      'Sync response filtering by room_id prevents cross-room leaks',
      () async {
        // Setup: Create messages in multiple rooms
        final targetRoom = 'sync-target-room';
        final otherRoom = 'other-room';
        final localDevice = 'test-device';

        final baseTimestamp = DateTime.now().subtract(const Duration(hours: 5));

        // Messages in target room (should be included in sync)
        final targetMessage1 = Message(
          uuid: 'target-msg-1',
          senderId: 'user-1',
          senderName: 'User 1',
          content: 'Target room message 1',
          timestampMicros: baseTimestamp
              .add(const Duration(hours: 1))
              .microsecondsSinceEpoch,
          isOutgoing: false,
          roomId: targetRoom,
        );

        final targetMessage2 = Message(
          uuid: 'target-msg-2',
          senderId: 'user-1',
          senderName: 'User 1',
          content: 'Target room message 2',
          timestampMicros: baseTimestamp
              .add(const Duration(hours: 2))
              .microsecondsSinceEpoch,
          isOutgoing: false,
          roomId: targetRoom,
        );

        // Messages in other room (should NOT be included in sync)
        final otherMessage1 = Message(
          uuid: 'other-msg-1',
          senderId: 'user-2',
          senderName: 'User 2',
          content: 'Other room message 1',
          timestampMicros: baseTimestamp
              .add(const Duration(hours: 1))
              .microsecondsSinceEpoch,
          isOutgoing: false,
          roomId: otherRoom,
        );

        final otherMessage2 = Message(
          uuid: 'other-msg-2',
          senderId: 'user-2',
          senderName: 'User 2',
          content: 'Other room message 2',
          timestampMicros: baseTimestamp
              .add(const Duration(hours: 3))
              .microsecondsSinceEpoch,
          isOutgoing: false,
          roomId: otherRoom,
        );

        // Save all messages
        await repository.saveMessage(targetMessage1, localDevice, targetRoom);
        await repository.saveMessage(targetMessage2, localDevice, targetRoom);
        await repository.saveMessage(otherMessage1, localDevice, otherRoom);
        await repository.saveMessage(otherMessage2, localDevice, otherRoom);

        // Simulate sync request for targetRoom only
        final syncFromTimestamp = baseTimestamp.microsecondsSinceEpoch;

        final syncedMessages = await repository
            .getMessagesAfterTimestampPaginated(
              localDevice,
              targetRoom, // Only sync this room
              syncFromTimestamp,
              100,
            );

        // Verify: Only target room messages are returned
        expect(syncedMessages.length, equals(2));
        expect(syncedMessages.every((m) => m.roomId == targetRoom), isTrue);
        expect(syncedMessages.any((m) => m.uuid == 'target-msg-1'), isTrue);
        expect(syncedMessages.any((m) => m.uuid == 'target-msg-2'), isTrue);

        // Verify: Other room messages are NOT included
        expect(syncedMessages.any((m) => m.uuid == 'other-msg-1'), isFalse);
        expect(syncedMessages.any((m) => m.uuid == 'other-msg-2'), isFalse);
        expect(
          syncedMessages.any((m) => m.content.contains('Other room')),
          isFalse,
        );
      },
    );

    test('Timestamp-based sync respects room boundaries', () async {
      // This test verifies that sync with timestamp filtering still respects room boundaries

      final room1 = 'timestamp-room-1';
      final room2 = 'timestamp-room-2';
      final localDevice = 'test-device';

      final baseTime = DateTime.now().subtract(const Duration(hours: 10));

      // Old message in room1 (before sync timestamp)
      final oldRoom1Message = Message(
        uuid: 'old-room1',
        senderId: 'user-1',
        senderName: 'User 1',
        content: 'Old message in room 1',
        timestampMicros: baseTime
            .add(const Duration(hours: 1))
            .microsecondsSinceEpoch,
        isOutgoing: false,
        roomId: room1,
      );

      // New message in room1 (after sync timestamp)
      final newRoom1Message = Message(
        uuid: 'new-room1',
        senderId: 'user-1',
        senderName: 'User 1',
        content: 'New message in room 1',
        timestampMicros: baseTime
            .add(const Duration(hours: 6))
            .microsecondsSinceEpoch,
        isOutgoing: false,
        roomId: room1,
      );

      // New message in room2 (after sync timestamp, but wrong room)
      final newRoom2Message = Message(
        uuid: 'new-room2',
        senderId: 'user-2',
        senderName: 'User 2',
        content: 'New message in room 2',
        timestampMicros: baseTime
            .add(const Duration(hours: 7))
            .microsecondsSinceEpoch,
        isOutgoing: false,
        roomId: room2,
      );

      await repository.saveMessage(oldRoom1Message, localDevice, room1);
      await repository.saveMessage(newRoom1Message, localDevice, room1);
      await repository.saveMessage(newRoom2Message, localDevice, room2);

      // Sync from 5 hours ago for room1 only
      final syncTimestamp = baseTime
          .add(const Duration(hours: 5))
          .microsecondsSinceEpoch;

      final syncedMessages = await repository
          .getMessagesAfterTimestampPaginated(
            localDevice,
            room1,
            syncTimestamp,
            100,
          );

      // Verify: Only new room1 message is returned
      expect(syncedMessages.length, equals(1));
      expect(syncedMessages.first.uuid, equals('new-room1'));
      expect(syncedMessages.first.roomId, equals(room1));

      // Verify: Old room1 message is excluded (too old)
      expect(syncedMessages.any((m) => m.uuid == 'old-room1'), isFalse);

      // Verify: Room2 message is excluded (wrong room)
      expect(syncedMessages.any((m) => m.uuid == 'new-room2'), isFalse);
    });
  });
}
