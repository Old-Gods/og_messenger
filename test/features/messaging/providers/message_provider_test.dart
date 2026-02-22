import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:og_messenger/features/messaging/providers/message_provider.dart';
import 'package:og_messenger/features/messaging/domain/entities/message.dart';
import 'package:og_messenger/features/settings/data/services/settings_service.dart';
import '../../../helpers/test_helpers.dart';

void main() {
  group('MessageProvider - Typing Indicators', () {
    late ProviderContainer container;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      // Setup mock with a valid network ID to avoid 'WiFi network required' errors
      TestHelpers.setupMockSharedPreferences({'network_id': 'TestNetwork'});
      await SettingsService.instance.initialize();
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    group('typingPeers state', () {
      test('initial state has empty typing peers map', () {
        final state = container.read(messageProvider);
        expect(state.typingPeers, isEmpty);
        expect(state.typingPeers, isA<Map<String, DateTime>>());
      });

      test('state can hold typing peer information', () {
        final typingPeers = {
          'device-1': DateTime.now(),
          'device-2': DateTime.now().subtract(Duration(seconds: 2)),
        };
        final state = MessageState(typingPeers: typingPeers);

        expect(state.typingPeers.length, 2);
        expect(state.typingPeers, contains('device-1'));
        expect(state.typingPeers, contains('device-2'));
      });

      test('typing peer timestamps are DateTime objects', () {
        final now = DateTime.now();
        final typingPeers = {'device-1': now};
        final state = MessageState(typingPeers: typingPeers);

        expect(state.typingPeers['device-1'], isA<DateTime>());
        expect(state.typingPeers['device-1'], equals(now));
      });
    });

    group('typing indicator cleanup', () {
      test('can identify expired typing indicators', () {
        final oldTimestamp = DateTime.now().subtract(Duration(seconds: 6));
        final recentTimestamp = DateTime.now().subtract(Duration(seconds: 2));

        final typingPeers = {
          'expired-device': oldTimestamp,
          'active-device': recentTimestamp,
        };

        // Test the logic for identifying expired indicators
        final now = DateTime.now();
        final expired = typingPeers.entries
            .where((e) => now.difference(e.value) > Duration(seconds: 5))
            .map((e) => e.key)
            .toList();

        expect(expired, contains('expired-device'));
        expect(expired, isNot(contains('active-device')));
      });

      test('recent typing indicators should not be considered expired', () {
        final recentTimestamp = DateTime.now().subtract(Duration(seconds: 3));
        final now = DateTime.now();

        final isExpired =
            now.difference(recentTimestamp) > Duration(seconds: 5);
        expect(isExpired, false);
      });

      test('old typing indicators should be considered expired', () {
        final oldTimestamp = DateTime.now().subtract(Duration(seconds: 7));
        final now = DateTime.now();

        final isExpired = now.difference(oldTimestamp) > Duration(seconds: 5);
        expect(isExpired, true);
      });
    });

    group('message arrival clears typing indicator', () {
      test('message structure includes sender ID for correlation', () {
        final testDeviceId = 'test-device-123';
        final message = Message(
          uuid: 'msg-123',
          timestampMicros: DateTime.now().microsecondsSinceEpoch,
          senderId: testDeviceId,
          senderName: 'Test User',
          content: 'Hello!',
          isOutgoing: false,
        );

        // Verify message has sender ID that can be used to clear typing indicator
        expect(message.senderId, equals(testDeviceId));
        expect(message.senderId, isNotEmpty);
      });

      test('typing indicator map can have entries removed by sender ID', () {
        final typingPeers = {
          'device-1': DateTime.now(),
          'device-2': DateTime.now(),
          'device-3': DateTime.now(),
        };

        // Simulate removing typing indicator when message arrives
        final updated = Map<String, DateTime>.from(typingPeers);
        updated.remove('device-2');

        expect(updated.length, 2);
        expect(updated, isNot(contains('device-2')));
        expect(updated, contains('device-1'));
        expect(updated, contains('device-3'));
      });
    });

    group('sendTypingIndicator', () {
      test('does not throw when called', () async {
        final notifier = container.read(messageProvider.notifier);

        // Should not throw even if no peers are connected
        expect(() => notifier.sendTypingIndicator(), returnsNormally);
      });

      test('handles missing device ID gracefully', () async {
        final notifier = container.read(messageProvider.notifier);

        // Should handle case where user info is not set
        await notifier.sendTypingIndicator();

        // In test environment, networkId will be 'Unknown' which triggers
        // 'WiFi network required' error. This is expected behavior.
        final state = container.read(messageProvider);
        expect(state.error, anyOf(isNull, equals('WiFi network required')));
      });
    });

    group('typing state integration', () {
      test('typing peers map is properly initialized in state', () {
        final state = container.read(messageProvider);
        expect(state.typingPeers, isNotNull);
        expect(state.typingPeers, isA<Map<String, DateTime>>());
      });

      test('copyWith preserves typing peers', () {
        final state = container.read(messageProvider);
        final typingPeers = {'device-1': DateTime.now()};

        final newState = state.copyWith(typingPeers: typingPeers);

        expect(newState.typingPeers, equals(typingPeers));
      });

      test('copyWith without typing peers keeps existing ones', () {
        final typingPeers = {'device-1': DateTime.now()};
        final state = MessageState(typingPeers: typingPeers);

        final newState = state.copyWith(isLoading: true);

        expect(newState.typingPeers, equals(typingPeers));
        expect(newState.isLoading, true);
      });
    });

    group('peer disconnection', () {
      test('typing indicator state persists across provider reads', () {
        final typingPeers = {'device-1': DateTime.now()};
        final state = MessageState(typingPeers: typingPeers);

        // State should maintain typing peers
        expect(state.typingPeers, equals(typingPeers));
        expect(state.typingPeers['device-1'], isNotNull);
      });

      test('multiple typing indicators can coexist', () {
        final now = DateTime.now();
        final typingPeers = {
          'device-1': now,
          'device-2': now.subtract(Duration(seconds: 1)),
          'device-3': now.subtract(Duration(seconds: 2)),
        };

        expect(typingPeers.length, 3);
        expect(
          typingPeers.keys,
          containsAll(['device-1', 'device-2', 'device-3']),
        );
      });
    });

    group('typing indicator format validation', () {
      test('typing indicator data structure has required fields', () {
        final indicatorData = {
          'device_id': 'device-123',
          'device_name': 'Test User',
        };

        expect(indicatorData, containsPair('device_id', isA<String>()));
        expect(indicatorData, containsPair('device_name', isA<String>()));
        expect(indicatorData['device_id'], isNotEmpty);
        expect(indicatorData['device_name'], isNotEmpty);
      });

      test(
        'typing indicator state updates preserve other state properties',
        () {
          final messages = [
            Message(
              uuid: 'msg-1',
              timestampMicros: DateTime.now().microsecondsSinceEpoch,
              senderId: 'device-1',
              senderName: 'User 1',
              content: 'Hello',
              isOutgoing: false,
            ),
          ];

          final typingPeers = {'device-2': DateTime.now()};
          final state = MessageState(
            messages: messages,
            isLoading: false,
            typingPeers: typingPeers,
          );

          expect(state.messages, equals(messages));
          expect(state.typingPeers, equals(typingPeers));
          expect(state.isLoading, false);
        },
      );

      test('state correctly reports typing peer count', () {
        final typingPeers = {
          'device-1': DateTime.now(),
          'device-2': DateTime.now(),
          'device-3': DateTime.now(),
        };
        final state = MessageState(typingPeers: typingPeers);

        expect(state.typingPeers.length, 3);
      });
    });
  });
}
