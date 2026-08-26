import 'dart:io';

import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/models/config_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/coupon/domain/models/coupon_model.dart';
import 'package:acafe_customer/features/coupon/providers/coupon_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_coupon_reward.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_session.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_confirm_screen.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_order_line_card.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/main.dart' show navigatorKey;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// The order summary with a coupon on it — Figma POS node 1385:15938
/// ("10a – Order Summary (Discounted)"): the list price struck through beside
/// what is actually paid, FREE where a line costs nothing, the discount on its
/// own labelled row, and a total that has the coupon taken off it.
class _StubSplashProvider extends SplashProvider {
  _StubSplashProvider({required super.splashRepo});

  @override
  ConfigModel? get configModel => ConfigModel(
        currencySymbol: '€',
        currencySymbolPosition: 'left',
        decimalPointSettings: 2,
      );

  @override
  BaseUrls? get baseUrls => BaseUrls(productImageUrl: 'http://localhost/p');
}

class _StubCartProvider extends CartProvider {
  _StubCartProvider(this._lines) : super(cartRepo: null);
  final List<CartModel?> _lines;

  @override
  List<CartModel?> get cartList => _lines;
}

class _StubCouponProvider extends CouponProvider {
  _StubCouponProvider({this.applied, this.amountOff = 0})
      : super(couponRepo: null);
  final CouponModel? applied;
  final double amountOff;

  @override
  CouponModel? get coupon => applied;

  @override
  double? get discount => amountOff;
}

Future<void> _loadFonts() async {
  const Map<String, List<String>> families = {
    'Loew': [
      'assets/fonts/Loew-Regular.ttf',
      'assets/fonts/Loew-Medium.ttf',
      'assets/fonts/Loew-Bold.ttf',
      'assets/fonts/Loew-ExtraBold.ttf',
    ],
    'Swiss721': ['assets/fonts/Swiss721-Light.ttf'],
    'ScotchDisplay': ['assets/fonts/ScotchDisplay-Light.ttf'],
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

CartModel _line({
  required String name,
  required double price,
  required double discountedPrice,
  int quantity = 1,
  double tax = 0,
}) =>
    CartModel(
      price,
      discountedPrice,
      const [],
      price - discountedPrice,
      quantity,
      tax,
      const [],
      Product(id: 1, name: name, image: '', price: price),
      const [],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_loadFonts);

  // €19.50 latte discounted to €17.50, plus a matcha the till gives away.
  final lines = <CartModel?>[
    _line(name: 'Iced Strawberry Latte', price: 19.50, discountedPrice: 17.50),
    _line(name: 'Iced Mango Matcha', price: 10.00, discountedPrice: 0),
  ];
  final coupon = CouponModel(
    id: 1,
    title: 'Summer Sale',
    code: 'SUMMER10',
    discount: 10,
    discountType: 'percent',
    minPurchase: 0,
    maxDiscount: 0,
  );

  Widget harness({double couponDiscount = 1.41}) => MultiProvider(
        providers: [
          ChangeNotifierProvider<CartProvider>(
              create: (_) => _StubCartProvider(lines)),
          ChangeNotifierProvider<CouponProvider>(
            create: (_) => _StubCouponProvider(
                applied: couponDiscount > 0 ? coupon : null,
                amountOff: couponDiscount),
          ),
          ChangeNotifierProvider<SplashProvider>(
              create: (_) => _StubSplashProvider(splashRepo: null)),
        ],
        // The real navigator key: PriceConverterHelper reads the currency
        // config off Get.context, which is this key's context.
        child: MaterialApp(
          navigatorKey: navigatorKey,
          home: const KioskConfirmScreen(),
        ),
      );

  Future<void> render(WidgetTester tester, {double couponDiscount = 1.41}) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(harness(couponDiscount: couponDiscount));
    await tester.pump();
  }

  group('line prices', () {
    test('the original total is the list price, before the line discount', () {
      expect(kioskLineOriginalTotal(lines[0]!), 19.50);
      expect(kioskLineTotal(lines[0]!), 17.50);
    });

    testWidgets('show the old price struck through beside the new one',
        (tester) async {
      await render(tester);

      expect(find.text('€19.50'), findsOneWidget);
      expect(find.text('€17.50'), findsOneWidget);

      final Text was = tester.widget<Text>(find.text('€19.50'));
      expect(was.style?.decoration, TextDecoration.lineThrough);
      expect(was.style?.color, kOrderWasPriceColor);

      final Text now = tester.widget<Text>(find.text('€17.50'));
      expect(now.style?.decoration, anyOf(isNull, TextDecoration.none));
      expect(now.style?.color, kOrderPriceColor);
    });

    testWidgets('say FREE instead of €0.00 when a line costs nothing',
        (tester) async {
      await render(tester);

      expect(find.text('€10.00'), findsOneWidget);
      expect(find.text('FREE'), findsOneWidget);
      // Scoped to the price rows: the summary's own TAX row is €0.00 here.
      expect(
        find.descendant(
          of: find.byType(KioskLinePriceRow),
          matching: find.text('€0.00'),
        ),
        findsNothing,
      );
    });

    testWidgets('leave an undiscounted line with a single price',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CartProvider>(
              create: (_) => _StubCartProvider([
                _line(name: 'Flat White', price: 4.00, discountedPrice: 4.00),
              ]),
            ),
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

      // The same €4.00 also appears as ITEMS TOTAL and as the total, so this
      // looks only inside the line's price row.
      final Finder linePrice = find.descendant(
        of: find.byType(KioskLinePriceRow),
        matching: find.text('€4.00'),
      );
      expect(linePrice, findsOneWidget);
      final Text price = tester.widget<Text>(linePrice);
      expect(price.style?.decoration, anyOf(isNull, TextDecoration.none));
    });
  });

  group('order summary', () {
    testWidgets('gives the coupon its own row, naming the offer',
        (tester) async {
      await render(tester);

      expect(find.textContaining('SUMMER SALE'), findsOneWidget);
      expect(find.text('- €1.41'), findsOneWidget);
    });

    testWidgets('puts the money coming off above TAX', (tester) async {
      await render(tester);

      final double couponRow =
          tester.getTopLeft(find.textContaining('SUMMER SALE')).dy;
      final double taxRow = tester.getTopLeft(find.text('TAX')).dy;
      expect(couponRow, lessThan(taxRow),
          reason: 'the artboard puts the discount between ITEMS TOTAL and TAX');
    });

    testWidgets('takes the coupon off the total', (tester) async {
      await render(tester);

      // items 29.50 − line discounts 12.00 + tax 0 − coupon 1.41
      expect(kioskPayableTotal(lines, 1.41), closeTo(16.09, 0.001));
      expect(find.text('€16.09'), findsOneWidget);
    });

    testWidgets('drops the row entirely when no coupon is applied',
        (tester) async {
      await render(tester, couponDiscount: 0);

      expect(find.textContaining('SUMMER SALE'), findsNothing);
      expect(find.text('- €1.41'), findsNothing);
      // Total is the un-couponed grand total.
      expect(find.text('€17.50'), findsWidgets);
    });
  });

  testWidgets('the wide layout carries the same labelled row', (tester) async {
    // >= 1100px switches the checkout to its fixed-pixel POS layout, which has
    // its own footer — the coupon row has to be on that one too.
    tester.view.physicalSize = const Size(1500, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(harness());
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('SUMMER SALE'), findsOneWidget);
    expect(find.text('- €1.41'), findsOneWidget);
    expect(find.text('€16.09'), findsOneWidget);
    expect(find.text('€19.50'), findsOneWidget);
    expect(find.text('FREE'), findsOneWidget);
  });

  // Rendered to PNG so the discounted summary can be compared against the
  // Figma frame by eye, the way the customize and coupon-applied screens are.
  // It shares this file's stubs rather than duplicating them into a golden-only
  // file. Regenerate after a deliberate design change:
  //   flutter test --update-goldens test/features/kiosk/coupon_cart_summary_test.dart
  testWidgets('golden — order summary with a coupon applied', (tester) async {
    await render(tester);

    await expectLater(
      find.byType(KioskConfirmScreen),
      matchesGoldenFile('goldens/order_summary_discounted_1080x1920.png'),
    );
  });

  group('the row label', () {
    test('prefers the offer name a customer can recognise', () {
      expect(
        kioskCouponRowLabel(
            discountLabel: 'Discount', title: 'Summer Sale', code: 'SUMMER10'),
        'DISCOUNT · SUMMER SALE',
      );
    });

    test('falls back to the code they typed', () {
      expect(
        kioskCouponRowLabel(
            discountLabel: 'Discount', title: '  ', code: 'SUMMER10'),
        'DISCOUNT · SUMMER10',
      );
    });

    test('is just the discount word when the coupon names nothing', () {
      expect(kioskCouponRowLabel(discountLabel: 'Discount'), 'DISCOUNT');
    });
  });
}
