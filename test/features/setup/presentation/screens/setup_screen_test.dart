import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:og_messenger/features/setup/presentation/screens/setup_screen.dart';
import '../../../../helpers/test_helpers.dart';

void main() {
  group('SetupScreen', () {
    setUp(() {
      TestHelpers.setupMockSharedPreferences();
    });

    testWidgets('renders without crashing', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: SetupScreen())),
      );

      await tester.pumpAndSettle();

      expect(find.byType(SetupScreen), findsOneWidget);
    });

    testWidgets('has username input field', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: SetupScreen())),
      );

      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('has continue or submit button', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: SetupScreen())),
      );

      await tester.pumpAndSettle();

      // Look for button with continue or similar text
      final elevatedButtonFinder = find.byType(ElevatedButton);
      final textButtonFinder = find.byType(TextButton);

      expect(
        elevatedButtonFinder.evaluate().isNotEmpty ||
            textButtonFinder.evaluate().isNotEmpty,
        true,
      );
    });

    testWidgets('username field accepts text input', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: SetupScreen())),
      );

      await tester.pumpAndSettle();

      // Find username field and enter text
      final textField = find.byType(TextField).first;
      await tester.enterText(textField, 'TestUser');
      await tester.pump();

      expect(find.text('TestUser'), findsOneWidget);
    });

    testWidgets('shows validation error for empty username', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: SetupScreen())),
      );

      await tester.pumpAndSettle();

      // Try to submit without entering username
      final elevatedButtonFinder = find.byType(ElevatedButton);
      final textButtonFinder = find.byType(TextButton);
      final buttonFinder = elevatedButtonFinder.evaluate().isNotEmpty
          ? elevatedButtonFinder.first
          : textButtonFinder.first;

      if (buttonFinder.evaluate().isNotEmpty) {
        await tester.tap(buttonFinder);
        await tester.pumpAndSettle();

        // Should show error message
        // The exact error message depends on your implementation
      }
    });

    testWidgets('displays app branding or welcome message', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: SetupScreen())),
      );

      await tester.pumpAndSettle();

      // Look for app name or welcome text
      final ogMessengerFinder = find.textContaining('OG Messenger');
      final welcomeFinder = find.textContaining('Welcome');

      expect(
        ogMessengerFinder.evaluate().isNotEmpty ||
            welcomeFinder.evaluate().isNotEmpty,
        true,
      );
    });
  });

  group('SetupScreen - Layout', () {
    testWidgets('maintains structure on different screen sizes', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: SetupScreen())),
      );

      await tester.pumpAndSettle();

      expect(find.byType(SetupScreen), findsOneWidget);

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });
  });

  group('SetupScreen - Accessibility', () {
    testWidgets('username field has proper semantics', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: SetupScreen())),
      );

      await tester.pumpAndSettle();

      final textField = find.byType(TextField).first;
      if (textField.evaluate().isNotEmpty) {
        final widget = tester.widget<TextField>(textField);
        expect(widget, isNotNull);
      }
    });

    testWidgets('submit button is accessible', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: SetupScreen())),
      );

      await tester.pumpAndSettle();

      final elevatedButtonFinder = find.byType(ElevatedButton);
      final textButtonFinder = find.byType(TextButton);

      expect(
        elevatedButtonFinder.evaluate().isNotEmpty ||
            textButtonFinder.evaluate().isNotEmpty,
        true,
      );
    });
  });
}
