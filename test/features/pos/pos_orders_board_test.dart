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

    test('each Kitchen Display tab status lands in its own section', () {
      // The KDS tabs are exact matches on one status each
      // (order_status_tab_widget.dart); the board files them the same way.
      expect(
        PosOrderGrouping.sectionOf('preparing'),
        PosOrderSection.preparing,
      );
      expect(
        PosOrderGrouping.sectionOf('item_to_collect'),
        PosOrderSection.readyToCollect,
      );
      // A paused order is its own section now, not hidden inside preparing.
      expect(PosOrderGrouping.sectionOf('on_hold'), PosOrderSection.onHold);
      expect(
        PosOrderGrouping.sectionOf('completed'),
        PosOrderSection.completed,
      );
    });

    test('legacy statuses keep a home', () {
      for (final String s in const ['confirmed', 'processing', 'cooking']) {
        expect(PosOrderGrouping.sectionOf(s), PosOrderSection.preparing,
            reason: s);
      }
      // `delivered` is a live legacy value on real rows, not just an alias
      // constant. Dropping it would silently hide those orders.
      expect(
        PosOrderGrouping.sectionOf('delivered'),
        PosOrderSection.completed,
      );
    });

    test('sections, pills and wire values line up with the backend', () {
      expect(PosOrderGrouping.boardSections, const [
        PosOrderSection.newOrders,
        PosOrderSection.preparing,
        PosOrderSection.readyToCollect,
        PosOrderSection.onHold,
        PosOrderSection.completed,
      ]);
      expect(
        PosOrderGrouping.boardSections.map(PosOrderGrouping.labelFor),
        ['NEW', 'PREPARING', 'READY TO COLLECT', 'ON HOLD', 'COMPLETED'],
      );
      // KioskManagerController::orders() `section` values and `counts` keys.
      expect(
        PosOrderGrouping.boardSections.map(PosOrderGrouping.queryValueFor),
        ['new', 'preparing', 'ready_to_collect', 'on_hold', 'completed'],
      );
      expect(PosOrderGrouping.queryValueFor(PosOrderSection.excluded), isNull);
    });

    test('Figma card variants: in-kitchen vs out-of-kitchen', () {
      expect(
        PosOrderGrouping.boardSections
            .where(PosOrderGrouping.usesInProgressCard),
        [PosOrderSection.preparing, PosOrderSection.onHold],
      );
      expect(
        PosOrderGrouping.boardSections.where(PosOrderGrouping.usesFinishedCard),
        [PosOrderSection.readyToCollect, PosOrderSection.completed],
      );
    });

    test('canceled is excluded from the board entirely', () {
      expect(PosOrderGrouping.sectionOf('canceled'), PosOrderSection.excluded);
      expect(
        PosOrderGrouping.sectionOf('canceled'),
        isNot(PosOrderSection.completed),
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
        ...PosOrderGrouping.preparingStatuses,
        ...PosOrderGrouping.readyToCollectStatuses,
        ...PosOrderGrouping.onHoldStatuses,
        ...PosOrderGrouping.completedStatuses,
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

    test('item_to_collect is drawn as finished yet still advanceable', () {
      // The exact case the section-keyed version got wrong: drawn on Figma's
      // FINISHED card, but not terminal, so its card still finishes it.
      expect(
        PosOrderGrouping.usesFinishedCard(
          PosOrderGrouping.sectionOf('item_to_collect'),
        ),
        isTrue,
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

    test(
        'an order with no address falls back to channel and branch, not a '
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
      expect(moved.section, PosOrderSection.preparing);
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
