/// Pure cash-change math for the POS Cash pane. No Flutter imports, integer
/// cents only — every amount in and out is minor units, so the arithmetic is
/// exact (`5000 - 3050 = 1950`, never `19.4999…`).
///
/// It knows nothing about widgets, currency symbols or formatting; the pane
/// feeds it cents and renders the result through the app's existing formatter.
library;

/// Which side of the total the tender sits on.
enum CashStatusKind {
  /// Tendered < Due. [amount] is what is still owed.
  remaining,

  /// Tendered == Due. [amount] is 0.
  exact,

  /// Tendered > Due. [amount] is the change to give back.
  change,
}

class CashStatus {
  final CashStatusKind kind;

  /// Minor units: the shortfall (remaining), 0 (exact) or the change.
  final int amount;

  const CashStatus(this.kind, this.amount);

  @override
  bool operator ==(Object other) =>
      other is CashStatus && other.kind == kind && other.amount == amount;

  @override
  int get hashCode => Object.hash(kind, amount);

  @override
  String toString() => 'CashStatus($kind, $amount)';
}

/// One row of a change breakdown: a denomination [value] handed back [count]
/// times, e.g. `(200, 2)` = two €2 coins.
class CashBreakdownPart {
  final int value;
  final int count;

  const CashBreakdownPart(this.value, this.count);

  @override
  bool operator ==(Object other) =>
      other is CashBreakdownPart && other.value == value && other.count == count;

  @override
  int get hashCode => Object.hash(value, count);

  @override
  String toString() => 'CashBreakdownPart($value×$count)';
}

/// Stateless calculator. All methods are pure functions of their arguments.
class CashChangeCalculator {
  const CashChangeCalculator();

  /// The live three-state status for [tenderedCents] against [dueCents].
  /// An empty tender (0) against a positive due reads as `remaining = due`.
  CashStatus status(int dueCents, int tenderedCents) {
    final int diff = tenderedCents - dueCents;
    if (diff < 0) return CashStatus(CashStatusKind.remaining, -diff);
    if (diff == 0) return const CashStatus(CashStatusKind.exact, 0);
    return CashStatus(CashStatusKind.change, diff);
  }

  /// Up to four quick-cash suggestions, each the smallest multiple of a unit
  /// that is **strictly greater** than [dueCents].
  ///
  /// For each unit `d` in [units] the candidate is `(due ~/ d + 1) * d`, so an
  /// exact multiple jumps to the next note rather than offering the due itself
  /// (€1.00 → €2, not €1). De-duplicate, sort ascending, take the first four;
  /// may return fewer (e.g. €87.20 → €88, €90, €100).
  List<int> suggestions(int dueCents, List<int> units) {
    if (dueCents <= 0) return const [];
    final Set<int> seen = <int>{};
    for (final int d in units) {
      if (d <= 0) continue;
      seen.add((dueCents ~/ d + 1) * d);
    }
    final List<int> out = seen.toList()..sort();
    return out.length > 4 ? out.sublist(0, 4) : out;
  }

  /// Greedy change breakdown for [changeCents] over [denominations] (which
  /// must be largest first), as ordered (value, count) rows. Non-positive
  /// change returns an empty list.
  List<CashBreakdownPart> breakdown(int changeCents, List<int> denominations) {
    if (changeCents <= 0) return const [];
    int remaining = changeCents;
    final List<CashBreakdownPart> parts = [];
    for (final int d in denominations) {
      if (d <= 0 || remaining < d) continue;
      final int count = remaining ~/ d;
      remaining -= count * d;
      parts.add(CashBreakdownPart(d, count));
      if (remaining == 0) break;
    }
    return parts;
  }
}
