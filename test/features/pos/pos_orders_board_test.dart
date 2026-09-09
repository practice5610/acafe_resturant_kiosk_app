import 'package:acafe_customer/features/pos/domain/pos_order_card.dart';
import 'package:acafe_customer/features/pos/domain/pos_order_grouping.dart';
import 'package:acafe_customer/features/pos/domain/pos_order_timer.dart';
import 'package:flutter_test/flutter_test.dart';

/// The two pieces of board logic that carry operational meaning: which section
/// an order lands in, and when it starts looking late. Both are pure functions,
/// so they are tested directly rather than through the widget tree.
void main() {
  group('PosOrderGrouping', () {
    test('new and its legacy alias land in NEW', () {
      expect(PosOrderGrouping.sectionOf('new'), PosOrderSection.newOrders);
      expect(PosOrderGrouping.sectionOf('pending'), PosOrderSection.newOrders);
    });

    test('preparing and on_hold land in IN PROGRESS', () {
      expect(
        PosOrderGrouping.sectionOf('preparing'),
        PosOrderSection.inProgress,
      );
      // A paused order is still active — it simply is not progressing.
      expect(
        PosOrderGrouping.sectionOf('on_hold'),
        PosOrderSection.inProgress,
      );
    });

    test('item_to_collect, completed and legacy delivered land in FINISHED', () {
      expect(
        PosOrderGrouping.sectionOf('item_to_collect'),
        PosOrderSection.finished,
      );
      expect(
        PosOrderGrouping.sectionOf('completed'),
        PosOrderSection.finished,
      );
      // `delivered` is a live legacy value on real rows, not just an alias
      // constant. Dropping it would silently hide those orders.
      expect(
        PosOrderGrouping.sectionOf('delivered'),
        PosOrderSection.finished,
      );
    });

    test('canceled is excluded from the board entirely', () {
      expect(PosOrderGrouping.sectionOf('canceled'), PosOrderSection.excluded);
      expect(
        PosOrderGrouping.sectionOf('canceled'),
        isNot(PosOrderSection.finished),
      );
    });

    test('an unknown future status is excluded, never mis-sectioned', () {
      expect(
        PosOrderGrouping.sectionOf('some_new_status'),
        PosOrderSection.excluded,
      );
    });

    test('the ladder matches the Kitchen Display rung for rung', () {
      // Same switch as `_AdvanceButton._nextStatus()` in
      // acafe_resturant_kitchen_app/lib/features/home/widgets/order_card_widget.dart.
      expect(PosOrderGrouping.nextStatusFor('new'), 'preparing');
      expect(PosOrderGrouping.nextStatusFor('pending'), 'preparing');
      expect(PosOrderGrouping.nextStatusFor('preparing'), 'item_to_collect');
      expect(PosOrderGrouping.nextStatusFor('item_to_collect'), 'completed');
      // Resume; the server re-derives the true status from the item aggregate.
      expect(PosOrderGrouping.nextStatusFor('on_hold'), 'preparing');
    });

    test('preparing never jumps straight to completed', () {
      // Skipping item_to_collect would skip `ready_at` and the customer's
      // "ready to collect" push.
      expect(
        PosOrderGrouping.nextStatusFor('preparing'),
        isNot('completed'),
      );
    });

    test('terminal statuses offer no action', () {
      expect(PosOrderGrouping.nextStatusFor('completed'), isNull);
      expect(PosOrderGrouping.nextStatusFor('delivered'), isNull);
      expect(PosOrderGrouping.nextStatusFor('canceled'), isNull);
      expect(PosOrderGrouping.actionLabelFor('completed'), isNull);
    });

    test('every status on the board has a firing action or is terminal', () {
      // The invariant the section/action split has to preserve: nothing may sit
      // in a section holding a button that can never legally fire.
      final Set<String> onBoard = {
        ...PosOrderGrouping.newStatuses,
        ...PosOrderGrouping.inProgressStatuses,
        ...PosOrderGrouping.finishedStatuses,
      };

      for (final String status in onBoard) {
        final String? next = PosOrderGrouping.nextStatusFor(status);
        final bool terminal = const {'completed', 'delivered'}.contains(status);

        if (terminal) {
          expect(next, isNull, reason: '\$status is terminal');
        } else {
          expect(next, isNotNull,
              reason: '\$status is on the board and must be advanceable');
          expect(PosOrderGrouping.actionLabelFor(status), isNotNull);
        }
      }
    });

    test('item_to_collect is grouped FINISHED yet still advanceable', () {
      // The exact case the section-keyed version got wrong: drawn under
      // FINISHED, but not terminal, so its card still finishes it.
      expect(
        PosOrderGrouping.sectionOf('item_to_collect'),
        PosOrderSection.finished,
      );
      expect(PosOrderGrouping.nextStatusFor('item_to_collect'), 'completed');
    });

    test('action labels describe the transition they actually perform', () {
      // Figma 1641:4341's own CTA for a NEW order.
      expect(PosOrderGrouping.actionLabelFor('new'), 'Accept order');
      // Not "Mark as complete", which is what Figma draws here: this rung makes
      // the order ready, it does not finish it.
      expect(PosOrderGrouping.actionLabelFor('preparing'), 'Mark as ready');
      expect(
        PosOrderGrouping.actionLabelFor('item_to_collect'),
        'Mark as complete',
      );
      expect(PosOrderGrouping.actionLabelFor('on_hold'), 'Resume');
    });
  });

  group('PosOrderTimer', () {
    final DateTime now = DateTime(2026, 9, 5, 12, 0, 0);

    PosOrderUrgency at(int minutesAgo, {String status = 'new'}) =>
        PosOrderTimer.urgencyOf(
          orderStatus: status,
          createdAt: now.subtract(Duration(minutes: minutesAgo)),
          now: now,
        );

    test('uses the Kitchen app 5 / 15 minute thresholds exactly', () {
      expect(at(0), PosOrderUrgency.normal);
      expect(at(4), PosOrderUrgency.normal);
      expect(at(5), PosOrderUrgency.warning);
      expect(at(14), PosOrderUrgency.warning);
      expect(at(15), PosOrderUrgency.urgent);
      expect(at(90), PosOrderUrgency.urgent);
    });

    test('escalates for in-progress orders too, not only new ones', () {
      expect(at(20, status: 'preparing'), PosOrderUrgency.urgent);
    });

    test('an order waiting on the pass keeps escalating', () {
      // item_to_collect is drawn under FINISHED but is not finished. An order
      // uncollected for 20 minutes is exactly what staff need flagged, so the
      // urgency follows the status, not the section.
      expect(at(20, status: 'item_to_collect'), PosOrderUrgency.urgent);
      expect(at(1, status: 'item_to_collect'), PosOrderUrgency.normal);
    });

    test('a genuinely terminal order reads done however long it took', () {
      expect(at(240, status: 'completed'), PosOrderUrgency.done);
      expect(at(240, status: 'delivered'), PosOrderUrgency.done);
    });

    test('elapsed counts up, and formats as m:ss then h:mm:ss', () {
      expect(
        PosOrderTimer.elapsedLabel(
          now.subtract(const Duration(minutes: 5, seconds: 23)),
          now: now,
        ),
        '5:23',
      );
      expect(
        PosOrderTimer.elapsedLabel(
          now.subtract(const Duration(seconds: 48)),
          now: now,
        ),
        '0:48',
      );
      expect(
        PosOrderTimer.elapsedLabel(
          now.subtract(const Duration(hours: 2, minutes: 3, seconds: 4)),
          now: now,
        ),
        '2:03:04',
      );
    });

    test('a terminal clock ahead of the server never renders a negative time',
        () {
      expect(
        PosOrderTimer.elapsedLabel(
          now.add(const Duration(minutes: 3)),
          now: now,
        ),
        '0:00',
      );
    });

    test('a missing created_at renders nothing rather than a fake time', () {
      expect(PosOrderTimer.elapsedLabel(null, now: now), '');
      expect(
        PosOrderTimer.urgencyOf(
          orderStatus: 'new',
          createdAt: null,
          now: now,
        ),
        PosOrderUrgency.normal,
      );
    });
  });

  group('PosOrderCard', () {
    PosOrderCard build({
      List<String> addressLines = const [],
      String channelKey = 'counter_pos',
      String? branchName = 'Acafe/Amsterdam',
    }) =>
        PosOrderCard(
          id: 1,
          createdAt: DateTime(2026, 9, 5, 10, 36),
          orderStatus: 'new',
          orderType: 'pos',
          channelKey: channelKey,
          orderAmount: 11.67,
          customerName: 'Max Mustermann',
          addressLines: addressLines,
          displayMethod: 'card',
          branchName: branchName,
        );

    test('a delivery order shows its stored address lines', () {
      expect(
        build(addressLines: ['Potsdamer Str. 33', '14974 Ludwigsfelde'])
            .subtitleLines,
        ['Potsdamer Str. 33', '14974 Ludwigsfelde'],
      );
    });

    test('an order with no address falls back to channel and branch, not a '
        'fabricated table label', () {
      expect(build().subtitleLines, ['Point of sale', 'Acafe/Amsterdam']);
    });

    test('the block collapses rather than padding out to three lines', () {
      expect(build(channelKey: '', branchName: null).subtitleLines, isEmpty);
      expect(build(channelKey: '').subtitleLines, ['Acafe/Amsterdam']);
    });

    test('withStatus re-sections the card without mutating the original', () {
      final PosOrderCard original = build();
      final PosOrderCard moved = original.withStatus('preparing');

      expect(original.section, PosOrderSection.newOrders);
      expect(moved.section, PosOrderSection.inProgress);
      expect(moved.id, original.id);
      expect(moved.customerName, original.customerName);
    });

    test('parses a real feed row', () {
      final PosOrderCard card = PosOrderCard.fromJson(<String, dynamic>{
        'id': 1000153,
        'created_at': '2026-09-04T17:45:37.000000Z',
        'order_status': 'new',
        'order_type': 'pos',
        'channel_key': 'counter_pos',
        'order_amount': 80.6,
        'customer_name': 'Walk-in',
        'address_lines': <String>[],
        'display_method': 'card',
        'branch_name': 'Acafe/Amsterdam',
      });

      expect(card.id, 1000153);
      expect(card.orderAmount, 80.6);
      expect(card.section, PosOrderSection.newOrders);
      expect(card.createdAt, isNotNull);
    });
  });
}
