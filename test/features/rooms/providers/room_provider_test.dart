import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:og_messenger/features/rooms/providers/room_provider.dart';
import 'package:og_messenger/features/rooms/domain/entities/room.dart';
import 'package:og_messenger/features/rooms/data/services/room_service.dart';
import 'package:og_messenger/features/storage/data/services/database_service.dart';
import 'package:og_messenger/features/security/data/services/security_service.dart';
import 'package:og_messenger/features/settings/data/services/settings_service.dart';
import 'package:og_messenger/features/notifications/data/services/notification_service.dart';
import '../../../../helpers/test_helpers.dart';

void main() {
  group('RoomProvider', () {
    late ProviderContainer container;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();

      // Setup mock shared preferences
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

      container = ProviderContainer();

      // Wait for initial state load
      await Future.delayed(const Duration(milliseconds: 100));
    });

    tearDown(() async {
      container.dispose();
      await DatabaseService.instance.close();
    });

    group('initial state', () {
      test('starts with empty state', () {
        final state = container.read(roomProvider);

        expect(state.activeRoomId, isNull);
        expect(state.availableRooms, isEmpty);
        expect(state.joinedRooms, isEmpty);
        expect(state.pendingRequests, isEmpty);
        expect(state.outgoingRequests, isEmpty);
        expect(state.error, isNull);
      });

      test('isLoading becomes false after initial load', () async {
        await Future.delayed(const Duration(milliseconds: 150));
        final state = container.read(roomProvider);

        expect(state.isLoading, false);
      });
    });

    group('createRoom', () {
      test('creates room and sets as active', () async {
        final notifier = container.read(roomProvider.notifier);

        await notifier.createRoom('Test Room');
        await Future.delayed(const Duration(milliseconds: 100));

        final state = container.read(roomProvider);

        expect(state.activeRoomId, isNotNull);
        expect(state.joinedRooms, isNotEmpty);
        expect(state.joinedRooms.values.first.roomName, 'Test Room');
        expect(state.joinedRooms.values.first.isCreator, true);
      });

      test('adds room to joinedRooms', () async {
        final notifier = container.read(roomProvider.notifier);

        await notifier.createRoom('New Room');
        await Future.delayed(const Duration(milliseconds: 100));

        final state = container.read(roomProvider);
        final createdRoom = state.joinedRooms.values.first;

        expect(state.joinedRooms.containsKey(createdRoom.roomId), true);
        expect(state.joinedRooms[createdRoom.roomId]?.roomName, 'New Room');
      });

      test('can create multiple rooms', () async {
        final notifier = container.read(roomProvider.notifier);

        await notifier.createRoom('Room 1');
        await Future.delayed(const Duration(milliseconds: 100));
        await notifier.createRoom('Room 2');
        await Future.delayed(const Duration(milliseconds: 100));

        final state = container.read(roomProvider);

        expect(state.joinedRooms.length, 2);
        final names = state.joinedRooms.values.map((r) => r.roomName).toSet();
        expect(names, contains('Room 1'));
        expect(names, contains('Room 2'));
      });

      test('handles creation errors gracefully', () async {
        final notifier = container.read(roomProvider.notifier);

        // Try to create room with empty name (may cause issues)
        await notifier.createRoom('');
        await Future.delayed(const Duration(milliseconds: 100));

        final state = container.read(roomProvider);
        // Should either have error or successfully create room
        expect(state.isLoading, false);
      });
    });

    group('switchActiveRoom', () {
      test('switches to existing room', () async {
        final notifier = container.read(roomProvider.notifier);

        // Create room
        await notifier.createRoom('Switch Test');
        await Future.delayed(const Duration(milliseconds: 100));

        final state = container.read(roomProvider);
        final roomId = state.activeRoomId!;

        // Switch to null
        notifier.switchActiveRoom(null);
        expect(container.read(roomProvider).activeRoomId, isNull);

        // Switch back
        notifier.switchActiveRoom(roomId);
        expect(container.read(roomProvider).activeRoomId, roomId);
      });

      test('can switch between multiple rooms', () async {
        final notifier = container.read(roomProvider.notifier);

        // Create two rooms
        await notifier.createRoom('Room A');
        await Future.delayed(const Duration(milliseconds: 100));
        final roomAId = container.read(roomProvider).activeRoomId!;

        await notifier.createRoom('Room B');
        await Future.delayed(const Duration(milliseconds: 100));
        final roomBId = container.read(roomProvider).activeRoomId!;

        // Switch to Room A
        notifier.switchActiveRoom(roomAId);
        expect(container.read(roomProvider).activeRoomId, roomAId);

        // Switch to Room B
        notifier.switchActiveRoom(roomBId);
        expect(container.read(roomProvider).activeRoomId, roomBId);
      });

      test('allows switching to null', () async {
        final notifier = container.read(roomProvider.notifier);

        await notifier.createRoom('Test');
        await Future.delayed(const Duration(milliseconds: 100));

        expect(container.read(roomProvider).activeRoomId, isNotNull);

        notifier.switchActiveRoom(null);
        expect(container.read(roomProvider).activeRoomId, isNull);
      });
    });

    group('leaveRoom', () {
      test('removes room from joinedRooms', () async {
        final notifier = container.read(roomProvider.notifier);

        await notifier.createRoom('Leave Test');
        await Future.delayed(const Duration(milliseconds: 100));

        final state = container.read(roomProvider);
        final roomId = state.activeRoomId!;

        await notifier.leaveRoom(roomId);
        await Future.delayed(const Duration(milliseconds: 100));

        final afterLeave = container.read(roomProvider);
        expect(afterLeave.joinedRooms.containsKey(roomId), false);
      });

      test('sets activeRoomId to null when leaving active room', () async {
        final notifier = container.read(roomProvider.notifier);

        await notifier.createRoom('Active Leave');
        await Future.delayed(const Duration(milliseconds: 100));

        final roomId = container.read(roomProvider).activeRoomId!;

        await notifier.leaveRoom(roomId);
        await Future.delayed(const Duration(milliseconds: 100));

        expect(container.read(roomProvider).activeRoomId, isNull);
      });

      test('handles leaving non-existent room', () async {
        final notifier = container.read(roomProvider.notifier);

        // Should not throw
        await notifier.leaveRoom('non-existent-room-id');
        await Future.delayed(const Duration(milliseconds: 100));

        expect(container.read(roomProvider).error, isNull);
      });
    });

    group('state persistence', () {
      test('loads previously created rooms on initialization', () async {
        // Create room in first container
        final notifier1 = container.read(roomProvider.notifier);
        await notifier1.createRoom('Persistent Room');
        await Future.delayed(const Duration(milliseconds: 100));

        final roomId = container.read(roomProvider).activeRoomId!;
        container.dispose();

        // Create new container (simulates app restart)
        final container2 = ProviderContainer();
        await Future.delayed(const Duration(milliseconds: 150));

        final state2 = container2.read(roomProvider);

        expect(state2.joinedRooms.containsKey(roomId), true);
        expect(state2.joinedRooms[roomId]?.roomName, 'Persistent Room');

        container2.dispose();
      });
    });

    group('RoomState', () {
      test('copyWith creates new instance with updated values', () {
        final original = const RoomState(
          activeRoomId: 'room-1',
          isLoading: false,
        );

        final updated = original.copyWith(
          activeRoomId: 'room-2',
          isLoading: true,
        );

        expect(updated.activeRoomId, 'room-2');
        expect(updated.isLoading, true);
        expect(original.activeRoomId, 'room-1');
        expect(original.isLoading, false);
      });

      test('copyWith preserves unspecified values', () {
        final original = const RoomState(
          activeRoomId: 'room-1',
          isLoading: false,
          error: 'Test error',
        );

        final updated = original.copyWith(activeRoomId: 'room-2');

        expect(updated.activeRoomId, 'room-2');
        expect(updated.isLoading, false);
        expect(updated.error, 'Test error');
      });

      test('handles empty collections correctly', () {
        const state = RoomState();

        expect(state.availableRooms, isEmpty);
        expect(state.joinedRooms, isEmpty);
        expect(state.pendingRequests, isEmpty);
        expect(state.outgoingRequests, isEmpty);
      });
    });
  });
}
