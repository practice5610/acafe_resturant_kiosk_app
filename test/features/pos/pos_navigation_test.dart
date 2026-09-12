import 'package:acafe_customer/common/responsive/kiosk_shell.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:acafe_customer/features/cart/domain/reposotories/cart_repo.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/category/providers/category_provider.dart';
import 'package:acafe_customer/features/coupon/providers/coupon_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_auth_repo.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_manager_repo.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_manager_provider.dart';
import 'package:acafe_customer/features/language/providers/localization_provider.dart';
import 'package:acafe_customer/di_container.dart' as di;
import 'package:acafe_customer/features/pos/domain/pos_mode.dart';
import 'package:acafe_customer/features/pos/domain/pos_orders_repo.dart';
import 'package:acafe_customer/features/pos/domain/pos_responsive.dart';
import 'package:acafe_customer/features/pos/domain/pos_routes.dart';
import 'package:acafe_customer/features/pos/pos_router.dart';
import 'package:acafe_customer/features/pos/pos_shell.dart';
import 'package:acafe_customer/features/pos/providers/pos_session_provider.dart';
import 'package:acafe_customer/features/pos/widgets/pos_top_nav_bar.dart';
import 'package:acafe_customer/features/splash/domain/reposotories/splash_repo.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/kiosk_layout_harness.dart';

/// Drives the *real* GoRouter — the same `RouterHelper.goRoutes` the app runs —
/// so this exercises the route splice, the guard branch and the shell swap
/// together rather than any of them in isolation.

/// Session provider whose manager step-up can be granted directly.
/// Authenticating for real would need a network round trip; the gate's
/// effect on routing is the thing under test.
class _UnlockedSessionProvider extends PosSessionProvider {
  _UnlockedSessionProvider(KioskManagerRepo repo)
      : super(kioskManagerRepo: repo);

  void unlock() => debugSetElevated(true);
}

Future<
    ({
      KioskAuthProvider auth,
      KioskManagerProvider manager,
      _UnlockedSessionProvider session,
      SharedPreferences prefs,
      DioClient dio,
    })> _providers({
  required String category,
  bool loggedIn = true,
}) async {
  SharedPreferences.setMockInitialValues({
    if (loggedIn) AppConstants.token: 'device-token',
    AppConstants.branch: 1,
    AppConstants.kioskDeviceCategory: category,
    AppConstants.kioskBranchName: 'Main Branch',
    AppConstants.kioskDeviceName: 'Till 1',
  });
  final prefs = await SharedPreferences.getInstance();
  final dio = DioClient(
    AppConstants.baseUrl,
    null,
    loggingInterceptor: LoggingInterceptor(),
    sharedPreferences: prefs,
  );

  // Tabs that build their own screen-scoped provider resolve its repo from the
  // service locator, exactly as they do under di.init() in the real app. This
  // harness builds the POS tree by hand, so the few singletons those screens
  // reach for have to be registered here too.
  if (di.sl.isRegistered<PosOrdersRepo>()) {
    await di.sl.unregister<PosOrdersRepo>();
  }
  di.sl.registerLazySingleton(() => PosOrdersRepo(dioClient: dio));

  // Settings' General tab falls back to the locator for prefs the same way.
  if (di.sl.isRegistered<SharedPreferences>()) {
    await di.sl.unregister<SharedPreferences>();
  }
  di.sl.registerLazySingleton<SharedPreferences>(() => prefs);

  return (
    auth: KioskAuthProvider(
        kioskAuthRepo: KioskAuthRepo(dioClient: dio, sharedPreferences: prefs)),
    manager: KioskManagerProvider(
        kioskManagerRepo: KioskManagerRepo(dioClient: dio, sharedPreferences: prefs)),
    session: _UnlockedSessionProvider(
        KioskManagerRepo(dioClient: dio, sharedPreferences: prefs)),
    prefs: prefs,
    dio: dio,
  );
}

/// Mirrors `MyApp.build` — same router, same shell decision.
Widget _app({
  required KioskAuthProvider auth,
  required KioskManagerProvider manager,
  required PosSessionProvider session,
  required SharedPreferences prefs,
  required DioClient dio,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<KioskAuthProvider>.value(value: auth),
      ChangeNotifierProvider<KioskManagerProvider>.value(value: manager),
      ChangeNotifierProvider<PosSessionProvider>.value(value: session),
      ChangeNotifierProvider<SplashProvider>(
        create: (_) => KioskStubSplashProvider(
          splashRepo: SplashRepo(dioClient: dio, sharedPreferences: prefs),
        ),
      ),
      ChangeNotifierProvider<CartProvider>(
        create: (_) =>
            CartProvider(cartRepo: CartRepo(sharedPreferences: prefs)),
      ),
      ChangeNotifierProvider<CouponProvider>(
        create: (_) => CouponProvider(couponRepo: null),
      ),
      ChangeNotifierProvider<CategoryProvider>(
        create: (_) => CategoryProvider(categoryRepo: null),
      ),
      ChangeNotifierProvider<LocalizationProvider>(
        create: (_) => LocalizationProvider(
          sharedPreferences: prefs,
          dioClient: dio,
        ),
      ),
    ],
    child: MaterialApp.router(
      routerConfig: RouterHelper.goRoutes,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        final content = child ?? const SizedBox.shrink();
        if (PosMode.of(context).isPos) return PosShell(child: content);
        return KioskShell(child: content);
      },
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The router is an app-wide singleton, so location leaks between tests
  // unless each one starts from a known place.
  tearDown(() => RouterHelper.goRoutes.go(RouterHelper.kioskLoginScreen));

  // GetIt is process-global and outlives this file. Leaving these registered
  // hands the next test file in the shard a SharedPreferences and a DioClient
  // built for *this* harness — which is how an unrelated suite starts failing
  // only when run together with this one.
  tearDown(() async {
    if (di.sl.isRegistered<PosOrdersRepo>()) {
      await di.sl.unregister<PosOrdersRepo>();
    }
    if (di.sl.isRegistered<SharedPreferences>()) {
      await di.sl.unregister<SharedPreferences>();
    }
  });

  testWidgets('a POS device boots straight into the shell, not the kiosk',
      (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final p = await _providers(category: 'pos');
    await tester.pumpWidget(_app(
        auth: p.auth,
        manager: p.manager,
        session: p.session,
        prefs: p.prefs,
        dio: p.dio));
    await tester.pumpAndSettle();

    // No PIN gate: the counter (POS/Orders/Receipts) needs no one to sign in.
    expect(find.byType(PosShell), findsOneWidget);
    expect(find.byType(KioskShell), findsNothing);
    expect(find.byType(PosTopNavBar), findsOneWidget);
  });

  testWidgets('a stepped-up terminal reaches every tab', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final p = await _providers(category: 'pos');
    await tester.pumpWidget(_app(
        auth: p.auth,
        manager: p.manager,
        session: p.session,
        prefs: p.prefs,
        dio: p.dio));
    await tester.pumpAndSettle();

    p.session.unlock();
    RouterHelper.goRoutes.go(PosRoutes.home);
    await tester.pumpAndSettle();

    expect(find.byType(PosTopNavBar), findsOneWidget);

    // Walk the nav bar the way staff would.
    for (final item in kPosNavItems) {
      await tester.tap(find.text(item.label));
      await tester.pumpAndSettle();
      expect(RouterHelper.goRoutes.routeInformationProvider.value.uri.path,
          item.path,
          reason: 'tapping ${item.label} should route to ${item.path}');
      expect(find.byType(PosTopNavBar), findsOneWidget,
          reason: 'chrome should persist across tab switches');
    }
  });

  testWidgets('payment screens are full-screen, outside the shell',
      (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final p = await _providers(category: 'pos');
    await tester.pumpWidget(_app(
        auth: p.auth,
        manager: p.manager,
        session: p.session,
        prefs: p.prefs,
        dio: p.dio));
    p.session.unlock();
    await tester.pumpAndSettle();

    for (final path in [
      PosRoutes.payment,
      PosRoutes.paymentCash,
      PosRoutes.paymentWait,
      PosRoutes.paymentSuccess,
    ]) {
      RouterHelper.goRoutes.go(path);
      await tester.pumpAndSettle();
      // The invariant is the *shell*, not the bar: payment routes sit outside
      // the ShellRoute so the chrome is never shared with the tab tree.
      expect(find.byType(PosScaffold), findsNothing,
          reason: '$path must be routed outside the POS shell');
    }

    // The payment-selection frame (Figma 1641:2757) draws the nav bar itself.
    // It is mounted by the screen, not inherited, and PosTopNavBar.interactive
    // is what stops tab switching while a charge is actually in flight.
    RouterHelper.goRoutes.go(PosRoutes.payment);
    await tester.pumpAndSettle();
    expect(find.byType(PosTopNavBar), findsOneWidget);

    // The remaining payment steps have no Figma chrome and mount none.
    for (final path in [
      PosRoutes.paymentCash,
      PosRoutes.paymentWait,
      PosRoutes.paymentSuccess,
    ]) {
      RouterHelper.goRoutes.go(path);
      await tester.pumpAndSettle();
      expect(find.byType(PosTopNavBar), findsNothing, reason: path);
    }
  });

  // The kiosk-device cases below deliberately do NOT mount the real kiosk
  // screens. Those pull in the full provider graph and start their own timers
  // (KioskIntroImage), which says nothing about this change. What matters — and
  // what is asserted here — is the shell decision. The routing half is covered
  // exhaustively by pos_route_policy_test.dart.
  Widget shellHarness({
    required KioskAuthProvider auth,
    required KioskManagerProvider manager,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<KioskAuthProvider>.value(value: auth),
        ChangeNotifierProvider<KioskManagerProvider>.value(value: manager),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Builder(
          builder: (context) {
            const content = SizedBox.shrink();
            if (PosMode.of(context).isPos) {
              return const PosShell(child: content);
            }
            return const KioskShell(child: content);
          },
        ),
      ),
    );
  }

  testWidgets('a kiosk device gets the kiosk shell, never the POS one',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final p = await _providers(category: 'kiosk');
    await tester.pumpWidget(shellHarness(auth: p.auth, manager: p.manager));
    await tester.pumpAndSettle();

    expect(find.byType(KioskShell), findsOneWidget);
    expect(find.byType(PosShell), findsNothing);
  });

  testWidgets('a kiosk device in landscape still gets the kiosk shell',
      (tester) async {
    // The regression this guards: keying the interface off orientation would
    // hand a landscape kiosk the POS UI and orphan the kiosk's own tested
    // landscape compositions.
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final p = await _providers(category: 'kiosk');
    await tester.pumpWidget(shellHarness(auth: p.auth, manager: p.manager));
    await tester.pumpAndSettle();

    expect(find.byType(KioskShell), findsOneWidget);
    expect(find.byType(PosShell), findsNothing);
  });

  testWidgets('a POS device in portrait still gets the POS shell',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final p = await _providers(category: 'pos');
    await tester.pumpWidget(shellHarness(auth: p.auth, manager: p.manager));
    await tester.pumpAndSettle();

    expect(find.byType(PosShell), findsOneWidget);
    expect(find.byType(KioskShell), findsNothing);
  });

  testWidgets('POS lays out against the real window, uncapped',
      (tester) async {
    // The kiosk shell would cap this at its 2572 artboard and rewrite
    // MediaQuery.size to match. POS must see the window it actually has.
    tester.view.physicalSize = const Size(3000, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final p = await _providers(category: 'pos');
    await tester.pumpWidget(_app(
        auth: p.auth,
        manager: p.manager,
        session: p.session,
        prefs: p.prefs,
        dio: p.dio));
    p.session.unlock();
    RouterHelper.goRoutes.go(PosRoutes.home);
    await tester.pumpAndSettle();

    final metrics = PosMetrics.of(
        tester.element(find.byType(PosTopNavBar)));
    expect(metrics.window.width, 3000);
    expect(metrics.showsSideReceipt, isTrue);
  });
}
