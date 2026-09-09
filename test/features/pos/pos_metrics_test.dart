import 'package:acafe_customer/features/pos/domain/pos_responsive.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Real windows a POS terminal actually lands in.
const Size counter1920 = Size(1920, 1080);
const Size counter1280 = Size(1280, 800);
const Size laptop1366 = Size(1366, 768);
const Size large4k = Size(3840, 2160);
const Size tabletPortrait = Size(1024, 1366);
const Size phone = Size(430, 932);

void main() {
  group('structure is chosen by band and orientation, not by shrinking', () {
    test('the counter terminal pins the receipt panel open', () {
      final m = PosMetrics.resolve(counter1920);
      expect(m.isLandscape, isTrue);
      expect(m.band, PosBand.standard);
      expect(m.showsSideReceipt, isTrue);
    });

    test('a phone drops the side receipt rather than splitting into slivers',
        () {
      final m = PosMetrics.resolve(phone);
      expect(m.band, PosBand.compact);
      expect(m.showsSideReceipt, isFalse);
    });

    test(
        'a tablet just under the desktop floor is wide enough by the number '
        'but still splits badly in portrait', () {
      // 1000 clears the compact threshold but sits below the desktop floor,
      // so orientation still gates it: width alone would pin the panel open
      // and leave two unusable columns.
      final m = PosMetrics.resolve(const Size(1000, 1366));
      expect(m.band, PosBand.standard);
      expect(m.isPortrait, isTrue);
      expect(m.showsSideReceipt, isFalse);
    });

    test(
        'a portrait desktop monitor at the floor keeps the full layout '
        'anyway', () {
      // 1024 is the desktop floor: from here up it is a pure width decision.
      // A monitor turned portrait is still plainly a desktop window with
      // room for three panes — it must not drop to the compact bottom bar
      // just because it is taller than it is wide.
      final m = PosMetrics.resolve(tabletPortrait);
      expect(m.band, PosBand.standard);
      expect(m.isPortrait, isTrue);
      expect(m.showsSideReceipt, isTrue);
    });

    test('the desktop floor is a pure width decision at any height', () {
      for (final size in [
        const Size(1024, 700), // short landscape
        const Size(1024, 3000), // extreme portrait
        const Size(1600, 2200), // large portrait monitor
      ]) {
        expect(PosMetrics.resolve(size).showsSideReceipt, isTrue,
            reason: 'side receipt dropped at $size');
      }
    });

    test('a large-format display keeps the same structure with more air', () {
      final m = PosMetrics.resolve(large4k);
      expect(m.band, PosBand.large);
      expect(m.showsSideReceipt, isTrue);
    });
  });

  group('density is bounded on both sides', () {
    test('the reference board is exactly 1.0', () {
      expect(PosMetrics.resolve(counter1920).scale, 1.0);
    });

    test('a short landscape laptop reduces density instead of overflowing', () {
      // 1366x768: byWidth 0.71, byHeight 0.71. Height must participate or the
      // chrome inflates until the content pane is clipped.
      final m = PosMetrics.resolve(laptop1366);
      expect(m.scale, lessThan(1.0));
      expect(m.scale, greaterThanOrEqualTo(PosResponsive.minScale));
    });

    test('type never falls below the legibility floor', () {
      for (final size in [phone, const Size(320, 480), const Size(800, 400)]) {
        expect(PosMetrics.resolve(size).scale,
            greaterThanOrEqualTo(PosResponsive.minScale),
            reason: 'scale collapsed at $size');
      }
    });

    test('4K does not inflate without bound', () {
      expect(PosMetrics.resolve(large4k).scale, PosResponsive.maxScale);
    });

    test('scale is driven by the tighter axis', () {
      // Very wide but short: height is the binding constraint.
      final m = PosMetrics.resolve(const Size(3000, 900));
      expect(m.scale, closeTo(900 / PosResponsive.designHeight, 0.0001));
    });
  });

  group('receipt panel width', () {
    test('is bounded at both ends', () {
      expect(PosResponsive.receiptPanelWidth(1000),
          greaterThanOrEqualTo(PosResponsive.receiptMin));
      expect(PosResponsive.receiptPanelWidth(8000),
          PosResponsive.receiptMax);
    });

    test('leaves the majority of a counter terminal to the content pane', () {
      final w = PosResponsive.receiptPanelWidth(counter1920.width);
      expect(w, lessThan(counter1920.width / 2));
    });
  });

  group('desktop floor: no structural jump at/above 1024', () {
    // The whole point of the floor: resizing across it — or turning a wide
    // window portrait — must never flip the composition between "3 panes"
    // and "compact bar", and the two side panes must move continuously
    // rather than snapping between a flat design pixel and a proportion.
    const List<double> desktopWidths = [1024, 1180, 1300, 1366, 1440, 1920, 2199];

    test('the side receipt never drops at/above the floor, in either orientation', () {
      for (final width in desktopWidths) {
        for (final height in [width * 0.5, width * 0.75, width, width * 1.5]) {
          final m = PosMetrics.resolve(Size(width, height));
          expect(m.showsSideReceipt, isTrue,
              reason: 'dropped the side receipt at ${width}x$height');
        }
      }
    });

    test('sidebar and receipt widths grow continuously with the window', () {
      double lastSidebar = PosResponsive.sidebarWidth(desktopWidths.first);
      double lastReceipt = PosResponsive.receiptWidth(desktopWidths.first);
      for (final width in desktopWidths.skip(1)) {
        final double sidebar = PosResponsive.sidebarWidth(width);
        final double receipt = PosResponsive.receiptWidth(width);
        expect(sidebar, greaterThan(lastSidebar),
            reason: 'sidebar did not grow at $width');
        expect(receipt, greaterThan(lastReceipt),
            reason: 'receipt did not grow at $width');
        lastSidebar = sidebar;
        lastReceipt = receipt;
      }
    });

    test('reproduces the Figma 192/421 pixels exactly at the 1366 reference',
        () {
      // closeTo, not exact equality: the ratio is computed as a fraction
      // (192/1366) and multiplied back by 1366, which floating point does not
      // guarantee round-trips to the exact integer — sub-pixel noise no
      // render can show.
      expect(PosResponsive.sidebarWidth(1366), closeTo(192, 0.001));
      expect(PosResponsive.receiptWidth(1366), closeTo(421, 0.001));
    });

    test('below the floor, sidebar stays flat at the legacy design pixel', () {
      for (final width in [900.0, 1000.0, 1023.999]) {
        expect(PosResponsive.sidebarWidth(width), 192);
      }
    });

    test('the sidebar and receipt keep the 192:753:421 ratio above the floor',
        () {
      for (final width in desktopWidths) {
        final double sidebar = PosResponsive.sidebarWidth(width);
        final double receipt = PosResponsive.receiptWidth(width);
        expect(sidebar / receipt, closeTo(192 / 421, 0.0001),
            reason: 'ratio drifted at $width');
      }
    });
  });

  test('PosMetrics equality drives InheritedWidget updates', () {
    expect(PosMetrics.resolve(counter1920), PosMetrics.resolve(counter1920));
    expect(PosMetrics.resolve(counter1920) == PosMetrics.resolve(counter1280),
        isFalse);
  });
}
