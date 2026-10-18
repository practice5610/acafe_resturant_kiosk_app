import 'package:flutter/foundation.dart';

/// A quick-denomination button on the cash panel.
///
/// [exact] is the odd one out: it does not name a note, it means "tender the
/// total to the cent", which is what an operator picks when the customer pays
/// by the exact amount and there is no change to count back.
@immutable
class PosCashDenomination {
  /// Minor units, or null for [exact].
  final int? cents;
  final bool exact;

  const PosCashDenomination.note(int this.cents) : exact = false;
  const PosCashDenomination.exact()
      : cents = null,
        exact = true;

  /// Figma's row: €5 / €10 / €20 / €50 / Exact.
  static const List<PosCashDenomination> defaults = [
    PosCashDenomination.note(500),
    PosCashDenomination.note(1000),
    PosCashDenomination.note(2000),
    PosCashDenomination.note(5000),
    PosCashDenomination.exact(),
  ];

  @override
  bool operator ==(Object other) =>
      other is PosCashDenomination &&
      other.cents == cents &&
      other.exact == exact;

  @override
  int get hashCode => Object.hash(cents, exact);
}
