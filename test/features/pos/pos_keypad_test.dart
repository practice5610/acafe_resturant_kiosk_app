import 'dart:io';
import 'package:acafe_customer/utill/images.dart';

import 'package:acafe_customer/features/pos/domain/pos_payment_spec.dart';
import 'package:acafe_customer/features/pos/widgets/pos_keypad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _pad({double width = 412}) => MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            height: PosPaymentSpec.keypadHeight,
            child: PosKeypad(
              key: const Key('pad'),
              rows: PosKeypad.digitRows(decimal: ','),
              style: posPaymentKeypadStyle(backspaceAsset: Images.posKeyBackspaceSvg),
              onKey: (_) {},
              onBackspace: () {},
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('PosKeypad renders 4 rows of 3 keys', (tester) async {
    await tester.pumpWidget(_pad());
    expect(find.byType(GestureDetector), findsNWidgets(12));
    for (final String d in ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', ',']) {
      expect(find.text(d), findsOneWidget);
    }
  });

  testWidgets('PosKeypad keys are 56px tall', (tester) async {
    await tester.pumpWidget(_pad());
    for (final Element e in find.byType(AnimatedScale).evaluate()) {
      expect(tester.getSize(find.byWidget(e.widget)).height, 56);
    }
  });

  testWidgets('keys are ~131px wide in a 412px keypad (10px gaps)',
      (tester) async {
    await tester.pumpWidget(_pad());
    expect(tester.getSize(find.byType(AnimatedScale).first).width,
        closeTo((412 - 20) / 3, 0.5));
  });

  test('payment keys: tile stroke, soft shadow, Loew Bold 22', () {
    final PosKeypadStyle style = posPaymentKeypadStyle(backspaceAsset: 'x');
    expect(style.borderColor, const Color(0xFFE8E3D5));
    expect(style.borderWidth, 1);
    expect(style.labelSize, 22);
    expect(style.shadow, hasLength(1));
    expect(style.backspaceFill, const Color(0xFFF0EBD8));
  });

  test('Only one keypad style exists', () {
    final String src =
        File('lib/features/pos/widgets/pos_keypad.dart').readAsStringSync();
        expect(RegExp(r'PosKeypadStyle posPaymentKeypadStyle\(').hasMatch(src), isTrue);
    expect(posPaymentKeypadStyle(backspaceAsset: 'x').keyHeight, 56);
    expect(posCompactKeypadStyle(backspaceAsset: 'x').keyHeight, 48);
  });

  testWidgets('Keypad total height is 254px', (tester) async {
    await tester.pumpWidget(_pad());
    expect(PosPaymentSpec.keypadHeight, 254);
    expect(tester.getSize(find.byKey(const Key('pad'))).height, 254);
  });
}
