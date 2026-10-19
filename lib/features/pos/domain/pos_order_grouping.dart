/// The sections of the Orders board — the Kitchen Display's own tabs (New /
/// Preparing / Ready to collect / On hold / Completed), so the counter and the
/// kitchen file an order under the same word — plus "not on the board at all".
enum PosOrderSection {
  newOrders,
  preparing,
  readyToCollect,
  onHold,
  completed,
  excluded,
}

/// Maps a real `orders.order_status` onto a board section.
///
/// Mirrors the server-side constants in `KioskManagerController` on purpose:
/// the endpoint already excludes off-board statuses, but the board also
/// re-groups locally after an optimistic status change, and the two answers
/// have to agree or a card would jump to the wrong section for the duration of
/// the round trip.
///
/// Each Kitchen Display tab is one exact status; the sets below add only the
/// legacy values that tab would otherwise drop on the floor.
class PosOrderGrouping {
  PosOrderGrouping._();

  /// Board order, top to bottom — and the filter pills, left to right.
  static const List<PosOrderSection> boardSections = [
    PosOrderSection.newOrders,
    PosOrderSection.preparing,
    PosOrderSection.readyToCollect,
    PosOrderSection.onHold,
    PosOrderSection.completed,
  ];

  /// `pending` is the legacy alias for `new` and is still readable on old rows.
  static const Set<String> newStatuses = {'new', 'pending'};

  /// Being worked. The Kitchen Display only writes `preparing`; the others are
  /// legacy values still readable on old rows.
  static const Set<String> preparingStatuses = {
    'preparing',
    'confirmed',
    'processing',
    'cooking',
  };

  /// The kitchen is done; the handover is not. Not terminal — its card still
  /// carries "Mark as complete".
  static const Set<String> readyToCollectStatuses = {'item_to_collect'};

  /// Paused but still active.
  static const Set<String> onHoldStatuses = {'on_hold'};

  /// `delivered` is a legacy value that is still written on live rows —
  /// omitting it would silently drop those orders off the board.
  static const Set<String> completedStatuses = {'completed', 'delivered'};

  /// `canceled` has no section. It is not folded into COMPLETED: a canceled
  /// order is not a fulfilled one, and showing it as such would misreport what
  /// happened to it.
  static const Set<String> excludedStatuses = {'canceled', 'returned', 'failed'};

  /// Figma draws three card variants (NEW / IN PROGRESS / FINISHED); the five
  /// kitchen sections reuse them. PREPARING and ON HOLD orders are still in the
  /// kitchen, so they get the IN PROGRESS card: station pills or the "n/m
  /// ready" line, footer pinned to the bottom edge.
  static bool usesInProgressCard(PosOrderSection section) =>
      section == PosOrderSection.preparing || section == PosOrderSection.onHold;

  /// READY TO COLLECT and COMPLETED orders are out of the kitchen, so they get
  /// Figma's FINISHED card: ring-less source badge, thinner glyphs.
  static bool usesFinishedCard(PosOrderSection section) =>
      section == PosOrderSection.readyToCollect ||
      section == PosOrderSection.completed;

  static PosOrderSection sectionOf(String status) {
    final String s = status.trim().toLowerCase();
    if (newStatuses.contains(s)) return PosOrderSection.newOrders;
    if (preparingStatuses.contains(s)) return PosOrderSection.preparing;
    if (readyToCollectStatuses.contains(s)) {
      return PosOrderSection.readyToCollect;
    }
    if (onHoldStatuses.contains(s)) return PosOrderSection.onHold;
    if (completedStatuses.contains(s)) return PosOrderSection.completed;
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
  /// consistent: `item_to_collect` is drawn on a finished card, but it is not a
  /// terminal status, so its card still carries the action that finishes it.
  /// Nothing is ever grouped into a section whose action cannot fire, because
  /// the action is not a property of the section.
  static String? nextStatusFor(String orderStatus) {
    final String s = orderStatus.trim().toLowerCase();

    if (newStatuses.contains(s)) return 'preparing';
    if (s == 'on_hold') return 'preparing';
    if (preparingStatuses.contains(s)) return 'item_to_collect';
    if (s == 'item_to_collect') return 'completed';

    // completed / delivered / canceled are the end of the line.
    return null;
  }

  /// Label for that action.
  ///
  /// Deliberately describes the transition it actually performs. Figma draws
  /// "Mark as complete" on every in-progress card, but a `preparing` order's
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

  /// Section header and modal badge text: the Kitchen Display's tab names, in
  /// the capitals Figma sets every section label in.
  static String labelFor(PosOrderSection section) {
    switch (section) {
      case PosOrderSection.newOrders:
        return 'NEW';
      case PosOrderSection.preparing:
        return 'PREPARING';
      case PosOrderSection.readyToCollect:
        return 'READY TO COLLECT';
      case PosOrderSection.onHold:
        return 'ON HOLD';
      case PosOrderSection.completed:
        return 'COMPLETED';
      case PosOrderSection.excluded:
        return '';
    }
  }

  /// The coarser `section` an older backend understands (new / in_progress /
  /// finished): each kitchen section sits wholly inside one, so the board asks
  /// for that and keeps only its own cards. Used until the server shows it
  /// knows the kitchen sections, so a terminal updated before its backend
  /// still filters instead of failing with a 422.
  static String? legacyQueryValueFor(PosOrderSection section) {
    switch (section) {
      case PosOrderSection.newOrders:
        return 'new';
      case PosOrderSection.preparing:
      case PosOrderSection.onHold:
        return 'in_progress';
      case PosOrderSection.readyToCollect:
      case PosOrderSection.completed:
        return 'finished';
      case PosOrderSection.excluded:
        return null;
    }
  }

  /// Wire value for the endpoint's `section` parameter — also the key of that
  /// section's total in its `counts`.
  static String? queryValueFor(PosOrderSection section) {
    switch (section) {
      case PosOrderSection.newOrders:
        return 'new';
      case PosOrderSection.preparing:
        return 'preparing';
      case PosOrderSection.readyToCollect:
        return 'ready_to_collect';
      case PosOrderSection.onHold:
        return 'on_hold';
      case PosOrderSection.completed:
        return 'completed';
      case PosOrderSection.excluded:
        return null;
    }
  }
}
