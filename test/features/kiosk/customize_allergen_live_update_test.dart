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
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_product_customize_sheet.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_allergen_notice.dart';
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

/// Stands in for the realtime menu cache: [publish] is what
/// `applyRealtimeUpsert` does after the socket refetch — swap the cached
/// product for a fresh object and notify.
class _FakeCatalog extends CategoryProvider {
  _FakeCatalog({required super.categoryRepo});

  Product? _cached;

  void publish(Product product) {
    _cached = product;
    notifyListeners();
  }

  @override
  Product? findCachedProduct(int? productId) =>
      (_cached?.id == productId) ? _cached : null;
}

/// An allergen edit changes NOTHING the modifier signature looks at: allergens
/// ride the product_tag pivot, so `products.updated_at` does not move and the
/// variations / add-ons are byte-identical. The host used to keep rendering the
/// snapshot it took when the screen opened, so the CONTAINS strip only caught
/// up after the customer backed out and re-entered — while a price edit, which
/// does move updated_at, appeared instantly.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadKioskTestFonts);

  Product buildProduct({List<ProductTag>? tags}) {
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
      updatedAt: '2026-08-31T10:00:00.000000Z',
      tags: tags,
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
      ],
    );
  }

  testWidgets(
      'CONTAINS strip follows an allergen edit that leaves updated_at alone',
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
    final catalog = _FakeCatalog(
      categoryRepo: CategoryRepo(dioClient: dio, sharedPreferences: prefs),
    );

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
          ChangeNotifierProvider<CategoryProvider>.value(value: catalog),
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

    expect(find.byType(KioskAllergenNotice), findsNothing);

    // Admin ticks "Nuts". Same updated_at, same variations, same add-ons.
    catalog.publish(buildProduct(tags: [
      ProductTag(id: 7, tag: 'Nuts', isAllergen: true, isKioskFilter: false),
    ]));
    await tester.pump();

    expect(find.byType(KioskAllergenNotice), findsOneWidget);

    // ...and unticking it takes the strip away again, without a re-entry.
    catalog.publish(buildProduct(tags: const <ProductTag>[]));
    await tester.pump();

    expect(find.byType(KioskAllergenNotice), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  });
}
