import 'package:flutter_test/flutter_test.dart';
import 'package:og_messenger/features/reactions/domain/entities/reaction.dart';

void main() {
  group('Reaction', () {
    final testDate = DateTime(2024, 3, 4, 15, 30);
    final testReaction = Reaction(
      messageUuid: 'msg-123',
      messageSenderId: 'sender-456',
      reactorDeviceId: 'reactor-789',
      reactorName: 'John Doe',
      emoji: '👍',
      timestampMicros: testDate.microsecondsSinceEpoch,
      roomId: 'room-123',
    );

    group('constructor', () {
      test('creates reaction with all required fields', () {
        expect(testReaction.messageUuid, 'msg-123');
        expect(testReaction.messageSenderId, 'sender-456');
        expect(testReaction.reactorDeviceId, 'reactor-789');
        expect(testReaction.reactorName, 'John Doe');
        expect(testReaction.emoji, '👍');
        expect(testReaction.timestampMicros, testDate.microsecondsSinceEpoch);
        expect(testReaction.roomId, 'room-123');
      });

      test('accepts different emoji values', () {
        final reactions = ['👍', '❤️', '😆', '👎', '🎉', '🔥'];

        for (final emoji in reactions) {
          final reaction = testReaction.copyWith(emoji: emoji);
          expect(reaction.emoji, emoji);
        }
      });
    });

    group('copyWith', () {
      test('returns new instance with updated fields', () {
        final updated = testReaction.copyWith(
          emoji: '❤️',
          reactorName: 'Jane Smith',
        );

        expect(updated.messageUuid, testReaction.messageUuid);
        expect(updated.emoji, '❤️');
        expect(updated.reactorName, 'Jane Smith');
        expect(updated.reactorDeviceId, testReaction.reactorDeviceId);
      });

      test('returns copy with same values when no parameters provided', () {
        final copy = testReaction.copyWith();

        expect(copy.messageUuid, testReaction.messageUuid);
        expect(copy.messageSenderId, testReaction.messageSenderId);
        expect(copy.reactorDeviceId, testReaction.reactorDeviceId);
        expect(copy.emoji, testReaction.emoji);
        expect(copy.timestampMicros, testReaction.timestampMicros);
      });

      test('can update all fields independently', () {
        final newTimestamp = DateTime.now().microsecondsSinceEpoch;
        final updated = testReaction.copyWith(
          messageUuid: 'new-msg',
          messageSenderId: 'new-sender',
          reactorDeviceId: 'new-reactor',
          reactorName: 'New Name',
          emoji: '🎉',
          timestampMicros: newTimestamp,
          roomId: 'new-room',
        );

        expect(updated.messageUuid, 'new-msg');
        expect(updated.messageSenderId, 'new-sender');
        expect(updated.reactorDeviceId, 'new-reactor');
        expect(updated.reactorName, 'New Name');
        expect(updated.emoji, '🎉');
        expect(updated.timestampMicros, newTimestamp);
        expect(updated.roomId, 'new-room');
      });
    });

    group('JSON serialization', () {
      test('toJson converts reaction to JSON map', () {
        final json = testReaction.toJson();

        expect(json['message_uuid'], 'msg-123');
        expect(json['message_sender_id'], 'sender-456');
        expect(json['reactor_device_id'], 'reactor-789');
        expect(json['reactor_name'], 'John Doe');
        expect(json['emoji'], '👍');
        expect(json['timestamp_micros'], testDate.microsecondsSinceEpoch);
        expect(json['room_id'], 'room-123');
      });

      test('fromJson creates reaction from JSON map', () {
        final json = {
          'message_uuid': 'msg-456',
          'message_sender_id': 'sender-789',
          'reactor_device_id': 'reactor-123',
          'reactor_name': 'Jane Smith',
          'emoji': '❤️',
          'timestamp_micros': testDate.microsecondsSinceEpoch,
          'room_id': 'room-456',
        };

        final reaction = Reaction.fromJson(json);

        expect(reaction.messageUuid, 'msg-456');
        expect(reaction.messageSenderId, 'sender-789');
        expect(reaction.reactorDeviceId, 'reactor-123');
        expect(reaction.reactorName, 'Jane Smith');
        expect(reaction.emoji, '❤️');
        expect(reaction.timestampMicros, testDate.microsecondsSinceEpoch);
        expect(reaction.roomId, 'room-456');
      });

      test('roundtrip serialization preserves data', () {
        final json = testReaction.toJson();
        final deserialized = Reaction.fromJson(json);

        expect(deserialized.messageUuid, testReaction.messageUuid);
        expect(deserialized.messageSenderId, testReaction.messageSenderId);
        expect(deserialized.reactorDeviceId, testReaction.reactorDeviceId);
        expect(deserialized.reactorName, testReaction.reactorName);
        expect(deserialized.emoji, testReaction.emoji);
        expect(deserialized.timestampMicros, testReaction.timestampMicros);
        expect(deserialized.roomId, testReaction.roomId);
      });

      test('handles emoji with skin tone modifiers', () {
        final emojiWithSkinTone = testReaction.copyWith(emoji: '👍🏻');
        final json = emojiWithSkinTone.toJson();
        final deserialized = Reaction.fromJson(json);

        expect(deserialized.emoji, '👍🏻');
      });

      test('handles complex emoji sequences', () {
        final complexEmojis = [
          '👨‍👩‍👧‍👦', // Family emoji
          '🏳️‍🌈', // Rainbow flag
          '👩‍💻', // Woman technologist
        ];

        for (final emoji in complexEmojis) {
          final reaction = testReaction.copyWith(emoji: emoji);
          final json = reaction.toJson();
          final deserialized = Reaction.fromJson(json);
          expect(deserialized.emoji, emoji);
        }
      });
    });

    group('equality', () {
      test('reactions with same composite key are equal', () {
        final reaction1 = Reaction(
          messageUuid: 'msg-123',
          messageSenderId: 'sender-456',
          reactorDeviceId: 'reactor-789',
          reactorName: 'John',
          emoji: '👍',
          timestampMicros: 1000,
          roomId: 'room-123',
        );

        final reaction2 = Reaction(
          messageUuid: 'msg-123',
          messageSenderId: 'sender-456',
          reactorDeviceId: 'reactor-789',
          reactorName: 'Different Name', // Different name
          emoji: '❤️', // Different emoji
          timestampMicros: 2000, // Different timestamp
          roomId: 'room-123',
        );

        expect(reaction1, equals(reaction2));
        expect(reaction1.hashCode, equals(reaction2.hashCode));
      });

      test('reactions with different message UUID are not equal', () {
        final reaction1 = testReaction;
        final reaction2 = testReaction.copyWith(messageUuid: 'different-msg');

        expect(reaction1, isNot(equals(reaction2)));
      });

      test('reactions with different sender ID are not equal', () {
        final reaction1 = testReaction;
        final reaction2 = testReaction.copyWith(
          messageSenderId: 'different-sender',
        );

        expect(reaction1, isNot(equals(reaction2)));
      });

      test('reactions with different reactor ID are not equal', () {
        final reaction1 = testReaction;
        final reaction2 = testReaction.copyWith(
          reactorDeviceId: 'different-reactor',
        );

        expect(reaction1, isNot(equals(reaction2)));
      });

      test('reactions with different room ID are not equal', () {
        final reaction1 = testReaction;
        final reaction2 = testReaction.copyWith(roomId: 'different-room');

        expect(reaction1, isNot(equals(reaction2)));
      });
    });

    group('timestamp handling', () {
      test('preserves microsecond precision', () {
        final microTimestamp = DateTime.now().microsecondsSinceEpoch;
        final reaction = testReaction.copyWith(timestampMicros: microTimestamp);

        expect(reaction.timestampMicros, microTimestamp);

        final json = reaction.toJson();
        final deserialized = Reaction.fromJson(json);

        expect(deserialized.timestampMicros, microTimestamp);
      });

      test('can compare reactions by timestamp', () {
        final time1 = DateTime(2024, 1, 1).microsecondsSinceEpoch;
        final time2 = DateTime(2024, 1, 2).microsecondsSinceEpoch;

        final reaction1 = testReaction.copyWith(timestampMicros: time1);
        final reaction2 = testReaction.copyWith(timestampMicros: time2);

        expect(reaction1.timestampMicros < reaction2.timestampMicros, isTrue);
      });
    });

    group('composite key uniqueness', () {
      test('composite key identifies unique reaction', () {
        // Same user reacting to same message in same room = unique
        final reaction = testReaction;

        // Key components
        expect(reaction.messageUuid, isNotEmpty);
        expect(reaction.messageSenderId, isNotEmpty);
        expect(reaction.reactorDeviceId, isNotEmpty);
        expect(reaction.roomId, isNotEmpty);
      });

      test(
        'different emoji from same user to same message is same reaction',
        () {
          // This represents changing a reaction, not adding a new one
          final reaction1 = testReaction.copyWith(emoji: '👍');
          final reaction2 = testReaction.copyWith(emoji: '❤️');

          // Same composite key (should UPSERT in database)
          expect(reaction1, equals(reaction2));
        },
      );

      test('same emoji from different users are different reactions', () {
        final reaction1 = testReaction.copyWith(
          reactorDeviceId: 'user-1',
          emoji: '👍',
        );
        final reaction2 = testReaction.copyWith(
          reactorDeviceId: 'user-2',
          emoji: '👍',
        );

        expect(reaction1, isNot(equals(reaction2)));
      });
    });
  });
}
