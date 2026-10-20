import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/models/config_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/common/providers/product_provider.dart';
import 'package:acafe_customer/common/reposotories/product_repo.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:acafe_customer/features/cart/domain/reposotories/cart_repo.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/coupon/domain/reposotories/coupon_repo.dart';
import 'package:acafe_customer/features/coupon/providers/coupon_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_auth_repo.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_customize_sections.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/pos/domain/pos_responsive.dart';
import 'package:acafe_customer/features/pos/screens/pos_product_customize_screen.dart';
import 'package:acafe_customer/features/splash/domain/reposotories/splash_repo.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/main.dart' show navigatorKey;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The real repo keys the saved cart by the branch, which these tests have no
/// provider for. Nothing here needs the cart to survive a restart.
class _FakeCartRepo extends CartRepo {
  _FakeCartRepo() : super(sharedPreferences: null);
  @override
  void addToCartList(List<CartModel?> cartProductList) {}
}

class _StubSplashProvider extends SplashProvider {
  _StubSplashProvider({required super.splashRepo});

  @override
  ConfigModel? get configModel => ConfigModel(
        currencySymbol: '\u20AC',
        currencySymbolPosition: 'left',
        decimalPointSettings: 2,
      );

  @override
  BaseUrls? get baseUrls => BaseUrls(
        productImageUrl: 'http://localhost/product',
        addonImageUrl: 'http://localhost/addon',
      );
}

Product _buildProduct() {
  final List<AddOns> addOns = [
    AddOns(id: 1, name: 'Shot of Espresso', price: 1.5, tax: 0),
    AddOns(id: 2, name: 'Whipped Cream', price: 0.9, tax: 0),
  ];
  return Product(
    id: 42,
    name: 'Iced Strawberry Latte',
    image: '',
    price: 5,
    tax: 0,
    discount: 0,
    discountType: 'amount',
    taxType: 'amount',
    addOns: addOns,
    addOnGroups: [
      AddOnGroup(id: 1, name: 'Add add-ons', addons: addOns),
    ],
    variations: [
      Variation(
        name: 'Choose your dietary',
        min: 0,
        max: 0,
        isRequired: false,
        isMultiSelect: false,
        variationValues: [
          VariationValue(level: 'Regular', optionPrice: 0),
          VariationValue(level: 'Oat', optionPrice: 0),
          VariationValue(level: 'Coconut', optionPrice: 0),
        ],
      ),
      Variation(
        name: 'Can or cup?',
        min: 0,
        max: 0,
        isRequired: false,
        isMultiSelect: false,
        variationValues: [
          VariationValue(level: 'Cup', optionPrice: 0),
          VariationValue(level: 'Can', optionPrice: 0),
        ],
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('KioskCustomizeSections splits dietary vs cup/can', () {
    final sections = KioskCustomizeSections.of(_buildProduct());
    expect(sections.dietary, hasLength(1));
    expect(sections.cupCan, hasLength(1));
    expect(sections.size, isEmpty);
  });

  testWidgets('POS customize paints Figma sections at 1280x1024',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final dio = DioClient(
      'http://localhost',
      null,
      loggingInterceptor: LoggingInterceptor(),
      sharedPreferences: prefs,
    );
    final product = _buildProduct();
    final productProvider = ProductProvider(
        productRepo: ProductRepo(dioClient: dio, sharedPreferences: prefs))
      ..initData(product, null)
      ..initProductVariationStatus(product.variations!.length);

    tester.view.physicalSize = const Size(1280, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ProductProvider>.value(value: productProvider),
          ChangeNotifierProvider<SplashProvider>(
              create: (_) => _StubSplashProvider(
                  splashRepo:
                      SplashRepo(dioClient: dio, sharedPreferences: prefs))),
          ChangeNotifierProvider<CartProvider>(
              create: (_) =>
                  CartProvider(cartRepo: CartRepo(sharedPreferences: prefs))),
          ChangeNotifierProvider<CouponProvider>(
              create: (_) =>
                  CouponProvider(couponRepo: CouponRepo(dioClient: dio))),
          ChangeNotifierProvider<KioskAuthProvider>(
              create: (_) => KioskAuthProvider(
                  kioskAuthRepo: KioskAuthRepo(
                      dioClient: dio, sharedPreferences: prefs))),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          home: PosMetricsScope(
            metrics: PosMetrics.resolve(const Size(1280, 1024)),
            child: PosProductCustomizeScreen(product: product),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Iced Strawberry Latte'), findsOneWidget);
    expect(find.text('Choose your dietary'), findsOneWidget);
    expect(find.text('Add add-ons'), findsOneWidget);
    expect(find.text('Can or cup?'), findsOneWidget);

    // Browse-POS redesign: header gains ADD NOTE + DUPLICATE (add mode),
    // the right pane previews the pending item, and the footer is a single
    // CTA that carries the total inside its label ("ADD TO CART  •  €x").
    expect(find.text('ADD NOTE'), findsOneWidget);
    expect(find.text('DUPLICATE'), findsOneWidget);
    expect(find.text('Items that you will add:'), findsOneWidget);
    expect(find.text('Purchase Receipt'), findsNothing);
    expect(find.textContaining('•'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('DUPLICATE', () {
    late ProductProvider productProvider;
    late CartProvider cart;

    /// Pushes the screen from a launcher route, the way the POS opens it, so
    /// the screen's own pop lands somewhere.
    Future<void> openScreen(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final dio = DioClient(
        'http://localhost',
        null,
        loggingInterceptor: LoggingInterceptor(),
        sharedPreferences: prefs,
      );
      final product = _buildProduct();
      productProvider = ProductProvider(
          productRepo: ProductRepo(dioClient: dio, sharedPreferences: prefs))
        ..initData(product, null)
        ..initProductVariationStatus(product.variations!.length);
      cart = CartProvider(cartRepo: _FakeCartRepo());

      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ProductProvider>.value(
                value: productProvider),
            ChangeNotifierProvider<SplashProvider>(
                create: (_) => _StubSplashProvider(
                    splashRepo:
                        SplashRepo(dioClient: dio, sharedPreferences: prefs))),
            ChangeNotifierProvider<CartProvider>.value(value: cart),
            ChangeNotifierProvider<CouponProvider>(
                create: (_) =>
                    CouponProvider(couponRepo: CouponRepo(dioClient: dio))),
            ChangeNotifierProvider<KioskAuthProvider>(
                create: (_) => KioskAuthProvider(
                    kioskAuthRepo: KioskAuthRepo(
                        dioClient: dio, sharedPreferences: prefs))),
          ],
          child: MaterialApp(
            navigatorKey: navigatorKey,
            home: PosMetricsScope(
              metrics: PosMetrics.resolve(const Size(1280, 1024)),
              child: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PosMetricsScope(
                          metrics: PosMetrics.resolve(const Size(1280, 1024)),
                          child: PosProductCustomizeScreen(product: product),
                        ),
                      ),
                    ),
                    child: const Text('OPEN'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();
    }

    bool anyVariationPicked() => productProvider.selectedVariations
        .expand((row) => row)
        .any((picked) => picked == true);

    testWidgets('parks the item, clears only its picks, writes nothing',
        (tester) async {
      await openScreen(tester);

      await tester.tap(find.text('Oat'));
      await tester.tap(find.text('Cup'));
      await tester.tap(find.text('Whipped Cream'));
      await tester.pump();
      expect(anyVariationPicked(), isTrue);
      expect(productProvider.addOnActiveList, contains(true));

      await tester.tap(find.text('DUPLICATE'));
      await tester.pumpAndSettle();

      // Nothing reached the cart and the screen is still open.
      expect(cart.cartList, isEmpty);
      expect(find.text('DUPLICATE'), findsOneWidget);

      // The finished item is listed; the new one starts with no picks.
      expect(find.text('ITEM 1'), findsOneWidget);
      expect(find.text('ITEM 2'), findsOneWidget);
      expect(anyVariationPicked(), isFalse);
      expect(productProvider.addOnActiveList, everyElement(isFalse));
      expect(find.textContaining('(2)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ADD TO CART adds every pending item, then closes',
        (tester) async {
      await openScreen(tester);

      await tester.tap(find.text('Cup'));
      await tester.pump();
      await tester.tap(find.text('DUPLICATE'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Can'));
      await tester.pump();

      await tester.tap(find.textContaining('•'));
      await tester.pumpAndSettle();

      expect(cart.cartList, hasLength(2));
      expect(cart.cartList[0]!.variations![1], [true, false],
          reason: 'item 1 kept its Cup pick');
      expect(cart.cartList[1]!.variations![1], [false, true],
          reason: 'item 2 is the Can');
      expect(find.text('OPEN'), findsOneWidget, reason: 'screen closed');
    });

    testWidgets('identical items fold into one line of quantity 2',
        (tester) async {
      await openScreen(tester);

      await tester.tap(find.text('Cup'));
      await tester.pump();
      await tester.tap(find.text('DUPLICATE'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cup'));
      await tester.pump();
      await tester.tap(find.textContaining('•'));
      await tester.pumpAndSettle();

      expect(cart.cartList, hasLength(1));
      expect(cart.cartList.single!.quantity, 2);
    });

    testWidgets('trash on the item being edited brings the previous one back',
        (tester) async {
      await openScreen(tester);

      await tester.tap(find.text('Cup'));
      await tester.pump();
      await tester.tap(find.text('DUPLICATE'));
      await tester.pumpAndSettle();
      expect(find.text('ITEM 2'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_outline).last);
      await tester.pumpAndSettle();

      expect(find.text('ITEM 2'), findsNothing);
      expect(find.text('ITEM 1'), findsOneWidget);
      expect(productProvider.selectedVariations[1], [true, false],
          reason: 'item 1 is back in the editor with its Cup pick');
      expect(cart.cartList, isEmpty);
      expect(find.text('DUPLICATE'), findsOneWidget, reason: 'still open');
    });
  });
}
