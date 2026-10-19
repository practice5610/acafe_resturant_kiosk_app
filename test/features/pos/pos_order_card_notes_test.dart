import 'package:acafe_customer/features/pos/domain/pos_order_card.dart';
import 'package:acafe_customer/features/pos/widgets/pos_order_card_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A board card flags an order that carries notes, so staff see "less sugar"
/// before opening it: an amber strip under the customer block previewing the
/// first note and counting the rest. Driven by the board feed's `notes`.

/// Order #100014's line note, as typed (two lines).
const String _lineNote =
    'I AM UISING LESS SUGAR IN ICE\nIF PSOSIBLE USE ALERNATIV OF OTHER';

Map<String, dynamic> _row({Object? notes, String status = 'preparing'}) =>
    <String, dynamic>{
      'id': 100014,
      'created_at': '2026-10-19T06:13:00',
      'order_status': status,
      'order_type': 'pos',
      'channel_key': 'counter_pos',
      'order_amount': 6.5,
      'customer_name': 'Walk-in',
      'address_lines': const <String>[],
      'display_method': 'cash',
      'branch_name': 'Acafe/Amsterdam',
      'item_states': const [
        {'id': 7, 'prep_status': 'pending'},
      ],
      if (notes != null) 'notes': notes,
    };

final Finder _preview =
    find.byKey(PosOrderCardTile.notePreviewKeyFor(100014));

Future<void> _pumpCard(WidgetTester tester, PosOrderCard card) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 288,
          child: PosOrderCardTile(
            order: card,
            now: DateTime(2026, 10, 19, 6, 25),
          ),
        ),
      ),
    ),
  ));
}

/// The strip's whole text, spans joined.
String _previewText(WidgetTester tester) => tester
    .widgetList<RichText>(
      find.descendant(of: _preview, matching: find.byType(RichText)),
    )
    .map((r) => r.text.toPlainText())
    .join(' ');

void main() {
  group('parsing', () {
    test('notes: order note and line notes, blank or malformed rows dropped',
        () {
      final PosOrderCard card = PosOrderCard.fromJson(_row(notes: [
        {'item': null, 'quantity': null, 'text': 'Allergic to nuts'},
        {'item': 'Latte', 'quantity': 2, 'text': 'Oat milk'},
        {'item': 'Tea', 'quantity': 1, 'text': '   '},
        'junk',
      ]));

      expect(card.hasNotes, isTrue);
      expect(card.notes, hasLength(2));
      expect(card.notes.first.itemLabel, isNull);
      expect(card.notes.last.itemLabel, '2× Latte');
      expect(card.withStatus('item_to_collect').notes, card.notes,
          reason: 'an optimistic move keeps the flag');
    });

    test('an older API without the key flags nothing', () {
      expect(PosOrderCard.fromJson(_row()).hasNotes, isFalse);
    });
  });

  group('card', () {
    testWidgets('a line note shows as an amber strip with its line name',
        (tester) async {
      await _pumpCard(
        tester,
        PosOrderCard.fromJson(_row(notes: [
          {'item': 'Fresh Mint Tea', 'quantity': 1, 'text': _lineNote},
        ])),
      );

      expect(_preview, findsOneWidget);
      final String text = _previewText(tester);
      expect(text, contains('Fresh Mint Tea: '));
      expect(text, contains('LESS SUGAR IN ICE IF PSOSIBLE'),
          reason: 'a typed line break reads as a space on the preview');
      expect(tester.takeException(), isNull);
    });

    testWidgets('it sits under the customer block, above the timer',
        (tester) async {
      await _pumpCard(
        tester,
        PosOrderCard.fromJson(_row(notes: [
          {'item': 'Fresh Mint Tea', 'quantity': 1, 'text': _lineNote},
        ])),
      );

      final Rect strip = tester.getRect(_preview);
      expect(strip.top,
          greaterThan(tester.getRect(find.text('Acafe/Amsterdam')).bottom));
      expect(strip.bottom, lessThan(tester.getRect(find.text('€ 6.50')).top));
    });

    testWidgets('more than one note: the first is previewed, the rest counted',
        (tester) async {
      await _pumpCard(
        tester,
        PosOrderCard.fromJson(_row(notes: [
          {'item': null, 'quantity': null, 'text': 'Allergic to nuts'},
          {'item': 'Latte', 'quantity': 2, 'text': 'Oat milk'},
          {'item': 'Bagel', 'quantity': 1, 'text': 'No seeds'},
        ])),
      );

      expect(_previewText(tester), contains('Allergic to nuts'));
      expect(_previewText(tester), isNot(contains('Oat milk')));
      expect(find.descendant(of: _preview, matching: find.text('+2')),
          findsOneWidget);
    });

    testWidgets('a long note is clipped to two lines, never overflowing',
        (tester) async {
      await _pumpCard(
        tester,
        PosOrderCard.fromJson(_row(notes: [
          {'item': 'Bagel', 'quantity': 1, 'text': 'no seeds ' * 20},
        ])),
      );

      expect(tester.takeException(), isNull);
      expect(tester.getSize(_preview).height, lessThan(48));
    });

    testWidgets('an order without notes draws no strip', (tester) async {
      await _pumpCard(tester, PosOrderCard.fromJson(_row(notes: const [])));
      expect(_preview, findsNothing);
    });

    testWidgets('NEW and finished cards flag notes too', (tester) async {
      for (final String status in ['new', 'completed']) {
        await _pumpCard(
          tester,
          PosOrderCard.fromJson(_row(status: status, notes: [
            {'item': 'Latte', 'quantity': 1, 'text': 'Extra hot'},
          ])),
        );
        expect(_preview, findsOneWidget, reason: status);
        expect(tester.takeException(), isNull, reason: status);
      }
    });
  });
}
