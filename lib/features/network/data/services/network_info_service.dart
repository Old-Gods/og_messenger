import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service for getting network information
class NetworkInfoService {
  static final NetworkInfoService instance = NetworkInfoService._();
  final NetworkInfo _networkInfo = NetworkInfo();
  bool _permissionRequested = false;

  NetworkInfoService._();

  /// Request location permission (needed for WiFi SSID on iOS/Android)
  /// Note: macOS doesn't support runtime location permissions
  Future<bool> requestLocationPermission() async {
    // Skip permission request on macOS - not supported
    if (Platform.isMacOS) {
      print(
        '📍 macOS detected - skipping permission request (sandboxed apps cannot access WiFi SSID)',
      );
      return false;
    }

    if (_permissionRequested) {
      return await Permission.location.isGranted;
    }

    _permissionRequested = true;

    try {
      final status = await Permission.location.status;
      print('📍 Current location permission status: $status');

      if (status.isGranted) {
        return true;
      }

      if (status.isDenied) {
        print('📍 Requesting location permission...');
        final result = await Permission.location.request();
        print('📍 Location permission result: $result');
        return result.isGranted;
      }

      return false;
    } catch (e) {
      print('⚠️ Error requesting location permission: $e');
      return false;
    }
  }

  /// Get the current WiFi SSID
  /// Returns the SSID or IP-based identifier if unable to determine
  Future<String> getCurrentNetworkId() async {
    try {
      // Request location permission first (not needed on macOS)
      if (!Platform.isMacOS) {
        await requestLocationPermission();
      }

      print('🔍 Attempting to get WiFi SSID...');
      final ssid = await _networkInfo.getWifiName();
      print('📡 Raw SSID value: "$ssid"');

      // Remove quotes that iOS/Android sometimes add
      String cleanSsid = ssid ?? 'Unknown';
      if (cleanSsid.startsWith('"') && cleanSsid.endsWith('"')) {
        cleanSsid = cleanSsid.substring(1, cleanSsid.length - 1);
      }

      // If we couldn't get SSID, try to use IP address prefix as fallback
      if (cleanSsid == 'Unknown' || cleanSsid.isEmpty) {
        print('⚠️ Could not get SSID, trying IP address fallback...');
        final ipAddress = await _networkInfo.getWifiIP();
        print('📡 WiFi IP: $ipAddress');
        if (ipAddress != null && ipAddress.isNotEmpty) {
          // Use first 3 octets as network identifier
          final parts = ipAddress.split('.');
          if (parts.length >= 3) {
            cleanSsid = '${parts[0]}.${parts[1]}.${parts[2]}.x';
            print('✅ Using IP-based network ID: $cleanSsid');
          }
        }
      } else {
        print('✅ Network SSID detected: $cleanSsid');
      }

      return cleanSsid;
    } catch (e) {
      print('⚠️ Failed to get network ID: $e');
      return 'Unknown';
    }
  }

  /// Get the current WiFi IP address
  Future<String?> getWifiIP() async {
    try {
      return await _networkInfo.getWifiIP();
    } catch (e) {
      print('⚠️ Failed to get WiFi IP: $e');
      return null;
    }
  }

  /// Get the WiFi subnet mask
  Future<String?> getWifiSubmask() async {
    try {
      return await _networkInfo.getWifiSubmask();
    } catch (e) {
      print('⚠️ Failed to get WiFi submask: $e');
      return null;
    }
  }

  /// Get the WiFi gateway IP
  Future<String?> getWifiGatewayIP() async {
    try {
      return await _networkInfo.getWifiGatewayIP();
    } catch (e) {
      print('⚠️ Failed to get WiFi gateway IP: $e');
      return null;
    }
  }
}
