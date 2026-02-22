import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/services/settings_service.dart';
import '../../messaging/providers/message_provider.dart';
import '../../network/data/services/network_info_service.dart';

/// Settings state model
class SettingsState {
  final String? deviceId;
  final String? userName;
  final int retentionDays;
  final bool isFirstLaunch;
  final String networkId;
  final bool isConnected;
  final String connectedNetworkId;

  const SettingsState({
    this.deviceId,
    this.userName,
    required this.retentionDays,
    required this.isFirstLaunch,
    this.networkId = 'Unknown',
    this.isConnected = true,
    this.connectedNetworkId = 'Unknown',
  });

  bool get hasUserName {
    return userName != null && userName!.trim().isNotEmpty;
  }

  SettingsState copyWith({
    String? deviceId,
    String? userName,
    int? retentionDays,
    bool? isFirstLaunch,
    String? networkId,
    bool? isConnected,
    String? connectedNetworkId,
  }) {
    return SettingsState(
      deviceId: deviceId ?? this.deviceId,
      userName: userName ?? this.userName,
      retentionDays: retentionDays ?? this.retentionDays,
      isFirstLaunch: isFirstLaunch ?? this.isFirstLaunch,
      networkId: networkId ?? this.networkId,
      isConnected: isConnected ?? this.isConnected,
      connectedNetworkId: connectedNetworkId ?? this.connectedNetworkId,
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
    print('⚙️ Initializing settings provider...');
    await _service.initialize();
    print('⚙️ Fetching network ID...');
    final networkId = await NetworkInfoService.instance.getCurrentNetworkId();
    print('⚙️ Network ID result: $networkId');
    state = SettingsState(
      deviceId: _service.deviceId,
      userName: _service.userName,
      retentionDays: _service.retentionDays,
      isFirstLaunch: _service.isFirstLaunch,
      networkId: networkId,
    );
  }

  /// Update user name
  Future<void> setUserName(String name, {bool skipBroadcast = false}) async {
    await _service.setUserName(name);
    await _service.setFirstLaunchComplete();
    // Use the actual value from service (which is trimmed)
    state = state.copyWith(userName: _service.userName, isFirstLaunch: false);

    // Only broadcast name change if explicitly allowed (not during first setup)
    if (!skipBroadcast) {
      try {
        await ref
            .read(messageProvider.notifier)
            .broadcastNameChange(_service.userName!);
      } catch (e) {
        print('Could not broadcast name change: $e');
      }
    }
  }

  /// Update retention days
  Future<void> setRetentionDays(int days) async {
    await _service.setRetentionDays(days);
    // Use the actual value from service (which is clamped)
    state = state.copyWith(retentionDays: _service.retentionDays);
  }

  /// Refresh network ID (call when network changes)
  Future<void> refreshNetworkId() async {
    final networkId = await NetworkInfoService.instance.getCurrentNetworkId();
    state = state.copyWith(networkId: networkId);
  }

  /// Update network connectivity status
  void updateNetworkStatus({
    required String networkId,
    required bool isConnected,
  }) {
    state = state.copyWith(
      networkId: networkId,
      isConnected: isConnected,
      connectedNetworkId: networkId,
    );
  }

  /// Reset all settings
  Future<void> resetAll() async {
    await _service.resetAll();
    final networkId = await NetworkInfoService.instance.getCurrentNetworkId();
    state = SettingsState(
      deviceId: _service.deviceId,
      userName: _service.userName,
      retentionDays: _service.retentionDays,
      isFirstLaunch: _service.isFirstLaunch,
      networkId: networkId,
    );
  }
}

/// Provider for settings
final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(
  () => SettingsNotifier(),
);
