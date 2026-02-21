/// Network-related constants for OG Messenger
class NetworkConstants {
  // Multicast Configuration
  static const String multicastAddress = '239.255.42.99';
  static const int multicastPort = 4445;
  static const int multicastTTL = 1; // LAN-only

  // TCP Configuration
  static const int baseTcpPort = 8888;
  static const int maxPortAttempts = 100; // Try ports 8888-8987
  static const int tcpPortRangeEnd = baseTcpPort + maxPortAttempts - 1;

  // Timing Configuration
  static const Duration discoveryBeaconInterval = Duration(seconds: 3);
  static const Duration peerTimeout = Duration(seconds: 7);
  static const Duration reconnectDelay = Duration(seconds: 5);
  static const Duration tcpHeartbeatInterval = Duration(seconds: 30);

  // Typing Indicator Configuration
  static const Duration typingThrottleInterval = Duration(seconds: 3);
  static const Duration typingTimeout = Duration(seconds: 5);
  static const int typingDisplayLimit =
      2; // Max names to show before "and X others"

  // Message Configuration
  static const int maxMessageSizeBytes = 10 * 1024; // 10 KB
  static const int maxMessageSizeKB = 10;
}
