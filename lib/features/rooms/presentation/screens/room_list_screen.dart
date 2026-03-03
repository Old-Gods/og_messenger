import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/room_provider.dart';
import '../../domain/entities/room.dart';
import '../../../discovery/providers/discovery_provider.dart';
import '../../../messaging/providers/message_provider.dart';
import '../../../../core/utils/dialog_utils.dart';

/// Screen for managing rooms - available rooms and joined rooms
class RoomListScreen extends ConsumerStatefulWidget {
  const RoomListScreen({super.key});

  @override
  ConsumerState<RoomListScreen> createState() => _RoomListScreenState();
}

class _RoomListScreenState extends ConsumerState<RoomListScreen> {
  bool _servicesInitialized = false;
  int _previousJoinedRoomsCount = 0;
  bool _isFirstLoad = true;
  final Set<String> _shownInviteIds = {};

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    if (_servicesInitialized) return;

    print('🚀 Initializing services from RoomListScreen...');

    // Start TCP server
    final messageNotifier = ref.read(messageProvider.notifier);
    final serverStarted = await messageNotifier.startServer();

    if (!serverStarted) {
      print('❌ Failed to start TCP server');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to start messaging server'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final tcpPort = messageNotifier.serverPort;
    print('✅ TCP server started on port: $tcpPort');

    // Start UDP discovery
    if (tcpPort != null) {
      final discoveryNotifier = ref.read(discoveryProvider.notifier);
      final discoveryStarted = await discoveryNotifier.start(tcpPort);

      if (discoveryStarted) {
        print('✅ UDP discovery started');
        setState(() => _servicesInitialized = true);
      } else {
        print('❌ UDP discovery failed to start');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Discovery service failed to start'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roomState = ref.watch(roomProvider);

    // Initialize the count on first load, don't trigger notification
    if (_isFirstLoad && roomState.joinedRooms.isNotEmpty) {
      _previousJoinedRoomsCount = roomState.joinedRooms.length;
      _isFirstLoad = false;
    }

    // Show snackbar when a new room is joined (but not on first load)
    if (!_isFirstLoad &&
        roomState.joinedRooms.length > _previousJoinedRoomsCount) {
      _previousJoinedRoomsCount = roomState.joinedRooms.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Successfully joined room!'),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.green,
            ),
          );
        }
      });
    }

    // Show snackbar for incoming invites (only for new invites)
    if (roomState.receivedInvites.isNotEmpty) {
      // Get the most recent invite
      final invites = roomState.receivedInvites.values.toList();
      invites.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final latestInvite = invites.first;

      // Only show if we haven't shown this invite before
      if (!_shownInviteIds.contains(latestInvite.inviteId)) {
        _shownInviteIds.add(latestInvite.inviteId);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${latestInvite.inviterName} invited you to ${latestInvite.roomName}',
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ref
                            .read(roomProvider.notifier)
                            .rejectInvite(latestInvite.inviteId);
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.grey.withValues(alpha: 0.3),
                      ),
                      child: const Text(
                        'Ignore',
                        style: TextStyle(color: Colors.black87),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ref
                            .read(roomProvider.notifier)
                            .acceptInvite(latestInvite.inviteId);
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.green.withValues(alpha: 0.8),
                      ),
                      child: const Text(
                        'Accept',
                        style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                duration: const Duration(days: 365),
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.all(16),
              ),
            );
          }
        });
      }
    }

    // Clean up shown invite IDs when invites are removed from state
    _shownInviteIds.removeWhere(
      (id) => !roomState.receivedInvites.containsKey(id),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rooms'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: _buildRoomsList(roomState),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateRoomDialog,
        icon: const Icon(Icons.add),
        label: const Text('Create Room'),
      ),
    );
  }

  /// Build unified rooms list
  Widget _buildRoomsList(RoomState roomState) {
    // Combine all rooms: joined rooms + available rooms
    final allRooms = <String, Room>{};

    // Add joined rooms
    allRooms.addAll(roomState.joinedRooms);

    // Add available rooms (from discovery)
    for (final room in roomState.availableRooms.values) {
      // Only add if not already in joined rooms
      if (!allRooms.containsKey(room.roomId)) {
        allRooms[room.roomId] = room;
      }
    }

    if (allRooms.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _EmptyStateIcon(),
            SizedBox(height: 16),
            Text(
              'No rooms available',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Create a room to get started',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final roomsList = allRooms.values.toList();
    // Sort alphabetically by room name
    roomsList.sort((a, b) => a.roomName.compareTo(b.roomName));

    return ListView.builder(
      itemCount: roomsList.length,
      padding: const EdgeInsets.only(bottom: 80, top: 8),
      itemBuilder: (context, index) {
        final room = roomsList[index];
        final isMember = roomState.joinedRooms.containsKey(room.roomId);
        return _buildRoomCard(room, isMember, roomState);
      },
    );
  }

  /// Build unified room card
  Widget _buildRoomCard(Room room, bool isMember, RoomState roomState) {
    final hasPendingRequest = roomState.outgoingRequests.values.any(
      (req) => req.roomId == room.roomId,
    );

    // Get online member count
    final discoveryNotifier = ref.read(discoveryProvider.notifier);
    final onlineMembers = discoveryNotifier.getOnlineMembersForRoom(
      room.roomId,
    );
    final memberCount = onlineMembers.length;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isMember ? Colors.green : Colors.blue,
          child: Icon(
            isMember ? Icons.check_circle : Icons.public,
            color: Colors.white,
          ),
        ),
        title: Text(
          room.roomName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Created by ${room.creatorName}${memberCount > 0 ? ' • $memberCount online' : ''}',
        ),
        trailing: isMember
            ? IconButton(
                icon: const Icon(Icons.arrow_forward),
                onPressed: () => _enterRoom(room.roomId),
                tooltip: 'Enter room',
              )
            : hasPendingRequest
            ? const Chip(
                label: Text('Pending', style: TextStyle(fontSize: 12)),
                backgroundColor: Colors.orange,
              )
            : IconButton(
                icon: const Icon(Icons.login),
                onPressed: () => _requestJoinRoom(room.roomId),
                tooltip: 'Request to join',
              ),
        onTap: isMember ? () => _enterRoom(room.roomId) : null,
        onLongPress: isMember ? () => _showRoomMenu(room) : null,
      ),
    );
  }

  /// Enter a room (for members only)
  void _enterRoom(String roomId) {
    // Set as active room
    ref.read(roomProvider.notifier).switchActiveRoom(roomId);
    // Navigate to chat
    Navigator.pushNamed(context, '/chat');
  }

  /// Show create room dialog
  void _showCreateRoomDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Room'),
        content: TextField(
          controller: controller,
          maxLength: 50,
          decoration: const InputDecoration(
            hintText: 'Enter room name',
            labelText: 'Room Name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final roomName = controller.text.trim();
              if (roomName.isNotEmpty) {
                Navigator.pop(context);
                _createRoom(roomName);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  /// Show room menu (for joined rooms)
  void _showRoomMenu(Room room) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.exit_to_app),
            title: const Text('Leave Room'),
            onTap: () {
              Navigator.pop(context);
              _leaveRoom(room.roomId);
            },
          ),
        ],
      ),
    );
  }

  /// Create a new room
  void _createRoom(String roomName) {
    ref.read(roomProvider.notifier).createRoom(roomName);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Creating room "$roomName"...')));
  }

  /// Request to join a room
  void _requestJoinRoom(String roomId) {
    ref.read(roomProvider.notifier).requestJoinRoom(roomId);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sending join request...'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Leave a room
  void _leaveRoom(String roomId) {
    DialogUtils.showLeaveRoomDialog(
      context: context,
      ref: ref,
      roomId: roomId,
      onLeave: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Left room'),
            duration: Duration(seconds: 2),
          ),
        );
      },
    );
  }
}

/// Widget for empty state icon that switches based on theme
class _EmptyStateIcon extends StatelessWidget {
  const _EmptyStateIcon();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      Theme.of(context).brightness == Brightness.dark
          ? 'images/og_messenger_rooms.dark.png'
          : 'images/og_messenger_rooms.png',
      width: 128,
    );
  }
}
