import 'dart:math' as math;

import 'package:acafe_customer/common/responsive/kiosk_responsive.dart';
import 'package:flutter/widgets.dart';

/// The kiosk's shared screen CHROME: the circular back button and the bottom
/// action bar. Every value is an artboard px (2572-wide Figma) read off the
/// /menu-kiosk customize screen, which is the reference, and is multiplied by
/// ONE chrome scale (see [kioskChromeScale]) so the chrome is the same size in
/// logical pixels on every screen at the same viewport.
///
/// Screen CONTENT keeps its own scale; only chrome is unified. This file is
/// the single place these numbers live. A screen that needs a different back
/// button or bar is a bug in the screen, not a reason to add an override here.
class KioskChromeSpec {
  KioskChromeSpec._();

  // -- back button (Figma `Group 97`) --------------------------------------
  static const double backDiameter = 141;
  static const double backBorder = 5;
  static const double backIcon = 55;

  /// Inset from the left edge of the screen's content column, and from its top.
  static const double insetLeft = 86;
  static const double insetTop = 93;

  /// Fixed gap between the back button and the content beside it (a step
  /// indicator, a title row). Same 48 the step-flow progress bar uses.
  static const double backToContentGap = 48;

  // -- bottom action bar (Figma `btn-skip` / `btn-next`) --------------------
  static const double barHeight = 252;
  static const double barFontSize = 72;
  static const double barRadius = 30;
  static const double barBorder = 8;
  static const double barBorderMin = 2;
  static const double barBorderMax = 10;
  static const double barGap = 22;
  static const double barInsetHorizontal = 86;
  static const double barTopGap = 72;
  static const double barBottomGap = 87;

  /// Whole bar, top gap to bottom gap, at scale 1.
  static const double barBlock = barTopGap + barHeight + barBottomGap;

  /// Outline width of an unfilled bar button at chrome scale [s].
  static double barBorderWidth(double s) =>
      (barBorder * s).clamp(barBorderMin, barBorderMax).toDouble();

  /// Back-button outline at chrome scale [s]. Hairlines cannot render below one
  /// logical pixel, so this never falls under 1.
  static double backBorderWidth(double s) => math.max(1.0, backBorder * s);
}

/// The chrome scale for a viewport: the kiosk's one true scale function,
/// `KioskResponsive.scale`, clamped 0.24–1.0.
///
/// Cart, coupon, checkout name / email, order summary and Version B customize
/// use this FLAT, with no `min()` and no exception.
double kioskChromeScale(Size viewport) =>
    KioskResponsive.scale(viewport.width, viewport.height);

// Version A customize is the ONE exception, and it is deliberate - do not
// "clean it up" into [kioskChromeScale].
//
// Version A is a single page whose whole content is fitted into the viewport
// HEIGHT: its page scale `s` is chosen so that the header, every panel AND an
// action bar budgeted at `252 * s` add up to exactly the screen. For a tall
// product (several variation panels plus add-ons) that `s` is well below the
// unified scale (0.3466 against 0.4199 at 1080x1920), and a bar drawn at the
// unified scale would be taller than the budget the page was fitted to, so it
// would push the page past the viewport. Taking the minimum keeps exactly
// today's chrome wherever the page is height-budgeted and adopts the unified
// chrome wherever it has headroom. Because it is a `min`, Version A chrome can
// never be LARGER than it is today: that is structural, not measured.
//
// The proper fix (let Version A scroll so its bar can stay pinned at the
// unified size) changes the pinned-layout design and is a separate pass.
double kioskChromeScaleVersionA(Size viewport, double pageScale) =>
    math.min(kioskChromeScale(viewport), pageScale);

/// Context-aware lookups, so a screen never rebuilds the viewport by hand.
///
/// Inside `KioskShell` the `MediaQuery` size IS the shell's viewport (the
/// capped content box x the window height), which is exactly what
/// [KioskMetrics.scale] was resolved from.
class KioskChrome {
  KioskChrome._();

  static double scaleOf(BuildContext context) {
    final KioskMetrics? metrics = KioskMetrics.maybeOf(context);
    if (metrics != null) return kioskChromeScale(metrics.viewport);
    return kioskChromeScale(MediaQuery.sizeOf(context));
  }

  /// Version A only. See the comment above [kioskChromeScaleVersionA].
  static double scaleOfVersionA(BuildContext context, double pageScale) {
    final KioskMetrics? metrics = KioskMetrics.maybeOf(context);
    final Size viewport = metrics?.viewport ?? MediaQuery.sizeOf(context);
    return kioskChromeScaleVersionA(viewport, pageScale);
  }
}
