import 'package:acafe_customer/features/pos/domain/pos_order_card.dart';
import 'package:acafe_customer/features/pos/domain/pos_orders_spec.dart';
import 'package:acafe_customer/features/pos/widgets/pos_order_card_grid.dart';
import 'package:acafe_customer/features/pos/widgets/pos_order_card_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every card on the board is one size: a card with no note, a one-line note
/// or a two-line note (the user's 2026-10-19 report), and the grid evens out
/// whatever else differs — a third address line, a progress row.

PosOrderCard _card(
  int id, {
  List<Map<String, dynamic>> notes = const [],
  List<String> address = const [],
  String status = 'completed',
}) =>
    PosOrderCard.fromJson(<String, dynamic>{
      'id': id,
      'created_at': '2026-10-19T06:05:00',
      'order_status': status,
      'order_type': 'pos',
      'channel_key': 'counter_pos',
      'order_amount': 88.0 + id,
      'customer_name': 'Walk-in',
      'address_lines': address,
      'display_method': 'cash',
      'branch_name': 'Acafe/Amsterdam',
      'notes': notes,
    });

final PosOrderCard _noNote = _card(1);
final PosOrderCard _oneLine = _card(2, notes: [
  {'item': null, 'quantity': null, 'text': 'Extra hot'},
]);
final PosOrderCard _twoLines = _card(3, notes: [
  {'item': 'Fresh Mint Tea', 'quantity': 1, 'text': 'notes for testing ' * 6},
]);

final DateTime _now = DateTime(2026, 10, 19, 6, 25);

Widget _tile(PosOrderCard order, {VoidCallback? onTap}) => PosOrderCardTile(
      key: ValueKey<int>(order.id),
      order: order,
      now: _now,
      onTap: onTap,
    );

Future<void> _pumpGrid(
  WidgetTester tester,
  List<Widget> children, {
  double width = 1318,
}) async {
  // The POS's 1366 window, so a 1318 board really is 1318 wide.
  tester.view.physicalSize = const Size(1366, 1024);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: PosOrderCardGrid(
            itemWidth: PosOrdersSpec.cardWidth,
            spacing: PosOrdersSpec.cardGap,
            runSpacing: PosOrdersSpec.cardGap,
            children: children,
          ),
        ),
      ),
    ),
  ));
}

Future<double> _standaloneHeight(WidgetTester tester, PosOrderCard o) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: PosOrdersSpec.cardWidth, child: _tile(o)),
      ),
    ),
  ));
  return tester.getSize(find.byType(PosOrderCardTile)).height;
}

Rect _rectOf(WidgetTester tester, PosOrderCard o) =>
    tester.getRect(find.byKey(ValueKey<int>(o.id)));

Rect _inCard(WidgetTester tester, PosOrderCard o, Finder f) => tester.getRect(
    find.descendant(of: find.byKey(ValueKey<int>(o.id)), matching: f));

Finder _strip(PosOrderCard o) =>
    find.byKey(PosOrderCardTile.notePreviewKeyFor(o.id));

void main() {
  testWidgets('the fixtures really are no note, one line and two lines',
      (tester) async {
    await _pumpGrid(tester, [_tile(_noNote), _tile(_oneLine), _tile(_twoLines)]);

    expect(_strip(_noNote), findsNothing);
    expect(tester.getSize(_strip(_oneLine)).height,
        PosOrdersSpec.notePreviewPadV * 2 + PosOrdersSpec.notePreviewLineHeight);
    expect(tester.getSize(_strip(_twoLines)).height,
        PosOrdersSpec.notePreviewSlotHeight);
  });

  testWidgets('a card keeps the two-line note room even on its own',
      (tester) async {
    final double none = await _standaloneHeight(tester, _noNote);
    final double one = await _standaloneHeight(tester, _oneLine);
    final double two = await _standaloneHeight(tester, _twoLines);

    expect(none, two);
    expect(one, two);
  });

  testWidgets('no note, one line, two lines: one size, timer and price aligned',
      (tester) async {
    await _pumpGrid(tester, [_tile(_noNote), _tile(_oneLine), _tile(_twoLines)]);

    final List<PosOrderCard> all = [_noNote, _oneLine, _twoLines];
    final Rect first = _rectOf(tester, _noNote);
    for (final PosOrderCard o in all) {
      final Rect r = _rectOf(tester, o);
      expect(r.size, first.size, reason: 'card ${o.id}');
      expect(r.top, first.top, reason: 'card ${o.id}');
      expect(_inCard(tester, o, find.text('Done')).top - r.top,
          _inCard(tester, _noNote, find.text('Done')).top - first.top,
          reason: 'card ${o.id}: "Done" sits on the same line');
      expect(r.bottom - _inCard(tester, o, find.textContaining('€')).bottom,
          first.bottom - _inCard(tester, _noNote, find.textContaining('€')).bottom,
          reason: 'card ${o.id}: price pinned to the bottom edge');
    }
    // The strip still sits under the customer block, above the timer.
    expect(_inCard(tester, _twoLines, _strip(_twoLines)).bottom,
        lessThan(_inCard(tester, _twoLines, find.text('Done')).top));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a taller card lifts the whole section to its height',
      (tester) async {
    final PosOrderCard delivery = _card(4,
        address: ['Potsdamer Str. 33', '14974 Ludwigsfelde', 'Germany'],
        notes: [
          {'item': null, 'quantity': null, 'text': 'Ring twice ' * 8},
        ]);
    final PosOrderCard preparing = _card(5, status: 'preparing');
    final double standard = await _standaloneHeight(tester, _noNote);

    await _pumpGrid(tester, [
      _tile(_noNote),
      _tile(delivery),
      _tile(_twoLines),
      _tile(preparing),
      _tile(_oneLine),
    ]);

    final double tallest = _rectOf(tester, delivery).height;
    expect(tallest, greaterThan(standard));
    for (final PosOrderCard o in [_noNote, _twoLines, preparing, _oneLine]) {
      expect(_rectOf(tester, o).height, tallest, reason: 'card ${o.id}');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('wraps 288px cards 12 apart, rows equally spaced',
      (tester) async {
    // 600 fits two 288 cards and a 12 gap.
    await _pumpGrid(
      tester,
      [_tile(_noNote), _tile(_oneLine), _tile(_twoLines)],
      width: 600,
    );

    final Rect a = _rectOf(tester, _noNote);
    final Rect b = _rectOf(tester, _oneLine);
    final Rect c = _rectOf(tester, _twoLines);
    expect(a.width, PosOrdersSpec.cardWidth);
    expect(b.left - a.right, PosOrdersSpec.cardGap);
    expect(b.top, a.top);
    expect(c.left, a.left);
    expect(c.top - a.bottom, PosOrdersSpec.cardGap);
  });

  testWidgets('narrower than one card: cards take the width, never overflow',
      (tester) async {
    await _pumpGrid(tester, [_tile(_noNote), _tile(_twoLines)], width: 240);

    expect(_rectOf(tester, _noNote).width, 240);
    expect(_rectOf(tester, _twoLines).top,
        _rectOf(tester, _noNote).bottom + PosOrdersSpec.cardGap);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a tap still reaches the card it lands on', (tester) async {
    final List<int> tapped = <int>[];
    await _pumpGrid(tester, [
      _tile(_noNote, onTap: () => tapped.add(_noNote.id)),
      _tile(_twoLines, onTap: () => tapped.add(_twoLines.id)),
    ]);

    await tester.tapAt(_rectOf(tester, _twoLines).center);
    // Inside the first card's reserved note room, where nothing is drawn.
    await tester.tapAt(_rectOf(tester, _noNote).center);
    expect(tapped, [_twoLines.id, _noNote.id]);
  });

  testWidgets('an empty section lays out to nothing', (tester) async {
    await _pumpGrid(tester, const []);
    expect(tester.getSize(find.byType(PosOrderCardGrid)).height, 0);
  });
}
