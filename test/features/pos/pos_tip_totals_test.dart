import 'package:acafe_customer/features/pos/domain/pos_general_settings.dart';
import 'package:acafe_customer/features/pos/domain/pos_hardware_settings.dart';
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_order_detail.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipt_history.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipt_print.dart';
import 'package:acafe_customer/features/pos/widgets/pos_payment_success_card.dart';
import 'package:acafe_customer/features/pos/widgets/pos_receipt_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A tipped sale as the API now returns it: `order_amount` (the `total`) is
/// what was charged and already includes the tip; `tip_amount` breaks it out.
/// €207 of items + €1 tip = €208 (order #1000455, 2026-10-19).
const Map<String, dynamic> _tippedJson = {
  'id': 1000455,
  'created_at': '2026-10-19T00:27:46Z',
  'customer_name': 'amirtest@gmail.com',
  'display_method': 'cash',
  'order_status': 'preparing',
  'payment_status': 'paid',
  'subtotal': 207,
  'discount': 0,
  'tip_amount': 1,
  'total': 208,
  'details': [],
  'items': [],
};

void main() {
  test('receipt and order detail read the tip breakout', () {
    final PosReceiptDetail receipt = PosReceiptDetail.fromJson(_tippedJson);
    expect(receipt.subtotal, 207);
    expect(receipt.tip, 1);
    expect(receipt.total, 208);

    final PosOrderDetail detail = PosOrderDetail.fromJson(_tippedJson);
    expect(detail.subtotal, 207);
    expect(detail.tip, 1);
    expect(detail.total, 208);
  });

  test('an API without tip_amount reads as no tip', () {
    final Map<String, dynamic> json = Map.of(_tippedJson)..remove('tip_amount');
    expect(PosReceiptDetail.fromJson(json).tip, 0);
    expect(PosOrderDetail.fromJson(json).tip, 0);
  });

  test('the printed receipt names the tip and totals what was charged', () {
    final String html = posReceiptPrintHtml(
      PosReceiptDetail.fromJson(_tippedJson),
      hardware: PosHardwareSettings.initial(storeName: 'A/CAFÉ'),
      general: PosGeneralSettings.fromJson(const {}),
    );
    expect(
      html,
      contains('<span>Subtotal</span>'
          '<span>${PosHomeSpec.formatPrice(207)}</span>'),
    );
    expect(
      html,
      contains('<span>Tip</span><span>${PosHomeSpec.formatPrice(1)}</span>'),
    );
    expect(
      html,
      contains('<span>Total</span><span>${PosHomeSpec.formatPrice(208)}</span>'),
    );
  });

  Future<void> pumpSummary(WidgetTester tester, {required double tip}) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 400,
              child: PosReceiptSummary(
                subtotal: 207,
                discount: 0,
                tip: tip,
                total: 207 + tip,
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('receipt totals show a Tip row and grow to fit it',
      (tester) async {
    await pumpSummary(tester, tip: 1);

    expect(find.text('Subtotal'), findsOneWidget);
    expect(find.text('Tip'), findsOneWidget);
    expect(find.text(PosHomeSpec.formatPrice(1)), findsOneWidget);
    expect(find.text(PosHomeSpec.formatPrice(208)), findsOneWidget);
    expect(
      tester.getSize(find.byType(PosReceiptSummary)).height,
      PosHomeSpec.summaryHeightWithDiscount,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('receipt totals without a tip are unchanged', (tester) async {
    await pumpSummary(tester, tip: 0);

    expect(find.text('Tip'), findsNothing);
    expect(
      tester.getSize(find.byType(PosReceiptSummary)).height,
      PosHomeSpec.summaryHeight,
    );
  });

  Future<void> pumpCard(WidgetTester tester, {required double tip}) {
    tester.view.physicalSize = const Size(1366, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PosPaymentSuccessCard(
            title: 'Order Paid',
            amount: 208,
            amountLabel: 'TOTAL PAID',
            tip: tip,
            buttonLabel: 'Next order',
            onContinue: () {},
          ),
        ),
      ),
    );
  }

  testWidgets('Order Paid names the tip inside the total', (tester) async {
    await pumpCard(tester, tip: 1);

    expect(find.text(PosHomeSpec.formatPrice(208, padZero: false)),
        findsOneWidget);
    expect(
      find.text('incl. ${PosHomeSpec.formatPrice(1, padZero: false)} tip'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Order Paid without a tip shows no tip line', (tester) async {
    await pumpCard(tester, tip: 0);

    expect(find.textContaining('tip'), findsNothing);
  });
}
