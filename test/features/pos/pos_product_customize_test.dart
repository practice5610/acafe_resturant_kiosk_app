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
import 'package:acafe_customer/features/kiosk/domain/kiosk_customize_sections.dart';
import 'package:acafe_customer/features/pos/domain/pos_responsive.dart';
import 'package:acafe_customer/features/pos/screens/pos_product_customize_screen.dart';
import 'package:acafe_customer/features/splash/domain/reposotories/splash_repo.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/main.dart' show navigatorKey;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
              create: (_) => CouponProvider(
                  couponRepo: CouponRepo(dioClient: dio))),
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
    expect(find.text('Purchase Receipt'), findsOneWidget);
    expect(find.textContaining('•'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
