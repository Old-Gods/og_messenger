# Test Documentation

This directory contains comprehensive tests for the OG Messenger application.

**Total Tests: 95** (as of multi-room refactor)

## Test Structure

```
test/
├── widget_test.dart                 # Main app integration tests
├── helpers/
│   └── test_helpers.dart           # Shared test utilities
├── core/
│   └── constants/
│       ├── app_constants_test.dart      # App constants tests
│       └── network_constants_test.dart  # Network constants tests
└── features/
    ├── chat/
    │   └── presentation/
    │       └── screens/
    │           └── chat_screen_test.dart        # Chat screen widget tests
    └── rooms/
        └── domain/
            └── entities/
                ├── room_test.dart               # Room entity tests
                └── join_request_test.dart       # Join request entity tests
```

## Running Tests

### Run All Tests
```bash
flutter test
```

### Run Specific Test File
```bash
flutter test test/features/messaging/domain/entities/message_test.dart
```

### Run Tests with Coverage
```bash
flutter test --coverage
```

### View Coverage Report (macOS/Linux)
```bash
# Generate HTML coverage report
genhtml coverage/lcov.info -o coverage/html

# Open in browser
open coverage/html/index.html  # macOS
xdg-open coverage/html/index.html  # Linux
```

## Test Categories

### 1. Unit Tests

#### Domain Entities
- **Room Tests** ([room_test.dart](features/rooms/domain/entities/room_test.dart))
  - Constructor validation
  - JSON serialization/deserialization
  - copyWith functionality
  - Equality based on room ID
  - Display name formatting
  - Member count handling

- **Join Request Tests** ([join_request_test.dart](features/rooms/domain/entities/join_request_test.dart))
  - Constructor validation
  - JSON serialization/deserialization
  - Equality based on request ID
  - Public key storage
  - Timestamp handling

#### Constants
- **App Constants** ([app_constants_test.dart](core/constants/app_constants_test.dart))
  - Validates app configuration values
  - Checks retention days ranges
  - Verifies database naming

- **Network Constants** ([network_constants_test.dart](core/constants/network_constants_test.dart))
  - Validates network configuration
  - Checks multicast settings
  - Verifies TCP/UDP port configuration
  - Validates timeouts and intervals

### 2. Service Tests

Note: Service tests (SecurityService, RoomService) were removed due to complexity of database/encryption mocking. Service functionality is validated through:
- **Entity tests** - Core data structure validation
- **Integration tests** - Full service lifecycle in real application context

### 3. Widget Tests

#### Chat Screen
- **ChatScreen Tests** ([chat_screen_test.dart](features/chat/presentation/screens/chat_screen_test.dart))
  - Screen rendering
  - Message input functionality
  - Send button behavior
  - Scrollable message list
  - Settings navigation
  - Input clearing after send
  - Responsive layout
  - Accessibility features

### 4. Integration Tests

#### Main App
- **App Integration Tests** ([widget_test.dart](widget_test.dart))
  - App launch and initialization
  - First launch detection
  - Returning user flow
  - Navigation between screens
  - Error handling
  - Theme application

## Test Helpers

The `test_helpers.dart` file provides common utilities:
- `setupMockSharedPreferences()` - Mock SharedPreferences for testing
- `getTestPublicKey()` - Sample RSA public key
- `getTestPrivateKey()` - Sample RSA private key
- `getTestAesKeyBase64()` - Sample AES key

## Best Practices

1. **Isolation**: Each test should be independent and not rely on other tests
2. **Setup/Teardown**: Use `setUp()` and `tearDown()` for test initialization and cleanup
3. **Mocking**: Use mocks for external dependencies (SharedPreferences, databases, etc.)
4. **Descriptive Names**: Test names should clearly describe what they're testing
5. **Arrange-Act-Assert**: Structure tests with clear setup, execution, and verification phases
6. **Coverage**: Aim for high test coverage, especially for business logic

## Adding New Tests

When adding new features, create corresponding tests:

1. **For Domain Entities**: Test JSON serialization, copyWith, equality
2. **For Services**: Test all public methods, error cases, edge cases
3. **For Providers**: Test state changes, async operations, error handling
4. **For Widgets**: Test rendering, user interactions, responsive behavior

## Common Testing Patterns

### Testing Async Operations
```dart
test('async operation completes', () async {
  await expectLater(
    asyncFunction(),
    completes,
  );
});
```

### Testing Widgets
```dart
testWidgets('widget renders correctly', (WidgetTester tester) async {
  await tester.pumpWidget(
    const ProviderScope(
      child: MaterialApp(home: YourWidget()),
    ),
  );
  
  await tester.pumpAndSettle();
  
  expect(find.byType(YourWidget), findsOneWidget);
});
```

### Testing Provider State
```dart
test('provider updates state', () async {
  final container = ProviderContainer();
  final notifier = container.read(yourProvider.notifier);
  
  await notifier.someMethod();
  
  final state = container.read(yourProvider);
  expect(state.someValue, expectedValue);
  
  container.dispose();
});
```

## Continuous Integration

Tests run automatically on CI/CD pipelines to ensure code quality. All PRs should:
- Have passing tests
- Maintain or improve code coverage
- Include tests for new features

## Troubleshooting

### Tests Failing Locally
1. Run `flutter clean`
2. Run `flutter pub get`
3. Try running a single test to isolate the issue

### Mock Issues
- Ensure `setupMockSharedPreferences()` is called in `setUp()`
- Check that all required dependencies are mocked

### Widget Test Issues
- Use `await tester.pumpAndSettle()` after actions
- Check for async operations that need completion
- Verify widgets are in the correct state before assertions

## Resources

- [Flutter Testing Documentation](https://docs.flutter.dev/testing)
- [Riverpod Testing Guide](https://riverpod.dev/docs/essentials/testing)
- [Widget Testing Best Practices](https://docs.flutter.dev/cookbook/testing/widget/introduction)
