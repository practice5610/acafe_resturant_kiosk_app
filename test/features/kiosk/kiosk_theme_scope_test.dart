@TestOn('vm')
library;

import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_auth_repo.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/pos/domain/pos_category_layout.dart';
import 'package:acafe_customer/features/realtime/device_settings_event.dart';
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:acafe_customer/common/models/kiosk_theme.dart';
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

  const stored = '{"screen":{"bg":"#112233"},"name":{"size":18}}';
  final base = <String, Object>{
    AppConstants.token: 'tok',
    AppConstants.branch: 7,
    AppConstants.kioskDeviceId: 42,
  };

  test('no stored theme = built-in look', () async {
    final auth = await _provider({...base, AppConstants.kioskDeviceCategory: 'kiosk'});
    expect(auth.portraitTheme.isEmpty, isTrue);
  });

  test('a kiosk device reads its stored theme (survives restart)', () async {
    final auth = await _provider({
      ...base,
      AppConstants.kioskDeviceCategory: 'kiosk',
      AppConstants.kioskTheme: stored,
    });
    expect(auth.portraitTheme.screenBg, const Color(0xFF112233));
    expect(auth.portraitTheme.name!.size, 18);
  });

  test('SCOPE LOCK: a POS-category device never gets a theme', () async {
    final auth = await _provider({
      ...base,
      AppConstants.kioskDeviceCategory: 'pos',
      AppConstants.kioskTheme: stored,
    });
    expect(auth.portraitTheme.isEmpty, isTrue);
  });

  test('realtime push applies, null key leaves it, {} resets, other device ignored',
      () async {
    final auth = await _provider({...base, AppConstants.kioskDeviceCategory: 'kiosk'});
    var o = await auth.applyDeviceSettingsFromRealtime(
        deviceId: 42, branchId: 7, theme: KioskTheme.fromJson({'screen': {'bg': '#112233'}}));
    expect(o, KioskDeviceSettingsOutcome.applied);
    expect(auth.portraitTheme.screenBg, const Color(0xFF112233));

    // Frame without `theme` (older server) must not clear it.
    o = await auth.applyDeviceSettingsFromRealtime(deviceId: 42, branchId: 7, name: 'x');
    expect(auth.portraitTheme.screenBg, const Color(0xFF112233));

    // Another device's frame is ignored.
    o = await auth.applyDeviceSettingsFromRealtime(
        deviceId: 99, branchId: 7, theme: KioskTheme.fromJson({'screen': {'bg': '#FF0000'}}));
    expect(o, KioskDeviceSettingsOutcome.ignored);
    expect(auth.portraitTheme.screenBg, const Color(0xFF112233));

    // Reset ({}).
    o = await auth.applyDeviceSettingsFromRealtime(
        deviceId: 42, branchId: 7, theme: KioskTheme.fromJson(<String, dynamic>{}));
    expect(o, KioskDeviceSettingsOutcome.applied);
    expect(auth.portraitTheme.isEmpty, isTrue);
  });
}
