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
import 'package:acafe_customer/features/kiosk/domain/kiosk_auth_repo.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_checkout_widgets.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_product_customize_sheet.dart';
import 'package:acafe_customer/features/splash/domain/reposotories/splash_repo.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/main.dart' show navigatorKey;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Renders the real customize screen at every viewport the brief names.
///
/// The screen's whole job is to fit the Figma page into whatever it is given,
/// so the assertions are about fitting: nothing overflows, the action bar is
/// on screen and never over the content, and the page shrinks with the viewport
/// instead of holding a size the viewport cannot carry. That last one is the
/// regression — the old screen floored its scale, so on a small window the
/// header, cards and buttons all rendered bigger than the design.
/// [PriceConverterHelper] reads the currency straight off the live
/// [SplashProvider] (via the global navigator key), and the cards read the
/// image base urls off it, so the harness has to answer both.
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Every viewport in the brief, plus the kiosk itself.
  const List<Size> viewports = [
    Size(408, 826),
    Size(480, 900),
    Size(600, 1024),
    Size(768, 1280),
    Size(900, 1500),
    Size(1024, 1600),
    Size(1080, 1920), // portrait kiosk
    Size(1286, 2700), // the artboard, halved
    Size(1440, 900), // landscape desktop window
  ];

  Product buildProduct() {
    final List<AddOns> addOns = [
      for (int i = 1; i <= 14; i++)
        AddOns(id: i, name: 'Test Addon $i', price: 0.9, tax: 0),
    ];
    return Product(
      id: 1,
      name: 'Iced Strawberry Latte',
      description:
          '<p>A cup milk with creamy ube, matcha, a touch of vanilla, and '
          'ice for a refreshing treat.</p>',
      image: '',
      price: 5,
      tax: 0,
      discount: 0,
      discountType: 'amount',
      taxType: 'amount',
      addOns: addOns,
      addOnGroups: [
        AddOnGroup(id: 1, name: 'Non Dairy', addons: addOns),
      ],
      variations: [
        Variation(
          name: 'Size',
          min: 0,
          max: 0,
          isRequired: false,
          isMultiSelect: false,
          variationValues: [
            VariationValue(level: 'Small', optionPrice: 0.02),
            VariationValue(level: 'Medium', optionPrice: 1),
            VariationValue(level: 'Large', optionPrice: 2),
          ],
        ),
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
            VariationValue(level: 'Almond', optionPrice: 0),
            VariationValue(level: 'Lactose free', optionPrice: 0),
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

  Future<void> pumpScreen(WidgetTester tester, Size viewport,
      {bool stepFlow = false}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final dio = DioClient(
      'http://localhost',
      null,
      loggingInterceptor: LoggingInterceptor(),
      sharedPreferences: prefs,
    );

    final product = buildProduct();
    final productProvider = ProductProvider(
        productRepo: ProductRepo(dioClient: dio, sharedPreferences: prefs))
      ..initData(product, null)
      ..initProductVariationStatus(product.variations!.length);

    tester.view.physicalSize = viewport;
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
          ChangeNotifierProvider<KioskAuthProvider>(
              create: (_) => KioskAuthProvider(
                  kioskAuthRepo:
                      KioskAuthRepo(dioClient: dio, sharedPreferences: prefs))),
          ChangeNotifierProvider<AuthProvider>(
              create: (_) => AuthProvider(
                  authRepo:
                      AuthRepo(dioClient: dio, sharedPreferences: prefs))),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          home: stepFlow
              ? KioskProductCustomizeStepScreen(product: product)
              : KioskProductCustomizeScreen(product: product),
        ),
      ),
    );
    await tester.pump();
  }

  /// The screen queues an analytics event on its first frame and another when
  /// it is unmounted, each flushed on a 5s timer. Unmount inside the test and
  /// let that timer fire, or the binding fails on "a Timer is still pending".
  Future<void> closeScreen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  }

  for (final viewport in viewports) {
    testWidgets(
        'lays out with no overflow at ${viewport.width.toInt()}x${viewport.height.toInt()}',
        (tester) async {
      await pumpScreen(tester, viewport);

      // A RenderFlex overflow reports through the exception channel, which is
      // exactly the failure the old pinned layout produced on a short viewport.
      expect(tester.takeException(), isNull);

      // Every question the customer has to answer is on screen or reachable.
      // Titles that come from the product data — the two translated ones
      // ('size', 'add_add_ons') echo their key without a localization delegate.
      expect(find.text('Iced Strawberry Latte'), findsOneWidget);
      expect(find.text('Choose your dietary'), findsOneWidget);
      expect(find.text('Can or cup?'), findsOneWidget);
      expect(find.text('CUP'), findsOneWidget);
      expect(find.text('CAN'), findsOneWidget);

      await closeScreen(tester);
    });

    testWidgets(
        'the action bar sits inside the viewport at '
        '${viewport.width.toInt()}x${viewport.height.toInt()}', (tester) async {
      await pumpScreen(tester, viewport);

      final Finder cancel = find.byType(KioskCheckoutButton).first;
      expect(cancel, findsOneWidget);
      final Rect bar = tester.getRect(cancel);
      expect(bar.bottom, lessThanOrEqualTo(viewport.height + 0.5),
          reason: 'the bar must never fall off the bottom of the screen');
      expect(bar.top, greaterThan(viewport.height * 0.5),
          reason: 'the bar is pinned to the bottom, not floating mid-page');

      await closeScreen(tester);
    });
  }

  testWidgets('the page shrinks with the viewport instead of holding a size',
      (tester) async {
    double titleHeight(WidgetTester tester) =>
        tester.getSize(find.text('Iced Strawberry Latte')).height;

    await pumpScreen(tester, const Size(1080, 1920));
    final double large = titleHeight(tester);

    await pumpScreen(tester, const Size(600, 1024));
    final double medium = titleHeight(tester);

    await pumpScreen(tester, const Size(408, 826));
    final double small = titleHeight(tester);

    // The old screen clamped its scale, so these three came out identical and
    // the small window looked enormous.
    expect(medium, lessThan(large));
    expect(small, lessThan(medium));

    await closeScreen(tester);
  });

  testWidgets('the header never eats more than the design\'s share of height',
      (tester) async {
    // Figma spends 1291 of 5400 on the header — under a quarter of the page.
    // The old compact header existed because the real one blew past that.
    for (final viewport in viewports) {
      await pumpScreen(tester, viewport);
      final Rect stepper = tester.getRect(find.text('1'));
      expect(stepper.bottom, lessThan(viewport.height * 0.45),
          reason: 'header runs to ${stepper.bottom} of ${viewport.height} '
              'at ${viewport.width}x${viewport.height}');
    }

    await closeScreen(tester);
  });

  // Version B (the three-step flow) is a `part` of the same library and reuses
  // every section widget above, so it inherits the same scale rule and has to
  // fit the same way — with a progress bar taking height the header used to.
  testWidgets('the three-step flow lays out at every viewport too',
      (tester) async {
    for (final viewport in viewports) {
      await pumpScreen(tester, viewport, stepFlow: true);
      expect(tester.takeException(), isNull,
          reason: 'version B overflowed at '
              '${viewport.width}x${viewport.height}');
      expect(find.text('Iced Strawberry Latte'), findsOneWidget);
    }

    await closeScreen(tester);
  });
}
