import 'package:acafe_customer/features/pos/domain/pos_payment_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_sale_session.dart';
import 'package:acafe_customer/features/pos/widgets/pos_pay_shell.dart';
import 'package:acafe_customer/features/pos/widgets/pos_payment_method_card.dart';
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

  group('R5: the three payment-screen sections', () {
    Border tileBorder(WidgetTester tester, Finder tile) {
      final Container box = tester.widget<Container>(find
          .descendant(of: tile, matching: find.byType(Container))
          .first);
      return (box.foregroundDecoration! as BoxDecoration).border! as Border;
    }

    for (final method in PosPaymentMethod.values) {
      testWidgets('DD1: one PRIMARY border set (frame 01) with ${method.name} selected',
          (tester) async {
        await pumpPaymentScreen(tester, method: method);
        const style = PosPaymentSpec.v2PrimaryTile;
        final Finder tiles = find.byType(PosPaymentMethodCard);
        expect(tiles, findsNWidgets(2));
        for (int i = 0; i < 2; i++) {
          final bool selected =
              tester.widget<PosPaymentMethodCard>(tiles.at(i)).selected;
          final Border b = tileBorder(tester, tiles.at(i));
          expect(b.top.color, selected ? style.selectedBorder : style.idleBorder);
          expect(b.top.width,
              selected ? style.selectedBorderWidth : style.idleBorderWidth);
          // Inside stroke: the tile stays 95 whatever its state.
          expect(tester.getSize(tiles.at(i)).height, PosPaymentSpec.methodHeight);
        }
      });
    }

    testWidgets('disabled tile: dimmed and inert, distinct from idle / selected',
        (tester) async {
      int taps = 0;
      await pumpPaymentApp(
        tester,
        (_) => Scaffold(
          body: Column(
            children: [
              SizedBox(
                width: 322,
                child: PosPaymentMethodCard(
                  method: PosPaymentMethod.cash,
                  selected: false,
                  onTap: null,
                ),
              ),
              SizedBox(
                width: 322,
                child: PosPaymentMethodCard(
                  method: PosPaymentMethod.card,
                  selected: false,
                  onTap: () => taps++,
                ),
              ),
            ],
          ),
        ),
      );
      final Finder dim = find.ancestor(
          of: find.text('Cash'), matching: find.byType(Opacity));
      expect(tester.widget<Opacity>(dim.first).opacity,
          PosPaymentSpec.v2TileDisabledOpacity);
      await tester.tap(find.text('Cash'));
      await tester.tap(find.text('Card'));
      expect(taps, 1);
    });

    testWidgets('pressed state ripples inside the rounded tile', (tester) async {
      await pumpPaymentScreen(tester);
      for (final label in ['Card', 'Split by item']) {
        final InkWell ink = tester.widget<InkWell>(
            find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first);
        expect(ink.borderRadius, isNotNull, reason: label);
      }
    });

    testWidgets('panes: 440 / 370 / 452, 20 apart, 19 above the bar', (tester) async {
      await pumpPaymentScreen(tester);
      final Finder cards = find.byType(PosPayCard);
      final List<Rect> panes = [
        for (int i = 0; i < 3; i++) tester.getRect(cards.at(i)),
      ]..sort((a, b) => a.left.compareTo(b.left));
      expect(panes.map((r) => r.left).toList(), [32, 492, 882]);
      expect(panes.map((r) => r.width).toList(), [440, 370, 452]);
      for (final r in panes) {
        expect(r.top, 67);
        expect(r.height, 834);
      }
      final Rect bar = tester.getRect(find.byType(PosPayPillBar));
      expect(bar.top - panes.first.bottom, PosPaymentSpec.v2ContentPaddingBottom);
      expect(bar.top, 920);
    });
  });
}
