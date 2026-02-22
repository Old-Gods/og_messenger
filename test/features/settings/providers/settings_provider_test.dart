import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:og_messenger/features/settings/providers/settings_provider.dart';
import 'package:og_messenger/features/settings/data/services/settings_service.dart';
import 'package:og_messenger/core/constants/app_constants.dart';
import '../../../helpers/test_helpers.dart';

void main() {
  group('SettingsProvider', () {
    late ProviderContainer container;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      TestHelpers.setupMockSharedPreferences();
      // Initialize the settings service before tests
      await SettingsService.instance.initialize();
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    group('initial state', () {
      test('has default values on first launch', () async {
        final state = container.read(settingsProvider);

        // isFirstLaunch becomes false after SettingsService.initialize() completes
        // because it generates a device ID and marks first launch as complete
        expect(state.isFirstLaunch, false);
        expect(state.retentionDays, AppConstants.defaultRetentionDays);
        expect(state.deviceId, isNotNull); // Device ID is generated during init
        expect(state.userName, isNull);
        expect(state.hasUserName, false);
      });
    });

    group('hasUserName', () {
      test('returns false when userName is null', () async {
        TestHelpers.setupMockSharedPreferences();
        await SettingsService.instance.initialize();
        final newContainer = ProviderContainer();
        final state = newContainer.read(settingsProvider);

        expect(state.hasUserName, false);
        newContainer.dispose();
      });

      test('returns false when userName is empty', () async {
        TestHelpers.setupMockSharedPreferences({AppConstants.keyUsername: ''});
        await SettingsService.instance.initialize();
        final newContainer = ProviderContainer();
        final state = newContainer.read(settingsProvider);

        expect(state.hasUserName, false);
        newContainer.dispose();
      });

      test('returns false when userName is only whitespace', () async {
        TestHelpers.setupMockSharedPreferences({
          AppConstants.keyUsername: '   ',
        });
        await SettingsService.instance.initialize();
        final newContainer = ProviderContainer();
        final state = newContainer.read(settingsProvider);

        expect(state.hasUserName, false);
        newContainer.dispose();
      });

      test('returns true when userName has value', () async {
        // Set userName through the provider
        final notifier = container.read(settingsProvider.notifier);
        await notifier.setUserName('John Doe', skipBroadcast: true);

        final state = container.read(settingsProvider);
        expect(state.hasUserName, true);
        expect(state.userName, 'John Doe');
      });
    });

    group('setUserName', () {
      test('updates userName successfully', () async {
        final notifier = container.read(settingsProvider.notifier);

        await notifier.setUserName('Alice', skipBroadcast: true);

        final state = container.read(settingsProvider);
        expect(state.userName, 'Alice');
        expect(state.hasUserName, true);
      });

      test('trims whitespace from userName', () async {
        final notifier = container.read(settingsProvider.notifier);

        await notifier.setUserName('  Bob  ', skipBroadcast: true);

        final state = container.read(settingsProvider);
        expect(state.userName, 'Bob');
      });
    });

    group('retention days', () {
      test('updates retention days within valid range', () async {
        final notifier = container.read(settingsProvider.notifier);

        await notifier.setRetentionDays(45);

        final state = container.read(settingsProvider);
        expect(state.retentionDays, 45);
      });

      test('clamps retention days to minimum', () async {
        final notifier = container.read(settingsProvider.notifier);

        await notifier.setRetentionDays(5); // Below minimum

        final state = container.read(settingsProvider);
        expect(state.retentionDays, AppConstants.minRetentionDays);
      });

      test('clamps retention days to maximum', () async {
        final notifier = container.read(settingsProvider.notifier);

        await notifier.setRetentionDays(100); // Above maximum

        final state = container.read(settingsProvider);
        expect(state.retentionDays, AppConstants.maxRetentionDays);
      });
    });

    group('deviceId', () {
      test(
        'has deviceId after initialization',
        () async {
          final notifier = container.read(settingsProvider.notifier);

          await notifier.initialize();

          final state = container.read(settingsProvider);
          // Device ID should be set after initialization
          expect(state.deviceId, isNotNull);
        },
        skip:
            'Requires platform bindings for device_info_plus (not available in test environment)',
      );

      test(
        'deviceId persists across provider instances',
        () async {
          TestHelpers.setupMockSharedPreferences({
            AppConstants.keyDeviceId: 'existing-device-id',
          });
          final newContainer = ProviderContainer();
          await newContainer.read(settingsProvider.notifier).initialize();

          final state = newContainer.read(settingsProvider);
          expect(state.deviceId, 'existing-device-id');
          newContainer.dispose();
        },
        skip:
            'Requires platform bindings for device_info_plus (not available in test environment)',
      );
    });

    group('networkId', () {
      test('updates network ID on refresh', () async {
        final notifier = container.read(settingsProvider.notifier);

        await notifier.refreshNetworkId();

        final state = container.read(settingsProvider);
        expect(state.networkId, isNotNull);
      });

      test('defaults to "Unknown" when not set', () {
        final state = container.read(settingsProvider);
        expect(state.networkId, 'Unknown');
      });
    });

    group('network connectivity', () {
      test('has default connectivity state', () {
        final state = container.read(settingsProvider);
        
        expect(state.isConnected, true);
        expect(state.connectedNetworkId, 'Unknown');
      });

      test('updateNetworkStatus updates connectivity fields', () {
        final notifier = container.read(settingsProvider.notifier);
        
        notifier.updateNetworkStatus(
          networkId: '192.168.1.1',
          isConnected: true,
        );
        
        final state = container.read(settingsProvider);
        expect(state.isConnected, true);
        expect(state.networkId, '192.168.1.1');
        expect(state.connectedNetworkId, '192.168.1.1');
      });

      test('updateNetworkStatus handles disconnection', () {
        final notifier = container.read(settingsProvider.notifier);
        
        notifier.updateNetworkStatus(
          networkId: 'Unknown',
          isConnected: false,
        );
        
        final state = container.read(settingsProvider);
        expect(state.isConnected, false);
        expect(state.networkId, 'Unknown');
        expect(state.connectedNetworkId, 'Unknown');
      });

      test('updateNetworkStatus updates to different network', () {
        final notifier = container.read(settingsProvider.notifier);
        
        // Set initial network
        notifier.updateNetworkStatus(
          networkId: '192.168.1.1',
          isConnected: true,
        );
        
        var state = container.read(settingsProvider);
        expect(state.connectedNetworkId, '192.168.1.1');
        
        // Switch to different network
        notifier.updateNetworkStatus(
          networkId: '10.0.0.1',
          isConnected: true,
        );
        
        state = container.read(settingsProvider);
        expect(state.isConnected, true);
        expect(state.networkId, '10.0.0.1');
        expect(state.connectedNetworkId, '10.0.0.1');
      });
    });

    group('first launch', () {
      test('marks setup as complete when username is set', () async {
        final notifier = container.read(settingsProvider.notifier);

        await notifier.setUserName('TestUser', skipBroadcast: true);

        final state = container.read(settingsProvider);
        expect(state.isFirstLaunch, false);
      });
    });

    group('state persistence', () {
      test('persists state across provider creation', () async {
        final notifier = container.read(settingsProvider.notifier);
        await notifier.setUserName('TestUser', skipBroadcast: true);
        await notifier.setRetentionDays(60);

        // Create new container to simulate app restart
        final newContainer = ProviderContainer();
        await newContainer.read(settingsProvider.notifier).initialize();
        final newState = newContainer.read(settingsProvider);

        expect(newState.userName, 'TestUser');
        expect(newState.retentionDays, 60);
        expect(newState.isFirstLaunch, false);

        newContainer.dispose();
      });
    });
  });
}
