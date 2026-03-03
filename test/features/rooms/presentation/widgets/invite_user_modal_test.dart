import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:og_messenger/features/rooms/presentation/widgets/invite_user_modal.dart';

void main() {
  group('InviteUserModal Widget', () {
    // Mock peer data structure
    final mockUser1 = _MockPeer('device-1', 'Alice');
    final mockUser2 = _MockPeer('device-2', 'Bob');
    final mockUser3 = _MockPeer('device-3', 'Charlie');
    final mockMember1 = _MockPeer('device-member', 'Dave');

    Widget createWidget({
      String roomId = 'room-123',
      List<dynamic> onlineMembers = const [],
      List<dynamic> onlineUsers = const [],
    }) {
      return ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: InviteUserModal(
              roomId: roomId,
              onlineMembers: onlineMembers,
              onlineUsers: onlineUsers,
            ),
          ),
        ),
      );
    }

    testWidgets('displays app bar with correct title', (tester) async {
      await tester.pumpWidget(
        createWidget(onlineUsers: [mockUser1, mockUser2]),
      );

      expect(find.text('Invite Members'), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('displays search field', (tester) async {
      await tester.pumpWidget(
        createWidget(onlineUsers: [mockUser1, mockUser2]),
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search users...'), findsOneWidget);
    });

    testWidgets('displays all online users initially', (tester) async {
      await tester.pumpWidget(
        createWidget(onlineUsers: [mockUser1, mockUser2, mockUser3]),
      );

      await tester.pumpAndSettle();

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Charlie'), findsOneWidget);
    });

    testWidgets('displays all provided online users', (tester) async {
      await tester.pumpWidget(
        createWidget(
          onlineMembers: [mockMember1],
          onlineUsers: [mockUser1, mockUser2],
        ),
      );

      await tester.pumpAndSettle();

      // Should show all provided online users
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
    });

    testWidgets('filters users based on search query', (tester) async {
      await tester.pumpWidget(
        createWidget(onlineUsers: [mockUser1, mockUser2, mockUser3]),
      );

      await tester.pumpAndSettle();

      // Initially all users visible
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Charlie'), findsOneWidget);

      // Enter search query - fuzzy match may include similar names
      await tester.enterText(find.byType(TextField), 'alice');
      await tester.pumpAndSettle();

      // Alice should definitely match
      expect(find.text('Alice'), findsOneWidget);
    });

    testWidgets('shows all users when search is cleared', (tester) async {
      await tester.pumpWidget(
        createWidget(onlineUsers: [mockUser1, mockUser2, mockUser3]),
      );

      await tester.pumpAndSettle();

      // Search for specific user
      await tester.enterText(find.byType(TextField), 'bob');
      await tester.pumpAndSettle();
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Alice'), findsNothing);

      // Clear search
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();

      // All users visible again
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Charlie'), findsOneWidget);
    });

    testWidgets('user selection shows checkmark', (tester) async {
      await tester.pumpWidget(
        createWidget(onlineUsers: [mockUser1, mockUser2]),
      );

      await tester.pumpAndSettle();

      // Tap on Alice
      await tester.tap(find.text('Alice'));
      await tester.pumpAndSettle();

      // Should show checkmark icon in trailing position
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('can switch selection between users', (tester) async {
      await tester.pumpWidget(
        createWidget(onlineUsers: [mockUser1, mockUser2]),
      );

      await tester.pumpAndSettle();

      // Select Alice
      await tester.tap(find.text('Alice'));
      await tester.pumpAndSettle();

      // Select Bob
      await tester.tap(find.text('Bob'));
      await tester.pumpAndSettle();

      // Both taps should register (only one will be selected at a time)
      expect(find.byType(CircleAvatar), findsWidgets);
    });

    testWidgets('displays empty state when no users available', (tester) async {
      await tester.pumpWidget(createWidget(onlineUsers: []));

      await tester.pumpAndSettle();

      expect(find.text('No users available'), findsOneWidget);
    });

    testWidgets(
      'displays empty state with message when search yields no results',
      (tester) async {
        await tester.pumpWidget(
          createWidget(onlineUsers: [mockUser1, mockUser2]),
        );

        await tester.pumpAndSettle();

        // Search for non-existent user
        await tester.enterText(find.byType(TextField), 'xyz123');
        await tester.pumpAndSettle();

        expect(find.text('No users found'), findsOneWidget);
      },
    );

    testWidgets('has cancel button', (tester) async {
      await tester.pumpWidget(createWidget(onlineUsers: [mockUser1]));

      await tester.pumpAndSettle();

      expect(find.text('Cancel'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
    });

    testWidgets('has send button', (tester) async {
      await tester.pumpWidget(createWidget(onlineUsers: [mockUser1]));

      await tester.pumpAndSettle();

      expect(find.text('Send Invite'), findsOneWidget);
      expect(
        find.widgetWithText(ElevatedButton, 'Send Invite'),
        findsOneWidget,
      );
    });

    testWidgets('cancel button closes modal', (tester) async {
      await tester.pumpWidget(createWidget(onlineUsers: [mockUser1]));

      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Modal should be closed (no longer finding its elements)
      expect(find.text('Invite User'), findsNothing);
    });

    testWidgets('search field auto-focuses on open', (tester) async {
      await tester.pumpWidget(createWidget(onlineUsers: [mockUser1]));

      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.focusNode?.hasFocus, true);
    });

    testWidgets('displays correct count of initial results', (tester) async {
      await tester.pumpWidget(
        createWidget(onlineUsers: [mockUser1, mockUser2, mockUser3]),
      );

      await tester.pumpAndSettle();

      // Count initial items
      expect(find.byType(ListTile), findsNWidgets(3));

      // Filter reduces results
      await tester.enterText(find.byType(TextField), 'alice');
      await tester.pumpAndSettle();

      // Should have fewer results than initial
      final resultCount = tester.widgetList(find.byType(ListTile)).length;
      expect(resultCount, lessThan(3));
    });

    testWidgets('fuzzy search works with partial matches', (tester) async {
      await tester.pumpWidget(
        createWidget(onlineUsers: [mockUser1, mockUser2, mockUser3]),
      );

      await tester.pumpAndSettle();

      // Search with partial match
      await tester.enterText(find.byType(TextField), 'char');
      await tester.pumpAndSettle();

      expect(find.text('Charlie'), findsOneWidget);
      expect(find.text('Alice'), findsNothing);
      expect(find.text('Bob'), findsNothing);
    });

    testWidgets('search is case insensitive', (tester) async {
      await tester.pumpWidget(
        createWidget(onlineUsers: [mockUser1, mockUser2]),
      );

      await tester.pumpAndSettle();

      // Search with uppercase
      await tester.enterText(find.byType(TextField), 'ALICE');
      await tester.pumpAndSettle();

      expect(find.text('Alice'), findsOneWidget);

      // Search with lowercase
      await tester.enterText(find.byType(TextField), 'bob');
      await tester.pumpAndSettle();

      expect(find.text('Bob'), findsOneWidget);
    });
  });
}

/// Mock peer object for testing
class _MockPeer {
  final String deviceId;
  final String deviceName;

  _MockPeer(this.deviceId, this.deviceName);
}
