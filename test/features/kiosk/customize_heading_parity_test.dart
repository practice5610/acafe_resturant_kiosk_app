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
import 'package:acafe_customer/features/kiosk/screens/kiosk_product_customize_sheet.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_allergen_notice.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_tap.dart';
import 'package:acafe_customer/features/splash/domain/reposotories/splash_repo.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/main.dart' show navigatorKey;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/kiosk_layout_harness.dart';

/// The CUP / CAN word must read as the same kind of label as the section
/// headings above it.
///
/// It used to be sized from the vessel CARD's width and set in Bold, while the
/// headings are sized from the page scale and set in ExtraBold. Those two
/// numbers track different things, so on the 1080x1920 kiosk — where height
/// pulls the page scale below the width scale — the vessel word rendered
/// LARGER than the "Size" and "Add add-ons" headings it sits under.
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

/// The Size panel's title comes from `getTranslated('size', ...)`, which echoes
/// the KEY back when no localization delegate is installed — and these tests
/// deliberately install none (see the coupon/language-sheet convention). So the
/// heading on screen is the lowercase key, not 'Size'.
const String _kSizeHeading = 'size';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadKioskTestFonts);

  Product buildProduct({bool withAllergen = true}) {
    final List<AddOns> addOns = [
      for (int i = 1; i <= 14; i++)
        AddOns(id: i, name: 'Test Addon $i', price: 0.9, tax: 0),
    ];
    return Product(
      id: 1,
      name: 'Iced Strawberry Latte',
      description: '<p>A refreshing treat.</p>',
      image: '',
      price: 5,
      tax: 0,
      discount: 0,
      discountType: 'amount',
      taxType: 'amount',
      addOns: addOns,
      addOnGroups: [AddOnGroup(id: 1, name: 'Non Dairy', addons: addOns)],
      tags: withAllergen
          ? [ProductTag(tag: 'Nuts', isAllergen: true, isKioskFilter: false)]
          : const <ProductTag>[],
      variations: [
        Variation(
          name: 'Size',
          min: 0,
          max: 0,
          isRequired: false,
          isMultiSelect: false,
          variationValues: [
            VariationValue(level: 'Small', optionPrice: 0.02),
            VariationValue(level: 'Large', optionPrice: 2),
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
      {bool withAllergen = true}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final dio = DioClient(
      'http://localhost',
      null,
      loggingInterceptor: LoggingInterceptor(),
      sharedPreferences: prefs,
    );

    final product = buildProduct(withAllergen: withAllergen);
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
          home: KioskProductCustomizeScreen(product: product),
        ),
      ),
    );
    await tester.pump();
  }

  /// The screen queues analytics on a 5s timer; unmount and let it fire.
  Future<void> closeScreen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  }

  TextStyle styleOf(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).style!;

  for (final Size viewport in const [
    Size(1080, 1920), // production kiosk — where the drift was worst
    Size(2160, 3840),
    Size(1440, 900),
    Size(768, 1280),
  ]) {
    testWidgets(
        'CUP matches the section headings at '
        '${viewport.width.toInt()}x${viewport.height.toInt()}', (tester) async {
      await pumpScreen(tester, viewport);

      final TextStyle size = styleOf(tester, _kSizeHeading);
      final TextStyle vessel = styleOf(tester, 'CUP');

      expect(
        vessel.fontSize,
        closeTo(size.fontSize!, 0.01),
        reason: 'CUP is ${vessel.fontSize} but the Size heading is '
            '${size.fontSize}',
      );
      expect(vessel.fontWeight, size.fontWeight);
      expect(vessel.fontFamily, size.fontFamily);

      await closeScreen(tester);
    });
  }

  testWidgets('all three headings share one size and weight', (tester) async {
    await pumpScreen(tester, const Size(1080, 1920));

    final TextStyle size = styleOf(tester, _kSizeHeading);
    final TextStyle addOns = styleOf(tester, 'Non Dairy');
    final TextStyle cup = styleOf(tester, 'CUP');
    final TextStyle can = styleOf(tester, 'CAN');

    for (final TextStyle other in [addOns, cup, can]) {
      expect(other.fontSize, closeTo(size.fontSize!, 0.01));
      expect(other.fontWeight, size.fontWeight);
    }

    await closeScreen(tester);
  });

  testWidgets('the allergen strip sits ABOVE the Size heading', (tester) async {
    // The placement requirement: the disclosure is read before any choice is
    // made, not after. Asserted on geometry rather than widget order, because
    // the screen has three different layout branches.
    await pumpScreen(tester, const Size(1080, 1920));

    final double strip = tester.getTopLeft(find.text('CONTAINS')).dy;
    final double sizeHeading = tester.getTopLeft(find.text(_kSizeHeading)).dy;

    expect(strip, lessThan(sizeHeading),
        reason: 'allergen strip at $strip is not above Size at $sizeHeading');

    await closeScreen(tester);
  });

  testWidgets('the strip is left-aligned, not stretched across the column',
      (tester) async {
    await pumpScreen(tester, const Size(1080, 1920));

    // The widget itself is an Align that fills the column; the PILL is its
    // tappable child, and that is what has to hug the left edge.
    final Rect area = tester.getRect(find.byType(KioskAllergenNotice));
    final Rect pill = tester.getRect(find.descendant(
      of: find.byType(KioskAllergenNotice),
      matching: find.byType(KioskTap),
    ));

    // Flush to the column's left edge, not centred in it.
    expect(pill.left, closeTo(area.left, 1.0));
    // And a badge, not a banner: it stops well short of the full column.
    expect(pill.width, lessThan(area.width * 0.9),
        reason: 'pill is ${pill.width} of a ${area.width} column');

    await closeScreen(tester);
  });

  testWidgets('a product with no allergens shows no strip', (tester) async {
    await pumpScreen(tester, const Size(1080, 1920), withAllergen: false);

    expect(find.byType(KioskAllergenNotice), findsNothing);
    expect(find.text('CONTAINS'), findsNothing);
    expect(find.text(_kSizeHeading), findsOneWidget);

    await closeScreen(tester);
  });

  testWidgets('the vessel word is not clipped by the cap', (tester) async {
    // The size is capped against the card width so a narrow card ellipsizes.
    // On the real kiosk that cap must not be what binds, or CUP renders
    // smaller than the headings after all.
    await pumpScreen(tester, const Size(1080, 1920));

    expect(find.text('CUP'), findsOneWidget);
    expect(find.text('CAN'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await closeScreen(tester);
  });
}
