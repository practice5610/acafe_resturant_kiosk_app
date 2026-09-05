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
import 'package:acafe_customer/features/pos/widgets/pos_staff_settings_panel.dart';
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

Future<void> _pumpStaff(WidgetTester tester) async {
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

  await tester.tap(find.text('STAFF'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);

  testWidgets('Staff UI matches Figma chrome and fixtures', (tester) async {
    await _pumpStaff(tester);

    expect(find.text(PosStaffSettingsPanel.pageTitle), findsWidgets);
    expect(find.text(PosStaffSettingsPanel.pageSubtitle), findsOneWidget);
    expect(find.text('Add Staff Member'), findsOneWidget);

    expect(find.text('SHIFTS'), findsOneWidget);
    expect(find.text('Morning'), findsOneWidget);
    expect(find.text('Afternoon'), findsOneWidget);
    expect(find.text('Evening'), findsOneWidget);
    expect(find.text('+9 more'), findsOneWidget);
    expect(find.text('+8 more'), findsOneWidget);
    expect(find.text('+10 more'), findsOneWidget);

    expect(find.text('TEAM OF THE DAY'), findsOneWidget);
    expect(find.text('Maria van den Berg'), findsOneWidget);
    expect(find.text('Thomas de Vries'), findsWidgets);
    expect(find.text('MEMBER DETAILS'), findsOneWidget);
    expect(find.text('PERMISSIONS'), findsOneWidget);
    expect(find.text('Process refunds'), findsOneWidget);
    expect(find.text('Generate'), findsOneWidget);
    expect(
      find.text(
        'Restricted actions on POS will prompt a manager override passcode.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('selecting a team member updates Member Details', (tester) async {
    await _pumpStaff(tester);

    expect(find.widgetWithText(TextField, 'Thomas de Vries'), findsOneWidget);

    await tester.tap(find.text('Sophie Jansen'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Sophie Jansen'), findsOneWidget);
    expect(find.text('Employee'), findsWidgets);
  });

  test('staff section subtitle matches Figma', () {
    expect(
      PosSettingsSection.staff.subtitle,
      PosStaffSettingsPanel.pageSubtitle,
    );
  });
}
