import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/services/settings_service.dart';
import '../../messaging/providers/message_provider.dart';

/// Settings state model
class SettingsState {
  final String? deviceId;
  final String? userName;
  final int retentionDays;
  final bool isFirstLaunch;

  const SettingsState({
    this.deviceId,
    this.userName,
    required this.retentionDays,
    required this.isFirstLaunch,
  });

  bool get hasUserName {
    return userName != null && userName!.trim().isNotEmpty;
  }

  SettingsState copyWith({
    String? deviceId,
    String? userName,
    int? retentionDays,
    bool? isFirstLaunch,
  }) {
    return SettingsState(
      deviceId: deviceId ?? this.deviceId,
      userName: userName ?? this.userName,
      retentionDays: retentionDays ?? this.retentionDays,
      isFirstLaunch: isFirstLaunch ?? this.isFirstLaunch,
    );
  }
}

/// Settings notifier
class SettingsNotifier extends Notifier<SettingsState> {
  late SettingsService _service;

  @override
  SettingsState build() {
    _service = SettingsService.instance;
    return SettingsState(
      deviceId: _service.deviceId,
      userName: _service.userName,
      retentionDays: _service.retentionDays,
      isFirstLaunch: _service.isFirstLaunch,
    );
  }

  /// Initialize settings (call on app start)
  Future<void> initialize() async {
    await _service.initialize();
    state = SettingsState(
      deviceId: _service.deviceId,
      userName: _service.userName,
      retentionDays: _service.retentionDays,
      isFirstLaunch: _service.isFirstLaunch,
    );
  }

  /// Update user name
  Future<void> setUserName(String name, {bool skipBroadcast = false}) async {
    await _service.setUserName(name);
    state = state.copyWith(userName: name, isFirstLaunch: false);

    // Only broadcast name change if explicitly allowed (not during first setup)
    if (!skipBroadcast) {
      try {
        await ref.read(messageProvider.notifier).broadcastNameChange(name);
      } catch (e) {
        print('Could not broadcast name change: $e');
      }
    }
  }

  /// Update retention days
  Future<void> setRetentionDays(int days) async {
    await _service.setRetentionDays(days);
    state = state.copyWith(retentionDays: days);
  }

  /// Reset all settings
  Future<void> resetAll() async {
    await _service.resetAll();
    state = SettingsState(
      deviceId: _service.deviceId,
      userName: _service.userName,
      retentionDays: _service.retentionDays,
      isFirstLaunch: _service.isFirstLaunch,
    );
  }
}

/// Provider for settings
final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(
  () => SettingsNotifier(),
);
