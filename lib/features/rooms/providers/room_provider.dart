import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../domain/entities/room.dart';
import '../domain/entities/join_request.dart';
import '../data/services/room_service.dart';
import '../../storage/data/services/database_service.dart';
import '../../security/data/services/security_service.dart';
import '../../messaging/data/services/tcp_server_service.dart';
import '../../notifications/data/services/notification_service.dart';
import '../../discovery/providers/discovery_provider.dart';
import '../../settings/providers/settings_provider.dart';

/// Room state
class RoomState {
  final String? activeRoomId;
  final Map<String, Room> availableRooms; // From discovery
  final Map<String, Room> joinedRooms; // Locally joined rooms
  final Map<String, JoinRequest> pendingRequests; // Requests from others
  final Map<String, JoinRequest> outgoingRequests; // Requests sent by us
  final bool isLoading;
  final String? error;

  const RoomState({
    this.activeRoomId,
    this.availableRooms = const {},
    this.joinedRooms = const {},
    this.pendingRequests = const {},
    this.outgoingRequests = const {},
    this.isLoading = false,
    this.error,
  });

  RoomState copyWith({
    String? activeRoomId,
    Map<String, Room>? availableRooms,
    Map<String, Room>? joinedRooms,
    Map<String, JoinRequest>? pendingRequests,
    Map<String, JoinRequest>? outgoingRequests,
    bool? isLoading,
    String? error,
  }) {
    return RoomState(
      activeRoomId: activeRoomId ?? this.activeRoomId,
      availableRooms: availableRooms ?? this.availableRooms,
      joinedRooms: joinedRooms ?? this.joinedRooms,
      pendingRequests: pendingRequests ?? this.pendingRequests,
      outgoingRequests: outgoingRequests ?? this.outgoingRequests,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Room notifier
class RoomNotifier extends Notifier<RoomState> {
  StreamSubscription? _joinRequestSubscription;
  StreamSubscription? _joinResponseSubscription;
  StreamSubscription? _requestResolvedSubscription;

  @override
  RoomState build() {
    // Listen to join requests
    _joinRequestSubscription = TcpServerService.instance.joinRequestStream
        .listen(_handleJoinRequest);

    // Listen to join responses
    _joinResponseSubscription = TcpServerService.instance.joinResponseStream
        .listen(_handleJoinResponse);

    // Listen to request resolved notifications
    _requestResolvedSubscription = TcpServerService
        .instance
        .requestResolvedStream
        .listen(_handleRequestResolved);

    // Clean up subscriptions when provider is disposed
    ref.onDispose(() {
      _joinRequestSubscription?.cancel();
      _joinResponseSubscription?.cancel();
      _requestResolvedSubscription?.cancel();
    });

    // Load joined rooms and pending requests from database after build completes
    Future.microtask(() => _loadState());

    // Sync available rooms from discovery
    ref.listen(discoveryProvider, (previous, next) {
      state = state.copyWith(availableRooms: next.availableRooms);
    });

    return const RoomState();
  }

  /// Load state from database
  Future<void> _loadState() async {
    state = state.copyWith(isLoading: true);

    try {
      // Load joined rooms
      final joinedRoomsList = await RoomService.instance.getJoinedRooms();
      final joinedRoomsMap = <String, Room>{};
      for (final room in joinedRoomsList) {
        joinedRoomsMap[room.roomId] = room;
      }

      // Load pending join requests
      final pendingRequestsList = await DatabaseService.instance
          .getJoinRequests();
      final pendingRequestsMap = <String, JoinRequest>{};
      for (final request in pendingRequestsList) {
        pendingRequestsMap[request.requestId] = request;
      }

      state = state.copyWith(
        joinedRooms: joinedRoomsMap,
        pendingRequests: pendingRequestsMap,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to load room state: $e',
        isLoading: false,
      );
    }
  }

  /// Create a new room
  Future<void> createRoom(String roomName) async {
    state = state.copyWith(isLoading: true);

    try {
      print('🏠 Creating room: $roomName');

      // Create room via service
      final room = await RoomService.instance.createRoom(roomName);

      print('✅ Room created: ${room.roomId}');

      // Reload state from database to ensure consistency
      await _loadState();

      // Set the newly created room as active
      state = state.copyWith(activeRoomId: room.roomId);

      print('✅ Room set as active: ${room.roomId}');
    } catch (e) {
      print('❌ Failed to create room: $e');
      state = state.copyWith(
        error: 'Failed to create room: $e',
        isLoading: false,
      );
    }
  }

  /// Request to join a room
  Future<void> requestJoinRoom(String roomId) async {
    state = state.copyWith(isLoading: true);

    try {
      final room = state.availableRooms[roomId];
      if (room == null) {
        throw Exception('Room not found in available rooms');
      }

      // Check if already a member
      if (state.joinedRooms.containsKey(roomId)) {
        state = state.copyWith(
          error: 'Already a member of this room',
          isLoading: false,
        );
        return;
      }

      // Get online members for this room
      final discoveryNotifier = ref.read(discoveryProvider.notifier);
      final onlineMembers = discoveryNotifier.getOnlineMembersForRoom(roomId);

      if (onlineMembers.isEmpty) {
        state = state.copyWith(
          error: 'No online members found for this room',
          isLoading: false,
        );
        return;
      }

      // Send join request to ALL online members
      final settings = ref.read(settingsProvider);
      final securityService = SecurityService.instance;

      const uuid = Uuid();
      final requestId = uuid.v7().toString();

      final joinRequest = JoinRequest(
        requestId: requestId,
        roomId: roomId,
        roomName: room.roomName,
        requesterDeviceId: settings.deviceId!,
        requesterName: settings.userName!,
        requesterPublicKey: securityService.publicKeyPem!,
        createdAt: DateTime.now(),
      );

      // Send request to ALL online members
      int successCount = 0;
      for (final targetPeer in onlineMembers) {
        final success = await TcpServerService.instance.sendJoinRequest(
          peerAddress: targetPeer.ipAddress,
          peerPort: targetPeer.tcpPort,
          requestId: requestId,
          roomId: roomId,
          roomName: room.roomName,
          requesterDeviceId: settings.deviceId!,
          requesterName: settings.userName!,
          requesterPublicKey: securityService.publicKeyPem!,
          tcpPort: TcpServerService.instance.actualPort!,
        );
        if (success) successCount++;
      }

      if (successCount > 0) {
        // Add to outgoing requests
        final updatedOutgoingRequests = Map<String, JoinRequest>.from(
          state.outgoingRequests,
        );
        updatedOutgoingRequests[requestId] = joinRequest;

        state = state.copyWith(
          outgoingRequests: updatedOutgoingRequests,
          isLoading: false,
        );

        print('✅ Join request sent to $successCount member(s): $requestId');
      } else {
        state = state.copyWith(
          error: 'Failed to send join request to any members',
          isLoading: false,
        );
      }
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to request join: $e',
        isLoading: false,
      );
    }
  }

  /// Handle incoming join request
  void _handleJoinRequest(Map<String, dynamic> data) {
    try {
      final requestId = data['request_id'] as String;
      final roomId = data['room_id'] as String;
      final roomName = data['room_name'] as String;
      final requesterDeviceId = data['requester_device_id'] as String;
      final requesterName = data['requester_name'] as String;
      final requesterPublicKey = data['requester_public_key'] as String;

      print('📥 Received join request: $requestId for room $roomId');

      // Check if we're a member of this room
      if (!state.joinedRooms.containsKey(roomId)) {
        print('⚠️ Ignoring join request for room we are not a member of');
        return;
      }

      // Check for duplicate requests from same user for same room
      final existingRequest = state.pendingRequests.values.firstWhere(
        (req) =>
            req.requesterDeviceId == requesterDeviceId && req.roomId == roomId,
        orElse: () => JoinRequest(
          requestId: '',
          roomId: '',
          roomName: '',
          requesterDeviceId: '',
          requesterName: '',
          requesterPublicKey: '',
          createdAt: DateTime.now(),
        ),
      );

      if (existingRequest.requestId.isNotEmpty) {
        print(
          '⚠️ Ignoring duplicate join request from $requesterName for room $roomId',
        );
        return;
      }

      // Create join request entity
      final joinRequest = JoinRequest(
        requestId: requestId,
        roomId: roomId,
        roomName: roomName,
        requesterDeviceId: requesterDeviceId,
        requesterName: requesterName,
        requesterPublicKey: requesterPublicKey,
        createdAt: DateTime.now(),
      );

      // Store in database
      DatabaseService.instance.insertJoinRequest(joinRequest);

      // Add to pending requests
      final updatedPendingRequests = Map<String, JoinRequest>.from(
        state.pendingRequests,
      );
      updatedPendingRequests[requestId] = joinRequest;

      state = state.copyWith(pendingRequests: updatedPendingRequests);

      // Show notification only if user is NOT currently viewing this room
      // (if they're in the room, they'll see the in-app dialog instead)
      if (state.activeRoomId != roomId) {
        NotificationService.instance.showJoinRequestNotification(
          requesterName: requesterName,
          roomName: roomName,
          requestId: requestId,
          roomId: roomId,
        );
      }

      print('✅ Join request stored: $requestId');
    } catch (e) {
      print('❌ Failed to handle join request: $e');
    }
  }

  /// Accept a join request
  Future<void> acceptJoinRequest(String requestId) async {
    try {
      final request = state.pendingRequests[requestId];
      if (request == null) {
        throw Exception('Join request not found');
      }

      final room = state.joinedRooms[request.roomId];
      if (room == null) {
        throw Exception('Room not found in joined rooms');
      }

      // Get room AES key
      final aesKey = RoomService.instance.getRoomAesKey(request.roomId);
      if (aesKey == null) {
        throw Exception('Room AES key not found');
      }

      // Encrypt AES key with requester's public key
      // Convert AES key bytes to base64 first, then encrypt
      final securityService = SecurityService.instance;
      final aesKeyBase64 = base64Encode(aesKey);
      final encryptedAesKey = securityService.encryptWithPublicKeyPem(
        aesKeyBase64,
        request.requesterPublicKey,
      );

      // Find requester peer
      final discoveryNotifier = ref.read(discoveryProvider.notifier);
      final requesterPeer = discoveryNotifier.getPeer(
        request.requesterDeviceId,
      );

      if (requesterPeer == null) {
        throw Exception('Requester peer not found');
      }

      // Send join response
      await TcpServerService.instance.sendJoinResponse(
        peerAddress: requesterPeer.ipAddress,
        peerPort: requesterPeer.tcpPort,
        requestId: requestId,
        success: true,
        roomId: request.roomId,
        roomName: room.roomName,
        creatorName: room.creatorName,
        encryptedAesKey: encryptedAesKey,
      );

      // Notify all other room members to dismiss this request
      await _notifyRequestResolved(requestId, request.roomId);

      // Remove from pending requests
      await DatabaseService.instance.deleteJoinRequest(requestId);
      final updatedPendingRequests = Map<String, JoinRequest>.from(
        state.pendingRequests,
      );
      updatedPendingRequests.remove(requestId);

      state = state.copyWith(pendingRequests: updatedPendingRequests);

      print('✅ Join request accepted: $requestId');
    } catch (e) {
      print('❌ Failed to accept join request: $e');
      state = state.copyWith(error: 'Failed to accept join request: $e');
    }
  }

  /// Reject a join request
  Future<void> rejectJoinRequest(String requestId) async {
    try {
      final request = state.pendingRequests[requestId];
      if (request == null) {
        throw Exception('Join request not found');
      }

      // Find requester peer
      final discoveryNotifier = ref.read(discoveryProvider.notifier);
      final requesterPeer = discoveryNotifier.getPeer(
        request.requesterDeviceId,
      );

      if (requesterPeer != null) {
        // Send rejection response
        await TcpServerService.instance.sendJoinResponse(
          peerAddress: requesterPeer.ipAddress,
          peerPort: requesterPeer.tcpPort,
          requestId: requestId,
          success: false,
          message: 'Join request rejected',
        );
      }

      // Notify all other room members to dismiss this request
      await _notifyRequestResolved(requestId, request.roomId);

      // Remove from pending requests
      await DatabaseService.instance.deleteJoinRequest(requestId);
      final updatedPendingRequests = Map<String, JoinRequest>.from(
        state.pendingRequests,
      );
      updatedPendingRequests.remove(requestId);

      state = state.copyWith(pendingRequests: updatedPendingRequests);

      print('✅ Join request rejected: $requestId');
    } catch (e) {
      print('❌ Failed to reject join request: $e');
      state = state.copyWith(error: 'Failed to reject join request: $e');
    }
  }

  /// Handle join response
  void _handleJoinResponse(Map<String, dynamic> data) async {
    try {
      final requestId = data['request_id'] as String;
      final success = data['success'] as bool;

      print('📥 Received join response: $requestId (success: $success)');

      // Remove from outgoing requests
      final updatedOutgoingRequests = Map<String, JoinRequest>.from(
        state.outgoingRequests,
      );
      updatedOutgoingRequests.remove(requestId);

      if (success) {
        final roomId = data['room_id'] as String;
        final roomName = data['room_name'] as String;
        final creatorName = data['creator_name'] as String;
        final encryptedAesKey = data['encrypted_aes_key'] as String;

        // Join the room (await to ensure key is stored before messages arrive)
        try {
          await RoomService.instance.joinRoom(
            roomId,
            roomName,
            creatorName,
            encryptedAesKey,
          );

          // Reload joined rooms
          _loadState();

          // Set as active room
          state = state.copyWith(activeRoomId: roomId);

          // Show notification
          NotificationService.instance.showJoinAcceptedNotification(
            roomName: roomName,
            roomId: roomId,
          );

          print('✅ Successfully joined room: $roomId');
        } catch (e) {
          print('❌ Failed to join room: $e');
          state = state.copyWith(error: 'Failed to join room: $e');
        }
      } else {
        final message = data['message'] as String?;
        state = state.copyWith(error: message ?? 'Join request was rejected');
      }

      state = state.copyWith(outgoingRequests: updatedOutgoingRequests);
    } catch (e) {
      print('❌ Failed to handle join response: $e');
    }
  }

  /// Switch active room
  void switchActiveRoom(String? roomId) {
    if (roomId != null && !state.joinedRooms.containsKey(roomId)) {
      state = state.copyWith(error: 'Not a member of this room');
      return;
    }

    state = state.copyWith(activeRoomId: roomId);
    print('🔄 Active room switched to: $roomId');
  }

  /// Leave a room
  Future<void> leaveRoom(String roomId) async {
    state = state.copyWith(isLoading: true);

    try {
      await RoomService.instance.leaveRoom(roomId);

      // Remove from joined rooms
      final updatedJoinedRooms = Map<String, Room>.from(state.joinedRooms);
      updatedJoinedRooms.remove(roomId);

      // Always clear active room when leaving - let user choose next room
      String? newActiveRoomId = state.activeRoomId;
      if (newActiveRoomId == roomId) {
        newActiveRoomId = null;
      }

      state = state.copyWith(
        joinedRooms: updatedJoinedRooms,
        activeRoomId: newActiveRoomId,
        isLoading: false,
      );

      print('✅ Left room: $roomId');
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to leave room: $e',
        isLoading: false,
      );
    }
  }

  /// Notify all other room members to dismiss a resolved join request
  Future<void> _notifyRequestResolved(String requestId, String roomId) async {
    try {
      // Get all online peers who are members of this room
      final discoveryState = ref.read(discoveryProvider);
      final onlineMembers = discoveryState.peers.values
          .where((peer) => peer.rooms.any((r) => r.roomId == roomId))
          .toList();

      // Send notification to all online members
      for (final peer in onlineMembers) {
        await TcpServerService.instance.sendRequestResolved(
          peerAddress: peer.ipAddress,
          peerPort: peer.tcpPort,
          requestId: requestId,
          roomId: roomId,
        );
      }

      print(
        '📤 Notified ${onlineMembers.length} members that request $requestId was resolved',
      );
    } catch (e) {
      print('⚠️ Error notifying request resolved: $e');
    }
  }

  /// Handle incoming request_resolved message
  void _handleRequestResolved(Map<String, dynamic> data) {
    try {
      final requestId = data['request_id'] as String?;
      final roomId = data['room_id'] as String?;

      if (requestId == null || roomId == null) {
        print('⚠️ Invalid request_resolved data: missing fields');
        return;
      }

      // Remove from pending requests if present
      if (state.pendingRequests.containsKey(requestId)) {
        final updatedPendingRequests = Map<String, JoinRequest>.from(
          state.pendingRequests,
        );
        updatedPendingRequests.remove(requestId);

        state = state.copyWith(pendingRequests: updatedPendingRequests);

        // Delete from database
        DatabaseService.instance.deleteJoinRequest(requestId);

        print('✅ Dismissed resolved join request: $requestId');
      }
    } catch (e) {
      print('⚠️ Error handling request_resolved: $e');
    }
  }
}

/// Provider for room management
final roomProvider = NotifierProvider<RoomNotifier, RoomState>(
  () => RoomNotifier(),
);
