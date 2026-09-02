import 'dart:io';

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
import 'package:acafe_customer/features/splash/domain/reposotories/splash_repo.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/main.dart' show navigatorKey;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How a DEFAULT add-on presents itself on the kiosk customize screen: tan
/// ground, tan outline, a tick over the artwork and the word *Included* where a
/// surcharge would otherwise sit — matching the customer web app exactly.
///
/// The point of asserting it here rather than only in a golden is that the
/// golden cannot say WHY it changed. These say it: the card is marked, it is
/// not priced, and it cannot be turned off.
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

  Product buildProduct() {
    final List<AddOns> addOns = [
      AddOns(id: 1, name: 'Banana puree', price: 0, tax: 0, isDefault: true),
      AddOns(id: 2, name: 'Blueberry', price: 0, tax: 0, isDefault: true),
      AddOns(id: 3, name: 'Caramel syrup', price: 0, tax: 0, isDefault: true),
      AddOns(id: 4, name: 'Extra mango', price: 0, tax: 0, isDefault: true),
      AddOns(id: 5, name: 'Extra strawberry', price: 0, tax: 0, isDefault: true),
      AddOns(id: 6, name: 'Caramel syrup', price: 0.9, tax: 0),
      AddOns(id: 7, name: 'Extra banana puree', price: 0.9, tax: 0),
      AddOns(id: 8, name: 'Extra blueberry', price: 0.9, tax: 0),
      AddOns(id: 9, name: 'Extra strawberry', price: 0.9, tax: 0),
      AddOns(id: 10, name: 'Sugar free vanilla syrup', price: 0.9, tax: 0),
      AddOns(id: 11, name: 'Extra mango', price: 0.9, tax: 0),
      AddOns(id: 12, name: 'Sugar free caramel syrup', price: 0.9, tax: 0),
    ];
    return Product(
      id: 1,
      name: 'Iced Strawberry Latte',
      description: '<p>A cup milk with creamy ube, matcha, a touch of '
          'vanilla, and ice for a refreshing treat.</p>',
      image: '',
      price: 5,
      tax: 0,
      discount: 0,
      discountType: 'amount',
      taxType: 'amount',
      addOns: addOns,
      addOnGroups: [AddOnGroup(
        id: 1,
        name: 'Add add-ons',
        // Single on purpose: Elad's rule is that single-choice applies to the
        // NON-default remainder, so this is the arrangement that can actually
        // break — a naive implementation clears the whole group on each pick.
        selectionType: 'single',
        addons: addOns,
      )],
      variations: [
        Variation(
          name: 'Size',
          min: 0,
          max: 0,
          isRequired: false,
          isMultiSelect: false,
          variationValues: [
            VariationValue(level: 'Small', optionPrice: 0),
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

  Future<ProductProvider> pumpScreen(WidgetTester tester, Size viewport) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final dio = DioClient('http://localhost', null,
        loggingInterceptor: LoggingInterceptor(), sharedPreferences: prefs);

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
          debugShowCheckedModeBanner: false,
          home: KioskProductCustomizeScreen(product: product),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return productProvider;
  }

  /// The screen queues an analytics event on its first frame and another when
  /// it is unmounted, each flushed on a 5s timer. Unmount inside the test and
  /// let that timer fire, or the binding fails on "a Timer is still pending".
  Future<void> closeScreen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  }

  /// The five defaults in the fixture, and one that is merely free-and-optional.
  const defaults = ['BANANA PUREE', 'BLUEBERRY', 'CARAMEL SYRUP',
    'EXTRA MANGO', 'EXTRA STRAWBERRY'];

  testWidgets('an included add-on says so instead of showing a price',
      (tester) async {
    await pumpScreen(tester, const Size(1080, 1920));

    // One per default add-on — never on a card the customer has to pay for.
    expect(find.text('Included'), findsNWidgets(defaults.length));
    await closeScreen(tester);
  });

  testWidgets('an included add-on is ticked, a payable one is not',
      (tester) async {
    await pumpScreen(tester, const Size(1080, 1920));

    expect(find.byIcon(Icons.check_rounded), findsNWidgets(defaults.length),
        reason: 'the tick marks exactly the add-ons that come with the product');
    await closeScreen(tester);
  });

  testWidgets('included cards sit on the tan ground, payable ones on cream',
      (tester) async {
    await pumpScreen(tester, const Size(1080, 1920));

    /// The card's own Material — the innermost one wrapping a label.
    Color? groundUnder(Finder label) => tester
        .widget<Material>(
            find.ancestor(of: label, matching: find.byType(Material)).first)
        .color;

    final Color? included = groundUnder(find.text('Included').first);
    final Color? payable = groundUnder(find.text('CARAMEL SYRUP').last);

    // The tan wash is what separates "comes with it" from "you pay for it" at a
    // glance, before any text is read.
    expect(included, isNot(payable),
        reason: 'an included card must not share the payable cards\' ground');
    expect(payable, const Color(0xFFFBF8EF),
        reason: 'a payable card keeps the panel cream');
    expect(included!.a, 1.0,
        reason: 'the tint is blended opaque, so nothing shows through it');
    // Warmer and darker than the cream it is mixed into — a tan wash, not a
    // grey one.
    expect(included.r, greaterThan(included.b));
    expect(included.b, lessThan(const Color(0xFFFBF8EF).b));
    await closeScreen(tester);
  });

  /// Which add-ons are selected right now.
  List<int> selectedIndexes(ProductProvider p) => [
        for (int i = 0; i < p.addOnActiveList.length; i++)
          if (p.addOnActiveList[i]) i,
      ];

  testWidgets('defaults are on before the customer touches anything',
      (tester) async {
    final provider = await pumpScreen(tester, const Size(1080, 1920));
    expect(selectedIndexes(provider), [0, 1, 2, 3, 4]);
    await closeScreen(tester);
  });

  testWidgets('picking one extra keeps all five defaults — 5 + 1, never 1',
      (tester) async {
    final provider = await pumpScreen(tester, const Size(1080, 1920));

    // In a single-choice group a naive toggle clears every sibling, which would
    // take the five locked defaults down with it.
    await tester.tap(find.text('CARAMEL SYRUP').last);
    await tester.pump();

    expect(selectedIndexes(provider), [0, 1, 2, 3, 4, 5],
        reason: 'single choice applies to the payable remainder only');
    await closeScreen(tester);
  });

  testWidgets('a second pick swaps the extra and leaves the defaults alone',
      (tester) async {
    final provider = await pumpScreen(tester, const Size(1080, 1920));

    await tester.tap(find.text('CARAMEL SYRUP').last);
    await tester.pump();
    await tester.tap(find.text('EXTRA BLUEBERRY'));
    await tester.pump();

    expect(selectedIndexes(provider), [0, 1, 2, 3, 4, 7],
        reason: 'the extra is replaced; the defaults are not part of the swap');
    await closeScreen(tester);
  });

  testWidgets('tapping an included add-on changes nothing at all',
      (tester) async {
    final provider = await pumpScreen(tester, const Size(1080, 1920));
    await tester.tap(find.text('CARAMEL SYRUP').last);
    await tester.pump();
    final before = selectedIndexes(provider);

    await tester.tap(find.text(defaults.first));
    await tester.pump();

    expect(selectedIndexes(provider), before,
        reason: 'it comes with the product — the tap must not deselect it, '
            'and must not count as the group\'s one pick either');
    await closeScreen(tester);
  });
}
