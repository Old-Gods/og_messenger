import 'package:flutter_test/flutter_test.dart';
import 'package:og_messenger/features/rooms/domain/entities/invite_request.dart';

void main() {
  group('InviteRequest', () {
    final testDate = DateTime(2024, 1, 15, 10, 30);
    final testInvite = InviteRequest(
      inviteId: 'invite-123',
      roomId: 'room-456',
      roomName: 'Test Room',
      inviterDeviceId: 'device-789',
      inviterName: 'John Doe',
      createdAt: testDate,
    );

    group('constructor', () {
      test('creates invite with all required fields', () {
        expect(testInvite.inviteId, 'invite-123');
        expect(testInvite.roomId, 'room-456');
        expect(testInvite.roomName, 'Test Room');
        expect(testInvite.inviterDeviceId, 'device-789');
        expect(testInvite.inviterName, 'John Doe');
        expect(testInvite.createdAt, testDate);
      });

      test('creates invite with different values', () {
        final invite = InviteRequest(
          inviteId: 'invite-abc',
          roomId: 'room-xyz',
          roomName: 'Another Room',
          inviterDeviceId: 'device-def',
          inviterName: 'Jane Smith',
          createdAt: DateTime(2024, 2, 1),
        );
        expect(invite.inviteId, 'invite-abc');
        expect(invite.roomId, 'room-xyz');
        expect(invite.roomName, 'Another Room');
        expect(invite.inviterDeviceId, 'device-def');
        expect(invite.inviterName, 'Jane Smith');
      });
    });

    group('toJson', () {
      test('converts invite to JSON correctly', () {
        final json = testInvite.toJson();
        expect(json['invite_id'], 'invite-123');
        expect(json['room_id'], 'room-456');
        expect(json['room_name'], 'Test Room');
        expect(json['inviter_device_id'], 'device-789');
        expect(json['inviter_name'], 'John Doe');
        expect(json['created_at'], testDate.microsecondsSinceEpoch);
      });

      test('converts datetime to microseconds', () {
        final json = testInvite.toJson();
        expect(json['created_at'], isA<int>());
        expect(json['created_at'], testDate.microsecondsSinceEpoch);
      });

      test('JSON contains all required keys', () {
        final json = testInvite.toJson();
        expect(
          json.keys,
          containsAll([
            'invite_id',
            'room_id',
            'room_name',
            'inviter_device_id',
            'inviter_name',
            'created_at',
          ]),
        );
      });
    });

    group('fromJson', () {
      test('creates invite from valid JSON', () {
        final json = {
          'invite_id': 'invite-123',
          'room_id': 'room-456',
          'room_name': 'Test Room',
          'inviter_device_id': 'device-789',
          'inviter_name': 'John Doe',
          'created_at': testDate.microsecondsSinceEpoch,
        };

        final invite = InviteRequest.fromJson(json);
        expect(invite.inviteId, 'invite-123');
        expect(invite.roomId, 'room-456');
        expect(invite.roomName, 'Test Room');
        expect(invite.inviterDeviceId, 'device-789');
        expect(invite.inviterName, 'John Doe');
        expect(invite.createdAt, testDate);
      });

      test('converts microseconds to DateTime', () {
        final json = {
          'invite_id': 'invite-123',
          'room_id': 'room-456',
          'room_name': 'Test Room',
          'inviter_device_id': 'device-789',
          'inviter_name': 'John Doe',
          'created_at': testDate.microsecondsSinceEpoch,
        };

        final invite = InviteRequest.fromJson(json);
        expect(invite.createdAt, isA<DateTime>());
        expect(
          invite.createdAt.microsecondsSinceEpoch,
          testDate.microsecondsSinceEpoch,
        );
      });

      test('handles different JSON values', () {
        final json = {
          'invite_id': 'different-id',
          'room_id': 'different-room',
          'room_name': 'Different Room',
          'inviter_device_id': 'different-device',
          'inviter_name': 'Different User',
          'created_at': DateTime(2024, 3, 1).microsecondsSinceEpoch,
        };

        final invite = InviteRequest.fromJson(json);
        expect(invite.inviteId, 'different-id');
        expect(invite.roomId, 'different-room');
      });
    });

    group('JSON round-trip', () {
      test('survives toJson -> fromJson conversion', () {
        final json = testInvite.toJson();
        final reconstructed = InviteRequest.fromJson(json);

        expect(reconstructed.inviteId, testInvite.inviteId);
        expect(reconstructed.roomId, testInvite.roomId);
        expect(reconstructed.roomName, testInvite.roomName);
        expect(reconstructed.inviterDeviceId, testInvite.inviterDeviceId);
        expect(reconstructed.inviterName, testInvite.inviterName);
        expect(reconstructed.createdAt, testInvite.createdAt);
      });

      test('preserves data integrity through multiple conversions', () {
        final json1 = testInvite.toJson();
        final invite1 = InviteRequest.fromJson(json1);
        final json2 = invite1.toJson();
        final invite2 = InviteRequest.fromJson(json2);

        expect(invite2.inviteId, testInvite.inviteId);
        expect(invite2.roomId, testInvite.roomId);
        expect(invite2.roomName, testInvite.roomName);
        expect(invite2.createdAt, testInvite.createdAt);
      });
    });

    group('equality', () {
      test('equal invites have same inviteId', () {
        final invite1 = InviteRequest(
          inviteId: 'invite-123',
          roomId: 'room-456',
          roomName: 'Test Room',
          inviterDeviceId: 'device-789',
          inviterName: 'John Doe',
          createdAt: testDate,
        );
        final invite2 = InviteRequest(
          inviteId: 'invite-123',
          roomId: 'room-different',
          roomName: 'Different Room',
          inviterDeviceId: 'device-different',
          inviterName: 'Different User',
          createdAt: DateTime(2024, 2, 1),
        );

        expect(invite1, equals(invite2));
      });

      test('different inviteIds are not equal', () {
        final invite1 = testInvite;
        final invite2 = InviteRequest(
          inviteId: 'invite-different',
          roomId: 'room-456',
          roomName: 'Test Room',
          inviterDeviceId: 'device-789',
          inviterName: 'John Doe',
          createdAt: testDate,
        );

        expect(invite1, isNot(equals(invite2)));
      });

      test('same object is equal to itself', () {
        expect(testInvite, equals(testInvite));
      });

      test('equal invites have same hashCode', () {
        final invite1 = InviteRequest(
          inviteId: 'invite-123',
          roomId: 'room-456',
          roomName: 'Test Room',
          inviterDeviceId: 'device-789',
          inviterName: 'John Doe',
          createdAt: testDate,
        );
        final invite2 = InviteRequest(
          inviteId: 'invite-123',
          roomId: 'room-different',
          roomName: 'Different Room',
          inviterDeviceId: 'device-different',
          inviterName: 'Different User',
          createdAt: DateTime(2024, 2, 1),
        );

        expect(invite1.hashCode, equals(invite2.hashCode));
      });
    });
  });
}
