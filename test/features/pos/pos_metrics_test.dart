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

    test('a portrait tablet is wide enough by the number but still splits badly',
        () {
      // 1024 clears the compact threshold, so width alone would pin the panel
      // open and leave two unusable columns. Orientation is the real signal.
      final m = PosMetrics.resolve(tabletPortrait);
      expect(m.band, PosBand.standard);
      expect(m.isPortrait, isTrue);
      expect(m.showsSideReceipt, isFalse);
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

  test('PosMetrics equality drives InheritedWidget updates', () {
    expect(PosMetrics.resolve(counter1920), PosMetrics.resolve(counter1920));
    expect(PosMetrics.resolve(counter1920) == PosMetrics.resolve(counter1280),
        isFalse);
  });
}
