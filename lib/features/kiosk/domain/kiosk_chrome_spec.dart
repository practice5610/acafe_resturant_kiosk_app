import 'dart:math' as math;

import 'package:acafe_customer/common/responsive/kiosk_responsive.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_customize_spec.dart';
import 'package:flutter/widgets.dart';

/// The kiosk's shared screen CHROME: the circular back button and the bottom
/// action bar. Every value is an artboard px (2572-wide Figma) read off the
/// /menu-kiosk customize screen, which is the reference, and is multiplied by
/// ONE chrome scale (see [kioskChromeScale]), derived from the `/menu-kiosk`
/// customize scale, so the chrome is the same size in logical pixels on every
/// screen at the same viewport and never larger than `/menu-kiosk` draws it.
///
/// Screen CONTENT keeps its own scale; only chrome is unified. This file is
/// the single place these numbers live. A screen that needs a different back
/// button or bar is a bug in the screen, not a reason to add an override here.
class KioskChromeSpec {
  KioskChromeSpec._();

  // -- back button (Figma `Group 97`) --------------------------------------
  //
  // 100 / 4 / 50: the same diameter, outline and arrow as the step-indicator
  // circles that sit beside it on the checkout screens.
  static const double backDiameter = 100;
  static const double backBorder = 4;
  static const double backIcon = 50;

  /// The back button is this much larger on a portrait screen (all three of
  /// diameter, outline and arrow scale together). Landscape stays at 1.
  static const double backPortraitFactor = 1.1;

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

/// Artboard height the chrome scale is measured against: ONE fixed constant,
/// never a per-product value, so the chrome is the same size on every screen at
/// a given viewport.
///
/// HOW IT WAS CHOSEN. `/menu-kiosk` (Version B) is the reference: its back
/// button and action bar are `141 * s` and `252 * s` with
/// `s = kioskCustomizeScale(viewport, <the product's tallest step>)`. The
/// reference product is a normal two-step one (Iced Earl Grey Matcha: an
/// "Alternative Milk" panel and a "Cup or Can" panel, with a description), whose
/// tallest step is Cup or Can:
///
///   kioskCustomizeArtboardHeight(description, 1 vessel)   2938.44
///   + back-button top inset (93) + progress bar (227)
///   + "Your Choices" row (271)                              591.00
///   ------------------------------------------------------------
///                                                          3529.44
///
/// `kiosk_chrome_test.dart` recomputes that sum from the spec and fails if this
/// constant drifts from it. A smaller height would make the reference scale
/// larger (a weaker cap); a larger one would shrink the reference below what
/// `/menu-kiosk` renders (800x1280 is the tightest portrait case, 4115). 3529.44
/// leaves every tested portrait viewport width-bound, so the reference scale is
/// exactly `/menu-kiosk`'s.
const double kKioskChromeReferenceArtboardHeight = 3529.44;

/// The largest chrome scale any screen may use at [viewport]: the
/// `/menu-kiosk` customize scale for the fixed reference artboard.
double referenceChromeScale(Size viewport) => kioskCustomizeScale(
      viewport: viewport,
      artboardHeight: kKioskChromeReferenceArtboardHeight,
    );

/// The chrome scale for a screen: the reference scale, capped by the screen's
/// own page scale.
///
/// The cap is universal. It exists purely as a safety net: a page that is
/// height-budgeted (Version A and B customize size themselves to the product)
/// keeps its own smaller chrome, so it can never be pushed past the viewport.
/// Nothing can exceed [referenceChromeScale].
double kioskChromeScale(Size viewport, double pageScale) =>
    math.min(referenceChromeScale(viewport), pageScale);

/// Context-aware lookups, so a screen never rebuilds the viewport by hand.
///
/// Inside `KioskShell` the `MediaQuery` size IS the shell's viewport (the
/// capped content box x the window height), which is exactly what
/// [KioskMetrics.scale] was resolved from.
class KioskChrome {
  KioskChrome._();

  /// 1.1 on a portrait screen, 1.0 on landscape: see
  /// [KioskChromeSpec.backPortraitFactor]. Portrait is `width < height`, the
  /// same test [KioskMetrics] uses.
  static double backFactorOf(BuildContext context) {
    final KioskMetrics? metrics = KioskMetrics.maybeOf(context);
    final Size viewport = metrics?.viewport ?? MediaQuery.sizeOf(context);
    return viewport.width < viewport.height
        ? KioskChromeSpec.backPortraitFactor
        : 1.0;
  }

  /// Chrome scale for the screen under [context]. [pageScale] is the screen's
  /// own content scale; omitted, it is the shell's width-based scale
  /// ([KioskMetrics.scale], i.e. `KioskResponsive.scale`), which is what the
  /// cart, coupon, checkout and confirm screens lay their content out with.
  static double scaleOf(BuildContext context, [double? pageScale]) {
    final KioskMetrics? metrics = KioskMetrics.maybeOf(context);
    final Size viewport = metrics?.viewport ?? MediaQuery.sizeOf(context);
    final double page = pageScale ??
        metrics?.scale ??
        KioskResponsive.scale(viewport.width, viewport.height);
    return kioskChromeScale(viewport, page);
  }
}
