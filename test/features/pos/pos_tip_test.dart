import 'dart:convert';

import 'package:acafe_customer/features/kiosk/domain/kiosk_place_order.dart';
import 'package:acafe_customer/features/pos/domain/pos_checkout.dart';
import 'package:acafe_customer/features/pos/domain/pos_payment_settings.dart';
import 'package:acafe_customer/features/pos/domain/pos_sale_session.dart';
import 'package:acafe_customer/features/pos/widgets/pos_keypad.dart';
import 'package:acafe_customer/features/pos/screens/pos_payment_selection_screen.dart';
import 'package:acafe_customer/features/pos/widgets/pos_tip_dialog.dart';
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pos_payment_audit_golden_test.dart';
import 'pos_payment_flow_test.dart'
    show
        setUpFlowFakes,
        tearDownFlowFakes,
        terminal,
        bar,
        confirmBar,
        tap;

/// "Add tip" on the payment screen: the modal (presets, custom € / %,
/// validation), and what the tip does to the sale (back row, amount due, cash
/// coverage, the charge and the order's tip_amount).
///
/// The Dylan € 19.00 ticket: 5% = € 0.95, 10% = € 1.90, 15% = € 2.85.
void main() {
  late List<(double, double?)> orders;

  setUpAll(loadPaymentFonts);
  setUp(() {
    PosSaleSession.instance.reset();
    setUpFlowFakes();
    orders = [];
    debugPosPlaceOrder = (context,
        {required amount,
        paymentRef,
        bringChangeAmount,
        tipAmountOverride,
        splitPayment = false,
        paymentMethod = 'cash_on_delivery'}) async {
      orders.add((amount, tipAmountOverride));
      return const KioskPlaceResult(success: true, orderId: '27362');
    };
  });
  tearDown(() {
    tearDownFlowFakes();
    PosSaleSession.instance.reset();
  });

  Finder inModal(String text) =>
      find.descendant(of: find.byType(PosTipModal), matching: find.text(text));

  Future<void> keyIn(WidgetTester tester, String typed) async {
    for (final String k in typed.split('')) {
      await tap(
          tester,
          find.descendant(
              of: find.byType(PosTipModal),
              matching: find.descendant(
                  of: find.byType(PosKeypad), matching: find.text(k))));
    }
  }

  String modalBar(WidgetTester tester) => tester
      .widget<Text>(find.descendant(
          of: find.byKey(const Key('pos-tip-apply')),
          matching: find.byType(Text)))
      .data!;

  bool modalBarLive(WidgetTester tester) =>
      tester.widget<InkWell>(find.byKey(const Key('pos-tip-apply'))).onTap !=
      null;

  Future<void> openTip(WidgetTester tester,
      {PosPaymentMethod method = PosPaymentMethod.card}) async {
    await pumpPaymentScreen(tester, routed: true, method: method);
    await tap(tester, find.text('Add tip'));
    expect(find.byType(PosTipModal), findsOneWidget);
  }

  group('the modal', () {
    testWidgets('presets show what they come to; No tip is the default',
        (tester) async {
      await openTip(tester);
      expect(inModal('€ 0.95'), findsOneWidget);
      expect(inModal('€ 1.90'), findsOneWidget);
      expect(inModal('€ 2.85'), findsOneWidget);
      expect(modalBar(tester), 'Continue without tip');
      expect(inModal('No tip on this order'), findsOneWidget);
    });

    testWidgets('10% → the sale becomes € 20.90 everywhere', (tester) async {
      await openTip(tester);
      await tap(tester, inModal('10%'));
      expect(inModal('10% of € 19.00'), findsOneWidget);
      expect(inModal('+ € 1.90'), findsOneWidget);
      expect(inModal('€ 20.90'), findsOneWidget); // preview total
      expect(modalBar(tester), 'Add € 1.90 tip');
      await tap(tester, find.byKey(const Key('pos-tip-apply')));

      expect(find.byType(PosTipModal), findsNothing);
      expect(find.text('Dylan / € 20.90'), findsOneWidget);
      expect(find.text('€ 20.90'), findsWidgets);
      expect(find.text('€ 1.90'), findsOneWidget); // tip row

      await confirmBar(tester);
      expect(terminal.charged, [20.9]);
      expect(orders.single, (20.9, 1.9));
    });

    testWidgets('custom amount keyed on the keypad, with decimals',
        (tester) async {
      await openTip(tester);
      await keyIn(tester, '2.505'); // the third decimal is ignored
      expect(find.descendant(
              of: find.byKey(const Key('pos-tip-input')),
              matching: find.text('2.50')),
          findsOneWidget);
      expect(modalBar(tester), 'Add € 2.50 tip');
      expect(inModal('Custom amount · 13.2% of € 19.00'), findsOneWidget);
      await tap(tester, find.byKey(const Key('pos-tip-apply')));
      expect(find.text('Dylan / € 21.50'), findsOneWidget);
    });

    testWidgets('a tip above the amount due is refused, not applied',
        (tester) async {
      await openTip(tester);
      await keyIn(tester, '25');
      expect(inModal("A tip can't be more than the amount due (€ 19.00)."),
          findsOneWidget);
      expect(modalBarLive(tester), isFalse);
      expect(modalBar(tester), 'Add tip');
      expect(
          tester
              .widget<Text>(find.byKey(const Key('pos-tip-amount')))
              .data,
          '—');
    });

    testWidgets('percentage: 20% = € 3.80; over 100% is refused',
        (tester) async {
      await openTip(tester);
      await tap(tester, inModal('%'));
      await keyIn(tester, '20');
      expect(modalBar(tester), 'Add € 3.80 tip');
      expect(inModal('20% of € 19.00'), findsOneWidget);
      tester.widget<PosKeypad>(find.descendant(
              of: find.byType(PosTipModal), matching: find.byType(PosKeypad)))
          .onBackspace();
      await tester.pumpAndSettle();
      await keyIn(tester, '50'); // 250%
      expect(inModal('A tip can be at most 100% of the amount due.'),
          findsOneWidget);
      expect(modalBarLive(tester), isFalse);
    });

    testWidgets('reopening shows the tip on the sale; "Remove tip" clears it',
        (tester) async {
      await openTip(tester);
      await tap(tester, inModal('15%'));
      await tap(tester, find.byKey(const Key('pos-tip-apply')));
      expect(find.text('Dylan / € 21.85'), findsOneWidget);

      await tap(tester, find.text('Add tip'));
      final PosTipModal modal =
          tester.widget<PosTipModal>(find.byType(PosTipModal));
      expect(modal.currentTip, 2.85);
      expect(modalBar(tester), 'Add € 2.85 tip'); // 15% is still picked
      await tap(tester, inModal('No tip'));
      expect(modalBar(tester), 'Remove tip');
      await tap(tester, find.byKey(const Key('pos-tip-apply')));
      expect(find.text('Dylan / € 19.00'), findsOneWidget);
    });

    testWidgets('closing leaves the sale as it was', (tester) async {
      await openTip(tester);
      await tap(tester, inModal('10%'));
      await tap(tester, find.bySemanticsLabel('Close'));
      expect(find.byType(PosTipModal), findsNothing);
      expect(find.text('Dylan / € 19.00'), findsOneWidget);
    });

    testWidgets('a hardware keyboard works: digits, Backspace, Enter',
        (tester) async {
      await openTip(tester);
      for (final k in [
        LogicalKeyboardKey.digit3,
        LogicalKeyboardKey.digit5,
        LogicalKeyboardKey.backspace,
      ]) {
        await tester.sendKeyEvent(k);
        await tester.pump();
      }
      expect(modalBar(tester), 'Add € 3.00 tip');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Dylan / € 22.00'), findsOneWidget);
    });
  });

  group('the sale', () {
    testWidgets('cash on Exact follows the tip, so the sale stays covered',
        (tester) async {
      await openTip(tester, method: PosPaymentMethod.cash);
      await tap(tester, inModal('10%'));
      await tap(tester, find.byKey(const Key('pos-tip-apply')));
      expect(bar(tester), ('Confirm Payment', true));
      await confirmBar(tester);
      expect(terminal.charged, isEmpty);
      expect(orders.single, (20.9, 1.9));
    });

    testWidgets('tipping switched off in Settings: the row says so',
        (tester) async {
      PosSaleSession.instance.customerName.text = 'Dylan';
      await pumpPaymentApp(
        tester,
        (prefs) {
          // Saved by Settings → Payments with the switch off.
          prefs.setString(
              AppConstants.posPaymentSettingsKey,
              jsonEncode(PosPaymentSettings.initial()
                  .copyWith(tippingEnabled: false)
                  .toJson()));
          return PosPaymentSelectionScreen(sharedPreferences: prefs);
        },
        routed: true,
      );
      await tap(tester, find.text('Add tip'));
      expect(find.byType(PosTipModal), findsNothing);
      expect(find.text('Tipping is turned off in Settings → Payments.'),
          findsOneWidget);
    });
  });

  group('sizes', () {
    for (final size in const [
      Size(1366, 1024),
      Size(1024, 768),
      Size(900, 600),
      Size(768, 1024),
    ]) {
      testWidgets('no overflow at ${size.width.toInt()}x${size.height.toInt()}',
          (tester) async {
        await pumpPaymentScreen(tester, routed: true, size: size);
        await tap(tester, find.text('Add tip'));
        await tap(tester, inModal('10%'));
        await keyIn(tester, '123');
        expect(tester.takeException(), isNull);
        expect(find.byType(PosTipModal), findsOneWidget);
      });
    }
  });
}
