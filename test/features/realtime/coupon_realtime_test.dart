import 'dart:convert';

import 'package:acafe_customer/features/realtime/catalog_event.dart';
import 'package:acafe_customer/features/realtime/catalog_socket_frame.dart';
import 'package:flutter_test/flutter_test.dart';

/// Frames as Reverb delivers them: `data` arrives as a JSON string.
String _frame(String event, Map<String, dynamic> data) => jsonEncode({
      'event': event,
      'channel': 'branch.1.products',
      'data': jsonEncode(data),
    });

void main() {
  group('coupon.changed frame', () {
    test('parses a coupon event', () {
      final CatalogEvent? event = CatalogSocketFrame.couponChanged(_frame(
        'coupon.changed',
        {
          'v': 1,
          'event_id': 'abc-123',
          'action': 'updated',
          'coupon_id': 42,
          'branch_id': 1,
          'occurred_at': '2026-09-03T10:00:00+00:00',
        },
      ));

      expect(event, isNotNull);
      expect(event!.couponId, 42);
      expect(event.isCoupon, isTrue);
      expect(event.action, 'updated');
      expect(event.branchId, 1);
      expect(event.eventId, 'abc-123');
    });

    test('a delete action is recognised', () {
      final CatalogEvent? event = CatalogSocketFrame.couponChanged(_frame(
        'coupon.changed',
        {'action': 'deleted', 'coupon_id': 7, 'branch_id': 1, 'event_id': 'e2'},
      ));
      expect(event, isNotNull);
      expect(event!.isDelete, isTrue);
      expect(event.couponId, 7);
    });

    test('ignores a deal frame', () {
      expect(
        CatalogSocketFrame.couponChanged(
            _frame('deal.changed', {'deal_id': 3, 'branch_id': 1})),
        isNull,
      );
    });

    test('a coupon frame is not mistaken for a deal', () {
      final CatalogEvent? asDeal = CatalogSocketFrame.dealChanged(
          _frame('coupon.changed', {'coupon_id': 9, 'branch_id': 1}));
      expect(asDeal, isNull);
    });

    test('a deal event carries no coupon id, and vice versa', () {
      final deal = CatalogSocketFrame.dealChanged(
          _frame('deal.changed', {'deal_id': 5, 'branch_id': 1}));
      expect(deal!.couponId, 0);
      expect(deal.isCoupon, isFalse);

      final coupon = CatalogSocketFrame.couponChanged(
          _frame('coupon.changed', {'coupon_id': 5, 'branch_id': 1}));
      expect(coupon!.dealId, 0);
      expect(coupon.isDeal, isFalse);
    });

    test('malformed payloads are ignored rather than thrown', () {
      expect(CatalogSocketFrame.couponChanged('not json'), isNull);
      expect(CatalogSocketFrame.couponChanged(null), isNull);
      expect(
        CatalogSocketFrame.couponChanged(
            jsonEncode({'event': 'coupon.changed', 'data': 'not-a-map'})),
        isNull,
      );
    });
  });
}
