import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:acafe_customer/features/pos/domain/pos_route_policy.dart';
import 'package:acafe_customer/features/pos/domain/pos_routes.dart';
import 'package:acafe_customer/features/pos/domain/pos_staff_session.dart';
import 'package:acafe_customer/features/pos/domain/pos_staff_session_repo.dart';
import 'package:acafe_customer/features/pos/providers/pos_staff_session_provider.dart';
import 'package:acafe_customer/features/pos/widgets/pos_top_nav_bar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_pos_staff_backend.dart';

const PosStaffSession _cashier = PosStaffSession(
  id: 'sara',
  staffId: 7,
  name: 'Sara de Vries',
  initials: 'SV',
  role: 'Cashier',
  permissions: {'apply_discounts': true, 'view_orders': true},
);

late FakePosStaffBackend backend;
late DioClient client;

Future<PosStaffSessionProvider> _session({
  bool loginRequired = true,
  Duration idle = PosStaffSessionProvider.defaultIdleTimeout,
  PosStaffTokenStore? store,
}) async {
  backend = FakePosStaffBackend(staffLoginRequired: loginRequired);
  backend.setPin('sophie', '1234');
  backend.setPin('thomas', '4321');
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final Dio dio = Dio(BaseOptions(baseUrl: 'http://localhost'))
    ..httpClientAdapter = backend;
  client = DioClient('http://localhost', dio,
      loggingInterceptor: LoggingInterceptor(), sharedPreferences: prefs);
  return PosStaffSessionProvider(
    repo: PosStaffSessionRepo(dioClient: client),
    tokenStore: store ?? MemoryPosStaffTokenStore(),
    idleTimeout: idle,
    dioClient: client,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PosAccess — switch off is today, exactly', () {
    test('every action is allowed and tabs follow the manager step-up', () {
      const off = PosAccess(loginRequired: false, managerStepUp: false);
      expect(off.can('close_day'), isTrue);
      expect(off.can('void_orders'), isTrue);
      expect(off.canSeeReport, isFalse);
      expect(off.canSeeSettings, isFalse);
      expect(off.mustSignIn, isFalse);

      const stepped = PosAccess(loginRequired: false, managerStepUp: true);
      expect(stepped.canSeeReport, isTrue);
      expect(stepped.canSeeSettings, isTrue);
    });

    test('nav items match the old filter exactly', () {
      for (final bool stepUp in [false, true]) {
        final items = visiblePosNavItemsFor(
          PosAccess(loginRequired: false, managerStepUp: stepUp),
        );
        expect(items.map((i) => i.path), visiblePosNavItems(stepUp).map((i) => i.path));
      }
    });
  });

  group('PosAccess — switch on', () {
    test('nobody signed in means the PIN screen, and nothing is allowed', () {
      const on = PosAccess(loginRequired: true, managerStepUp: true);
      expect(on.mustSignIn, isTrue);
      expect(on.can('apply_discounts'), isFalse);
      // The device step-up plays no part once staff sign-in is on.
      expect(on.canSeeReport, isFalse);
      expect(on.canSeeSettings, isFalse);
    });

    test('a cashier sees only what their permissions allow', () {
      const on = PosAccess(loginRequired: true, managerStepUp: false, session: _cashier);
      expect(on.mustSignIn, isFalse);
      expect(on.can('apply_discounts'), isTrue);
      expect(on.can('close_day'), isFalse);
      expect(on.canSeeReport, isFalse);
      expect(on.canSeeSettings, isFalse);
      expect(visiblePosNavItemsFor(on).map((i) => i.path),
          [PosRoutes.home, PosRoutes.orders, PosRoutes.receipts]);
    });

    test('each manager tab follows its own permission', () {
      const reportsOnly = PosAccess(
        loginRequired: true,
        managerStepUp: false,
        session: PosStaffSession(
          id: 'x', staffId: 1, name: 'X', initials: 'X', role: 'R',
          permissions: {'access_reports': true},
        ),
      );
      expect(reportsOnly.canSeeReport, isTrue);
      expect(reportsOnly.canSeeSettings, isFalse);
      expect(visiblePosNavItemsFor(reportsOnly).map((i) => i.path),
          contains(PosRoutes.report));
      expect(visiblePosNavItemsFor(reportsOnly).map((i) => i.path),
          isNot(contains(PosRoutes.settings)));
    });
  });

  group('route policy', () {
    String? go(String path, {bool? report, bool? settings, bool stepUp = false}) =>
        PosRoutePolicy.redirect(
          path: path,
          isPosDevice: true,
          isLoggedIn: true,
          kioskLoginPath: '/login',
          kioskWelcomePath: '/welcome',
          canAccessManagerTabs: stepUp,
          canAccessReport: report,
          canAccessSettings: settings,
        );

    test('without per-tab answers it behaves as before', () {
      expect(go(PosRoutes.report), PosRoutes.home);
      expect(go(PosRoutes.report, stepUp: true), isNull);
    });

    test('a typed URL cannot reach a tab the person lacks', () {
      expect(go(PosRoutes.report, report: true, settings: false), isNull);
      expect(go(PosRoutes.settings, report: true, settings: false), PosRoutes.home);
    });
  });

  group('PosStaffSessionProvider', () {
    test('with the switch off nothing is required and no token is sent', () async {
      final session = await _session(loginRequired: false);
      await session.bootstrap();

      expect(session.loginRequired, isFalse);
      expect(session.access(managerStepUp: false).mustSignIn, isFalse);

      backend.requests.clear();
      await client.get('/api/v1/anything', options: Options(validateStatus: (_) => true));
      expect(backend.requests.single.headers.containsKey('X-Staff-Token'), isFalse);
    });

    test('with the switch on, only people with a PIN appear as faces', () async {
      final session = await _session();
      await session.bootstrap();

      expect(session.loginRequired, isTrue);
      expect(session.members.map((m) => m.id), unorderedEquals(['sophie', 'thomas']));
      expect(session.members.firstWhere((m) => m.id == 'sophie').initials, 'SJ');
    });

    test('a right PIN signs in and every request then carries the token', () async {
      final session = await _session();
      await session.bootstrap();

      final result = await session.signIn('1234', memberId: 'sophie');

      expect(result.ok, isTrue);
      expect(session.session!.name, 'Sophie Jansen');
      expect(session.token, isNotNull);

      backend.requests.clear();
      await client.get('/api/v1/kiosk/manager/orders',
          options: Options(validateStatus: (_) => true));
      expect(backend.requests.single.headers['X-Staff-Token'], session.token);
    });

    test('someone else\'s PIN under a face is a wrong PIN', () async {
      final session = await _session();
      await session.bootstrap();

      final result = await session.signIn('4321', memberId: 'sophie');

      expect(result.outcome, PosSignInOutcome.wrongPin);
      expect(result.attemptsRemaining, 4);
      expect(session.isSignedIn, isFalse);
    });

    test('PIN-only mode signs in whoever the PIN belongs to', () async {
      final session = await _session();
      await session.bootstrap();

      expect((await session.signIn('4321')).ok, isTrue);
      expect(session.session!.name, 'Thomas de Vries');
    });

    test('five wrong PINs lock the till out, with a countdown', () async {
      final session = await _session();
      await session.bootstrap();

      PosSignInResult last = const PosSignInResult(PosSignInOutcome.wrongPin);
      for (int i = 0; i < 5; i++) {
        last = await session.signIn('0000');
      }
      expect(last.outcome, PosSignInOutcome.lockedOut);
      expect(session.isLockedOut, isTrue);
      expect(session.lockoutSecondsLeft, 300);

      // A right PIN during the lockout is refused without a round trip.
      backend.requests.clear();
      expect((await session.signIn('1234')).outcome, PosSignInOutcome.lockedOut);
      expect(backend.requests, isEmpty);
      session.dispose();
    });

    test('lock clears the session and the token, memory and storage', () async {
      final store = MemoryPosStaffTokenStore();
      final session = await _session(store: store);
      await session.bootstrap();
      await session.signIn('1234', memberId: 'sophie');
      expect(await store.read(), isNotNull);

      await session.lock();

      expect(session.isSignedIn, isFalse);
      expect(session.token, isNull);
      expect(await store.read(), isNull);
    });

    test('a stored token survives a reload if the server still honours it', () async {
      final store = MemoryPosStaffTokenStore();
      final first = await _session(store: store);
      await first.bootstrap();
      await first.signIn('1234', memberId: 'sophie');

      // Same backend, a fresh provider -- as after a page reload.
      final Dio dio = Dio(BaseOptions(baseUrl: 'http://localhost'))
        ..httpClientAdapter = backend;
      final prefs = await SharedPreferences.getInstance();
      final reloaded = PosStaffSessionProvider(
        repo: PosStaffSessionRepo(
          dioClient: DioClient('http://localhost', dio,
              loggingInterceptor: LoggingInterceptor(), sharedPreferences: prefs),
        ),
        tokenStore: store,
      );
      await reloaded.bootstrap();

      expect(reloaded.session?.name, 'Sophie Jansen');
    });

    test('a stored token for someone since deactivated is dropped', () async {
      final store = MemoryPosStaffTokenStore();
      final first = await _session(store: store);
      await first.bootstrap();
      await first.signIn('1234', memberId: 'sophie');
      backend.deactivate('sophie');

      final Dio dio = Dio(BaseOptions(baseUrl: 'http://localhost'))
        ..httpClientAdapter = backend;
      final prefs = await SharedPreferences.getInstance();
      final reloaded = PosStaffSessionProvider(
        repo: PosStaffSessionRepo(
          dioClient: DioClient('http://localhost', dio,
              loggingInterceptor: LoggingInterceptor(), sharedPreferences: prefs),
        ),
        tokenStore: store,
      );
      await reloaded.bootstrap();

      expect(reloaded.isSignedIn, isFalse);
      expect(await store.read(), isNull);
    });

    test('a request answered "no staff session" locks the till', () async {
      final session = await _session();
      await session.bootstrap();
      await session.signIn('1234', memberId: 'sophie');
      backend.deactivate('sophie');

      // Any call the server rejects this way -- here, /me.
      await client.get('/api/v1/kiosk/manager/staff/me',
          options: Options(validateStatus: (_) => true));
      await pumpEventQueue();

      expect(session.isSignedIn, isFalse);
    });

    test('the till locks itself after the idle timeout', () async {
      // Real timers, scaled down: the behaviour is the ratio, not the minutes.
      final session = await _session(idle: const Duration(milliseconds: 200));
      await session.bootstrap();
      await session.signIn('1234', memberId: 'sophie');
      expect(session.isSignedIn, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 130));
      session.touch(); // somebody used the till
      await Future<void>.delayed(const Duration(milliseconds: 130));
      expect(session.isSignedIn, isTrue, reason: 'a touch resets the clock');

      await Future<void>.delayed(const Duration(milliseconds: 260));
      await pumpEventQueue();
      expect(session.isSignedIn, isFalse, reason: 'untouched past the timeout, it locks');
    });

    test('the default idle timeout is five minutes', () {
      expect(PosStaffSessionProvider.defaultIdleTimeout, const Duration(minutes: 5));
    });

    test('switching the branch off drops a leftover session', () async {
      final session = await _session();
      await session.bootstrap();
      await session.signIn('1234', memberId: 'sophie');

      backend.staffLoginRequired = false;
      await session.refreshRoster();

      expect(session.loginRequired, isFalse);
      expect(session.isSignedIn, isFalse);
      expect(session.token, isNull);
    });
  });

  group('kiosk', () {
    test('a kiosk device answers 403, which reads as staff sign-in off', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final Dio dio = Dio(BaseOptions(baseUrl: 'http://localhost'))
        ..httpClientAdapter = _KioskRefusal();
      final repo = PosStaffSessionRepo(
        dioClient: DioClient('http://localhost', dio,
            loggingInterceptor: LoggingInterceptor(), sharedPreferences: prefs),
      );

      final roster = await repo.signInRoster();

      expect(roster, isNotNull);
      expect(roster!.staffLoginRequired, isFalse);
      expect(roster.members, isEmpty);
    });
  });
}

class _KioskRefusal extends FakePosStaffBackend {
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream,
      Future<void>? cancelFuture) async {
    return ResponseBody.fromString(
      '{"errors":[{"code":"staff-not-available","message":"Not on a kiosk."}]}',
      403,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}
