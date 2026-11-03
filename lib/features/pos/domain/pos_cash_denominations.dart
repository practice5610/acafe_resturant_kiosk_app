/// Central cash-denomination config, keyed by currency.
///
/// There is no ISO currency code in `ConfigModel` — only `currency_symbol` —
/// so the resolver keys off the symbol and falls back to EUR for anything it
/// does not recognise. One place owns these values; widgets never hardcode a
/// note or coin.
///
/// Two sets per currency, both in **minor units (cents)**:
/// - [breakdown]: every note and coin, largest first, used to count change
///   back to the customer.
/// - [suggestionUnits]: the round values the quick-cash chips are built from
///   (`ceil(due / unit) * unit`). Coins below €1 are deliberately excluded —
///   a chip for "pay €0.50 over" is noise at a till.
class PosCashDenominations {
  /// Notes and coins, largest first, in minor units.
  final List<int> breakdown;

  /// Units the quick-cash suggestions round up to, in minor units.
  final List<int> suggestionUnits;

  const PosCashDenominations({
    required this.breakdown,
    required this.suggestionUnits,
  });

  /// Notes and coins €100 … €0.01, largest first (minor units). Exposed as a
  /// const list so widgets can use it as a default parameter value.
  static const List<int> eurBreakdown = [
    10000, 5000, 2000, 1000, 500, 200, 100, // notes + €2/€1 coins
    50, 20, 10, 5, 2, 1, //                     €0.50 … €0.01 coins
  ];

  /// Round values the quick-cash suggestions are built from (minor units).
  static const List<int> eurSuggestionUnits = [
    100, 500, 1000, 2000, 5000, 10000,
  ];

  /// €100 … €0.01, and €1 … €100 for suggestions.
  static const PosCashDenominations eur = PosCashDenominations(
    breakdown: eurBreakdown,
    suggestionUnits: eurSuggestionUnits,
  );

  /// Picks the set for a currency symbol. EUR is the fallback for any symbol
  /// the app has no table for, so a till never loses its change counter.
  static PosCashDenominations forSymbol(String? symbol) {
    switch ((symbol ?? '').trim()) {
      case '€':
        return eur;
      default:
        return eur;
    }
  }
}
