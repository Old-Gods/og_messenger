import 'package:flutter_test/flutter_test.dart';
import 'package:og_messenger/features/rooms/domain/entities/join_request.dart';

void main() {
  group('JoinRequest', () {
    final testDate = DateTime(2024, 1, 15, 10, 30);
    const testPublicKey = '''-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA...
-----END PUBLIC KEY-----''';

    final testRequest = JoinRequest(
      requestId: 'request-123',
      roomId: 'room-456',
      roomName: 'Test Room',
      requesterDeviceId: 'device-789',
      requesterName: 'Alice',
      requesterPublicKey: testPublicKey,
      createdAt: testDate,
    );

    group('constructor', () {
      test('creates join request with all required fields', () {
        expect(testRequest.requestId, 'request-123');
        expect(testRequest.roomId, 'room-456');
        expect(testRequest.roomName, 'Test Room');
        expect(testRequest.requesterDeviceId, 'device-789');
        expect(testRequest.requesterName, 'Alice');
        expect(testRequest.requesterPublicKey, testPublicKey);
        expect(testRequest.createdAt, testDate);
      });

      test('stores public key as string', () {
        expect(testRequest.requesterPublicKey, isA<String>());
        expect(testRequest.requesterPublicKey, contains('BEGIN PUBLIC KEY'));
      });
    });

    group('JSON serialization', () {
      test('toJson converts request to JSON map', () {
        final json = testRequest.toJson();

        expect(json['request_id'], 'request-123');
        expect(json['room_id'], 'room-456');
        expect(json['room_name'], 'Test Room');
        expect(json['requester_device_id'], 'device-789');
        expect(json['requester_name'], 'Alice');
        expect(json['requester_public_key'], testPublicKey);
        expect(json['created_at'], testDate.microsecondsSinceEpoch);
      });

      test('fromJson creates request from JSON map', () {
        final json = {
          'request_id': 'request-999',
          'room_id': 'room-888',
          'room_name': 'Another Room',
          'requester_device_id': 'device-111',
          'requester_name': 'Bob',
          'requester_public_key': testPublicKey,
          'created_at': testDate.microsecondsSinceEpoch,
        };

        final request = JoinRequest.fromJson(json);

        expect(request.requestId, 'request-999');
        expect(request.roomId, 'room-888');
        expect(request.roomName, 'Another Room');
        expect(request.requesterDeviceId, 'device-111');
        expect(request.requesterName, 'Bob');
        expect(request.requesterPublicKey, testPublicKey);
        expect(request.createdAt, testDate);
      });

      test('round-trip serialization preserves data', () {
        final json = testRequest.toJson();
        final deserialized = JoinRequest.fromJson(json);

        expect(deserialized.requestId, testRequest.requestId);
        expect(deserialized.roomId, testRequest.roomId);
        expect(deserialized.roomName, testRequest.roomName);
        expect(deserialized.requesterDeviceId, testRequest.requesterDeviceId);
        expect(deserialized.requesterName, testRequest.requesterName);
        expect(deserialized.requesterPublicKey, testRequest.requesterPublicKey);
        expect(deserialized.createdAt, testRequest.createdAt);
      });

      test('handles timestamp conversion correctly', () {
        final micros = testDate.microsecondsSinceEpoch;
        final json = testRequest.toJson();

        expect(json['created_at'], micros);

        final deserialized = JoinRequest.fromJson(json);
        expect(deserialized.createdAt.microsecondsSinceEpoch, micros);
      });
    });

    group('equality', () {
      test('requests with same requestId are equal', () {
        final request1 = JoinRequest(
          requestId: 'same-id',
          roomId: 'room-1',
          roomName: 'Room 1',
          requesterDeviceId: 'device-1',
          requesterName: 'Alice',
          requesterPublicKey: 'key1',
          createdAt: testDate,
        );

        final request2 = JoinRequest(
          requestId: 'same-id',
          roomId: 'room-2',
          roomName: 'Room 2',
          requesterDeviceId: 'device-2',
          requesterName: 'Bob',
          requesterPublicKey: 'key2',
          createdAt: testDate.add(Duration(days: 1)),
        );

        expect(request1, equals(request2));
        expect(request1.hashCode, equals(request2.hashCode));
      });

      test('requests with different requestId are not equal', () {
        final request1 = testRequest;
        final request2 = JoinRequest(
          requestId: 'different-id',
          roomId: testRequest.roomId,
          roomName: testRequest.roomName,
          requesterDeviceId: testRequest.requesterDeviceId,
          requesterName: testRequest.requesterName,
          requesterPublicKey: testRequest.requesterPublicKey,
          createdAt: testRequest.createdAt,
        );

        expect(request1, isNot(equals(request2)));
      });

      test('request equals itself', () {
        expect(testRequest, equals(testRequest));
      });
    });

    group('toString', () {
      test('returns formatted string representation', () {
        final str = testRequest.toString();

        expect(str, contains('JoinRequest('));
        expect(str, contains('requestId: request-123'));
        expect(str, contains('requesterName: Alice'));
        expect(str, contains('roomName: Test Room'));
      });

      test('includes key information in string', () {
        final str = testRequest.toString();

        // Should include the three main identifying pieces
        expect(str, contains(testRequest.requestId));
        expect(str, contains(testRequest.requesterName));
        expect(str, contains(testRequest.roomName));
      });
    });
  });
}
