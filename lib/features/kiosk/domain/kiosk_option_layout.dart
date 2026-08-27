import 'dart:math' as math;

/// How option cards (dietary, size, add-ons) divide the width they are given.
///
/// Extracted from the customize screen so the rule is unit-testable.

/// Never fewer than this many cards across on a kiosk-sized panel. Narrow
/// windows drop toward 2 so a 400px card does not render a 7px label.
const int kOptionMinColumns = 4;

/// Upper bound so an ultra-wide panel cannot produce a grid of tiny cards.
const int kOptionMaxColumns = 8;

/// Floor on column count for a panel of [width] logical pixels.
int kioskOptionMinColumnsFor(double width) {
  if (width < 420) return 2;
  if (width < 650) return 3;
  return kOptionMinColumns;
}

/// Cards narrower than this (logical px) drop a column on a small panel.
const double kOptionMinReadableCard = 110;

/// How many option cards fit across a panel [width] px wide.
///
/// [cardWidth] is the design's card at the current scale, so a large screen
/// gets the density the artboard intends. The result is then floored at
/// [kioskOptionMinColumnsFor] — four across on a kiosk panel, fewer only
/// when the panel is too narrow for a readable 4-up.
int kioskOptionColumns({
  required double width,
  required double cardWidth,
  required double gap,
}) {
  if (width <= 0 || cardWidth <= 0) return kOptionMinColumns;
  final int minCols = kioskOptionMinColumnsFor(width);
  final int byArtboard = ((width + gap) / (cardWidth + gap)).round();
  int columns = math.max(minCols, byArtboard).clamp(minCols, kOptionMaxColumns);
  final double implied =
      columns <= 0 ? width : (width - gap * (columns - 1)) / columns;
  if (implied < kOptionMinReadableCard &&
      columns > minCols &&
      minCols < kOptionMinColumns) {
    columns = math.max(
      minCols,
      ((width + gap) / (kOptionMinReadableCard + gap)).floor(),
    );
  }
  return columns.clamp(minCols, kOptionMaxColumns);
}

/// Width for one option card inside a panel [width] px wide.
///
/// Cards divide the row exactly, so the last card always ends flush with the
/// panel edge — no ragged gap, no half card clipped off.
double kioskOptionCardWidth({
  required double width,
  required double cardWidth,
  required double gap,
}) {
  final int columns =
      kioskOptionColumns(width: width, cardWidth: cardWidth, gap: gap);
  final double gaps = gap * (columns - 1);
  return math.max(1, (width - gaps) / columns);
}
