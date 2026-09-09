import 'dart:math' as math;

import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:flutter/widgets.dart';

/// Single source of truth for POS responsive scaling.
///
/// Deliberately *not* the kiosk's model. The kiosk multiplies every value from
/// a 2572px Figma artboard by one scale factor, which works because a kiosk is
/// one known piece of hardware in one orientation. A counter terminal is not:
/// it is landscape first, but the same build has to stay usable on a smaller
/// staff tablet and on whatever browser window someone opens it in.
///
/// So POS splits the two jobs the kiosk conflates:
///
///  * **Structure** is chosen by [PosBand] / [PosMetrics.showsSideReceipt] and
///    expressed with Flex, so a narrow window drops the receipt side panel
///    rather than shrinking every pane toward illegibility.
///  * **Density** is tuned by [PosMetrics.scale], a *bounded* fit factor
///    applied to type and spacing tokens only.
///
/// That is what "degrades sensibly" means here, as opposed to uniform shrink.
class PosResponsive {
  PosResponsive._();

  /// Reference landscape artboard for the counter terminal. Type and spacing
  /// tokens in `pos_ui.dart` are authored against this.
  ///
  /// Revisit once the POS Figma frames are available — if the design is
  /// authored at another size, change these two numbers and every token
  /// rescales with them.
  static const double designWidth = 1920;
  static const double designHeight = 1080;

  /// Scale clamp. Unlike the kiosk this is bounded on *both* sides well away
  /// from zero: POS is a working tool read at arm's length by staff under time
  /// pressure, so type has a floor even when the window does not deserve one.
  static const double minScale = 0.68;
  static const double maxScale = 1.30;

  /// Below this width there is not enough room for a product pane and a
  /// receipt pane side by side, whatever the scale.
  static const double compactMax = 900;

  /// Genuine large-format counter displays and 4K browser windows.
  static const double largeMin = 2200;

  /// Structural floor for the desktop 3-pane composition (sidebar + products
  /// + receipt): at/above this width the layout is decided by width alone —
  /// never by height, and never by portrait vs landscape. A 1200px-wide
  /// monitor turned portrait is still plainly a desktop window with room for
  /// three panes; it is not a tablet, and treating it as one was the "jumps
  /// to compact on rotate" bug this floor exists to close.
  ///
  /// Below this width, [PosBand.compact]'s bottom-bar/sheet behaviour and the
  /// existing orientation gate on the standard band are both untouched — see
  /// [PosMetrics.showsSideReceipt].
  static const double desktopFloor = 1024;

  /// The 1366×1024 Figma home frame's pane ratio (`192 : 753 : 421`,
  /// [PosHomeSpec.sidebarWidth] : centre : [PosHomeSpec.receiptWidth]).
  /// [sidebarWidth] and [receiptWidth] scale the two side panes by this ratio
  /// at/above [desktopFloor] so resizing between 1024 and 2199px moves the
  /// panes continuously instead of holding them at a literal 192/421 design
  /// pixels while only the centre pane absorbs the change.
  static const double _refWidth = 1366;
  static const double _sidebarRatio = PosHomeSpec.sidebarWidth / _refWidth;
  static const double _receiptRatio = PosHomeSpec.receiptWidth / _refWidth;

  /// Sidebar pane width for a window of [width].
  ///
  /// Below [desktopFloor] this is [PosHomeSpec.sidebarWidth] exactly, as it
  /// always has been — untouched, per the floor's own contract. At/above it,
  /// a continuous proportion of the window.
  static double sidebarWidth(double width) => width >= desktopFloor
      ? width * _sidebarRatio
      : PosHomeSpec.sidebarWidth;

  /// Receipt pane width for a window of [width] — the one policy shared by
  /// Customize and Payment (both already used [receiptPanelWidth]'s 30%
  /// clamp below the desktop floor; this makes that same rule continuous
  /// above it too, instead of jumping to a discrete flex ratio).
  ///
  /// Home is deliberately **not** wired to call this below [desktopFloor]:
  /// its legacy there is a flat [PosHomeSpec.receiptWidth], not the 30%
  /// clamp, so unifying the three screens below the floor would itself be a
  /// behaviour change in the one place the floor's contract forbids one.
  /// `pos_home_cart_screen.dart` therefore branches at its own call site —
  /// [PosHomeSpec.receiptWidth] below the floor, this function's ratio above
  /// it — so this method only ever needs to answer for width ≥ [desktopFloor]
  /// there, which is exactly where its ratio and Customize/Payment's clamp
  /// already agree in spirit (both are "the receipt gets its Figma share").
  static double receiptWidth(double width) => width >= desktopFloor
      ? width * _receiptRatio
      : receiptPanelWidth(width);

  /// Fit factor for [width] x [height]. `min` of both axes, so a short
  /// landscape window (1366x768 laptops, the classic offender) reduces density
  /// instead of overflowing vertically.
  static double scale(double width, double height) {
    final double byWidth = width / designWidth;
    final double byHeight = height / designHeight;
    return math.min(byWidth, byHeight).clamp(minScale, maxScale);
  }

  /// Width of the purchase-receipt side panel for a window of [width].
  ///
  /// Grows with the window but is bounded at both ends: a receipt narrower
  /// than [receiptMin] truncates item names, and one wider than [receiptMax]
  /// steals room the product grid uses better.
  static const double receiptMin = 340;
  static const double receiptMax = 560;
  static const double receiptFraction = 0.30;

  static double receiptPanelWidth(double width) =>
      (width * receiptFraction).clamp(receiptMin, receiptMax);
}

/// Width buckets. Structure, not density.
enum PosBand {
  /// Single pane. Receipt is reachable as a sheet rather than pinned open.
  compact,

  /// The design target: product pane + pinned receipt panel.
  standard,

  /// Large-format counter display; same structure as [standard] with more air.
  large,
}

/// Resolved POS layout for the current window. Published by [PosShell] and
/// read through [PosMetrics.of] / [PosMetrics.maybeOf].
@immutable
class PosMetrics {
  final double scale;
  final Orientation orientation;
  final PosBand band;
  final Size window;

  const PosMetrics({
    required this.scale,
    required this.orientation,
    required this.band,
    required this.window,
  });

  bool get isLandscape => orientation == Orientation.landscape;
  bool get isPortrait => orientation == Orientation.portrait;
  bool get isCompact => band == PosBand.compact;

  /// Whether the purchase receipt is pinned open beside the content.
  ///
  /// At/above [PosResponsive.desktopFloor] this is a pure width decision —
  /// orientation never overrides it, so a desktop monitor turned portrait
  /// keeps the full 3-pane layout instead of dropping to the compact bottom
  /// bar. Below the floor, the original rule stands: landscape *and* room,
  /// since a 900px-wide tablet held portrait is wide enough by the number
  /// alone but splitting it leaves two unusable columns.
  bool get showsSideReceipt =>
      band != PosBand.compact &&
      (window.width >= PosResponsive.desktopFloor || isLandscape);

  double get receiptPanelWidth =>
      PosResponsive.receiptPanelWidth(window.width);

  /// Figma-authored value -> logical pixels.
  double px(double designPx) => designPx * scale;

  static PosMetrics resolve(Size window) {
    final Orientation orientation = window.width >= window.height
        ? Orientation.landscape
        : Orientation.portrait;

    final PosBand band;
    if (window.width < PosResponsive.compactMax) {
      band = PosBand.compact;
    } else if (window.width < PosResponsive.largeMin) {
      band = PosBand.standard;
    } else {
      band = PosBand.large;
    }

    return PosMetrics(
      scale: PosResponsive.scale(window.width, window.height),
      orientation: orientation,
      band: band,
      window: window,
    );
  }

  static PosMetrics of(BuildContext context) {
    final PosMetricsScope? scope =
        context.dependOnInheritedWidgetOfExactType<PosMetricsScope>();
    assert(scope != null, 'PosMetrics.of() called outside PosShell');
    return scope!.metrics;
  }

  static PosMetrics? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PosMetricsScope>()?.metrics;

  @override
  bool operator ==(Object other) =>
      other is PosMetrics &&
      other.scale == scale &&
      other.orientation == orientation &&
      other.band == band &&
      other.window == window;

  @override
  int get hashCode => Object.hash(scale, orientation, band, window);
}

class PosMetricsScope extends InheritedWidget {
  final PosMetrics metrics;

  const PosMetricsScope({
    super.key,
    required this.metrics,
    required super.child,
  });

  @override
  bool updateShouldNotify(PosMetricsScope oldWidget) =>
      oldWidget.metrics != metrics;
}
