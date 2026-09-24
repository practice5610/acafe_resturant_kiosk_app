import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_auth_repo.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_manager_repo.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_logout_button.dart';
import 'package:acafe_customer/features/pos/providers/pos_session_provider.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records whether the manager step-up grant was actually dropped, the same
/// spy the POS nav-bar test uses.
class _SpySessionProvider extends PosSessionProvider {
  _SpySessionProvider(KioskManagerRepo repo) : super(kioskManagerRepo: repo);

  int lockCalls = 0;

  @override
  void lock() {
    lockCalls++;
    super.lock();
  }
}

late KioskAuthProvider auth;
late _SpySessionProvider session;

/// Mounts the button on a stand-in kiosk screen whose whole body navigates on
/// tap. The kiosk screens the button sits on are tap-hungry (a product card,
/// the attract screen), so "the surface underneath must not fire" is the one
/// thing the button has to survive.
Future<void> pumpButton(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({
    AppConstants.token: 'device-token',
    AppConstants.branch: 1,
    AppConstants.kioskDeviceCategory: 'kiosk',
    AppConstants.kioskBranchName: 'Amsterdam',
    AppConstants.kioskDeviceName: 'Kiosk 1',
  });
  final prefs = await SharedPreferences.getInstance();
  final dio = DioClient(
    AppConstants.baseUrl,
    null,
    loggingInterceptor: LoggingInterceptor(),
    sharedPreferences: prefs,
  );
  auth = KioskAuthProvider(
      kioskAuthRepo: KioskAuthRepo(dioClient: dio, sharedPreferences: prefs));
  session = _SpySessionProvider(
      KioskManagerRepo(dioClient: dio, sharedPreferences: prefs));

  final router = GoRouter(
    initialLocation: RouterHelper.kioskWelcomeScreen,
    routes: [
      GoRoute(
        path: RouterHelper.kioskWelcomeScreen,
        builder: (context, state) => Scaffold(
          body: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => context.go(RouterHelper.kioskCartScreen),
            child: const Stack(
              fit: StackFit.expand,
              children: [
                Center(child: Text('KIOSK SCREEN')),
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: KioskLogoutButton(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      GoRoute(
        path: RouterHelper.kioskCartScreen,
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('SOMEWHERE ELSE'))),
      ),
      GoRoute(
        path: RouterHelper.kioskLoginScreen,
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('KIOSK LOGIN SCREEN'))),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<KioskAuthProvider>.value(value: auth),
        ChangeNotifierProvider<PosSessionProvider>.value(value: session),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('tapping the avatar shows a single Logout option -- and does '
      'not trigger the surface underneath', (tester) async {
    await pumpButton(tester);

    await tester.tap(find.byKey(KioskLogoutButton.buttonKey));
    await tester.pumpAndSettle();

    expect(find.text('Logout'), findsOneWidget);
    // The screen's own tap handler must not have fired underneath.
    expect(find.text('SOMEWHERE ELSE'), findsNothing);
    expect(auth.isLoggedIn(), isTrue);
  });

  testWidgets('Logout asks for confirmation before doing anything',
      (tester) async {
    await pumpButton(tester);

    await tester.tap(find.byKey(KioskLogoutButton.buttonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();

    expect(find.text('Log out this device?'), findsOneWidget);
    expect(auth.isLoggedIn(), isTrue);
    expect(session.lockCalls, 0);
  });

  testWidgets('cancelling the confirmation changes nothing', (tester) async {
    await pumpButton(tester);

    await tester.tap(find.byKey(KioskLogoutButton.buttonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(session.lockCalls, 0);
    expect(auth.isLoggedIn(), isTrue);
    expect(find.text('KIOSK SCREEN'), findsOneWidget);
  });

  testWidgets('confirming signs the device out and returns to device login',
      (tester) async {
    await pumpButton(tester);

    await tester.tap(find.byKey(KioskLogoutButton.buttonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log Out'));
    await tester.pumpAndSettle();

    expect(auth.isLoggedIn(), isFalse);
    expect(session.lockCalls, 1);
    expect(find.text('KIOSK LOGIN SCREEN'), findsOneWidget);
  });
}
