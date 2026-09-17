import 'dart:async';

import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:acafe_customer/features/category/providers/category_provider.dart';
import 'package:acafe_customer/features/language/providers/localization_provider.dart';
import 'package:acafe_customer/features/pos/domain/pos_routes.dart';
import 'package:acafe_customer/features/pos/screens/pos_welcome_screen.dart';
import 'package:acafe_customer/features/splash/domain/reposotories/splash_repo.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/kiosk_layout_harness.dart';

/// Holds the menu load open until the test releases it, so the "loading
/// before navigating" window is observable.
class _GatedCategoryProvider extends CategoryProvider {
  _GatedCategoryProvider() : super(categoryRepo: null);

  final Completer<void> gate = Completer<void>();
  int ensureCalls = 0;

  @override
  Future<void> warmKioskMenuFromDisk(String localeCode) async {}

  @override
  Future<void> ensureKioskMenuReady({required String localeCode}) {
    ensureCalls++;
    return gate.future;
  }
}

late _GatedCategoryProvider category;

Future<void> pumpWelcome(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({AppConstants.branch: 1});
  final prefs = await SharedPreferences.getInstance();
  final dio = DioClient(
    'http://localhost',
    null,
    loggingInterceptor: LoggingInterceptor(),
    sharedPreferences: prefs,
  );
  category = _GatedCategoryProvider();

  final router = GoRouter(
    initialLocation: PosRoutes.welcome,
    routes: [
      GoRoute(
        path: PosRoutes.welcome,
        builder: (_, __) => const PosWelcomeScreen(),
      ),
      GoRoute(
        path: PosRoutes.home,
        builder: (_, __) => const Scaffold(body: Text('TILL')),
      ),
    ],
  );
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<SplashProvider>(
        create: (_) => KioskStubSplashProvider(
          splashRepo: SplashRepo(dioClient: dio, sharedPreferences: prefs),
        ),
      ),
      ChangeNotifierProvider<CategoryProvider>.value(value: category),
      ChangeNotifierProvider<LocalizationProvider>(
        create: (_) =>
            LocalizationProvider(sharedPreferences: prefs, dioClient: dio),
      ),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pump();
}

void main() {
  for (final size in const [
    Size(390, 844),
    Size(1280, 800),
    Size(1920, 1080),
    Size(1080, 1920),
  ]) {
    testWidgets('renders at ${size.width.toInt()}x${size.height.toInt()}',
        (tester) async {
      await pumpWelcome(tester, size);
      expect(tester.takeException(), isNull);
      expect(find.text('TOUCH TO START'), findsOneWidget);
    });
  }

  testWidgets('tap loads the menu first, then opens the till',
      (tester) async {
    await pumpWelcome(tester, const Size(1920, 1080));

    await tester.tapAt(const Offset(200, 900));
    await tester.pump();

    // Still here, spinner up, menu load in flight.
    expect(category.ensureCalls, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('TILL'), findsNothing);

    // A second tap while loading must not start another load.
    await tester.tapAt(const Offset(200, 900));
    await tester.pump();
    expect(category.ensureCalls, 1);

    category.gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('TILL'), findsOneWidget);
  });
}
