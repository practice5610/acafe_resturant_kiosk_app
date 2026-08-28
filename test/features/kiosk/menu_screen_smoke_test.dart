import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:acafe_customer/common/models/config_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/common/responsive/kiosk_shell.dart';
import 'package:acafe_customer/features/branch/providers/branch_provider.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/category/domain/category_model.dart';
import 'package:acafe_customer/features/category/providers/category_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_deal.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_deal_provider.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_menu_screen.dart';
import 'package:acafe_customer/features/language/providers/localization_provider.dart';
import 'package:acafe_customer/features/search/providers/search_provider.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_deal_repo.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/features/cart/domain/reposotories/cart_repo.dart';
import 'package:acafe_customer/features/category/domain/reposotories/category_repo.dart';
import 'package:acafe_customer/features/search/domain/reposotories/search_repo.dart';
import 'package:acafe_customer/features/splash/domain/reposotories/splash_repo.dart';
import 'package:acafe_customer/features/kiosk/domain/reposotories/kiosk_auth_repo.dart';
import 'package:dio/dio.dart';
import 'package:acafe_customer/data/datasource/remote/dio/logging_interceptor.dart';

class _FakeDealProvider extends KioskDealProvider {
  _FakeDealProvider(List<KioskDeal> deals)
      : super(
          dealRepo: KioskDealRepo(
            dioClient: DioClient(
              'http://localhost',
              Dio(),
              loggingInterceptor: LoggingInterceptor(),
              sharedPreferences: null,
            ),
            sharedPreferences: null,
          ),
        ) {
    // ignore: invalid_use_of_protected_member
  }

  List<KioskDeal> seeded;
  @override
  List<KioskDeal> get deals => seeded;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('KioskMenuScreen builds with deals and products', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final product = Product(
      id: 1,
      name: 'Test Coffee',
      price: 3.5,
      image: 'x.png',
      tags: [ProductTag(tag: 'POPULAR', isKioskFilter: true)],
    );

    final categoryProvider = CategoryProvider(
      categoryRepo: CategoryRepo(
        dioClient: DioClient('http://localhost', Dio(),
            loggingInterceptor: LoggingInterceptor(), sharedPreferences: prefs),
      ),
    );
    // Seed via reflection-ish public APIs if available — set fields carefully.
    // Use the disk-warm path shape by assigning through known setters if any.
    // Fall back: call methods that set state from ProductModel.
    categoryProvider.setCategoryListForTest([
      CategoryModel(id: 10, name: 'COFFEE', status: 1),
    ]);
    categoryProvider.setCategoryProductsForTest(
      ProductModel(products: [product], totalSize: 1, offset: 1),
      selectedId: '10',
    );

    final deal = KioskDeal(
      id: 2,
      title: 'Special',
      bundlePrice: 10,
      originalPrice: 20,
      savings: 10,
      savingsPercent: 50,
      available: true,
      image: 'deal.png',
      items: [KioskDealItem(quantity: 1, product: product)],
    );

    final dealProvider = _FakeDealProvider([])..seeded = [deal];

    final splash = SplashProvider(
      splashRepo: SplashRepo(
        dioClient: DioClient('http://localhost', Dio(),
            loggingInterceptor: LoggingInterceptor(), sharedPreferences: prefs),
        sharedPreferences: prefs,
      ),
    );
    splash.setConfigForTest(ConfigModel(
      baseUrls: BaseUrls(productImageUrl: 'http://img', dealImageUrl: 'http://deal'),
    ));

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SplashProvider>.value(value: splash),
          ChangeNotifierProvider<CategoryProvider>.value(value: categoryProvider),
          ChangeNotifierProvider<SearchProvider>(
            create: (_) => SearchProvider(
              searchRepo: SearchRepo(
                dioClient: DioClient('http://localhost', Dio(),
                    loggingInterceptor: LoggingInterceptor(),
                    sharedPreferences: prefs),
                sharedPreferences: prefs,
              ),
            ),
          ),
          ChangeNotifierProvider<CartProvider>(
            create: (_) => CartProvider(
              cartRepo: CartRepo(sharedPreferences: prefs),
            ),
          ),
          ChangeNotifierProvider<LocalizationProvider>(
            create: (_) => LocalizationProvider(
              sharedPreferences: prefs,
              dioClient: DioClient('http://localhost', Dio(),
                  loggingInterceptor: LoggingInterceptor(),
                  sharedPreferences: prefs),
            ),
          ),
          ChangeNotifierProvider<KioskAuthProvider>(
            create: (_) => KioskAuthProvider(
              kioskAuthRepo: KioskAuthRepo(
                dioClient: DioClient('http://localhost', Dio(),
                    loggingInterceptor: LoggingInterceptor(),
                    sharedPreferences: prefs),
                sharedPreferences: prefs,
              ),
            ),
          ),
          ChangeNotifierProvider<KioskDealProvider>.value(value: dealProvider),
          ChangeNotifierProvider(
            create: (_) => BranchProvider(
              splashRepo: SplashRepo(
                dioClient: DioClient('http://localhost', Dio(),
                    loggingInterceptor: LoggingInterceptor(),
                    sharedPreferences: prefs),
                sharedPreferences: prefs,
              ),
            ),
          ),
        ],
        child: MaterialApp(
          home: KioskShell(
            child: const KioskMenuScreen(),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(KioskMenuScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
