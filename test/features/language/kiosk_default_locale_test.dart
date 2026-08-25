import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:acafe_customer/features/language/providers/localization_provider.dart';
import 'package:acafe_customer/features/splash/domain/reposotories/splash_repo.dart';
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A fresh kiosk must come up in English and stay there across reloads until
/// somebody picks a language. The regression this guards: `initSharedData`
/// seeded the locale from `AppConstants.languages[0]` (German) while
/// `LocalizationProvider` defaulted to English, so the kiosk showed English on
/// first run and silently flipped to German on a later reload.
DioClient _dio(SharedPreferences prefs) => DioClient(
      'http://localhost',
      null,
      loggingInterceptor: LoggingInterceptor(),
      sharedPreferences: prefs,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('fresh kiosk seeds and keeps English across repeated startups', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = SplashRepo(sharedPreferences: prefs, dioClient: _dio(prefs));

    // initSharedData returns after the first missing key it seeds, so a real
    // kiosk walks through them over several app starts. Simulate that.
    for (var i = 0; i < 10; i++) {
      await repo.initSharedData();
    }

    expect(prefs.getString(AppConstants.languageCode), 'en');
    expect(prefs.getString(AppConstants.countryCode), 'US');

    final provider =
        LocalizationProvider(sharedPreferences: prefs, dioClient: _dio(prefs));
    await Future<void>.delayed(Duration.zero);
    expect(provider.locale.languageCode, 'en');
  });

  test('an explicit choice survives later startups', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.languageCode, 'nl');
    await prefs.setString(AppConstants.countryCode, 'NL');

    final repo = SplashRepo(sharedPreferences: prefs, dioClient: _dio(prefs));
    for (var i = 0; i < 10; i++) {
      await repo.initSharedData();
    }

    expect(prefs.getString(AppConstants.languageCode), 'nl');

    final provider =
        LocalizationProvider(sharedPreferences: prefs, dioClient: _dio(prefs));
    await Future<void>.delayed(Duration.zero);
    expect(provider.locale.languageCode, 'nl');
  });
}
