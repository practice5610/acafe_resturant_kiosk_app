import 'dart:io';

import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/models/config_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/coupon/providers/coupon_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_session.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_confirm_screen.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_tip_sheet.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/main.dart' show navigatorKey;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _StubSplashProvider extends SplashProvider {
  _StubSplashProvider({required super.splashRepo});

  @override
  ConfigModel? get configModel => ConfigModel(
        currencySymbol: '€',
        currencySymbolPosition: 'left',
        decimalPointSettings: 2,
      );
}

class _StubCartProvider extends CartProvider {
  _StubCartProvider(this._lines) : super(cartRepo: null);
  final List<CartModel?> _lines;

  @override
  List<CartModel?> get cartList => _lines;
}

class _StubCouponProvider extends CouponProvider {
  _StubCouponProvider() : super(couponRepo: null);

  @override
  double? get discount => 0;
}

Future<void> _loadFonts() async {
  const families = <String, List<String>>{
    'Loew': [
      'assets/fonts/Loew-Regular.ttf',
      'assets/fonts/Loew-Medium.ttf',
      'assets/fonts/Loew-Bold.ttf',
      'assets/fonts/Loew-ExtraBold.ttf',
    ],
  };
  for (final family in families.entries) {
    final loader = FontLoader(family.key);
    for (final path in family.value) {
      loader.addFont(
        File(path).readAsBytes().then((b) => b.buffer.asByteData()),
      );
    }
    await loader.load();
  }
}

List<CartModel?> get _lines => [
      CartModel(
        8.80,
        8.80,
        const [],
        0,
        1,
        0,
        const [],
        Product(id: 1, name: 'Flat White', image: '', price: 8.80),
        const [],
      ),
    ];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_loadFonts);
  setUp(KioskSession.instance.reset);
  tearDown(KioskSession.instance.reset);

  Future<void> openSheet(
    WidgetTester tester, {
    double payable = 8.80,
    void Function(int?)? onResult,
  }) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<SplashProvider>(
        create: (_) => _StubSplashProvider(splashRepo: null),
        child: MaterialApp(
          navigatorKey: navigatorKey,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  final int? result = await openKioskTipSheet(
                    context,
                    payableTotal: payable,
                  );
                  onResult?.call(result);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('opens in the empty state: no tile is preselected',
      (tester) async {
    await openSheet(tester);

    expect(find.text('Enjoying your visit? Tip the team'), findsOneWidget);
    expect(find.text('Your tip goes directly to the team'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
    expect(find.text('No tip'), findsOneWidget);
    expect(find.text('5%'), findsOneWidget);
    expect(find.text('€0.44'), findsOneWidget);
    expect(find.text('10%'), findsOneWidget);
    expect(find.text('€0.88'), findsOneWidget);
    expect(find.text('15%'), findsOneWidget);
    expect(find.text('NO, THANK YOU!'), findsOneWidget);

    final AnimatedContainer five = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('kiosk-tip-5')),
    );
    final BoxDecoration decoration = five.decoration! as BoxDecoration;
    expect(decoration.border?.top.color, isNot(Colors.black));
    expect(decoration.border?.top.width, lessThan(2));
  });

  testWidgets('No, thank you continues with a zero tip', (tester) async {
    int? result = -1;
    await openSheet(tester, onResult: (value) => result = value);

    await tester.tap(find.byKey(const ValueKey('kiosk-tip-decline')));
    await tester.pumpAndSettle();

    expect(result, 0);
    expect(find.text('Enjoying your visit? Tip the team'), findsNothing);
  });

  testWidgets('selecting 10% shows the selected state then returns 10',
      (tester) async {
    int? result;
    await openSheet(tester, onResult: (value) => result = value);

    await tester.tap(find.byKey(const ValueKey('kiosk-tip-10')));
    await tester.pump(); // selected border paints
    await tester.pump(const Duration(milliseconds: 50));

    final AnimatedContainer ten = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('kiosk-tip-10')),
    );
    final BoxDecoration decoration = ten.decoration! as BoxDecoration;
    expect(decoration.border?.top.color, const Color(0xFF1E1E1E));
    expect(decoration.border?.top.width, greaterThanOrEqualTo(2.5));

    await tester.pump(const Duration(milliseconds: 320));
    await tester.pumpAndSettle();
    expect(result, 10);
  });

  testWidgets('Pay on the order summary opens the tip sheet', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<CartProvider>(
              create: (_) => _StubCartProvider(_lines)),
          ChangeNotifierProvider<CouponProvider>(
              create: (_) => _StubCouponProvider()),
          ChangeNotifierProvider<SplashProvider>(
              create: (_) => _StubSplashProvider(splashRepo: null)),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          home: const KioskConfirmScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Enjoying your visit? Tip the team'), findsNothing);

    await tester.tap(find.text('COMPLETE ORDER & PAY'));
    await tester.pumpAndSettle();

    expect(find.text('Enjoying your visit? Tip the team'), findsOneWidget);
    expect(find.text('No tip'), findsOneWidget);

    // Dismissing the scrim cancels Pay — the customer is still on the summary.
    await tester.tapAt(const Offset(16, 16));
    await tester.pumpAndSettle();

    expect(find.text('Enjoying your visit? Tip the team'), findsNothing);
    expect(find.text('COMPLETE ORDER & PAY'), findsOneWidget);
    expect(KioskSession.instance.hasLockedInTip, isFalse);
  });

  testWidgets('a locked-in tip is shown on the summary and not pre-applied at 0',
      (tester) async {
    KioskSession.instance.applyTip(10);
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<CartProvider>(
              create: (_) => _StubCartProvider(_lines)),
          ChangeNotifierProvider<CouponProvider>(
              create: (_) => _StubCouponProvider()),
          ChangeNotifierProvider<SplashProvider>(
              create: (_) => _StubSplashProvider(splashRepo: null)),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          home: const KioskConfirmScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('TIP'), findsOneWidget);
    expect(find.text('€0.88'), findsOneWidget);
    expect(find.text('€9.68'), findsOneWidget);
    expect(KioskSession.instance.hasLockedInTip, isTrue);
  });
}
