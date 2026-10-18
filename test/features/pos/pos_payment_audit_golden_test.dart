import 'dart:io';

import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:acafe_customer/features/cart/domain/reposotories/cart_repo.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/coupon/providers/coupon_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_auth_repo.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_manager_repo.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/pos/domain/pos_sale_session.dart';
import 'package:acafe_customer/features/pos/pos_shell.dart';
import 'package:acafe_customer/features/pos/providers/pos_session_provider.dart';
import 'package:acafe_customer/features/pos/screens/pos_payment_selection_screen.dart';
import 'package:acafe_customer/features/splash/domain/reposotories/splash_repo.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/main.dart' show navigatorKey;
import 'package:acafe_customer/theme/light_theme.dart';
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/kiosk_layout_harness.dart';

/// Pixel-audit goldens for the "POS payment" Figma layer (1915:9314).
///
/// Each golden renders one frame at its Figma size (1366x1024) with the
/// frame's own sample data, so it can be laid next to the Figma export.
Future<void> loadPaymentFonts() async {
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

int _addOnSeq = 100;

/// A Figma sample line: `name`, `€ price · vessel`, and its `+`/`-` notes.
CartModel figmaLine(
  String name,
  double price, {
  String vessel = 'Cup',
  List<String> added = const [],
  List<String> removed = const [],
  int id = 1,
}) {
  final List<AddOns> addOns = [];
  final List<AddOn> picked = [];
  for (final String a in added) {
    final int addOnId = _addOnSeq++;
    addOns.add(AddOns(id: addOnId, name: a, price: 0));
    picked.add(AddOn(id: addOnId, quantity: 1));
  }
  for (final String r in removed) {
    addOns.add(AddOns(id: _addOnSeq++, name: r, price: 0, isDefault: true));
  }
  return CartModel(
    price,
    price,
    const [],
    0,
    1,
    0,
    picked,
    Product(
      id: id,
      name: name,
      price: price,
      variations: [
        Variation(name: 'Cup or Can', variationValues: [
          VariationValue(level: 'Cup', optionPrice: 0),
          VariationValue(level: 'Can', optionPrice: 0),
        ]),
      ],
      addOns: addOns,
    ),
    [
      [vessel == 'Cup', vessel == 'Can'],
    ],
  );
}

/// The three-line Dylan / € 19.00 ticket drawn on frames 01–12.
List<CartModel> figmaTicket() => [
      figmaLine('Oat Milk Matcha', 6, added: ['Oat milk'], id: 1),
      figmaLine('Vanilla Matcha Latte', 6,
          vessel: 'Can', added: ['Vanilla syrup'], id: 2),
      figmaLine('Mango Matcha', 7,
          added: ['Mango purée', 'Coconut milk', 'Honey drizzle', 'Chia seeds'],
          removed: ['Whipped cream'],
          id: 3),
    ];

Future<void> pumpPaymentScreen(
  WidgetTester tester, {
  Size size = const Size(1366, 1024),
  List<CartModel>? lines,
  PosPaymentMethod method = PosPaymentMethod.card,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({
    AppConstants.branch: 1,
    AppConstants.kioskDeviceCategory: 'pos',
    AppConstants.kioskDeviceName: 'Till 1',
  });
  final prefs = await SharedPreferences.getInstance();
  final dio = DioClient(
    'http://localhost',
    null,
    loggingInterceptor: LoggingInterceptor(),
    sharedPreferences: prefs,
  );
  final cart = CartProvider(cartRepo: CartRepo(sharedPreferences: prefs));
  cart.replaceCartList(lines ?? figmaTicket());

  PosSaleSession.instance.customerName.text = 'Dylan';
  PosSaleSession.instance.paymentMethod = method;

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<KioskAuthProvider>(
          create: (_) => KioskAuthProvider(
            kioskAuthRepo:
                KioskAuthRepo(dioClient: dio, sharedPreferences: prefs),
          ),
        ),
        ChangeNotifierProvider<SplashProvider>(
          create: (_) => KioskStubSplashProvider(
            splashRepo: SplashRepo(dioClient: dio, sharedPreferences: prefs),
          ),
        ),
        ChangeNotifierProvider<CartProvider>.value(value: cart),
        ChangeNotifierProvider<CouponProvider>(
          create: (_) => CouponProvider(couponRepo: null),
        ),
        ChangeNotifierProvider<PosSessionProvider>(
          create: (_) => PosSessionProvider(
            kioskManagerRepo:
                KioskManagerRepo(dioClient: dio, sharedPreferences: prefs),
          )..debugSetElevated(true),
        ),
      ],
      child: MediaQuery(
        data: MediaQueryData(size: size),
        child: PosShell(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            // The production theme, so inherited text styles match the app.
            theme: light,
            navigatorKey: navigatorKey,
            home: PosPaymentSelectionScreen(sharedPreferences: prefs),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadPaymentFonts);
  setUp(() => PosSaleSession.instance.reset());
  tearDown(() => PosSaleSession.instance.reset());

  testWidgets('01 Payment – Card (1915:9346)', (tester) async {
    await pumpPaymentScreen(tester);
    await expectLater(find.byType(PosPaymentSelectionScreen),
        matchesGoldenFile('goldens/payment_audit/01_card.png'));
  });

  testWidgets('02 Payment – Cash (1915:10105)', (tester) async {
    await pumpPaymentScreen(tester, method: PosPaymentMethod.cash);
    await expectLater(find.byType(PosPaymentSelectionScreen),
        matchesGoldenFile('goldens/payment_audit/02_cash.png'));
  });
}
