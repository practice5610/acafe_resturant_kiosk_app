// D1 — a new product tap opens a BLANK configuration.
//
// `openKioskCustomize` used to scan the cart by `product.id`, and on a hit it
// seeded the customize screen with that line's picks and set `cartIndex`, so
// saving overwrote the line instead of adding a second one. Everything
// downstream was already configuration-aware; this entry point was the reason a
// product could only ever hold one cart line.
//
// These tests go through the real entry point rather than the provider, because
// the bug lived in the seeding decision, not in the cart.

import 'dart:io';

import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/models/config_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/common/providers/product_provider.dart';
import 'package:acafe_customer/common/reposotories/product_repo.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:acafe_customer/features/auth/domain/reposotories/auth_repo.dart';
import 'package:acafe_customer/features/auth/providers/auth_provider.dart';
import 'package:acafe_customer/features/cart/domain/reposotories/cart_repo.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/category/domain/reposotories/category_repo.dart';
import 'package:acafe_customer/features/category/providers/category_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_auth_repo.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_product_customize_sheet.dart';
import 'package:acafe_customer/features/splash/domain/reposotories/splash_repo.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/main.dart' show navigatorKey;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The real [CartRepo] resolves its storage key through a `BranchProvider`,
/// which this test has no reason to stand up — the entry point's seeding
/// decision is what is under test, not persistence.
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_loadFonts);

  Product americano() => Product(
        id: 42,
        name: 'Americano',
        price: 3.50,
        tax: 0,
        taxType: 'amount',
        discount: 0,
        discountType: 'amount',
        image: '',
        addOns: [
          AddOns(id: 17, name: 'Extra Shot', price: 0.80, tax: 0),
          AddOns(id: 18, name: 'Vanilla Syrup', price: 0.60, tax: 0),
        ],
        variations: [
          Variation(
            name: 'Milk',
            min: 0,
            max: 0,
            isRequired: false,
            isMultiSelect: false,
            variationValues: [
              VariationValue(level: 'Regular Milk', optionPrice: 0),
              VariationValue(level: 'Coconut Milk', optionPrice: 0.50),
            ],
          ),
        ],
      );

  /// A cart line for [product] with coconut milk and a shot already chosen.
  CartModel coconutWithShot(Product product) => CartModel(
        4.30,
        4.30,
        const [],
        0,
        1,
        0,
        [AddOn(id: 17, quantity: 1)],
        product,
        [
          [false, true],
        ],
      );

  /// Pumps a host with the kiosk providers and hands back the context to open
  /// the customize screen from, plus the two providers under test.
  Future<(BuildContext, CartProvider, ProductProvider)> pumpHost(
    WidgetTester tester,
    Product product,
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

    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    late BuildContext ctx;
    await tester.pumpWidget(
      MultiProvider(
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
          ChangeNotifierProvider<AuthProvider>(
              create: (_) => AuthProvider(
                  authRepo:
                      AuthRepo(dioClient: dio, sharedPreferences: prefs))),
          ChangeNotifierProvider<CategoryProvider>(
              create: (_) => CategoryProvider(
                  categoryRepo: CategoryRepo(
                      dioClient: dio, sharedPreferences: prefs))),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          home: Builder(builder: (c) {
            ctx = c;
            return const Scaffold(body: SizedBox());
          }),
        ),
      ),
    );
    await tester.pump();
    return (ctx, cartProvider, productProvider);
  }

  /// The customize screen queues analytics on a 5s timer; unmount and let it
  /// fire or the binding complains about a pending Timer.
  Future<void> closeScreen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  }

  testWidgets('a new tap on an in-cart product does not seed the cart line',
      (tester) async {
    final Product product = americano();
    final (ctx, _, productProvider) =
        await pumpHost(tester, product, [coconutWithShot(product)]);

    openKioskCustomize(ctx, product);
    await tester.pump();
    await tester.pump();

    // Blank: no milk chosen, no add-on switched on. The cart line's coconut
    // milk and Extra Shot must not have leaked into this screen.
    expect(productProvider.selectedVariations[0], [false, false],
        reason: 'a new tap starts from no milk chosen');
    expect(productProvider.addOnActiveList, [false, false],
        reason: "the existing line's Extra Shot must not carry over");
    expect(productProvider.quantity, 1);

    await closeScreen(tester);
  });

  testWidgets('reopening a line for editing still seeds it', (tester) async {
    final Product product = americano();
    final CartModel line = coconutWithShot(product);
    final (ctx, _, productProvider) = await pumpHost(tester, product, [line]);

    // This is what `openKioskCartLine` does: hand over the line AND its index.
    openKioskCustomize(ctx, product, cart: line, cartIndex: 0);
    await tester.pump();
    await tester.pump();

    expect(productProvider.selectedVariations[0], [false, true],
        reason: 'an edit restores the coconut milk that line holds');
    expect(productProvider.addOnActiveList, [true, false],
        reason: 'and its Extra Shot');

    await closeScreen(tester);
  });

  testWidgets('a plain product with nothing to configure still stacks',
      (tester) async {
    // The no-modifier shortcut was left alone: it hands `addToCart` the always
    // -1 `productProvider.cartIndex`, so the signature matcher decides.
    final Product mug = Product(
      id: 77,
      name: 'A/Cafe Mug',
      price: 12,
      tax: 0,
      taxType: 'amount',
      discount: 0,
      discountType: 'amount',
      image: '',
    );
    final (ctx, cartProvider, _) = await pumpHost(tester, mug, const []);

    openKioskCustomize(ctx, mug);
    await tester.pump();
    openKioskCustomize(ctx, mug);
    await tester.pump();

    expect(cartProvider.cartList.length, 1,
        reason: 'identical plain lines stack rather than duplicating');
    expect(cartProvider.cartList[0]!.quantity, 2);
  });
}
