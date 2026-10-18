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
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_invoice_model.dart';
import 'package:acafe_customer/features/pos/domain/pos_payment_spec.dart';
import 'package:acafe_customer/features/pos/screens/pos_payment_selection_screen.dart';
import 'package:acafe_customer/features/pos/widgets/pos_invoice_panel.dart';
import 'package:acafe_customer/features/pos/widgets/pos_standalone_panel.dart';
import 'package:acafe_customer/features/pos/widgets/pos_pay_shell.dart';
import 'package:acafe_customer/features/pos/widgets/pos_payment_method_selector.dart';
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

/// Mounts [home] under the providers and the production theme the payment
/// screen runs with.
Future<CartProvider> pumpPaymentApp(
  WidgetTester tester,
  Widget Function(SharedPreferences prefs) home, {
  Size size = const Size(1366, 1024),
  List<CartModel>? lines,
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
            home: home(prefs),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  return cart;
}

Future<void> pumpPaymentScreen(
  WidgetTester tester, {
  Size size = const Size(1366, 1024),
  List<CartModel>? lines,
  PosPaymentMethod method = PosPaymentMethod.card,
}) async {
  PosSaleSession.instance.customerName.text = 'Dylan';
  PosSaleSession.instance.paymentMethod = method;
  await pumpPaymentApp(
    tester,
    (prefs) => PosPaymentSelectionScreen(sharedPreferences: prefs),
    size: size,
    lines: lines,
  );
}

/// The payment screen's chrome composed from the same public pieces the
/// screen builds it from — for the OTHER-mode frames, whose state is only
/// reachable after a live order placement.
Future<void> pumpComposedFrame(
  WidgetTester tester, {
  required Widget Function(bool fill) summary,
  bool invoiceActive = false,
  bool standaloneActive = false,
  bool splitActive = false,
  bool splitByItemActive = false,
  Widget? bar,
  String backLabel = 'Dylan / € 19.00',
  List<CartModel>? lines,
}) async {
  final List<CartModel> ticket = lines ?? figmaTicket();
  final name = TextEditingController(text: 'Dylan');
  final table = TextEditingController();
  addTearDown(name.dispose);
  addTearDown(table.dispose);
  await pumpPaymentApp(
    tester,
    lines: ticket,
    (_) => Scaffold(
      backgroundColor: PosHomeSpec.pageBg,
      body: PosPayTextScope(
        child: SafeArea(
          child: Column(
            children: [
              PosPayBackRow(onBack: () {}, label: backLabel),
              Expanded(
                child: PosPayThreePane(
                  receipt: (fill) => PosPayReceiptCard(
                    fill: fill,
                    lines: ticket,
                    hasItems: ticket.isNotEmpty,
                    imageBaseUrl: null,
                    dealImageBaseUrl: null,
                    orderNumber: null,
                    customerNameController: name,
                    tableController: table,
                    onIncrement: (_) {},
                    onDecrement: (_) {},
                    onOptions: (_) {},
                  ),
                  method: (fill) {
                    final Widget selector = PosPaymentMethodSelector(
                      method: PosPaymentMethod.card,
                      cashEnabled: true,
                      cardEnabled: true,
                      onSelectMethod: (_) {},
                      onSplitByPayment: () {},
                      splitActive: splitActive,
                      onSplitByItem: () {},
                      splitByItemActive: splitByItemActive,
                      onInvoice: () {},
                      invoiceActive: invoiceActive,
                      onStandalone: () {},
                      standaloneActive: standaloneActive,
                      onCancelActiveOther: () {},
                    );
                    return PosPayCard(
                      padding: const EdgeInsets.all(
                          PosPaymentSpec.v2MethodCardPadding),
                      child: fill
                          ? SingleChildScrollView(child: selector)
                          : selector,
                    );
                  },
                  summary: summary,
                ),
              ),
              if (bar != null) bar,
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> expectFrame(WidgetTester tester, String name) async {
  await expectLater(
      find.byType(MaterialApp), matchesGoldenFile('goldens/payment_audit/$name.png'));
}

/// Composed frames, keyed by golden name. Also driven by the measuring probe.
final Map<String, Future<void> Function(WidgetTester)> auditFrames = {
  '03_invoice': (tester) async {
    final form = PosInvoiceFormState();
    addTearDown(form.dispose);
    form.companyName.value = 'Matcha Studio BV';
    form.vatNumber.value = 'NL123456789B01';
    form.email.value = 'finance@matchastudio.nl';
    form.sendByEmail.value = true;
    await pumpComposedFrame(
      tester,
      invoiceActive: true,
      summary: (_) => PosPayCard(
        child: PosInvoicePanel(
          grandTotal: 19,
          form: form,
          loading: false,
          onSubmit: () {},
        ),
      ),
      bar: PosPayPillBar(label: 'Confirm Payment', onConfirm: () {}),
    );
  },
  '04_standalone': (tester) async {
    final code = ValueNotifier<String>('');
    addTearDown(code.dispose);
    await pumpComposedFrame(
      tester,
      standaloneActive: true,
      summary: (_) => PosPayCard(
        child: PosStandalonePanel(
          grandTotal: 19,
          approvalCode: code,
          loading: false,
          onConfirm: () {},
        ),
      ),
      bar: PosPayPillBar(label: 'Confirm Payment', onConfirm: () {}),
    );
  },
};

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

  for (final entry in auditFrames.entries) {
    testWidgets('frame ${entry.key}', (tester) async {
      await entry.value(tester);
      await expectFrame(tester, entry.key);
    });
  }
}
