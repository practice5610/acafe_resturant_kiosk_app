import 'dart:io';

import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_auth_repo.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_manager_repo.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/pos/domain/pos_routes.dart';
import 'package:acafe_customer/features/pos/domain/pos_staff_session.dart';
import 'package:acafe_customer/features/pos/domain/pos_staff_session_repo.dart';
import 'package:acafe_customer/features/pos/providers/pos_session_provider.dart';
import 'package:acafe_customer/features/pos/providers/pos_staff_session_provider.dart';
import 'package:acafe_customer/features/pos/widgets/pos_staff_gate.dart';
import 'package:acafe_customer/features/pos/widgets/pos_staff_lock_screen.dart';
import 'package:acafe_customer/features/pos/widgets/pos_top_nav_bar.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_pos_staff_backend.dart';

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

late FakePosStaffBackend backend;
late KioskAuthProvider auth;
late PosSessionProvider stepUp;
late PosStaffSessionProvider staff;

Future<void> _providers({bool loginRequired = true, bool deviceLoggedIn = true}) async {
  backend = FakePosStaffBackend(staffLoginRequired: loginRequired);
  backend.setPin('sophie', '1234');
  backend.setPin('thomas', '4321');
  SharedPreferences.setMockInitialValues({
    if (deviceLoggedIn) AppConstants.token: 'device-token',
    AppConstants.branch: 1,
    AppConstants.kioskDeviceCategory: 'pos',
    AppConstants.kioskBranchName: 'Amsterdam',
    AppConstants.kioskDeviceName: 'Till 1',
  });
  final prefs = await SharedPreferences.getInstance();
  final Dio dio = Dio(BaseOptions(baseUrl: 'http://localhost'))..httpClientAdapter = backend;
  final client = DioClient('http://localhost', dio,
      loggingInterceptor: LoggingInterceptor(), sharedPreferences: prefs);
  auth = KioskAuthProvider(kioskAuthRepo: KioskAuthRepo(dioClient: client, sharedPreferences: prefs));
  stepUp = PosSessionProvider(
      kioskManagerRepo: KioskManagerRepo(dioClient: client, sharedPreferences: prefs));
  staff = PosStaffSessionProvider(
    repo: PosStaffSessionRepo(dioClient: client),
    tokenStore: MemoryPosStaffTokenStore(),
    dioClient: client,
  );
}

Future<void> _pumpGate(WidgetTester tester, {Size size = const Size(1366, 1024)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<KioskAuthProvider>.value(value: auth),
        ChangeNotifierProvider<PosSessionProvider>.value(value: stepUp),
        ChangeNotifierProvider<PosStaffSessionProvider>.value(value: staff),
      ],
      child: const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: PosStaffGate(
          child: Scaffold(body: Center(child: Text('THE TILL'))),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _typePin(WidgetTester tester, String pin) async {
  for (final String digit in pin.split('')) {
    await tester.tap(find.descendant(
      of: find.byType(PosStaffLockScreen),
      matching: find.text(digit),
    ).last);
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);

  group('gate', () {
    testWidgets('switch off: the till shows, no PIN screen, exactly as today',
        (tester) async {
      await _providers(loginRequired: false);
      await _pumpGate(tester);

      expect(find.text('THE TILL'), findsOneWidget);
      expect(find.byType(PosStaffLockScreen), findsNothing);
    });

    testWidgets('switch on and nobody signed in: the PIN screen covers the till',
        (tester) async {
      await _providers();
      await _pumpGate(tester);

      expect(find.byType(PosStaffLockScreen), findsOneWidget);
      // Still mounted underneath -- a sale in progress survives the lock --
      // but not reachable.
      expect(find.text('THE TILL', skipOffstage: false), findsOneWidget);
      expect(find.text('Who is on the till?'), findsOneWidget);
    });

    testWidgets('a device that is not logged in never sees the PIN screen',
        (tester) async {
      await _providers(deviceLoggedIn: false);
      await _pumpGate(tester);

      expect(find.byType(PosStaffLockScreen), findsNothing);
    });
  });

  group('lock screen', () {
    // Two fixed buttons, not the branch's role rows. Their keys are the sentinel
    // ids the lock screen uses for Employee (-1) and Manager (-2); neither is a
    // real role id and neither is ever sent to the server.
    const Key employeeCard = Key('pos-lock-role--1');
    const Key managerCard = Key('pos-lock-role--2');

    testWidgets('shows the two fixed buttons, then a PIN card for the one tapped',
        (tester) async {
      await _providers();
      await _pumpGate(tester);

      // Always exactly Employee and Manager -- the roster's own roles (e.g. an
      // Owner card) never appear here, so the screen is the same everywhere.
      expect(find.byKey(employeeCard), findsOneWidget);
      expect(find.byKey(managerCard), findsOneWidget);
      expect(find.text('Employee'), findsOneWidget);
      expect(find.text('Manager'), findsOneWidget);
      expect(find.byKey(const Key('pos-lock-role-14')), findsNothing); // no Owner
      expect(find.text('Choose your role to sign in'), findsOneWidget);

      await tester.tap(find.byKey(employeeCard));
      await tester.pumpAndSettle();

      expect(find.text('Enter your PIN'), findsOneWidget);
    });

    testWidgets('the right PIN signs in and uncovers the till', (tester) async {
      await _providers();
      await _pumpGate(tester);

      await tester.tap(find.byKey(employeeCard));
      await tester.pumpAndSettle();
      await _typePin(tester, '1234');

      expect(find.byType(PosStaffLockScreen), findsNothing);
      expect(find.text('THE TILL'), findsOneWidget);
      expect(staff.session?.name, 'Sophie Jansen');
      // Signed in means the idle timer is armed; the provider is supplied with
      // .value, so the tree will not dispose it for us.
      staff.dispose();
    });

    testWidgets('an employee PIN on the Manager button is refused', (tester) async {
      await _providers();
      await _pumpGate(tester);

      // Tap Manager but type Sophie's (Employee) PIN. The button is sent as the
      // group, so the server refuses her: a real PIN on the wrong button reads as
      // a generic wrong PIN, never revealing that the PIN exists on the other side.
      await tester.tap(find.byKey(managerCard));
      await tester.pumpAndSettle();
      await _typePin(tester, '1234');

      expect(find.byType(PosStaffLockScreen), findsOneWidget);
      expect(staff.session, isNull);
      expect(find.text('That PIN was not recognised. 4 tries left.'), findsOneWidget);
    });

    testWidgets('a manager PIN on the Employee button is refused', (tester) async {
      await _providers();
      await _pumpGate(tester);

      await tester.tap(find.byKey(employeeCard));
      await tester.pumpAndSettle();
      await _typePin(tester, '4321'); // Thomas is a Manager

      expect(find.byType(PosStaffLockScreen), findsOneWidget);
      expect(staff.session, isNull);
    });

    testWidgets('the manager PIN signs the manager in', (tester) async {
      await _providers();
      await _pumpGate(tester);

      await tester.tap(find.byKey(managerCard));
      await tester.pumpAndSettle();
      await _typePin(tester, '4321');

      expect(staff.session?.name, 'Thomas de Vries');
      staff.dispose();
    });

    testWidgets('a wrong PIN says so and how many tries are left', (tester) async {
      await _providers();
      await _pumpGate(tester);

      await tester.tap(find.byKey(employeeCard));
      await tester.pumpAndSettle();
      await _typePin(tester, '9999');

      expect(find.byType(PosStaffLockScreen), findsOneWidget);
      expect(find.text('That PIN was not recognised. 4 tries left.'), findsOneWidget);
    });

    testWidgets('five wrong PINs show a lockout countdown', (tester) async {
      await _providers();
      await _pumpGate(tester);

      await tester.tap(find.byKey(employeeCard));
      await tester.pumpAndSettle();
      for (int i = 0; i < 5; i++) {
        await _typePin(tester, '9999');
      }

      expect(find.textContaining('Too many wrong PINs. Try again in 5:00'), findsOneWidget);
      staff.dispose();
    });

    testWidgets('changing the selected role clears the entered PIN',
        (tester) async {
      await _providers();
      await _pumpGate(tester);

      await tester.tap(find.byKey(employeeCard));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
        of: find.byType(PosStaffLockScreen),
        matching: find.text('1'),
      ).last);
      await tester.pump();

      // Go back and pick a different role: the two typed digits are gone.
      await tester.tap(find.byKey(const Key('pos-lock-back')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(managerCard));
      await tester.pumpAndSettle();

      // No filled dots: a fresh card for the new role.
      expect(find.byType(PosStaffLockScreen), findsOneWidget);
      expect(staff.session, isNull);
    });

    testWidgets('lays out without overflow on a narrow tablet', (tester) async {
      await _providers();
      await _pumpGate(tester, size: const Size(800, 1100));

      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(employeeCard));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // On a narrow screen the PIN card takes the faces' place, with a way back.
      expect(find.byKey(const Key('pos-lock-back')), findsOneWidget);
    });
  });

  group('top bar', () {
    Future<void> pumpBar(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1430, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final router = GoRouter(
        initialLocation: PosRoutes.home,
        routes: [
          GoRoute(
            path: PosRoutes.home,
            builder: (context, state) => const Scaffold(
              body: Column(children: [PosTopNavBar(currentPath: PosRoutes.home)]),
            ),
          ),
          GoRoute(
            path: RouterHelper.kioskLoginScreen,
            builder: (context, state) => const Scaffold(body: Text('LOGIN')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<KioskAuthProvider>.value(value: auth),
            ChangeNotifierProvider<PosSessionProvider>.value(value: stepUp),
            ChangeNotifierProvider<PosStaffSessionProvider>.value(value: staff),
          ],
          child: MaterialApp.router(debugShowCheckedModeBanner: false, routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
    }

    const PosStaffSession cashier = PosStaffSession(
      id: 'sophie',
      staffId: 3,
      name: 'Sophie Jansen',
      initials: 'SJ',
      role: 'Employee',
      permissions: {'apply_discounts': true, 'view_orders': true},
    );

    testWidgets('shows who is signed in, with Switch user and Lock', (tester) async {
      await _providers();
      staff.debugSignIn(cashier);
      await pumpBar(tester);

      expect(find.text('Sophie'), findsOneWidget);
      await tester.tap(find.byKey(const Key('pos-staff-menu-button')));
      await tester.pumpAndSettle();

      expect(find.text('Sophie Jansen'), findsOneWidget);
      expect(find.text('Switch user'), findsOneWidget);
      expect(find.text('Lock'), findsOneWidget);
      expect(find.text('Log out terminal'), findsOneWidget);
    });

    testWidgets('Lock ends the session', (tester) async {
      await _providers();
      staff.debugSignIn(cashier);
      await pumpBar(tester);

      await tester.tap(find.byKey(const Key('pos-staff-menu-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lock'));
      await tester.pumpAndSettle();

      expect(staff.isSignedIn, isFalse);
    });

    testWidgets('a cashier sees no Report or Settings, and no manager lock',
        (tester) async {
      await _providers();
      staff.debugSignIn(cashier);
      stepUp.debugSetElevated(true); // even with the device step-up granted
      await pumpBar(tester);

      expect(find.text('Report'), findsNothing);
      expect(find.text('Settings'), findsNothing);
      expect(find.byKey(PosNavBarSpec.lockButtonKey), findsNothing);
    });

    testWidgets('with the switch off the bar is exactly as before', (tester) async {
      await _providers(loginRequired: false);
      staff.debugSetRoster(PosSignInRoster.off);
      stepUp.debugSetElevated(true);
      await pumpBar(tester);

      expect(find.text('Report'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.byKey(PosNavBarSpec.lockButtonKey), findsOneWidget);
      expect(find.byKey(const Key('pos-staff-menu-button')), findsNothing);
    });
  });
}
