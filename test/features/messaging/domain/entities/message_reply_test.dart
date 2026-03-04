import 'package:flutter_test/flutter_test.dart';
import 'package:og_messenger/features/messaging/domain/entities/message.dart';

/// Tests for Message entity reply functionality.
///
/// These tests verify:
/// 1. Reply field handling in message entities
/// 2. JSON serialization/deserialization with reply data
/// 3. CopyWith functionality for reply fields
/// 4. Null handling for non-reply messages
void main() {
  group('Message Reply Fields', () {
    final testDate = DateTime(2024, 3, 4, 15, 30);

    final originalMessage = Message(
      uuid: 'original-msg-123',
      senderId: 'user-1',
      senderName: 'Original Sender',
      content: 'This is the original message being replied to',
      timestampMicros: testDate.microsecondsSinceEpoch,
      isOutgoing: false,
      roomId: 'room-1',
    );

    final replyMessage = Message(
      uuid: 'reply-msg-456',
      senderId: 'user-2',
      senderName: 'Reply Sender',
      content: 'This is a reply',
      timestampMicros: testDate
          .add(const Duration(minutes: 5))
          .microsecondsSinceEpoch,
      isOutgoing: true,
      roomId: 'room-1',
      repliedToUuid: 'original-msg-123',
      repliedToSenderId: 'user-1',
      replyToPreviewContent: 'This is the original message being replied to',
      replyToPreviewSenderName: 'Original Sender',
    );

    group('constructor', () {
      test('creates message without reply fields', () {
        expect(originalMessage.repliedToUuid, isNull);
        expect(originalMessage.repliedToSenderId, isNull);
        expect(originalMessage.replyToPreviewContent, isNull);
        expect(originalMessage.replyToPreviewSenderName, isNull);
      });

      test('creates message with all reply fields', () {
        expect(replyMessage.repliedToUuid, 'original-msg-123');
        expect(replyMessage.repliedToSenderId, 'user-1');
        expect(
          replyMessage.replyToPreviewContent,
          'This is the original message being replied to',
        );
        expect(replyMessage.replyToPreviewSenderName, 'Original Sender');
      });

      test('accepts partial reply fields (DB fields only)', () {
        final partialReply = Message(
          uuid: 'partial-msg-789',
          senderId: 'user-3',
          senderName: 'User 3',
          content: 'Reply without preview',
          timestampMicros: testDate.microsecondsSinceEpoch,
          isOutgoing: false,
          roomId: 'room-1',
          repliedToUuid: 'original-msg-123',
          repliedToSenderId: 'user-1',
          // Preview fields are null
        );

        expect(partialReply.repliedToUuid, 'original-msg-123');
        expect(partialReply.repliedToSenderId, 'user-1');
        expect(partialReply.replyToPreviewContent, isNull);
        expect(partialReply.replyToPreviewSenderName, isNull);
      });
    });

    group('copyWith', () {
      test('can add reply fields to existing message', () {
        final withReply = originalMessage.copyWith(
          repliedToUuid: 'other-msg',
          repliedToSenderId: 'other-user',
          replyToPreviewContent: 'Preview content',
          replyToPreviewSenderName: 'Preview sender',
        );

        expect(withReply.repliedToUuid, 'other-msg');
        expect(withReply.repliedToSenderId, 'other-user');
        expect(withReply.replyToPreviewContent, 'Preview content');
        expect(withReply.replyToPreviewSenderName, 'Preview sender');
        // Original fields preserved
        expect(withReply.uuid, originalMessage.uuid);
        expect(withReply.content, originalMessage.content);
      });

      test('can update reply fields independently', () {
        final updated = replyMessage.copyWith(
          replyToPreviewContent: 'Updated preview',
        );

        expect(updated.replyToPreviewContent, 'Updated preview');
        expect(updated.repliedToUuid, replyMessage.repliedToUuid);
        expect(
          updated.replyToPreviewSenderName,
          replyMessage.replyToPreviewSenderName,
        );
      });

      test('copyWith preserves reply fields when not specified', () {
        final updated = replyMessage.copyWith(content: 'Updated content');

        // Reply fields should be preserved
        expect(updated.repliedToUuid, replyMessage.repliedToUuid);
        expect(updated.repliedToSenderId, replyMessage.repliedToSenderId);
        expect(
          updated.replyToPreviewContent,
          replyMessage.replyToPreviewContent,
        );
        expect(
          updated.replyToPreviewSenderName,
          replyMessage.replyToPreviewSenderName,
        );
        // But content should be updated
        expect(updated.content, 'Updated content');
      });
    });

    group('JSON serialization', () {
      test('toJson includes reply fields when present', () {
        final json = replyMessage.toJson();

        expect(json['replied_to_uuid'], 'original-msg-123');
        expect(json['replied_to_sender_id'], 'user-1');
        expect(
          json['reply_to_preview_content'],
          'This is the original message being replied to',
        );
        expect(json['reply_to_preview_sender_name'], 'Original Sender');
      });

      test('toJson omits null reply fields', () {
        final json = originalMessage.toJson();

        expect(json.containsKey('replied_to_uuid'), isFalse);
        expect(json.containsKey('replied_to_sender_id'), isFalse);
        expect(json.containsKey('reply_to_preview_content'), isFalse);
        expect(json.containsKey('reply_to_preview_sender_name'), isFalse);
      });

      test('fromJson creates message with reply fields', () {
        final json = {
          'uuid': 'test-msg',
          'sender_id': 'test-sender',
          'sender_name': 'Test User',
          'content': 'Test content',
          'timestamp_micros': testDate.microsecondsSinceEpoch,
          'is_outgoing': true,
          'room_id': 'room-1',
          'replied_to_uuid': 'original-123',
          'replied_to_sender_id': 'original-sender',
          'reply_to_preview_content': 'Original content preview',
          'reply_to_preview_sender_name': 'Original Sender Name',
        };

        final message = Message.fromJson(json);

        expect(message.repliedToUuid, 'original-123');
        expect(message.repliedToSenderId, 'original-sender');
        expect(message.replyToPreviewContent, 'Original content preview');
        expect(message.replyToPreviewSenderName, 'Original Sender Name');
      });

      test('fromJson handles missing reply fields', () {
        final json = {
          'uuid': 'test-msg',
          'sender_id': 'test-sender',
          'sender_name': 'Test User',
          'content': 'Test content',
          'timestamp_micros': testDate.microsecondsSinceEpoch,
          'is_outgoing': false,
          'room_id': 'room-1',
        };

        final message = Message.fromJson(json);

        expect(message.repliedToUuid, isNull);
        expect(message.repliedToSenderId, isNull);
        expect(message.replyToPreviewContent, isNull);
        expect(message.replyToPreviewSenderName, isNull);
      });

      test('round-trip serialization preserves reply data', () {
        final json = replyMessage.toJson();
        final restored = Message.fromJson(json);

        expect(restored.repliedToUuid, replyMessage.repliedToUuid);
        expect(restored.repliedToSenderId, replyMessage.repliedToSenderId);
        expect(
          restored.replyToPreviewContent,
          replyMessage.replyToPreviewContent,
        );
        expect(
          restored.replyToPreviewSenderName,
          replyMessage.replyToPreviewSenderName,
        );
        expect(restored.content, replyMessage.content);
        expect(restored.senderName, replyMessage.senderName);
      });
    });

    group('reply preview truncation', () {
      test('long content can be stored in preview', () {
        final longContent = 'A' * 200; // 200 characters
        final message = replyMessage.copyWith(
          replyToPreviewContent: longContent,
        );

        expect(message.replyToPreviewContent, longContent);
        // Note: Truncation happens in UI layer, not entity
      });

      test('special characters in preview are preserved', () {
        final specialContent =
            'Hello 👋 World! @user #hashtag https://example.com';
        final message = replyMessage.copyWith(
          replyToPreviewContent: specialContent,
        );

        expect(message.replyToPreviewContent, specialContent);
      });

      test('newlines in preview are preserved', () {
        final multilineContent = 'Line 1\nLine 2\nLine 3';
        final message = replyMessage.copyWith(
          replyToPreviewContent: multilineContent,
        );

        expect(message.replyToPreviewContent, multilineContent);
      });
    });

    group('reply field validation', () {
      test('replied_to_uuid and replied_to_sender_id should be paired', () {
        // Both present - valid
        final validReply = Message(
          uuid: 'msg-1',
          senderId: 'user-1',
          senderName: 'User 1',
          content: 'Content',
          timestampMicros: testDate.microsecondsSinceEpoch,
          isOutgoing: false,
          roomId: 'room-1',
          repliedToUuid: 'original',
          repliedToSenderId: 'original-sender',
        );
        expect(validReply.repliedToUuid, isNotNull);
        expect(validReply.repliedToSenderId, isNotNull);

        // Both null - valid
        final noReply = Message(
          uuid: 'msg-2',
          senderId: 'user-2',
          senderName: 'User 2',
          content: 'Content',
          timestampMicros: testDate.microsecondsSinceEpoch,
          isOutgoing: false,
          roomId: 'room-1',
        );
        expect(noReply.repliedToUuid, isNull);
        expect(noReply.repliedToSenderId, isNull);
      });

      test('preview fields can be null even with DB fields present', () {
        // This represents a message loaded from DB before preview population
        final dbOnly = Message(
          uuid: 'msg-3',
          senderId: 'user-3',
          senderName: 'User 3',
          content: 'Content',
          timestampMicros: testDate.microsecondsSinceEpoch,
          isOutgoing: false,
          roomId: 'room-1',
          repliedToUuid: 'original',
          repliedToSenderId: 'original-sender',
          // Preview fields null
        );

        expect(dbOnly.repliedToUuid, isNotNull);
        expect(dbOnly.repliedToSenderId, isNotNull);
        expect(dbOnly.replyToPreviewContent, isNull);
        expect(dbOnly.replyToPreviewSenderName, isNull);
      });
    });
  });
}
