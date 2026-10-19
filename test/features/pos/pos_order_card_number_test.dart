import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_order_card.dart';
import 'package:acafe_customer/features/pos/widgets/pos_order_card_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A board card's headline is the order's public number (`#100014`), so the
/// counter can match a card to a receipt, a kitchen ticket or a customer's
/// screen without opening it. Spelled by [PosOrderCard.numberLabelFor], the
/// same helper behind the detail modal's "Order #…" title.

Map<String, dynamic> _row({Object id = 100014}) => <String, dynamic>{
      'id': id,
      'created_at': '2026-10-19T06:13:00',
      'order_status': 'pending',
      'order_type': 'pos',
      'channel_key': 'counter_pos',
      'order_amount': 6.5,
      'customer_name': 'Walk-in',
      'address_lines': const <String>[],
      'display_method': 'cash',
      'branch_name': 'Acafe/Amsterdam',
    };

Future<void> _pumpCard(WidgetTester tester, PosOrderCard card) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 288,
          child: PosOrderCardTile(
            order: card,
            // 40 minutes in: a late card, red bar and clock.
            now: DateTime(2026, 10, 19, 6, 53),
          ),
        ),
      ),
    ),
  ));
}

Finder _number(int id) => find.byKey(PosOrderCardTile.numberKeyFor(id));

RichText _numberText(WidgetTester tester, int id) => tester.widget<RichText>(
    find.descendant(of: _number(id), matching: find.byType(RichText)));

void main() {
  testWidgets('the card shows the order number as its headline',
      (tester) async {
    await _pumpCard(tester, PosOrderCard.fromJson(_row()));

    expect(_number(100014), findsOneWidget);
    expect(_numberText(tester, 100014).text.toPlainText(), '#100014');
    expect(PosOrderCard.fromJson(_row()).numberLabel, '#100014',
        reason: 'one spelling for card and detail modal');
  });

  testWidgets('it sits above the customer name, in the name\'s size',
      (tester) async {
    await _pumpCard(tester, PosOrderCard.fromJson(_row()));

    final Rect number = tester.getRect(_number(100014));
    final Rect name = tester.getRect(find.text('Walk-in'));
    expect(number.bottom, lessThanOrEqualTo(name.top));
    expect(number.left, name.left, reason: 'one left edge');
    final TextStyle nameStyle =
        tester.widget<Text>(find.text('Walk-in')).style!;
    final TextStyle numberStyle = _numberText(tester, 100014).text.style!;
    expect(numberStyle.fontSize, nameStyle.fontSize);
    expect(numberStyle.fontWeight, nameStyle.fontWeight);
    expect(number.height, name.height);
  });

  testWidgets('a late card keeps the number in ink, not red', (tester) async {
    await _pumpCard(tester, PosOrderCard.fromJson(_row()));

    final TextSpan root = _numberText(tester, 100014).text as TextSpan;
    TextSpan? digits;
    root.visitChildren((InlineSpan span) {
      if (span is TextSpan && span.text == '100014') digits = span;
      return digits == null;
    });
    expect(digits, isNotNull);
    // The digits inherit the number's ink; the late card's red never reaches
    // them.
    expect(digits!.style?.color, isNull);
    expect(root.style?.color, PosHomeSpec.ink);
  });

  testWidgets('an unparseable id draws no number rather than "#0"',
      (tester) async {
    await _pumpCard(tester, PosOrderCard.fromJson(_row(id: 'oops')));

    expect(find.textContaining('#0'), findsNothing);
    expect(_number(0), findsNothing);
    expect(find.text('Walk-in'), findsOneWidget);
  });

  testWidgets('the number fits a narrow card without overflowing',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 140,
            child: PosOrderCardTile(
              order: PosOrderCard.fromJson(_row(id: 123456789012)),
              now: DateTime(2026, 10, 19, 6, 20),
            ),
          ),
        ),
      ),
    ));

    expect(tester.takeException(), isNull);
    expect(_number(123456789012), findsOneWidget);
  });
}
