import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/widgets/pos_receipt_line.dart';
import 'package:acafe_customer/theme/text_legibility.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/text_legibility_audit.dart';
import 'pos_test_kiosk_auth.dart';

/// The line from the client's screenshot: Espresso, Can, plus an add-on, a
/// dropped default and a kitchen note.
CartModel _espresso() {
  final Product product = Product(
    id: 7,
    name: 'Espresso',
    price: 4,
    variations: [
      Variation(
        name: 'Can or cup?',
        variationValues: [
          VariationValue(level: 'Cup'),
          VariationValue(level: 'Can'),
        ],
      ),
      Variation(
        name: 'Size',
        variationValues: [VariationValue(level: 'Double shot')],
      ),
    ],
    addOns: [
      AddOns(id: 1, name: 'Oat milk'),
      AddOns(id: 2, name: 'Sugar', isDefault: true),
    ],
  );
  return CartModel(
    4,
    4,
    const [],
    0,
    1,
    0,
    [AddOn(id: 1, quantity: 1)],
    product,
    [
      [false, true],
      [true],
    ],
    instruction: 'Extra hot',
  );
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<void> pumpLine(WidgetTester tester, {bool inset = false}) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [testKioskAuthProvider(prefs)],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: PosHomeSpec.receiptWidth,
              // The receipt pane's own fill (PosReceiptPanel).
              child: ColoredBox(
                color: PosHomeSpec.panelBg,
                child: PosReceiptLine(
                  line: _espresso(),
                  imageUrl: '',
                  onIncrement: () {},
                  onDecrement: () {},
                  onEdit: () {},
                  inset: inset,
                  showInstruction: true,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  TextStyle styleOf(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).style!;

  testWidgets('variation, add-on and note lines all render', (tester) async {
    await pumpLine(tester);

    expect(find.text('Espresso'), findsOneWidget);
    expect(find.text('€ 4.00 · Can'), findsOneWidget);
    expect(find.text('Double shot'), findsOneWidget);
    expect(find.text('Oat milk'), findsOneWidget);
    expect(find.text('Sugar'), findsOneWidget);
    expect(find.text('Extra hot'), findsOneWidget);
  });

  testWidgets('every run on the line is legible on the receipt panel',
      (tester) async {
    await pumpLine(tester);
    expectLegibleText(tester, within: find.byType(PosReceiptLine));
  });

  testWidgets('detail lines reach AAA (7:1), not just AA', (tester) async {
    await pumpLine(tester);
    expectLegibleText(
      tester,
      within: find.byType(PosReceiptLine),
      minRatio: TextLegibility.enhancedContrast,
      // The qty digit and EDIT sit on their own white/black chips; they are
      // covered by the AA audit above.
      ignore: (t) => t == '1' || t == '+' || t == 'EDIT',
    );
  });

  testWidgets('detail lines use the Medium face in the secondary tone',
      (tester) async {
    await pumpLine(tester);

    for (final String text in [
      '€ 4.00 · Can',
      'Double shot',
      'Oat milk',
      'Sugar',
      'Extra hot',
    ]) {
      final TextStyle style = styleOf(tester, text);
      expect(style.color, TextTones.secondary, reason: text);
      expect(style.fontFamily, 'Swiss721', reason: text);
      expect(style.fontWeight, FontWeight.w500, reason: text);
    }
    // The +/− marks share the tone so they do not read as a separate level.
    // (The qty stepper's "+" chip is cream on black and is not a mark.)
    final List<Text> marks = [
      ...tester.widgetList<Text>(find.text('+')),
      ...tester.widgetList<Text>(find.text('-')),
    ].where((t) => t.style?.color != PosHomeSpec.plusLabel).toList();
    expect(marks, hasLength(3)); // + Double shot, + Oat milk, − Sugar
    for (final Text mark in marks) {
      expect(mark.style!.color, TextTones.secondary);
    }
  });

  testWidgets('sizes still follow the Figma line spec', (tester) async {
    await pumpLine(tester);

    expect(styleOf(tester, '€ 4.00 · Can').fontSize, PosHomeSpec.linePriceSize);
    expect(styleOf(tester, 'Oat milk').fontSize, PosHomeSpec.lineNoteSize);
    expect(styleOf(tester, 'Espresso').fontSize, PosHomeSpec.lineNameSize);
  });

  testWidgets('the payment layer (inset rows) passes too', (tester) async {
    await pumpLine(tester, inset: true);
    expectLegibleText(tester, within: find.byType(PosReceiptLine));
    expect(tester.takeException(), isNull);
  });
}
