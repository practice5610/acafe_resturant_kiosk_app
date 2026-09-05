import 'dart:io';

import 'package:acafe_customer/common/models/config_model.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:acafe_customer/features/language/providers/localization_provider.dart';
import 'package:acafe_customer/features/pos/domain/pos_settings_spec.dart';
import 'package:acafe_customer/features/pos/pos_shell.dart';
import 'package:acafe_customer/features/pos/screens/pos_settings_screen.dart';
import 'package:acafe_customer/features/splash/domain/reposotories/splash_repo.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _loadFonts() async {
  final loader = FontLoader('Loew');
  for (final path in const [
    'assets/fonts/Loew-Regular.ttf',
    'assets/fonts/Loew-Medium.ttf',
    'assets/fonts/Loew-Bold.ttf',
    'assets/fonts/Loew-ExtraBold.ttf',
  ]) {
    loader.addFont(File(path)
        .readAsBytes()
        .then((bytes) => ByteData.view(Uint8List.fromList(bytes).buffer)));
  }
  await loader.load();
}

class _SettingsSplash extends SplashProvider {
  _SettingsSplash({required super.splashRepo});

  @override
  ConfigModel? get configModel => ConfigModel(
        restaurantName: 'A|CAFÉ Amsterdam',
        restaurantAddress: 'Nieuwendijk 123, 1012 MD Amsterdam',
        restaurantPhone: '+31 20 555 3829',
        restaurantEmail: 'info@acafe.nl',
        currencySymbol: '€',
        currencySymbolPosition: 'left',
        countryCode: 'NL',
        decimalPointSettings: 2,
        socialMediaLink: [
          SocialMediaLink(name: 'Website', link: 'https://www.acafegroup.com'),
        ],
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_loadFonts);

  testWidgets('Settings General golden at 1366x1024', (tester) async {
    const Size size = Size(1366, 1024);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({
      AppConstants.languageCode: 'nl',
      AppConstants.countryCode: 'NL',
    });
    final prefs = await SharedPreferences.getInstance();
    final dio = DioClient(
      'http://localhost',
      null,
      loggingInterceptor: LoggingInterceptor(),
      sharedPreferences: prefs,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SplashProvider>(
            create: (_) => _SettingsSplash(
              splashRepo:
                  SplashRepo(dioClient: dio, sharedPreferences: prefs),
            ),
          ),
          ChangeNotifierProvider<LocalizationProvider>(
            create: (_) => LocalizationProvider(
              sharedPreferences: prefs,
              dioClient: dio,
            ),
          ),
        ],
        child: MediaQuery(
          data: const MediaQueryData(size: size),
          child: PosShell(
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              home: Scaffold(
                backgroundColor: PosSettingsSpec.pageBg,
                body: PosSettingsScreen(sharedPreferences: prefs),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('General'), findsOneWidget);
    expect(find.text('Save Changes'), findsOneWidget);
    expect(find.text('A|CAFÉ Amsterdam'), findsOneWidget);

    await expectLater(
      find.byType(PosSettingsScreen),
      matchesGoldenFile('goldens/pos_settings_general_1366.png'),
    );
  }, skip: !Platform.isMacOS && !Platform.isLinux);

  testWidgets('Settings Payments golden at 1366x1024', (tester) async {
    const Size size = Size(1366, 1024);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({
      AppConstants.languageCode: 'nl',
      AppConstants.countryCode: 'NL',
    });
    final prefs = await SharedPreferences.getInstance();
    final dio = DioClient(
      'http://localhost',
      null,
      loggingInterceptor: LoggingInterceptor(),
      sharedPreferences: prefs,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SplashProvider>(
            create: (_) => _SettingsSplash(
              splashRepo:
                  SplashRepo(dioClient: dio, sharedPreferences: prefs),
            ),
          ),
          ChangeNotifierProvider<LocalizationProvider>(
            create: (_) => LocalizationProvider(
              sharedPreferences: prefs,
              dioClient: dio,
            ),
          ),
        ],
        child: MediaQuery(
          data: const MediaQueryData(size: size),
          child: PosShell(
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              home: Scaffold(
                backgroundColor: PosSettingsSpec.pageBg,
                body: PosSettingsScreen(sharedPreferences: prefs),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('PAYMENTS'));
    await tester.pumpAndSettle();

    expect(find.text('Payments'), findsOneWidget);
    expect(find.text('PAYMENT METHODS'), findsOneWidget);
    expect(find.text('TRANSACTION SETTINGS'), findsOneWidget);

    await expectLater(
      find.byType(PosSettingsScreen),
      matchesGoldenFile('goldens/pos_settings_payments_1366.png'),
    );
  }, skip: !Platform.isMacOS && !Platform.isLinux);
}
