import 'dart:io';

import 'package:acafe_customer/common/models/config_model.dart';
import 'package:acafe_customer/common/responsive/kiosk_shell.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:acafe_customer/features/cart/domain/reposotories/cart_repo.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/coupon/providers/coupon_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_auth_repo.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/splash/domain/reposotories/splash_repo.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/main.dart' show navigatorKey;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Viewports the audit requires every kiosk layout to survive.
///
/// Includes medium landscape tablets (1024×768 / 900×600) — those used to
/// throw on login/checkout because `.clamp(floor, screen*frac)` had floor >
/// ceiling and painted the grey ErrorWidget.
const kioskTargetSizes = <Size>[
  Size(1080, 1920),
  Size(2160, 3840),
  Size(1920, 1080),
  Size(2560, 1440),
  Size(3840, 2160),
  Size(1366, 768),
  Size(1024, 768),
  Size(900, 600),
];

/// Currency config so [PriceConverterHelper] can run in widget tests.
class KioskStubSplashProvider extends SplashProvider {
  KioskStubSplashProvider({required super.splashRepo});

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

Future<void> loadKioskTestFonts() async {
  const families = <String, List<String>>{
    'Loew': [
      'assets/fonts/Loew-Regular.ttf',
      'assets/fonts/Loew-Medium.ttf',
      'assets/fonts/Loew-Bold.ttf',
      'assets/fonts/Loew-ExtraBold.ttf',
    ],
    'Swiss721': ['assets/fonts/Swiss721-Light.ttf'],
    'ScotchDisplay': ['assets/fonts/ScotchDisplay-Light.ttf'],
  };
  for (final family in families.entries) {
    final loader = FontLoader(family.key);
    for (final path in family.value) {
      loader.addFont(
        File(path).readAsBytes().then((b) => b.buffer.asByteData()),
      );
    }
    await loader.load();
  }
}

Future<List<SingleChildWidget>> kioskBaseProviders({
  bool withAuth = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final dio = DioClient(
    'http://localhost',
    null,
    loggingInterceptor: LoggingInterceptor(),
    sharedPreferences: prefs,
  );
  return [
    ChangeNotifierProvider<SplashProvider>(
      create: (_) => KioskStubSplashProvider(
        splashRepo: SplashRepo(dioClient: dio, sharedPreferences: prefs),
      ),
    ),
    ChangeNotifierProvider<CartProvider>(
      create: (_) => CartProvider(cartRepo: CartRepo(sharedPreferences: prefs)),
    ),
    ChangeNotifierProvider<CouponProvider>(
      create: (_) => CouponProvider(couponRepo: null),
    ),
    if (withAuth)
      ChangeNotifierProvider<KioskAuthProvider>(
        create: (_) => KioskAuthProvider(
          kioskAuthRepo:
              KioskAuthRepo(dioClient: dio, sharedPreferences: prefs),
        ),
      ),
  ];
}

Future<void> pumpKioskScreen(
  WidgetTester tester,
  Size size,
  Widget screen, {
  List<SingleChildWidget>? providers,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final Widget app = MediaQuery(
    data: MediaQueryData(size: size),
    child: MaterialApp(
      navigatorKey: navigatorKey,
      home: KioskShell(child: screen),
    ),
  );

  await tester.pumpWidget(
    providers == null || providers.isEmpty
        ? app
        : MultiProvider(providers: providers, child: app),
  );
}

Future<void> settleKiosk(WidgetTester tester) async {
  for (int i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

void expectNoOverflow(WidgetTester tester, Size size) {
  expect(
    tester.takeException(),
    isNull,
    reason:
        'overflow or exception at ${size.width.toInt()}×${size.height.toInt()}',
  );
}
