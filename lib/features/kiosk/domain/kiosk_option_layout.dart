import 'dart:math' as math;

/// How option cards (dietary, size, add-ons) divide the width they are given.
///
/// Extracted from the customize screen so the rule is unit-testable.

/// Never fewer than four cards across. The design never shows fewer, and a
/// smaller device is no reason to drop below it — the cards get narrower, the
/// row does not get shorter.
const int kOptionMinColumns = 4;

/// Upper bound so an ultra-wide panel cannot produce a grid of tiny cards.
const int kOptionMaxColumns = 8;

/// How many option cards fit across a panel [width] px wide.
///
/// [cardWidth] is the design's card at the current scale, so a large screen
/// gets the density the artboard intends. The result is then floored at
/// [kOptionMinColumns] — that floor is what keeps four across on a narrow
/// window instead of two.
int kioskOptionColumns({
  required double width,
  required double cardWidth,
  required double gap,
}) {
  if (width <= 0 || cardWidth <= 0) return kOptionMinColumns;
  final int byArtboard = ((width + gap) / (cardWidth + gap)).floor();
  return math
      .max(kOptionMinColumns, byArtboard)
      .clamp(kOptionMinColumns, kOptionMaxColumns);
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
