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

  /// A stacked kiosk screen — cart, order summary, checkout form — centres
  /// its content in one reading column on a landscape window. Full width there
  /// is a line card with a thumbnail at one end and a stepper at the other,
  /// with a metre of empty beige between them.
  static const double readingColumnFraction = 0.62;
  static const double readingColumnMin = 720;
  static const double readingColumnMax = 1600;

  /// Type reduction for the customize / add-on choice-card labels, whose
  /// Figma sizes overflow the card at real kiosk widths. The menu screen is
  /// deliberately NOT scaled by this — it renders type at full artboard size.
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

  // ── Promotional deal banner ────────────────────────────────────────────
  //
  // The banner used to be a fixed `760 * scale` tall box at the full width of
  // the product area, with the artwork `BoxFit.cover`-ed into it. That box's
  // aspect ratio has nothing to do with the artwork's: width tracks the grid
  // (which depends on window width, rail width and column count) while height
  // tracks `scale` (which in landscape is also bounded by window HEIGHT). The
  // two drift apart, so the same banner was side-cropped on a narrow window
  // and top-and-bottom-cropped on a wide one. Sizing the slot from the
  // image's own ratio is what makes it correct at every size.

  /// Ratio used before the artwork's real one is known, so the first frame
  /// reserves about the right amount of room and the grid does not jump.
  /// Matches the 2400×1000 house banner.
  static const double dealBannerDefaultAspect = 2.4;

  /// Aspect bounds for the slot. A near-square upload would otherwise take
  /// over the page, and a letterbox strip would vanish; outside these bounds
  /// the artwork is cover-cropped rather than allowed to dictate the layout.
  static const double dealBannerMinAspect = 1.6;
  static const double dealBannerMaxAspect = 4.0;

  /// On a large-format panel the banner stops at half the window. Full grid
  /// width there reads as a stretched billboard; half reads as a feature card
  /// sitting deliberately between two rows of products.
  static const double dealBannerLargeWidthFraction = 0.5;

  /// The banner never takes more than this share of the window's HEIGHT.
  /// Width alone is not enough on a short landscape window (a 1366×768
  /// laptop): a full-width 2.4:1 banner there is over half the viewport, so
  /// the products it is meant to sit between scroll out of sight.
  static const double dealBannerMaxHeightFraction = 0.42;
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

/// Size of the promotional deal banner slot.
///
/// Two rules, in this order:
///
///  1. **Width.** The banner fills the product area, except on a large-format
///     panel ([KioskResponsive.largeMin] and up) where it stops at
///     [KioskResponsive.dealBannerLargeWidthFraction] of the window. The cap
///     is measured against the WINDOW, not the product area, because that is
///     what "half the screen" means to someone looking at the kiosk.
///
///  2. **Height.** Derived from the artwork's own aspect ratio, so the slot
///     and the image agree and there is nothing to crop or stretch. Until the
///     ratio is known [KioskResponsive.dealBannerDefaultAspect] stands in.
///
/// Both inputs are guarded: a zero or negative width (which a [LayoutBuilder]
/// can hand out for one frame during a resize) yields a zero-size slot rather
/// than an infinity that would throw in the render tree.
class KioskDealBannerGeometry {
  /// Laid-out width of the banner, in logical pixels.
  final double width;

  /// Laid-out height, always [width] / [aspect].
  final double height;

  /// The ratio actually used, after clamping.
  final double aspect;

  /// Whether the half-window cap bound (i.e. the banner is narrower than the
  /// product area). Exposed so the caller can centre it.
  final bool capped;

  const KioskDealBannerGeometry({
    required this.width,
    required this.height,
    required this.aspect,
    required this.capped,
  });

  factory KioskDealBannerGeometry.resolve({
    required double areaWidth,
    required double windowWidth,
    double windowHeight = double.infinity,
    double? imageAspect,
  }) {
    final double aspect = _clampAspect(imageAspect);

    if (!areaWidth.isFinite || areaWidth <= 0) {
      return KioskDealBannerGeometry(
        width: 0,
        height: 0,
        aspect: aspect,
        capped: false,
      );
    }

    double width = areaWidth;
    bool capped = false;

    // Width cap: half the window on a large-format panel.
    if (windowWidth.isFinite && windowWidth >= KioskResponsive.largeMin) {
      final double half =
          windowWidth * KioskResponsive.dealBannerLargeWidthFraction;
      if (half < width) {
        width = half;
        capped = true;
      }
    }

    double height = width / aspect;

    // Height cap: shrink the whole card, keeping its ratio, rather than
    // squashing it. This is what keeps a short landscape window from handing
    // the banner more than its share of the viewport.
    if (windowHeight.isFinite && windowHeight > 0) {
      final double maxHeight =
          windowHeight * KioskResponsive.dealBannerMaxHeightFraction;
      if (height > maxHeight) {
        height = maxHeight;
        width = maxHeight * aspect;
        capped = true;
      }
    }

    return KioskDealBannerGeometry(
      width: width,
      height: height,
      aspect: aspect,
      capped: capped,
    );
  }

  /// The shared slot for a carousel of banners, so paging between artwork of
  /// different shapes never resizes the grid underneath.
  ///
  /// Every card is laid out at ONE width — the narrowest any of them is
  /// allowed (a tall banner hits the height cap sooner, so it is the one that
  /// sets the common width). The slot is then that width at the TALLEST
  /// artwork's ratio, which is exactly the room the tallest card needs and
  /// more than every other card needs, so each one centres inside it.
  ///
  /// Taking the tallest *geometry* instead would be wrong: once two banners
  /// are both height-capped they are equally tall but not equally wide, and
  /// picking either one's width hands the other a card wider than its page.
  static KioskDealBannerGeometry forAll({
    required double areaWidth,
    required double windowWidth,
    double windowHeight = double.infinity,
    required Iterable<double?> imageAspects,
  }) {
    double? sharedWidth;
    double? minAspect;

    for (final aspect in imageAspects) {
      final geo = KioskDealBannerGeometry.resolve(
        areaWidth: areaWidth,
        windowWidth: windowWidth,
        windowHeight: windowHeight,
        imageAspect: aspect,
      );
      if (sharedWidth == null || geo.width < sharedWidth) {
        sharedWidth = geo.width;
      }
      if (minAspect == null || geo.aspect < minAspect) minAspect = geo.aspect;
    }

    if (sharedWidth == null || minAspect == null) {
      return KioskDealBannerGeometry.resolve(
        areaWidth: areaWidth,
        windowWidth: windowWidth,
        windowHeight: windowHeight,
      );
    }

    return KioskDealBannerGeometry(
      width: sharedWidth,
      height: sharedWidth <= 0 ? 0 : sharedWidth / minAspect,
      aspect: minAspect,
      capped: sharedWidth < areaWidth,
    );
  }

  static double _clampAspect(double? aspect) {
    if (aspect == null || !aspect.isFinite || aspect <= 0) {
      return KioskResponsive.dealBannerDefaultAspect;
    }
    return kioskBounded(
      aspect,
      min: KioskResponsive.dealBannerMinAspect,
      max: KioskResponsive.dealBannerMaxAspect,
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

/// Safe clamp. Flutter's `num.clamp` throws when [min] > [max] (common when
/// a fixed floor meets a screen-relative ceiling on medium tablets). Prefer
/// the ceiling so layout still paints instead of the grey ErrorWidget.
double kioskBounded(double value, {required double min, required double max}) {
  if (max <= min) return max;
  return value.clamp(min, max);
}

/// [clamp] throws when min > max (tiny inner rows). Prefer the cap.
double _bounded(double value, {required double min, required double max}) =>
    kioskBounded(value, min: min, max: max);

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

/// Width of the centred reading column for a window of [width]. Portrait
/// keeps the full width — there the artboard already *is* the column.
double kioskReadingColumnWidth({
  required double width,
  required bool landscape,
}) {
  if (!landscape) return width;
  // 62% of a medium landscape window can sit below the 720 floor, so this is
  // bounded rather than clamped: the column shrinks instead of throwing.
  return kioskBounded(
    width * KioskResponsive.readingColumnFraction,
    min: math.min(KioskResponsive.readingColumnMin, width),
    max: math.min(KioskResponsive.readingColumnMax, width),
  );
}

/// Horizontal insets that put a stacked screen's content on that column.
///
/// [left] / [right] are measured inside the centred artboard band, where the
/// header and the scrolling body live. [pageLeft] / [pageRight] are the same
/// column measured from the screen edge, for a full-bleed bar whose contents
/// still have to line up with the body above it.
///
/// Portrait passes through the screen's own Figma gutters untouched, so the
/// production 1080×1920 kiosk resolves to exactly the artboard numbers.
class KioskReadingInsets {
  final double left;
  final double right;
  final double pageLeft;
  final double pageRight;

  const KioskReadingInsets({
    required this.left,
    required this.right,
    required this.pageLeft,
    required this.pageRight,
  });

  factory KioskReadingInsets.resolve({
    required double width,
    required double band,
    required bool landscape,
    required double portraitLeft,
    required double portraitRight,
    required double minGutter,
  }) {
    final double bleed = math.max((width - band) / 2, 0);
    double left = portraitLeft;
    double right = portraitRight;
    if (landscape) {
      final double column =
          kioskReadingColumnWidth(width: band, landscape: true);
      final double side = math.max((band - column) / 2, minGutter);
      left = side;
      right = side;
    }
    return KioskReadingInsets(
      left: left,
      right: right,
      pageLeft: bleed + left,
      pageRight: bleed + right,
    );
  }

  /// Insets for content inside the centred band.
  EdgeInsets padded({double top = 0, double bottom = 0}) =>
      EdgeInsets.fromLTRB(left, top, right, bottom);

  /// Insets for a full-bleed bar, landing on the same column as [padded].
  EdgeInsets pagePadded({double top = 0, double bottom = 0}) =>
      EdgeInsets.fromLTRB(pageLeft, top, pageRight, bottom);
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
