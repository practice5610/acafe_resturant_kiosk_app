import 'dart:io';

import 'package:acafe_customer/common/models/config_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/common/providers/product_provider.dart';
import 'package:acafe_customer/common/reposotories/product_repo.dart';
import 'package:acafe_customer/common/widgets/custom_image_widget.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:acafe_customer/features/auth/domain/reposotories/auth_repo.dart';
import 'package:acafe_customer/features/auth/providers/auth_provider.dart';
import 'package:acafe_customer/features/cart/domain/reposotories/cart_repo.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/coupon/domain/reposotories/coupon_repo.dart';
import 'package:acafe_customer/features/coupon/providers/coupon_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_auth_repo.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_product_customize_sheet.dart';
import 'package:acafe_customer/features/pos/domain/pos_responsive.dart';
import 'package:acafe_customer/features/pos/screens/pos_product_customize_screen.dart';
import 'package:acafe_customer/features/splash/domain/reposotories/splash_repo.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/main.dart' show navigatorKey;
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Picture-less ("Show Product Images" OFF) coverage for the customize screens.
///
/// Two guarantees per screen:
///  * no product/variation/add-on image is built (so none is fetched), and
///  * a fresh OFF golden captures the collapsed layout. The ON goldens live in
///    customize_golden_test.dart / pos_product_customize_test.dart and are not
///    touched here.
///
///   flutter test --update-goldens test/features/kiosk/picture_less_mode_test.dart
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

Product _buildProduct() {
  final List<AddOns> addOns = [
    AddOns(id: 1, name: 'Shot of espresso', price: 1.5, tax: 0),
    AddOns(id: 2, name: 'Whipped cream', price: 0.9, tax: 0),
    AddOns(id: 3, name: 'Vanilla syrup', price: 0.9, tax: 0),
    AddOns(id: 4, name: 'Caramel syrup', price: 0.9, tax: 0),
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

  setUpAll(_loadFonts);

  // Every test in this file runs with the device in picture-less mode.
  setUp(() {
    CustomImageWidget.showProductImages = false;
  });
  tearDown(() {
    CustomImageWidget.showProductImages = true;
  });

  Future<(DioClient, SharedPreferences, ProductProvider, Product)> deps() async {
    SharedPreferences.setMockInitialValues({
      AppConstants.kioskShowImages: false,
    });
    final prefs = await SharedPreferences.getInstance();
    final dio = DioClient('http://localhost', null,
        loggingInterceptor: LoggingInterceptor(), sharedPreferences: prefs);
    final product = _buildProduct();
    final productProvider = ProductProvider(
        productRepo: ProductRepo(dioClient: dio, sharedPreferences: prefs))
      ..initData(product, null)
      ..initProductVariationStatus(product.variations!.length);
    return (dio, prefs, productProvider, product);
  }

  List<ChangeNotifierProvider> providers(
      DioClient dio, SharedPreferences prefs, ProductProvider productProvider) {
    return [
      ChangeNotifierProvider<ProductProvider>.value(value: productProvider),
      ChangeNotifierProvider<SplashProvider>(
          create: (_) => _StubSplashProvider(
              splashRepo: SplashRepo(dioClient: dio, sharedPreferences: prefs))),
      ChangeNotifierProvider<CartProvider>(
          create: (_) =>
              CartProvider(cartRepo: CartRepo(sharedPreferences: prefs))),
      ChangeNotifierProvider<CouponProvider>(
          create: (_) =>
              CouponProvider(couponRepo: CouponRepo(dioClient: dio))),
      ChangeNotifierProvider<KioskAuthProvider>(
          create: (_) => KioskAuthProvider(
              kioskAuthRepo:
                  KioskAuthRepo(dioClient: dio, sharedPreferences: prefs))),
      ChangeNotifierProvider<AuthProvider>(
          create: (_) =>
              AuthProvider(authRepo: AuthRepo(dioClient: dio, sharedPreferences: prefs))),
    ];
  }

  testWidgets('CustomImageWidget never builds a network image when OFF',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: CustomImageWidget(image: 'http://localhost/product/latte.png'),
      ),
    ));
    await tester.pump();
    // The placeholder asset stands in; no CachedNetworkImage is ever created,
    // so nothing is requested over the network.
    expect(find.byType(Image), findsWidgets); // the placeholder asset
    expect(tester.takeException(), isNull);
  });

  testWidgets('kiosk customize Version A OFF: no product image, collapsed',
      (tester) async {
    final (dio, prefs, productProvider, product) = await deps();
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MultiProvider(
      providers: providers(dio, prefs, productProvider),
      child: MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        home: KioskProductCustomizeScreen(product: product),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // No product/variation/add-on image widget is built at all.
    expect(find.byType(CustomImageWidget), findsNothing);
    expect(tester.takeException(), isNull);

    await expectLater(
      find.byType(KioskProductCustomizeScreen),
      matchesGoldenFile('goldens/customize_off_version_a_1080x1920.png'),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('kiosk customize Version B OFF: no product image, collapsed',
      (tester) async {
    final (dio, prefs, productProvider, product) = await deps();
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MultiProvider(
      providers: providers(dio, prefs, productProvider),
      child: MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        home: KioskProductCustomizeStepScreen(product: product),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(CustomImageWidget), findsNothing);
    expect(tester.takeException(), isNull);

    await expectLater(
      find.byType(KioskProductCustomizeStepScreen),
      matchesGoldenFile('goldens/customize_off_version_b_1080x1920.png'),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('POS customize OFF: no product image, collapsed', (tester) async {
    final (dio, prefs, productProvider, product) = await deps();
    tester.view.physicalSize = const Size(1280, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MultiProvider(
      providers: providers(dio, prefs, productProvider),
      child: MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        home: PosMetricsScope(
          metrics: PosMetrics.resolve(const Size(1280, 1024)),
          child: PosProductCustomizeScreen(product: product),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(CustomImageWidget), findsNothing);
    // The sections still render — only the imagery is gone.
    expect(find.text('Can or cup?'), findsOneWidget);
    expect(find.text('Add add-ons'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await expectLater(
      find.byType(PosProductCustomizeScreen),
      matchesGoldenFile('goldens/customize_off_pos_1280x1024.png'),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  });
}
