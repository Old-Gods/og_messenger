import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/rooms/providers/room_provider.dart';

/// Utility class for common dialogs
class DialogUtils {
  /// Show confirmation dialog for leaving a room
  ///
  /// [onLeave] is called after the user confirms and the room is left
  static void showLeaveRoomDialog({
    required BuildContext context,
    required WidgetRef ref,
    required String roomId,
    VoidCallback? onLeave,
  }) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Leave Room'),
        content: const Text(
          'Are you sure you want to leave this room? '
          'All messages will be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext); // Close dialog
              ref.read(roomProvider.notifier).leaveRoom(roomId);
              onLeave?.call();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }
}
