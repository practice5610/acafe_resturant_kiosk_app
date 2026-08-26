import 'package:flutter/widgets.dart';

/// Single source of truth for kiosk responsive scaling.
///
/// Every kiosk screen is authored against a 2572px-wide Figma artboard and
/// rendered by multiplying each Figma pixel value by [scale]. Previously this
/// logic was copy-pasted into four screens (`kiosk_menu_screen`,
/// `kiosk_cart_screen`, `kiosk_product_customize_sheet`,
/// `kiosk_checkout_widgets`), each with a duplicated `2572` constant and
/// *inconsistent* clamping — the menu clamped the scale, the others did not, so
/// text became illegibly small on ~600px tablets and inflated without bound on
/// 4K displays. This module consolidates them so the clamp is applied uniformly.
///
/// Nothing about the visual design changes: same Figma pixels, same clamp the
/// menu already used. Screens narrower than [designWidth] render exactly as
/// before; only the small/ultra-wide extremes are corrected, and content on
/// very large screens is capped at [designWidth] and centered.
class KioskResponsive {
  KioskResponsive._();

  /// Figma artboard width every kiosk screen is designed against.
  static const double designWidth = 2572;

  /// Form screens (login, language picker) are authored against a narrower
  /// artboard and cap their content at this width.
  static const double formDesignWidth = 1000;

  /// Scale clamp. Below [minScale] chrome/typography become illegible on small
  /// tablets; above [maxScale] elements would inflate on ultra-wide/4K displays
  /// — instead content is capped at [designWidth] and centered.
  static const double minScale = 0.24;
  static const double maxScale = 1.0;

  /// Figma artboard px → logical px for a screen/area of the given [width]
  /// (clamped). This is the one true scale function for the kiosk flow.
  static double scale(double width) =>
      (width / designWidth).clamp(minScale, maxScale);

  /// Scale for the narrower form artboard, capped at [formDesignWidth].
  static double formScale(double width) =>
      (width < formDesignWidth ? width : formDesignWidth) / formDesignWidth;

  /// Responsive product-grid column count for the given product-area width.
  ///
  /// Per the Figma design the kiosk shows 3 products per row, so 3 is the
  /// minimum on every device; larger desktop / 4K displays step up to 4–6 so
  /// cards fill the extra width instead of ballooning.
  static int columns(double productAreaWidth) {
    if (productAreaWidth < 1080) return 3; // phone → small/medium kiosk
    if (productAreaWidth < 1550) return 4;
    if (productAreaWidth < 2100) return 5;
    return 6;
  }

  /// Breakpoint bucket for the given width (small <800, medium <1200,
  /// large <1600, xlarge ≥1600).
  static KioskBreakpoint breakpoint(double width) {
    if (width < 800) return KioskBreakpoint.small;
    if (width < 1200) return KioskBreakpoint.medium;
    if (width < 1600) return KioskBreakpoint.large;
    return KioskBreakpoint.xlarge;
  }

  /// Category rail on the 2572px artboard. 524px made the rail as wide as a
  /// product card once the artboard was scaled onto a tablet; 390px still
  /// fits labels like MERCHANDISE after scaling.
  static const double categoryRailDesignWidth = 390;

  /// Gap between the category rail and the product grid (Figma was 104px).
  static const double categoryRailDesignGap = 56;

  /// Rail must not take more than this share of the inner menu row.
  static const double categoryRailMaxFraction = 0.24;
}

/// Width + gap for the kiosk category rail on the narrow (< 1100px) menu.
///
/// Scales with [scale] like the rest of the Figma layout, then caps so the
/// product grid always keeps the majority of the row on small tablets.
KioskCategoryRailLayout kioskCategoryRailLayout({
  required double scale,
  required double innerWidth,
}) {
  if (innerWidth <= 0) {
    return const KioskCategoryRailLayout(width: 80, gap: 8);
  }
  final double preferredWidth = KioskResponsive.categoryRailDesignWidth * scale;
  final double maxWidth = innerWidth * KioskResponsive.categoryRailMaxFraction;
  final double preferredGap = KioskResponsive.categoryRailDesignGap * scale;
  final double maxGap = innerWidth * 0.045;
  return KioskCategoryRailLayout(
    width: _bounded(preferredWidth, min: 80, max: maxWidth),
    gap: _bounded(preferredGap, min: 8, max: maxGap),
  );
}

/// [clamp] throws when min > max (tiny inner rows). Prefer the cap.
double _bounded(double value, {required double min, required double max}) {
  if (max <= min) return max;
  return value.clamp(min, max);
}

/// Category-rail type size. Must not call `clamp(11, 40 * s)` — on a small
/// window `40 * s` is below 11 and Flutter paints a red "Invalid argument: 11"
/// box instead of the rail.
double kioskCategoryRailFontSize({
  required double railWidth,
  required double scale,
}) {
  final double maxSize = 40 * scale;
  final double preferred = railWidth * 0.12;
  return _bounded(preferred, min: 8, max: maxSize);
}

class KioskCategoryRailLayout {
  final double width;
  final double gap;
  const KioskCategoryRailLayout({required this.width, required this.gap});
}

/// Width of the category rail on the wide (>= 1100px) menu. Shrinks a little
/// on the lower end of that band so the product grid gets more room.
double kioskWideCategoryRailWidth(double screenWidth) {
  if (screenWidth < 1280) return 120;
  if (screenWidth < 1600) return 140;
  return 156;
}

enum KioskBreakpoint { small, medium, large, xlarge }

/// Caps content at [maxWidth] (default: the kiosk artboard) and centers it, so
/// full-bleed screens don't stretch edge-to-edge on 2000px+ / 4K displays.
/// Below the cap this is a no-op — the child already fits — so screens narrower
/// than [maxWidth] render identically to before.
class KioskCenteredContent extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const KioskCenteredContent({
    super.key,
    required this.child,
    this.maxWidth = KioskResponsive.designWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
