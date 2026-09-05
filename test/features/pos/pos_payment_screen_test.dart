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
import 'package:acafe_customer/features/kiosk/domain/kiosk_payment_service.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_auth_repo.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_payment_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_sale_session.dart';
import 'package:acafe_customer/features/pos/pos_shell.dart';
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

      expect(find.byType(PosCashPanel), findsNothing,
          reason: 'Card is the default method and has no tender panel');

      await selectCash(tester);

      expect(find.byType(PosCashPanel), findsOneWidget);
      expect(find.text('Amount Tendered'), findsOneWidget);
      expect(find.text('Change Due'), findsOneWidget);
      expect(find.byType(PosKeypad), findsOneWidget);
      for (final String key in const ['1', '5', '9', '0', ',']) {
        expect(find.descendant(
          of: find.byType(PosKeypad),
          matching: find.text(key),
        ), findsOneWidget, reason: 'key $key');
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('the keypad builds up the tendered amount', (tester) async {
      await _pump(tester, lines: [_line('Oat Milk Matcha', 6)]);
      await selectCash(tester);

      expect(find.text(PosHomeSpec.formatPrice(0, padZero: false)),
          findsWidgets);

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
        tester.widget<PosCashPanel>(find.byType(PosCashPanel))
            .selectedDenomination,
        const PosCashDenomination.note(2000),
      );
    });

    testWidgets('Exact tenders the total and leaves no change',
        (tester) async {
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
        tester.widget<PosCashPanel>(find.byType(PosCashPanel))
            .selectedDenomination,
        const PosCashDenomination.note(5000),
        reason: 'the later chip wins; both must not be lit',
      );

      await tapKey(tester, '7');
      expect(
        tester.widget<PosCashPanel>(find.byType(PosCashPanel))
            .selectedDenomination,
        isNull,
        reason: 'manual entry clears the chip highlight',
      );
    });

    testWidgets('confirmation is blocked until the tender covers the total',
        (tester) async {
      await _pump(tester, lines: [_line('Oat Milk Matcha', 6)]);
      await selectCash(tester);

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
      expect(find.text(PosHomeSpec.formatPrice(0, padZero: false)),
          findsWidgets);
      expect(find.textContaining('-'), findsNothing);
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

    testWidgets('switching back to Card drops the tender', (tester) async {
      await _pump(tester, lines: [_line('Oat Milk Matcha', 6)]);
      await selectCash(tester);
      await tester.tap(find.text('€ 20'));
      await tester.pump();

      await tester.tap(find.text('Card'));
      await tester.pump();
      await selectCash(tester);

      expect(
        tester.widget<PosCashPanel>(find.byType(PosCashPanel)).entry.isEmpty,
        isTrue,
      );
      expect(confirmEnabled(tester), isFalse);
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
        tester.widget<PosCashPanel>(find.byType(PosCashPanel)).entry.isEmpty,
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
      expect(find.text('SELECT PAYMENT METHOD'), findsNothing);
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
      expect(find.text(PosHomeSpec.formatPrice(13, padZero: false)),
          findsOneWidget);
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
      expect(find.text('SELECT PAYMENT METHOD'), findsOneWidget);
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
      expect(find.text('SELECT PAYMENT METHOD'), findsNothing);
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
      expect(find.text('SELECT PAYMENT METHOD'), findsOneWidget);
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
