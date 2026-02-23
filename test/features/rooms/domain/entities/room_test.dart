import 'package:flutter_test/flutter_test.dart';
import 'package:og_messenger/features/rooms/domain/entities/room.dart';

void main() {
  group('Room', () {
    final testDate = DateTime(2024, 1, 15, 10, 30);
    final testRoom = Room(
      roomId: 'room-123',
      roomName: 'Test Room',
      creatorDeviceId: 'device-456',
      creatorName: 'John Doe',
      createdAt: testDate,
      lastSeenAt: testDate,
      isCreator: true,
      memberCount: 3,
    );

    group('constructor', () {
      test('creates room with all required fields', () {
        expect(testRoom.roomId, 'room-123');
        expect(testRoom.roomName, 'Test Room');
        expect(testRoom.creatorDeviceId, 'device-456');
        expect(testRoom.creatorName, 'John Doe');
        expect(testRoom.createdAt, testDate);
        expect(testRoom.lastSeenAt, testDate);
        expect(testRoom.isCreator, true);
        expect(testRoom.memberCount, 3);
      });

      test('memberCount defaults to 0', () {
        final room = Room(
          roomId: 'room-123',
          roomName: 'Test Room',
          creatorDeviceId: 'device-456',
          creatorName: 'John Doe',
          createdAt: testDate,
          lastSeenAt: testDate,
          isCreator: false,
        );
        expect(room.memberCount, 0);
      });
    });

    group('displayName', () {
      test('returns formatted name with creator', () {
        expect(testRoom.displayName, 'Test Room (created by John Doe)');
      });

      test('handles different creator names', () {
        final room = testRoom.copyWith(creatorName: 'Jane Smith');
        expect(room.displayName, 'Test Room (created by Jane Smith)');
      });
    });

    group('copyWith', () {
      test('returns new instance with updated fields', () {
        final updated = testRoom.copyWith(
          roomName: 'Updated Room',
          memberCount: 5,
        );

        expect(updated.roomId, testRoom.roomId);
        expect(updated.roomName, 'Updated Room');
        expect(updated.memberCount, 5);
        expect(updated.creatorName, testRoom.creatorName);
      });

      test('returns copy with same values when no parameters provided', () {
        final copy = testRoom.copyWith();

        expect(copy.roomId, testRoom.roomId);
        expect(copy.roomName, testRoom.roomName);
        expect(copy.creatorDeviceId, testRoom.creatorDeviceId);
        expect(copy.memberCount, testRoom.memberCount);
      });

      test('can update isCreator flag', () {
        final updated = testRoom.copyWith(isCreator: false);
        expect(updated.isCreator, false);
        expect(testRoom.isCreator, true); // Original unchanged
      });
    });

    group('JSON serialization', () {
      test('toJson converts room to JSON map', () {
        final json = testRoom.toJson();

        expect(json['room_id'], 'room-123');
        expect(json['room_name'], 'Test Room');
        expect(json['creator_device_id'], 'device-456');
        expect(json['creator_name'], 'John Doe');
        expect(json['created_at'], testDate.microsecondsSinceEpoch);
        expect(json['last_seen_at'], testDate.microsecondsSinceEpoch);
        expect(json['is_creator'], 1);
        // memberCount is not serialized to JSON
        expect(json.containsKey('member_count'), false);
      });

      test('toJson stores isCreator as integer', () {
        final creatorJson = testRoom.toJson();
        expect(creatorJson['is_creator'], 1);

        final memberJson = testRoom.copyWith(isCreator: false).toJson();
        expect(memberJson['is_creator'], 0);
      });

      test('fromJson creates room from JSON map', () {
        final json = {
          'room_id': 'room-789',
          'room_name': 'New Room',
          'creator_device_id': 'device-111',
          'creator_name': 'Alice',
          'created_at': testDate.microsecondsSinceEpoch,
          'last_seen_at': testDate.microsecondsSinceEpoch,
          'is_creator': 0,
        };

        final room = Room.fromJson(json);

        expect(room.roomId, 'room-789');
        expect(room.roomName, 'New Room');
        expect(room.creatorDeviceId, 'device-111');
        expect(room.creatorName, 'Alice');
        expect(room.createdAt, testDate);
        expect(room.lastSeenAt, testDate);
        expect(room.isCreator, false);
        expect(room.memberCount, 0); // Always 0 from database
      });

      test('round-trip serialization preserves data', () {
        final json = testRoom.toJson();
        final deserialized = Room.fromJson(json);

        expect(deserialized.roomId, testRoom.roomId);
        expect(deserialized.roomName, testRoom.roomName);
        expect(deserialized.creatorDeviceId, testRoom.creatorDeviceId);
        expect(deserialized.creatorName, testRoom.creatorName);
        expect(deserialized.createdAt, testRoom.createdAt);
        expect(deserialized.lastSeenAt, testRoom.lastSeenAt);
        expect(deserialized.isCreator, testRoom.isCreator);
        // Note: memberCount is not preserved in round-trip
        expect(deserialized.memberCount, 0);
      });
    });

    group('equality', () {
      test('rooms with same roomId are equal', () {
        final room1 = Room(
          roomId: 'same-id',
          roomName: 'Room 1',
          creatorDeviceId: 'device-1',
          creatorName: 'Creator 1',
          createdAt: testDate,
          lastSeenAt: testDate,
          isCreator: true,
        );

        final room2 = Room(
          roomId: 'same-id',
          roomName: 'Room 2',
          creatorDeviceId: 'device-2',
          creatorName: 'Creator 2',
          createdAt: testDate.add(Duration(days: 1)),
          lastSeenAt: testDate.add(Duration(days: 1)),
          isCreator: false,
        );

        expect(room1, equals(room2));
        expect(room1.hashCode, equals(room2.hashCode));
      });

      test('rooms with different roomId are not equal', () {
        final room1 = testRoom;
        final room2 = testRoom.copyWith(roomId: 'different-id');

        expect(room1, isNot(equals(room2)));
      });

      test('room equals itself', () {
        expect(testRoom, equals(testRoom));
      });
    });

    group('toString', () {
      test('returns formatted string representation', () {
        final str = testRoom.toString();

        expect(str, contains('Room('));
        expect(str, contains('roomId: room-123'));
        expect(str, contains('roomName: Test Room'));
        expect(str, contains('creatorName: John Doe'));
        expect(str, contains('memberCount: 3'));
      });
    });
  });
}
