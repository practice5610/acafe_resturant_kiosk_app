import 'dart:io';
import 'dart:typed_data';

import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_auth_repo.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_manager_repo.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_manager_provider.dart';
import 'package:acafe_customer/features/pos/domain/pos_routes.dart';
import 'package:acafe_customer/features/pos/widgets/pos_nav_pill.dart';
import 'package:acafe_customer/features/pos/widgets/pos_top_nav_bar.dart';
import 'package:acafe_customer/features/pos/widgets/pos_ui.dart';
import 'package:acafe_customer/features/pos/widgets/pos_wordmark.dart';
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Real type metrics, so the padding-driven pill geometry is measured against
/// the font the design was drawn in rather than the test fallback.
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

/// Records whether the shift lock was actually cleared.
class _SpyManagerProvider extends KioskManagerProvider {
  _SpyManagerProvider(KioskManagerRepo repo) : super(kioskManagerRepo: repo);

  int lockCalls = 0;

  @override
  void lockManagerAccess() {
    lockCalls++;
    super.lockManagerAccess();
  }
}

late KioskAuthProvider auth;
late _SpyManagerProvider manager;

Future<void> _buildProviders() async {
  SharedPreferences.setMockInitialValues({
    AppConstants.token: 'device-token',
    AppConstants.branch: 1,
    AppConstants.kioskDeviceCategory: 'pos',
    AppConstants.kioskBranchName: 'Amsterdam',
    AppConstants.kioskDeviceName: 'Till 1',
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
  manager = _SpyManagerProvider(
      KioskManagerRepo(dioClient: dio, sharedPreferences: prefs));
}

Future<void> pumpBar(
  WidgetTester tester, {
  String currentPath = PosRoutes.home,
  DateTime Function()? now,
  double width = 1366,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await _buildProviders();

  // A real GoRouter, because locking the terminal navigates to the lock screen
  // and `context.go` asserts on an ancestor router.
  final router = GoRouter(
    initialLocation: '/host',
    routes: [
      GoRoute(
        path: '/host',
        builder: (context, state) => Scaffold(
          body: Column(
            children: [
              PosTopNavBar(
                currentPath: currentPath,
                now: now ?? () => DateTime(2026, 6, 23, 23, 59, 50),
              ),
            ],
          ),
        ),
      ),
      GoRoute(
        path: PosRoutes.login,
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('LOCK SCREEN'))),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<KioskAuthProvider>.value(value: auth),
        ChangeNotifierProvider<KioskManagerProvider>.value(value: manager),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Color pillColor(WidgetTester tester, int index) => tester
    .widget<Material>(find.descendant(
      of: find.byType(PosNavPill).at(index),
      matching: find.byType(Material),
    ))
    .color!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);

  group('active pill follows currentPath', () {
    // The pill order in the bar.
    const labels = ['POS', 'Report', 'Orders', 'Receipts', 'Settings'];

    const cases = <String, int>{
      PosRoutes.home: 0,
      PosRoutes.report: 1,
      PosRoutes.orders: 2,
      PosRoutes.receipts: 3,
      PosRoutes.settings: 4,
      // Browse is reached from the POS tab, so POS stays lit.
      PosRoutes.browse: 0,
    };

    cases.forEach((path, expectedIndex) {
      testWidgets('$path lights ${labels[expectedIndex]}', (tester) async {
        await pumpBar(tester, currentPath: path);

        for (int i = 0; i < labels.length; i++) {
          final bool shouldBeActive = i == expectedIndex;
          expect(
            pillColor(tester, i),
            shouldBeActive ? PosUI.ink : Colors.white,
            reason: '${labels[i]} active=$shouldBeActive for $path',
          );
        }
      });
    });

    testWidgets('a payment path lights nothing — payment leaves the shell',
        (tester) async {
      await pumpBar(tester, currentPath: PosRoutes.payment);
      for (int i = 0; i < 5; i++) {
        expect(pillColor(tester, i), Colors.white);
      }
    });
  });

  group('geometry matches the Figma frame', () {
    testWidgets('bar height and horizontal padding', (tester) async {
      await pumpBar(tester);

      expect(tester.getSize(find.byType(PosTopNavBar)).height, 80);

      // Wordmark starts at the 32px left padding.
      expect(tester.getTopLeft(find.byType(PosWordmark)).dx, 32);

      // Avatar ends at the 32px right padding.
      expect(
        tester.getBottomRight(find.byType(PosAvatar)).dx,
        1366 - 32,
      );
    });

    testWidgets('wordmark keeps the artwork ratio', (tester) async {
      await pumpBar(tester);
      final size = tester.getSize(find.byType(PosWordmark));
      expect(size.height, 18);
      expect(size.width, closeTo(68.652, 0.01));
    });

    testWidgets('12px between pills', (tester) async {
      await pumpBar(tester);
      for (int i = 0; i < 4; i++) {
        final a = tester.getRect(find.byType(PosNavPill).at(i));
        final b = tester.getRect(find.byType(PosNavPill).at(i + 1));
        expect(b.left - a.right, closeTo(12, 0.01),
            reason: 'gap between pill $i and ${i + 1}');
      }
    });

    testWidgets('16px from pills to scan, and scan to avatar',
        (tester) async {
      await pumpBar(tester);
      final lastPill = tester.getRect(find.byType(PosNavPill).at(4));
      final scan = tester.getRect(find.byKey(PosNavBarSpec.scanButtonKey));
      final avatar = tester.getRect(find.byType(PosAvatar));

      expect(scan.left - lastPill.right, closeTo(16, 0.01));
      expect(avatar.left - scan.right, closeTo(16, 0.01));
    });

    testWidgets('scan is 36 and avatar is 40', (tester) async {
      await pumpBar(tester);
      expect(tester.getSize(find.byKey(PosNavBarSpec.scanButtonKey)),
          const Size(36, 36));
      expect(tester.getSize(find.byType(PosAvatar)), const Size(40, 40));
    });

    testWidgets('pill heights come from padding, not hardcoded widths',
        (tester) async {
      await pumpBar(tester);
      // 12 + 17 line box + 12 for every pill except Report, which is 10/10.
      for (final i in [0, 2, 3, 4]) {
        expect(tester.getSize(find.byType(PosNavPill).at(i)).height,
            closeTo(41, 0.5),
            reason: 'pill $i should be 41 tall');
      }
      expect(tester.getSize(find.byType(PosNavPill).at(1)).height,
          closeTo(37, 0.5),
          reason: 'Report is 18/10 in the design');
    });

    testWidgets('the date sits at the measured offset from the wordmark',
        (tester) async {
      await pumpBar(tester);
      final wordmark = tester.getRect(find.byType(PosWordmark));
      final date = tester.getRect(find.text('Tuesday, 23 June'));
      expect(date.left - wordmark.right,
          closeTo(PosNavBarSpec.kNavDateOffset, 0.01));
    });
  });

  group('date', () {
    testWidgets('renders the injected day, not the wall clock', (tester) async {
      await pumpBar(tester, now: () => DateTime(2026, 6, 23, 9, 0));
      expect(find.text('Tuesday, 23 June'), findsOneWidget);
    });

    testWidgets('rolls over at midnight without a rebuild', (tester) async {
      DateTime fakeNow = DateTime(2026, 6, 23, 23, 59, 50);
      await pumpBar(tester, now: () => fakeNow);

      expect(find.text('Tuesday, 23 June'), findsOneWidget);

      // Cross midnight. The widget is never rebuilt from outside — only its
      // own timer fires.
      fakeNow = DateTime(2026, 6, 24, 0, 0, 2);
      await tester.pump(const Duration(seconds: 12));

      expect(find.text('Tuesday, 23 June'), findsNothing);
      expect(find.text('Wednesday, 24 June'), findsOneWidget);
    });
  });

  group('actions', () {
    testWidgets('avatar opens the menu and locks the terminal',
        (tester) async {
      await pumpBar(tester);
      expect(manager.lockCalls, 0);

      await tester.tap(find.byType(PosAvatar));
      await tester.pumpAndSettle();
      expect(find.text('Lock terminal'), findsOneWidget);

      await tester.tap(find.text('Lock terminal'));
      await tester.pumpAndSettle();

      expect(manager.lockCalls, 1);
      expect(manager.isPinVerified, isFalse);
      // ...and the terminal is actually sent to the lock screen, rather than
      // sitting unlocked-looking until the next navigation.
      expect(find.text('LOCK SCREEN'), findsOneWidget);
      expect(find.byType(PosTopNavBar), findsNothing);
    });

    testWidgets('the avatar menu can be dismissed without locking',
        (tester) async {
      await pumpBar(tester);
      await tester.tap(find.byType(PosAvatar));
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(400, 400));
      await tester.pumpAndSettle();

      expect(find.text('Lock terminal'), findsNothing);
      expect(manager.lockCalls, 0);
    });

    testWidgets('scan is inert — tapping it does nothing and does not throw',
        (tester) async {
      await pumpBar(tester);
      await tester.tap(find.byKey(PosNavBarSpec.scanButtonKey),
          warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(manager.lockCalls, 0);
      expect(find.byType(PosTopNavBar), findsOneWidget);
    });
  });

  testWidgets('degrades on a narrower window instead of overflowing',
      (tester) async {
    await pumpBar(tester, width: 1024);
    expect(tester.takeException(), isNull);
  });
}
