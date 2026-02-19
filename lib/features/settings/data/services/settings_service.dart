import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
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

  /// Ensure device ID exists, generate if first launch
  Future<void> _ensureDeviceId() async {
    if (_prefs == null) return;

    final isFirstLaunch = _prefs!.getBool(_keyFirstLaunch) ?? true;
    if (isFirstLaunch) {
      // Generate UUIDv7 for device
      const uuid = Uuid();
      final deviceId = uuid.v7();
      await _prefs!.setString(_keyDeviceId, deviceId);
      await _prefs!.setBool(_keyFirstLaunch, false);

      // Set default retention days
      await _prefs!.setInt(_keyRetentionDays, AppConstants.retentionDays);
    }
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
