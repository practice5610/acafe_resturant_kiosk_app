import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipt_history.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipt_save_changes_repo.dart';
import 'package:acafe_customer/features/pos/widgets/pos_receipt_edit_line_dialog.dart';
import 'package:acafe_customer/features/pos/widgets/pos_receipt_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../helpers/kiosk_layout_harness.dart';

/// Reopen -> EDIT on a settled receipt line (Figma 1915:21366).
///
/// The line is rebuilt from the stored order_details row, so this fixture is
/// that row exactly as the backend formatter hands it back (shape copied from
/// local order #100009: an Americano sold Large + Can + Blueberry).
Map<String, dynamic> _receiptJson({
  String size = 'Large',
  String vessel = 'Can',
  List<int> addOns = const [199],
  String? instruction,
  List<Map<String, dynamic>> extraVariations = const [],
  List<Map<String, dynamic>> extraPicks = const [],
}) {
  Map<String, dynamic> pick(String name, String label, Object price) => {
        'name': name,
        'type': 'single',
        'values': [
          {'label': label, 'optionPrice': price},
        ],
      };

  return {
    'id': 100009,
    'subtotal': 110.5,
    'discount': 0,
    'total': 110.5,
    'details': [
      {
        'id': 4493,
        'product_id': 351,
        'price': size == 'Large' ? 110 : 100,
        'quantity': 1,
        'discount_on_product': 0,
        'tax_amount': 0,
        'instruction': instruction,
        'add_on_ids': addOns,
        'variation': [
          pick('Size', size, size == 'Large' ? '10' : '0'),
          pick('Can or cup?', vessel, 0),
          ...extraPicks,
        ],
        'product_details': {
          'id': 351,
          'name': 'Americano',
          'price': 100,
          'note_suggestions': ['Extra hot', 'No sugar'],
          'variations': [
            {
              'name': 'Size',
              'type': 'single',
              'required': 'on',
              'values': [
                {'label': 'Small', 'optionPrice': '0'},
                {'label': 'Large', 'optionPrice': '10'},
              ],
            },
            {
              'name': 'Can or cup?',
              'type': 'single',
              'required': 'on',
              'values': [
                {'label': 'Cup', 'optionPrice': 0},
                {'label': 'Can', 'optionPrice': 0},
              ],
            },
            ...extraVariations,
          ],
          'add_ons': [
            {'id': 198, 'name': 'Banana Puree', 'price': 0.5, 'is_default': false},
            {'id': 199, 'name': 'Blueberry', 'price': 0.5, 'is_default': false},
            {'id': 200, 'name': 'Caramel Syrup', 'price': 0.5, 'is_default': false},
          ],
        },
      },
    ],
  };
}

CartModel _line({
  String size = 'Large',
  String vessel = 'Can',
  List<int> addOns = const [199],
  String? instruction,
  List<Map<String, dynamic>> extraVariations = const [],
  List<Map<String, dynamic>> extraPicks = const [],
}) =>
    PosReceiptDetail.fromJson(_receiptJson(
      size: size,
      vessel: vessel,
      addOns: addOns,
      instruction: instruction,
      extraVariations: extraVariations,
      extraPicks: extraPicks,
    )).lines.single;

/// Opens the editor over [line] and hands back what UPDATE ITEM returned.
Future<PosReceiptLineEdits? Function()> _openEditor(
  WidgetTester tester,
  CartModel line,
) async {
  tester.view.physicalSize = const Size(1600, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  PosReceiptLineEdits? confirmed;
  late BuildContext ctx;
  await tester.pumpWidget(MaterialApp(
    home: Builder(builder: (c) {
      ctx = c;
      return const SizedBox.expand();
    }),
  ));
  showPosReceiptEditLineDialog(
    context: ctx,
    receiptNumber: '100009',
    line: line,
    onConfirm: (edits) => confirmed = edits,
  );
  await tester.pumpAndSettle();
  return () => confirmed;
}

bool _isSelected(WidgetTester tester, String label) {
  final Material tile = tester.widget<Material>(find
      .ancestor(of: find.text(label).first, matching: find.byType(Material))
      .first);
  final BorderSide side =
      (tile.shape as RoundedRectangleBorder?)?.side ?? BorderSide.none;
  return side != BorderSide.none;
}

/// The option tile for [label] (the sidebar summary may repeat the label).
Finder _tile(String label) => find.text(label).first;

Finder _sidebar() => find.byKey(const Key('pos-edit-line-summary'));

Finder _inSidebar(String text) =>
    find.descendant(of: _sidebar(), matching: find.text(text));

void main() {
  group('a reopened line keeps everything it was sold with', () {
    test('the line note comes back from order_details.instruction', () {
      expect(_line(instruction: '  no sugar  ').instruction, 'no sugar');
      expect(_line(instruction: '   ').instruction, isNull);
      expect(_line().instruction, isNull);
    });

    test('the option surcharge is what the picks cost', () {
      expect(posLineVariationSurcharge(_line(size: 'Large')), 10);
      expect(posLineVariationSurcharge(_line(size: 'Small')), 0);
    });
  });

  group('line editor', () {
    testWidgets('opens with the sold size, vessel and add-ons already picked',
        (tester) async {
      await _openEditor(tester, _line());

      expect(_isSelected(tester, 'Large'), isTrue);
      expect(_isSelected(tester, 'Small'), isFalse);
      expect(_isSelected(tester, 'Can'), isTrue);
      expect(_isSelected(tester, 'Cup'), isFalse);
      expect(_isSelected(tester, 'Blueberry'), isTrue);
      expect(_isSelected(tester, 'Banana Puree'), isFalse);
    });

    testWidgets('the sidebar summarises every pick, not just cup/can',
        (tester) async {
      await _openEditor(tester, _line(instruction: 'no sugar'));

      expect(_inSidebar('€ 110.50 · Can'), findsOneWidget);
      expect(_inSidebar('Large'), findsOneWidget);
      expect(_inSidebar('Blueberry'), findsOneWidget);
      expect(_inSidebar('no sugar'), findsOneWidget);
    });

    testWidgets('ADD NOTE opens the note dialog and the note rides UPDATE ITEM',
        (tester) async {
      final confirmed = await _openEditor(tester, _line());

      expect(find.text('ADD NOTE'), findsOneWidget);
      await tester.tap(find.text('ADD NOTE'));
      await tester.pumpAndSettle();

      // The product's own quick-add phrases are offered.
      expect(find.text('Extra hot'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'oat milk please');
      await tester.tap(find.text('Add Note').last);
      await tester.pumpAndSettle();

      expect(find.text('EDIT NOTE'), findsOneWidget);
      expect(_inSidebar('oat milk please'), findsOneWidget);

      await tester.tap(find.text('UPDATE ITEM'));
      await tester.pumpAndSettle();
      expect(confirmed()!.instruction, 'oat milk please');
    });

    testWidgets('an existing note is pre-filled and can be cleared',
        (tester) async {
      final confirmed = await _openEditor(tester, _line(instruction: 'no sugar'));

      await tester.tap(find.text('EDIT NOTE'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'no sugar',
      );
      await tester.enterText(find.byType(TextField), '');
      await tester.tap(find.text('Add Note').last);
      await tester.pumpAndSettle();

      expect(find.text('ADD NOTE'), findsOneWidget);
      await tester.tap(find.text('UPDATE ITEM'));
      await tester.pumpAndSettle();
      expect(confirmed()!.instruction, isNull);
    });

    testWidgets('dismissing the note dialog keeps the note as it was',
        (tester) async {
      final confirmed = await _openEditor(tester, _line(instruction: 'no sugar'));

      await tester.tap(find.text('EDIT NOTE'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5)); // barrier
      await tester.pumpAndSettle();

      await tester.tap(find.text('UPDATE ITEM'));
      await tester.pumpAndSettle();
      expect(confirmed()!.instruction, 'no sugar');
    });

    testWidgets('a size change is priced on the CTA and returned as picks',
        (tester) async {
      final confirmed = await _openEditor(tester, _line(size: 'Small'));

      await tester.tap(_tile('Large'));
      await tester.pumpAndSettle();
      expect(find.textContaining('UPDATE ITEM  •  + €10.00'), findsOneWidget);

      await tester.tap(find.textContaining('UPDATE ITEM'));
      await tester.pumpAndSettle();
      expect(confirmed()!.flags.first, [false, true]);
    });

    testWidgets('an optional single choice can be cleared, a required one not',
        (tester) async {
      final confirmed = await _openEditor(
        tester,
        _line(
          extraVariations: [
            {
              'name': 'Milk',
              'type': 'single',
              'required': 'off',
              'values': [
                {'label': 'Oat', 'optionPrice': '0.5'},
                {'label': 'Soy', 'optionPrice': '0.5'},
              ],
            },
          ],
          extraPicks: [
            {
              'name': 'Milk',
              'values': [
                {'label': 'Oat', 'optionPrice': '0.5'},
              ],
            },
          ],
        ),
      );

      await tester.tap(_tile('Oat'));
      await tester.tap(_tile('Large'));
      await tester.pumpAndSettle();
      expect(_isSelected(tester, 'Oat'), isFalse);
      expect(_isSelected(tester, 'Large'), isTrue);

      await tester.tap(find.textContaining('UPDATE ITEM'));
      await tester.pumpAndSettle();
      expect(confirmed()!.flags[2], [false, false]);
    });

    testWidgets('a multi choice stops at its maximum', (tester) async {
      await _openEditor(
        tester,
        _line(extraVariations: [
          {
            'name': 'Extras',
            'type': 'multi',
            'min': '0',
            'max': '1',
            'required': 'off',
            'values': [
              {'label': 'Extra Shot', 'optionPrice': '0.8'},
              {'label': 'Vanilla Syrup', 'optionPrice': '0.8'},
            ],
          },
        ]),
      );

      expect(find.text('Choose up to 1'), findsOneWidget);
      await tester.tap(_tile('Extra Shot'));
      await tester.tap(_tile('Vanilla Syrup'));
      await tester.pumpAndSettle();
      expect(_isSelected(tester, 'Extra Shot'), isTrue);
      expect(_isSelected(tester, 'Vanilla Syrup'), isFalse);
    });
  });

  group('save-changes payload', () {
    test('carries each line note and its picks in checkout\'s shape', () {
      final CartModel edited = _line(size: 'Small', instruction: 'no sugar');

      expect(posReceiptSaveLines([edited]), [
        {
          'add_on_ids': [199],
          'variations': [
            {
              'name': 'Size',
              'values': {
                'label': ['Small'],
              },
            },
            {
              'name': 'Can or cup?',
              'values': {
                'label': ['Can'],
              },
            },
          ],
          'instruction': 'no sugar',
        },
      ]);
    });

    test('a line without a note sends an explicit null so it is cleared', () {
      final Map<String, dynamic> line = posReceiptSaveLines([_line()]).single;
      expect(line.containsKey('instruction'), isTrue);
      expect(line['instruction'], isNull);
    });
  });

  group('receipt row', () {
    late List<SingleChildWidget> providers;
    setUp(() async => providers = await kioskBaseProviders(withAuth: true));

    Widget host(Widget child) => MultiProvider(
          providers: providers,
          child: MaterialApp(home: Scaffold(body: child)),
        );

    testWidgets('shows the line note when asked to', (tester) async {
      await tester.pumpWidget(host(PosReceiptLine(
        line: _line(instruction: 'no sugar'),
        imageUrl: '',
        quantityOnly: true,
        showInstruction: true,
      )));
      expect(find.text('no sugar'), findsOneWidget);
    });

    testWidgets('the live sale row is unchanged by default', (tester) async {
      await tester.pumpWidget(host(PosReceiptLine(
        line: _line(instruction: 'no sugar'),
        imageUrl: '',
        quantityOnly: true,
      )));
      expect(find.text('no sugar'), findsNothing);
    });
  });
}
