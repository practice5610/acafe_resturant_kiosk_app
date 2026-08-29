import 'dart:io';

import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/models/config_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/common/providers/product_provider.dart';
import 'package:acafe_customer/common/reposotories/product_repo.dart';
import 'package:acafe_customer/common/responsive/kiosk_shell.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:acafe_customer/features/auth/domain/reposotories/auth_repo.dart';
import 'package:acafe_customer/features/auth/providers/auth_provider.dart';
import 'package:acafe_customer/features/branch/providers/branch_provider.dart';
import 'package:acafe_customer/features/cart/domain/reposotories/cart_repo.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/category/domain/category_model.dart';
import 'package:acafe_customer/features/category/domain/reposotories/category_repo.dart';
import 'package:acafe_customer/features/category/providers/category_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_auth_repo.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_cart_totals.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_deal_repo.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_deal_provider.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_menu_screen.dart';
import 'package:acafe_customer/features/language/providers/localization_provider.dart';
import 'package:acafe_customer/features/search/domain/reposotories/search_repo.dart';
import 'package:acafe_customer/features/search/providers/search_provider.dart';
import 'package:acafe_customer/features/splash/domain/reposotories/splash_repo.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/helper/price_converter_helper.dart';
import 'package:acafe_customer/main.dart' show navigatorKey;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StubSplash extends SplashProvider {
  _StubSplash({required super.splashRepo});
  @override
  ConfigModel? get configModel => ConfigModel(
      currencySymbol: '€',
      currencySymbolPosition: 'left',
      decimalPointSettings: 2);
  @override
  BaseUrls? get baseUrls => BaseUrls(
      productImageUrl: 'http://localhost/product',
      addonImageUrl: 'http://localhost/addon');
}

class _StubCategory extends CategoryProvider {
  _StubCategory({required super.categoryRepo});
  @override
  List<CategoryModel>? get categoryList =>
      [CategoryModel(id: 1, name: 'Coffee')];
}

Future<void> _fonts() async {
  const f = {
    'Loew': [
      'assets/fonts/Loew-Regular.ttf',
      'assets/fonts/Loew-Medium.ttf',
      'assets/fonts/Loew-Bold.ttf',
      'assets/fonts/Loew-ExtraBold.ttf'
    ],
    'Swiss721': ['assets/fonts/Swiss721-Light.ttf'],
  };
  for (final e in f.entries) {
    final l = FontLoader(e.key);
    for (final p in e.value) {
      l.addFont(File(p).readAsBytes().then((b) => b.buffer.asByteData()));
    }
    await l.load();
  }
}

CartModel _addonLine({int quantity = 3}) {
  final product = Product(
    id: 42,
    name: 'New Test Live',
    price: 17.50,
    image: 'x.png',
    addOns: [AddOns(id: 7, name: 'Caramel Syrup', price: 1.57)],
  );
  return CartModel(
    17.50,
    17.50,
    const [],
    0,
    quantity,
    0,
    [AddOn(id: 7, quantity: 1)],
    product,
    const [],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_fonts);

  testWidgets(
      'menu latest-item + keeps unit price stable and raises checkout total',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final dio = DioClient('http://localhost', null,
        loggingInterceptor: LoggingInterceptor(), sharedPreferences: prefs);

    const viewport = Size(1920, 1080);
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final cart = CartProvider(cartRepo: CartRepo(sharedPreferences: prefs))
      ..replaceCartList([_addonLine(quantity: 3)]);

    // 17.50 product + 1.57 caramel — must stay put when qty changes.
    const double unitBefore = 19.07;
    const double totalBefore = 57.21; // × 3
    expect(kioskLineUnitPrice(cart.cartList.first!), unitBefore);
    expect(kioskCartTotal(cart.cartList), totalBefore);

    final splashRepo = SplashRepo(dioClient: dio, sharedPreferences: prefs);

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<SplashProvider>(
            create: (_) => _StubSplash(splashRepo: splashRepo)),
        ChangeNotifierProvider<BranchProvider>(
            create: (_) => BranchProvider(splashRepo: splashRepo)),
        ChangeNotifierProvider<CategoryProvider>(
            create: (_) => _StubCategory(
                categoryRepo:
                    CategoryRepo(dioClient: dio, sharedPreferences: prefs))),
        ChangeNotifierProvider<LocalizationProvider>(
            create: (_) => LocalizationProvider(
                sharedPreferences: prefs, dioClient: dio)),
        ChangeNotifierProvider<KioskDealProvider>(
            create: (_) => KioskDealProvider(
                dealRepo:
                    KioskDealRepo(dioClient: dio, sharedPreferences: prefs))),
        ChangeNotifierProvider<CartProvider>.value(value: cart),
        ChangeNotifierProvider<KioskAuthProvider>(
            create: (_) => KioskAuthProvider(
                kioskAuthRepo:
                    KioskAuthRepo(dioClient: dio, sharedPreferences: prefs))),
        ChangeNotifierProvider<AuthProvider>(
            create: (_) => AuthProvider(
                authRepo: AuthRepo(dioClient: dio, sharedPreferences: prefs))),
        ChangeNotifierProvider<SearchProvider>(
            create: (_) => SearchProvider(
                searchRepo:
                    SearchRepo(dioClient: dio, sharedPreferences: prefs))),
        ChangeNotifierProvider<ProductProvider>(
            create: (_) => ProductProvider(
                productRepo:
                    ProductRepo(dioClient: dio, sharedPreferences: prefs))),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        home: const Scaffold(body: KioskShell(child: KioskMenuScreen())),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // convertPrice reads currency off Get.context (navigatorKey).
    final String unitLabel = PriceConverterHelper.convertPrice(unitBefore);
    final String totalLabel = PriceConverterHelper.convertPrice(totalBefore);

    final texts = tester.widgetList<Text>(find.byType(Text)).map((t) {
      final d = t.data;
      if (d != null) return d;
      return t.textSpan?.toPlainText() ?? '';
    }).where((s) => s.trim().isNotEmpty).toList();
    expect(texts, isNotEmpty, reason: 'menu rendered no text: $texts');

    // Latest-item card shows the per-unit price (product + add-ons).
    expect(find.text('New Test Live'), findsWidgets,
        reason: 'expected latest item in cart bar; texts=$texts');
    expect(find.text(unitLabel), findsWidgets,
        reason: 'expected unit $unitLabel; texts=$texts');
    expect(
      texts.any((t) => t.toUpperCase().contains('CHECK OUT') || t.contains(totalLabel)),
      isTrue,
      reason: 'expected checkout total $totalLabel; texts=$texts',
    );

    // The filled cart bar's "+" (add another of the latest item).
    final Finder plus = find.descendant(
      of: find.byType(KioskMenuScreen),
      matching: find.byIcon(Icons.add),
    );
    expect(plus, findsOneWidget);

    await tester.tap(plus);
    await tester.pump();
    // Snackbar / settle without waiting forever on pending timers.
    await tester.pump(const Duration(milliseconds: 500));

    expect(cart.cartList.first!.quantity, 4);
    expect(kioskLineUnitPrice(cart.cartList.first!), unitBefore,
        reason: 'unit price under the name must not shrink after +');
    expect(kioskCartTotal(cart.cartList), closeTo(totalBefore + unitBefore, 0.001),
        reason: 'checkout total must rise by a full unit (incl. add-ons)');

    // UI still shows the same unit price string.
    expect(find.text(unitLabel), findsWidgets);
    final String newTotalLabel =
        PriceConverterHelper.convertPrice(totalBefore + unitBefore);
    expect(find.textContaining(newTotalLabel), findsOneWidget);
  });
}
