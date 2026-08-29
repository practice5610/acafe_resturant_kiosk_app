import 'package:acafe_customer/common/responsive/kiosk_responsive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The product area the banner is laid out in, for a given window. Mirrors what
/// the menu screen measures: page margins, then the category rail and its gap.
double _areaWidthFor(Size window) {
  final metrics = KioskMetrics.resolve(window);
  final double inner = metrics.contentWidth - 2 * (85 * metrics.scale);
  final rail = kioskCategoryRailLayout(
    scale: metrics.scale,
    innerWidth: inner,
  );
  return inner - rail.width - rail.gap;
}

/// Every shape the two seeded deal images and a few adversarial uploads take.
const double kWideBanner = 2400 / 1000; // 2.40 — the house banner
const double kNarrowBanner = 1672 / 941; // 1.78 — the second live deal
const double kSquareUpload = 1.0;
const double kStripUpload = 8.0;

/// Real devices this kiosk actually runs on or is previewed at.
const Map<String, Size> kDevices = {
  'production kiosk 1080×1920': Size(1080, 1920),
  'iPad mini portrait': Size(744, 1133),
  'iPad Pro 11 portrait': Size(834, 1194),
  'iPad Pro 12.9 landscape': Size(1366, 1024),
  'small browser window': Size(990, 1560),
  'MacBook 14 landscape': Size(1512, 982),
  'desktop 2000×1300': Size(2000, 1300),
  'QHD landscape': Size(2560, 1440),
  '4K landscape': Size(3840, 2160),
  'portrait 4K kiosk': Size(2160, 3840),
};

void main() {
  group('KioskDealBannerGeometry', () {
    test('height follows the artwork, so there is nothing to crop', () {
      final geo = KioskDealBannerGeometry.resolve(
        areaWidth: 1200,
        windowWidth: 1500,
        imageAspect: kWideBanner,
      );
      expect(geo.width, 1200);
      expect(geo.aspect, closeTo(kWideBanner, 0.0001));
      expect(geo.height, closeTo(1200 / kWideBanner, 0.0001));
      expect(geo.capped, isFalse);
    });

    test('an unresolved ratio falls back to the design default', () {
      final geo = KioskDealBannerGeometry.resolve(
        areaWidth: 1000,
        windowWidth: 1000,
      );
      expect(geo.aspect, KioskResponsive.dealBannerDefaultAspect);
      expect(geo.height, closeTo(1000 / 2.4, 0.0001));
    });

    test('a near-square upload is clamped so it cannot take over the page', () {
      final geo = KioskDealBannerGeometry.resolve(
        areaWidth: 1200,
        windowWidth: 1200,
        imageAspect: kSquareUpload,
      );
      expect(geo.aspect, KioskResponsive.dealBannerMinAspect);
      expect(geo.height, closeTo(1200 / 1.6, 0.0001));
    });

    test('an ultra-wide strip is clamped so it cannot vanish', () {
      final geo = KioskDealBannerGeometry.resolve(
        areaWidth: 1200,
        windowWidth: 1200,
        imageAspect: kStripUpload,
      );
      expect(geo.aspect, KioskResponsive.dealBannerMaxAspect);
    });

    test('a zero-width frame yields a zero slot, never an infinity', () {
      for (final width in [0.0, -10.0, double.nan]) {
        final geo = KioskDealBannerGeometry.resolve(
          areaWidth: width,
          windowWidth: 1080,
        );
        expect(geo.width, 0);
        expect(geo.height, 0);
      }
    });

    group('half-window cap', () {
      test('binds on a large-format panel', () {
        final geo = KioskDealBannerGeometry.resolve(
          areaWidth: 2000,
          windowWidth: 2560,
          imageAspect: kWideBanner,
        );
        expect(geo.capped, isTrue);
        expect(geo.width, 1280); // exactly half the window
        expect(geo.width, lessThan(2000));
      });

      test('does not bind below the large band', () {
        final geo = KioskDealBannerGeometry.resolve(
          areaWidth: 900,
          windowWidth: KioskResponsive.largeMin - 1,
          imageAspect: kWideBanner,
        );
        expect(geo.capped, isFalse);
        expect(geo.width, 900);
      });

      test('never widens a banner past its product area', () {
        // A tall 4K portrait kiosk: half the window is far more than the grid.
        final geo = KioskDealBannerGeometry.resolve(
          areaWidth: 800,
          windowWidth: 2160,
          imageAspect: kWideBanner,
        );
        expect(geo.width, 800);
        expect(geo.capped, isFalse);
      });
    });

    group('height cap', () {
      test('a short landscape window shrinks the card, keeping its ratio', () {
        // 1366×768: a full-width 2.4:1 banner is over half the viewport.
        final geo = KioskDealBannerGeometry.resolve(
          areaWidth: 983,
          windowWidth: 1366,
          windowHeight: 768,
          imageAspect: kWideBanner,
        );
        expect(geo.capped, isTrue);
        expect(geo.height,
            closeTo(768 * KioskResponsive.dealBannerMaxHeightFraction, 0.001));
        // Shrunk, not squashed.
        expect(geo.width / geo.height, closeTo(kWideBanner, 0.0001));
        expect(geo.width, lessThan(983));
      });

      test('a tall window leaves the width cap in charge', () {
        final geo = KioskDealBannerGeometry.resolve(
          areaWidth: 800,
          windowWidth: 1080,
          windowHeight: 1920,
          imageAspect: kWideBanner,
        );
        expect(geo.capped, isFalse);
        expect(geo.width, 800);
      });

      test('the cap never widens a banner past its product area', () {
        for (final window in kDevices.values) {
          final double area = _areaWidthFor(window);
          final geo = KioskDealBannerGeometry.resolve(
            areaWidth: area,
            windowWidth: window.width,
            windowHeight: window.height,
            imageAspect: kWideBanner,
          );
          expect(geo.width, lessThanOrEqualTo(area + 0.001));
        }
      });
    });

    group('forAll — the shared carousel slot', () {
      test('is tall enough for the tallest banner in the set', () {
        final slot = KioskDealBannerGeometry.forAll(
          areaWidth: 1200,
          windowWidth: 1400,
          imageAspects: const [kWideBanner, kNarrowBanner],
        );
        expect(slot.aspect, closeTo(kNarrowBanner, 0.0001));
        expect(slot.height, closeTo(1200 / kNarrowBanner, 0.0001));

        // and every banner fits inside it at its own shape
        for (final aspect in const [kWideBanner, kNarrowBanner]) {
          final tile = KioskDealBannerGeometry.resolve(
            areaWidth: slot.width,
            windowWidth: double.infinity,
            imageAspect: aspect,
          );
          expect(tile.width, slot.width);
          expect(tile.height, lessThanOrEqualTo(slot.height + 0.001));
        }
      });

      test('two height-capped banners still share ONE width', () {
        // Regression: taking the tallest *geometry* used to win here. Once
        // both banners hit the height cap they are equally tall but not
        // equally wide, and the wide one's width made the narrow one's card
        // overflow its own page.
        const Size window = Size(900, 600);
        final double area = _areaWidthFor(window);
        final slot = KioskDealBannerGeometry.forAll(
          areaWidth: area,
          windowWidth: window.width,
          windowHeight: window.height,
          imageAspects: const [kWideBanner, kNarrowBanner],
        );

        for (final aspect in const [kWideBanner, kNarrowBanner]) {
          final solo = KioskDealBannerGeometry.resolve(
            areaWidth: area,
            windowWidth: window.width,
            windowHeight: window.height,
            imageAspect: aspect,
          );
          expect(slot.width, lessThanOrEqualTo(solo.width + 0.001),
              reason: 'the slot must fit inside every banner\'s own budget');

          final tile = KioskDealBannerGeometry.resolve(
            areaWidth: slot.width,
            windowWidth: double.infinity,
            imageAspect: aspect,
          );
          expect(tile.height, lessThanOrEqualTo(slot.height + 0.001));
        }

        // And the slot still respects the height cap.
        expect(
          slot.height,
          lessThanOrEqualTo(
            window.height * KioskResponsive.dealBannerMaxHeightFraction + 0.001,
          ),
        );
      });

      test('unresolved ratios still produce a usable slot', () {
        final slot = KioskDealBannerGeometry.forAll(
          areaWidth: 1000,
          windowWidth: 1000,
          imageAspects: const [null, null],
        );
        expect(slot.aspect, KioskResponsive.dealBannerDefaultAspect);
        expect(slot.height, greaterThan(0));
      });

      test('an empty set falls back to the default slot', () {
        final slot = KioskDealBannerGeometry.forAll(
          areaWidth: 1000,
          windowWidth: 1000,
          imageAspects: const <double?>[],
        );
        expect(slot.aspect, KioskResponsive.dealBannerDefaultAspect);
        expect(slot.width, 1000);
      });
    });

    group('across real devices', () {
      for (final entry in kDevices.entries) {
        test('${entry.key}: banner is sane and uncropped', () {
          final Size window = entry.value;
          final double area = _areaWidthFor(window);
          expect(area, greaterThan(0), reason: 'product area must be positive');

          for (final aspect in const [kWideBanner, kNarrowBanner]) {
            final geo = KioskDealBannerGeometry.resolve(
              areaWidth: area,
              windowWidth: window.width,
              windowHeight: window.height,
              imageAspect: aspect,
            );

            // Never wider than the room it was given.
            expect(geo.width, lessThanOrEqualTo(area + 0.001),
                reason: '${entry.key} overflows its product area');

            // Never more than its share of the viewport, so the products it
            // sits between stay on screen with it.
            expect(
              geo.height,
              lessThanOrEqualTo(window.height *
                      KioskResponsive.dealBannerMaxHeightFraction +
                  0.001),
              reason: '${entry.key} banner takes over the viewport',
            );

            // The slot IS the artwork's shape, so cover crops nothing.
            expect(geo.width / geo.height, closeTo(aspect, 0.0001),
                reason: '${entry.key} slot ratio drifted from the artwork');

            // Still big enough to read.
            expect(geo.height, greaterThan(60),
                reason: '${entry.key} banner is too small to see');
          }
        });
      }

      test('the half-window cap engages exactly on large panels', () {
        final capped = <String>[];
        for (final entry in kDevices.entries) {
          final geo = KioskDealBannerGeometry.resolve(
            areaWidth: _areaWidthFor(entry.value),
            windowWidth: entry.value.width,
            imageAspect: kWideBanner,
          );
          if (geo.capped) capped.add(entry.key);
          // (windowHeight left off on purpose: this asserts the WIDTH cap.)
        }
        // Only the genuinely wide displays; the 1080 kiosk and the tablets
        // keep a full-width banner.
        expect(capped, contains('desktop 2000×1300'));
        expect(capped, contains('QHD landscape'));
        expect(capped, contains('4K landscape'));
        expect(capped, isNot(contains('production kiosk 1080×1920')));
        expect(capped, isNot(contains('iPad Pro 12.9 landscape')));
        expect(capped, isNot(contains('MacBook 14 landscape')));
      });
    });

    test('the old fixed-height box was the bug: it ignored the artwork', () {
      // Regression guard, stated as the thing that used to go wrong. The old
      // slot was `760 * scale` tall at the full area width; on a wide landscape
      // window that is a ratio nowhere near the 2.4 artwork, so `BoxFit.cover`
      // had to crop. The new slot cannot drift from the image.
      const Size window = Size(2000, 1300);
      final metrics = KioskMetrics.resolve(window);
      final double area = _areaWidthFor(window);

      final double oldHeight = 760 * metrics.scale;
      final double oldRatio = area / oldHeight;
      expect((oldRatio - kWideBanner).abs(), greaterThan(0.5),
          reason: 'the old box really did disagree with the artwork');

      final geo = KioskDealBannerGeometry.resolve(
        areaWidth: area,
        windowWidth: window.width,
        imageAspect: kWideBanner,
      );
      expect(geo.width / geo.height, closeTo(kWideBanner, 0.0001));
    });
  });
}
