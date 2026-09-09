/// The three sections of the Orders board, plus "not on the board at all".
enum PosOrderSection { newOrders, inProgress, finished, excluded }

/// Maps a real `orders.order_status` onto a board section.
///
/// Mirrors the server-side constants in `KioskManagerController` on purpose:
/// the endpoint already excludes off-board statuses, but the board also
/// re-groups locally after an optimistic status change, and the two answers
/// have to agree or a card would jump to the wrong section for the duration of
/// the round trip.
class PosOrderGrouping {
  PosOrderGrouping._();

  /// `pending` is the legacy alias for `new` and is still readable on old rows.
  static const Set<String> newStatuses = {'new', 'pending'};

  /// Being worked. `on_hold` belongs here: a paused order is still active, it
  /// simply is not progressing.
  static const Set<String> inProgressStatuses = {
    'preparing',
    'confirmed',
    'processing',
    'cooking',
    'on_hold',
  };

  /// Kitchen work is done. `item_to_collect` sits here rather than in progress
  /// because from the counter's side a ready order is finished and waiting to
  /// be handed over. `delivered` is a legacy value that is still written on
  /// live rows — omitting it would silently drop those orders off the board.
  static const Set<String> finishedStatuses = {
    'item_to_collect',
    'completed',
    'delivered',
  };

  /// `canceled` has no section. It is not folded into FINISHED: a canceled
  /// order is not a fulfilled one, and showing it as such would misreport what
  /// happened to it.
  static const Set<String> excludedStatuses = {'canceled', 'returned', 'failed'};

  static PosOrderSection sectionOf(String status) {
    final String s = status.trim().toLowerCase();
    if (newStatuses.contains(s)) return PosOrderSection.newOrders;
    if (inProgressStatuses.contains(s)) return PosOrderSection.inProgress;
    if (finishedStatuses.contains(s)) return PosOrderSection.finished;
    return PosOrderSection.excluded;
  }

  /// The status this order's primary action moves it to — the kitchen ladder,
  /// keyed on the order's **real status**, not on the section it is drawn in.
  ///
  /// This is the same switch the Kitchen Display runs in `_AdvanceButton`
  /// (`order_card_widget.dart`), and it is the only place the ladder is
  /// defined: `KitchenController::changeStatus` has no transition matrix at
  /// all — it writes whatever target it is handed, its only guards being the
  /// branch check and a station-scoped restriction. So the ladder is a client
  /// contract shared between the two apps, and POS has to run the same one.
  ///
  ///   new             -> preparing
  ///   preparing       -> item_to_collect
  ///   item_to_collect -> completed
  ///   on_hold         -> preparing      (resume; the server re-derives the
  ///                                      true status from the item aggregate)
  ///   completed / delivered / canceled  -> nothing
  ///
  /// Keying on status rather than section is what keeps grouping and gating
  /// consistent: `item_to_collect` is grouped under FINISHED, but it is not a
  /// terminal status, so its card still carries the action that finishes it.
  /// Nothing is ever grouped into a section whose action cannot fire, because
  /// the action is not a property of the section.
  static String? nextStatusFor(String orderStatus) {
    final String s = orderStatus.trim().toLowerCase();

    if (newStatuses.contains(s)) return 'preparing';
    if (s == 'on_hold') return 'preparing';
    if (inProgressStatuses.contains(s)) return 'item_to_collect';
    if (s == 'item_to_collect') return 'completed';

    // completed / delivered / canceled are the end of the line.
    return null;
  }

  /// Label for that action.
  ///
  /// Deliberately describes the transition it actually performs. Figma draws
  /// "Mark as complete" on every IN PROGRESS card, but a `preparing` order's
  /// next rung is `item_to_collect`, not `completed` — labelling that button
  /// "complete" would tell staff the order is finished when the customer has
  /// not been handed anything, and would skip the "ready to collect" push the
  /// customer gets at that rung.
  ///
  /// `new -> preparing` reads "Accept order" — Figma **1641:4341**'s own CTA
  /// for a NEW order, not the "Start preparing" this used to say.
  static String? actionLabelFor(String orderStatus) {
    final String? next = nextStatusFor(orderStatus);
    if (next == null) return null;

    final String s = orderStatus.trim().toLowerCase();
    if (s == 'on_hold') return 'Resume';
    if (newStatuses.contains(s)) return 'Accept order';
    if (next == 'item_to_collect') return 'Mark as ready';
    return 'Mark as complete';
  }

  static String labelFor(PosOrderSection section) {
    switch (section) {
      case PosOrderSection.newOrders:
        return 'NEW';
      case PosOrderSection.inProgress:
        return 'IN PROGRESS';
      case PosOrderSection.finished:
        return 'FINISHED';
      case PosOrderSection.excluded:
        return '';
    }
  }

  /// Wire value for the endpoint's `section` parameter.
  static String? queryValueFor(PosOrderSection section) {
    switch (section) {
      case PosOrderSection.newOrders:
        return 'new';
      case PosOrderSection.inProgress:
        return 'in_progress';
      case PosOrderSection.finished:
        return 'finished';
      case PosOrderSection.excluded:
        return null;
    }
  }
}
