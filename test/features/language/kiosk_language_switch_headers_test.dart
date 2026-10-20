import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:acafe_customer/features/language/providers/localization_provider.dart';
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Every language switch re-applies the request headers. A kiosk sees dozens
/// of switches a day (one tap per customer on the welcome screen), so that
/// path must stay idempotent.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late DioClient dio;
  late LocalizationProvider localization;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    dio = DioClient(
      'http://localhost',
      null,
      loggingInterceptor: LoggingInterceptor(),
      sharedPreferences: prefs,
    );
    localization =
        LocalizationProvider(sharedPreferences: prefs, dioClient: dio);
  });

  test('switching language does not stack another request logger', () async {
    for (final Locale locale in const [
      Locale('nl', 'NL'),
      Locale('fr', 'FR'),
      Locale('de', 'DE'),
      Locale('en', 'US'),
    ]) {
      await localization.setKioskLanguage(locale);
    }

    expect(dio.dio!.interceptors.whereType<LoggingInterceptor>(), hasLength(1),
        reason: 'each extra logger runs on every later request');
  });

  test('switching language sends it on the next request and remembers it',
      () async {
    await localization.setKioskLanguage(const Locale('de', 'DE'));

    expect(dio.dio!.options.headers['X-localization'], 'de');
    expect(prefs.getString(AppConstants.languageCode), 'de');
    expect(prefs.getString(AppConstants.countryCode), 'DE');
    expect(localization.locale, const Locale('de', 'DE'));
  });
}
