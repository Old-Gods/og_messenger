import 'dart:io';
import 'package:flutter/services.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// Callback type for network ID refresh
typedef NetworkIdRefreshCallback = void Function(String networkId);

/// Service for getting network information
class NetworkInfoService {
  static final NetworkInfoService instance = NetworkInfoService._();
  final NetworkInfo _networkInfo = NetworkInfo();
  static const _macOSChannel = MethodChannel('com.ogmessenger.network_info');
  bool _permissionRequested = false;
  NetworkIdRefreshCallback? _onNetworkIdRefresh;

  NetworkInfoService._() {
    // Set up method call handler for macOS location permission callback
    if (Platform.isMacOS) {
      _macOSChannel.setMethodCallHandler(_handleMethodCall);
    }
  }

  /// Handle method calls from native code
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onLocationPermissionGranted') {
      print('📡 Received location permission granted callback from macOS');
      // Refresh network ID
      final networkId = await getCurrentNetworkId();
      // Notify listener (settings provider)
      _onNetworkIdRefresh?.call(networkId);
    }
  }

  /// Set callback for network ID refresh (called when permissions are granted)
  void setNetworkIdRefreshCallback(NetworkIdRefreshCallback callback) {
    _onNetworkIdRefresh = callback;
  }

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

  /// Get the current WiFi SSID for network identification
  ///
  /// IMPORTANT: This method ONLY returns the WiFi SSID. There is NO fallback
  /// to IP addresses. If SSID cannot be determined, returns 'Unknown'.
  ///
  /// This ensures proper network isolation - devices on different WiFi networks
  /// will not see each other's messages, even if they use the same IP subnet.
  ///
  /// Platform-specific behavior:
  /// - macOS: Uses CoreWLAN framework (requires Location Services permission)
  /// - iOS/Android: Uses network_info_plus (requires location permission)
  /// - Other platforms: Uses network_info_plus
  ///
  /// Returns the SSID string or 'Unknown' if unable to determine
  Future<String> getCurrentNetworkId() async {
    try {
      String? ssid;

      // Use CoreWLAN on macOS via method channel
      if (Platform.isMacOS) {
        print('🔍 macOS: Using CoreWLAN to get WiFi SSID...');
        try {
          ssid = await _macOSChannel.invokeMethod<String>('getWifiSSID');
          print('📡 CoreWLAN SSID value: "$ssid"');
        } catch (e) {
          print('⚠️ CoreWLAN failed: $e');
          ssid = null;
        }
      } else {
        // Use network_info_plus on other platforms (with location permission)
        await requestLocationPermission();
        print('🔍 Attempting to get WiFi SSID...');
        ssid = await _networkInfo.getWifiName();
        print('📡 Raw SSID value: "$ssid"');
      }

      // Remove quotes that iOS/Android sometimes add
      String cleanSsid = ssid ?? 'Unknown';
      if (cleanSsid.startsWith('"') && cleanSsid.endsWith('"')) {
        cleanSsid = cleanSsid.substring(1, cleanSsid.length - 1);
      }

      if (cleanSsid == 'Unknown' || cleanSsid.isEmpty) {
        print('❌ Could not get SSID - network identification will fail');
        return 'Unknown';
      }

      print('✅ Network SSID detected: $cleanSsid');
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
