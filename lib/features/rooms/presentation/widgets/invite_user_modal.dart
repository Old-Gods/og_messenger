import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuzzywuzzy/fuzzywuzzy.dart';
import '../../../rooms/providers/room_provider.dart';

/// Modal for selecting users to invite to a room
class InviteUserModal extends ConsumerStatefulWidget {
  final String roomId;
  final List<dynamic> onlineMembers;
  final List<dynamic> onlineUsers;

  const InviteUserModal({
    super.key,
    required this.roomId,
    required this.onlineMembers,
    required this.onlineUsers,
  });

  @override
  ConsumerState<InviteUserModal> createState() => _InviteUserModalState();
}

class _InviteUserModalState extends ConsumerState<InviteUserModal> {
  late TextEditingController _searchController;
  late FocusNode _searchFocusNode;
  List<dynamic> _filteredUsers = [];
  String _selectedUserId = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
    _filteredUsers = List.from(widget.onlineUsers);
    _searchFocusNode.requestFocus();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _filterUsers(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredUsers = List.from(widget.onlineUsers);
      });
      return;
    }

    final results = <dynamic>[];

    for (final user in widget.onlineUsers) {
      final score = tokenSetRatio(
        query.toLowerCase(),
        user.deviceName.toString().toLowerCase(),
      );

      if (score > 40) {
        results.add(user);
      }
    }

    // Sort by score (highest first)
    results.sort((a, b) {
      final scoreA = tokenSetRatio(
        query.toLowerCase(),
        a.deviceName.toString().toLowerCase(),
      );
      final scoreB = tokenSetRatio(
        query.toLowerCase(),
        b.deviceName.toString().toLowerCase(),
      );
      return scoreB.compareTo(scoreA);
    });

    setState(() {
      _filteredUsers = results;
    });
  }

  void _selectUser(dynamic user) {
    setState(() {
      _selectedUserId = user.deviceId as String;
    });
  }

  Future<void> _sendInvite() async {
    if (_selectedUserId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a user')));
      return;
    }

    Navigator.pop(context);

    await ref
        .read(roomProvider.notifier)
        .sendInvite(widget.roomId, _selectedUserId);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invite sent!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invite Members'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Search field
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: 'Search users...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: _filterUsers,
            ),
          ),

          // User list
          Expanded(
            child: _filteredUsers.isEmpty
                ? Center(
                    child: Text(
                      _searchController.text.isEmpty
                          ? 'No users available'
                          : 'No users found',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = _filteredUsers[index];
                      final isSelected = _selectedUserId == user.deviceId;

                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            user.deviceName
                                .toString()
                                .substring(0, 1)
                                .toUpperCase(),
                          ),
                        ),
                        title: Text(user.deviceName as String),
                        trailing: isSelected
                            ? Container(
                                decoration: const BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              )
                            : null,
                        onTap: () => _selectUser(user),
                      );
                    },
                  ),
          ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: _selectedUserId.isEmpty ? null : _sendInvite,
                  icon: const Icon(Icons.send),
                  label: const Text('Send Invite'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
