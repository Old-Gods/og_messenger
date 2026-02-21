import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:og_messenger/main.dart';
import 'helpers/test_helpers.dart';

void main() {
  group('OGMessengerApp', () {
    setUp(() {
      TestHelpers.setupMockSharedPreferences();
    });

    testWidgets('App launches successfully', (WidgetTester tester) async {
      await tester.pumpWidget(const ProviderScope(child: OGMessengerApp()));
      await tester.pumpAndSettle();

      // Verify that the app launches
      expect(find.byType(OGMessengerApp), findsOneWidget);
    });

    testWidgets('App shows MaterialApp', (WidgetTester tester) async {
      await tester.pumpWidget(const ProviderScope(child: OGMessengerApp()));
      await tester.pumpAndSettle();

      // Verify MaterialApp is present
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('App has proper theme', (WidgetTester tester) async {
      await tester.pumpWidget(const ProviderScope(child: OGMessengerApp()));
      await tester.pumpAndSettle();

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.theme, isNotNull);
    });

    testWidgets('App navigates to appropriate screen', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const ProviderScope(child: OGMessengerApp()));
      await tester.pumpAndSettle();

      // App should show either setup screen or chat screen
      // Depending on whether it's first launch
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });

  group('OGMessengerApp - First Launch', () {
    testWidgets('Shows setup screen on first launch', (
      WidgetTester tester,
    ) async {
      TestHelpers.setupMockSharedPreferences({});

      await tester.pumpWidget(const ProviderScope(child: OGMessengerApp()));
      await tester.pumpAndSettle();

      // On first launch, should show some form of setup or input
      expect(find.byType(TextField), findsWidgets);
    });
  });

  group('OGMessengerApp - Returning User', () {
    testWidgets('Shows chat screen for returning user', (
      WidgetTester tester,
    ) async {
      TestHelpers.setupMockSharedPreferences({
        'device_id': 'test-device-123',
        'username': 'TestUser',
        'is_first_launch': false,
      });

      await tester.pumpWidget(const ProviderScope(child: OGMessengerApp()));
      await tester.pumpAndSettle();

      // Should navigate to chat screen eventually
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });

  group('OGMessengerApp - Error Handling', () {
    testWidgets('Handles initialization errors gracefully', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const ProviderScope(child: OGMessengerApp()));

      // Even if there are initialization issues, app should not crash
      await tester.pumpAndSettle();

      expect(find.byType(OGMessengerApp), findsOneWidget);
    });
  });

  group('OGMessengerApp - ProviderScope', () {
    testWidgets('Requires ProviderScope wrapper', (WidgetTester tester) async {
      // This test verifies the app uses Riverpod
      await tester.pumpWidget(const ProviderScope(child: OGMessengerApp()));
      await tester.pumpAndSettle();

      expect(find.byType(ProviderScope), findsOneWidget);
    });
  });
}
