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
import 'package:acafe_customer/features/pos/domain/pos_method_change.dart';
import 'package:acafe_customer/features/pos/domain/pos_payment_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_sale_session.dart';
import 'package:acafe_customer/features/pos/pos_shell.dart';
import 'package:acafe_customer/features/pos/providers/pos_session_provider.dart';
import 'package:acafe_customer/features/pos/screens/pos_payment_selection_screen.dart';
import 'package:acafe_customer/features/pos/widgets/pos_cash_panel.dart'
    show PosCashDenomination;
import 'package:acafe_customer/features/pos/widgets/pos_keypad.dart';
import 'package:acafe_customer/features/pos/widgets/pos_pay_cash_panel.dart';
import 'package:acafe_customer/features/pos/widgets/pos_pay_shell.dart';
import 'package:acafe_customer/features/pos/widgets/pos_pay_summary_panel.dart';
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

  testWidgets('the 1366 frame paints both cards and the sticky bar',
      (tester) async {
    await _pump(tester, lines: [_line('Oat Milk Matcha', 6)]);

    expect(find.text('Purchase Receipt'), findsOneWidget);
    expect(find.text('Order list'), findsOneWidget);
    expect(find.text('PAYMENT METHOD'), findsOneWidget);
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

  testWidgets('the amount due is the cart total, not a literal', (tester) async {
    await _pump(tester, lines: [
      _line('Oat Milk Matcha', 6, qty: 2),
      _line('Mango Matcha', 7, id: 2),
    ]);

    // The redesigned summary pane shows the payable amount as one display
    // figure (PAYMENT AMOUNT), not the old Subtotal/Total rows (those live on
    // the home cart screen now). The figure is read from the cart.
    expect(find.text('PAYMENT AMOUNT'), findsOneWidget);
    expect(find.text('Amount due'), findsOneWidget);
    expect(
      tester
          .widget<PosPaySummaryPanel>(find.byType(PosPaySummaryPanel))
          .total,
      19,
    );
    expect(find.text(PosHomeSpec.formatPrice(19, padZero: false)), findsWidgets);
  });

  testWidgets('the customer name survives the route change', (tester) async {
    PosSaleSession.instance.customerName.text = 'Dylan';

    await _pump(tester, lines: [_line('Oat Milk Matcha', 6)]);

    // The receipt sidebar's customer-name field shows the carried-over name.
    // (The Table field was dropped in the Browse-POS receipt redesign; its
    // controller is retained but no longer rendered.)
    expect(find.text('Dylan'), findsOneWidget);
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

    // The receipt pane sits at the top of the stack; the pill CTA is pinned
    // below the scroll area.
    expect(find.text('Purchase Receipt'), findsOneWidget);
    expect(find.text('Confirm Payment'), findsOneWidget);
    expect(find.byType(PosPayThreePane), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Below the desktop floor the three panes stack into one scroll
    // (PosPayThreePane's ListView, which builds lazily). The method pane sits
    // under the tall receipt and comes into view on scroll — proving the
    // stack scrolls without overflowing.
    await tester.scrollUntilVisible(
      find.text('PAYMENT METHOD'),
      400,
      scrollable: find
          .descendant(
            of: find.byType(PosPayThreePane),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('PAYMENT METHOD'), findsOneWidget);
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

  testWidgets('the sticky bar is the full-width pill CTA', (tester) async {
    await _pump(tester, lines: [_line('Oat Milk Matcha', 6)]);

    // The CTA is now PosPayPillBar (node 1915:9516): a full-bleed pill, not
    // the old fixed-width compact button.
    expect(find.byType(PosPayPillBar), findsOneWidget);

    // The pill itself is 64 tall (node 1915:9517) and spans the content width
    // (window minus the bar's 32px side padding), rather than a fixed 360.
    final Size pill = tester.getSize(
      find.ancestor(
        of: find.text('Confirm Payment'),
        matching: find.byType(InkWell),
      ),
    );
    expect(pill.height, PosPaymentSpec.v2PillHeight);
    expect(pill.width, 1366 - PosPaymentSpec.v2BarPaddingH * 2);
  });

  // ── Cash payment method (Figma 1641:3751) ──────────────────────────────

  Future<void> selectCash(WidgetTester tester) async {
    await tester.tap(find.text('Cash'));
    await tester.pump();
  }

  Future<void> tapKey(WidgetTester tester, String label) async {
    await tester.tap(find.descendant(
      of: find.byType(PosKeypad),
      matching: find.text(label),
    ));
    await tester.pump();
  }

  bool confirmEnabled(WidgetTester tester) =>
      tester
          .widget<InkWell>(find.ancestor(
            of: find.text('Confirm Payment'),
            matching: find.byType(InkWell),
          ))
          .onTap !=
      null;

  group('cash', () {
    testWidgets('the panel appears only for Cash', (tester) async {
      await _pump(tester, lines: [_line('Oat Milk Matcha', 6)]);

      expect(find.byType(PosPayCashSummaryPanel), findsNothing,
          reason: 'Card is the default method and has no tender panel');

      await selectCash(tester);

      expect(find.byType(PosPayCashSummaryPanel), findsOneWidget);
      expect(find.text('Amount Tendered'), findsOneWidget);
      expect(find.text('Change Due'), findsOneWidget);
      expect(find.byType(PosKeypad), findsOneWidget);
      for (final String key in const ['1', '5', '9', '0', ',']) {
        expect(
            find.descendant(
              of: find.byType(PosKeypad),
              matching: find.text(key),
            ),
            findsOneWidget,
            reason: 'key $key');
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('opens with the exact total already tendered', (tester) async {
      await _pump(tester, lines: [_line('Oat Milk Matcha', 6)]);
      await selectCash(tester);

      expect(
          find.text(PosHomeSpec.formatPrice(6, padZero: false)), findsWidgets,
          reason: 'exact is the common case, so it is the default, not €0');
      expect(
        tester
            .widget<PosPayCashSummaryPanel>(find.byType(PosPayCashSummaryPanel))
            .selectedDenomination,
        const PosCashDenomination.exact(),
      );
      expect(confirmEnabled(tester), isTrue);
    });

    testWidgets('the keypad builds up the tendered amount', (tester) async {
      await _pump(tester, lines: [_line('Oat Milk Matcha', 6)]);
      await selectCash(tester);

      // Cash opens pre-filled with the exact total; clear it first so the
      // keypad is building up a manual amount from scratch.
      await tester.tap(find.bySemanticsLabel('Clear amount tendered'));
      await tester.pump();
      expect(
          find.text(PosHomeSpec.formatPrice(0, padZero: false)), findsWidgets);

      await tapKey(tester, '2');
      await tapKey(tester, '0');
      expect(find.text(PosHomeSpec.formatPrice(20, padZero: false)),
          findsOneWidget);

      await tapKey(tester, ',');
      await tapKey(tester, '5');
      expect(find.text(PosHomeSpec.formatPrice(20.5, padZero: false)),
          findsOneWidget);
    });

    testWidgets('a quick chip sets the amount and lights up', (tester) async {
      await _pump(tester, lines: [_line('Oat Milk Matcha', 6)]);
      await selectCash(tester);

      await tester.tap(find.text('€ 20'));
      await tester.pump();

      expect(find.text(PosHomeSpec.formatPrice(20, padZero: false)),
          findsOneWidget);
      expect(
        tester
            .widget<PosPayCashSummaryPanel>(find.byType(PosPayCashSummaryPanel))
            .selectedDenomination,
        const PosCashDenomination.note(2000),
      );
    });

    testWidgets('Exact tenders the total and leaves no change', (tester) async {
      await _pump(tester, lines: [_line('Oat Milk Matcha', 6.5)]);
      await selectCash(tester);

      await tester.tap(find.text('Exact'));
      await tester.pump();

      expect(find.text(PosHomeSpec.formatPrice(6.5, padZero: false)),
          findsWidgets);
      // Change Due reads zero, and confirmation is open.
      expect(confirmEnabled(tester), isTrue);
    });

    testWidgets('only one chip is active, and typing clears the selection',
        (tester) async {
      await _pump(tester, lines: [_line('Oat Milk Matcha', 6)]);
      await selectCash(tester);

      await tester.tap(find.text('€ 20'));
      await tester.pump();
      await tester.tap(find.text('€ 50'));
      await tester.pump();

      expect(
        tester
            .widget<PosPayCashSummaryPanel>(find.byType(PosPayCashSummaryPanel))
            .selectedDenomination,
        const PosCashDenomination.note(5000),
        reason: 'the later chip wins; both must not be lit',
      );

      await tapKey(tester, '7');
      expect(
        tester
            .widget<PosPayCashSummaryPanel>(find.byType(PosPayCashSummaryPanel))
            .selectedDenomination,
        isNull,
        reason: 'manual entry clears the chip highlight',
      );
    });

    testWidgets('confirmation is blocked until the tender covers the total',
        (tester) async {
      await _pump(tester, lines: [_line('Oat Milk Matcha', 6)]);
      await selectCash(tester);

      // Clear the exact-tender default to exercise a manual, partial tender.
      await tester.tap(find.bySemanticsLabel('Clear amount tendered'));
      await tester.pump();
      expect(confirmEnabled(tester), isFalse, reason: 'nothing tendered');

      await tapKey(tester, '5');
      expect(confirmEnabled(tester), isFalse, reason: '€5 against a €6 total');

      await tapKey(tester, '0');
      expect(confirmEnabled(tester), isTrue, reason: '€50 covers it');
    });

    testWidgets('change due never shows a negative value', (tester) async {
      await _pump(tester, lines: [_line('Oat Milk Matcha', 6)]);
      await selectCash(tester);

      await tapKey(tester, '2');
      // €2 against a €6 total.
      expect(
          find.text(PosHomeSpec.formatPrice(0, padZero: false)), findsWidgets);
      // No negative figure anywhere (a minus next to a digit or the currency
      // symbol). Scoped to numbers so it does not trip over "Stand-alone".
      expect(find.textContaining(RegExp(r'-\s*\d')), findsNothing);
      expect(find.textContaining(RegExp(r'€\s*-')), findsNothing);
    });

    testWidgets('change due is exact for the classic float case',
        (tester) async {
      // 25.00 - 16.70; in doubles that is 8.299999999999999.
      await _pump(tester, lines: [_line('Matcha', 16.70)]);
      await selectCash(tester);

      await tester.tap(find.text('€ 20'));
      await tester.pump();

      expect(find.text(PosHomeSpec.formatPrice(3.30, padZero: false)),
          findsOneWidget);
    });

    testWidgets(
        'switching to Card drops the tender, switching back re-defaults to Exact',
        (tester) async {
      await _pump(tester, lines: [_line('Oat Milk Matcha', 6)]);
      await selectCash(tester);
      await tester.tap(find.text('€ 20'));
      await tester.pump();

      await tester.tap(find.text('Card'));
      await tester.pump();

      expect(find.byType(PosPayCashSummaryPanel), findsNothing,
          reason: 'Card carries no tender panel at all');

      await selectCash(tester);

      // Back on Cash, the €20 chip is gone — the tender re-defaults to
      // Exact, not to whatever the operator had chosen before switching away.
      expect(
        tester
            .widget<PosPayCashSummaryPanel>(find.byType(PosPayCashSummaryPanel))
            .selectedDenomination,
        const PosCashDenomination.exact(),
      );
      expect(confirmEnabled(tester), isTrue);
    });

    testWidgets('the field clear button wipes the amount', (tester) async {
      await _pump(tester, lines: [_line('Oat Milk Matcha', 6)]);
      await selectCash(tester);
      await tester.tap(find.text('€ 20'));
      await tester.pump();
      expect(confirmEnabled(tester), isTrue);

      await tester.tap(find.bySemanticsLabel('Clear amount tendered'));
      await tester.pump();

      expect(
        tester.widget<PosPayCashSummaryPanel>(find.byType(PosPayCashSummaryPanel)).entry.isEmpty,
        isTrue,
      );
      expect(confirmEnabled(tester), isFalse);
    });

    testWidgets('the cash panel fits without overflow at 1366 and narrow',
        (tester) async {
      await _pump(tester, lines: [_line('Oat Milk Matcha', 6)]);
      await selectCash(tester);
      expect(tester.takeException(), isNull);

      await _pump(tester,
          size: const Size(820, 1180), lines: [_line('Oat Milk Matcha', 6)]);
      await selectCash(tester);
      expect(tester.takeException(), isNull);
    });
  });

  // ── Waiting for payment (Figma 1641:4203) ──────────────────────────────

  group('waiting for payment', () {
    late _FakeTerminal terminal;

    setUp(() {
      terminal = _FakeTerminal();
      if (sl.isRegistered<KioskPaymentService>()) {
        sl.unregister<KioskPaymentService>();
      }
      sl.registerSingleton<KioskPaymentService>(terminal);
    });

    tearDown(() {
      if (sl.isRegistered<KioskPaymentService>()) {
        sl.unregister<KioskPaymentService>();
      }
    });

    /// Resolves the terminal and lets the outcome reach the widget tree.
    ///
    /// `pumpAndSettle` is unusable here — the dot indicator's ticker repeats
    /// forever, so the tree never quiesces. And a plain `pump` is not enough
    /// either: completing the payment future starts a chain of awaits
    /// (`pay` -> `posConfirmPayment` -> `_confirm` -> `setState`) that only
    /// unwinds on a real async turn.
    Future<void> settleTerminal(
        WidgetTester tester, void Function() complete) async {
      await tester.runAsync(() async {
        complete();
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      // Two frames: the first drains the fake-zone continuations the real-zone
      // completion queued, the second renders what they changed.
      await tester.pump();
      await tester.pump();
    }

    /// Confirms a card payment and stops on the waiting state — the fake
    /// terminal holds its future open until the test decides otherwise.
    Future<CartProvider> startCardPayment(WidgetTester tester,
        {Size size = const Size(1366, 1024)}) async {
      final CartProvider cart = await _pump(
        tester,
        size: size,
        lines: [_line('Oat Milk Matcha', 6), _line('Mango Matcha', 7, id: 2)],
      );
      await tester.tap(find.text('Confirm Payment'));
      await tester.pump();
      return cart;
    }

    testWidgets('the waiting card replaces the selector on Card confirm',
        (tester) async {
      await startCardPayment(tester);

      expect(find.byType(PosWaitingCard), findsOneWidget);
      expect(find.text('Waiting for payment...'), findsOneWidget);
      expect(find.text('AMOUNT DUE'), findsOneWidget);
      expect(find.text('Cancel Transaction'), findsOneWidget);

      // The selector and the sticky bar step aside; the header stays.
      expect(find.text('PAYMENT METHOD'), findsNothing);
      expect(find.text('Confirm Payment'), findsNothing);
      expect(find.byType(PosTopNavBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Amount Due is the real order total', (tester) async {
      await startCardPayment(tester);

      // €6 + €7, read from the cart rather than recomputed.
      expect(
        tester.widget<PosWaitingCard>(find.byType(PosWaitingCard)).amountDue,
        13,
      );
      // The figure renders on the waiting card and in the back-row caption
      // ("… / € 13.00"), both reading the same total.
      expect(find.text(PosHomeSpec.formatPrice(13, padZero: false)),
          findsNWidgets(2));
    });

    testWidgets('the dots animate without disturbing the rest of the screen',
        (tester) async {
      await startCardPayment(tester);

      expect(find.byType(PosWaitingDots), findsOneWidget);
      // The ticker keeps running; pumping frames must not throw or settle.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      expect(find.byType(PosWaitingCard), findsOneWidget);
    });

    testWidgets('back is withheld while the terminal has the payment',
        (tester) async {
      await startCardPayment(tester);

      expect(
        tester
            .widgetList<InkWell>(find.byType(InkWell))
            .where((w) => w.onTap != null)
            .length,
        1,
        reason: 'Cancel Transaction is the only live control',
      );
    });

    testWidgets('Cancel asks the terminal and shows it is working',
        (tester) async {
      await startCardPayment(tester);

      await tester.tap(find.text('Cancel Transaction'));
      await tester.pump();

      expect(terminal.cancelCalls, 1);
      expect(find.text('Cancelling...'), findsOneWidget);
      expect(
        tester.widget<PosWaitingCard>(find.byType(PosWaitingCard)).onCancel,
        isNull,
        reason: 'a second cancel must not reach the terminal',
      );
    });

    testWidgets('a cancelled payment returns to the selector, cart intact',
        (tester) async {
      final CartProvider cart = await startCardPayment(tester);

      await tester.tap(find.text('Cancel Transaction'));
      await tester.pump();
      expect(terminal.cancelCalls, 1);

      // The terminal answers the cancel, which is what actually ends the wait.
      await settleTerminal(tester, terminal.completeCanceled);

      expect(find.byType(PosWaitingCard), findsNothing);
      expect(find.text('PAYMENT METHOD'), findsOneWidget);
      expect(find.text('Confirm Payment'), findsOneWidget);
      expect(cart.cartList.where((l) => l != null).length, 2,
          reason: 'cancelling must not clear the sale');
      expect(find.text('Oat Milk Matcha'), findsOneWidget);
    });

    testWidgets('a declined payment hands over to the declined card',
        (tester) async {
      await startCardPayment(tester);

      await settleTerminal(tester, terminal.completeFailed);

      expect(find.byType(PosWaitingCard), findsNothing);
      expect(find.byType(PosDeclinedCard), findsOneWidget);
      // The selector stays out of the way until the operator decides.
      expect(find.text('PAYMENT METHOD'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    // ── Payment declined (Figma 1641:4218) ─────────────────────────────

    /// Drives a card payment all the way to the declined card.
    Future<CartProvider> reachDeclined(WidgetTester tester,
        {Size size = const Size(1366, 1024)}) async {
      final CartProvider cart = await startCardPayment(tester, size: size);
      await settleTerminal(tester, terminal.completeFailed);
      return cart;
    }

    testWidgets('the declined card shows the design and both actions',
        (tester) async {
      await reachDeclined(tester);

      expect(find.text('Payment Declined'), findsOneWidget);
      expect(find.text('AMOUNT DUE'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
      // Header survives; the sticky bar does not.
      expect(find.byType(PosTopNavBar), findsOneWidget);
      expect(find.text('Confirm Payment'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Amount Due matches what the waiting card quoted',
        (tester) async {
      await startCardPayment(tester);
      final double quoted =
          tester.widget<PosWaitingCard>(find.byType(PosWaitingCard)).amountDue;

      await settleTerminal(tester, terminal.completeFailed);

      expect(
        tester.widget<PosDeclinedCard>(find.byType(PosDeclinedCard)).amountDue,
        quoted,
        reason: 'the customer must not be quoted two different figures',
      );
      expect(quoted, 13);
    });

    testWidgets('Cancel returns to the selector with the sale intact',
        (tester) async {
      final CartProvider cart = await reachDeclined(tester);

      await tester.tap(find.text('Cancel'));
      await tester.pump();

      expect(find.byType(PosDeclinedCard), findsNothing);
      expect(find.text('PAYMENT METHOD'), findsOneWidget);
      expect(find.text('Confirm Payment'), findsOneWidget);
      expect(cart.cartList.where((l) => l != null).length, 2,
          reason: 'a decline must not clear the sale');
      expect(find.text('Oat Milk Matcha'), findsOneWidget);
    });

    testWidgets('Try Again starts one new attempt on the same key',
        (tester) async {
      await reachDeclined(tester);
      expect(terminal.payCalls, 1);

      await tester.tap(find.text('Try Again'));
      await tester.pump();

      // Straight back into the waiting state, not a fresh order.
      expect(find.byType(PosDeclinedCard), findsNothing);
      expect(find.byType(PosWaitingCard), findsOneWidget);
      expect(terminal.payCalls, 2, reason: 'exactly one more attempt');
      expect(terminal.keys.toSet().length, 1,
          reason: 'a retry is the same checkout attempt, so one key');
    });

    testWidgets('Try Again cannot be double-tapped into two attempts',
        (tester) async {
      await reachDeclined(tester);

      await tester.tap(find.text('Try Again'));
      await tester.pump();
      // The button is gone with the card; confirm the guard holds anyway.
      expect(terminal.payCalls, 2);
      await settleTerminal(tester, terminal.completeFailed);
      expect(terminal.payCalls, 2);
    });

    testWidgets('a retry that succeeds leaves the declined card behind',
        (tester) async {
      await reachDeclined(tester);
      await tester.tap(find.text('Try Again'));
      await tester.pump();

      expect(find.byType(PosWaitingCard), findsOneWidget);
      expect(find.byType(PosDeclinedCard), findsNothing);
    });

    testWidgets('back is withheld, but both card actions are live',
        (tester) async {
      await reachDeclined(tester);

      // The back arrow greys out: leaving by the chrome would strand the
      // operator on the counter screen mid-decision. The nav tabs stay live —
      // no payment is in flight, and the sale survives in CartProvider either
      // way.
      expect(
        tester
            .widgetList<Opacity>(find.byType(Opacity))
            .where((o) => o.opacity == 0.4),
        isNotEmpty,
        reason: 'back button is greyed while the decline is on screen',
      );

      final PosDeclinedCard card =
          tester.widget<PosDeclinedCard>(find.byType(PosDeclinedCard));
      expect(card.onCancel, isNotNull);
      expect(card.onTryAgain, isNotNull);
    });

    testWidgets('the declined card stays whole on a short window',
        (tester) async {
      await reachDeclined(tester, size: const Size(820, 700));

      expect(find.text('Payment Declined'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // Note: "cash confirm never touches the terminal" is not asserted here.
    // Driving a cash confirm runs straight into `placeKioskOrder`, which needs
    // the whole order/auth/branch provider graph and a live Dio client — a
    // network stack this layout harness has no business owning. The guard is a
    // single `if (method == PosPaymentMethod.card)` in posConfirmPayment, and
    // the cash group above covers the panel it gates.

    testWidgets('the card stays whole on a short window', (tester) async {
      await startCardPayment(tester, size: const Size(820, 700));

      expect(find.text('Waiting for payment...'), findsOneWidget);
      expect(find.text('Cancel Transaction'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('3-pane responsive shell (PosPayThreePane)', () {
    // The screen is now a receipt / method / summary 3-pane expressed as
    // window ratios (440/1366, 370/1366) with the summary taking the
    // remainder. It lays the three panes side by side while they all clear
    // their floor, and stacks into one scroll when they do not — never
    // shrinking a column past legibility. (The old 2-pane flex model and its
    // 1180 medium-band seam are retired.)
    Future<double> methodCardWidth(WidgetTester tester, Size size) async {
      await _pump(tester, size: size, lines: [_line('Oat Milk Matcha', 6)]);
      return tester.getSize(find.byType(PosPaymentMethodCard).first).width;
    }

    testWidgets('a wide window lays the three panes side by side',
        (tester) async {
      final double card = await methodCardWidth(tester, const Size(1366, 900));
      // Both PRIMARY method cards render, and the method pane is a fraction of
      // the window (its ~370/1366 ratio), which only holds in the side-by-side
      // Row — not the stacked, full-width ListView.
      expect(find.byType(PosPaymentMethodCard), findsNWidgets(2));
      expect(card, lessThan(1366 * 0.45));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the panes grow with the window above the min-clamp',
        (tester) async {
      final double w1200 = await methodCardWidth(tester, const Size(1200, 900));
      final double w1366 = await methodCardWidth(tester, const Size(1366, 900));
      final double w1600 = await methodCardWidth(tester, const Size(1600, 900));

      // Monotonic, continuous growth — no column-swap "pop".
      expect(w1366, greaterThan(w1200));
      expect(w1600, greaterThan(w1366));
      // Still a fraction of the window at every width (ratio layout, not full
      // width).
      expect(w1600, lessThan(1600 * 0.45));
    });

    testWidgets('a narrow window stacks the panes into one scroll',
        (tester) async {
      final double card = await methodCardWidth(tester, const Size(760, 1024));
      // Stacked: the method pane spans the content width, so its card is well
      // over half the window — the opposite of the side-by-side fraction.
      expect(find.byType(PosPaymentMethodCard), findsNWidgets(2));
      expect(card, greaterThan(760 * 0.6));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a portrait window wide enough for three panes stays side by side',
        (tester) async {
      // Width, not orientation, decides the structure. 1366 wide but portrait
      // still holds the 3-pane Row (1024 genuinely cannot fit three panes, so
      // this is tested at a width that can).
      final double card =
          await methodCardWidth(tester, const Size(1366, 1600));
      expect(find.byType(PosPaymentMethodCard), findsNWidgets(2));
      expect(card, lessThan(1366 * 0.45));
      expect(tester.takeException(), isNull);
    });
  });

  group('receipt method change', () {
    testWidgets('opens preselected with no cart and an enabled Confirm change',
        (tester) async {
      PosSaleSession.instance.methodChange = const PosMethodChange(
        orderId: 9,
        fromMethod: 'card',
        toMethod: 'cash',
        reason: 'paid cash after card failed',
        total: 9,
      );
      await _pump(tester);

      expect(PosSaleSession.instance.paymentMethod, PosPaymentMethod.cash);
      expect(PosSaleSession.instance.methodChange, isNull,
          reason: 'consumed on open so it cannot leak into a normal sale');
      expect(find.text('Confirm change'), findsOneWidget);
      final PosPayPillBar pill =
          tester.widget(find.byType(PosPayPillBar).first);
      expect(pill.onConfirm, isNotNull,
          reason: 'a receipt change needs no cart items');
    });
  });
}

/// A terminal whose result the test decides, standing in for the registered
/// [KioskPaymentService]. `pay()` hangs until the test completes it, which is
/// what holds the screen on the waiting state.
class _FakeTerminal implements KioskPaymentService {
  /// One completer per attempt, so a retry can be resolved independently of
  /// the attempt it followed.
  final List<Completer<KioskPaymentResult>> _attempts = [];

  /// Every idempotency key the screen has handed over, in order. Retrying the
  /// same checkout attempt must not mint a new one.
  final List<String> keys = [];

  int cancelCalls = 0;

  int get payCalls => _attempts.length;

  @override
  Future<KioskPaymentResult> pay({
    required double amount,
    required String idempotencyKey,
  }) {
    keys.add(idempotencyKey);
    final completer = Completer<KioskPaymentResult>();
    _attempts.add(completer);
    return completer.future;
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;
  }

  void _resolve(KioskPaymentResult result) {
    final pending = _attempts.lastWhere((c) => !c.isCompleted);
    pending.complete(result);
  }

  void completeCanceled() =>
      _resolve(const KioskPaymentResult(KioskPaymentStatus.canceled));

  void completeFailed() => _resolve(
      const KioskPaymentResult(KioskPaymentStatus.failed, message: 'Declined'));
}
