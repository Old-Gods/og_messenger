import 'package:flutter_test/flutter_test.dart';
import 'package:og_messenger/features/messaging/data/repositories/message_repository.dart';
import 'package:og_messenger/features/messaging/domain/entities/message.dart';
import '../../../../helpers/test_helpers.dart';

void main() {
  group('MessageRepository', () {
    late MessageRepository repository;
    const testDeviceId = 'device-123';
    const testNetworkId = 'test-network';

    setUp(() {
      TestHelpers.setupMockSharedPreferences();
      repository = MessageRepository();
    });

    group('message operations', () {
      test('saves message successfully', () async {
        final message = Message(
          uuid: 'test-uuid-1',
          timestampMicros: DateTime.now().microsecondsSinceEpoch,
          senderId: 'sender-123',
          senderName: 'Test Sender',
          content: 'Test message content',
          isOutgoing: true,
        );

        await expectLater(
          repository.saveMessage(message, testDeviceId, testNetworkId),
          completes,
        );
      });

      test('retrieves all messages', () async {
        final messages = await repository.getAllMessages(
          testDeviceId,
          testNetworkId,
        );

        expect(messages, isA<List<Message>>());
      });

      test('retrieves messages in correct order', () async {
        // Save multiple messages
        final message1 = Message(
          uuid: 'uuid-1',
          timestampMicros: DateTime.now().microsecondsSinceEpoch,
          senderId: 'sender-1',
          senderName: 'Sender 1',
          content: 'First message',
          isOutgoing: false,
        );

        final message2 = Message(
          uuid: 'uuid-2',
          timestampMicros: DateTime.now()
              .add(Duration(seconds: 1))
              .microsecondsSinceEpoch,
          senderId: 'sender-2',
          senderName: 'Sender 2',
          content: 'Second message',
          isOutgoing: true,
        );

        await repository.saveMessage(message1, testDeviceId, testNetworkId);
        await repository.saveMessage(message2, testDeviceId, testNetworkId);

        final messages = await repository.getAllMessages(
          testDeviceId,
          testNetworkId,
        );

        // Messages should be ordered by timestamp
        expect(messages.length, greaterThanOrEqualTo(2));

        // Find our test messages
        final testMessages = messages
            .where((m) => m.uuid == 'uuid-1' || m.uuid == 'uuid-2')
            .toList();

        if (testMessages.length >= 2) {
          final index1 = messages.indexOf(testMessages[0]);
          final index2 = messages.indexOf(testMessages[1]);

          // First message should come before second
          expect(index1, lessThan(index2));
        }
      });
    });

    group('message filtering', () {
      test('filters messages by network', () async {
        final message1 = Message(
          uuid: 'network1-uuid',
          timestampMicros: DateTime.now().microsecondsSinceEpoch,
          senderId: 'sender-1',
          senderName: 'Sender 1',
          content: 'Message for network 1',
          isOutgoing: false,
        );

        final message2 = Message(
          uuid: 'network2-uuid',
          timestampMicros: DateTime.now().microsecondsSinceEpoch,
          senderId: 'sender-2',
          senderName: 'Sender 2',
          content: 'Message for network 2',
          isOutgoing: false,
        );

        await repository.saveMessage(message1, testDeviceId, 'network-1');
        await repository.saveMessage(message2, testDeviceId, 'network-2');

        final network1Messages = await repository.getAllMessages(
          testDeviceId,
          'network-1',
        );

        // Should only get messages from network-1
        final network2MessagesInResult = network1Messages.where(
          (m) => m.uuid == 'network2-uuid',
        );
        expect(network2MessagesInResult, isEmpty);
      });
    });

    group('message count', () {
      test('returns correct message count', () async {
        final message = Message(
          uuid: 'count-test-uuid',
          timestampMicros: DateTime.now().microsecondsSinceEpoch,
          senderId: 'sender-count',
          senderName: 'Count Sender',
          content: 'Message for count test',
          isOutgoing: true,
        );

        await repository.saveMessage(message, testDeviceId, 'count-network');

        final messages = await repository.getAllMessages(
          testDeviceId,
          'count-network',
        );

        expect(messages.length, greaterThanOrEqualTo(1));
      });
    });

    group('outgoing flag', () {
      test('correctly sets isOutgoing for own messages', () async {
        final message = Message(
          uuid: 'outgoing-test',
          timestampMicros: DateTime.now().microsecondsSinceEpoch,
          senderId: testDeviceId, // Same as local device ID
          senderName: 'Me',
          content: 'My message',
          isOutgoing: false, // Will be set by repository
        );

        await repository.saveMessage(message, testDeviceId, testNetworkId);

        final messages = await repository.getAllMessages(
          testDeviceId,
          testNetworkId,
        );

        final savedMessage = messages.firstWhere(
          (m) => m.uuid == 'outgoing-test',
          orElse: () => message,
        );

        // Should be marked as outgoing since sender ID matches device ID
        expect(savedMessage.isOutgoing, true);
      });

      test('correctly sets isOutgoing for received messages', () async {
        final message = Message(
          uuid: 'incoming-test',
          timestampMicros: DateTime.now().microsecondsSinceEpoch,
          senderId: 'other-device-123', // Different from local device ID
          senderName: 'Other User',
          content: 'Their message',
          isOutgoing: true, // Will be corrected by repository
        );

        await repository.saveMessage(message, testDeviceId, testNetworkId);

        final messages = await repository.getAllMessages(
          testDeviceId,
          testNetworkId,
        );

        final savedMessage = messages.firstWhere(
          (m) => m.uuid == 'incoming-test',
          orElse: () => message,
        );

        // Should be marked as not outgoing since sender ID doesn't match device ID
        expect(savedMessage.isOutgoing, false);
      });
    });
  });
}
