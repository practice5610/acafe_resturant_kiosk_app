import 'dart:io';

import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:acafe_customer/features/cart/domain/reposotories/cart_repo.dart';
import 'package:acafe_customer/features/branch/providers/branch_provider.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/coupon/providers/coupon_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_auth_repo.dart';
import 'package:acafe_customer/features/language/providers/localization_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_manager_repo.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/pos/domain/pos_routes.dart';
import 'package:acafe_customer/features/pos/domain/pos_sale_session.dart';
import 'package:acafe_customer/features/pos/pos_shell.dart';
import 'package:acafe_customer/features/pos/providers/pos_session_provider.dart';
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_invoice_model.dart';
import 'package:acafe_customer/features/pos/domain/pos_payment_spec.dart';
import 'package:acafe_customer/features/pos/screens/pos_payment_selection_screen.dart';
import 'package:acafe_customer/features/pos/domain/pos_cash_denomination.dart';
import 'package:acafe_customer/features/pos/domain/pos_cash_entry.dart';
import 'package:acafe_customer/features/pos/domain/pos_split_by_item_builder.dart';
import 'package:acafe_customer/features/pos/domain/pos_split_by_item_model.dart';
import 'package:acafe_customer/features/pos/domain/pos_split_session.dart';
import 'package:acafe_customer/features/pos/widgets/pos_split_by_item_panel.dart';
import 'package:acafe_customer/features/pos/widgets/pos_fit_column.dart';
import 'package:acafe_customer/features/pos/widgets/pos_declined_card.dart';
import 'package:acafe_customer/common/models/api_response_model.dart';
import 'package:acafe_customer/di_container.dart' show sl;
import 'package:acafe_customer/features/pos/domain/pos_receipt_history.dart';
import 'package:acafe_customer/features/pos/domain/pos_refund_repo.dart';
import 'package:acafe_customer/features/pos/domain/pos_refund_session.dart';
import 'package:acafe_customer/features/pos/screens/pos_refund_screen.dart';
import 'package:acafe_customer/features/pos/widgets/pos_invoice_panel.dart';
import 'package:dio/dio.dart';
import 'package:acafe_customer/features/pos/widgets/pos_receipt_dialog.dart';
import 'package:acafe_customer/features/pos/widgets/pos_payment_error_card.dart';
import 'package:acafe_customer/features/pos/widgets/pos_payment_success_card.dart';
import 'package:acafe_customer/features/pos/widgets/pos_waiting_card.dart';
import 'package:acafe_customer/features/pos/widgets/pos_tip_dialog.dart';
import 'package:acafe_customer/features/pos/widgets/pos_keypad.dart';
import 'package:acafe_customer/features/pos/widgets/pos_split_summary_panel.dart';
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
import 'package:go_router/go_router.dart';
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
/// Window the audit frames render at; the responsive sweep changes it.
Size auditSize = const Size(1366, 1024);

Future<CartProvider> pumpPaymentApp(
  WidgetTester tester,
  Widget Function(SharedPreferences prefs) home, {
  Size? size,
  List<CartModel>? lines,
  bool routed = false,
}) async {
  size ??= auditSize;
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
        // The receipt settings read the app's language (auto-print check).
        ChangeNotifierProvider<LocalizationProvider>(
          create: (_) =>
              LocalizationProvider(sharedPreferences: prefs, dioClient: dio),
        ),
        // The cart's storage key reads the branch (clearing it after a sale).
        ChangeNotifierProvider<BranchProvider>(
          create: (_) => BranchProvider(
            splashRepo: SplashRepo(dioClient: dio, sharedPreferences: prefs),
          ),
        ),
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
          child: routed
              // Flow tests: the screen leaves with `context.go`, so it runs
              // under a router whose other destinations are named stubs.
              ? MaterialApp.router(
                  debugShowCheckedModeBanner: false,
                  theme: light,
                  routerConfig: GoRouter(
                    navigatorKey: navigatorKey,
                    initialLocation: '/pay',
                    routes: [
                      GoRoute(path: '/pay', builder: (_, __) => home(prefs)),
                      GoRoute(
                        path: PosRoutes.refund,
                        builder: (_, __) => const PosRefundScreen(),
                      ),
                      for (final String stub in [
                        PosRoutes.home,
                        PosRoutes.receipts,
                      ])
                        GoRoute(
                          path: stub,
                          builder: (_, __) =>
                              Scaffold(body: Text('ROUTE $stub')),
                        ),
                    ],
                  ),
                )
              : MaterialApp(
                  debugShowCheckedModeBanner: false,
                  // The production theme, so inherited text styles match the
                  // app.
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
  Size? size,
  List<CartModel>? lines,
  PosPaymentMethod method = PosPaymentMethod.card,
  bool routed = false,
}) async {
  PosSaleSession.instance.customerName.text = 'Dylan';
  PosSaleSession.instance.paymentMethod = method;
  await pumpPaymentApp(
    tester,
    (prefs) => PosPaymentSelectionScreen(sharedPreferences: prefs),
    size: size,
    lines: lines,
    routed: routed,
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
          child: PosPayCanvas(
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
                          ? PosFitColumn(children: [selector])
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
  '05_split_enter': (t) => _splitFrame(t, paid: const [], typed: ''),
  '09_split_p2': (t) => _splitFrame(t, paid: const [(9.0, 'card')], typed: ''),
  '10_split_p2_cash': (t) => _splitFrame(t,
      paid: const [(9.0, 'card')],
      typed: '20',
      cash: true,
      denomination: const PosCashDenomination.note(2000)),
  '11_split_p3': (t) => _splitFrame(t,
      paid: const [(9.0, 'card'), (5.0, 'cash')], typed: ''),
  '12_split_p4': (t) => _splitFrame(t,
      paid: const [(9.0, 'card'), (5.0, 'card'), (2.0, 'card')],
      typed: '3.00'),
  // "Add tip" — no frame in the layer; built on the Apply-discount modal
  // (1915:14411). Opened through the real screen.
  'tip_modal_preset': (t) => _tipFrame(t, (t) async {
        await _tapVisible(t, _inTip('10%'));
      }),
  'tip_modal_custom_error': (t) => _tipFrame(t, (t) async {
        for (final k in ['2', '5']) {
          await _tapVisible(
              t,
              find.descendant(
                  of: find.byType(PosTipModal),
                  matching: find.descendant(
                      of: find.byType(PosKeypad), matching: find.text(k))));
        }
      }),
  '13_split_chooser': (t) => pumpComposedFrame(
        t,
        splitByItemActive: true,
        summary: (fill) => PosPayCard(
          borderColor: PosSplitSummaryPanel.borderColor,
          borderWidth: PosSplitSummaryPanel.borderWidth,
          child: PosSplitChooserPanel(
            grandTotal: 19,
            choice: PosSplitChoice.byItem,
            onChoice: (_) {},
            fill: fill,
          ),
        ),
        bar: PosPayPillBar(label: 'Continue', onConfirm: () {}),
      ),
  '15_sbi_cash': (t) => pumpComposedFrame(
        t,
        splitByItemActive: true,
        summary: (fill) => PosPayCard(
          borderColor: PosSplitSummaryPanel.borderColor,
          borderWidth: PosSplitSummaryPanel.borderWidth,
          child: PosSplitSummaryPanel(
            grandTotal: 19,
            remaining: 19,
            paid: const [],
            subtitle: 'By item · Oat Milk Matcha, Vanilla Matcha Latte',
            entryLabel: 'PAYMENT 1 · AMOUNT DUE € 12.00',
            changeBaseCents: 1200,
            tipRowHeight: PosPaymentSpec.v2SplitTipRowHeight,
            entry: const PosCashEntry().key('2').key('0'),
            splitMethod: PosPaymentMethod.cash,
            onSplitMethod: (_) {},
            onKey: (_) {},
            onBackspace: () {},
            onDenomination: (_) {},
            selectedDenomination: const PosCashDenomination.note(2000),
            fill: fill,
          ),
        ),
        bar: PosPayPillBar(
            label: 'Confirm Payment · € 12.00', onConfirm: () {}),
      ),
  '19_split_custom': (t) =>
      _splitFrame(t, paid: const [], typed: '8,50', custom: true),
  '14_sbi_select': (t) => _sbiFrame(t,
      items: _sbiTicket,
      selected: {0, 1},
      method: PosPaymentMethod.cash),
  '16_sbi_p2': (t) => _sbiFrame(t,
      items: _sbiTicket,
      selected: {2},
      paid: const PosSplitByItemGroup(
          id: 201,
          seq: 1,
          itemIds: [0, 1],
          amount: 12,
          paidWith: 'cash',
          paidAmount: 12,
          reference: 'r1')),
  '20_sbi_six': (t) => _sbiFrame(t,
      items: const [
        PosSplitByItemLineItem(id: 0, name: 'Oat Milk Matcha', detail: '', price: 6),
        PosSplitByItemLineItem(id: 1, name: 'Vanilla Matcha Latte', detail: '', price: 6),
        PosSplitByItemLineItem(id: 2, name: 'Mango Matcha', detail: '', price: 7),
        PosSplitByItemLineItem(id: 3, name: 'Iced Americano', detail: '', price: 3.5),
        PosSplitByItemLineItem(id: 4, name: 'Butter Croissant', detail: '', price: 3.2),
        PosSplitByItemLineItem(id: 5, name: 'Banana Bread', detail: '', price: 4.2),
      ],
      selected: {0, 1},
      total: 29.9,
      backLabel: 'Dylan / € 29.90',
      method: PosPaymentMethod.cash),
  '06_waiting': (t) => pumpOverlayFrame(
      t, PosWaitingCard(amountDue: 9, onCancel: () {})),
  '07_declined': (t) => pumpOverlayFrame(t,
      PosDeclinedCard(amountDue: 9, onCancel: () {}, onTryAgain: () {})),
  '08_split_success': (t) => pumpOverlayFrame(
      t,
      PosPaymentSuccessCard(
        title: 'Split Payment 1 Successful',
        amount: 9,
        buttonLabel: 'Start next payment',
        onContinue: () {},
      )),
  '18a_receipt_email': (t) => _receiptFrame(t, print: false),
  '18b_receipt_print': (t) => _receiptFrame(t, print: true),
  '25_refund_select': (t) => _refundFrame(t, step: 25),
  '26_refund_method': (t) => _refundFrame(t, step: 26),
  '26b_refund_method_last4_credit': (t) =>
      _refundFrame(t, step: 26, backendData: true),
  '27_refund_waiting': (t) => _refundFrame(t, step: 27),
  '28_refund_complete': (t) => _refundFrame(t, step: 28),
  '29_refund_split_confirm': (t) => _refundFrame(t, step: 29, split: true),
  '30_refund_split_done': (t) => _refundFrame(t, step: 30, split: true),
  '22_terminal_offline': (t) => pumpOverlayFrame(
      t,
      PosPaymentErrorCard.terminalOffline(
          amountDue: 9, onCancel: () {}, onRetry: () {})),
  '23_timed_out': (t) => pumpOverlayFrame(
      t,
      PosPaymentErrorCard.timedOut(
          amountDue: 9, onCancel: () {}, onTryAgain: () {})),
  '24_cash_too_low': (t) => pumpOverlayFrame(
      t,
      PosPaymentErrorCard.cashTooLow(
          received: 5.7, total: 9, onBack: () {}, onAddCash: () {})),
  '18_order_paid': (t) => pumpOverlayFrame(
      t,
      PosPaymentSuccessCard(
        title: 'Order Paid',
        amount: 19,
        amountLabel: 'TOTAL PAID',
        secondaryLabel: 'Receipt',
        onSecondary: () {},
        buttonLabel: 'Next order',
        onContinue: () {},
      )),
};

const List<PosSplitByItemLineItem> _sbiTicket = [
  PosSplitByItemLineItem(id: 0, name: 'Oat Milk Matcha', detail: 'Cup', price: 6),
  PosSplitByItemLineItem(
      id: 1, name: 'Vanilla Matcha Latte', detail: 'Can', price: 6),
  PosSplitByItemLineItem(id: 2, name: 'Mango Matcha', detail: 'Cup', price: 7),
];

/// Split-by-item frames: [items] with [selected] ticked, after [paid].
Future<void> _sbiFrame(
  WidgetTester tester, {
  required List<PosSplitByItemLineItem> items,
  required Set<int> selected,
  PosSplitByItemGroup? paid,
  double total = 19,
  String backLabel = 'Dylan / € 19.00',
  PosPaymentMethod method = PosPaymentMethod.card,
}) async {
  final groups = PosSplitByItemGroupsBuilder(groupSeq: paid == null ? 1 : 2);
  addTearDown(groups.dispose);
  for (final id in selected) {
    groups.toggleItem(id);
  }
  final double remaining = total - (paid?.paidAmount ?? 0);
  await pumpComposedFrame(
    tester,
    splitByItemActive: true,
    backLabel: backLabel,
    summary: (fill) => PosPayCard(
      borderColor: PosSplitSummaryPanel.borderColor,
      borderWidth: PosSplitSummaryPanel.borderWidth,
      child: PosSplitByItemPanel(
        groupSeq: paid == null ? 1 : 2,
        grandTotal: total,
        remaining: remaining,
        lineItems: items,
        groupBuilder: groups,
        paymentMethod: method,
        onToggleItem: (_) {},
        onPaymentMethodChanged: (_) {},
        groups: [if (paid != null) paid],
        onRefund: (_) {},
        fill: fill,
      ),
    ),
    bar: PosPayPillBar(
      label: 'Start Payment ${paid == null ? 1 : 2}'
          ' · ${PosHomeSpec.formatPrice(groups.value.calculateAmount(items), padZero: false)}',
      onConfirm: () {},
    ),
  );
  // Let the scrollbar thumb finish fading in.
  await tester.pump(const Duration(seconds: 1));
}

Finder _inTip(String text) =>
    find.descendant(of: find.byType(PosTipModal), matching: find.text(text));

/// Taps [f] the way an operator reaches it: on a short window the panes stack
/// into one scroll, so scroll to it first.
Future<void> _tapVisible(WidgetTester tester, Finder f) async {
  if (f.evaluate().isEmpty) {
    final Finder panes = find.descendant(
        of: find.byType(PosPayThreePane), matching: find.byType(Scrollable));
    if (panes.evaluate().isNotEmpty) {
      await tester.scrollUntilVisible(f, 200, scrollable: panes.first);
    }
  }
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

/// The payment screen with the tip modal open, then [then] applied.
Future<void> _tipFrame(WidgetTester tester,
    Future<void> Function(WidgetTester) then) async {
  await pumpPaymentScreen(tester);
  await _tapVisible(tester, find.text('Add tip'));
  await then(tester);
}

/// Frames 18a / 18b: the receipt options over the "Order Paid" card.
Future<void> _receiptFrame(WidgetTester tester, {required bool print}) async {
  await pumpOverlayFrame(
    tester,
    Stack(
      children: [
        PosPaymentSuccessCard(
          title: 'Order Paid',
          amount: 19,
          amountLabel: 'TOTAL PAID',
          secondaryLabel: 'Receipt',
          onSecondary: () {},
          buttonLabel: 'Next order',
          onContinue: () {},
        ),
        const Positioned.fill(
          child: ColoredBox(color: PosPaymentSpec.v2DialogScrim),
        ),
        PosReceiptDialog(
          orderId: 27362,
          total: 19,
          deviceId: 1,
          onComplete: () {},
          onSkip: () {},
        ),
      ],
    ),
  );
  if (print) {
    await tester.tap(find.text('Print'));
  } else {
    await tester.enterText(find.byType(TextField), 'dylan@example.com');
  }
  await tester.pump();
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump(const Duration(milliseconds: 300));
}

/// Answers the refund endpoints like the backend does for the Dylan order.
class _FakeRefundRepo extends PosRefundRepo {
  _FakeRefundRepo(DioClient dio) : super(dioClient: dio);

  static ApiResponseModel _ok(Map<String, dynamic> data) =>
      ApiResponseModel.withSuccess(Response<dynamic>(
        requestOptions: RequestOptions(path: ''),
        statusCode: 200,
        data: data,
      ));

  static const Map<String, dynamic> _ledger = {
    'refundable_remaining': 19.0,
    'refunds': <dynamic>[],
  };

  @override
  Future<ApiResponseModel> list({
    required int orderId,
    required int deviceId,
  }) async =>
      _ok(_ledger);

  @override
  Future<ApiResponseModel> create({
    required int orderId,
    required int deviceId,
    required String reference,
    String? reason,
    List<int>? itemsJson,
    int? partialPaymentId,
    int? splitGroupId,
  }) async {
    // Like RefundController: the whole remaining balance of the source.
    final int? source = partialPaymentId ?? splitGroupId;
    final PosRefundSplit? split = source == null
        ? null
        : PosRefundSession.instance.splits.firstWhere((s) => s.id == source);
    return _ok({
      'refund_id': 1,
      'refund_seq': 1,
      'amount': posRefundableAmount(ledger: _ledger, split: split),
      'method': split?.method ?? 'card',
    });
  }

  @override
  Future<ApiResponseModel> confirm({
    required int orderId,
    required int refundSeq,
    required String method,
    required String reference,
    required int deviceId,
    String? approvalCode,
  }) async =>
      _ok({'ok': true});
}

/// Refund frames 25–30: the real [PosRefundScreen], driven step by step.
Future<void> _refundFrame(WidgetTester tester,
    {required int step, bool split = false, bool backendData = false}) async {
  final session = PosRefundSession.instance;
  session.reset();
  addTearDown(session.reset);
  session.order = PosReceiptDetail(
    id: 27362,
    placedAt: null,
    customerName: 'Dylan',
    table: null,
    method: 'card',
    subtotal: 19,
    discount: 0,
    total: 19,
    orderStatus: 'delivered',
    paymentStatus: 'paid',
    lines: figmaTicket(),
    // Frame 26 as Figma draws it, once the backend sends these (B5).
    cardLast4: backendData ? '4242' : null,
    storeCreditAvailable: backendData,
  );
  // Frames 29 / 30: one paid payment of a sale in progress, opened from its
  // Refund pill — Payment 1 of frame 16 (cash, the two lattes).
  session.splits = split
      ? const [
          PosRefundSplit(
            id: 11,
            seq: 1,
            method: 'cash',
            amount: 12,
            itemGroup: true,
            items: 'Oat Milk Matcha, Vanilla Matcha Latte',
          ),
        ]
      : const [];
  session.fromPayment = split;
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  if (sl.isRegistered<PosRefundRepo>()) sl.unregister<PosRefundRepo>();
  sl.registerSingleton<PosRefundRepo>(_FakeRefundRepo(DioClient(
    'http://localhost',
    null,
    loggingInterceptor: LoggingInterceptor(),
    sharedPreferences: prefs,
  )));
  addTearDown(() => sl.unregister<PosRefundRepo>());

  await pumpPaymentApp(tester, (_) => const PosRefundScreen());
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  if (split) {
    // Opens on frame 29 with the backend's quote.
    await tester.pump();
    if (step == 29) return;
    await tester.tap(find.text('Refund € 12.00'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    return;
  }

  // The screen clears the flow on entry; pick as the frames show.
  session.selectedItemIndices.value = {0};
  session.reason.value = PosRefundReason.customerChanged;
  await tester.pump();
  if (step == 25) return;

  // On a narrow window the panes stack into one scroll; bring each control
  // into view before tapping it, as an operator would.
  Future<void> tap(Finder f) async {
    final Finder panes = find.descendant(
        of: find.byType(PosPayThreePane), matching: find.byType(Scrollable));
    if (f.evaluate().isEmpty && panes.evaluate().isNotEmpty) {
      await tester.scrollUntilVisible(f, 200, scrollable: panes.first);
    }
    await tester.ensureVisible(f);
    await tester.pump();
    await tester.tap(f);
  }

  await tap(find.text('Continue to refund method'));
  await tester.pump();
  await tap(find.text('Original payment'));
  await tester.pump();
  if (step == 26) return;

  await tap(find.textContaining('Confirm refund'));
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  if (step == 27) return;

  await tap(find.text('Confirm Refund'));
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

/// A full-screen state: [card] alone on the page background, as the screen
/// shows the waiting / declined cards (no back row) and the success dialogs
/// (opaque page-coloured barrier).
Future<void> pumpOverlayFrame(WidgetTester tester, Widget card) =>
    pumpPaymentApp(
      tester,
      (_) => Scaffold(
        backgroundColor: PosHomeSpec.pageBg,
        body: PosPayCanvas(
          child: PosPayTextScope(
            child: Material(type: MaterialType.transparency, child: card),
          ),
        ),
      ),
    );

/// Split-by-payment frames: the Dylan € 19.00 order with [paid] already taken.
Future<void> _splitFrame(
  WidgetTester tester, {
  required List<(double, String)> paid,
  required String typed,
  bool cash = false,
  PosCashDenomination? denomination,
  bool custom = false,
}) async {
  final double paidSum = paid.fold(0.0, (a, p) => a + p.$1);
  final state = PosSplitState(
    orderId: 27362,
    deviceId: 1,
    grandTotal: 19,
    payments: [
      for (int i = 0; i < paid.length; i++)
        PosSplitPayment(
          // With an id (backend-needs B3) a paid row carries its Refund pill,
          // as frames 09–12 draw it.
          id: 100 + i,
          seq: i + 1,
          paidWith: paid[i].$2,
          paidAmount: paid[i].$1,
          reference: 'r$i',
        ),
    ],
    paid: paidSum,
    remaining: 19 - paidSum,
    fullyPaid: false,
  );
  PosCashEntry entry = const PosCashEntry();
  for (final c in typed.split('')) {
    entry = entry.key(c);
  }
  await pumpComposedFrame(
    tester,
    splitActive: !custom,
    splitByItemActive: custom,
    summary: (fill) => PosPayCard(
      borderColor: PosSplitSummaryPanel.borderColor,
      borderWidth: PosSplitSummaryPanel.borderWidth,
      child: PosSplitSummaryPanel.forPayments(
        state: state,
        entry: entry,
        splitMethod: cash ? PosPaymentMethod.cash : PosPaymentMethod.card,
        onSplitMethod: (_) {},
        onKey: (_) {},
        onBackspace: () {},
        onDenomination: (_) {},
        selectedDenomination: denomination,
        fill: fill,
        customAmount: custom,
        onRefund: (_) {},
      ),
    ),
    bar: PosPayPillBar(
        label: 'Start Payment ${state.nextSequence}'
            '${custom && entry.cents > 0 ? ' · ${PosHomeSpec.formatPrice(entry.cents / 100, padZero: false)}' : ''}',
        onConfirm: () {}),
  );
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

  for (final entry in auditFrames.entries) {
    testWidgets('frame ${entry.key}', (tester) async {
      await entry.value(tester);
      await expectFrame(tester, entry.key);
    });
  }
}
