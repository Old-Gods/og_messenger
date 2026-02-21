import 'package:flutter_test/flutter_test.dart';
import '../../../../helpers/test_helpers.dart';
import '../../../../helpers/mock_database_service.dart';

void main() {
  group('MessageRepository (Integration Tests)', () {
    late TestMessageRepository repository;
    const testDeviceId = 'device-123';
    const testNetworkId = 'test-network';

    setUp(() {
      TestHelpers.setupMockSharedPreferences();
      repository = TestMessageRepository();
    });

    tearDown() {
      repository.clearStorage();
    }

    group('message operations', () {
      test('saves message successfully', () async {
        final now = DateTime.now().microsecondsSinceEpoch;

        await expectLater(
          repository.saveMessage(
            'test-uuid-1',
            now,
            'sender-123',
            'Test Sender',
            'Test message content',
            testDeviceId,
            testNetworkId,
          ),
          completes,
        );
      });

      test('retrieves all messages', () async {
        final messages = await repository.getAllMessages(
          testDeviceId,
          testNetworkId,
        );

        expect(messages, isA<List>());
      });

      test('retrieves messages in correct order', () async {
        final now = DateTime.now().microsecondsSinceEpoch;

        await repository.saveMessage(
          'uuid-1',
          now,
          'sender-1',
          'Sender 1',
          'First message',
          testDeviceId,
          testNetworkId,
        );

        await repository.saveMessage(
          'uuid-2',
          now + 1000000,
          'sender-2',
          'Sender 2',
          'Second message',
          testDeviceId,
          testNetworkId,
        );

        final messages = await repository.getAllMessages(
          testDeviceId,
          testNetworkId,
        );

        expect(messages.length, greaterThanOrEqualTo(2));

        final index1 = messages.indexWhere((m) => m['uuid'] == 'uuid-1');
        final index2 = messages.indexWhere((m) => m['uuid'] == 'uuid-2');

        if (index1 != -1 && index2 != -1) {
          expect(index1, lessThan(index2));
        }
      });
    });

    group('message filtering', () {
      test('filters messages by network', () async {
        final now = DateTime.now().microsecondsSinceEpoch;

        await repository.saveMessage(
          'network1-uuid',
          now,
          'sender-1',
          'Sender 1',
          'Message for network 1',
          testDeviceId,
          'network-1',
        );

        await repository.saveMessage(
          'network2-uuid',
          now,
          'sender-2',
          'Sender 2',
          'Message for network 2',
          testDeviceId,
          'network-2',
        );

        final network1Messages = await repository.getAllMessages(
          testDeviceId,
          'network-1',
        );

        final network2MessagesInResult = network1Messages.where(
          (m) => m['uuid'] == 'network2-uuid',
        );
        expect(network2MessagesInResult, isEmpty);
      });
    });

    group('outgoing flag', () {
      test('correctly sets isOutgoing for own messages', () async {
        final now = DateTime.now().microsecondsSinceEpoch;

        await repository.saveMessage(
          'outgoing-test',
          now,
          testDeviceId,
          'Me',
          'My message',
          testDeviceId,
          testNetworkId,
        );

        final messages = await repository.getAllMessages(
          testDeviceId,
          testNetworkId,
        );

        final savedMessage = messages.firstWhere(
          (m) => m['uuid'] == 'outgoing-test',
        );

        expect(savedMessage['isOutgoing'], true);
      });

      test('correctly sets isOutgoing for received messages', () async {
        final now = DateTime.now().microsecondsSinceEpoch;

        await repository.saveMessage(
          'incoming-test',
          now,
          'other-device-123',
          'Other User',
          'Their message',
          testDeviceId,
          testNetworkId,
        );

        final messages = await repository.getAllMessages(
          testDeviceId,
          testNetworkId,
        );

        final savedMessage = messages.firstWhere(
          (m) => m['uuid'] == 'incoming-test',
        );

        expect(savedMessage['isOutgoing'], false);
      });
    });

    group('message cleanup', () {
      test('deletes old messages', () async {
        final oldTimestamp = DateTime.now()
            .subtract(Duration(days: 40))
            .microsecondsSinceEpoch;

        await repository.saveMessage(
          'old-uuid',
          oldTimestamp,
          'sender-old',
          'Old Sender',
          'Old message',
          testDeviceId,
          testNetworkId,
        );

        final deletedCount = await repository.deleteExpiredMessages();

        expect(deletedCount, greaterThanOrEqualTo(1));
      });

      test('keeps recent messages when cleaning up', () async {
        final recentTimestamp = DateTime.now()
            .subtract(Duration(days: 5))
            .microsecondsSinceEpoch;

        await repository.saveMessage(
          'recent-uuid',
          recentTimestamp,
          'sender-recent',
          'Recent Sender',
          'Recent message',
          testDeviceId,
          testNetworkId,
        );

        await repository.deleteExpiredMessages();

        final messages = await repository.getAllMessages(
          testDeviceId,
          testNetworkId,
        );

        final recentMessages = messages.where(
          (m) => m['uuid'] == 'recent-uuid',
        );
        expect(recentMessages, isNotEmpty);
      });
    });
  });
}
