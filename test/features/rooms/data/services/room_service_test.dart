import 'package:flutter_test/flutter_test.dart';
import 'package:og_messenger/features/rooms/data/services/room_service.dart';
import 'package:og_messenger/features/rooms/domain/entities/room.dart';
import 'package:og_messenger/features/storage/data/services/database_service.dart';
import 'package:og_messenger/features/security/data/services/security_service.dart';
import 'package:og_messenger/features/settings/data/services/settings_service.dart';
import 'package:og_messenger/features/notifications/data/services/notification_service.dart';
import '../../../../helpers/test_helpers.dart';

void main() {
  group('RoomService', () {
    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();

      // Setup mock shared preferences with required settings
      TestHelpers.setupMockSharedPreferences({
        'device_id': 'test-device-123',
        'user_name': 'Test User',
      });

      // Initialize services
      await SettingsService.instance.initialize();
      await SecurityService.instance.initialize();
      await NotificationService.instance.initialize();
      await DatabaseService.instance.initialize();
      await RoomService.instance.initialize();
    });

    tearDown(() async {
      // Clean up database between tests
      await DatabaseService.instance.close();
    });

    group('initialization', () {
      test('singleton instance is always the same', () {
        final instance1 = RoomService.instance;
        final instance2 = RoomService.instance;

        expect(instance1, same(instance2));
      });

      test('can be initialized multiple times without error', () async {
        await RoomService.instance.initialize();
        await RoomService.instance.initialize();
        // No exception should be thrown
      });
    });

    group('createRoom', () {
      test('creates room with valid name', () async {
        final room = await RoomService.instance.createRoom('Test Room');

        expect(room.roomName, 'Test Room');
        expect(room.roomId, isNotEmpty);
        expect(room.creatorDeviceId, 'test-device-123');
        expect(room.creatorName, 'Test User');
        expect(room.isCreator, true);
      });

      test('generates unique room IDs', () async {
        final room1 = await RoomService.instance.createRoom('Room 1');
        final room2 = await RoomService.instance.createRoom('Room 2');

        expect(room1.roomId, isNot(equals(room2.roomId)));
      });

      test('generates AES key for room', () async {
        final room = await RoomService.instance.createRoom('Secure Room');

        // Verify key exists (will throw if not found)
        expect(
          () => SecurityService.instance.getRoomKey(room.roomId),
          returnsNormally,
        );
      });

      test('stores room in database', () async {
        final room = await RoomService.instance.createRoom('DB Test Room');

        // Retrieve rooms from database
        final rooms = await RoomService.instance.getJoinedRooms();

        expect(rooms.any((r) => r.roomId == room.roomId), true);
      });

      test('sets timestamps correctly', () async {
        final before = DateTime.now();
        final room = await RoomService.instance.createRoom('Time Test');
        final after = DateTime.now();

        expect(room.createdAt.isAfter(before), true);
        expect(room.createdAt.isBefore(after), true);
        expect(room.lastSeenAt.isAfter(before), true);
        expect(room.lastSeenAt.isBefore(after), true);
      });
    });

    group('leaveRoom', () {
      test('removes room completely', () async {
        final room = await RoomService.instance.createRoom('Leave Test');

        await RoomService.instance.leaveRoom(room.roomId);

        final rooms = await RoomService.instance.getJoinedRooms();
        expect(rooms.any((r) => r.roomId == room.roomId), false);
      });

      test('removes AES key', () async {
        final room = await RoomService.instance.createRoom('Key Test');

        await RoomService.instance.leaveRoom(room.roomId);

        // Key should not exist
        expect(
          () => SecurityService.instance.getRoomKey(room.roomId),
          throwsException,
        );
      });

      test('deletes messages in room', () async {
        final room = await RoomService.instance.createRoom('Msg Test');

        // Insert a test message
        await DatabaseService.instance.insertMessage({
          'uuid': 'msg-123',
          'timestamp': DateTime.now().microsecondsSinceEpoch,
          'sender_id': 'device-1',
          'sender_name': 'User 1',
          'content': 'Test message',
          'room_id': room.roomId,
        });

        await RoomService.instance.leaveRoom(room.roomId);

        // Verify messages are deleted
        final messages = await DatabaseService.instance.getMessages(
          room.roomId,
          limit: 100,
        );
        expect(messages, isEmpty);
      });

      test('handles leaving non-existent room', () async {
        // Should not throw
        await RoomService.instance.leaveRoom('non-existent-room-id');
      });
    });

    group('getJoinedRooms', () {
      test('returns empty list when no rooms joined', () async {
        final rooms = await RoomService.instance.getJoinedRooms();
        expect(rooms, isEmpty);
      });

      test('returns all joined rooms', () async {
        await RoomService.instance.createRoom('Room 1');
        await RoomService.instance.createRoom('Room 2');
        await RoomService.instance.createRoom('Room 3');

        final rooms = await RoomService.instance.getJoinedRooms();
        expect(rooms.length, 3);
      });

      test('returns rooms with correct names', () async {
        await RoomService.instance.createRoom('Alpha');
        await RoomService.instance.createRoom('Beta');

        final rooms = await RoomService.instance.getJoinedRooms();
        final names = rooms.map((r) => r.roomName).toSet();

        expect(names, contains('Alpha'));
        expect(names, contains('Beta'));
      });

      test('excludes left rooms', () async {
        final room1 = await RoomService.instance.createRoom('Stay');
        final room2 = await RoomService.instance.createRoom('Leave');

        await RoomService.instance.leaveRoom(room2.roomId);

        final rooms = await RoomService.instance.getJoinedRooms();

        expect(rooms.any((r) => r.roomId == room1.roomId), true);
        expect(rooms.any((r) => r.roomId == room2.roomId), false);
      });
    });

    group('room operations', () {
      test('can create, retrieve, and leave room in sequence', () async {
        // Create
        final created = await RoomService.instance.createRoom('Sequential');
        expect(created.roomName, 'Sequential');

        // Retrieve
        final rooms = await RoomService.instance.getJoinedRooms();
        expect(rooms.any((r) => r.roomId == created.roomId), true);

        // Leave
        await RoomService.instance.leaveRoom(created.roomId);
        final afterLeave = await RoomService.instance.getJoinedRooms();
        expect(afterLeave.any((r) => r.roomId == created.roomId), false);
      });

      test('handles multiple rooms independently', () async {
        final room1 = await RoomService.instance.createRoom('Room 1');
        final room2 = await RoomService.instance.createRoom('Room 2');

        await RoomService.instance.leaveRoom(room1.roomId);

        final rooms = await RoomService.instance.getJoinedRooms();
        expect(rooms.any((r) => r.roomId == room1.roomId), false);
        expect(rooms.any((r) => r.roomId == room2.roomId), true);
      });
    });
  });
}
