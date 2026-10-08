// TEMPORARY screenshot harness — delete after use.
// ignore_for_file: unused_element, avoid_print
import 'dart:io';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'dart:async';

import 'dart:io';

import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:acafe_customer/features/cart/domain/reposotories/cart_repo.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/di_container.dart';
import 'package:acafe_customer/features/coupon/providers/coupon_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_manager_repo.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_payment_service.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_auth_repo.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_payment_spec.dart';
import 'package:acafe_customer/features/pos/widgets/pos_settings_save_button.dart';
import 'package:acafe_customer/features/pos/widgets/pos_ui.dart';
import 'package:acafe_customer/features/pos/domain/pos_sale_session.dart';
import 'package:acafe_customer/features/pos/pos_shell.dart';
import 'package:acafe_customer/features/pos/providers/pos_session_provider.dart';
import 'package:acafe_customer/features/pos/screens/pos_payment_selection_screen.dart';
import 'package:acafe_customer/features/pos/widgets/pos_cash_panel.dart';
import 'package:acafe_customer/features/pos/widgets/pos_keypad.dart';
import 'package:acafe_customer/features/pos/widgets/pos_payment_method_card.dart';
import 'package:acafe_customer/features/pos/widgets/pos_receipt_line.dart';
import 'package:acafe_customer/features/pos/widgets/pos_top_nav_bar.dart';
import 'package:acafe_customer/features/pos/widgets/pos_declined_card.dart';
import 'package:acafe_customer/features/pos/widgets/pos_waiting_card.dart';
import 'package:acafe_customer/features/splash/domain/reposotories/splash_repo.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/main.dart' show navigatorKey;
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/kiosk_layout_harness.dart';

/// Payment selection — Figma 1641:2757.
///
/// The screen is mounted under a plain [MaterialApp]: every `context.go` on it
/// lives inside a tap callback, so no router is needed to render it. Routing
/// itself is covered by pos_navigation_test.dart.

Future<void> _loadFonts() async {
  final loader = FontLoader('Loew');
  for (final path in const [
    'assets/fonts/Loew-Regular.ttf',
    'assets/fonts/Loew-Medium.ttf',
    'assets/fonts/Loew-Bold.ttf',
    'assets/fonts/Loew-ExtraBold.ttf',
  ]) {
    loader.addFont(File(path)
        .readAsBytes()
        .then((bytes) => ByteData.view(Uint8List.fromList(bytes).buffer)));
  }
  await loader.load();
}

CartModel _line(String name, double price, {int qty = 1, int id = 1}) =>
    CartModel(
      price,
      price,
      const [],
      0,
      qty,
      0,
      const [],
      Product(id: id, name: name, price: price),
      const [],
    );

Future<CartProvider> _pump(
  WidgetTester tester, {
  Size size = const Size(1366, 1024),
  List<CartModel> lines = const [],
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
  if (lines.isNotEmpty) cart.replaceCartList(lines);

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
        // The payment frame draws its own PosTopNavBar (Figma 1641:2758),
        // which reads the signed-in staff role. Owner keeps every tab
        // visible, matching what these tests otherwise assume by default.
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
            // The app's global key, so `Get.context` resolves and
            // showCustomSnackBarHelper can find a ScaffoldMessenger — the
            // outcome switch calls it on every non-success branch.
            navigatorKey: navigatorKey,
            home: const PosPaymentSelectionScreen(),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  return cart;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);
  setUp(() => PosSaleSession.instance.reset());
  tearDown(() => PosSaleSession.instance.reset());

  for (final size in const [
    Size(1280, 800), Size(1440, 900), Size(1920, 1080), Size(820, 1180),
  ]) {
    testWidgets('pay shot ${size.width.toInt()}', (tester) async {
      await _pump(tester, size: size,
          lines: [_line('Americano_200', 110.5)]);
      await tester.pump(const Duration(milliseconds: 300));
      final btn = tester.getRect(find.byType(PosSettingsSaveButton));
      final card = tester.getRect(find.byType(PosPaymentMethodCard).last);
      print('[${size.width.toInt()}] button=$btn methodCardRight=${card.right}');
      await tester.runAsync(() async {
        final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
        final ui.Image img = await layer.toImage(Offset.zero & size);
        final d = await img.toByteData(format: ui.ImageByteFormat.png);
        await File('$_out/pay_${size.width.toInt()}.png')
            .writeAsBytes(d!.buffer.asUint8List());
      });
      expect(tester.takeException(), isNull);
    });
  }
}
const String _out = String.fromEnvironment('OUT');
