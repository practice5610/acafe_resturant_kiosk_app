@TestOn('vm')
library;

import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_auth_repo.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/pos/domain/pos_category_layout.dart';
import 'package:acafe_customer/features/realtime/device_settings_event.dart';
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<KioskAuthProvider> _provider(Map<String, Object> prefs) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  final dio = DioClient('http://localhost', null,
      loggingInterceptor: LoggingInterceptor(), sharedPreferences: sp);
  return KioskAuthProvider(
      kioskAuthRepo: KioskAuthRepo(dioClient: dio, sharedPreferences: sp));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('categoryLayout is driven by the Show Category Images setting', () {
    test('defaults to the simple text rail when the setting is absent',
        () async {
      final auth = await _provider({});
      expect(auth.categoryLayout, PosCategoryLayout.list);
    });

    test('is the simple rail when the setting is off', () async {
      final auth = await _provider({
        AppConstants.kioskShowCategoryImages: false,
      });
      expect(auth.categoryLayout, PosCategoryLayout.list);
    });

    test('switches to the photo tiles when the setting is on', () async {
      final auth = await _provider({
        AppConstants.kioskShowCategoryImages: true,
      });
      expect(auth.categoryLayout, PosCategoryLayout.tiles);
    });

    test('a live device-settings push flips the rail', () async {
      final auth = await _provider({
        AppConstants.token: 'tok',
        AppConstants.branch: 7,
        AppConstants.kioskDeviceId: 42,
      });
      expect(auth.categoryLayout, PosCategoryLayout.list);

      final outcome = await auth.applyDeviceSettingsFromRealtime(
        deviceId: 42,
        branchId: 7,
        showCategoryImages: true,
      );

      expect(outcome, isNot(KioskDeviceSettingsOutcome.ignored));
      expect(auth.categoryLayout, PosCategoryLayout.tiles);
    });
  });

  group('DeviceSettingsEvent parses show_category_images', () {
    test('present true -> true', () {
      final e = DeviceSettingsEvent.fromJson({
        'device_id': 1,
        'branch_id': 1,
        'show_category_images': true,
      });
      expect(e.showCategoryImages, isTrue);
    });

    test('absent -> null (leave the local value alone)', () {
      final e = DeviceSettingsEvent.fromJson({
        'device_id': 1,
        'branch_id': 1,
      });
      expect(e.showCategoryImages, isNull);
    });
  });
}
