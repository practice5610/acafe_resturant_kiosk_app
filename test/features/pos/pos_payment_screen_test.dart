import 'dart:io';

import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:acafe_customer/features/cart/domain/reposotories/cart_repo.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/coupon/providers/coupon_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_auth_repo.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_payment_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_sale_session.dart';
import 'package:acafe_customer/features/pos/pos_shell.dart';
import 'package:acafe_customer/features/pos/screens/pos_payment_selection_screen.dart';
import 'package:acafe_customer/features/pos/widgets/pos_payment_method_card.dart';
import 'package:acafe_customer/features/pos/widgets/pos_receipt_line.dart';
import 'package:acafe_customer/features/pos/widgets/pos_top_nav_bar.dart';
import 'package:acafe_customer/features/splash/domain/reposotories/splash_repo.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
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
      ],
      child: MediaQuery(
        data: MediaQueryData(size: size),
        child: PosShell(
          child: const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: PosPaymentSelectionScreen(),
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

  testWidgets('the 1366 frame paints both cards and the sticky bar',
      (tester) async {
    await _pump(tester, lines: [_line('Oat Milk Matcha', 6)]);

    expect(find.text('Purchase Receipt'), findsOneWidget);
    expect(find.text('Order list'), findsOneWidget);
    expect(find.text('SELECT PAYMENT METHOD'), findsOneWidget);
    expect(find.text('Confirm Payment'), findsOneWidget);
    // Figma draws the nav bar on this frame (1641:2758).
    expect(find.byType(PosTopNavBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('order lines come from the cart and drop EDIT', (tester) async {
    await _pump(tester, lines: [
      _line('Oat Milk Matcha', 6),
      _line('Mango Matcha', 7, id: 2),
    ]);

    expect(find.byType(PosReceiptLine), findsNWidgets(2));
    expect(find.text('Oat Milk Matcha'), findsOneWidget);
    expect(find.text('Mango Matcha'), findsOneWidget);
    // Customising a line belongs to the counter screen, not the till.
    expect(find.text('EDIT'), findsNothing);
    // Quantity control survives, so a mistake is still fixable here.
    expect(find.byKey(const Key('pos-qty-plus')), findsNWidgets(2));
  });

  testWidgets('totals are the cart totals, not literals', (tester) async {
    await _pump(tester, lines: [
      _line('Oat Milk Matcha', 6, qty: 2),
      _line('Mango Matcha', 7, id: 2),
    ]);

    expect(find.text('Subtotal'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    expect(find.text(PosHomeSpec.formatPrice(19)), findsNWidgets(2));
    // No discount applied, so the row is absent rather than showing zero.
    expect(find.text('Discount'), findsNothing);
  });

  testWidgets('the customer name and table survive the route change',
      (tester) async {
    PosSaleSession.instance.customerName.text = 'Dylan';
    PosSaleSession.instance.table.text = 'B1';

    await _pump(tester, lines: [_line('Oat Milk Matcha', 6)]);

    expect(find.text('Dylan'), findsOneWidget);
    expect(find.text('B1'), findsOneWidget);
  });

  testWidgets('exactly one method is selected and the choice sticks',
      (tester) async {
    await _pump(tester, lines: [_line('Oat Milk Matcha', 6)]);

    PosPaymentMethodCard cardFor(PosPaymentMethod m) => tester
        .widgetList<PosPaymentMethodCard>(find.byType(PosPaymentMethodCard))
        .firstWhere((w) => w.method == m);

    // Figma paints Card as the active method.
    expect(cardFor(PosPaymentMethod.card).selected, isTrue);
    expect(cardFor(PosPaymentMethod.cash).selected, isFalse);

    await tester.tap(find.text('Cash'));
    await tester.pump();

    expect(cardFor(PosPaymentMethod.cash).selected, isTrue);
    expect(cardFor(PosPaymentMethod.card).selected, isFalse);
    expect(PosSaleSession.instance.paymentMethod, PosPaymentMethod.cash);

    // A rebuild driven by cart state must not reset it.
    tester
        .element(find.byType(PosPaymentSelectionScreen))
        .read<CartProvider>()
        .replaceCartList([_line('Oat Milk Matcha', 6, qty: 3)]);
    await tester.pump();
    expect(cardFor(PosPaymentMethod.cash).selected, isTrue);
  });

  testWidgets('a long ticket scrolls instead of overflowing', (tester) async {
    await _pump(tester, lines: [
      for (int i = 0; i < 25; i++) _line('Matcha $i', 6, id: i + 1),
    ]);

    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(PosReceiptLine).first, const Offset(0, -300));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a narrow window stacks the cards and still scrolls',
      (tester) async {
    await _pump(
      tester,
      size: const Size(760, 1024),
      lines: [for (int i = 0; i < 12; i++) _line('Matcha $i', 6, id: i + 1)],
    );

    expect(find.text('SELECT PAYMENT METHOD'), findsOneWidget);
    expect(find.text('Confirm Payment'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.drag(
        find.byType(SingleChildScrollView).first, const Offset(0, -400));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty cart cannot confirm a payment', (tester) async {
    await _pump(tester);

    expect(find.text('No items'), findsOneWidget);
    final InkWell confirm = tester.widget<InkWell>(
      find.ancestor(
        of: find.text('Confirm Payment'),
        matching: find.byType(InkWell),
      ),
    );
    expect(confirm.onTap, isNull);
  });

  testWidgets('the sticky bar keeps its Figma height', (tester) async {
    await _pump(tester, lines: [_line('Oat Milk Matcha', 6)]);

    final Size button = tester.getSize(
      find.ancestor(
        of: find.text('Confirm Payment'),
        matching: find.byType(SizedBox),
      ).first,
    );
    expect(button.height, PosPaymentSpec.confirmHeight);
  });
}
