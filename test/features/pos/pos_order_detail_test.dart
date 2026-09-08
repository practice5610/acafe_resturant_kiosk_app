import 'package:acafe_customer/features/pos/domain/pos_order_detail.dart';
import 'package:acafe_customer/features/pos/domain/pos_order_grouping.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shapes taken from real `GET /api/v1/kiosk/manager/transactions/{id}`
/// responses on the local branch-1 data, not invented.
Map<String, dynamic> _payload({
  String customerName = 'Sanne de Vries',
  String? phone,
  String? email,
  String? note,
  String status = 'new',
  List<Map<String, dynamic>> items = const [],
}) {
  return <String, dynamic>{
    'id': 1000164,
    'created_at': '2026-09-08T08:57:22.000000Z',
    'order_status': status,
    'order_type': 'pos',
    'channel_key': 'counter_pos',
    'display_method': 'cash',
    'payment_status': 'paid',
    'table': null,
    'customer_name': customerName,
    'customer_phone': phone,
    'customer_email': email,
    'order_note': note,
    'items': items,
    'subtotal': 4.5,
    'discount': 0,
    'total': 4.5,
  };
}

void main() {
  group('Customer Details is omitted unless there is real contact data', () {
    test('guest order (no users row) has no contact', () {
      // 49 of 57 local orders are guests: this is the common case.
      final d = PosOrderDetail.fromJson(_payload());
      expect(d.hasContact, isFalse);
    });

    test('registered customer with either field has contact', () {
      expect(
        PosOrderDetail.fromJson(_payload(phone: '+923049153165')).hasContact,
        isTrue,
      );
      expect(
        PosOrderDetail.fromJson(_payload(email: 'chef@gmail.com')).hasContact,
        isTrue,
      );
    });

    test('empty strings do not count as contact', () {
      final d = PosOrderDetail.fromJson(_payload(phone: '   ', email: ''));
      expect(d.hasContact, isFalse);
    });
  });

  group('Order Notes never duplicates the customer name', () {
    test('a note that is only the name-carrier is dropped entirely', () {
      // The real shape: displayCustomerName() parses the name back out of
      // this line, so it is already on screen in the header.
      final d = PosOrderDetail.fromJson(
        _payload(note: 'Kiosk order — Sanne de Vries'),
      );
      expect(d.displayNote, isNull);
    });

    test('en dash and hyphen carriers are dropped too', () {
      for (final String dash in ['—', '–', '-']) {
        final d = PosOrderDetail.fromJson(
          _payload(note: 'Kiosk order $dash Sanne de Vries'),
        );
        expect(d.displayNote, isNull, reason: 'dash: $dash');
      }
    });

    test('a real note under the carrier line survives', () {
      final d = PosOrderDetail.fromJson(
        _payload(note: 'Kiosk order — Sanne de Vries\nExtra hot please'),
      );
      expect(d.displayNote, 'Extra hot please');
    });

    test('a carrier naming someone else is kept, not silently eaten', () {
      final d = PosOrderDetail.fromJson(
        _payload(customerName: 'Sanne de Vries', note: 'Kiosk order — Someone Else'),
      );
      expect(d.displayNote, 'Kiosk order — Someone Else');
    });

    test('a plain note is untouched', () {
      // Real row 1000143.
      final d = PosOrderDetail.fromJson(
        _payload(note: 'Web order\n[dev-receipt-fixture]'),
      );
      expect(d.displayNote, 'Web order\n[dev-receipt-fixture]');
    });

    test('empty / whitespace notes render nothing', () {
      expect(PosOrderDetail.fromJson(_payload(note: null)).displayNote, isNull);
      expect(PosOrderDetail.fromJson(_payload(note: '   ')).displayNote, isNull);
    });
  });

  group('Item notes only appear where the line has them', () {
    test('a line with no add-ons and no instruction has no notes', () {
      final d = PosOrderDetail.fromJson(_payload(items: [
        {'name': 'Flat White', 'quantity': 1, 'unit_price': 5.0, 'addons': [], 'variations': []},
      ]));
      expect(d.items.single.hasNotes, isFalse);
    });

    test('resolved add-on names come through', () {
      // Real: add_on_ids [20,21] resolve to these via OrderPreviewPresenter.
      final d = PosOrderDetail.fromJson(_payload(items: [
        {
          'name': 'Flat White',
          'quantity': 2,
          'unit_price': 5.0,
          'instruction': null,
          'variations': [],
          'addons': [
            {'name': 'Test Addon 4', 'quantity': 1},
            {'name': 'Test Addon3', 'quantity': 1},
          ],
        },
      ]));
      final item = d.items.single;
      expect(item.hasNotes, isTrue);
      expect(item.addons.map((a) => a.name), ['Test Addon 4', 'Test Addon3']);
    });

    test('a per-line instruction alone is enough', () {
      final d = PosOrderDetail.fromJson(_payload(items: [
        {'name': 'Latte', 'quantity': 1, 'unit_price': 4.0, 'instruction': 'more ice hige', 'addons': [], 'variations': []},
      ]));
      expect(d.items.single.hasNotes, isTrue);
    });

    test('variation labels flatten for the meta line', () {
      final d = PosOrderDetail.fromJson(_payload(items: [
        {
          'name': 'Cappuccino',
          'quantity': 1,
          'unit_price': 4.5,
          'addons': [],
          'variations': [
            {'name': 'Size', 'options': [{'label': 'Cup', 'price': 0}]},
          ],
        },
      ]));
      expect(d.items.single.variationLabels, ['Cup']);
    });
  });

  group('The overlay action is the board ladder, not a hardcoded jump', () {
    test('a preparing order advances to ready, never straight to complete', () {
      // Decision 1: skipping item_to_collect would skip ready_at and the
      // "ready to collect" push the customer gets at that rung.
      expect(PosOrderGrouping.nextStatusFor('preparing'), 'item_to_collect');
      expect(PosOrderGrouping.actionLabelFor('preparing'), 'Mark as ready');
    });

    test('item_to_collect is the rung that completes', () {
      expect(PosOrderGrouping.nextStatusFor('item_to_collect'), 'completed');
      expect(PosOrderGrouping.actionLabelFor('item_to_collect'), 'Mark as complete');
    });

    test('on_hold resumes', () {
      expect(PosOrderGrouping.actionLabelFor('on_hold'), 'Resume');
    });

    test('finished orders offer no action, so the bar shows a label', () {
      for (final String s in ['completed', 'delivered']) {
        expect(PosOrderGrouping.nextStatusFor(s), isNull, reason: s);
        expect(PosOrderGrouping.actionLabelFor(s), isNull, reason: s);
      }
    });
  });
}
