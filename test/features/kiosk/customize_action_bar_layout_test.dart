import 'dart:io';

import 'package:acafe_customer/features/kiosk/screens/kiosk_checkout_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The customize screen has now been broken TWICE by the same mistake: a `Row`
/// with `CrossAxisAlignment.stretch` placed directly inside the screen's
/// `Column`. A Column hands its children an unbounded height, so `stretch`
/// gives every Row child a tight *infinite* height, layout throws, and the
/// entire body below the header renders blank — options, add-ons, cup/can and
/// the action buttons all vanish at once.
///
/// These tests lock the shape down: one proves the failure mode is real, one
/// proves the shipped structure survives it, and one bans the pattern from the
/// file outright.
void main() {
  /// The exact parent shape of the action bar: pinned row at the bottom of the
  /// screen's Column, under an Expanded scroll area.
  Widget screenShaped({required CrossAxisAlignment cross}) => MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const Expanded(child: SizedBox()),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: cross,
                  children: const [
                    Expanded(
                      child: KioskCheckoutButton(
                        s: 0.3,
                        label: 'CANCEL ITEM',
                        filled: false,
                        onTap: null,
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: KioskCheckoutButton(
                        s: 0.3,
                        label: 'ADD TO CART',
                        filled: true,
                        onTap: null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  testWidgets('stretch in the screen Column throws — the regression',
      (tester) async {
    await tester.pumpWidget(screenShaped(cross: CrossAxisAlignment.stretch));
    expect(tester.takeException(), isNotNull,
        reason: 'this is why the body went blank');
  });

  testWidgets('the shipped shape lays out and shows both buttons',
      (tester) async {
    await tester.pumpWidget(screenShaped(cross: CrossAxisAlignment.center));

    expect(tester.takeException(), isNull);
    expect(find.text('CANCEL ITEM'), findsOneWidget);
    expect(find.text('ADD TO CART'), findsOneWidget);

    // KioskCheckoutButton sizes itself, so the pair matches height without
    // stretch — which is why stretch was never needed here.
    final Size cancel = tester.getSize(find.text('CANCEL ITEM'));
    final Size add = tester.getSize(find.text('ADD TO CART'));
    expect(cancel.height, greaterThan(0));
    expect(add.height, greaterThan(0));
  });

  test('no Row in the customize screen uses CrossAxisAlignment.stretch', () {
    final List<String> lines = File(
      'lib/features/kiosk/screens/kiosk_product_customize_sheet.dart',
    ).readAsLinesSync();

    final List<String> offenders = [];
    for (int i = 0; i < lines.length; i++) {
      if (!RegExp(r'\bRow\(').hasMatch(lines[i])) continue;
      final String window = lines.sublist(i, (i + 4).clamp(0, lines.length)).join('\n');
      if (window.contains('CrossAxisAlignment.stretch')) {
        offenders.add('line ${i + 1}');
      }
    }

    expect(offenders, isEmpty,
        reason: 'Row + stretch inside this screen\'s unbounded-height Columns '
            'blanks the whole body. Let the children size themselves instead. '
            'Offenders: $offenders');
  });
}
