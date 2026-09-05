import 'package:acafe_customer/features/pos/domain/pos_receipt_export.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipt_filters.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipt_history.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipt_line_copy.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipts_spec.dart';
import 'package:acafe_customer/features/pos/widgets/pos_receipt_detail_panel.dart';
import 'package:acafe_customer/features/pos/widgets/pos_receipt_line.dart';
import 'package:acafe_customer/features/pos/widgets/pos_receipts_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// One `order_details` row as the backend hands it back, i.e. already through
/// `Helpers::order_details_formatter()`: product_details is a whole product
/// whose add_ons are resolved rows carrying is_default.
Map<String, dynamic> _detailJson({
  String name = 'Flat White',
  double price = 5.00,
  int quantity = 1,
  List<int> chosenAddOns = const [70],
  String? sizeLabel = 'Cup',
}) {
  return {
    'product_id': 2,
    'price': price,
    'quantity': quantity,
    'discount_on_product': 0,
    'tax_amount': 0,
    'add_on_ids': chosenAddOns,
    'add_on_qtys': [for (final _ in chosenAddOns) 1],
    'add_on_prices': [for (final _ in chosenAddOns) 0],
    'variation': sizeLabel == null
        ? []
        : [
            {
              'name': 'Can or cup?',
              'type': 'single',
              'values': [
                {'label': sizeLabel, 'optionPrice': 0},
              ],
            },
          ],
    'product_details': {
      'id': 2,
      'name': name,
      'price': price,
      'image': 'flat-white.png',
      'variations': [
        {
          'name': 'Can or cup?',
          'type': 'single',
          'required': 'on',
          'values': [
            {'label': 'Cup', 'optionPrice': 0},
            {'label': 'Can', 'optionPrice': 0},
          ],
        },
      ],
      'add_ons': [
        {'id': 70, 'name': 'Coconut', 'price': 0.60, 'is_default': 0},
        {'id': 71, 'name': 'Almond', 'price': 0.50, 'is_default': 0},
        {'id': 90, 'name': 'Whipped cream', 'price': 0, 'is_default': 1},
      ],
    },
  };
}

Map<String, dynamic> _receiptJson({
  int id = 1000136,
  double subtotal = 20.60,
  double discount = 8.30,
  double total = 12.30,
  Object? table,
  List<Map<String, dynamic>>? details,
}) {
  return {
    'id': id,
    'created_at': '2026-09-04T12:14:00.000000Z',
    'customer_name': 'Dylan',
    'display_method': 'card',
    'payment_method': 'cash_on_delivery',
    'order_status': 'delivered',
    'table': table,
    'subtotal': subtotal,
    'discount': discount,
    'total': total,
    'details': details ?? [_detailJson()],
  };
}

Map<String, dynamic> _rowJson({
  int id = 1000136,
  String customer = 'Dylan',
  String method = 'card',
  double amount = 12.30,
  String products = '2x Flat White + Iced Mango Matcha',
}) {
  return {
    'id': id,
    'created_at': '2026-09-04T12:14:00.000000Z',
    'customer_name': customer,
    'products_summary': products,
    'display_method': method,
    'order_amount': amount,
    'order_status': 'delivered',
    'payment_status': 'paid',
    'channel_key': 'counter_pos',
  };
}

void main() {
  group('PosReceiptRow', () {
    test('reads the additive keys the transactions endpoint gained', () {
      final row = PosReceiptRow.fromJson(_rowJson());

      expect(row.receiptNumber, '#1000136');
      expect(row.customerName, 'Dylan');
      expect(row.productsSummary, '2x Flat White + Iced Mango Matcha');
      expect(row.amount, 12.30);
      expect(row.channelKey, 'counter_pos');
    });

    test('shows the derived method, never the cash_on_delivery wire value', () {
      expect(PosReceiptRow.fromJson(_rowJson(method: 'card')).methodLabel,
          'Card');
      expect(PosReceiptRow.fromJson(_rowJson(method: 'cash')).methodLabel,
          'Cash');
    });

    test('a missing timestamp does not crash the row', () {
      final row = PosReceiptRow.fromJson({..._rowJson(), 'created_at': null});
      expect(row.placedAt, isNull);
      expect(row.placedAtLabel, '—');
    });
  });

  group('PosReceiptDetail', () {
    test('carries the money breakdown through unchanged', () {
      final detail = PosReceiptDetail.fromJson(_receiptJson());

      expect(detail.receiptNumber, '1000136');
      expect(detail.subtotal, 20.60);
      expect(detail.discount, 8.30);
      expect(detail.total, 12.30);
      expect(detail.customerName, 'Dylan');
    });

    test('table stays null when the backend has none to give', () {
      expect(PosReceiptDetail.fromJson(_receiptJson()).table, isNull);
      expect(PosReceiptDetail.fromJson(_receiptJson(table: '')).table, isNull);
      expect(PosReceiptDetail.fromJson(_receiptJson(table: 'B1')).table, 'B1');
    });

    test('adapts a stored line into one the shared row widget can draw', () {
      final detail = PosReceiptDetail.fromJson(_receiptJson(
        details: [_detailJson(quantity: 2)],
      ));

      expect(detail.lines, hasLength(1));
      final line = detail.lines.single;
      expect(posReceiptLineName(line), 'Flat White');
      expect(line.quantity, 2);
      // The cup/can group becomes the "· Cup" suffix, not an add-on note.
      expect(posReceiptUnit(line), 'Cup');
    });

    test('a chosen extra reads +, a removed default reads −', () {
      final detail = PosReceiptDetail.fromJson(_receiptJson(
        details: [_detailJson(chosenAddOns: [70])],
      ));

      final notes = posReceiptNotes(detail.lines.single);
      final included =
          notes.where((n) => n.included).map((n) => n.label).toList();
      final removed =
          notes.where((n) => !n.included).map((n) => n.label).toList();

      // Coconut was picked and is not a default, so it is an addition.
      expect(included, contains('Coconut'));
      // Whipped cream is a default that was not carried over, so it was taken
      // off — exactly the `- Whipped cream` line Figma draws.
      expect(removed, contains('Whipped cream'));
      // Almond was neither picked nor a default: it belongs on neither list.
      expect(included, isNot(contains('Almond')));
      expect(removed, isNot(contains('Almond')));
    });

    test('a corrupt line is skipped rather than blanking the receipt', () {
      final detail = PosReceiptDetail.fromJson(_receiptJson(details: [
        {'product_details': 'not-a-map'},
        _detailJson(),
      ]));

      expect(detail.lines, hasLength(1));
    });
  });

  group('CSV export', () {
    test('quotes anything with a comma, quote or space', () {
      final csv = posReceiptsCsv([
        PosReceiptRow.fromJson(_rowJson(
          customer: 'Van der Berg, Jan',
          products: 'Flat White "large"',
        )),
      ]);

      final lines = csv.trim().split('\n');
      expect(lines.first, contains('"Date & Time"'));
      expect(lines[1], contains('"Van der Berg, Jan"'));
      // A literal quote is doubled, per RFC 4180.
      expect(lines[1], contains('"Flat White ""large"""'));
    });

    test('one header plus one line per row', () {
      final csv = posReceiptsCsv([
        PosReceiptRow.fromJson(_rowJson(id: 1)),
        PosReceiptRow.fromJson(_rowJson(id: 2)),
      ]);

      expect(csv.trim().split('\n'), hasLength(3));
    });

    test('amount is written as a plain number, not a formatted price', () {
      final csv = posReceiptsCsv([PosReceiptRow.fromJson(_rowJson(amount: 7))]);
      expect(csv, contains('7.00'));
      expect(csv, isNot(contains('€')));
    });
  });

  group('date filters', () {
    test('Today stays a single report_date, as the endpoint already served',
        () {
      const range = PosReceiptDateRange.today;
      expect(range.reportDate, isNotNull);
      expect(range.dateFrom, isNull);
      expect(range.dateTo, isNull);
    });

    test('a range sends from/to and drops report_date', () {
      const range = PosReceiptDateRange.last7Days;
      expect(range.reportDate, isNull);
      expect(range.dateFrom, isNotNull);
      expect(range.dateTo, isNotNull);
      expect(range.dateFrom!.compareTo(range.dateTo!), lessThan(0));
    });
  });

  group('receipts table', () {
    Future<void> pumpTable(
      WidgetTester tester, {
      required double width,
      int? selectedId,
      required ValueChanged<PosReceiptRow> onSelect,
    }) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: width,
            height: 600,
            child: PosReceiptsTable(
              rows: [
                PosReceiptRow.fromJson(_rowJson(id: 1, customer: 'Dylan')),
                PosReceiptRow.fromJson(_rowJson(id: 2, customer: 'Yuki')),
              ],
              selectedId: selectedId,
              onSelect: onSelect,
              controller: controller,
            ),
          ),
        ),
      ));
      await tester.pump();
    }

    testWidgets('tapping a row reports that row', (tester) async {
      PosReceiptRow? picked;
      await pumpTable(tester,
          width: 960, onSelect: (row) => picked = row);

      await tester.tap(find.text('#2'));
      await tester.pump();

      expect(picked?.id, 2);
    });

    testWidgets('the selected row is ink-filled and its text goes white',
        (tester) async {
      await pumpTable(tester,
          width: 960, selectedId: 1, onSelect: (_) {});

      final Text customer = tester.widget<Text>(find.text('Dylan'));
      expect(customer.style?.color, PosReceiptsSpec.selectedInk);

      final Text other = tester.widget<Text>(find.text('Yuki'));
      expect(other.style?.color, isNot(PosReceiptsSpec.selectedInk));
    });

    testWidgets('no overflow at any supported width', (tester) async {
      for (final double width in [1366, 966, 800, 640, 480]) {
        await pumpTable(tester, width: width, onSelect: (_) {});
        expect(tester.takeException(), isNull,
            reason: 'table overflowed at ${width}px');
      }
    });

    testWidgets('empty state explains itself instead of showing a blank box',
        (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PosReceiptsTable(
            rows: const [],
            selectedId: null,
            onSelect: (_) {},
            controller: controller,
          ),
        ),
      ));
      await tester.pump();

      expect(find.text('No receipts for this filter'), findsOneWidget);
    });
  });

  group('receipt detail panel', () {
    Future<void> pumpPanel(
      WidgetTester tester, {
      PosReceiptDetail? receipt,
      bool loading = false,
      VoidCallback? onPrint,
    }) async {
      tester.view.physicalSize = const Size(1366, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 926,
            child: PosReceiptDetailPanel(
              receipt: receipt,
              loading: loading,
              onPrint: onPrint,
              imageBaseUrl: null,
            ),
          ),
        ),
      ));
      await tester.pump();
    }

    testWidgets('renders the receipt without the ⋯ options button',
        (tester) async {
      await pumpPanel(tester,
          receipt: PosReceiptDetail.fromJson(_receiptJson()));

      expect(find.text('Purchase Receipt'), findsOneWidget);
      expect(find.text('#1000136'), findsOneWidget);
      // The live panel's ⋯ is a Material over an InkWell inside the header;
      // absence of the SVG is what showOptions: false buys.
      expect(find.byIcon(Icons.more_vert), findsNothing);
    });

    testWidgets('customer and table fields are read-only', (tester) async {
      await pumpPanel(tester,
          receipt: PosReceiptDetail.fromJson(_receiptJson(table: 'B1')));

      final fields = tester.widgetList<TextField>(find.byType(TextField));
      expect(fields, hasLength(2));
      for (final field in fields) {
        expect(field.readOnly, isTrue);
      }
      expect(fields.first.controller?.text, 'Dylan');
      expect(fields.last.controller?.text, 'B1');
    });

    testWidgets('an absent table renders an empty field, never a placeholder',
        (tester) async {
      await pumpPanel(tester,
          receipt: PosReceiptDetail.fromJson(_receiptJson()));

      final fields = tester.widgetList<TextField>(find.byType(TextField));
      expect(fields.last.controller?.text, isEmpty);
    });

    testWidgets('lines carry a static qty badge, not the stepper',
        (tester) async {
      await pumpPanel(tester,
          receipt: PosReceiptDetail.fromJson(_receiptJson()));

      expect(find.byKey(const Key('pos-qty-badge')), findsOneWidget);
      expect(find.byKey(const Key('pos-qty-plus')), findsNothing);
      expect(find.byKey(const Key('pos-qty-minus')), findsNothing);
      expect(find.byKey(const Key('pos-qty-delete')), findsNothing);
      expect(find.text('EDIT'), findsNothing);
    });

    testWidgets('Print is offered for a receipt and withheld without one',
        (tester) async {
      var printed = 0;
      await pumpPanel(tester,
          receipt: PosReceiptDetail.fromJson(_receiptJson()),
          onPrint: () => printed++);

      await tester.tap(find.text('Print Receipt'));
      await tester.pump();
      expect(printed, 1);

      await pumpPanel(tester, receipt: null);
      expect(find.text('Print Receipt'), findsOneWidget);
      await tester.tap(find.text('Print Receipt'));
      await tester.pump();
      // Still 1: the button stays on screen to hold the panel's height, but
      // does nothing without a receipt behind it.
      expect(printed, 1);
    });

    testWidgets('nothing selected shows a prompt, not an empty panel',
        (tester) async {
      await pumpPanel(tester, receipt: null);
      expect(find.text('No receipt selected'), findsOneWidget);
    });

    testWidgets('switching receipts replaces every field', (tester) async {
      await pumpPanel(tester,
          receipt: PosReceiptDetail.fromJson(
              _receiptJson(id: 1, table: 'B1')));
      expect(find.text('#1'), findsOneWidget);

      await pumpPanel(tester,
          receipt: PosReceiptDetail.fromJson(_receiptJson(
            id: 2,
            details: [_detailJson(name: 'Iced Mango Matcha')],
          )));
      await tester.pump();

      expect(find.text('#2'), findsOneWidget);
      expect(find.text('#1'), findsNothing);
      expect(find.text('Iced Mango Matcha'), findsOneWidget);
      expect(find.text('Flat White'), findsNothing);
      // The table controller must not keep the previous receipt's value.
      final fields = tester.widgetList<TextField>(find.byType(TextField));
      expect(fields.last.controller?.text, isEmpty);
    });

    testWidgets('no overflow while a receipt is on screen', (tester) async {
      await pumpPanel(tester,
          receipt: PosReceiptDetail.fromJson(_receiptJson(details: [
        _detailJson(name: 'A very long product name that will not fit at all'),
        _detailJson(name: 'Second line', chosenAddOns: [70, 71]),
      ])));

      expect(tester.takeException(), isNull);
    });
  });

  group('shared receipt row stays a live-sale control by default', () {
    testWidgets('quantityOnly defaults to false, keeping the stepper',
        (tester) async {
      final detail = PosReceiptDetail.fromJson(_receiptJson());

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PosReceiptLine(
            line: detail.lines.single,
            imageUrl: '',
            onIncrement: () {},
            onDecrement: () {},
          ),
        ),
      ));
      await tester.pump();

      expect(find.byKey(const Key('pos-qty-badge')), findsNothing);
      expect(find.byKey(const Key('pos-qty-plus')), findsOneWidget);
    });
  });
}
