import 'package:flutter_test/flutter_test.dart';
import 'package:og_messenger/features/rooms/domain/entities/invite_request.dart';
import 'package:og_messenger/features/rooms/providers/room_provider.dart';

void main() {
  group('RoomProvider - Invite State Management', () {
    test('initial state has empty receivedInvites', () {
      const initialState = RoomState();
      expect(initialState.receivedInvites, isEmpty);
    });

    test('copyWith can update receivedInvites', () {
      const initialState = RoomState();

      final invite = InviteRequest(
        inviteId: 'invite-123',
        roomId: 'room-456',
        roomName: 'Test Room',
        inviterDeviceId: 'device-789',
        inviterName: 'John Doe',
        createdAt: DateTime(2024, 1, 15),
      );

      final updatedState = initialState.copyWith(
        receivedInvites: {'invite-123': invite},
      );

      expect(updatedState.receivedInvites.length, 1);
      expect(updatedState.receivedInvites['invite-123'], invite);
    });

    test('copyWith preserves existing invites when not updating', () {
      final invite = InviteRequest(
        inviteId: 'invite-123',
        roomId: 'room-456',
        roomName: 'Test Room',
        inviterDeviceId: 'device-789',
        inviterName: 'John Doe',
        createdAt: DateTime(2024, 1, 15),
      );

      final stateWithInvite = RoomState(
        receivedInvites: {'invite-123': invite},
      );

      final updatedState = stateWithInvite.copyWith(error: 'Some error');

      expect(updatedState.receivedInvites.length, 1);
      expect(updatedState.receivedInvites['invite-123'], invite);
      expect(updatedState.error, 'Some error');
    });

    test('can add multiple invites to state', () {
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

      final state = RoomState(
        receivedInvites: {'invite-1': invite1, 'invite-2': invite2},
      );

      expect(state.receivedInvites.length, 2);
      expect(state.receivedInvites['invite-1'], invite1);
      expect(state.receivedInvites['invite-2'], invite2);
    });

    test('can remove invite from state', () {
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

      final stateWithInvites = RoomState(
        receivedInvites: {'invite-1': invite1, 'invite-2': invite2},
      );

      // Remove invite-1
      final updatedInvites = Map<String, InviteRequest>.from(
        stateWithInvites.receivedInvites,
      );
      updatedInvites.remove('invite-1');

      final updatedState = stateWithInvites.copyWith(
        receivedInvites: updatedInvites,
      );

      expect(updatedState.receivedInvites.length, 1);
      expect(updatedState.receivedInvites.containsKey('invite-1'), false);
      expect(updatedState.receivedInvites['invite-2'], invite2);
    });

    test('can update existing invite in state', () {
      final invite = InviteRequest(
        inviteId: 'invite-123',
        roomId: 'room-456',
        roomName: 'Test Room',
        inviterDeviceId: 'device-789',
        inviterName: 'John Doe',
        createdAt: DateTime(2024, 1, 15),
      );

      final stateWithInvite = RoomState(
        receivedInvites: {'invite-123': invite},
      );

      // Update the invite
      final updatedInvite = InviteRequest(
        inviteId: 'invite-123',
        roomId: 'room-456',
        roomName: 'Updated Room Name',
        inviterDeviceId: 'device-789',
        inviterName: 'John Doe',
        createdAt: DateTime(2024, 1, 16),
      );

      final updatedState = stateWithInvite.copyWith(
        receivedInvites: {'invite-123': updatedInvite},
      );

      expect(updatedState.receivedInvites.length, 1);
      expect(
        updatedState.receivedInvites['invite-123']?.roomName,
        'Updated Room Name',
      );
    });

    test('receivedInvites is independent of other state properties', () {
      final invite = InviteRequest(
        inviteId: 'invite-123',
        roomId: 'room-456',
        roomName: 'Test Room',
        inviterDeviceId: 'device-789',
        inviterName: 'John Doe',
        createdAt: DateTime(2024, 1, 15),
      );

      final state = RoomState(
        receivedInvites: {'invite-123': invite},
        isLoading: true,
        error: 'Some error',
      );

      expect(state.receivedInvites.length, 1);
      expect(state.isLoading, true);
      expect(state.error, 'Some error');
    });

    test('empty invites map is different from null', () {
      const state1 = RoomState();
      final state2 = state1.copyWith(receivedInvites: {});

      expect(state1.receivedInvites, isEmpty);
      expect(state2.receivedInvites, isEmpty);
    });

    test('can clear all invites', () {
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

      final stateWithInvites = RoomState(
        receivedInvites: {'invite-1': invite1, 'invite-2': invite2},
      );

      expect(stateWithInvites.receivedInvites.length, 2);

      final clearedState = stateWithInvites.copyWith(receivedInvites: {});

      expect(clearedState.receivedInvites, isEmpty);
    });

    test('invite lookups work correctly', () {
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

      final state = RoomState(
        receivedInvites: {'invite-1': invite1, 'invite-2': invite2},
      );

      // Test successful lookup
      expect(state.receivedInvites['invite-1'], invite1);
      expect(state.receivedInvites['invite-2'], invite2);

      // Test failed lookup
      expect(state.receivedInvites['invite-3'], null);
    });

    test('invites for specific room can be filtered', () {
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

      final state = RoomState(
        receivedInvites: {
          'invite-1': invite1,
          'invite-2': invite2,
          'invite-3': invite3,
        },
      );

      // Filter invites for room-123
      final room123Invites = state.receivedInvites.values
          .where((invite) => invite.roomId == 'room-123')
          .toList();

      expect(room123Invites.length, 2);
      expect(room123Invites.every((i) => i.roomId == 'room-123'), true);
    });

    test('invites can be sorted by creation time', () {
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

      final state = RoomState(
        receivedInvites: {
          'invite-1': invite1,
          'invite-2': invite2,
          'invite-3': invite3,
        },
      );

      // Sort by creation time (newest first)
      final sortedInvites = state.receivedInvites.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      expect(sortedInvites[0].inviteId, 'invite-2'); // 11:00
      expect(sortedInvites[1].inviteId, 'invite-1'); // 10:00
      expect(sortedInvites[2].inviteId, 'invite-3'); // 9:00
    });
  });
}
