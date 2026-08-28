import 'dart:ui' show Size;

import 'package:acafe_customer/features/kiosk/domain/kiosk_customize_spec.dart';
import 'package:flutter_test/flutter_test.dart';

/// The responsive rule for the customize screen.
///
/// The bug this replaces: the screen scaled by VIEWPORT WIDTH alone. On the
/// 2572x5400 kiosk that is exact, but on anything proportionally shorter — a
/// browser window, a landscape tablet — it asks for more height than exists, so
/// the header, the cards and the buttons all render bigger than the design ever
/// intended and the options get squeezed into what is left. The scale is
/// bounded by both axes now.
void main() {
  /// The product the Figma frame draws: a description, one dietary group,
  /// add-ons and the cup/can question.
  double figmaProduct() => kioskCustomizeArtboardHeight(
        hasDescription: true,
        variationPanels: 1,
        hasAddOns: true,
        hasVessel: true,
      );

  double scaleAt(double w, double h, [double? artboard]) => kioskCustomizeScale(
        viewport: Size(w, h),
        artboardHeight: artboard ?? figmaProduct(),
      );

  group('the artboard height follows the product', () {
    test('the Figma product fits inside the 5400px frame', () {
      // The frame is 5400 because it draws three rows of add-ons; the rule
      // counts one, so it must come in under the artboard but not far under.
      expect(figmaProduct(), lessThan(KioskCustomizeSpec.artboardHeight));
      expect(
          figmaProduct(), greaterThan(KioskCustomizeSpec.artboardHeight * 0.8));
    });

    test('a product with no options needs far less height', () {
      final double bare = kioskCustomizeArtboardHeight(
        hasDescription: false,
        variationPanels: 0,
        hasAddOns: false,
        hasVessel: false,
      );
      expect(bare, lessThan(figmaProduct() * 0.6));
    });

    test('each section adds height, none of them subtract', () {
      double taller(
              {int panels = 0, bool addOns = false, bool vessel = false}) =>
          kioskCustomizeArtboardHeight(
            hasDescription: false,
            variationPanels: panels,
            hasAddOns: addOns,
            hasVessel: vessel,
          );
      final double none = taller();
      expect(taller(panels: 1), greaterThan(none));
      expect(taller(panels: 2), greaterThan(taller(panels: 1)));
      expect(taller(addOns: true), greaterThan(none));
      expect(taller(vessel: true), greaterThan(none));
    });

    test('a description costs two lines of Swiss 721', () {
      final double withText = kioskCustomizeArtboardHeight(
          hasDescription: true,
          variationPanels: 1,
          hasAddOns: true,
          hasVessel: true);
      final double without = kioskCustomizeArtboardHeight(
          hasDescription: false,
          variationPanels: 1,
          hasAddOns: true,
          hasVessel: true);
      expect(
          withText - without,
          closeTo(
            KioskCustomizeSpec.titleToDescription +
                KioskCustomizeSpec.descriptionSize *
                    KioskCustomizeSpec.descriptionLineHeight *
                    2,
            0.001,
          ));
    });
  });

  group('the kiosk itself renders 1:1 with Figma', () {
    test('at the artboard\'s own size the scale is exactly 1', () {
      expect(
          scaleAt(KioskCustomizeSpec.artboardWidth,
              KioskCustomizeSpec.artboardHeight),
          1.0);
    });

    test('a display bigger than the artboard is capped, never magnified', () {
      expect(scaleAt(4000, 8000), 1.0);
      expect(scaleAt(6000, 12000), 1.0);
    });

    test('a portrait kiosk of the artboard\'s shape scales proportionally', () {
      // 1286x2700 is the artboard halved: everything should land on 0.5.
      expect(scaleAt(1286, 2700), closeTo(0.5, 0.001));
    });
  });

  group('height is a ceiling, which is the actual fix', () {
    test('a viewport shorter than the artboard\'s shape scales DOWN', () {
      // 1080x1920 portrait: width alone would say 0.42, but 1920px cannot carry
      // 0.42 of a 4800px page.
      const double w = 1080, h = 1920;
      final double byWidth = w / KioskCustomizeSpec.artboardWidth;
      final double s = scaleAt(w, h);
      expect(s, lessThan(byWidth),
          reason: 'the old screen used byWidth here and overflowed');
      expect(figmaProduct() * s, lessThanOrEqualTo(h + 0.5));
    });

    test('the browser window the screen looked oversized in shrinks', () {
      // ~497x807 CSS px. The old rule clamped at 0.24 and rendered a page that
      // needed 1296px of height in 807.
      final double s = scaleAt(497, 807);
      expect(s, lessThan(0.24),
          reason: 'this is the clamp that made everything look too big');
    });

    test('taller viewports never scale smaller than shorter ones', () {
      double previous = 0;
      for (double h = 400; h <= 6000; h += 25) {
        final double s = scaleAt(1080, h);
        expect(s, greaterThanOrEqualTo(previous - 1e-9),
            reason: 'scale dropped going up to ${h}px tall');
        previous = s;
      }
    });

    test('wider viewports never scale smaller than narrower ones', () {
      double previous = 0;
      for (double w = 320; w <= 4000; w += 20) {
        final double s = scaleAt(w, 2000);
        expect(s, greaterThanOrEqualTo(previous - 1e-9),
            reason: 'scale dropped going up to ${w}px wide');
        previous = s;
      }
    });

    test('a shorter product is not shrunk for height it never asked for', () {
      final double bare = kioskCustomizeArtboardHeight(
        hasDescription: false,
        variationPanels: 1,
        hasAddOns: false,
        hasVessel: false,
      );
      expect(scaleAt(1080, 1400, bare), greaterThan(scaleAt(1080, 1400)));
    });
  });

  group('bounded, so nothing ever renders illegibly small', () {
    test('height can only pull the scale so far below the width rule', () {
      // A wide, short desktop window: 1600x600 would otherwise ask for 0.12.
      final double byWidth =
          1600 / KioskCustomizeSpec.artboardWidth; // capped below 1
      final double s = scaleAt(1600, 600);
      expect(s, closeTo(byWidth * kKioskCustomizeHeightPull, 1e-9));
    });

    test('every plausible viewport keeps the scale in range', () {
      for (double w = 320; w <= 4000; w += 40) {
        for (double h = 400; h <= 4000; h += 100) {
          final double s = scaleAt(w, h);
          expect(s, greaterThanOrEqualTo(kKioskCustomizeMinScale));
          expect(s, lessThanOrEqualTo(1.0));
        }
      }
    });

    test('degenerate viewports do not produce zero or NaN', () {
      expect(scaleAt(0, 0), kKioskCustomizeMinScale);
      expect(scaleAt(-100, 500), kKioskCustomizeMinScale);
      expect(
          kioskCustomizeScale(
              viewport: const Size(500, 500), artboardHeight: 0),
          kKioskCustomizeMinScale);
    });
  });

  group('the pinned layout gives way to scrolling, never to overflow', () {
    test('the artboard-shaped kiosk pins everything', () {
      const Size kiosk = Size(
          KioskCustomizeSpec.artboardWidth, KioskCustomizeSpec.artboardHeight);
      expect(
        kioskCustomizeFits(
          viewport: kiosk,
          artboardHeight: figmaProduct(),
          scale: kioskCustomizeScale(
              viewport: kiosk, artboardHeight: figmaProduct()),
        ),
        isTrue,
      );
    });

    test('a window too short even at the floor falls back to scrolling', () {
      const Size squat = Size(1600, 600);
      expect(
        kioskCustomizeFits(
          viewport: squat,
          artboardHeight: figmaProduct(),
          scale: kioskCustomizeScale(
              viewport: squat, artboardHeight: figmaProduct()),
        ),
        isFalse,
        reason: 'shrinking further would be illegible; the page scrolls',
      );
    });

    test('whenever it pins, the page genuinely fits the viewport', () {
      for (double w = 320; w <= 3000; w += 40) {
        for (double h = 500; h <= 4000; h += 100) {
          final Size viewport = Size(w, h);
          final double s = kioskCustomizeScale(
              viewport: viewport, artboardHeight: figmaProduct());
          if (kioskCustomizeFits(
              viewport: viewport, artboardHeight: figmaProduct(), scale: s)) {
            expect(figmaProduct() * s, lessThanOrEqualTo(h + 0.5),
                reason: 'pinned at ${w}x$h but the page is taller than that');
          }
        }
      }
    });

    test('a landscape artboard is the taller column plus the action bar', () {
      final double stacked = kioskCustomizeArtboardHeight(
        hasDescription: true,
        variationPanels: 1,
        hasAddOns: true,
        hasVessel: true,
      );
      final double landscape = kioskCustomizeArtboardHeight(
        hasDescription: true,
        variationPanels: 1,
        hasAddOns: true,
        hasVessel: true,
        landscape: true,
      );
      // Two columns, so the page is shorter than the stack — but by the real
      // difference (the header column drops out from under the panels), not by
      // a flat factor.
      expect(landscape, lessThan(stacked));
      expect(landscape,
          closeTo(stacked - KioskCustomizeSpec.headerHeight(hasDescription: true) -
              KioskCustomizeSpec.headerToPanels, 0.001),
          reason: 'the panel column is the taller one for this product');
    });

    test('a landscape artboard never budgets less than the header column', () {
      // The regression: a product whose only question is a Size row has a
      // SHORT panel column, so a fraction-of-the-stack rule budgeted less
      // height than the header alone occupies. The scale came out too large
      // and the hero/name/stepper block overflowed across the action bar.
      final double landscape = kioskCustomizeArtboardHeight(
        hasDescription: true,
        variationPanels: 1,
        hasAddOns: false,
        hasVessel: false,
        landscape: true,
      );
      expect(
        landscape,
        greaterThanOrEqualTo(
            KioskCustomizeSpec.headerHeight(hasDescription: true) +
                KioskCustomizeSpec.actionBarBlock),
        reason: 'the header column does not scroll; it has to fit',
      );
    });

    test('landscape scale at 2560×1440 is no longer stuck at the height-pull floor',
        () {
      final double artboard = kioskCustomizeArtboardHeight(
        hasDescription: true,
        variationPanels: 1,
        hasAddOns: true,
        hasVessel: true,
        landscape: true,
      );
      const Size viewport = Size(2560, 1440);
      final double s = kioskCustomizeScale(
          viewport: viewport, artboardHeight: artboard);
      // Without the landscape branch, scale landed at byWidth × 0.55 = 0.308
      // on every landscape size from 1366 to 2560.
      expect(s, greaterThan(0.45),
          reason: 'portrait-in-landscape used to freeze at byWidth×0.55≈0.308');
      expect(KioskCustomizeSpec.artboardWidth * s / 2560, greaterThan(0.45));
    });
  });
}
