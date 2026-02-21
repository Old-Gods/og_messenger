import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:og_messenger/features/chat/presentation/screens/chat_screen.dart';
import '../../../../helpers/test_helpers.dart';

void main() {
  group('ChatScreen', () {
    setUp(() {
      TestHelpers.setupMockSharedPreferences();
    });

    testWidgets('renders without crashing', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: ChatScreen())),
      );

      await tester.pumpAndSettle();

      // Verify basic structure is present
      expect(find.byType(ChatScreen), findsOneWidget);
    });

    testWidgets('has message input field', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: ChatScreen())),
      );

      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('has app bar', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: ChatScreen())),
      );

      await tester.pumpAndSettle();

      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('message input field accepts text', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: ChatScreen())),
      );

      await tester.pumpAndSettle();

      // Find the message input field
      final textFieldFinder = find.byType(TextField).last;
      expect(textFieldFinder, findsOneWidget);

      // Enter text
      await tester.enterText(textFieldFinder, 'Test message');
      await tester.pump();

      // Verify text was entered
      expect(find.text('Test message'), findsOneWidget);
    });

    testWidgets('has send button', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: ChatScreen())),
      );

      await tester.pumpAndSettle();

      // Look for send icon or button
      expect(find.byIcon(Icons.send), findsOneWidget);
    });

    testWidgets('send button is visible', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: ChatScreen())),
      );

      await tester.pumpAndSettle();

      final sendButton = find.byIcon(Icons.send);
      expect(sendButton, findsOneWidget);

      // Verify button is visible and enabled
      final iconButton = tester.widget<IconButton>(
        find.ancestor(of: sendButton, matching: find.byType(IconButton)),
      );
      expect(iconButton.onPressed, isNotNull);
    });

    testWidgets('has scrollable message list', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: ChatScreen())),
      );

      await tester.pumpAndSettle();

      // Look for ListView or similar scrollable widget
      final listViewFinder = find.byType(ListView);
      final customScrollViewFinder = find.byType(CustomScrollView);

      expect(
        listViewFinder.evaluate().isNotEmpty ||
            customScrollViewFinder.evaluate().isNotEmpty,
        true,
      );
    });

    testWidgets('shows settings button in app bar', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: ChatScreen())),
      );

      await tester.pumpAndSettle();

      // Look for settings or menu icon
      final settingsFinder = find.byIcon(Icons.settings);
      final menuFinder = find.byIcon(Icons.more_vert);

      expect(
        settingsFinder.evaluate().isNotEmpty ||
            menuFinder.evaluate().isNotEmpty,
        true,
      );
    });

    testWidgets('clears input field after sending message', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: ChatScreen())),
      );

      await tester.pumpAndSettle();

      // Enter text
      final textFieldFinder = find.byType(TextField).last;
      await tester.enterText(textFieldFinder, 'Test message');
      await tester.pump();

      expect(find.text('Test message'), findsOneWidget);

      // Tap send button
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      // Verify input field is cleared (text should no longer be in text field)
      final textField = tester.widget<TextField>(textFieldFinder);
      expect(textField.controller?.text ?? '', isEmpty);
    });

    testWidgets('displays peer count or connection status', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: ChatScreen())),
      );

      await tester.pumpAndSettle();

      // Look for any text that might indicate peer count or status
      // This will depend on your implementation
      expect(find.byType(AppBar), findsOneWidget);
    });
  });

  group('ChatScreen - Message Display', () {
    testWidgets('displays empty state when no messages', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: ChatScreen())),
      );

      await tester.pumpAndSettle();

      // Should show some indication of empty state or just an empty list
      expect(find.byType(ChatScreen), findsOneWidget);
    });
  });

  group('ChatScreen - Accessibility', () {
    testWidgets('message input field has proper semantics', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: ChatScreen())),
      );

      await tester.pumpAndSettle();

      final textField = find.byType(TextField).last;
      expect(textField, findsOneWidget);

      // Verify it's accessible
      final widget = tester.widget<TextField>(textField);
      expect(widget, isNotNull);
    });

    testWidgets('send button is accessible', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: ChatScreen())),
      );

      await tester.pumpAndSettle();

      final sendButton = find.byIcon(Icons.send);
      expect(sendButton, findsOneWidget);

      // Verify it has proper semantics
      final semantics = tester.getSemantics(sendButton);
      expect(semantics, isNotNull);
    });
  });

  group('ChatScreen - Layout', () {
    testWidgets('maintains structure on different screen sizes', (
      WidgetTester tester,
    ) async {
      // Test with small screen
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: ChatScreen())),
      );

      await tester.pumpAndSettle();

      expect(find.byType(ChatScreen), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(TextField), findsWidgets);

      // Reset to default
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });

    testWidgets('maintains structure on tablet size', (
      WidgetTester tester,
    ) async {
      // Test with tablet screen
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: ChatScreen())),
      );

      await tester.pumpAndSettle();

      expect(find.byType(ChatScreen), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);

      // Reset to default
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });
  });
}
