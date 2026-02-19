import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../../../../core/constants/app_constants.dart';

/// Service for managing app settings and user preferences
class SettingsService {
  static const String _keyDeviceId = 'device_id';
  static const String _keyUserName = 'user_name';
  static const String _keyRetentionDays = 'retention_days';
  static const String _keyFirstLaunch = 'first_launch';

  static final SettingsService instance = SettingsService._();
  SharedPreferences? _prefs;

  SettingsService._();

  /// Initialize the settings service
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _ensureDeviceId();
  }

  /// Ensure device ID exists, generate from hardware if not present
  Future<void> _ensureDeviceId() async {
    if (_prefs == null) return;

    // Check if device ID already exists
    String? deviceId = _prefs!.getString(_keyDeviceId);
    
    if (deviceId == null || deviceId.isEmpty) {
      // Generate device ID from hardware identifiers
      deviceId = await _getHardwareDeviceId();
      await _prefs!.setString(_keyDeviceId, deviceId);
      
      final isFirstLaunch = _prefs!.getBool(_keyFirstLaunch) ?? true;
      if (isFirstLaunch) {
        await _prefs!.setBool(_keyFirstLaunch, false);
        // Set default retention days
        await _prefs!.setInt(_keyRetentionDays, AppConstants.retentionDays);
      }
    }
  }

  /// Get hardware-based device identifier that persists across app updates
  Future<String> _getHardwareDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    
    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        // Use Android ID - persists across app updates but not factory resets
        return androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        // Use identifierForVendor - persists for same vendor apps
        return iosInfo.identifierForVendor ?? _generateFallbackId();
      } else if (Platform.isMacOS) {
        final macosInfo = await deviceInfo.macOsInfo;
        // Use system GUID for macOS
        return macosInfo.systemGUID ?? _generateFallbackId();
      } else if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        // Use machine ID for Windows
        return windowsInfo.deviceId;
      } else if (Platform.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        // Use machine ID for Linux
        return linuxInfo.machineId ?? _generateFallbackId();
      }
    } catch (e) {
      print('❌ Failed to get hardware device ID: $e');
    }
    
    // Fallback to UUID if hardware ID unavailable
    return _generateFallbackId();
  }
  
  /// Generate fallback UUID if hardware ID is unavailable
  String _generateFallbackId() {
    const uuid = Uuid();
    return uuid.v7();
  }

  /// Get the device ID (generated on first launch)
  String? get deviceId {
    return _prefs?.getString(_keyDeviceId);
  }

  /// Get the user's display name
  String? get userName {
    return _prefs?.getString(_keyUserName);
  }

  /// Set the user's display name
  Future<bool> setUserName(String name) async {
    if (_prefs == null) return false;
    return await _prefs!.setString(_keyUserName, name);
  }

  /// Get the retention period in days
  int get retentionDays {
    return _prefs?.getInt(_keyRetentionDays) ?? AppConstants.retentionDays;
  }

  /// Set the retention period in days
  Future<bool> setRetentionDays(int days) async {
    if (_prefs == null) return false;
    return await _prefs!.setInt(_keyRetentionDays, days);
  }

  /// Check if this is the first launch
  bool get isFirstLaunch {
    return _prefs?.getBool(_keyFirstLaunch) ?? true;
  }

  /// Check if user has set their name
  bool get hasUserName {
    final name = userName;
    return name != null && name.trim().isNotEmpty;
  }

  /// Reset all settings (for testing)
  Future<bool> resetAll() async {
    if (_prefs == null) return false;
    await _prefs!.clear();
    await _ensureDeviceId();
    return true;
  }
}
