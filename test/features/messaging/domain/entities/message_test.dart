import 'package:flutter_test/flutter_test.dart';
import 'package:og_messenger/features/messaging/domain/entities/message.dart';

void main() {
  group('Message', () {
    group('constructor', () {
      test('creates a message with required fields', () {
        final message = Message(
          uuid: 'test-uuid-123',
          timestampMicros: 1640000000000000,
          senderId: 'sender-123',
          senderName: 'John Doe',
          content: 'Hello, World!',
          isOutgoing: true,
        );

        expect(message.uuid, 'test-uuid-123');
        expect(message.timestampMicros, 1640000000000000);
        expect(message.senderId, 'sender-123');
        expect(message.senderName, 'John Doe');
        expect(message.content, 'Hello, World!');
        expect(message.isOutgoing, true);
      });
    });

    group('timestamp getter', () {
      test('converts microseconds to DateTime correctly', () {
        final timestampMicros =
            1640000000000000; // Mon Dec 20 2021 09:46:40 GMT
        final message = Message(
          uuid: 'test-uuid',
          timestampMicros: timestampMicros,
          senderId: 'sender-id',
          senderName: 'Sender',
          content: 'Test',
          isOutgoing: false,
        );

        final expectedDateTime = DateTime.fromMicrosecondsSinceEpoch(
          timestampMicros,
        );
        expect(message.timestamp, expectedDateTime);
      });
    });

    group('fromJson', () {
      test('creates message from valid JSON', () {
        final json = {
          'uuid': 'uuid-456',
          'timestamp_micros': 1640000000000000,
          'sender_id': 'device-789',
          'sender_name': 'Alice',
          'content': 'Test message',
        };

        final message = Message.fromJson(json);

        expect(message.uuid, 'uuid-456');
        expect(message.timestampMicros, 1640000000000000);
        expect(message.senderId, 'device-789');
        expect(message.senderName, 'Alice');
        expect(message.content, 'Test message');
        expect(message.isOutgoing, false); // Always false from JSON
      });

      test('handles empty content', () {
        final json = {
          'uuid': 'uuid-empty',
          'timestamp_micros': 1640000000000000,
          'sender_id': 'device-id',
          'sender_name': 'Bob',
          'content': '',
        };

        final message = Message.fromJson(json);
        expect(message.content, '');
      });
    });

    group('toJson', () {
      test('converts message to JSON correctly', () {
        final message = Message(
          uuid: 'test-uuid',
          timestampMicros: 1640000000000000,
          senderId: 'sender-123',
          senderName: 'Charlie',
          content: 'Message content',
          isOutgoing: true,
        );

        final json = message.toJson();

        expect(json['uuid'], 'test-uuid');
        expect(json['timestamp_micros'], 1640000000000000);
        expect(json['sender_id'], 'sender-123');
        expect(json['sender_name'], 'Charlie');
        expect(json['content'], 'Message content');
        expect(json.containsKey('isOutgoing'), false); // Not included in JSON
      });
    });

    group('copyWith', () {
      test('creates a copy with updated fields', () {
        final original = Message(
          uuid: 'original-uuid',
          timestampMicros: 1640000000000000,
          senderId: 'sender-1',
          senderName: 'Original Name',
          content: 'Original content',
          isOutgoing: false,
        );

        final updated = original.copyWith(
          senderName: 'Updated Name',
          content: 'Updated content',
        );

        expect(updated.uuid, original.uuid);
        expect(updated.timestampMicros, original.timestampMicros);
        expect(updated.senderId, original.senderId);
        expect(updated.senderName, 'Updated Name');
        expect(updated.content, 'Updated content');
        expect(updated.isOutgoing, original.isOutgoing);
      });

      test('creates a copy without changes when no parameters provided', () {
        final original = Message(
          uuid: 'original-uuid',
          timestampMicros: 1640000000000000,
          senderId: 'sender-1',
          senderName: 'Name',
          content: 'Content',
          isOutgoing: true,
        );

        final copy = original.copyWith();

        expect(copy.uuid, original.uuid);
        expect(copy.timestampMicros, original.timestampMicros);
        expect(copy.senderId, original.senderId);
        expect(copy.senderName, original.senderName);
        expect(copy.content, original.content);
        expect(copy.isOutgoing, original.isOutgoing);
      });
    });

    group('equality', () {
      test('two messages with same properties are equal', () {
        final message1 = Message(
          uuid: 'same-uuid',
          timestampMicros: 1640000000000000,
          senderId: 'sender-1',
          senderName: 'Name',
          content: 'Content',
          isOutgoing: true,
        );

        final message2 = Message(
          uuid: 'same-uuid',
          timestampMicros: 1640000000000000,
          senderId: 'sender-1',
          senderName: 'Name',
          content: 'Content',
          isOutgoing: true,
        );

        expect(message1 == message2, true);
        expect(message1.hashCode, message2.hashCode);
      });

      test('two messages with different UUIDs are not equal', () {
        final message1 = Message(
          uuid: 'uuid-1',
          timestampMicros: 1640000000000000,
          senderId: 'sender-1',
          senderName: 'Name',
          content: 'Content',
          isOutgoing: true,
        );

        final message2 = Message(
          uuid: 'uuid-2',
          timestampMicros: 1640000000000000,
          senderId: 'sender-1',
          senderName: 'Name',
          content: 'Content',
          isOutgoing: true,
        );

        expect(message1 == message2, false);
      });
    });
  });
}
