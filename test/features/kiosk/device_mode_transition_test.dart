import 'dart:async';

import 'package:acafe_customer/common/responsive/app_chrome.dart';
import 'package:acafe_customer/common/responsive/app_frame.dart';
import 'package:acafe_customer/common/responsive/kiosk_responsive.dart';
import 'package:acafe_customer/features/pos/domain/pos_responsive.dart';
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
import 'package:acafe_customer/features/pos/domain/pos_staff_session.dart';
import 'package:acafe_customer/features/pos/domain/pos_staff_session_repo.dart';
import 'package:acafe_customer/features/pos/providers/pos_session_provider.dart';
import 'package:acafe_customer/features/pos/providers/pos_staff_session_provider.dart';
import 'package:acafe_customer/features/pos/widgets/pos_staff_gate.dart';
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_html/html.dart' as html;

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

/// The exit PIN is validated by a normal staff sign-in now. Configurable so a
/// test can make it succeed (with the permission) or refuse.
const PosStaffSession _sara = PosStaffSession(
  id: 'sara',
  staffId: 7,
  name: 'Sara',
  initials: 'S',
  role: 'Employee',
  permissions: {'switch_device_mode': true},
);

class _Roster extends PosStaffSessionRepo {
  _Roster() : super(dioClient: null);

  int calls = 0;

  (PosStaffSession?, String?, DateTime?, PosSignInResult) Function(String)
      onSignIn = (pin) => (
            _sara,
            'staff-token',
            DateTime.parse('2030-01-01T00:00:00Z'),
            const PosSignInResult(PosSignInOutcome.signedIn),
          );

  @override
  Future<PosSignInRoster?> signInRoster() async {
    calls++;
    return const PosSignInRoster(staffLoginRequired: true, pinLength: 4, lockoutSeconds: 0, members: []);
  }

  @override
  Future<(PosStaffSession?, String?, DateTime?, PosSignInResult)> signIn(
    String pin, {
    String? memberId,
    int? roleId,
  }) async =>
      onSignIn(pin);
}

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
    });
    // The session flag lives in sessionStorage, which leaks across VM tests;
    // reset it per boot and seed it only for a simulated kiosk session.
    if (kioskMode) {
      html.window.sessionStorage[AppConstants.kioskDeviceKioskMode] = 'true';
    } else {
      html.window.sessionStorage.remove(AppConstants.kioskDeviceKioskMode);
    }
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
    testWidgets('switching modes neither rebuilds nor re-parses the router', (tester) async {
      // The app hands AppChrome a Router. Rebuilt -- or even moved -- it
      // re-parses the address, which mid-switch GoRouter cannot do (the
      // RangeError in canonicalUri seen live). It must stay exactly where it is.
      await boot(kioskMode: true);
      int parses = 0;
      final GoRouter router = GoRouter(
        routes: [GoRoute(path: '/', builder: (_, __) => const _Probe())],
        redirect: (_, __) {
          parses++;
          return null;
        },
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(ChangeNotifierProvider<KioskAuthProvider>.value(
        value: auth,
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => AppChrome(child: child),
        ),
      ));
      final State before = tester.state(find.byWidgetPredicate((w) => w is Router));
      final int parsesBefore = parses;

      await auth.applyKioskMode(false);
      await tester.pump();
      await auth.applyKioskMode(true);
      await tester.pump();

      expect(tester.state(find.byWidgetPredicate((w) => w is Router)), same(before));
      expect(parses, parsesBefore, reason: 'a mode switch must not make the router parse again');
    });

    testWidgets('the frame never moves the screen: kiosk, full-bleed kiosk, POS', (tester) async {
      _Probe.created = 0;
      Widget frame({required bool pos, bool fullBleed = false}) => MaterialApp(
            home: AppFrame(pos: pos, fullBleed: fullBleed, child: const _Probe()),
          );

      await tester.pumpWidget(frame(pos: false, fullBleed: true));
      await tester.pumpWidget(frame(pos: false));
      await tester.pumpWidget(frame(pos: true));
      await tester.pumpWidget(frame(pos: false, fullBleed: true));

      expect(_Probe.created, 1);
    });

    testWidgets('each mode sees only its own measurements', (tester) async {
      late BuildContext inner;
      Widget frame(bool pos) => MaterialApp(
            home: AppFrame(pos: pos, child: Builder(builder: (c) {
              inner = c;
              return const SizedBox();
            })),
          );

      await tester.pumpWidget(frame(true));
      expect(PosMetrics.maybeOf(inner), isNotNull);
      expect(KioskMetrics.maybeOf(inner), isNull, reason: 'POS layouts must keep their window fallbacks');

      await tester.pumpWidget(frame(false));
      expect(KioskMetrics.maybeOf(inner), isNotNull);
      expect(PosMetrics.maybeOf(inner), isNull);
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

  group('returning to POS renders the till (no blank screen)', () {
    // Mirrors AppChrome's shape: curtain > frame > gate > the routed child,
    // with `pos` driven off the live KioskAuthProvider exactly as PosMode does.
    Widget chrome(PosStaffSessionProvider staff, DeviceModeProvider modes) =>
        MultiProvider(
          providers: [
            ChangeNotifierProvider<KioskAuthProvider>.value(value: auth),
            ChangeNotifierProvider<PosStaffSessionProvider>.value(value: staff),
            ChangeNotifierProvider<DeviceModeProvider>.value(value: modes),
          ],
          child: MaterialApp(
            home: Builder(builder: (context) {
              final bool pos = context.watch<KioskAuthProvider>().isPosDevice;
              return DeviceModeCurtain(
                child: AppFrame(
                  pos: pos,
                  child: PosStaffGate(
                    enabled: pos,
                    child: Text(pos ? 'POS HOME' : 'KIOSK'),
                  ),
                ),
              );
            }),
          ),
        );

    testWidgets(
        'a till reloaded in kiosk mode shows the POS after the exit PIN, not a blank cover',
        (tester) async {
      // A kiosk session reloaded while in kiosk mode: the gate was disabled, so
      // the staff provider never bootstrapped -- exactly the state that used to
      // leave PosStaffGate holding its blank beige cover after the triple-tap.
      await boot(kioskMode: true);
      final t = build(_HeldRepo());
      expect(t.staff.bootstrapped, isFalse, reason: 'precondition: reloaded-kiosk');

      await tester.pumpWidget(chrome(t.staff, t.modes));
      expect(find.text('KIOSK'), findsOneWidget);

      // Triple-tap exit: a valid staff PIN brings the till back to POS.
      await tester.runAsync(() => t.modes.switchToPos('4321'));
      t.modes.landed();
      await tester.pumpAndSettle();

      // The till is on screen...
      expect(auth.isPosDevice, isTrue);
      expect(t.staff.bootstrapped, isTrue,
          reason: 'the gate must be ready or it holds its blank cover');
      expect(find.text('POS HOME'), findsOneWidget);

      // ...actually painted, not left offstage under the gate's blank cover...
      final Offstage gateOffstage = tester.widget<Offstage>(
        find
            .ancestor(
                of: find.text('POS HOME'), matching: find.byType(Offstage))
            .first,
      );
      expect(gateOffstage.offstage, isFalse,
          reason: 'the POS content must be on stage, not hidden behind a cover');

      // ...and the switch curtain has come down.
      expect(find.byKey(DeviceModeCurtain.faceKey), findsNothing);
    });

    // Repeated switching is a state-machine concern (Scenario C): the gate must
    // stay bootstrapped and the effective mode must track each switch. Asserted
    // at the provider level so the result is deterministic and free of the
    // curtain's spinner animation.
    test('switching kiosk <-> POS repeatedly keeps the mode and gate consistent',
        () async {
      await boot();
      final t = build(_HeldRepo());
      await t.staff.bootstrap(); // a fresh POS boot bootstraps the gate
      expect(auth.isPosDevice, isTrue);
      expect(t.staff.bootstrapped, isTrue);

      for (int i = 0; i < 3; i++) {
        await t.modes.switchToKiosk();
        expect(auth.kioskModeActive, isTrue, reason: 'round $i to kiosk');
        expect(auth.isPosDevice, isFalse, reason: 'round $i to kiosk');
        expect(t.staff.isSignedIn, isFalse,
            reason: 'round $i: the till is torn down for the customer');

        await t.modes.switchToPos('4321');
        expect(auth.isPosDevice, isTrue, reason: 'round $i to POS');
        expect(auth.kioskModeActive, isFalse, reason: 'round $i to POS');
        expect(t.staff.bootstrapped, isTrue,
            reason: 'round $i: the gate must stay ready, never a blank cover');
        expect(t.staff.isSignedIn, isTrue,
            reason: 'round $i: the member who entered the PIN is signed in');
      }
    });
  });

  group('a broadcast never moves this session', () {
    test('a kiosk_mode push does not flip the running screen', () async {
      await boot();
      build(_HeldRepo());
      await auth.applyKioskMode(true); // this screen switched itself, locally

      // Another session (or the server echo) broadcasts a mode change.
      await auth.applyDeviceSettingsFromRealtime(
          deviceId: 2, category: 'pos', kioskMode: false);

      expect(auth.kioskModeActive, isTrue,
          reason: 'only this screen decides its own mode');
    });

    test('a non-mode device setting still applies from a broadcast', () async {
      await boot();
      build(_HeldRepo());

      await auth.applyDeviceSettingsFromRealtime(
          deviceId: 2, category: 'pos', name: 'Renamed', kioskMode: false);

      expect(auth.deviceName, 'Renamed');
      expect(auth.isPosDevice, isTrue);
    });
  });

  group('the curtain', () {
    test('covers a successful switch until the screen has landed', () async {
      await boot();
      final t = build(_HeldRepo());
      await auth.applyKioskMode(true);

      await t.modes.switchToPos('4321');
      expect(t.modes.curtain, isTrue);
      expect(t.modes.curtainTarget, DeviceModeTarget.pos);

      t.modes.landed();
      await Future<void>.delayed(Duration.zero);

      expect(t.modes.curtain, isFalse);
    });

    test('a refused PIN never raises it', () async {
      await boot();
      final t = build(_HeldRepo());
      await auth.applyKioskMode(true);
      t.roster.onSignIn = (pin) => (
            null,
            null,
            null,
            const PosSignInResult(PosSignInOutcome.wrongPin,
                attemptsRemaining: 4),
          );

      await t.modes.switchToPos('0000');

      expect(t.modes.curtain, isFalse);
      expect(auth.kioskModeActive, isTrue);
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

  group('DeviceModeCurtain', () {
    Future<DeviceModeProvider> pumpCurtain(WidgetTester tester) async {
      await boot();
      final t = build(_HeldRepo());
      await auth.applyKioskMode(true);
      await tester.pumpWidget(ChangeNotifierProvider<DeviceModeProvider>.value(
        value: t.modes,
        child: const MaterialApp(home: DeviceModeCurtain(child: Text('screen'))),
      ));
      return t.modes;
    }

    testWidgets('its label has a real text style above the navigator', (tester) async {
      // In the app the curtain sits in MaterialApp's builder, above the
      // navigator and its Material -- no DefaultTextStyle, so Text falls back
      // to the debug style (yellow double underline) unless the face brings one.
      await boot();
      final t = build(_HeldRepo());
      await auth.applyKioskMode(true);
      await tester.pumpWidget(ChangeNotifierProvider<DeviceModeProvider>.value(
        value: t.modes,
        child: MaterialApp(
          builder: (context, child) => DeviceModeCurtain(child: child!),
          home: const SizedBox(),
        ),
      ));
      await tester.runAsync(() => t.modes.switchToPos('4321'));
      await tester.pump();

      final TextStyle style = DefaultTextStyle.of(tester.element(find.text('Switching to POS'))).style;
      expect(style.decoration, isNot(TextDecoration.underline));
      t.modes.landed();
      await tester.pumpAndSettle();
    });

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
