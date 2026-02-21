import 'package:flutter_test/flutter_test.dart';
import 'package:og_messenger/features/discovery/domain/entities/peer.dart';

void main() {
  group('Peer', () {
    group('constructor', () {
      test('creates a peer with required fields', () {
        final lastSeen = DateTime.now();
        final peer = Peer(
          deviceId: 'device-123',
          deviceName: 'Test Device',
          ipAddress: '192.168.1.100',
          tcpPort: 8080,
          lastSeen: lastSeen,
        );

        expect(peer.deviceId, 'device-123');
        expect(peer.deviceName, 'Test Device');
        expect(peer.ipAddress, '192.168.1.100');
        expect(peer.tcpPort, 8080);
        expect(peer.lastSeen, lastSeen);
        expect(peer.publicKey, null);
        expect(peer.isAuthenticated, false);
      });

      test('creates a peer with optional fields', () {
        final lastSeen = DateTime.now();
        final peer = Peer(
          deviceId: 'device-123',
          deviceName: 'Test Device',
          ipAddress: '192.168.1.100',
          tcpPort: 8080,
          lastSeen: lastSeen,
          publicKey: 'test-public-key',
          isAuthenticated: true,
        );

        expect(peer.publicKey, 'test-public-key');
        expect(peer.isAuthenticated, true);
      });
    });

    group('fromJson', () {
      test('creates peer from valid JSON', () {
        final json = {
          'device_id': 'device-456',
          'device_name': 'Alice Device',
          'ip_address': '10.0.0.5',
          'tcp_port': 9090,
          'timestamp': 1640000000000000,
        };

        final peer = Peer.fromJson(json);

        expect(peer.deviceId, 'device-456');
        expect(peer.deviceName, 'Alice Device');
        expect(peer.ipAddress, '10.0.0.5');
        expect(peer.tcpPort, 9090);
        expect(peer.lastSeen, isA<DateTime>());
        expect(peer.publicKey, null);
        expect(peer.isAuthenticated, false);
      });

      test('creates peer with public key from JSON', () {
        final json = {
          'device_id': 'device-789',
          'device_name': 'Bob Device',
          'ip_address': '172.16.0.1',
          'tcp_port': 7070,
          'timestamp': 1640000000000000,
          'public_key':
              '-----BEGIN PUBLIC KEY-----\nMIIBIj...\n-----END PUBLIC KEY-----',
          'is_authenticated': true,
        };

        final peer = Peer.fromJson(json);

        expect(peer.publicKey, contains('BEGIN PUBLIC KEY'));
        expect(peer.isAuthenticated, true);
      });

      test('handles missing optional fields in JSON', () {
        final json = {
          'device_id': 'device-minimal',
          'device_name': 'Minimal Device',
          'ip_address': '192.168.0.1',
          'tcp_port': 5000,
        };

        final peer = Peer.fromJson(json);

        expect(peer.publicKey, null);
        expect(peer.isAuthenticated, false);
      });
    });

    group('toJson', () {
      test('converts peer to JSON correctly', () {
        final lastSeen = DateTime.now();
        final peer = Peer(
          deviceId: 'device-123',
          deviceName: 'Test Device',
          ipAddress: '192.168.1.100',
          tcpPort: 8080,
          lastSeen: lastSeen,
        );

        final json = peer.toJson();

        expect(json['device_id'], 'device-123');
        expect(json['device_name'], 'Test Device');
        expect(json['ip_address'], '192.168.1.100');
        expect(json['tcp_port'], 8080);
        expect(json['timestamp'], isA<int>());
        expect(json.containsKey('public_key'), false);
        expect(json['is_authenticated'], false);
      });

      test('includes public key in JSON when present', () {
        final lastSeen = DateTime.now();
        final peer = Peer(
          deviceId: 'device-456',
          deviceName: 'Device With Key',
          ipAddress: '10.0.0.1',
          tcpPort: 9000,
          lastSeen: lastSeen,
          publicKey: 'test-key-data',
          isAuthenticated: true,
        );

        final json = peer.toJson();

        expect(json['public_key'], 'test-key-data');
        expect(json['is_authenticated'], true);
      });
    });

    group('copyWith', () {
      test('creates a copy with updated fields', () {
        final lastSeen = DateTime.now();
        final original = Peer(
          deviceId: 'device-original',
          deviceName: 'Original Name',
          ipAddress: '192.168.1.1',
          tcpPort: 8080,
          lastSeen: lastSeen,
        );

        final newLastSeen = DateTime.now().add(Duration(minutes: 5));
        final updated = original.copyWith(
          deviceName: 'Updated Name',
          lastSeen: newLastSeen,
          isAuthenticated: true,
        );

        expect(updated.deviceId, original.deviceId);
        expect(updated.deviceName, 'Updated Name');
        expect(updated.ipAddress, original.ipAddress);
        expect(updated.tcpPort, original.tcpPort);
        expect(updated.lastSeen, newLastSeen);
        expect(updated.isAuthenticated, true);
      });

      test('creates a copy without changes when no parameters provided', () {
        final lastSeen = DateTime.now();
        final original = Peer(
          deviceId: 'device-123',
          deviceName: 'Name',
          ipAddress: '192.168.1.1',
          tcpPort: 8080,
          lastSeen: lastSeen,
          publicKey: 'key-data',
          isAuthenticated: true,
        );

        final copy = original.copyWith();

        expect(copy.deviceId, original.deviceId);
        expect(copy.deviceName, original.deviceName);
        expect(copy.ipAddress, original.ipAddress);
        expect(copy.tcpPort, original.tcpPort);
        expect(copy.lastSeen, original.lastSeen);
        expect(copy.publicKey, original.publicKey);
        expect(copy.isAuthenticated, original.isAuthenticated);
      });
    });

    group('equality', () {
      test('two peers with same device ID are equal', () {
        final lastSeen = DateTime.now();
        final peer1 = Peer(
          deviceId: 'same-device-id',
          deviceName: 'Device 1',
          ipAddress: '192.168.1.1',
          tcpPort: 8080,
          lastSeen: lastSeen,
        );

        final peer2 = Peer(
          deviceId: 'same-device-id',
          deviceName: 'Device 2', // Different name
          ipAddress: '192.168.1.2', // Different IP
          tcpPort: 9090, // Different port
          lastSeen: lastSeen,
        );

        expect(peer1 == peer2, true);
        expect(peer1.hashCode, peer2.hashCode);
      });

      test('two peers with different device IDs are not equal', () {
        final lastSeen = DateTime.now();
        final peer1 = Peer(
          deviceId: 'device-1',
          deviceName: 'Device',
          ipAddress: '192.168.1.1',
          tcpPort: 8080,
          lastSeen: lastSeen,
        );

        final peer2 = Peer(
          deviceId: 'device-2',
          deviceName: 'Device',
          ipAddress: '192.168.1.1',
          tcpPort: 8080,
          lastSeen: lastSeen,
        );

        expect(peer1 == peer2, false);
      });
    });
  });
}
