import 'package:acafe_customer/features/kiosk/domain/kiosk_option_layout.dart';
import 'package:flutter_test/flutter_test.dart';

/// The rule for option cards (dietary, size, add-ons):
///   * never fewer than four across, on any device;
///   * the artboard sets the density above that, so a big kiosk gets big cards;
///   * the row always divides exactly, so nothing is clipped at the right edge.
void main() {
  const double artboardCard = 360; // _kAddOnCardWidth
  const double artboard = 2572;

  /// Panel inner width for a screen width, matching the screen's own 86px
  /// gutter + 38px panel padding at the kiosk scale.
  ({double inner, double gap, double card}) layout(double screenWidth) {
    final double s = (screenWidth / artboard).clamp(0.24, 1.0);
    return (
      inner: screenWidth - 2 * 86 * s - 2 * 32 * s,
      // Mirrors _optionGap: floored so cards stay visibly separate on a small
      // screen, where the artboard gutter collapses to ~5px.
      gap: (16 * s).clamp(6.0, 16.0),
      card: artboardCard * s,
    );
  }

  int columnsAt(double w) {
    final l = layout(w);
    return kioskOptionColumns(width: l.inner, cardWidth: l.card, gap: l.gap);
  }

  double cardAt(double w) {
    final l = layout(w);
    return kioskOptionCardWidth(width: l.inner, cardWidth: l.card, gap: l.gap);
  }

  group('at least four across, always', () {
    test('every screen from a tiny window to a 4K kiosk shows >= 4', () {
      for (double w = 320; w <= 3000; w += 10) {
        expect(columnsAt(w), greaterThanOrEqualTo(kOptionMinColumns),
            reason: 'only ${columnsAt(w)} cards across at ${w}px');
      }
    });

    test('a narrow window keeps four rather than dropping to two', () {
      expect(columnsAt(400), greaterThanOrEqualTo(4));
      expect(columnsAt(560), greaterThanOrEqualTo(4));
      expect(columnsAt(660), greaterThanOrEqualTo(4));
    });
  });

  group('artboard density above the minimum', () {
    test('the 4K kiosk gets the design density, not a tiny-card grid', () {
      expect(columnsAt(2572), 6);
      expect(cardAt(2572), greaterThan(330),
          reason: 'a 2324px panel should render design-sized cards');
    });

    test('cards grow with the screen', () {
      expect(cardAt(2572), greaterThan(cardAt(1080)));
      expect(cardAt(1080), greaterThan(cardAt(660)));
    });

    test('columns never decrease as the screen grows', () {
      int previous = 0;
      for (double w = 320; w <= 3000; w += 20) {
        final int c = columnsAt(w);
        expect(c, greaterThanOrEqualTo(previous),
            reason: 'columns dropped going up to ${w}px');
        previous = c;
      }
    });

    test('an ultra-wide panel is capped, not split into slivers', () {
      final int c = kioskOptionColumns(width: 12000, cardWidth: 300, gap: 20);
      expect(c, lessThanOrEqualTo(kOptionMaxColumns));
    });
  });

  group('the row divides exactly', () {
    test('cards plus gaps fill the panel with no ragged edge', () {
      for (double w = 320; w <= 3000; w += 10) {
        final l = layout(w);
        final int c =
            kioskOptionColumns(width: l.inner, cardWidth: l.card, gap: l.gap);
        final double used = cardAt(w) * c + l.gap * (c - 1);
        expect(used, closeTo(l.inner, 0.5),
            reason: 'row does not fill the panel at ${w}px');
      }
    });

    test('cards are always positive', () {
      for (double w = 200; w <= 3000; w += 10) {
        expect(cardAt(w), greaterThan(0));
      }
    });
  });

  group('degenerate input', () {
    test('zero, negative and absurd widths still return the minimum', () {
      expect(kioskOptionColumns(width: 0, cardWidth: 100, gap: 10),
          kOptionMinColumns);
      expect(kioskOptionColumns(width: -50, cardWidth: 100, gap: 10),
          kOptionMinColumns);
      expect(kioskOptionColumns(width: 90, cardWidth: 424, gap: 20),
          kOptionMinColumns);
      expect(kioskOptionColumns(width: 500, cardWidth: 0, gap: 10),
          kOptionMinColumns);
    });
  });
}
