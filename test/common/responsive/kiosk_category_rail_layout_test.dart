import 'package:acafe_customer/common/responsive/kiosk_responsive.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the category rail is narrower than the old 524px Figma column', () {
    const double screen = 800;
    final double s = KioskResponsive.scale(screen);
    final double inner = screen - 2 * 85 * s;
    final rail = kioskCategoryRailLayout(scale: s, innerWidth: inner);

    expect(rail.width, lessThan(524 * s));
    expect(rail.gap, lessThan(104 * s));
  });

  test('on a small tablet the rail stays under a quarter of the row', () {
    const double screen = 700;
    final double s = KioskResponsive.scale(screen);
    final double inner = screen - 2 * 85 * s;
    final rail = kioskCategoryRailLayout(scale: s, innerWidth: inner);

    expect(rail.width, lessThanOrEqualTo(inner * 0.24 + 0.001));
    expect(rail.width + rail.gap, lessThan(inner * 0.4));
  });

  test('a tiny inner row does not throw when the cap is below the min', () {
    final rail = kioskCategoryRailLayout(scale: 0.24, innerWidth: 200);
    expect(rail.width, lessThanOrEqualTo(200 * 0.24));
    expect(rail.width + rail.gap, lessThan(200));
  });

  test('the wide rail shrinks below 1280px', () {
    expect(kioskWideCategoryRailWidth(1100), 120);
    expect(kioskWideCategoryRailWidth(1400), 140);
    expect(kioskWideCategoryRailWidth(1920), 156);
  });

  test('rail font size does not throw when 40×scale is below 11', () {
    expect(
      () => kioskCategoryRailFontSize(railWidth: 90, scale: 0.24),
      returnsNormally,
    );
    expect(
      kioskCategoryRailFontSize(railWidth: 90, scale: 0.24),
      greaterThan(0),
    );
  });
}
