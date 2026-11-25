import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/models/config_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:acafe_customer/features/cart/domain/reposotories/cart_repo.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/coupon/providers/coupon_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_deal.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_deal_repo.dart';
import 'package:acafe_customer/features/kiosk/landscape/widgets/landscape_cancel_dialog.dart';
import 'package:acafe_customer/features/kiosk/landscape/widgets/landscape_order_panel.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_auth_repo.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_deal_provider.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/main.dart' show navigatorKey;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _loadFonts() async {
  const Map<String, List<String>> families = {
    'Loew': [
      'assets/fonts/Loew-Regular.ttf',
      'assets/fonts/Loew-Medium.ttf',
      'assets/fonts/Loew-Bold.ttf',
      'assets/fonts/Loew-ExtraBold.ttf',
    ],
    'Swiss721Light': ['assets/fonts/Swiss 721 Light.otf'],
    'NunitoSans': [
      'assets/fonts/NunitoSans-Regular.ttf',
      'assets/fonts/NunitoSans-Medium.ttf',
    ],
  };
  for (final entry in families.entries) {
    final loader = FontLoader(entry.key);
    for (final path in entry.value) {
      loader.addFont(File(path)
          .readAsBytes()
          .then((bytes) => ByteData.view(Uint8List.fromList(bytes).buffer)));
    }
    await loader.load();
  }
}

class _StubSplash extends SplashProvider {
  _StubSplash({required super.splashRepo});
  @override
  ConfigModel? get configModel => ConfigModel(
      currencySymbol: '€',
      currencySymbolPosition: 'left',
      decimalPointSettings: 2);
  @override
  BaseUrls? get baseUrls => BaseUrls(productImageUrl: 'http://localhost/p');
}

class _StubDeals extends KioskDealProvider {
  final List<KioskDeal> _d;
  _StubDeals(KioskDealRepo repo, this._d) : super(dealRepo: repo);
  @override
  List<KioskDeal> get deals => _d;
  @override
  Future<bool> fetchDeals() async => false;
}

CartModel _line(String name, double price) => CartModel(
      price,
      price,
      const [],
      0,
      1,
      0,
      const [],
      Product(id: name.hashCode, name: name, image: '', price: price),
      const [],
    );

Future<Widget> _harness(
  WidgetTester tester, {
  required List<CartModel?> lines,
  required VoidCallback onCheckout,
  required VoidCallback onCancelOrder,
  VoidCallback? onCoupon,
  VoidCallback? onCombo,
  List<KioskDeal> deals = const [],
  int? highlightIndex,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final dio = DioClient('http://localhost', null,
      loggingInterceptor: LoggingInterceptor(), sharedPreferences: prefs);

  tester.view.physicalSize = const Size(1366, 1024);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<CartProvider>(
          create: (_) => CartProvider(cartRepo: CartRepo(sharedPreferences: prefs))
            ..replaceCartList(lines)),
      ChangeNotifierProvider<CouponProvider>(
          create: (_) => CouponProvider(couponRepo: null)),
      ChangeNotifierProvider<SplashProvider>(
          create: (_) => _StubSplash(splashRepo: null)),
      ChangeNotifierProvider<KioskAuthProvider>(
          create: (_) => KioskAuthProvider(
              kioskAuthRepo:
                  KioskAuthRepo(dioClient: dio, sharedPreferences: prefs))),
      ChangeNotifierProvider<KioskDealProvider>(
          create: (_) => _StubDeals(
              KioskDealRepo(dioClient: dio, sharedPreferences: prefs), deals)),
    ],
    child: MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: 350,
            height: 1024,
            child: LandscapeOrderPanel(
              s: 1.0,
              onCheckout: onCheckout,
              onCancelOrder: onCancelOrder,
              onCoupon: onCoupon ?? () {},
              onCombo: onCombo ?? () {},
              highlightIndex: highlightIndex,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);

  group('B-01 empty order', () {
    testWidgets('shows the empty state and hides Cancel order', (tester) async {
      await tester.pumpWidget(await _harness(tester,
          lines: const [], onCheckout: () {}, onCancelOrder: () {}));
      await tester.pump();

      expect(find.text('Your order is empty'), findsOneWidget);
      expect(find.text('0 items'), findsOneWidget);
      expect(find.textContaining('Cancel order'), findsNothing);
    });

    testWidgets('CHECK OUT does nothing when the order is empty',
        (tester) async {
      var checkedOut = false;
      await tester.pumpWidget(await _harness(tester,
          lines: const [],
          onCheckout: () => checkedOut = true,
          onCancelOrder: () {}));
      await tester.pump();

      await tester.tap(find.text('CHECK OUT'));
      await tester.pump();
      expect(checkedOut, isFalse);
    });
  });

  group('B-02 order with items', () {
    testWidgets('lists the items with a count and Cancel order', (tester) async {
      await tester.pumpWidget(await _harness(tester, lines: [
        _line('Iced Strawberry Latte', 6),
        _line('Iced Mango Matcha', 7),
      ], onCheckout: () {}, onCancelOrder: () {}));
      await tester.pump();

      expect(find.text('2 items'), findsOneWidget);
      expect(find.text('Iced Strawberry Latte'), findsOneWidget);
      expect(find.text('Iced Mango Matcha'), findsOneWidget);
      expect(find.text('Your order is empty'), findsNothing);
      expect(find.textContaining('Cancel order'), findsOneWidget);
    });

    testWidgets('8+ lines scroll, and the newest (highlighted) line is scrolled into view',
        (tester) async {
      final lines = [
        for (int i = 0; i < 9; i++) _line('Drink number $i with a long name', 5.0 + i),
      ];
      // Mirrors the real flow: the list first renders with nothing
      // highlighted, then the newest line is highlighted on a later build —
      // exactly the transition `_ItemList.didUpdateWidget` reacts to.
      await tester.pumpWidget(await _harness(
        tester,
        lines: lines,
        onCheckout: () {},
        onCancelOrder: () {},
      ));
      await tester.pump();
      await tester.pumpWidget(await _harness(
        tester,
        lines: lines,
        onCheckout: () {},
        onCancelOrder: () {},
        highlightIndex: lines.length - 1,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.text('Drink number 8 with a long name'), findsOneWidget);
    });

    testWidgets('CHECK OUT fires when there are items', (tester) async {
      var checkedOut = false;
      await tester.pumpWidget(await _harness(tester,
          lines: [_line('Latte', 6)],
          onCheckout: () => checkedOut = true,
          onCancelOrder: () {}));
      await tester.pump();

      await tester.tap(find.text('CHECK OUT'));
      await tester.pump();
      expect(checkedOut, isTrue);
    });

    testWidgets('Cancel order fires its callback', (tester) async {
      var cancelled = false;
      await tester.pumpWidget(await _harness(tester,
          lines: [_line('Latte', 6)],
          onCheckout: () {},
          onCancelOrder: () => cancelled = true));
      await tester.pump();

      await tester.tap(find.textContaining('Cancel order'));
      await tester.pump();
      expect(cancelled, isTrue);
    });

    testWidgets('shows the combo card when a product-bundle deal is available',
        (tester) async {
      await tester.pumpWidget(await _harness(
        tester,
        lines: [_line('Latte', 6)],
        onCheckout: () {},
        onCancelOrder: () {},
        deals: const [
          KioskDeal(
            id: 1,
            dealType: KioskDeal.typeProductBundle,
            title: 'Strawberry Matcha Meal',
            bundlePrice: 16.0,
            originalPrice: 20.0,
            savings: 4.0,
            savingsPercent: 20,
            available: true,
            items: [],
          ),
        ],
      ));
      await tester.pump();

      expect(find.textContaining('COMBO'), findsWidgets);
      expect(find.text('Strawberry Matcha Meal'), findsOneWidget);
      expect(find.text('Enter code'), findsOneWidget);
    });

    testWidgets('hides the whole combo block when there is no bundle deal',
        (tester) async {
      await tester.pumpWidget(await _harness(tester,
          lines: [_line('Latte', 6)], onCheckout: () {}, onCancelOrder: () {}));
      await tester.pump();

      expect(find.textContaining('COMBO'), findsNothing);
      expect(find.text('Enter code'), findsOneWidget);
    });

    group('kLandscapeComboEnabled flag (Phase 5 Part C — "+" not wired to anything)', () {
      final bundleDeal = [
        KioskDeal(
          id: 1,
          dealType: KioskDeal.typeProductBundle,
          title: 'Strawberry Matcha Meal',
          bundlePrice: 16.0,
          originalPrice: 20.0,
          savings: 4.0,
          savingsPercent: 20,
          available: true,
          items: [],
        ),
      ];

      tearDown(() => kLandscapeComboEnabled = true);

      testWidgets('true (default): combo card renders when a bundle exists',
          (tester) async {
        kLandscapeComboEnabled = true;
        await tester.pumpWidget(await _harness(tester,
            lines: [_line('Latte', 6)],
            onCheckout: () {},
            onCancelOrder: () {},
            deals: bundleDeal));
        await tester.pump();

        expect(find.textContaining('COMBO'), findsWidgets);
      });

      testWidgets('false: the whole combo block is hidden even with a bundle available',
          (tester) async {
        kLandscapeComboEnabled = false;
        await tester.pumpWidget(await _harness(tester,
            lines: [_line('Latte', 6)],
            onCheckout: () {},
            onCancelOrder: () {},
            deals: bundleDeal));
        await tester.pump();

        expect(find.textContaining('COMBO'), findsNothing);
      });
    });
  });

  group('B-04 cancel dialog', () {
    Future<void> pumpTrigger(
        WidgetTester tester, void Function(bool) onResult) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  onResult(await showLandscapeCancelOrderDialog(context, s: 1.0)),
              child: const Text('open'),
            ),
          ),
        ),
      ));
    }

    testWidgets('YES, CANCEL resolves true', (tester) async {
      bool? result;
      await pumpTrigger(tester, (r) => result = r);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Cancel your order?'), findsOneWidget);
      await tester.tap(find.text('YES, CANCEL'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });

    testWidgets('KEEP ORDERING resolves false and dismisses', (tester) async {
      bool? result;
      await pumpTrigger(tester, (r) => result = r);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('KEEP ORDERING'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
      expect(find.text('Cancel your order?'), findsNothing);
    });
  });
}
