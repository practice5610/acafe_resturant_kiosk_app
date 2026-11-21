import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acafe_customer/features/kiosk/landscape/landscape_metrics.dart';

/// The landscape scale helper is constraint-based: it fits the 1366x1024 design
/// base into whatever tablet it is given by the smaller of the two axes, so the
/// layout is responsive on any size and aspect ratio and never uses fixed px.
void main() {
  group('LandscapeMetrics.scaleFor (fit = min(w/1366, h/1024))', () {
    test('the design base 1366x1024 is exactly scale 1.0', () {
      expect(LandscapeMetrics.scaleFor(1366, 1024), 1.0);
    });

    test('a half-width window is width-bound at 0.5', () {
      expect(LandscapeMetrics.scaleFor(683, 1024), closeTo(0.5, 1e-9));
    });

    test('a half-height window is height-bound at 0.5', () {
      expect(LandscapeMetrics.scaleFor(1366, 512), closeTo(0.5, 1e-9));
    });

    test('a bigger tablet scales up by the smaller axis', () {
      expect(LandscapeMetrics.scaleFor(2732, 2048), closeTo(2.0, 1e-9));
    });

    test('an extra-wide 4000x1024 window is bounded by height, not width', () {
      expect(LandscapeMetrics.scaleFor(4000, 1024), closeTo(1.0, 1e-9));
    });

    test('zero or negative dimensions fall back to 1.0', () {
      expect(LandscapeMetrics.scaleFor(0, 1024), 1.0);
      expect(LandscapeMetrics.scaleFor(1366, -5), 1.0);
    });

    test('non-finite dimensions fall back to 1.0', () {
      expect(LandscapeMetrics.scaleFor(double.infinity, 1024), 1.0);
      expect(LandscapeMetrics.scaleFor(double.nan, 1024), 1.0);
    });
  });

  group('LandscapeMetrics instance', () {
    test('px multiplies a design value by the scale', () {
      final m = LandscapeMetrics.fromSize(const Size(683, 1024)); // scale 0.5
      expect(m.px(100), closeTo(50, 1e-9));
    });

    test('fromConstraints reads the max width and height', () {
      final m = LandscapeMetrics.fromConstraints(
          const BoxConstraints(maxWidth: 1366, maxHeight: 512));
      expect(m.scale, closeTo(0.5, 1e-9));
      expect(m.size, const Size(1366, 512));
    });
  });
}
