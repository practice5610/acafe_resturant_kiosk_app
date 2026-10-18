import 'package:acafe_customer/features/pos/domain/pos_payment_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_sale_session.dart';
import 'package:acafe_customer/features/pos/widgets/pos_receipt_panel.dart';
import 'package:acafe_customer/features/pos/widgets/pos_split_summary_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pos_payment_audit_golden_test.dart';

/// The Figma conflicts resolved by decision (ui-audit/report.md, "Design
/// decisions"), pinned so they cannot drift back.
void main() {
  setUpAll(loadPaymentFonts);
  setUp(() => PosSaleSession.instance.reset());
  tearDown(() => PosSaleSession.instance.reset());

  testWidgets('DD2: "Amount due" sits at the same place on Card and Cash',
      (tester) async {
    await pumpPaymentScreen(tester);
    final Rect card = tester.getRect(find.text('Amount due'));
    await pumpPaymentScreen(tester, method: PosPaymentMethod.cash);
    final Rect cash = tester.getRect(find.text('Amount due'));
    expect(cash, card);
  });

  testWidgets('DD3: paid rows are 48 tall, 8 apart (frames 09–11), everywhere',
      (tester) async {
    await auditFrames['12_split_p4']!(tester);
    final Finder rows = find.byType(PosSplitPaidRow);
    expect(rows, findsNWidgets(3));
    for (int i = 0; i < 3; i++) {
      expect(tester.getSize(rows.at(i)).height,
          PosPaymentSpec.v2SplitPaidRowHeight);
    }
    expect(
      tester.getTopLeft(rows.at(1)).dy - tester.getBottomLeft(rows.at(0)).dy,
      PosPaymentSpec.v2SplitGap,
    );

    await auditFrames['16_sbi_p2']!(tester);
    expect(tester.getSize(find.byType(PosSplitPaidRow)).height,
        PosPaymentSpec.v2SplitPaidRowHeight);
  });

  for (final frame in ['18_order_paid', '18a_receipt_email', '18b_receipt_print']) {
    testWidgets('DD4: Receipt above Next order on $frame', (tester) async {
      await auditFrames[frame]!(tester);
      final double receipt = tester.getTopLeft(find.text('Receipt').last).dy;
      final double next = tester.getTopLeft(find.text('Next order')).dy;
      // On 18a / 18b the dialog's own "Receipt" title is drawn last; the
      // success card's pill is the other one.
      final double pill = frame == '18_order_paid'
          ? receipt
          : tester.getTopLeft(find.text('Receipt').first).dy;
      expect(pill, lessThan(next));
    });
  }

  group('R4: customer-name field stroke', () {
    Future<double> textInset(WidgetTester tester, {required bool inside}) async {
      final name = TextEditingController(text: 'Dylan');
      final table = TextEditingController();
      addTearDown(name.dispose);
      addTearDown(table.dispose);
      await pumpPaymentApp(
        tester,
        (_) => Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 440,
              child: PosReceiptCustomerInfo(
                nameController: name,
                tableController: table,
                insideStroke: inside,
              ),
            ),
          ),
        ),
      );
      return tester.getTopLeft(find.text('Dylan')).dx;
    }

    testWidgets('payment screens: text 14px inside the field (Figma)',
        (tester) async {
      // 24 pane padding + 14 field padding.
      expect(await textInset(tester, inside: true), 38);
    });

    testWidgets('default (Receipts / counter): unchanged, +1.5 border',
        (tester) async {
      expect(await textInset(tester, inside: false), 39.5);
    });
  });
}
