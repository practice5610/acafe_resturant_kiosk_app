import 'package:acafe_customer/common/models/config_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/common/providers/product_provider.dart';
import 'package:acafe_customer/common/reposotories/product_repo.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:acafe_customer/features/auth/domain/reposotories/auth_repo.dart';
import 'package:acafe_customer/features/auth/providers/auth_provider.dart';
import 'package:acafe_customer/features/category/domain/reposotories/category_repo.dart';
import 'package:acafe_customer/features/category/providers/category_provider.dart';
import 'package:acafe_customer/features/cart/domain/reposotories/cart_repo.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_auth_repo.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_ordering_experience.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_product_customize_sheet.dart';
import 'package:acafe_customer/features/splash/domain/reposotories/splash_repo.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/main.dart' show navigatorKey;
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/kiosk_layout_harness.dart';

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

/// Live A↔B switch: when auth.orderingExperience changes, the customize host
/// remounts Version B (step flow) without a Navigator pop/push.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadKioskTestFonts);

  Product buildProduct() {
    final List<AddOns> addOns = [
      AddOns(id: 1, name: 'Extra Shot', price: 0.9, tax: 0),
    ];
    return Product(
      id: 42,
      name: 'Test Latte',
      description: '<p>Test</p>',
      image: '',
      price: 4.5,
      tax: 0,
      discount: 0,
      discountType: 'amount',
      taxType: 'amount',
      addOns: addOns,
      addOnGroups: [AddOnGroup(id: 1, name: 'Extras', addons: addOns)],
      variations: [
        Variation(
          name: 'Size',
          min: 0,
          max: 0,
          isRequired: false,
          isMultiSelect: false,
          variationValues: [
            VariationValue(level: 'Small', optionPrice: 0),
            VariationValue(level: 'Large', optionPrice: 1),
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

  testWidgets('host remounts Version B when Ordering Experience flips live',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      AppConstants.token: 'tok',
      AppConstants.branch: 1,
      AppConstants.kioskDeviceId: 1,
      AppConstants.kioskOrderingExperience: 'version_a',
    });
    final prefs = await SharedPreferences.getInstance();
    final dio = DioClient(
      'http://localhost',
      null,
      loggingInterceptor: LoggingInterceptor(),
      sharedPreferences: prefs,
    );
    final auth = KioskAuthProvider(
      kioskAuthRepo: KioskAuthRepo(dioClient: dio, sharedPreferences: prefs),
    );
    final product = buildProduct();
    final productProvider = ProductProvider(
      productRepo: ProductRepo(dioClient: dio, sharedPreferences: prefs),
    )
      ..initData(product, null)
      ..initProductVariationStatus(product.variations!.length);

    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ProductProvider>.value(value: productProvider),
          ChangeNotifierProvider<SplashProvider>(
            create: (_) => _StubSplashProvider(
              splashRepo: SplashRepo(dioClient: dio, sharedPreferences: prefs),
            ),
          ),
          ChangeNotifierProvider<CartProvider>(
            create: (_) =>
                CartProvider(cartRepo: CartRepo(sharedPreferences: prefs)),
          ),
          ChangeNotifierProvider<KioskAuthProvider>.value(value: auth),
          // The host watches the catalog so an admin editing add-ons mid-sheet
          // re-seeds the selection; without it the screen cannot even mount.
          ChangeNotifierProvider<CategoryProvider>(
            create: (_) => CategoryProvider(
                categoryRepo:
                    CategoryRepo(dioClient: dio, sharedPreferences: prefs)),
          ),
          ChangeNotifierProvider<AuthProvider>(
            create: (_) => AuthProvider(
              authRepo: AuthRepo(dioClient: dio, sharedPreferences: prefs),
            ),
          ),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          home: KioskCustomizeExperienceHost(product: product),
        ),
      ),
    );
    await tester.pump();

    expect(auth.orderingExperience, KioskOrderingExperience.versionA);
    expect(find.byType(KioskProductCustomizeScreen), findsOneWidget);
    expect(find.byType(KioskProductCustomizeStepScreen), findsNothing);

    final changed = await auth.applyOrderingExperienceFromRealtime(
      deviceId: 1,
      orderingExperience: 'version_b',
    );
    expect(changed, isTrue);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(auth.orderingExperience, KioskOrderingExperience.versionB);
    expect(find.byType(KioskProductCustomizeStepScreen), findsOneWidget);
    expect(find.byType(KioskProductCustomizeScreen), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  });
}
