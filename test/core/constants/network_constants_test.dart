import 'package:flutter_test/flutter_test.dart';
import 'package:og_messenger/core/constants/network_constants.dart';

void main() {
  group('NetworkConstants', () {
    group('UDP multicast', () {
      test('has valid multicast address', () {
        expect(NetworkConstants.multicastAddress, '239.255.42.99');
        // Verify it's in the valid multicast range (224.0.0.0 to 239.255.255.255)
        expect(NetworkConstants.multicastAddress.startsWith('239.'), true);
      });

      test('has valid multicast port', () {
        expect(NetworkConstants.multicastPort, 4445);
        expect(
          NetworkConstants.multicastPort,
          greaterThan(1024),
        ); // Not a privileged port
        expect(
          NetworkConstants.multicastPort,
          lessThan(65536),
        ); // Valid port range
      });

      test('has valid multicast TTL', () {
        expect(NetworkConstants.multicastTTL, 1); // LAN-only
        expect(NetworkConstants.multicastTTL, greaterThan(0));
      });

      test('has valid discovery beacon interval', () {
        expect(NetworkConstants.discoveryBeaconInterval, Duration(seconds: 3));
        expect(
          NetworkConstants.discoveryBeaconInterval.inSeconds,
          greaterThan(0),
        );
      });
    });

    group('TCP configuration', () {
      test('has valid base TCP port', () {
        expect(NetworkConstants.baseTcpPort, 8888);
        expect(
          NetworkConstants.baseTcpPort,
          greaterThan(1024),
        ); // Not a privileged port
        expect(
          NetworkConstants.baseTcpPort,
          lessThan(65536),
        ); // Valid port range
      });

      test('has valid max port attempts', () {
        expect(NetworkConstants.maxPortAttempts, 100);
        expect(NetworkConstants.maxPortAttempts, greaterThan(0));
      });

      test('TCP port range end is calculated correctly', () {
        expect(
          NetworkConstants.tcpPortRangeEnd,
          NetworkConstants.baseTcpPort + NetworkConstants.maxPortAttempts - 1,
        );
        expect(
          NetworkConstants.tcpPortRangeEnd,
          lessThan(65536),
        ); // Valid port range
      });

      test('multicast and TCP base ports are different', () {
        expect(
          NetworkConstants.baseTcpPort,
          isNot(equals(NetworkConstants.multicastPort)),
        );
      });
    });

    group('timing configuration', () {
      test('has valid peer timeout', () {
        expect(NetworkConstants.peerTimeout, Duration(seconds: 7));
        expect(NetworkConstants.peerTimeout.inSeconds, greaterThan(0));
      });

      test('has valid reconnect delay', () {
        expect(NetworkConstants.reconnectDelay, Duration(seconds: 5));
        expect(NetworkConstants.reconnectDelay.inSeconds, greaterThan(0));
      });

      test('has valid TCP heartbeat interval', () {
        expect(NetworkConstants.tcpHeartbeatInterval, Duration(seconds: 30));
        expect(NetworkConstants.tcpHeartbeatInterval.inSeconds, greaterThan(0));
      });

      test('peer timeout is longer than discovery beacon interval', () {
        expect(
          NetworkConstants.peerTimeout.inSeconds,
          greaterThan(NetworkConstants.discoveryBeaconInterval.inSeconds),
        );
      });

      test('heartbeat interval is reasonable', () {
        expect(
          NetworkConstants.tcpHeartbeatInterval.inSeconds,
          greaterThan(NetworkConstants.reconnectDelay.inSeconds),
        );
      });
    });

    group('message configuration', () {
      test('has valid message size in bytes', () {
        expect(NetworkConstants.maxMessageSizeBytes, 10 * 1024);
        expect(NetworkConstants.maxMessageSizeBytes, greaterThan(0));
      });

      test('has valid message size in KB', () {
        expect(NetworkConstants.maxMessageSizeKB, 10);
        expect(NetworkConstants.maxMessageSizeKB, greaterThan(0));
      });

      test('message size constants are consistent', () {
        expect(
          NetworkConstants.maxMessageSizeBytes,
          NetworkConstants.maxMessageSizeKB * 1024,
        );
      });

      test('message buffer size is reasonable', () {
        // Should be large enough for typical messages but not excessive
        expect(
          NetworkConstants.maxMessageSizeBytes,
          greaterThanOrEqualTo(1024),
        );
        expect(
          NetworkConstants.maxMessageSizeBytes,
          lessThanOrEqualTo(1024 * 1024),
        );
      });
    });
  });
}
