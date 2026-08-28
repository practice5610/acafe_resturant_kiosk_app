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

/// Renders the customize screen to PNG at three viewports so the layout can be
/// compared against the Figma frame by eye, section by section, rather than
/// only by assertion.
///
/// The images are a review aid as much as a guard. After a deliberate design
/// change — or a Flutter/font upgrade that shifts glyph rendering — regenerate
/// and look at the result:
///
///   flutter test --update-goldens test/features/kiosk/customize_golden_test.dart
///
/// The product here has no artwork (no network in a widget test), so the hero
/// and the option images render as the fallback tile; everything the design
/// specifies about size, spacing and type is still exact.
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
      AddOns(id: 1, name: 'Shot of espresso', price: 1.5, tax: 0),
      AddOns(id: 2, name: 'Extra shot of matcha', price: 1.5, tax: 0),
      AddOns(id: 3, name: 'Whipped cream', price: 0.9, tax: 0),
      AddOns(id: 4, name: 'Vanilla syrup', price: 0.9, tax: 0),
      AddOns(id: 5, name: 'Hazelnut syrup', price: 0.9, tax: 0),
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
      addOnGroups: [AddOnGroup(id: 1, name: 'Add add-ons', addons: addOns)],
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

  Future<void> pumpScreen(WidgetTester tester, Size viewport) async {
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
    // A column that has to scroll fades its indicator in over ~300ms; without
    // this the shot catches it mid-fade and the image is not reproducible.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  const Map<String, Size> shots = {
    'kiosk_1080x1920': Size(1080, 1920),
    'tablet_768x1280': Size(768, 1280),
    'small_408x826': Size(408, 826),
    'landscape_1920x1080': Size(1920, 1080),
    'landscape_2560x1440': Size(2560, 1440),
  };

  shots.forEach((name, viewport) {
    testWidgets('golden $name', (tester) async {
      await pumpScreen(tester, viewport);
      await expectLater(
        find.byType(KioskProductCustomizeScreen),
        matchesGoldenFile('goldens/customize_$name.png'),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));
    });
  });
}
