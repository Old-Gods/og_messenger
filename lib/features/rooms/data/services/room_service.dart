import 'dart:typed_data';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../../domain/entities/room.dart';
import '../../domain/entities/room_membership.dart';
import '../../../security/data/services/security_service.dart';
import '../../../storage/data/services/database_service.dart';
import '../../../notifications/data/services/notification_service.dart';
import '../../../settings/data/services/settings_service.dart';

/// Service for managing rooms and memberships
class RoomService {
  static final RoomService instance = RoomService._();
  RoomService._();

  bool _initialized = false;

  /// Initialize the room service
  Future<void> initialize() async {
    if (_initialized) return;
    print('🏠 Initializing RoomService...');
    _initialized = true;
  }

  /// Create a new room
  Future<Room> createRoom(String name) async {
    print('🏠 Creating room: $name');

    // Generate room ID
    const uuid = Uuid();
    final roomId = uuid.v7().toString();

    // Generate AES-256 key for the room
    final aesKey = SecurityService.instance.generateRoomAesKey();

    // Store the key
    await SecurityService.instance.addRoomKey(roomId, aesKey);

    // Get device info for creator
    final creatorDeviceId = SettingsService.instance.deviceId!;
    final creatorName = SettingsService.instance.userName!;

    final now = DateTime.now();
    final room = Room(
      roomId: roomId,
      roomName: name,
      creatorDeviceId: creatorDeviceId,
      creatorName: creatorName,
      createdAt: now,
      lastSeenAt: now,
      isCreator: true,
    );

    // Store in database
    await DatabaseService.instance.insertRoom(room);

    // Add membership
    final membership = RoomMembership(
      roomId: roomId,
      roomName: name,
      creatorName: creatorName,
      joinedAt: now,
    );
    await DatabaseService.instance.insertRoomMembership(membership);

    // Create notification channel for the room
    await NotificationService.instance.createRoomChannel(roomId, name);

    print('✅ Room created: $roomId');
    return room;
  }

  /// Join a room (when accepted by existing member)
  Future<void> joinRoom(
    String roomId,
    String roomName,
    String creatorName,
    String encryptedAesKey,
  ) async {
    print('🏠 Joining room: $roomName ($roomId)');

    // Decrypt AES key with device RSA private key
    final decrypted = SecurityService.instance.decryptWithPrivateKey(
      encryptedAesKey,
    );
    final aesKeyBytes = base64Decode(decrypted);

    // Store the room key
    await SecurityService.instance.addRoomKey(roomId, aesKeyBytes);

    // Add membership
    final membership = RoomMembership(
      roomId: roomId,
      roomName: roomName,
      creatorName: creatorName,
      joinedAt: DateTime.now(),
    );
    await DatabaseService.instance.insertRoomMembership(membership);

    // Create notification channel
    await NotificationService.instance.createRoomChannel(roomId, roomName);

    print('✅ Joined room: $roomId');
  }

  /// Leave a room (complete cleanup)
  Future<void> leaveRoom(String roomId) async {
    print('🏠 Leaving room: $roomId');

    // Get room name before deleting
    final memberships = await DatabaseService.instance.getRoomMemberships();
    final membership = memberships.where((m) => m.roomId == roomId).firstOrNull;

    // Remove from database
    await DatabaseService.instance.deleteMembership(roomId);
    await DatabaseService.instance.deleteRoom(roomId);

    // Delete all messages in the room
    await DatabaseService.instance.deleteMessagesByRoom(roomId);

    // Delete join requests for this room
    await DatabaseService.instance.deleteJoinRequestsByRoom(roomId);

    // Remove encryption key
    await SecurityService.instance.removeRoomKey(roomId);

    // Delete notification channel
    if (membership != null) {
      await NotificationService.instance.deleteRoomChannel(roomId);
    }

    print('✅ Left room: $roomId');
  }

  /// Get all joined rooms
  Future<List<Room>> getJoinedRooms() async {
    final memberships = await DatabaseService.instance.getRoomMemberships();

    final rooms = <Room>[];
    for (final membership in memberships) {
      final room = Room(
        roomId: membership.roomId,
        roomName: membership.roomName,
        creatorDeviceId: '', // Not stored in membership
        creatorName: membership.creatorName,
        createdAt: membership.joinedAt,
        lastSeenAt: DateTime.now(),
        isCreator: false, // Will be updated from rooms table if available
      );
      rooms.add(room);
    }

    return rooms;
  }

  /// Check if user is member of a room
  Future<bool> isRoomMember(String roomId) async {
    return await DatabaseService.instance.isRoomMember(roomId);
  }

  /// Get AES key for a room
  Uint8List? getRoomAesKey(String roomId) {
    return SecurityService.instance.getRoomAesKey(roomId);
  }
}
