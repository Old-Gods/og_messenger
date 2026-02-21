import 'package:flutter_test/flutter_test.dart';
import 'package:og_messenger/core/constants/app_constants.dart';

void main() {
  group('AppConstants', () {
    group('app info', () {
      test('has correct app name', () {
        expect(AppConstants.appName, 'OG Messenger');
      });

      test('has valid app version', () {
        expect(AppConstants.appVersion, isNotNull);
        expect(AppConstants.appVersion.isNotEmpty, true);
      });
    });

    group('settings keys', () {
      test('has correct device ID key', () {
        expect(AppConstants.keyDeviceId, 'device_id');
      });

      test('has correct username key', () {
        expect(AppConstants.keyUsername, 'username');
      });

      test('has correct retention days key', () {
        expect(AppConstants.keyRetentionDays, 'retention_days');
      });
    });

    group('default settings', () {
      test('has valid default retention days', () {
        expect(AppConstants.defaultRetentionDays, 30);
      });

      test('retention days range is valid', () {
        expect(
          AppConstants.minRetentionDays,
          lessThanOrEqualTo(AppConstants.defaultRetentionDays),
        );
        expect(
          AppConstants.defaultRetentionDays,
          lessThanOrEqualTo(AppConstants.maxRetentionDays),
        );
      });

      test('has valid minimum retention days', () {
        expect(AppConstants.minRetentionDays, 7);
        expect(AppConstants.minRetentionDays, greaterThan(0));
      });

      test('has valid maximum retention days', () {
        expect(AppConstants.maxRetentionDays, 90);
        expect(
          AppConstants.maxRetentionDays,
          greaterThan(AppConstants.minRetentionDays),
        );
      });
    });

    group('database', () {
      test('has correct database name', () {
        expect(AppConstants.databaseName, 'og_messenger.db');
      });

      test('database name has .db extension', () {
        expect(AppConstants.databaseName.endsWith('.db'), true);
      });
    });
  });
}
