import 'dart:io';

import 'package:acafe_customer/features/pos/domain/pos_cash_denomination.dart';
import 'package:acafe_customer/features/pos/domain/pos_cash_entry.dart';
import 'package:acafe_customer/features/pos/widgets/pos_pay_cash_panel.dart';
import 'package:acafe_customer/features/pos/domain/pos_sale_session.dart';
import 'package:acafe_customer/features/pos/widgets/pos_pay_shell.dart';
import 'package:acafe_customer/features/pos/widgets/pos_split_by_item_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _cashPanel({bool fill = true}) => MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 452,
            height: 835,
            child: PosPayCashSummaryPanel(
              total: 12.5,
              entry: const PosCashEntry(),
              totalCents: 1250,
              selectedDenomination: null,
              onDenomination: (_) {},
              onKey: (_) {},
              onTyped: (_) {},
              onBackspace: () {},
              onClear: () {},
              fill: fill,
            ),
          ),
        ),
      ),
    );

void main() {
  // Figma 1915:10244: 452 card, px-16 -> 420 (tendered field / keypad width).
  testWidgets('Right pane content width is 420px', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1366, 1024));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_cashPanel());
    expect(tester.getSize(find.byKey(const Key('pad-box'))).width, 420);
  });

  // Figma 1915:10256: (420 - 4 x 8) / 5 = 77.6 x 41.
  testWidgets('Quick denomination buttons are 77.6x41 with 8px gap',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1366, 1024));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_cashPanel());
    final Finder chips = find.byKey(const Key('denom-chip'));
    expect(chips, findsNWidgets(PosCashDenomination.defaults.length));
    for (int i = 0; i < 5; i++) {
      final Size s = tester.getSize(chips.at(i));
      expect(s.width, closeTo(77.6, 0.5));
      expect(s.height, 41);
    }
    final double gap = tester.getTopLeft(chips.at(1)).dx -
        tester.getTopRight(chips.at(0)).dx;
    expect(gap, closeTo(8, 0.5));
  });

  testWidgets('PAY WITH buttons are ~202px wide and 48px tall', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 452,
            child: PosPayWithRow(
              method: PosPaymentMethod.card,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    ));
    final Finder btns = find.byType(Container).evaluate().isEmpty
        ? find.byType(GestureDetector)
        : find.byType(GestureDetector);
    expect(btns, findsNWidgets(2));
    for (int i = 0; i < 2; i++) {
      final Size s = tester.getSize(btns.at(i));
      expect(s.width, closeTo(202, 1));
      expect(s.height, 48);
    }
    expect(
        tester.getTopLeft(btns.at(1)).dx - tester.getTopRight(btns.at(0)).dx,
        closeTo(8, 0.5));
  });

  testWidgets('Change Due banner height is 37px', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1366, 1024));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_cashPanel());
    expect(tester.getSize(find.byKey(const Key('change-due'))).height, 37);
  });

  testWidgets('3-pane widths match Figma spec', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1366, 835));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PosPayThreePane(
          receipt: (_) => const SizedBox.expand(key: Key('l')),
          method: (_) => const SizedBox.expand(key: Key('c')),
          summary: (_) => const SizedBox.expand(key: Key('r')),
        ),
      ),
    ));
    expect(tester.getSize(find.byKey(const Key('l'))).width, closeTo(440, 1));
    expect(tester.getSize(find.byKey(const Key('c'))).width, closeTo(370, 1));
    expect(tester.getSize(find.byKey(const Key('r'))).width, closeTo(452, 1));
    expect(tester.getTopLeft(find.byKey(const Key('l'))).dx, closeTo(32, 1));
    expect(
        tester.getTopLeft(find.byKey(const Key('c'))).dx -
            tester.getTopRight(find.byKey(const Key('l'))).dx,
        closeTo(20, 1));
    expect(1366 - tester.getTopRight(find.byKey(const Key('r'))).dx,
        closeTo(32, 1));
  });

  test('No dynamic keypad scaling in codebase', () {
    final RegExp formula = RegExp(r'/\s*_kNaturalKeypad|maxHeight\s*/\s*348');
    for (final FileSystemEntity f
        in Directory('lib/features/pos').listSync(recursive: true)) {
      if (f is File && f.path.endsWith('.dart')) {
        expect(formula.hasMatch(f.readAsStringSync()), isFalse, reason: f.path);
      }
    }
  });
}
