import 'dart:math' as math;

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
/// Width and orientation are independent: [KioskMetrics.band] / [scale] answer
/// "how much physical room", and [KioskMetrics.orientation] chooses portrait
/// vs landscape composition. Nothing here keys off a 1100px "is this a tablet"
/// seam — that is the wrong question for a kiosk.
class KioskResponsive {
  KioskResponsive._();

  /// Figma artboard width every kiosk screen is designed against.
  static const double designWidth = 2572;

  /// Form screens (login, language picker, PIN) are authored against a
  /// narrower 1000px column. That column is the floor; on large kiosks it
  /// grows — see [formContentWidth].
  static const double formDesignWidth = 1000;

  /// Width at which the form column starts growing past [formDesignWidth].
  /// Sits clear of the 1080 production kiosk so that device stays 1.0.
  static const double formGrowFrom = 1400;

  /// Maximum form column on a large-format panel.
  static const double formMaxWidth = 1800;

  /// Scale clamp. Below [minScale] chrome/typography become illegible on small
  /// tablets; above [maxScale] elements would inflate on ultra-wide/4K displays
  /// — instead content is capped at [designWidth] and centered.
  static const double minScale = 0.24;
  static const double maxScale = 1.0;

  /// Menu type is smaller than the Figma artboard so it matches the reduced
  /// customize / add-on screens. Layout (gaps, cards, bars) is unchanged.
  static const double menuTypeScale = 0.6;

  /// Compact band: below this, portrait single-column. Must sit clear of 1080
  /// so the production device is never near a seam.
  static const double compactMax = 900;

  /// Large band: genuine large-format panels. 1440/1600 laptops stay in
  /// [KioskBand.standard] with the production kiosk.
  static const double largeMin = 1800;

  /// Minimum readable product-card width, in logical pixels. Column count is
  /// derived from how many of these fit the measured product area.
  static const double minProductCard = 240;

  static const int minProductColumns = 3;
  static const int maxProductColumns = 6;

  /// Figma artboard height of a 16:9 landscape panel at `s = 1.0` (3840×2160
  /// with the 2572 cap). Portrait ignores this and stays width-only so the
  /// 1080×1920 kiosk is unchanged.
  static const double landscapeDesignHeight = 2160;

  /// Figma artboard px → logical px for a screen/area of the given [width]
  /// (clamped). This is the one true scale function for the kiosk flow.
  ///
  /// In portrait, only [width] matters — matching `s = width / 2572`.
  /// In landscape, [height] also participates: a 14" MacBook is wide enough
  /// that width-only scale inflates the header and cart bar until the product
  /// grid is clipped. Fit is `min(width/2572, height/2160)`.
  static double scale(double width, [double? height]) {
    final double byWidth = (width / designWidth).clamp(minScale, maxScale);
    if (height == null || height >= width) return byWidth;
    final double byHeight =
        (height / landscapeDesignHeight).clamp(minScale, maxScale);
    return math.min(byWidth, byHeight);
  }

  /// Width of the form column for a window of [width]. Unchanged at/below
  /// [formGrowFrom] (so the 1080 production kiosk stays a 1000px column at
  /// scale 1.0); grows toward [formMaxWidth] on large displays.
  static double formContentWidth(double width) {
    if (width <= formGrowFrom) {
      return math.min(width, formDesignWidth);
    }
    final double t =
        ((width - formGrowFrom) / (formMaxWidth - formGrowFrom)).clamp(0.0, 1.0);
    return formDesignWidth + t * (formMaxWidth - formDesignWidth);
  }

  /// Scale for the form artboard. At/below 1080 this is exactly 1.0 once the
  /// column has reached [formDesignWidth], matching the previous freeze.
  static double formScale(double width) =>
      formContentWidth(width) / formDesignWidth;

  /// Category rail on the 2572px artboard. 524px made the rail as wide as a
  /// product card once the artboard was scaled onto a tablet; 390px still
  /// fits labels like MERCHANDISE after scaling.
  static const double categoryRailDesignWidth = 390;

  /// Gap between the category rail and the product grid (Figma was 104px).
  static const double categoryRailDesignGap = 56;

  /// Rail must not take more than this share of the inner menu row.
  static const double categoryRailMaxFraction = 0.24;
}

/// Max width the app content is centered within on large displays. The
/// artboard width is the honest ceiling — `s = 1.0` there. Below this the cap
/// never binds, so the production 1080×1920 kiosk is unaffected.
const double kKioskContentMaxWidth = KioskResponsive.designWidth;

/// Size band. Orientation is a separate axis on [KioskMetrics].
enum KioskBand { compact, standard, large }

/// Resolved once at the shell and passed down. Screens should read layout
/// width from here rather than mixing [MediaQuery.size] and [LayoutBuilder].
class KioskMetrics {
  final double scale;
  final Orientation orientation;
  final KioskBand band;
  final double contentWidth;
  final Size viewport;
  final Size window;
  final bool fullBleed;

  const KioskMetrics({
    required this.scale,
    required this.orientation,
    required this.band,
    required this.contentWidth,
    required this.viewport,
    required this.window,
    this.fullBleed = false,
  });

  bool get isLandscape => orientation == Orientation.landscape;
  bool get isPortrait => orientation == Orientation.portrait;

  static KioskMetrics resolve(Size window, {bool fullBleed = false}) {
    final Orientation orientation = window.width >= window.height
        ? Orientation.landscape
        : Orientation.portrait;
    final double contentWidth = fullBleed
        ? window.width
        : math.min(window.width, KioskResponsive.designWidth);
    final KioskBand band;
    if (contentWidth < KioskResponsive.compactMax) {
      band = KioskBand.compact;
    } else if (contentWidth < KioskResponsive.largeMin) {
      band = KioskBand.standard;
    } else {
      band = KioskBand.large;
    }
    return KioskMetrics(
      scale: KioskResponsive.scale(contentWidth, window.height),
      orientation: orientation,
      band: band,
      contentWidth: contentWidth,
      viewport: Size(contentWidth, window.height),
      window: window,
      fullBleed: fullBleed,
    );
  }

  static KioskMetrics of(BuildContext context) {
    final KioskMetricsScope? scope =
        context.dependOnInheritedWidgetOfExactType<KioskMetricsScope>();
    assert(scope != null, 'KioskMetrics.of() called outside KioskShell');
    return scope!.metrics;
  }

  static KioskMetrics? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<KioskMetricsScope>()?.metrics;

  @override
  bool operator ==(Object other) =>
      other is KioskMetrics &&
      other.scale == scale &&
      other.orientation == orientation &&
      other.band == band &&
      other.contentWidth == contentWidth &&
      other.viewport == viewport &&
      other.window == window &&
      other.fullBleed == fullBleed;

  @override
  int get hashCode => Object.hash(
        scale,
        orientation,
        band,
        contentWidth,
        viewport,
        window,
        fullBleed,
      );
}

class KioskMetricsScope extends InheritedWidget {
  final KioskMetrics metrics;

  const KioskMetricsScope({
    super.key,
    required this.metrics,
    required super.child,
  });

  @override
  bool updateShouldNotify(KioskMetricsScope oldWidget) =>
      metrics != oldWidget.metrics;
}

/// Product-grid column count keyed to the *measured* product-area width.
///
/// `columns = clamp(floor((areaW + gap) / (minCard + gap)), 3, 6)` — drops a
/// column only when a card would fall below [minCard], and always fills the
/// row. At the 1080 production kiosk this resolves to 3, matching the Figma
/// composition.
int kioskProductGridColumns({
  required double areaWidth,
  required double gap,
  double minCard = KioskResponsive.minProductCard,
  int minColumns = KioskResponsive.minProductColumns,
  int maxColumns = KioskResponsive.maxProductColumns,
}) {
  if (areaWidth <= 0) return minColumns;
  final int fitted = ((areaWidth + gap) / (minCard + gap)).floor();
  return fitted.clamp(minColumns, maxColumns);
}

/// Resolved product-grid geometry. Card height follows the portrait 0.72
/// image aspect plus a text block proportional to tile width, so the card
/// keeps its proportions at any column count.
class KioskProductGridGeometry {
  final int columns;
  final double gap;
  final double tileWidth;
  final double imageHeight;
  final double textBlockHeight;
  final double tileHeight;

  const KioskProductGridGeometry({
    required this.columns,
    required this.gap,
    required this.tileWidth,
    required this.imageHeight,
    required this.textBlockHeight,
    required this.tileHeight,
  });

  factory KioskProductGridGeometry.resolve({
    required double areaWidth,
    required double gap,
    bool landscape = false,
    double minCard = KioskResponsive.minProductCard,
    int minColumns = KioskResponsive.minProductColumns,
    int maxColumns = KioskResponsive.maxProductColumns,
  }) {
    final int columns = kioskProductGridColumns(
      areaWidth: areaWidth,
      gap: gap,
      minCard: minCard,
      minColumns: minColumns,
      maxColumns: maxColumns,
    );
    final double tileWidth =
        columns <= 0 ? areaWidth : (areaWidth - gap * (columns - 1)) / columns;
    // Portrait Figma: image is taller than wide (width/height = 0.72).
    // Landscape: square image so a row of cards fits a 16:9 window.
    final double imageHeight = landscape ? tileWidth : tileWidth / 0.72;
    final double textBlockHeight = landscape ? tileWidth * 0.28 : tileWidth * 0.34;
    return KioskProductGridGeometry(
      columns: columns,
      gap: gap,
      tileWidth: tileWidth,
      imageHeight: imageHeight,
      textBlockHeight: textBlockHeight,
      tileHeight: imageHeight + textBlockHeight,
    );
  }
}

/// Width + gap for the kiosk category rail.
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
