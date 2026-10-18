import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/features/pos/domain/pos_sale_session.dart';
import 'package:acafe_customer/features/pos/widgets/pos_keypad.dart';
import 'package:acafe_customer/features/pos/widgets/pos_pay_shell.dart';
import 'package:acafe_customer/features/pos/widgets/pos_payment_method_selector.dart';
import 'package:acafe_customer/features/pos/widgets/pos_split_by_item_panel.dart';
import 'package:acafe_customer/features/pos/widgets/pos_split_summary_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pos_payment_audit_golden_test.dart';
import 'pos_payment_flow_test.dart'
    show setUpFlowFakes, tearDownFlowFakes, tap, confirmBar, inPane;

/// The split panes in windows shorter than the 1366×1024 frame — a laptop
/// browser among them (the 1479×756 window the keypad used to be cut off in):
/// every control stays inside its pane, nothing has to be scrolled to.
void main() {
  setUpAll(loadPaymentFonts);
  setUp(() {
    PosSaleSession.instance.reset();
    setUpFlowFakes();
  });
  tearDown(() {
    tearDownFlowFakes();
    PosSaleSession.instance.reset();
  });

  Rect paneOf(WidgetTester tester, Type pane) => tester.getRect(find
      .ancestor(of: find.byType(pane), matching: find.byType(PosPayCard))
      .first);

  void inside(WidgetTester tester, Finder f, Rect pane, String what) {
    final Rect r = tester.getRect(f);
    expect(r.top, greaterThanOrEqualTo(pane.top - 0.5), reason: '$what top');
    expect(r.bottom, lessThanOrEqualTo(pane.bottom + 0.5),
        reason: '$what is cut off at the bottom of its pane');
  }

  Finder key(String label) => find.descendant(
      of: find.byType(PosKeypad), matching: find.text(label));

  /// The key itself (its face), not its label.
  Finder face(String label) =>
      find.ancestor(of: key(label), matching: find.byType(Container)).first;

  const List<Size> sizes = [
    Size(1479, 756),
    Size(1366, 768),
    Size(1280, 800),
    Size(1024, 768),
  ];

  for (final Size size in sizes) {
    final String at = '${size.width.toInt()}x${size.height.toInt()}';

    testWidgets('split by payment, card: keypad and tip row in view at $at',
        (tester) async {
      await pumpPaymentScreen(tester, routed: true, size: size);
      await tap(tester, find.text('Split by payment'));
      final Rect pane = paneOf(tester, PosSplitSummaryPanel);
      inside(tester, key('0'), pane, 'the 0 key');
      inside(tester, find.text('Add tip'), pane, 'the tip row');
      // Keys get shorter, never below a comfortable 44px target.
      expect(tester.getSize(face('1')).height, greaterThanOrEqualTo(44));
      expect(tester.takeException(), isNull);
    });

    testWidgets('split by payment, cash: change due, notes, keypad in view at $at',
        (tester) async {
      await pumpPaymentScreen(tester, routed: true, size: size);
      await tap(tester, find.text('Split by payment'));
      await tap(
          tester,
          find.descendant(
              of: find.byType(PosSplitMethodToggle),
              matching: find.text('Cash')));
      final Rect pane = paneOf(tester, PosSplitSummaryPanel);
      inside(tester, find.text('Exact'), pane, 'the Exact chip');
      inside(tester, key('0'), pane, 'the 0 key');
      inside(tester, find.text('Add tip'), pane, 'the tip row');
      expect(tester.takeException(), isNull);
    });

    testWidgets('split by item, six lines: list, PAY WITH and tip in view at $at',
        (tester) async {
      final List<CartModel> six = [
        ...figmaTicket(),
        figmaLine('Iced Americano', 3.5, id: 4),
        figmaLine('Butter Croissant', 3.2, id: 5),
        figmaLine('Banana Bread', 4.2, id: 6),
      ];
      await pumpPaymentScreen(tester, routed: true, size: size, lines: six);
      await tap(tester, find.text('Split by item'));
      await confirmBar(tester);
      final Rect pane = paneOf(tester, PosSplitByItemPanel);
      inside(tester, find.text('PAY WITH'), pane, 'PAY WITH');
      inside(tester, inPane(PosSplitByItemPanel, 'Selected total'), pane,
          'the selected total');
      inside(tester, find.text('Add tip'), pane, 'the tip row');
      expect(tester.takeException(), isNull);
    });

    testWidgets('every payment method in view at $at', (tester) async {
      await pumpPaymentScreen(tester, routed: true, size: size);
      final Rect pane = paneOf(tester, PosPaymentMethodSelector);
      inside(tester, find.text('PAYMENT METHOD'), pane, 'the header');
      inside(tester, find.text('Stand-alone'), pane, 'Stand-alone');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('at the frame size the keys are the refined 56px, 10 apart',
      (tester) async {
    await pumpPaymentScreen(tester, routed: true);
    await tap(tester, find.text('Split by payment'));
    expect(tester.getSize(face('1')).height, 56);
    final double gap = tester.getTopLeft(face('4')).dy -
        tester.getBottomLeft(face('1')).dy;
    expect(gap, 10);
  });
}
