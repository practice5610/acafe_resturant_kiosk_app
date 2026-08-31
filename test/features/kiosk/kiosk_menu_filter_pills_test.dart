import 'dart:io';

import 'package:acafe_customer/features/coupon/domain/reposotories/coupon_repo.dart';
import 'package:acafe_customer/features/coupon/providers/coupon_provider.dart';
import 'package:acafe_customer/common/models/config_model.dart';
import 'package:acafe_customer/common/providers/product_provider.dart';
import 'package:acafe_customer/common/reposotories/product_repo.dart';
import 'package:acafe_customer/common/responsive/kiosk_shell.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:acafe_customer/features/auth/domain/reposotories/auth_repo.dart';
import 'package:acafe_customer/features/auth/providers/auth_provider.dart';
import 'package:acafe_customer/features/cart/domain/reposotories/cart_repo.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/category/domain/category_model.dart';
import 'package:acafe_customer/features/category/domain/reposotories/category_repo.dart';
import 'package:acafe_customer/features/category/providers/category_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_auth_repo.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_deal_repo.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_deal_provider.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_menu_screen.dart';
import 'package:acafe_customer/features/language/providers/localization_provider.dart';
import 'package:acafe_customer/features/search/domain/reposotories/search_repo.dart';
import 'package:acafe_customer/features/search/providers/search_provider.dart';
import 'package:acafe_customer/features/splash/domain/reposotories/splash_repo.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
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
  List<CategoryModel>? get categoryList => [
        CategoryModel(id: 1, name: 'Coffee'),
        CategoryModel(id: 2, name: 'Macha'),
        CategoryModel(id: 3, name: 'Poffertjes'),
        CategoryModel(id: 4, name: 'Soft Drinks'),
        CategoryModel(id: 5, name: 'Merchandise'),
        CategoryModel(id: 6, name: 'Other Drinks'),
      ];
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
      l.addFont(File(p)
          .readAsBytes()
          .then((b) => ByteData.view(Uint8List.fromList(b).buffer)));
    }
    await l.load();
  }
}

/// The menu's tag row — POPULAR / SIGNATURE / SEASONAL / SPECIALS / PURE /
/// CEROMONIAL.
///
/// Landscape used to lay this out as a horizontally scrolling `ListView` so a
/// second pill line could not take height from the product grid. That clipped
/// the last pill mid-word against the panel edge, with no scrollbar and no
/// fade — "CEROMO" reads as a broken layout, not as something to swipe, and on
/// a large display there was room for the whole set anyway.
///
/// It wraps in every composition now, so these pin the property that matters:
/// every pill is whole and on screen, at every size.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_fonts);

  /// Every pill label, in order.
  const List<String> pills = [
    'POPULAR',
    'SIGNATURE',
    'SEASONAL',
    'SPECIALS',
    'PURE',
    'CEROMONIAL',
  ];

  const Map<String, Size> viewports = {
    'laptop 1366x768': Size(1366, 768),
    'MacBook 1512x982': Size(1512, 982),
    'QHD 2560x1440': Size(2560, 1440),
    '4K 3840x2160': Size(3840, 2160),
    'portrait kiosk 1080x1920': Size(1080, 1920),
    'tablet 1024x768': Size(1024, 768),
  };

  viewports.forEach((name, viewport) {
    testWidgets('every tag pill is whole and on screen at $name',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final dio = DioClient('http://localhost', null,
          loggingInterceptor: LoggingInterceptor(), sharedPreferences: prefs);

      tester.view.physicalSize = viewport;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<SplashProvider>(
              create: (_) => _StubSplash(
                  splashRepo:
                      SplashRepo(dioClient: dio, sharedPreferences: prefs))),
          ChangeNotifierProvider<CategoryProvider>(
              create: (_) => _StubCategory(
                  categoryRepo: CategoryRepo(
                      dioClient: dio, sharedPreferences: prefs))),
          ChangeNotifierProvider<LocalizationProvider>(
              create: (_) => LocalizationProvider(
                  sharedPreferences: prefs, dioClient: dio)),
          ChangeNotifierProvider<KioskDealProvider>(
              create: (_) => KioskDealProvider(
                  dealRepo: KioskDealRepo(
                      dioClient: dio, sharedPreferences: prefs))),
          ChangeNotifierProvider<CartProvider>(
              create: (_) =>
                  CartProvider(cartRepo: CartRepo(sharedPreferences: prefs))),
          ChangeNotifierProvider<KioskAuthProvider>(
              create: (_) => KioskAuthProvider(
                  kioskAuthRepo: KioskAuthRepo(
                      dioClient: dio, sharedPreferences: prefs))),
          ChangeNotifierProvider<AuthProvider>(
              create: (_) => AuthProvider(
                  authRepo: AuthRepo(dioClient: dio, sharedPreferences: prefs))),
          ChangeNotifierProvider<SearchProvider>(
              create: (_) => SearchProvider(
                  searchRepo:
                      SearchRepo(dioClient: dio, sharedPreferences: prefs))),
          ChangeNotifierProvider<ProductProvider>(
              create: (_) => ProductProvider(
                  productRepo: ProductRepo(
                      dioClient: dio, sharedPreferences: prefs))),
          // The cart bar quotes the payable total, coupon included.
          ChangeNotifierProvider<CouponProvider>(
              create: (_) =>
                  CouponProvider(couponRepo: CouponRepo(dioClient: dio))),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          home: const KioskShell(child: KioskMenuScreen()),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);

      for (final String label in pills) {
        final Finder pill = find.text(label);
        expect(pill, findsOneWidget, reason: '"$label" is missing at $name');

        final Rect rect = tester.getRect(pill);
        expect(rect.left, greaterThanOrEqualTo(-0.5),
            reason: '"$label" starts off the left edge at $name ($rect)');
        expect(rect.right, lessThanOrEqualTo(viewport.width + 0.5),
            reason: '"$label" runs past the right edge at $name ($rect)');
        expect(rect.width, greaterThan(0),
            reason: '"$label" collapsed at $name');
      }

      // No sideways scroller under the pills: a row that scrolls is a row that
      // can hide a pill, which is the failure this replaced.
      expect(
        find.descendant(
          of: find.byType(Wrap),
          matching: find.byWidgetPredicate((w) =>
              w is Scrollable && w.axisDirection == AxisDirection.right),
        ),
        findsNothing,
        reason: 'the tag row must not scroll sideways at $name',
      );
    });
  });
}
