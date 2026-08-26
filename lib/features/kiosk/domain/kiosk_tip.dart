/// Tip percentages offered on the kiosk Pay sheet (Figma tip modal).
///
/// `0` is the empty / no-tip tile. Nothing is preselected — the customer has
/// to tap a tile or "No, thank you!" before a tip is applied.
const List<int> kKioskTipPercents = [0, 5, 10, 15];

/// Tip in currency for [payable] at [percent]. Always 0 when the customer
/// has not chosen a positive percentage. Rounded to 2 dp so the amount on
/// the tile, the summary, and the order payload stay identical.
double kioskTipAmount(double payable, int percent) {
  if (percent <= 0 || payable <= 0) return 0;
  return double.parse((payable * percent / 100).toStringAsFixed(2));
}

/// Grand total charged after an optional tip is added.
double kioskTotalWithTip(double payable, int percent) =>
    double.parse(
        (payable + kioskTipAmount(payable, percent)).toStringAsFixed(2));
