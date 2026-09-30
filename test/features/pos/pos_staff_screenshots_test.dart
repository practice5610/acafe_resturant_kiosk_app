@Tags(['screenshots'])
library;

import 'dart:io';

import 'package:acafe_customer/common/models/config_model.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:acafe_customer/di_container.dart' as di;
import 'package:acafe_customer/features/kiosk/domain/kiosk_auth_repo.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_manager_repo.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/language/providers/localization_provider.dart';
import 'package:acafe_customer/features/pos/domain/pos_routes.dart';
import 'package:acafe_customer/features/pos/domain/pos_settings_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_staff_session.dart';
import 'package:acafe_customer/features/pos/domain/pos_staff_session_repo.dart';
import 'package:acafe_customer/features/pos/pos_shell.dart';
import 'package:acafe_customer/features/pos/providers/pos_access_scope.dart';
import 'package:acafe_customer/features/pos/providers/pos_session_provider.dart';
import 'package:acafe_customer/features/pos/providers/pos_staff_session_provider.dart';
import 'package:acafe_customer/features/pos/screens/pos_settings_screen.dart';
import 'package:acafe_customer/features/pos/widgets/pos_staff_gate.dart';
import 'package:acafe_customer/features/pos/widgets/pos_staff_lock_screen.dart';
import 'package:acafe_customer/features/pos/widgets/pos_top_nav_bar.dart';
import 'package:acafe_customer/features/splash/domain/reposotories/splash_repo.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:acafe_customer/main.dart' show navigatorKey;
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_pos_staff_backend.dart';

/// Renders the staff screens to PNG for review.
///
/// Run with:
///   flutter test test/features/pos/pos_staff_screenshots_test.dart --update-goldens
///
/// Tagged so a normal `flutter test` run skips the comparison — these are
/// pictures for a human, not pixel assertions to defend.
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

// Golden paths resolve against this test file's directory.
const String _out = '../../../../staff-roles-screenshots';

late FakePosStaffBackend backend;
late KioskAuthProvider auth;
late PosSessionProvider stepUp;
late PosStaffSessionProvider staff;
late SharedPreferences prefs;
late DioClient client;

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

Future<void> _providers({bool loginRequired = true}) async {
  backend = FakePosStaffBackend(staffLoginRequired: loginRequired);
  backend.setPin('sophie', '1234');
  backend.setPin('thomas', '4321');
  backend.setPin('maria', '1111');
  backend.setPin('liam', '2222');
  SharedPreferences.setMockInitialValues({
    AppConstants.token: 'device-token',
    AppConstants.branch: 1,
    AppConstants.languageCode: 'en',
    AppConstants.countryCode: 'NL',
    AppConstants.kioskDeviceCategory: 'pos',
    AppConstants.kioskDeviceName: 'Till 1 Amsterdam',
    AppConstants.kioskBranchName: 'Amsterdam',
    AppConstants.kioskUsername: 'till1',
    AppConstants.kioskAllergenTagEnabled: true,
  });
  prefs = await SharedPreferences.getInstance();
  final Dio dio = Dio(BaseOptions(baseUrl: 'http://localhost'))..httpClientAdapter = backend;
  client = DioClient('http://localhost', dio,
      loggingInterceptor: LoggingInterceptor(), sharedPreferences: prefs);
  auth = KioskAuthProvider(
      kioskAuthRepo: KioskAuthRepo(dioClient: client, sharedPreferences: prefs));
  stepUp = PosSessionProvider(
      kioskManagerRepo: KioskManagerRepo(dioClient: client, sharedPreferences: prefs));
  staff = PosStaffSessionProvider(
    repo: PosStaffSessionRepo(dioClient: client),
    tokenStore: MemoryPosStaffTokenStore(),
    dioClient: client,
  );
  if (di.sl.isRegistered<DioClient>()) di.sl.unregister<DioClient>();
  di.sl.registerSingleton<DioClient>(client);
}

Widget _wrap(Widget child) => MultiProvider(
      providers: [
        ChangeNotifierProvider<SplashProvider>(
          create: (_) => _Splash(
              splashRepo: SplashRepo(dioClient: client, sharedPreferences: prefs)),
        ),
        ChangeNotifierProvider<LocalizationProvider>(
          create: (_) =>
              LocalizationProvider(sharedPreferences: prefs, dioClient: client),
        ),
        ChangeNotifierProvider<KioskAuthProvider>.value(value: auth),
        ChangeNotifierProvider<PosSessionProvider>.value(value: stepUp),
        ChangeNotifierProvider<PosStaffSessionProvider>.value(value: staff),
      ],
      child: PosShell(child: child),
    );

Future<void> _shot(WidgetTester tester, String name) async {
  await expectLater(
    find.byType(MaterialApp).first,
    matchesGoldenFile('$_out/$name.png'),
  );
}

Future<void> _pumpLock(WidgetTester tester, {Size size = const Size(1440, 960)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_wrap(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: PosStaffGate(child: Scaffold(body: SizedBox.expand())),
  )));
  await tester.pumpAndSettle();
}

Future<void> _tapPin(WidgetTester tester, String pin) async {
  for (final String d in pin.split('')) {
    await tester.tap(find
        .descendant(of: find.byType(PosStaffLockScreen), matching: find.text(d))
        .last);
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);
  tearDown(() {
    if (di.sl.isRegistered<DioClient>()) di.sl.unregister<DioClient>();
  });

  testWidgets('01 pin screen — idle', (tester) async {
    await _providers();
    await _pumpLock(tester);
    await _shot(tester, 'pos-01-pin-screen-idle');
  });

  testWidgets('02 pin screen — typing', (tester) async {
    await _providers();
    await _pumpLock(tester);
    await tester.tap(find.byKey(const Key('pos-lock-avatar-sophie')));
    await tester.pumpAndSettle();
    await _tapPin(tester, '12');
    await _shot(tester, 'pos-02-pin-screen-typing');
  });

  testWidgets('03 pin screen — wrong PIN', (tester) async {
    await _providers();
    await _pumpLock(tester);
    await tester.tap(find.byKey(const Key('pos-lock-avatar-sophie')));
    await tester.pumpAndSettle();
    await _tapPin(tester, '9999');
    await _shot(tester, 'pos-03-pin-screen-wrong-pin');
  });

  testWidgets('04 pin screen — locked out', (tester) async {
    await _providers();
    await _pumpLock(tester);
    await tester.tap(find.byKey(const Key('pos-lock-avatar-sophie')));
    await tester.pumpAndSettle();
    for (int i = 0; i < 5; i++) {
      await _tapPin(tester, '9999');
    }
    await _shot(tester, 'pos-04-pin-screen-lockout');
    staff.dispose();
  });

  testWidgets('05 signed-in top bar and menu', (tester) async {
    await _providers();
    staff.debugSignIn(const PosStaffSession(
      id: 'sophie',
      staffId: 3,
      name: 'Sophie Jansen',
      initials: 'SJ',
      role: 'Employee',
      permissions: {'apply_discounts': true, 'view_orders': true},
    ));
    tester.view.physicalSize = const Size(1440, 420);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: PosRoutes.home,
      routes: [
        GoRoute(
          path: PosRoutes.home,
          builder: (_, __) => const Scaffold(
            body: Column(children: [PosTopNavBar(currentPath: PosRoutes.home)]),
          ),
        ),
        GoRoute(path: RouterHelper.kioskLoginScreen, builder: (_, __) => const Scaffold()),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_wrap(MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: router,
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pos-staff-menu-button')));
    await tester.pumpAndSettle();
    await _shot(tester, 'pos-05-signed-in-top-bar-menu');
    staff.dispose();
  });

  testWidgets('06 permission denied', (tester) async {
    await _providers();
    staff.debugSignIn(const PosStaffSession(
      id: 'sophie',
      staffId: 3,
      name: 'Sophie Jansen',
      initials: 'SJ',
      role: 'Employee',
      permissions: {'apply_discounts': true},
    ));
    tester.view.physicalSize = const Size(1000, 420);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      home: Scaffold(
        backgroundColor: PosSettingsSpec.pageBg,
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () =>
                  PosAccessScope.guard(context, PosPermission.closeDay),
              child: const Text('Close Day'),
            ),
          ),
        ),
      ),
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close Day'));
    await tester.pumpAndSettle();
    await _shot(tester, 'pos-06-permission-denied');
    staff.dispose();
  });

  testWidgets('07 staff screen with PIN row', (tester) async {
    await _providers(loginRequired: false);
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: PosSettingsSpec.pageBg,
        body: PosSettingsScreen(sharedPreferences: prefs),
      ),
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('STAFF'));
    await tester.pumpAndSettle();
    await _shot(tester, 'pos-07-staff-screen-pin-row');
  });

  testWidgets('08 add staff dialog with PIN', (tester) async {
    await _providers(loginRequired: false);
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: PosSettingsSpec.pageBg,
        body: PosSettingsScreen(sharedPreferences: prefs),
      ),
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('STAFF'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Staff Member'));
    await tester.pumpAndSettle();
    await _shot(tester, 'pos-08-add-staff-dialog-pin');
  });

  testWidgets('09 login switch OFF — till unchanged', (tester) async {
    await _providers(loginRequired: false);
    stepUp.debugSetElevated(true);
    tester.view.physicalSize = const Size(1440, 420);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: PosRoutes.home,
      routes: [
        GoRoute(
          path: PosRoutes.home,
          builder: (_, __) => const Scaffold(
            body: Column(children: [PosTopNavBar(currentPath: PosRoutes.home)]),
          ),
        ),
        GoRoute(path: RouterHelper.kioskLoginScreen, builder: (_, __) => const Scaffold()),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_wrap(MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: router,
    )));
    await tester.pumpAndSettle();
    await _shot(tester, 'pos-09-login-switch-off-unchanged');
  });
}
