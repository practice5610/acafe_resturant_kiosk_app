import 'package:acafe_customer/features/pos/domain/pos_order_grouping.dart';
import 'package:flutter/material.dart';

/// Urgency of an order's age.
enum PosOrderUrgency { normal, warning, urgent, done }

/// Elapsed time since an order was received, and how late that makes it look.
///
/// **These thresholds are not new.** They are the Kitchen Display's live
/// numbers, lifted from `order_card_helpers.dart` in `acafe_resturant_kitchen_app`
/// so the POS board and the KDS judge the same order the same way — a ticket
/// that reads "late" on the kitchen screen has to read late at the counter too,
/// or the two screens send staff conflicting signals about the same order.
///
/// Deliberately *elapsed*, not a countdown. Figma draws descending values,
/// which implies a per-order deadline; there is no such thing in the data.
/// `orders.preparation_time` is written as 0 by every ordering app and
/// `branches.preparation_time` is one global 30-minute number that branch staff
/// can no longer edit — counting down against it would be inventing a deadline
/// and, worse, presenting it to staff as if it were real. So the clock starts
/// when the order arrives and counts up.
class PosOrderTimer {
  PosOrderTimer._();

  /// Kitchen: `kOrderWarningMinutes = 5`.
  static const int warningMinutes = 5;

  /// Kitchen: `isOrderUrgent()` — 15 minutes.
  static const int urgentMinutes = 15;

  /// Kitchen `kdsAgeWarningColor`.
  static const Color warningColor = Color(0xFFEF6C00);

  /// Kitchen's urgent chip colour.
  static const Color urgentColor = Color(0xFFB71C1C);

  /// A finished order's timer has stopped; it reads as settled, not as fast.
  static const Color doneColor = Color(0xFF3F8A4F);

  static const Color normalColor = Color(0xFF3F8A4F);

  /// Urgency only escalates while the order is still unfinished. A completed
  /// order that happened to take 40 minutes is not an alarm — it is history.
  ///
  /// "Unfinished" is decided by the order's real status, not by the section it
  /// is drawn in. `item_to_collect` is grouped under FINISHED but is not a
  /// terminal status — an order sitting uncollected on the pass for twenty
  /// minutes is exactly the case staff need flagged, and keying this on the
  /// section would have quietly shown it as settled. The Kitchen Display
  /// likewise counts `item_to_collect` among its active tickets.
  static PosOrderUrgency urgencyOf({
    required String orderStatus,
    required DateTime? createdAt,
    DateTime? now,
  }) {
    if (PosOrderGrouping.nextStatusFor(orderStatus) == null) {
      return PosOrderUrgency.done;
    }
    if (createdAt == null) {
      return PosOrderUrgency.normal;
    }

    final int minutes =
        (now ?? DateTime.now()).difference(createdAt).inMinutes;

    if (minutes >= urgentMinutes) return PosOrderUrgency.urgent;
    if (minutes >= warningMinutes) return PosOrderUrgency.warning;
    return PosOrderUrgency.normal;
  }

  static Color colorFor(PosOrderUrgency urgency) {
    switch (urgency) {
      case PosOrderUrgency.urgent:
        return urgentColor;
      case PosOrderUrgency.warning:
        return warningColor;
      case PosOrderUrgency.done:
        return doneColor;
      case PosOrderUrgency.normal:
        return normalColor;
    }
  }

  /// `m:ss` under an hour, `h:mm:ss` beyond it — matching the `5:23` shape
  /// Figma draws, while staying readable for an order that has been sitting all
  /// morning.
  static String elapsedLabel(DateTime? createdAt, {DateTime? now}) {
    if (createdAt == null) return '';

    Duration diff = (now ?? DateTime.now()).difference(createdAt);
    if (diff.isNegative) {
      // A terminal clock running ahead of the server's must not render "-1:-3".
      diff = Duration.zero;
    }

    final int hours = diff.inHours;
    final int minutes = diff.inMinutes.remainder(60);
    final int seconds = diff.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${_two(minutes)}:${_two(seconds)}';
    }
    return '${diff.inMinutes}:${_two(seconds)}';
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}
