import 'dart:io';

import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/models/config_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/common/providers/product_provider.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:acafe_customer/features/branch/providers/branch_provider.dart';
import 'package:acafe_customer/features/cart/domain/reposotories/cart_repo.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/category/domain/category_model.dart';
import 'package:acafe_customer/features/category/providers/category_provider.dart';
import 'package:acafe_customer/features/coupon/providers/coupon_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_deal.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_deal_repo.dart';
import 'package:acafe_customer/features/kiosk/landscape/landscape_routes.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_auth_repo.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_deal_provider.dart';
import 'package:acafe_customer/features/language/providers/localization_provider.dart';
import 'package:acafe_customer/features/search/providers/search_provider.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/main.dart' show navigatorKey;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _loadFonts() async {
  const Map<String, List<String>> families = {
    'Loew': [
      'assets/fonts/Loew-Regular.ttf',
      'assets/fonts/Loew-Medium.ttf',
      'assets/fonts/Loew-Bold.ttf',
      'assets/fonts/Loew-ExtraBold.ttf',
    ],
    'Swiss721': ['assets/fonts/Swiss721-Light.ttf'],
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

class _StubSplash extends SplashProvider {
  _StubSplash({required super.splashRepo});
  @override
  ConfigModel? get configModel => ConfigModel(
      currencySymbol: '€',
      currencySymbolPosition: 'left',
      decimalPointSettings: 2);
  @override
  BaseUrls? get baseUrls => BaseUrls(
      productImageUrl: 'http://localhost/p', categoryImageUrl: 'http://localhost/c');
}

class _StubCategory extends CategoryProvider {
  _StubCategory() : super(categoryRepo: null);
  @override
  bool isKioskMenuReadyFor(String localeCode) => true;
  @override
  List<CategoryModel>? get categoryList =>
      [CategoryModel(id: 1, name: 'Matcha', image: '')];
  @override
  String? get selectedSubCategoryId => '1';
  @override
  ProductModel? get categoryProductModel {
    // ProductModel's default ctor has a self-assignment bug (`products =
    // products`), so set the public field directly.
    final model = ProductModel();
    model.products = [
      for (int i = 0; i < 7; i++)
        Product(
            id: i,
            name: 'Drink $i',
            image: '',
            price: 6.0 + i,
            description: 'Tasty drink number $i'),
    ];
    return model;
  }
}

class _StubDeals extends KioskDealProvider {
  _StubDeals(KioskDealRepo repo) : super(dealRepo: repo);
  @override
  List<KioskDeal> get deals => const [];
  @override
  Future<bool> fetchDeals() async => false;
}

class _StubLocalization extends LocalizationProvider {
  _StubLocalization({required super.sharedPreferences, required super.dioClient});
  @override
  Locale get locale => const Locale('en');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);

  Future<Widget> harness(WidgetTester tester, {List<CartModel?>? cartLines}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final dio = DioClient('http://localhost', null,
        loggingInterceptor: LoggingInterceptor(), sharedPreferences: prefs);
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<CartProvider>(
            create: (_) => CartProvider(cartRepo: CartRepo(sharedPreferences: prefs))
              ..replaceCartList(cartLines ?? const [])),
        ChangeNotifierProvider<CouponProvider>(
            create: (_) => CouponProvider(couponRepo: null)),
        ChangeNotifierProvider<BranchProvider>(
            create: (_) => BranchProvider(splashRepo: null)),
        ChangeNotifierProvider<ProductProvider>(
            create: (_) => ProductProvider(productRepo: null)),
        ChangeNotifierProvider<SplashProvider>(
            create: (_) => _StubSplash(splashRepo: null)),
        ChangeNotifierProvider<KioskAuthProvider>(
            create: (_) => KioskAuthProvider(
                kioskAuthRepo:
                    KioskAuthRepo(dioClient: dio, sharedPreferences: prefs))),
        ChangeNotifierProvider<CategoryProvider>(create: (_) => _StubCategory()),
        ChangeNotifierProvider<SearchProvider>(
            create: (_) => SearchProvider(searchRepo: null)),
        ChangeNotifierProvider<KioskDealProvider>(
            create: (_) => _StubDeals(
                KioskDealRepo(dioClient: dio, sharedPreferences: prefs))),
        ChangeNotifierProvider<LocalizationProvider>(
            create: (_) => _StubLocalization(
                sharedPreferences: prefs, dioClient: dio)),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        home: Builder(
          builder: (context) => KioskLandscapeSwitch.resolve(
            context,
            '/menu-kiosk',
            const Text('PORTRAIT PLACEHOLDER', textDirection: TextDirection.ltr),
          ),
        ),
      ),
    );
  }

  const Map<String, Size> sizes = {
    '1366x1024': Size(1366, 1024),
    '1280x800': Size(1280, 800),
    '1024x768': Size(1024, 768),
    '1920x1200': Size(1920, 1200),
    '1920x1080': Size(1920, 1080),
  };



  sizes.forEach((name, size) {
    testWidgets('renders menu + order panel at $name with no overflow',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(await harness(tester));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      // Order panel is present (empty order).
      expect(find.text('Your order'), findsOneWidget);
      expect(find.text('Your order is empty'), findsOneWidget);
      // Products render in the grid.
      expect(find.text('Drink 0'), findsWidgets);
      // Filter pills render.
      expect(find.text('POPULAR'), findsOneWidget);
    });
  });

  testWidgets('header logo sits at Figma x40 at the 1366x1024 reference',
      (tester) async {
    tester.view.physicalSize = const Size(1366, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await harness(tester));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final Offset logoTopLeft = tester.getTopLeft(find.text('A/CAFÉ'));
    expect(logoTopLeft.dx, 40);
  });

  testWidgets('header and panel dividers sit at Figma y115/y118 at the 1366x1024 reference',
      (tester) async {
    tester.view.physicalSize = const Size(1366, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await harness(tester));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final headerLine = find.byWidgetPredicate((w) =>
        w is Container && w.color == Colors.black && (w.constraints?.maxHeight ?? 0) == 2);
    expect(tester.getTopLeft(headerLine).dy, closeTo(115, 1));

    expect(tester.getTopLeft(find.text('Your order')).dy, closeTo(36, 1));
    expect(tester.getTopLeft(find.text('0 items')).dy, closeTo(78, 1));

    final panelLine = find.byWidgetPredicate((w) =>
        w is Container &&
        w.color == const Color(0xFFDED8C6) &&
        (w.constraints?.maxHeight ?? 0) == 1.5);
    expect(tester.getTopLeft(panelLine).dy, closeTo(118, 1));
  });

  group('resize (Phase 3B P1 fix)', () {
    testWidgets(
        'landscape -> narrow portrait-shaped -> landscape never throws and always matches the CURRENT window',
        (tester) async {
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      tester.view.physicalSize = const Size(1366, 1024);
      await tester.pumpWidget(await harness(tester));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      expect(find.text('Your order'), findsOneWidget); // landscape screen

      // A narrow, portrait-shaped width used to crash this screen: the panel
      // width's clamp(220, maxWidth*0.4) throws once maxWidth < 550 (lower >
      // upper). It must now just show the portrait placeholder, no exception.
      tester.view.physicalSize = const Size(390, 900);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      expect(find.text('PORTRAIT PLACEHOLDER'), findsOneWidget);
      expect(find.text('Your order'), findsNothing);

      // Back to landscape, still live (no lock to a stale decision).
      tester.view.physicalSize = const Size(1920, 1080);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      expect(find.text('Your order'), findsOneWidget);
      expect(find.text('PORTRAIT PLACEHOLDER'), findsNothing);
    });

    testWidgets(
        'cart state survives a landscape -> portrait -> landscape resize (same Provider, no re-fetch)',
        (tester) async {
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final cartLines = [
        CartModel(
          6.0,
          6.0,
          const [],
          0,
          1,
          0,
          const [],
          Product(id: 1, name: 'Iced Matcha Latte', image: '', price: 6.0),
          const [],
        ),
      ];

      tester.view.physicalSize = const Size(1366, 1024);
      await tester.pumpWidget(await harness(tester, cartLines: cartLines));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('1 item'), findsOneWidget);

      tester.view.physicalSize = const Size(500, 1000);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);

      tester.view.physicalSize = const Size(1366, 1024);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      // Same CartProvider instance the whole time (it lives above the
      // switch), so the line the customer added is still there.
      expect(find.text('1 item'), findsOneWidget);
    });
  });

  group('B-03 item just added (toast + highlight)', () {
    testWidgets('adding a product shows the toast and the highlight together',
        (tester) async {
      tester.view.physicalSize = const Size(1366, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(await harness(tester));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final cart = Provider.of<CartProvider>(
          tester.element(find.text('Your order')),
          listen: false);
      cart.addToCart(
        CartModel(6.0, 6.0, const [], 0, 1, 0, const [],
            Product(id: 1, name: 'Iced Mango Matcha', image: '', price: 6.0), const []),
        null,
        showMessage: false,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.textContaining('Iced Mango Matcha added to your order'),
          findsOneWidget);
      expect(find.text('1 item'), findsOneWidget);

      // Toast is horizontally centered on the MENU pane, not the whole
      // screen (the order panel sits to its right).
      final double toastCenterX =
          tester.getCenter(find.byKey(const Key('landscape-toast'))).dx;
      expect(toastCenterX, lessThan(683)); // < half of 1366 (whole-screen center)
      expect(toastCenterX, closeTo(573, 40));
      final double toastBottomGap =
          1024 - tester.getBottomLeft(find.byKey(const Key('landscape-toast'))).dy;
      expect(toastBottomGap, closeTo(16, 2));

      // Toast + highlight disappear together after the single 3 s timer.
      await tester.pump(const Duration(seconds: 3, milliseconds: 100));
      expect(find.textContaining('added to your order'), findsNothing);
    });

    testWidgets('a panel +/- never shows the toast', (tester) async {
      tester.view.physicalSize = const Size(1366, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final cartLines = [
        CartModel(6.0, 6.0, const [], 0, 1, 0, const [],
            Product(id: 1, name: 'Iced Mango Matcha', image: '', price: 6.0), const []),
      ];
      await tester.pumpWidget(await harness(tester, cartLines: cartLines));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('+'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.textContaining('added to your order'), findsNothing);
    });
  });

  testWidgets(
      'resize with items in the cart and the toast visible: no exception',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    tester.view.physicalSize = const Size(1366, 1024);
    await tester.pumpWidget(await harness(tester));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final cart = Provider.of<CartProvider>(
        tester.element(find.text('Your order')),
        listen: false);
    cart.addToCart(
      CartModel(6.0, 6.0, const [], 0, 1, 0, const [],
          Product(id: 1, name: 'Iced Mango Matcha', image: '', price: 6.0), const []),
      null,
      showMessage: false,
    );
    await tester.pump();
    expect(find.textContaining('added to your order'), findsOneWidget);

    tester.view.physicalSize = const Size(500, 1000);
    await tester.pump();
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(1920, 1080);
    await tester.pump();
    expect(tester.takeException(), isNull);

    // Let the feedback timer fire so no Timer is pending when the test ends.
    await tester.pump(const Duration(seconds: 4));
  });
}
