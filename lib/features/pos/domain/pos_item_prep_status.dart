import 'package:acafe_customer/features/pos/domain/pos_order_detail_spec.dart';
import 'package:flutter/material.dart';

/// The POS mirror of the kitchen's per-item prep ladder.
///
/// Mirrors `order_card_helpers.dart:18-53` in the kitchen app
/// (`acafe_resturant_kitchen_app`) — the values, the labels and the allowed
/// moves are the same contract, so an item reads the same on both screens:
///
///     pending → preparing → ready          (Start, then Done)
///     ready   → preparing                  (Undo — the only backward move)
///
/// Two deliberate departures, both signed off:
///
///  * **Colours are POS, not kitchen.** The kitchen paints `#1565C0` /
///    `#2E7D32`; the POS uses its own badge palette so a status chip sits in
///    the same visual system as every other badge on the board. Only the hues
///    differ — the meaning, the wording and the ladder do not.
///  * **The server is the source of truth for transitions.** This enum decides
///    which button to *draw*; `KitchenItemStatusService` decides what is
///    actually allowed, and rejects a stale tap with a 409 that carries the
///    item's real state. Never treat [next] as permission.
///
/// Unknown and missing wire values fall back to [PrepStatus.pending] rather
/// than throwing: an item the server has not classified is one nobody has
/// started, and a new status value shipped server-first must never crash a
/// terminal that has not been updated yet.
enum PrepStatus {
  pending,
  preparing,
  ready;

  static PrepStatus fromWire(Object? value) {
    switch ('${value ?? ''}'.trim().toLowerCase()) {
      case 'preparing':
        return PrepStatus.preparing;
      case 'ready':
        return PrepStatus.ready;
      default:
        return PrepStatus.pending;
    }
  }

  /// The value the API speaks.
  String get wire => name;

  /// Kitchen's wording, capitalised for the POS chip.
  String get label {
    switch (this) {
      case PrepStatus.pending:
        return 'Pending';
      case PrepStatus.preparing:
        return 'Preparing';
      case PrepStatus.ready:
        return 'Ready';
    }
  }

  /// POS palette (see the class doc for why these are not kitchen's hexes).
  Color get color {
    switch (this) {
      case PrepStatus.pending:
        return PosOrderDetailSpec.inkAlpha(0.45);
      case PrepStatus.preparing:
        return PosOrderDetailSpec.badgeInProgress;
      case PrepStatus.ready:
        return PosOrderDetailSpec.badgeFinished;
    }
  }

  /// A finished item is struck through and its row goes quiet.
  bool get isDone => this == PrepStatus.ready;

  /// The one action this item offers next, or null if there is nothing to do.
  /// Never null in practice — `ready` still offers Undo — but kept nullable so
  /// a future terminal state does not need a sentinel.
  PrepAction? get next {
    switch (this) {
      case PrepStatus.pending:
        return const PrepAction(
          label: 'Start',
          icon: Icons.play_arrow_rounded,
          target: PrepStatus.preparing,
          subtle: false,
        );
      case PrepStatus.preparing:
        return const PrepAction(
          label: 'Done',
          icon: Icons.check_rounded,
          target: PrepStatus.ready,
          subtle: false,
        );
      case PrepStatus.ready:
        return const PrepAction(
          label: 'Undo',
          icon: Icons.undo_rounded,
          target: PrepStatus.preparing,
          subtle: true,
        );
    }
  }
}

/// One offered move on an item row.
class PrepAction {
  final String label;
  final IconData icon;
  final PrepStatus target;

  /// Undo is drawn as a quiet text button rather than an outlined one — it is
  /// a correction, not the expected next step, and should not compete with the
  /// forward action on neighbouring rows.
  final bool subtle;

  const PrepAction({
    required this.label,
    required this.icon,
    required this.target,
    required this.subtle,
  });
}

/// The order-level view of a set of items — the "n of m ready" the kitchen
/// shows on its ticket cards (`order_ticket_card.dart:836`) and the bulk action
/// the whole order offers.
///
/// The counts come from the server (`items_ready` / `items_total`), which is
/// also what drives `KitchenOrderProgressService`. This class never derives the
/// *order status* — that is the server's job and copying it here is exactly the
/// duplication the parity work set out to avoid.
class PrepProgress {
  final int ready;
  final int total;

  const PrepProgress({required this.ready, required this.total});

  factory PrepProgress.fromStatuses(Iterable<PrepStatus> statuses) {
    final List<PrepStatus> all = statuses.toList(growable: false);
    return PrepProgress(
      ready: all.where((s) => s == PrepStatus.ready).length,
      total: all.length,
    );
  }

  bool get isEmpty => total == 0;
  bool get allReady => total > 0 && ready == total;

  /// 0..1, and 0 rather than NaN for an order with no lines.
  double get fraction => total == 0 ? 0 : ready / total;

  /// "2 of 3 ready".
  String get label => '$ready of $total ready';
}

/// The bulk move an order offers, given every item's state.
///
/// This is the POS replacement for driving the order forward by writing
/// `order_status` directly: "Accept order" and "Mark as ready" now move the
/// *items*, and the order status follows from the server's aggregate exactly
/// as it does when the kitchen does the same thing.
///
///   any item pending            → Start all items (bulk → preparing)
///   none pending, any preparing → Mark all ready  (bulk → ready)
///   all ready                   → nothing (the order-level CTA takes over)
class PosBulkItemAction {
  final String label;
  final PrepStatus target;

  const PosBulkItemAction({required this.label, required this.target});

  static PosBulkItemAction? forStatuses(Iterable<PrepStatus> statuses) {
    final List<PrepStatus> all = statuses.toList(growable: false);
    if (all.isEmpty) return null;

    if (all.any((s) => s == PrepStatus.pending)) {
      return const PosBulkItemAction(
        label: 'Start all items',
        target: PrepStatus.preparing,
      );
    }
    if (all.any((s) => s == PrepStatus.preparing)) {
      return const PosBulkItemAction(
        label: 'Mark all ready',
        target: PrepStatus.ready,
      );
    }
    return null;
  }
}
