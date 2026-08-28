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
import 'package:acafe_customer/features/kiosk/domain/kiosk_customize_spec.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_checkout_widgets.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_ui.dart';
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
    Size(1024, 768), // landscape tablet
    Size(1366, 768), // small laptop
    Size(1440, 900), // landscape desktop window
    Size(1512, 905), // MacBook Pro 14" browser window, chrome deducted
    Size(1920, 1080),
    Size(2560, 1440), // large landscape display
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
      {bool stepFlow = false, Product? product}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final dio = DioClient(
      'http://localhost',
      null,
      loggingInterceptor: LoggingInterceptor(),
      sharedPreferences: prefs,
    );

    product ??= buildProduct();
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
    //
    // That proportion is a PORTRAIT one: it describes the header's share of a
    // page the panels sit below. Landscape puts them side by side, so the
    // header column is meant to run most of the way down; what matters there
    // is only that it stops above the action bar, which is asserted instead.
    for (final viewport in viewports) {
      await pumpScreen(tester, viewport);
      final Rect stepper = tester.getRect(find.text('1'));
      if (viewport.width > viewport.height) {
        final Rect bar = tester.getRect(find.byType(KioskCheckoutButton).first);
        expect(stepper.bottom, lessThanOrEqualTo(bar.top),
            reason: 'header runs to ${stepper.bottom}, over a bar at '
                '${bar.top} at ${viewport.width}x${viewport.height}');
      } else {
        expect(stepper.bottom, lessThan(viewport.height * 0.45),
            reason: 'header runs to ${stepper.bottom} of ${viewport.height} '
                'at ${viewport.width}x${viewport.height}');
      }
    }

    await closeScreen(tester);
  });

  // The bug this pins: on a landscape window the header and the panels are two
  // COLUMNS, and the page height rule used to report a flat fraction of the two
  // STACKED. For a product whose only question is a Size row that fraction came
  // out smaller than the header alone needs, the scale was chosen too large,
  // and the hero/name/stepper block overflowed the bottom of its column —
  // painting the quantity stepper across the Cancel Item button.
  testWidgets('a one-question product fits a short landscape window',
      (tester) async {
    Product sizeOnly() {
      final Product full = buildProduct();
      return Product(
        id: full.id,
        name: 'New Test Live',
        description: full.description,
        image: '',
        price: full.price,
        tax: 0,
        discount: 0,
        discountType: 'amount',
        taxType: 'amount',
        addOns: full.addOns,
        addOnGroups: full.addOnGroups,
        // Size and cup/can only: no dietary groups, so the panel column beside
        // the header is a single short panel.
        variations: [full.variations!.first, full.variations!.last],
      );
    }

    for (final bool stepFlow in [false, true]) {
      for (final Size viewport in [
        const Size(1512, 905),
        const Size(1512, 820),
        const Size(1440, 900),
      ]) {
        await pumpScreen(tester, viewport,
            stepFlow: stepFlow, product: sizeOnly());
        expect(tester.takeException(), isNull,
            reason: 'version ${stepFlow ? 'B' : 'A'} overflowed at '
                '${viewport.width}x${viewport.height}');
      }
    }

    await closeScreen(tester);
  });

  // Landscape draws the header and the panels as two columns and the page is
  // scaled by WIDTH there, so both columns come up short and the leftover
  // height used to collect in one dead block at the bottom. They centre now,
  // which only reads right if the back button stays where the artboard puts
  // it: a button pinned inside the header would ride down to the middle of
  // the page with it.
  testWidgets('the landscape back button stays in the page\'s top corner',
      (tester) async {
    for (final Size viewport in [
      const Size(1366, 768),
      const Size(1512, 905),
      const Size(2560, 1440),
    ]) {
      await pumpScreen(tester, viewport);
      final Rect back = tester.getRect(find.byType(KioskBackButton).first);
      expect(back.top, lessThan(viewport.height * 0.2),
          reason: 'back button at ${back.top} of ${viewport.height} '
              'at ${viewport.width}x${viewport.height}');
      expect(back.left, lessThan(viewport.width * 0.15));
    }

    await closeScreen(tester);
  });

  // A question with fewer answers than the row has slots — three sizes in a
  // seven-across kiosk panel — used to hang off the panel's left edge and read
  // as a row that had failed to load.
  testWidgets('an option row that does not fill the panel is centred',
      (tester) async {
    for (final Size viewport in [
      const Size(1080, 1920),
      const Size(1512, 905),
      const Size(2560, 1440),
    ]) {
      await pumpScreen(tester, viewport);
      final Rect small = tester.getRect(find.text('SMALL'));
      final Rect large = tester.getRect(find.text('LARGE'));
      // The panel's own box: the row is centred in it, so the row's centre
      // and the panel's centre have to land together.
      final Rect panel = tester.getRect(
          find.ancestor(of: find.text('SMALL'), matching: find.byType(Container))
              .last);
      final double rowCentre = (small.left + large.right) / 2;
      expect((rowCentre - panel.center.dx).abs(),
          lessThan(viewport.width * 0.05),
          reason: 'row centred at $rowCentre, panel at ${panel.center.dx} '
              'at ${viewport.width}x${viewport.height}');
    }

    await closeScreen(tester);
  });

  // The add-ons step used to FILL its column: the panel stretched the whole
  // height of the screen and its inner scroller then cut a row of cards in
  // half at the fold. It is told the height it may take now, keeps the whole
  // rows that fit, and hands the rest back to be centred — so the panel is
  // compact, has air above and below it, and scrolls inside itself.
  testWidgets('the add-ons panel keeps whole rows and its own indicator',
      (tester) async {
    // Add-ons only, so the flow opens straight on the step under test rather
    // than having to be driven through Size first.
    Product addOnsOnly() {
      final Product full = buildProduct();
      return Product(
        id: full.id,
        name: full.name,
        description: full.description,
        image: '',
        price: full.price,
        tax: 0,
        discount: 0,
        discountType: 'amount',
        taxType: 'amount',
        addOns: full.addOns,
        addOnGroups: full.addOnGroups,
        variations: const [],
      );
    }

    for (final Size viewport in [
      const Size(1512, 905),
      const Size(1920, 1080),
      const Size(2560, 1440),
      const Size(1080, 1920),
    ]) {
      await pumpScreen(tester, viewport,
          stepFlow: true, product: addOnsOnly());
      // Single group -> the panel takes the group's own name.
      expect(find.text('Non Dairy'), findsOneWidget,
          reason: 'the add-ons step is the whole flow for this product');

      final Rect panel = tester.getRect(find
          .ancestor(of: find.text('Non Dairy'), matching: find.byType(Container))
          .first);
      final Rect bar = tester.getRect(find.byType(KioskCheckoutButton).first);
      final Rect back = tester.getRect(find.byType(KioskBackButton).first);

      // Air on both sides of it: the panel is centred in its column, not
      // stretched to the full height of the screen.
      expect(panel.top, greaterThan(back.bottom),
          reason: 'the panel starts below the progress bar, not against it, '
              'at ${viewport.width}x${viewport.height}');
      expect(bar.top - panel.bottom, greaterThan(8),
          reason: 'the panel ran to ${panel.bottom}, against a bar at '
              '${bar.top} at ${viewport.width}x${viewport.height}');

      // Whole rows: the card area is an exact number of card pitches tall, so
      // the fold can never land through the middle of a row.
      final Rect first = tester.getRect(find.text('TEST ADDON 1'));
      final ScrollableState grid = tester.state(find
          .descendant(of: find.byType(RawScrollbar), matching: find.byType(Scrollable))
          .last);
      final Rect card = tester.getRect(find
          .ancestor(of: find.text('TEST ADDON 1'), matching: find.byType(Container))
          .first);
      final double gap = KioskCustomizeSpec.choiceCardGap *
          (card.width / KioskCustomizeSpec.choiceCardWidth);
      final double pitch = card.height + gap;
      final double rows = (grid.position.viewportDimension + gap) / pitch;
      expect((rows - rows.roundToDouble()).abs(), lessThan(0.05),
          reason: 'the card area is $rows rows tall at '
              '${viewport.width}x${viewport.height} — a fraction of a row '
              'means the fold cuts one in half');
      expect(first.top, greaterThan(panel.top),
          reason: 'the first row sits inside the panel');
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
