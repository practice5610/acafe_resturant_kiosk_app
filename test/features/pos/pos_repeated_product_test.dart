// POS: a product-grid tap opens a BLANK configuration.
//
// `openPosCustomize` used to scan the receipt by `product.id`, and on a hit it
// seeded this screen with that line's picks and set `cartIndex`, so saving
// overwrote the line and `removeOtherLinesForProduct` deleted the rest. That is
// why adding Americano/Small after Americano/Large replaced the Large line
// instead of adding a second one.
//
// The receipt-pane line tap (`openPosCartLine`) is now the only path that may
// pass a cart index.

import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/models/config_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/common/providers/product_provider.dart';
import 'package:acafe_customer/common/reposotories/product_repo.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:acafe_customer/features/cart/domain/reposotories/cart_repo.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/category/domain/reposotories/category_repo.dart';
import 'package:acafe_customer/features/category/providers/category_provider.dart';
import 'package:acafe_customer/features/coupon/domain/reposotories/coupon_repo.dart';
import 'package:acafe_customer/features/coupon/providers/coupon_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_auth_repo.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/pos/screens/pos_product_customize_screen.dart';
import 'package:acafe_customer/features/splash/domain/reposotories/splash_repo.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/main.dart' show navigatorKey;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeCartRepo extends CartRepo {
  _FakeCartRepo() : super(sharedPreferences: null);
  @override
  void addToCartList(List<CartModel?> cartProductList) {}
}

class _StubSplashProvider extends SplashProvider {
  _StubSplashProvider({required super.splashRepo});

  @override
  ConfigModel? get configModel => ConfigModel(
        currencySymbol: '€',
        currencySymbolPosition: 'left',
        decimalPointSettings: 2,
      );

  @override
  BaseUrls? get baseUrls => BaseUrls(
        productImageUrl: 'http://localhost/product',
        addonImageUrl: 'http://localhost/addon',
      );
}

const int _kAmericanoId = 42;

/// Americano with the two groups from the repro.
Product _americano() => Product(
      id: _kAmericanoId,
      name: 'Americano',
      image: '',
      price: 3.50,
      tax: 0,
      discount: 0,
      discountType: 'amount',
      taxType: 'amount',
      addOns: [
        AddOns(id: 17, name: 'Extra Shot', price: 0.80, tax: 0),
        AddOns(id: 18, name: 'Vanilla Syrup', price: 0.60, tax: 0),
      ],
      variations: [
        Variation(
          name: 'Size',
          min: 1,
          max: 1,
          isRequired: true,
          isMultiSelect: false,
          variationValues: [
            VariationValue(level: 'Large', optionPrice: 1.00),
            VariationValue(level: 'Small', optionPrice: 0),
          ],
        ),
        Variation(
          name: 'Milk',
          min: 1,
          max: 1,
          isRequired: true,
          isMultiSelect: false,
          variationValues: [
            VariationValue(level: 'Regular Milk', optionPrice: 0),
            VariationValue(level: 'Coconut Milk', optionPrice: 0.50),
          ],
        ),
      ],
    );

/// Americano, Large, Regular Milk, one Extra Shot — the line already on the
/// receipt when the operator taps the product again.
CartModel _largeRegularWithShot(Product product) => CartModel(
      4.30,
      4.30,
      const [],
      0,
      1,
      0,
      [AddOn(id: 17, quantity: 1)],
      product,
      [
        [true, false],
        [true, false],
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(BuildContext, CartProvider, ProductProvider)> pumpHost(
    WidgetTester tester,
    List<CartModel?> seed,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final dio = DioClient('http://localhost', null,
        loggingInterceptor: LoggingInterceptor(), sharedPreferences: prefs);

    final productProvider = ProductProvider(
        productRepo: ProductRepo(dioClient: dio, sharedPreferences: prefs));
    final cartProvider = CartProvider(cartRepo: _FakeCartRepo());
    if (seed.isNotEmpty) cartProvider.replaceCartList(seed);

    tester.view.physicalSize = const Size(1280, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    late BuildContext ctx;
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<ProductProvider>.value(value: productProvider),
        ChangeNotifierProvider<CartProvider>.value(value: cartProvider),
        ChangeNotifierProvider<SplashProvider>(
            create: (_) => _StubSplashProvider(
                splashRepo:
                    SplashRepo(dioClient: dio, sharedPreferences: prefs))),
        ChangeNotifierProvider<KioskAuthProvider>(
            create: (_) => KioskAuthProvider(
                kioskAuthRepo:
                    KioskAuthRepo(dioClient: dio, sharedPreferences: prefs))),
        ChangeNotifierProvider<CategoryProvider>(
            create: (_) => CategoryProvider(
                categoryRepo:
                    CategoryRepo(dioClient: dio, sharedPreferences: prefs))),
        ChangeNotifierProvider<CouponProvider>(
            create: (_) => CouponProvider(
                couponRepo: CouponRepo(dioClient: dio))),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        home: Builder(builder: (c) {
          ctx = c;
          return const Scaffold(body: SizedBox());
        }),
      ),
    ));
    await tester.pump();
    return (ctx, cartProvider, productProvider);
  }

  testWidgets('a product-grid tap does not seed the existing receipt line',
      (tester) async {
    final Product product = _americano();
    final (ctx, _, productProvider) =
        await pumpHost(tester, [_largeRegularWithShot(product)]);

    // This is what `pos_home_cart_screen._addToCart` does: product only.
    openPosCustomize(ctx, product);
    await tester.pump();
    await tester.pump();

    expect(productProvider.selectedVariations[0], [false, false],
        reason: 'a new tap starts with no size chosen');
    expect(productProvider.selectedVariations[1], [false, false],
        reason: 'and no milk chosen');
    expect(productProvider.addOnActiveList, [false, false],
        reason: "the receipt line's Extra Shot must not carry over");
    expect(productProvider.quantity, 1);
  });

  testWidgets('a receipt-line tap still seeds that line', (tester) async {
    final Product product = _americano();
    final CartModel line = _largeRegularWithShot(product);
    final (ctx, _, productProvider) = await pumpHost(tester, [line]);

    openPosCartLine(ctx, line, cartIndex: 0);
    await tester.pump();
    await tester.pump();

    expect(productProvider.selectedVariations[0], [true, false],
        reason: 'editing restores Large');
    expect(productProvider.selectedVariations[1], [true, false],
        reason: 'and Regular Milk');
    expect(productProvider.addOnActiveList, [true, false],
        reason: 'and the Extra Shot');
  });

  testWidgets('a plain product with no modifiers stacks instead of replacing',
      (tester) async {
    final Product mug = Product(
      id: 77,
      name: 'A/Cafe Mug',
      image: '',
      price: 12,
      tax: 0,
      discount: 0,
      discountType: 'amount',
      taxType: 'amount',
    );
    final (ctx, cartProvider, _) = await pumpHost(tester, const []);

    openPosCustomize(ctx, mug);
    await tester.pump();
    openPosCustomize(ctx, mug);
    await tester.pump();

    expect(cartProvider.cartList.length, 1);
    expect(cartProvider.cartList[0]!.quantity, 2);
  });
}
