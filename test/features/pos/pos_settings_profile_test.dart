import 'dart:io';

import 'package:acafe_customer/common/models/config_model.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_auth_repo.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/language/providers/localization_provider.dart';
import 'package:acafe_customer/features/pos/domain/pos_settings_section.dart';
import 'package:acafe_customer/features/pos/domain/pos_settings_spec.dart';
import 'package:acafe_customer/features/pos/pos_shell.dart';
import 'package:acafe_customer/features/pos/screens/pos_settings_screen.dart';
import 'package:acafe_customer/features/splash/domain/reposotories/splash_repo.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/main.dart' show navigatorKey;
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

class _Splash extends SplashProvider {
  _Splash({required super.splashRepo});

  @override
  ConfigModel? get configModel => ConfigModel(
        restaurantName: 'A|CAFÉ',
        restaurantEmail: 'info@acafe.nl',
        restaurantPhone: '+31 20 000 0000',
        currencySymbol: '€',
      );
}

Future<void> _pumpProfile(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1366, 1024);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({
    AppConstants.token: 'tok',
    AppConstants.branch: 1,
    AppConstants.languageCode: 'nl',
    AppConstants.countryCode: 'NL',
    AppConstants.kioskDeviceCategory: 'pos',
    AppConstants.kioskDeviceName: 'Till 1 Amsterdam',
    AppConstants.kioskBranchName: 'Amsterdam',
    AppConstants.kioskUsername: 'till1',
    AppConstants.kioskBranchEmail: 'amsterdam@acafe.nl',
    AppConstants.kioskBranchPhone: '+31 20 555 1000',
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
          create: (_) => _Splash(
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
        ChangeNotifierProvider<KioskAuthProvider>(
          create: (_) => KioskAuthProvider(
            kioskAuthRepo:
                KioskAuthRepo(dioClient: dio, sharedPreferences: prefs),
          ),
        ),
      ],
      child: MediaQuery(
        data: const MediaQueryData(size: Size(1366, 1024)),
        child: PosShell(
          child: MaterialApp(
            navigatorKey: navigatorKey,
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

  await tester.tap(find.text('PROFILE'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);

  testWidgets('Profile shows terminal identity from session', (tester) async {
    await _pumpProfile(tester);

    expect(find.text('PROFILE'), findsWidgets);
    expect(
      find.text('Personal account settings and preferences'),
      findsOneWidget,
    );
    expect(find.text('TILL 1 AMSTERDAM'), findsOneWidget);
    expect(find.text('POS Terminal'), findsOneWidget);
    expect(find.text('Till 1 Amsterdam'), findsOneWidget);
    expect(find.text('amsterdam@acafe.nl'), findsOneWidget);
    expect(find.text('+31 20 555 1000'), findsOneWidget);
    expect(find.text('Nederlands (Dutch)'), findsOneWidget);
    expect(find.text('Change photo'), findsOneWidget);
    expect(find.text('Update'), findsNWidgets(2));
  });

  testWidgets('Update passcode explains admin-managed PIN', (tester) async {
    await _pumpProfile(tester);

    await tester.tap(find.text('Update').last);
    await tester.pumpAndSettle();

    expect(find.text('Update POS passcode'), findsOneWidget);
    expect(find.textContaining('configuration code'), findsOneWidget);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  });

  test('profile section subtitle matches Figma', () {
    expect(
      PosSettingsSection.profile.subtitle,
      'Personal account settings and preferences',
    );
  });
}
