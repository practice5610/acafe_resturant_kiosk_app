import 'package:acafe_customer/features/kiosk/widgets/kiosk_upsell_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The upsell grid once rendered six cards as one tall column on a ~580px
/// window. The cause was arithmetic, not styling: `tile * columns + gutters`
/// came out EXACTLY equal to the space available, so floating-point error
/// tipped `Wrap` into a line break on every card.
///
/// These assert the invariant directly at real viewport widths.
void main() {
  KioskUpsellGridMetrics metricsFor(double width) =>
      KioskUpsellGridMetrics.forWidth(width);

  /// Widths that matter: the window from the bug report, small tablets, the
  /// kiosk artboard, and a 4K panel — plus awkward values in between.
  const widths = <double>[
    320, 375, 480, 520, 578, 580, 600, 640, 768, 800, 1024, 1080, 1200,
    1366, 1440, 1600, 1920, 2160, 2572, 3000, 3840,
  ];

  test('a full row always fits inside the sheet', () {
    for (final w in widths) {
      final m = metricsFor(w);
      expect(m.fits, isTrue,
          reason: 'viewport ${w}px: row ${m.rowWidth} >= available ${m.available} '
              '(${m.columns} x ${m.tile} + gutters) — Wrap would break');
    }
  });

  test('and still fits at every width in a continuous sweep', () {
    // The original bug only appeared at one specific width, so spot checks are
    // not enough — sweep the whole plausible range.
    for (double w = 300; w <= 3840; w += 1) {
      final m = metricsFor(w);
      expect(m.fits, isTrue, reason: 'viewport ${w}px overflows');
    }
  });

  test('tiles are whole pixels', () {
    // Fractional tiles are what made the sum unstable in the first place.
    for (final w in widths) {
      final m = metricsFor(w);
      expect(m.tile, m.tile.floorToDouble(), reason: 'viewport ${w}px');
    }
  });

  test('the bug-report width now lays out three across', () {
    // ~578 CSS px: the window in the screenshot, which rendered one per row.
    final m = metricsFor(578);
    expect(m.columns, 3);
    expect(m.tile, greaterThanOrEqualTo(112));
    expect(m.fits, isTrue);
  });

  test('cards never shrink below a legible size', () {
    for (final w in widths) {
      final m = metricsFor(w);
      // Single column is the escape hatch for a viewport too narrow for two.
      if (m.columns > 1) {
        expect(m.tile, greaterThanOrEqualTo(112),
            reason: 'viewport ${w}px gave ${m.columns} columns of ${m.tile}');
      }
    }
  });

  test('wide screens keep the design three across rather than sprawling', () {
    for (final w in [1080.0, 1920.0, 2572.0, 3840.0]) {
      expect(metricsFor(w).columns, 3, reason: 'viewport ${w}px');
    }
  });

  _renderTests();
  _proportionTests();
  _sheetSizeTests();
}

/// The arithmetic above is necessary but not sufficient — the bug showed up as
/// a RENDER, so assert the render too. These pump the same Wrap/SizedBox shape
/// the sheet builds, with plain boxes standing in for the product cards (which
/// need providers), and check the cards actually share a row.
void _renderTests() {
  Future<List<Offset>> pumpGrid(WidgetTester tester, double viewport) async {
    final m = KioskUpsellGridMetrics.forWidth(viewport);

    tester.view.physicalSize = Size(viewport, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MediaQuery(
      data: MediaQueryData(size: Size(viewport, 1400)),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: m.sheetWidth,
            child: Padding(
              padding: EdgeInsets.all(m.pad),
              child: Wrap(
                spacing: m.gutter,
                runSpacing: m.gutter,
                alignment: WrapAlignment.center,
                children: List.generate(
                  6,
                  (i) => SizedBox(
                    key: ValueKey('tile$i'),
                    width: m.tile,
                    height: 100,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ));

    return [
      for (int i = 0; i < 6; i++)
        tester.getTopLeft(find.byKey(ValueKey('tile$i'))),
    ];
  }

  testWidgets('six suggestions render as two rows of three, not one column',
      (tester) async {
    // 578px is the window from the bug report.
    final tops = await pumpGrid(tester, 578);

    expect(tester.takeException(), isNull);
    // First three share a row; last three share the next.
    expect(tops[0].dy, tops[1].dy);
    expect(tops[1].dy, tops[2].dy);
    expect(tops[3].dy, greaterThan(tops[0].dy));
    expect(tops[3].dy, tops[4].dy);
    expect(tops[4].dy, tops[5].dy);
    // ...and they are genuinely side by side, not stacked.
    expect(tops[1].dx, greaterThan(tops[0].dx));
    expect(tops[2].dx, greaterThan(tops[1].dx));
  });

  testWidgets('holds three across at kiosk size too', (tester) async {
    final tops = await pumpGrid(tester, 1080);
    expect(tops[0].dy, tops[2].dy);
    expect(tops[3].dy, greaterThan(tops[0].dy));
  });
}

/// The cards were "still bigger than Figma" after the first fix, because the
/// padding and gutters were derived from the artboard scale and bottomed out on
/// their clamps — leaving the tiles to soak up the difference. These pin the
/// proportions to the design instead.
void _proportionTests() {
  KioskUpsellGridMetrics m(double w) => KioskUpsellGridMetrics.forWidth(w);

  test('a card is ~26.7% of the sheet, as in Figma', () {
    // Figma sheet 412px: 24px padding, 17px gutters, 110px cards.
    for (final w in [586.0, 768.0, 1080.0, 1440.0, 1920.0, 2572.0]) {
      final g = m(w);
      expect(g.columns, 3, reason: 'viewport ${w}px');
      expect(g.tile / g.sheetWidth, closeTo(0.267, 0.012),
          reason: 'viewport ${w}px gave ${(g.tile / g.sheetWidth * 100)}%');
    }
  });

  test('chrome keeps its Figma share of the sheet', () {
    for (final w in [586.0, 1080.0, 1920.0]) {
      final g = m(w);
      expect(g.pad / g.sheetWidth, closeTo(0.058, 0.008), reason: 'padding');
      expect(g.gutter / g.sheetWidth, closeTo(0.041, 0.008), reason: 'gutter');
    }
  });

  test('padding is always larger than the gutter', () {
    // Design rule: the sheet breathes more at its edge than between cards.
    // Inverting this is what makes a grid look glued to its container.
    for (double w = 320; w <= 3840; w += 17) {
      final g = m(w);
      expect(g.pad, greaterThan(g.gutter), reason: 'viewport ${w}px');
    }
  });

  test('the grid still fits once a scrollbar actually appears', () {
    // The 586px window rendered 2-across because 3 fitted by 2px and the
    // vertical scrollbar then took 15 of them. `forWidth` now reserves that
    // width up front, so the invariant to check is that the sheet it returns
    // survives in the space left AFTER the bar shows up — not that a second
    // reserve can be subtracted on top (which would double-count it).
    const scrollbar = 15.0;
    for (double w = 320; w <= 3840; w += 7) {
      final g = m(w);
      expect(g.sheetWidth, lessThanOrEqualTo(w - scrollbar),
          reason: 'viewport ${w}px: sheet would be clipped by the scrollbar');
      expect(g.fits, isTrue, reason: 'viewport ${w}px');
    }
  });
}

/// The sheet itself was the thing that read as oversized: 86% of the viewport
/// with an unbounded height, plus a grid that stranded a single card on its own
/// row whenever the candidate count did not divide by the column count.
void _sheetSizeTests() {
  KioskUpsellGridMetrics m(double w) => KioskUpsellGridMetrics.forWidth(w);

  test('the sheet leaves the page visible around it', () {
    // A modal that fills its window has stopped being a modal. The Figma mock
    // keeps roughly 9% of the screen clear on each side.
    for (final w in [581.0, 768.0, 1080.0, 1440.0]) {
      final g = m(w);
      expect(g.sheetWidth / w, lessThanOrEqualTo(0.80), reason: 'viewport ${w}px');
      expect(g.sheetWidth / w, greaterThan(0.60), reason: 'viewport ${w}px');
    }
  });

  test('never strands a single card on the last row', () {
    for (final w in [581.0, 768.0, 1080.0, 1920.0]) {
      final g = m(w);
      for (int available = 1; available <= 6; available++) {
        final shown = g.visibleCount(available);
        expect(shown, lessThanOrEqualTo(available));
        if (shown >= g.columns) {
          expect(shown % g.columns, 0,
              reason: 'viewport ${w}px with $available candidates showed '
                  '$shown across ${g.columns} columns — leaves an orphan row');
        }
      }
    }
  });

  test('fills two rows when there is enough to fill them', () {
    // Two rows of three is the design.
    for (final w in [581.0, 1080.0, 1920.0]) {
      final g = m(w);
      expect(g.visibleCount(6), g.columns * 2, reason: 'viewport ${w}px');
      expect(g.visibleCount(9), g.columns * 2, reason: 'never more than 2 rows');
    }
  });

  test('a thin catalogue still shows what it has', () {
    // A branch with two drinks should not be shown an empty sheet.
    final g = m(1080);
    expect(g.visibleCount(0), 0);
    expect(g.visibleCount(1), 1);
    expect(g.visibleCount(2), 2);
  });

  test('landscape wide sheets use four columns and still fit', () {
    final m = KioskUpsellGridMetrics.forWidth(1920, viewportHeight: 1080);
    expect(m.columns, 4);
    expect(m.fits, isTrue);
    expect(m.visibleCount(6), 4);
    expect(m.visibleCount(8), 8);
  });
}
