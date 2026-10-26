import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:acafe_customer/features/category/providers/category_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_auth_repo.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/language/providers/localization_provider.dart';
import 'package:acafe_customer/features/pos/domain/pos_staff_session.dart';
import 'package:acafe_customer/features/pos/domain/pos_staff_session_repo.dart';
import 'package:acafe_customer/features/pos/providers/pos_staff_session_provider.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/features/pos/widgets/pos_staff_lock_screen.dart';
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/kiosk_layout_harness.dart';

/// The POS PIN screen must warm the catalog while the operator types, so
/// /pos-home paints from cache instead of a spinner on a fresh device login.
/// It must stay idempotent so a different member signing in next does not
/// re-fetch.

/// Records the warm calls; does no real network (categoryRepo is null).
class _SpyCategory extends CategoryProvider {
  _SpyCategory() : super(categoryRepo: null);

  final List<String> warmed = [];

  @override
  Future<void> warmKioskMenuFromDisk(String localeCode) async {
    warmed.add(localeCode);
  }
}

/// A roster with staff login on, so the lock screen is the real PIN gate.
class _Roster extends PosStaffSessionRepo {
  _Roster() : super(dioClient: null);

  @override
  Future<PosSignInRoster?> signInRoster() async => const PosSignInRoster(
        staffLoginRequired: true,
        pinLength: 4,
        lockoutSeconds: 0,
        members: [],
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the PIN screen warms the catalog while the operator types',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({
      AppConstants.token: 'device-token',
      AppConstants.branch: 1,
      AppConstants.kioskDeviceCategory: 'pos',
    });
    final prefs = await SharedPreferences.getInstance();
    final dio = DioClient('http://localhost', null,
        loggingInterceptor: LoggingInterceptor(), sharedPreferences: prefs);

    final category = _SpyCategory();
    final staff = PosStaffSessionProvider(repo: _Roster());

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<CategoryProvider>.value(value: category),
        ChangeNotifierProvider<PosStaffSessionProvider>.value(value: staff),
        ChangeNotifierProvider<KioskAuthProvider>(
          create: (_) => KioskAuthProvider(
              kioskAuthRepo:
                  KioskAuthRepo(dioClient: dio, sharedPreferences: prefs)),
        ),
        ChangeNotifierProvider<SplashProvider>(
          create: (_) => KioskStubSplashProvider(splashRepo: null),
        ),
        ChangeNotifierProvider<LocalizationProvider>(
          create: (_) => LocalizationProvider(
              sharedPreferences: prefs, dioClient: dio),
        ),
      ],
      child: const MaterialApp(home: Scaffold(body: PosStaffLockScreen())),
    ));
    await tester.pump(); // let the post-frame warm run

    expect(category.warmed, isNotEmpty,
        reason: 'the lock screen must start the catalog warm on mount');
  });

  testWidgets('a lock screen with no catalog providers simply skips the warm',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final staff = PosStaffSessionProvider(repo: _Roster());

    // No CategoryProvider / Splash / Localization in the tree: must not throw.
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<PosStaffSessionProvider>.value(value: staff),
      ],
      child: const MaterialApp(home: Scaffold(body: PosStaffLockScreen())),
    ));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
