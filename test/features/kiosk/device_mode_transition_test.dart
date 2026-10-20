import 'dart:async';

import 'package:acafe_customer/common/responsive/app_chrome.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/device_mode_repo.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_auth_repo.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_manager_repo.dart';
import 'package:acafe_customer/features/kiosk/providers/device_mode_provider.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_manager_provider.dart';
import 'package:acafe_customer/features/kiosk/widgets/device_mode_curtain.dart';
import 'package:acafe_customer/features/pos/domain/pos_routes.dart';
import 'package:acafe_customer/features/pos/domain/pos_staff_session.dart';
import 'package:acafe_customer/features/pos/domain/pos_staff_session_repo.dart';
import 'package:acafe_customer/features/pos/providers/pos_session_provider.dart';
import 'package:acafe_customer/features/pos/providers/pos_staff_session_provider.dart';
import 'package:acafe_customer/features/pos/widgets/pos_staff_gate.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Switching a till between POS and kiosk must never show a broken frame
/// (POS_KIOSK_MODE_PHASE1.md §5.6). The live repro: the shell swap rebuilt the
/// router from scratch (RangeError in GoRouter's parser, then "deactivated
/// widget's ancestor"), and the half-switched till was painted on the way.

/// Counts how many times it is created: a second creation is a remount.
class _Probe extends StatefulWidget {
  const _Probe();

  static int created = 0;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    _Probe.created++;
  }

  @override
  Widget build(BuildContext context) => const Text('probe');
}

/// Exit and enter calls the test resolves by hand.
class _HeldRepo extends DeviceModeRepo {
  _HeldRepo() : super(dioClient: null);

  Completer<DeviceModeResponse> exit = Completer();
  DeviceModeResponse enter = const DeviceModeResponse(200, {});

  @override
  Future<DeviceModeResponse> exitKiosk(String pin) => exit.future;

  @override
  Future<DeviceModeResponse> enterKiosk() async => enter;
}

class _Roster extends PosStaffSessionRepo {
  _Roster() : super(dioClient: null);

  int calls = 0;

  @override
  Future<PosSignInRoster?> signInRoster() async {
    calls++;
    return const PosSignInRoster(staffLoginRequired: true, pinLength: 4, lockoutSeconds: 0, members: []);
  }
}

const DeviceModeResponse _exitOk = DeviceModeResponse(200, {
  'device': {'id': 2, 'category': 'pos', 'kiosk_mode': false},
  'staff_session': {
    'token': 'staff-token',
    'expires_at': '2030-01-01T00:00:00+00:00',
    'staff': {'id': 'sara', 'staff_id': 7, 'name': 'Sara', 'initials': 'S', 'role': 'Employee', 'permissions': {}},
  },
});

void main() {
  late SharedPreferences prefs;
  late DioClient dio;
  late KioskAuthProvider auth;

  Future<void> boot({bool kioskMode = false}) async {
    SharedPreferences.setMockInitialValues({
      AppConstants.token: 'device-token',
      AppConstants.branch: 1,
      AppConstants.kioskDeviceId: 2,
      AppConstants.kioskDeviceCategory: 'pos',
      AppConstants.kioskDeviceKioskMode: kioskMode,
    });
    prefs = await SharedPreferences.getInstance();
    dio = DioClient(AppConstants.baseUrl, null,
        loggingInterceptor: LoggingInterceptor(), sharedPreferences: prefs);
    auth = KioskAuthProvider(kioskAuthRepo: KioskAuthRepo(dioClient: dio, sharedPreferences: prefs));
  }

  ({DeviceModeProvider modes, PosStaffSessionProvider staff, _Roster roster, List<String> went}) build(
      DeviceModeRepo repo) {
    final roster = _Roster();
    final staff = PosStaffSessionProvider(repo: roster);
    final went = <String>[];
    final modes = DeviceModeProvider(
      repo: repo,
      auth: auth,
      staff: staff,
      posSession: PosSessionProvider(kioskManagerRepo: KioskManagerRepo(dioClient: dio, sharedPreferences: prefs)),
      kioskManager: KioskManagerProvider(kioskManagerRepo: KioskManagerRepo(dioClient: dio, sharedPreferences: prefs)),
      cart: CartProvider(cartRepo: null),
      curtainFade: Duration.zero,
      landingDelay: Duration.zero,
      navigate: went.add,
    );
    return (modes: modes, staff: staff, roster: roster, went: went);
  }

  group('the router survives a mode switch', () {
    testWidgets('swapping the kiosk shell for the POS shell keeps the router', (tester) async {
      // The app hands AppChrome a Router. Rebuilt from scratch it re-parses
      // the address -- the RangeError seen live -- and strands open dialogs.
      await boot(kioskMode: true);
      final GoRouter router = GoRouter(routes: [GoRoute(path: '/', builder: (_, __) => const _Probe())]);
      addTearDown(router.dispose);
      await tester.pumpWidget(ChangeNotifierProvider<KioskAuthProvider>.value(
        value: auth,
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => AppChrome(child: child),
        ),
      ));
      final State before = tester.state(find.byWidgetPredicate((w) => w is Router));

      await auth.applyKioskMode(false);
      await tester.pump();

      expect(tester.state(find.byWidgetPredicate((w) => w is Router)), same(before),
          reason: 'the router must move into the POS shell, not be rebuilt');
    });

    testWidgets('the staff gate keeps the screen mounted while it reads the roster', (tester) async {
      await boot();
      _Probe.created = 0;
      final staff = PosStaffSessionProvider(repo: _Roster());
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<KioskAuthProvider>.value(value: auth),
          ChangeNotifierProvider<PosStaffSessionProvider>.value(value: staff),
        ],
        child: const MaterialApp(home: PosStaffGate(child: _Probe())),
      ));

      expect(_Probe.created, 1, reason: 'mounted, just not shown, before the roster is in');
      expect(find.text('probe'), findsNothing, reason: 'nothing is shown before the roster is in');

      await tester.pumpAndSettle();

      expect(_Probe.created, 1);
    });
  });

  group('one switch, one transition', () {
    test('a push during a switch from this till does not flip the mode under it', () async {
      await boot(kioskMode: true);
      final repo = _HeldRepo();
      final t = build(repo);

      final pending = t.modes.switchToPos('4321');
      await auth.applyDeviceSettingsFromRealtime(deviceId: 2, category: 'pos', kioskMode: false);
      expect(auth.kioskModeActive, isTrue, reason: 'the switch in flight decides, not its echo');

      repo.exit.complete(_exitOk);
      expect((await pending).ok, isTrue);
      expect(auth.kioskModeActive, isFalse);
    });

    test('a push with no switch in flight still applies', () async {
      await boot(kioskMode: true);
      build(_HeldRepo());

      await auth.applyDeviceSettingsFromRealtime(deviceId: 2, category: 'pos', kioskMode: false);

      expect(auth.kioskModeActive, isFalse);
    });
  });

  group('the curtain', () {
    test('covers a successful switch until the screen has landed', () async {
      await boot(kioskMode: true);
      final repo = _HeldRepo()..exit.complete(_exitOk);
      final t = build(repo);

      await t.modes.switchToPos('4321');
      expect(t.modes.curtain, isTrue);
      expect(t.modes.curtainTarget, DeviceModeTarget.pos);

      t.modes.landed();
      await Future<void>.delayed(Duration.zero);

      expect(t.modes.curtain, isFalse);
    });

    test('a refused PIN never raises it', () async {
      await boot(kioskMode: true);
      final repo = _HeldRepo()
        ..exit.complete(const DeviceModeResponse(422, {
          'errors': [
            {'code': 'incorrect-pin', 'message': 'no', 'attempts_remaining': 4}
          ]
        }));
      final t = build(repo);

      await t.modes.switchToPos('0000');

      expect(t.modes.curtain, isFalse);
    });

    test('into kiosk: the kiosk is shown before the till is torn down, then it lifts', () async {
      await boot();
      final t = build(_HeldRepo());
      t.staff.debugSignIn(const PosStaffSession(
          id: 'sara', staffId: 7, name: 'Sara', initials: 'S', role: 'Employee', permissions: {}));
      bool? signedInWhenShown;

      await t.modes.switchToKiosk(show: () async {
        expect(t.modes.curtain, isTrue);
        signedInWhenShown = t.staff.isSignedIn;
      });
      await Future<void>.delayed(Duration.zero);

      expect(signedInWhenShown, isTrue, reason: 'the POS never sits on screen signed out');
      expect(t.staff.isSignedIn, isFalse);
      expect(t.modes.curtain, isFalse);
    });
  });

  group('a switch made elsewhere', () {
    test('into kiosk: move to the welcome screen, then tear down', () async {
      await boot();
      final t = build(_HeldRepo());
      t.staff.debugSignIn(const PosStaffSession(
          id: 'sara', staffId: 7, name: 'Sara', initials: 'S', role: 'Employee', permissions: {}));
      await auth.applyDeviceSettingsFromRealtime(deviceId: 2, category: 'pos', kioskMode: true);

      await t.modes.afterRemoteSwitch();

      expect(t.went, [RouterHelper.kioskWelcomeScreen]);
      expect(t.staff.isSignedIn, isFalse);
    });

    test('back to POS: read the roster, then move to the till', () async {
      await boot(kioskMode: true);
      final t = build(_HeldRepo());
      await auth.applyDeviceSettingsFromRealtime(deviceId: 2, category: 'pos', kioskMode: false);

      await t.modes.afterRemoteSwitch();

      expect(t.roster.calls, 1);
      expect(t.went, [PosRoutes.home]);
    });
  });

  group('DeviceModeCurtain', () {
    Future<DeviceModeProvider> pumpCurtain(WidgetTester tester) async {
      await boot(kioskMode: true);
      final t = build(_HeldRepo()..exit.complete(_exitOk));
      await tester.pumpWidget(ChangeNotifierProvider<DeviceModeProvider>.value(
        value: t.modes,
        child: const MaterialApp(home: DeviceModeCurtain(child: Text('screen'))),
      ));
      return t.modes;
    }

    testWidgets('down: the screen shows', (tester) async {
      await pumpCurtain(tester);

      expect(find.text('screen'), findsOneWidget);
      expect(find.byKey(DeviceModeCurtain.faceKey), findsNothing);
    });

    testWidgets('up: the half-switched screen is never painted', (tester) async {
      final modes = await pumpCurtain(tester);

      await tester.runAsync(() => modes.switchToPos('4321'));
      await tester.pump();

      expect(find.text('screen'), findsNothing, reason: 'offstage under the curtain');
      expect(find.byKey(DeviceModeCurtain.faceKey), findsOneWidget);
      expect(find.text('Switching to POS'), findsOneWidget);

      modes.landed();
      await tester.pumpAndSettle();

      expect(find.text('screen'), findsOneWidget);
      expect(find.byKey(DeviceModeCurtain.faceKey), findsNothing);
    });
  });
}
