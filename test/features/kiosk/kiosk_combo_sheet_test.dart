import 'dart:convert';
import 'dart:io';

import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/models/config_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_combo_match.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_deal.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_combo_sheet.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_upsell_sheet.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/main.dart' show navigatorKey;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Combo upgrade sheet (Figma 05a). No [AppLocalization.delegate] — every
/// string on the card must fall back to readable copy, the same convention
/// as the coupon screen and the upsell grid tests.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(resetKioskUpsellMemory);
  tearDown(resetKioskUpsellMemory);

  final latte = Product(id: 1, name: 'Latte', price: 5, image: '');
  final food = Product(id: 2, name: 'Poffertjes', price: 8, image: '');

  CartModel line(Product product) => CartModel(
        product.price,
        product.price,
        const [],
        0,
        1,
        0,
        const [],
        product,
        const [],
      );

  KioskDeal deal() => KioskDeal(
        id: 10,
        title: 'Latte + Poffertjes',
        image: '',
        bundlePrice: 10,
        originalPrice: 13,
        savings: 3,
        savingsPercent: 23,
        available: true,
        items: [
          KioskDealItem(quantity: 1, product: latte),
          KioskDealItem(quantity: 1, product: food),
        ],
      );

  Future<void> openSheet(
    WidgetTester tester, {
    required CartProvider cart,
    required KioskComboMatch match,
  }) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SplashProvider>(
            create: (_) => _StubSplash(splashRepo: null),
          ),
          ChangeNotifierProvider<CartProvider>.value(value: cart),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    openKioskComboSheet(context, match: match),
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

  testWidgets('starts with neither option selected and NEXT disabled',
      (tester) async {
    final cartList = [line(latte), line(food)];
    final cart = CartProvider(cartRepo: null)..replaceCartList(cartList);
    final match = findKioskComboUpgrade(cartList, [deal()])!;
    await openSheet(tester, cart: cart, match: match);

    expect(find.text('MAKE IT A COMBO MEAL?'), findsOneWidget);
    expect(find.text('YES, COMBO ME!'), findsOneWidget);
    expect(find.text('NO, JUST MY ORDER'), findsOneWidget);
    expect(find.text('NEXT'), findsOneWidget);
    expect(find.textContaining('€10.00'), findsOneWidget);
    expect(find.textContaining('You save'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('kiosk-combo-next')));
    await tester.pump();
    expect(find.text('MAKE IT A COMBO MEAL?'), findsOneWidget);
    expect(cart.cartList, hasLength(2));
    expect(cart.cartList.any((l) => l?.isDeal == true), isFalse);
  });

  testWidgets('YES then NEXT swaps the covering lines for the combo',
      (tester) async {
    final cartList = [line(latte), line(food)];
    final cart = CartProvider(cartRepo: null)..replaceCartList(cartList);
    final match = findKioskComboUpgrade(cartList, [deal()])!;
    await openSheet(tester, cart: cart, match: match);

    await tester.tap(find.byKey(const ValueKey('kiosk-combo-yes')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('kiosk-combo-next')));
    await tester.pumpAndSettle();

    expect(find.text('MAKE IT A COMBO MEAL?'), findsNothing);
    expect(cart.cartList, hasLength(1));
    expect(cart.cartList.first!.isDeal, isTrue);
    expect(cart.cartList.first!.dealId, 10);
    expect(cart.amount, 10);
  });

  testWidgets('NO then NEXT leaves the cart unchanged', (tester) async {
    final cartList = [line(latte), line(food)];
    final cart = CartProvider(cartRepo: null)..replaceCartList(cartList);
    final match = findKioskComboUpgrade(cartList, [deal()])!;
    await openSheet(tester, cart: cart, match: match);

    await tester.tap(find.byKey(const ValueKey('kiosk-combo-no')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('kiosk-combo-next')));
    await tester.pumpAndSettle();

    expect(find.text('MAKE IT A COMBO MEAL?'), findsNothing);
    expect(cart.cartList, hasLength(2));
    expect(cart.cartList.any((l) => l?.isDeal == true), isFalse);
    expect(cart.amount, 13);
  });

  testWidgets('the two option cards sit side by side, not stacked',
      (tester) async {
    final cartList = [line(latte), line(food)];
    final cart = CartProvider(cartRepo: null)..replaceCartList(cartList);
    final match = findKioskComboUpgrade(cartList, [deal()])!;
    await openSheet(tester, cart: cart, match: match);

    final Offset yes =
        tester.getTopLeft(find.byKey(const ValueKey('kiosk-combo-yes')));
    final Offset no =
        tester.getTopLeft(find.byKey(const ValueKey('kiosk-combo-no')));
    expect(yes.dy, closeTo(no.dy, 2));
    expect(no.dx, greaterThan(yes.dx));
  });

  test('combo strings exist in every language file', () {
    const keys = ['make_it_a_combo_meal', 'yes_combo_me', 'no_just_my_order'];
    for (final lang in ['en', 'nl', 'fr', 'de']) {
      final Map<String, dynamic> json = jsonDecode(
        File('assets/language/$lang.json').readAsStringSync(),
      );
      for (final key in keys) {
        expect(json[key], isA<String>(), reason: '$lang missing $key');
        expect((json[key] as String).isNotEmpty, isTrue, reason: '$lang $key');
      }
    }
  });
}

class _StubSplash extends SplashProvider {
  _StubSplash({required super.splashRepo});

  @override
  ConfigModel? get configModel => ConfigModel(
        currencySymbol: '€',
        currencySymbolPosition: 'left',
        decimalPointSettings: 2,
      );

  @override
  BaseUrls? get baseUrls => BaseUrls(
        productImageUrl: 'http://localhost/product',
        dealImageUrl: 'http://localhost/deal',
      );
}
