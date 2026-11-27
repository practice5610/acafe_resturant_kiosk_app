import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/models/config_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/common/providers/product_provider.dart';
import 'package:acafe_customer/common/reposotories/product_repo.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:acafe_customer/features/branch/providers/branch_provider.dart';
import 'package:acafe_customer/features/cart/domain/reposotories/cart_repo.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_auth_repo.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_deal_detail_screen.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_order_line_card.dart';
import 'package:acafe_customer/features/splash/domain/reposotories/splash_repo.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/main.dart' show navigatorKey;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StubSplash extends SplashProvider {
  _StubSplash({required super.splashRepo});
  @override
  ConfigModel? get configModel => ConfigModel(
        currencySymbol: '€',
        currencySymbolPosition: 'left',
        decimalPointSettings: 2,
      );
  @override
  BaseUrls? get baseUrls => BaseUrls(
        productImageUrl: 'http://localhost/product',
        dealImageUrl: 'http://localhost/deal',
      );
}

Product _plainProduct() => Product(
      id: 9,
      name: 'A/Cafe Beige T-Shirt',
      price: 39.95,
      image: 'tee.png',
      // No variations / add-ons — the cart-card tap used to re-add these.
      variations: const [],
      addOns: const [],
      addOnGroups: const [],
    );

CartModel _plainLine({required Product product, int quantity = 11}) =>
    CartModel(
      39.95,
      39.95,
      const [],
      0,
      quantity,
      0,
      const [],
      product,
      const [],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final int qty in [1, 2]) {
    testWidgets('line card renders at quantity $qty (bin / minus beside +)',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final dio = DioClient('http://localhost', null,
          loggingInterceptor: LoggingInterceptor(), sharedPreferences: prefs);
      final splashRepo = SplashRepo(dioClient: dio, sharedPreferences: prefs);
      final cart = CartProvider(cartRepo: CartRepo(sharedPreferences: prefs))
        ..replaceCartList([_plainLine(product: _plainProduct(), quantity: qty)]);

      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<SplashProvider>(
              create: (_) => _StubSplash(splashRepo: splashRepo)),
          ChangeNotifierProvider<BranchProvider>(
              create: (_) => BranchProvider(splashRepo: splashRepo)),
          ChangeNotifierProvider<CartProvider>.value(value: cart),
          ChangeNotifierProvider<ProductProvider>(
              create: (_) => ProductProvider(
                  productRepo:
                      ProductRepo(dioClient: dio, sharedPreferences: prefs))),
          ChangeNotifierProvider<KioskAuthProvider>(
              create: (_) => KioskAuthProvider(
                  kioskAuthRepo:
                      KioskAuthRepo(dioClient: dio, sharedPreferences: prefs))),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          home: Scaffold(
            body: KioskOrderLineCard(s: 0.4, cart: cart.cartList.first!, index: 0),
          ),
        ),
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('+'), findsOneWidget);
      if (qty == 1) {
        expect(find.byType(SvgPicture), findsOneWidget);
      } else {
        expect(find.text('\u2212'), findsOneWidget);
      }
    });
  }
}
