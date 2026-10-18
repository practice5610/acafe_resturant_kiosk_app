import 'dart:io';

import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:acafe_customer/features/cart/domain/reposotories/cart_repo.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/coupon/providers/coupon_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_auth_repo.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_manager_repo.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipt_history.dart';
import 'package:acafe_customer/features/pos/domain/pos_refund_session.dart';
import 'package:acafe_customer/features/pos/pos_shell.dart';
import 'package:acafe_customer/features/pos/providers/pos_session_provider.dart';
import 'package:acafe_customer/features/pos/screens/pos_refund_screen.dart';
import 'package:acafe_customer/features/pos/widgets/pos_top_nav_bar.dart';
import 'package:acafe_customer/features/splash/domain/reposotories/splash_repo.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/main.dart' show navigatorKey;
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:acafe_customer/features/pos/widgets/pos_pay_shell.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/kiosk_layout_harness.dart';

/// Regression tests for the two Refund bugs fixed in this pass:
///
///  (a) DOUBLE HEADER — /pos-refund lives OUTSIDE the shell, so entering it with
///      context.push left the shell's nav bar mounted under the refund screen's
///      own nav bar. The screen must render exactly ONE PosTopNavBar.
///
///  (b) HANG — PosRefundScreen.initState used to call session.reset(), which
///      wiped the `order` that the caller set right before navigating. The next
///      step then dereferenced session.order!.id → crash → busy stuck true. The
///      screen must now preserve `order` across initState (it calls resetFlow).

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

PosReceiptDetail _receipt({
  int id = 27362,
  String method = 'cash',
  double total = 19.0,
}) {
  return PosReceiptDetail.fromJson({
    'id': id,
    'created_at': '2026-10-17T10:00:00.000000Z',
    'customer_name': 'Dylan',
    'display_method': method,
    'payment_method': 'cash_on_delivery',
    'order_status': 'delivered',
    'payment_status': 'paid',
    'table': null,
    'subtotal': total,
    'discount': 0,
    'total': total,
    'details': const [],
  });
}

Future<void> _pumpRefund(WidgetTester tester,
    {Size size = const Size(1366, 1024)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({
    AppConstants.branch: 1,
    AppConstants.kioskDeviceCategory: 'pos',
    AppConstants.kioskDeviceName: 'Till 1',
  });
  final prefs = await SharedPreferences.getInstance();
  final dio = DioClient(
    'http://localhost',
    null,
    loggingInterceptor: LoggingInterceptor(),
    sharedPreferences: prefs,
  );
  final cart = CartProvider(cartRepo: CartRepo(sharedPreferences: prefs));

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<KioskAuthProvider>(
          create: (_) => KioskAuthProvider(
            kioskAuthRepo:
                KioskAuthRepo(dioClient: dio, sharedPreferences: prefs),
          ),
        ),
        ChangeNotifierProvider<SplashProvider>(
          create: (_) => KioskStubSplashProvider(
            splashRepo: SplashRepo(dioClient: dio, sharedPreferences: prefs),
          ),
        ),
        ChangeNotifierProvider<CartProvider>.value(value: cart),
        ChangeNotifierProvider<CouponProvider>(
          create: (_) => CouponProvider(couponRepo: null),
        ),
        ChangeNotifierProvider<PosSessionProvider>(
          create: (_) => PosSessionProvider(
            kioskManagerRepo:
                KioskManagerRepo(dioClient: dio, sharedPreferences: prefs),
          )..debugSetElevated(true),
        ),
      ],
      child: MediaQuery(
        data: MediaQueryData(size: size),
        child: PosShell(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            navigatorKey: navigatorKey,
            home: const PosRefundScreen(),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);

  // ── Bug (b) root cause: session lifecycle ───────────────────────────────────
  group('PosRefundSession.resetFlow preserves the inbound order', () {
    test('resetFlow keeps order and splits, clears flow state', () {
      final s = PosRefundSession.instance;
      s.order = _receipt();
      s.splits = [
        const PosRefundSplit(id: 1, seq: 1, method: 'cash', amount: 10),
      ];
      s.reason.value = PosRefundReason.wrongItem;
      s.busy.value = true;
      s.error.value = 'stale';

      s.resetFlow();

      // The order the caller set MUST survive — this is the hang regression.
      expect(s.order, isNotNull);
      expect(s.order!.id, 27362);
      expect(s.splits, isNotEmpty);
      // Flow state is cleared.
      expect(s.reason.value, isNull);
      expect(s.busy.value, isFalse);
      expect(s.error.value, isNull);
    });

    test('reset clears order and splits as well', () {
      final s = PosRefundSession.instance;
      s.order = _receipt();
      s.splits = [
        const PosRefundSplit(id: 1, seq: 1, method: 'cash', amount: 10),
      ];

      s.reset();

      expect(s.order, isNull);
      expect(s.splits, isEmpty);
    });
  });

  // ── Bug (a) + (b) at the widget level ───────────────────────────────────────
  group('PosRefundScreen', () {
    tearDown(() => PosRefundSession.instance.reset());

    testWidgets('renders exactly ONE header (no shell duplication)',
        (tester) async {
      PosRefundSession.instance.order = _receipt();
      await _pumpRefund(tester);

      // Figma 1915:11344: the refund frames open on their own back row (no
      // nav bar), and it is drawn exactly once.
      expect(find.byType(PosPayBackRow), findsOneWidget);
      expect(find.byType(PosTopNavBar), findsNothing);
    });

    testWidgets('order survives initState (hang regression)', (tester) async {
      PosRefundSession.instance.order = _receipt(id: 999);
      await _pumpRefund(tester);

      // initState calls resetFlow (not reset) → the order the caller set is
      // still present, so _createRefund will not crash on order!.id.
      expect(PosRefundSession.instance.order, isNotNull);
      expect(PosRefundSession.instance.order!.id, 999);
    });

    testWidgets('shows the first step (reason + items), not a hang spinner',
        (tester) async {
      PosRefundSession.instance.order = _receipt();
      await _pumpRefund(tester);

      expect(find.text('REFUND REASON'), findsOneWidget);
      expect(find.text('Continue to refund method'), findsOneWidget);
    });
  });
}
