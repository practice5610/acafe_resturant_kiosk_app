import 'package:acafe_customer/common/responsive/kiosk_responsive.dart';
import 'package:acafe_customer/features/realtime/device_settings_event.dart';
import 'package:flutter_test/flutter_test.dart';

/// Per-category products-per-row override on the kiosk menu grid geometry.
///
/// The critical contract (decision #4): an override REPLACES the resolved
/// column count directly, clamped 1..6, bypassing the responsive
/// `minProductColumns = 3` floor. A null override leaves today's responsive
/// count untouched (no hardcoded 3).
void main() {
  // A wide area that, with the 3-floor, resolves to 3 columns -- the production
  // kiosk's product area. Used to prove the override can go BELOW that floor.
  const double areaWidth = 900;
  const double gap = 24;

  int resolvedColumns({int? columnsOverride}) {
    return KioskProductGridGeometry.resolve(
      areaWidth: areaWidth,
      gap: gap,
      columnsOverride: columnsOverride,
    ).columns;
  }

  group('columnsOverride', () {
    test('no override keeps the responsive count (>= 3 floor)', () {
      // Baseline: without an override this area resolves to the 3-floor.
      expect(resolvedColumns(), 3);
    });

    test('Poffertjes = 2 renders 2 per row, not 3 (bypasses the floor)', () {
      expect(resolvedColumns(columnsOverride: 2), 2);
    });

    test('an override of 1 is honoured', () {
      expect(resolvedColumns(columnsOverride: 1), 1);
    });

    test('an override above the max is clamped to 6', () {
      expect(resolvedColumns(columnsOverride: 99), 6);
    });

    test('an override of 0 or negative is clamped up to 1', () {
      expect(resolvedColumns(columnsOverride: 0), 1);
      expect(resolvedColumns(columnsOverride: -4), 1);
    });

    test('tile width reflects the overridden column count', () {
      final two = KioskProductGridGeometry.resolve(
          areaWidth: areaWidth, gap: gap, columnsOverride: 2);
      final three = KioskProductGridGeometry.resolve(
          areaWidth: areaWidth, gap: gap);
      // Fewer columns => wider cards.
      expect(two.tileWidth, greaterThan(three.tileWidth));
    });
  });

  group('parseCategoryColumnsMap', () {
    test('string keys and values are parsed and kept when in range', () {
      expect(parseCategoryColumnsMap({'7': 2, '10': 6}), {7: 2, 10: 6});
    });

    test('drops out-of-range, zero, and non-numeric entries', () {
      expect(
        parseCategoryColumnsMap({'7': 2, '8': 0, '9': 99, 'abc': 4}),
        {7: 2},
      );
    });

    test('a non-map (or null) parses to an empty map', () {
      expect(parseCategoryColumnsMap(null), isEmpty);
      expect(parseCategoryColumnsMap('nope'), isEmpty);
      expect(parseCategoryColumnsMap(<String, dynamic>{}), isEmpty);
    });
  });
}
