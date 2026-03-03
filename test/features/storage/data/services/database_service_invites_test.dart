import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:og_messenger/features/storage/data/services/database_service.dart';
import 'package:og_messenger/features/rooms/domain/entities/invite_request.dart';

void main() {
  // Initialize sqflite for testing
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('DatabaseService - Invite Operations', () {
    late DatabaseService dbService;

    setUp(() async {
      dbService = DatabaseService.instance;
      // Ensure clean state before each test
      try {
        await dbService.deleteDatabase();
      } catch (e) {
        // Ignore if database doesn't exist
      }
    });

    tearDown(() async {
      try {
        await dbService.deleteDatabase();
      } catch (e) {
        // Ignore errors during cleanup
      }
    });

    group('upsertInviteRequest', () {
      test('inserts new invite request', () async {
        final invite = InviteRequest(
          inviteId: 'invite-123',
          roomId: 'room-456',
          roomName: 'Test Room',
          inviterDeviceId: 'device-789',
          inviterName: 'John Doe',
          createdAt: DateTime(2024, 1, 15),
        );

        final result = await dbService.upsertInviteRequest(invite);
        expect(result, greaterThan(0));

        final invites = await dbService.getInviteRequests();
        expect(invites.length, 1);
        expect(invites.first.inviteId, 'invite-123');
        expect(invites.first.roomId, 'room-456');
        expect(invites.first.roomName, 'Test Room');
      });

      test('updates existing invite request with same inviteId', () async {
        final invite1 = InviteRequest(
          inviteId: 'invite-123',
          roomId: 'room-456',
          roomName: 'Test Room',
          inviterDeviceId: 'device-789',
          inviterName: 'John Doe',
          createdAt: DateTime(2024, 1, 15),
        );

        await dbService.upsertInviteRequest(invite1);

        // Upsert with same inviteId but different data
        final invite2 = InviteRequest(
          inviteId: 'invite-123',
          roomId: 'room-456',
          roomName: 'Updated Room Name',
          inviterDeviceId: 'device-789',
          inviterName: 'John Doe Updated',
          createdAt: DateTime(2024, 1, 16),
        );

        await dbService.upsertInviteRequest(invite2);

        final invites = await dbService.getInviteRequests();
        expect(invites.length, 1); // Should still be 1, not 2
        expect(invites.first.roomName, 'Updated Room Name');
        expect(invites.first.inviterName, 'John Doe Updated');
      });

      test('inserts multiple different invites', () async {
        final invite1 = InviteRequest(
          inviteId: 'invite-1',
          roomId: 'room-1',
          roomName: 'Room 1',
          inviterDeviceId: 'device-1',
          inviterName: 'User 1',
          createdAt: DateTime(2024, 1, 15),
        );

        final invite2 = InviteRequest(
          inviteId: 'invite-2',
          roomId: 'room-2',
          roomName: 'Room 2',
          inviterDeviceId: 'device-2',
          inviterName: 'User 2',
          createdAt: DateTime(2024, 1, 16),
        );

        await dbService.upsertInviteRequest(invite1);
        await dbService.upsertInviteRequest(invite2);

        final invites = await dbService.getInviteRequests();
        expect(invites.length, 2);
      });

      test('handles special characters in invite data', () async {
        final invite = InviteRequest(
          inviteId: 'invite-123',
          roomId: 'room-456',
          roomName: "Test's Room & \"Special\" Chars",
          inviterDeviceId: 'device-789',
          inviterName: "O'Neill",
          createdAt: DateTime(2024, 1, 15),
        );

        await dbService.upsertInviteRequest(invite);

        final invites = await dbService.getInviteRequests();
        expect(invites.first.roomName, "Test's Room & \"Special\" Chars");
        expect(invites.first.inviterName, "O'Neill");
      });
    });

    group('getInviteRequests', () {
      test('returns empty list when no invites', () async {
        final invites = await dbService.getInviteRequests();
        expect(invites, isEmpty);
      });

      test('returns all invite requests', () async {
        final invite1 = InviteRequest(
          inviteId: 'invite-1',
          roomId: 'room-1',
          roomName: 'Room 1',
          inviterDeviceId: 'device-1',
          inviterName: 'User 1',
          createdAt: DateTime(2024, 1, 15, 10, 0),
        );

        final invite2 = InviteRequest(
          inviteId: 'invite-2',
          roomId: 'room-2',
          roomName: 'Room 2',
          inviterDeviceId: 'device-2',
          inviterName: 'User 2',
          createdAt: DateTime(2024, 1, 15, 11, 0),
        );

        await dbService.upsertInviteRequest(invite1);
        await dbService.upsertInviteRequest(invite2);

        final invites = await dbService.getInviteRequests();
        expect(invites.length, 2);
      });

      test('orders invites by created_at DESC', () async {
        final invite1 = InviteRequest(
          inviteId: 'invite-1',
          roomId: 'room-1',
          roomName: 'Room 1',
          inviterDeviceId: 'device-1',
          inviterName: 'User 1',
          createdAt: DateTime(2024, 1, 15, 10, 0),
        );

        final invite2 = InviteRequest(
          inviteId: 'invite-2',
          roomId: 'room-2',
          roomName: 'Room 2',
          inviterDeviceId: 'device-2',
          inviterName: 'User 2',
          createdAt: DateTime(2024, 1, 15, 11, 0),
        );

        final invite3 = InviteRequest(
          inviteId: 'invite-3',
          roomId: 'room-3',
          roomName: 'Room 3',
          inviterDeviceId: 'device-3',
          inviterName: 'User 3',
          createdAt: DateTime(2024, 1, 15, 9, 0),
        );

        // Insert in random order
        await dbService.upsertInviteRequest(invite2);
        await dbService.upsertInviteRequest(invite1);
        await dbService.upsertInviteRequest(invite3);

        final invites = await dbService.getInviteRequests();
        // Should be ordered newest first
        expect(invites[0].inviteId, 'invite-2'); // 11:00
        expect(invites[1].inviteId, 'invite-1'); // 10:00
        expect(invites[2].inviteId, 'invite-3'); // 9:00
      });

      test('preserves all invite data fields', () async {
        final testDate = DateTime(2024, 1, 15, 10, 30, 45);
        final invite = InviteRequest(
          inviteId: 'invite-123',
          roomId: 'room-456',
          roomName: 'Test Room',
          inviterDeviceId: 'device-789',
          inviterName: 'John Doe',
          createdAt: testDate,
        );

        await dbService.upsertInviteRequest(invite);

        final invites = await dbService.getInviteRequests();
        final retrieved = invites.first;

        expect(retrieved.inviteId, invite.inviteId);
        expect(retrieved.roomId, invite.roomId);
        expect(retrieved.roomName, invite.roomName);
        expect(retrieved.inviterDeviceId, invite.inviterDeviceId);
        expect(retrieved.inviterName, invite.inviterName);
        expect(retrieved.createdAt, invite.createdAt);
      });
    });

    group('deleteInviteRequest', () {
      test('deletes invite by inviteId', () async {
        final invite = InviteRequest(
          inviteId: 'invite-123',
          roomId: 'room-456',
          roomName: 'Test Room',
          inviterDeviceId: 'device-789',
          inviterName: 'John Doe',
          createdAt: DateTime(2024, 1, 15),
        );

        await dbService.upsertInviteRequest(invite);
        expect((await dbService.getInviteRequests()).length, 1);

        final deleteCount = await dbService.deleteInviteRequest('invite-123');
        expect(deleteCount, 1);

        final invites = await dbService.getInviteRequests();
        expect(invites, isEmpty);
      });

      test('returns 0 when inviteId does not exist', () async {
        final deleteCount = await dbService.deleteInviteRequest(
          'nonexistent-invite',
        );
        expect(deleteCount, 0);
      });

      test('deletes only specified invite', () async {
        final invite1 = InviteRequest(
          inviteId: 'invite-1',
          roomId: 'room-1',
          roomName: 'Room 1',
          inviterDeviceId: 'device-1',
          inviterName: 'User 1',
          createdAt: DateTime(2024, 1, 15),
        );

        final invite2 = InviteRequest(
          inviteId: 'invite-2',
          roomId: 'room-2',
          roomName: 'Room 2',
          inviterDeviceId: 'device-2',
          inviterName: 'User 2',
          createdAt: DateTime(2024, 1, 16),
        );

        await dbService.upsertInviteRequest(invite1);
        await dbService.upsertInviteRequest(invite2);

        await dbService.deleteInviteRequest('invite-1');

        final invites = await dbService.getInviteRequests();
        expect(invites.length, 1);
        expect(invites.first.inviteId, 'invite-2');
      });
    });

    group('deleteInviteRequestsByRoom', () {
      test('deletes all invites for specified room', () async {
        final invite1 = InviteRequest(
          inviteId: 'invite-1',
          roomId: 'room-123',
          roomName: 'Target Room',
          inviterDeviceId: 'device-1',
          inviterName: 'User 1',
          createdAt: DateTime(2024, 1, 15),
        );

        final invite2 = InviteRequest(
          inviteId: 'invite-2',
          roomId: 'room-123',
          roomName: 'Target Room',
          inviterDeviceId: 'device-2',
          inviterName: 'User 2',
          createdAt: DateTime(2024, 1, 16),
        );

        final invite3 = InviteRequest(
          inviteId: 'invite-3',
          roomId: 'room-456',
          roomName: 'Other Room',
          inviterDeviceId: 'device-3',
          inviterName: 'User 3',
          createdAt: DateTime(2024, 1, 17),
        );

        await dbService.upsertInviteRequest(invite1);
        await dbService.upsertInviteRequest(invite2);
        await dbService.upsertInviteRequest(invite3);

        final deleteCount = await dbService.deleteInviteRequestsByRoom(
          'room-123',
        );
        expect(deleteCount, 2);

        final invites = await dbService.getInviteRequests();
        expect(invites.length, 1);
        expect(invites.first.roomId, 'room-456');
      });

      test('returns 0 when no invites for room', () async {
        final invite = InviteRequest(
          inviteId: 'invite-1',
          roomId: 'room-123',
          roomName: 'Room',
          inviterDeviceId: 'device-1',
          inviterName: 'User 1',
          createdAt: DateTime(2024, 1, 15),
        );

        await dbService.upsertInviteRequest(invite);

        final deleteCount = await dbService.deleteInviteRequestsByRoom(
          'room-nonexistent',
        );
        expect(deleteCount, 0);

        final invites = await dbService.getInviteRequests();
        expect(invites.length, 1); // Original invite still there
      });

      test('deletes nothing when no invites exist', () async {
        final deleteCount = await dbService.deleteInviteRequestsByRoom(
          'room-123',
        );
        expect(deleteCount, 0);
      });
    });

    group('integration tests', () {
      test('complete invite lifecycle', () async {
        // Insert invite
        final invite = InviteRequest(
          inviteId: 'invite-123',
          roomId: 'room-456',
          roomName: 'Test Room',
          inviterDeviceId: 'device-789',
          inviterName: 'John Doe',
          createdAt: DateTime(2024, 1, 15),
        );

        await dbService.upsertInviteRequest(invite);

        // Verify it's there
        var invites = await dbService.getInviteRequests();
        expect(invites.length, 1);

        // Delete it
        await dbService.deleteInviteRequest('invite-123');

        // Verify it's gone
        invites = await dbService.getInviteRequests();
        expect(invites, isEmpty);
      });

      test('multiple rooms and invites', () async {
        // Create 3 invites for room-1, 2 for room-2
        for (int i = 1; i <= 3; i++) {
          await dbService.upsertInviteRequest(
            InviteRequest(
              inviteId: 'room1-invite-$i',
              roomId: 'room-1',
              roomName: 'Room 1',
              inviterDeviceId: 'device-$i',
              inviterName: 'User $i',
              createdAt: DateTime(2024, 1, i),
            ),
          );
        }

        for (int i = 1; i <= 2; i++) {
          await dbService.upsertInviteRequest(
            InviteRequest(
              inviteId: 'room2-invite-$i',
              roomId: 'room-2',
              roomName: 'Room 2',
              inviterDeviceId: 'device-$i',
              inviterName: 'User $i',
              createdAt: DateTime(2024, 1, i + 10),
            ),
          );
        }

        // Verify total count
        var invites = await dbService.getInviteRequests();
        expect(invites.length, 5);

        // Delete room-1 invites
        await dbService.deleteInviteRequestsByRoom('room-1');

        // Verify only room-2 invites remain
        invites = await dbService.getInviteRequests();
        expect(invites.length, 2);
        expect(invites.every((i) => i.roomId == 'room-2'), true);
      });
    });
  });
}
