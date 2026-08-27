import 'dart:math' as math;
import 'dart:ui' show Size;

/// Design tokens and the responsive rule for the kiosk product-customize
/// screen, read straight off Figma `02a – Menu Browse (Full Page)`
/// (file `egyp8Y2o5BtoJLo8SrcWrX`, node `1385:13510`) — a 2572x5400 portrait
/// artboard.
///
/// Every number below is an ARTBOARD pixel. The screen multiplies them by one
/// scale `s` and nothing else: there are deliberately no per-element floors or
/// ceilings, because those are what pulled the old screen out of proportion —
/// a 16px minimum on a heading the design draws at 72 artboard px means the
/// heading stops shrinking while the panel around it keeps going, and the UI
/// reads as oversized even though the "scale" looks small. The only bounded
/// value is [kioskCustomizeScale] itself, plus hairline borders (see
/// [borderFloor]) which cannot render below one device pixel anyway.
class KioskCustomizeSpec {
  KioskCustomizeSpec._();

  /// The artboard the whole screen is measured against.
  static const double artboardWidth = 2572;
  static const double artboardHeight = 5400;

  // -- screen chrome -------------------------------------------------------
  /// Left/right page gutter (`Group 90` at x=86).
  static const double gutter = 86;

  /// Back button `Group 97`: 141x141 at (86, 93).
  static const double backButton = 141;
  static const double backButtonTop = 93;
  static const double backButtonBorder = 5;
  static const double backButtonIcon = 55;

  // -- product header ------------------------------------------------------
  /// Top of the hero photo box. The back button overlaps it on the left, which
  /// is why the header is a Stack rather than a Column with a back row.
  static const double heroTop = 118;
  static const double heroWidth = 453;
  static const double heroHeight = 731;

  /// Hero -> `Iced Strawberry Latte` (node 1385:13605, y=932.8).
  static const double heroToTitle = 84;

  /// Loew / ExtraBold / 72 / line-height 100%.
  static const double titleSize = 72;

  /// Title -> description (node 1385:13604, y=1027).
  static const double titleToDescription = 22;

  /// Swiss 721 Light / 48, two lines at 1.2.
  static const double descriptionSize = 48;
  static const double descriptionLineHeight = 1.2;

  /// Description -> quantity stepper (`Group 95`, y=1177.3).
  static const double descriptionToStepper = 45;

  /// Stepper (`Group 95`): two 150x114 buttons around a 256.5-wide digit box.
  static const double stepperButtonWidth = 150;
  static const double stepperButtonHeight = 114;
  static const double stepperDigitWidth = 256.5;
  static const double stepperRadius = 15;
  static const double stepperBorder = 2.25;
  static const double stepperGlyphSize = 96;

  /// Stepper bottom (1291.3) -> first panel top (1378).
  static const double headerToPanels = 87;

  /// Header block height, from the frame top to the bottom of the stepper.
  static double headerHeight({required bool hasDescription}) =>
      heroTop +
      heroHeight +
      heroToTitle +
      // Two title lines are always budgeted: the design's name fits one, but a
      // real one ("Iced White Choco Cinnamon Matcha") wraps, and a header that
      // grows AFTER the scale is chosen is what overflows the pinned layout.
      titleSize * 2 +
      (hasDescription
          ? titleToDescription + descriptionSize * descriptionLineHeight * 2
          : 0) +
      descriptionToStepper +
      stepperButtonHeight;

  // -- section panels ------------------------------------------------------
  /// `Rectangle 62`: #FBF8EF, 1px #B9B5A6, 30px radius.
  static const double panelRadius = 30;
  static const double panelPadH = 96;
  static const double panelPadTop = 74;
  static const double panelPadBottom = 130;

  /// `Choose your dietary` / `Add add-ons` / `Can or cup?` — Loew ExtraBold 72.
  static const double panelTitleSize = 72;

  /// Title box (93.237 at line-height 100%) -> first card.
  static const double panelTitleGap = 84;

  /// Gap between two stacked panels.
  static const double panelGap = 46;

  /// Panel chrome: everything except the cards themselves.
  static const double panelChrome =
      panelPadTop + panelTitleSize * 1.295 + panelTitleGap + panelPadBottom;

  // -- variation cards (dietary / size) ------------------------------------
  /// `Group 98`..`Group 102`: 407.823 x 449.4, 45 apart.
  static const double optionCardWidth = 407.823;
  static const double optionCardHeight = 449.4;
  static const double optionCardGap = 45;
  static const double optionCardRadius = 31.5;
  static const double optionCardBorder = 3.15;
  static const double optionCardBorderSelected = 5.25;
  static const double optionPadTop = 50;
  static const double optionPadH = 24;
  static const double optionPadBottom = 46;
  static const double optionImageGap = 20;

  /// Loew Medium 45.36, uppercase, centred.
  static const double optionLabelSize = 45.36;
  static const double optionPriceSize = 36;

  /// `Ellipse 22`: 36px radio, inset 20 from the card's top-right.
  static const double optionRadio = 36;
  static const double optionRadioInset = 20;

  // -- add-on cards --------------------------------------------------------
  /// `AddOns Wrapper` children: 539 x 535, 20 apart, 20 padding round the grid.
  static const double addOnCardWidth = 539;
  static const double addOnCardHeight = 535;
  static const double addOnCardGap = 20;
  static const double addOnCardRadius = 31.5;
  static const double addOnCardBorder = 3.15;
  static const double addOnCardBorderSelected = 4;
  static const double addOnPadTop = 40;
  static const double addOnPadH = 24;
  static const double addOnPadBottom = 24;
  static const double addOnInnerGap = 16;
  static const double addOnImageRadius = 8;

  /// Loew Medium 45 at line-height 1.2 / Swiss 721 Light 36.
  static const double addOnNameSize = 45;
  static const double addOnPriceSize = 36;

  /// `qty-counter`: three 72px boxes, 12 apart, 15px radius, 56px glyphs.
  static const double addOnQtyButton = 72;
  static const double addOnQtyGap = 12;
  static const double addOnQtyRadius = 15;
  static const double addOnQtyGlyph = 56;

  /// `Rectangle 100` (thumb) over `Rectangle 101` (track).
  static const double scrollbarWidth = 20;
  static const double scrollbarRadius = 15;

  // -- shared choice cards (variations + add-ons) --------------------------
  /// Compact box used by size/dietary variation cards AND add-on cards so
  /// both rows are the same width and height. Smaller than the Figma
  /// `Group 98` / `card-shot-espresso` measurements above, which still
  /// drive [kioskCustomizeArtboardHeight] so shrinking the tiles cannot
  /// inflate the rest of the page.
  static const double choiceCardWidth = 320;
  static const double choiceCardHeight = 340;
  static const double choiceCardGap = 24;

  /// Max width/height edge for those tiles on compact windows (< 900px).
  /// A 2–3-up on a phone otherwise stretches Small/Addon1 across a third
  /// of the panel. Kiosk-sized viewports never use this cap.
  static const double choiceCardMaxEdgeCompact = 96;

  // -- cup / can -----------------------------------------------------------
  /// `cup` / `can`: 1099 x 790, 35 apart, 28px radius.
  static const double vesselCardWidth = 1099;
  static const double vesselCardHeight = 790;

  /// Visual height of cup/can cards as a fraction of the 1099×790 Figma
  /// ratio. Width still fills the panel; only the section shrinks.
  static const double vesselHeightFactor = 0.58;
  static const double vesselCardGap = 35;
  static const double vesselCardRadius = 28;
  static const double vesselCardBorder = 1.5;
  static const double vesselCardBorderSelected = 4;

  /// The taller of the two vessel assets (`image 35`, the can) sets the slot.
  static const double vesselImageHeight = 380;
  static const double vesselImageWidth = 290;
  static const double vesselImageGap = 24;

  /// Loew Bold 28 with 3.36 tracking, uppercase — Figma `cup-text` / `can-text`.
  /// The rendered word is sized from the card's width, not the squashed
  /// height, and never below [vesselLabelMinSize].
  static const double vesselLabelSize = 28;
  static const double vesselLabelTracking = 3.36;

  /// Floor for the CUP/CAN word so a short vessel card cannot crush it.
  /// Kept below the size/add-on labels so it does not dominate the section.
  static const double vesselLabelMinSize = 16;

  // -- bottom action bar ---------------------------------------------------
  /// `btn-skip` / `btn-next`: 1201 x 252, 22 apart, 30px radius, 8px outline.
  static const double actionHeight = 252;
  static const double actionGap = 22;
  static const double actionRadius = 30;
  static const double actionBorder = 8;
  static const double actionLabelSize = 72;

  /// Cup/can panel bottom (4989) -> bar top (5061), and bar bottom -> artboard.
  static const double actionBarTopGap = 72;
  static const double actionBarBottomGap = 87;

  static const double actionBarBlock =
      actionBarTopGap + actionHeight + actionBarBottomGap;

  /// Hairlines cannot render below one logical pixel, so every border scales
  /// with `s` but never falls under this. It is the one place a fixed value is
  /// correct — a 0.3px outline simply disappears.
  static const double borderFloor = 1.0;
}

/// Height, in artboard pixels, of the screen this product actually produces.
///
/// The artboard is 5400 tall because the design's add-on grid shows three full
/// rows; a product with no add-ons, or no cup/can question, needs far less. The
/// scale rule below divides the viewport by THIS rather than by 5400, so a
/// short product is not shrunk to fit height it never asked for.
///
/// The add-on and cup/can areas are counted at their MINIMUM (one add-on row),
/// because the add-on grid is the one region that scrolls — anything beyond one
/// row is a bonus the leftover height pays for.
double kioskCustomizeArtboardHeight({
  required bool hasDescription,
  required int variationPanels,
  required bool hasAddOns,
  required bool hasVessel,
  bool landscape = false,
}) {
  const spec = KioskCustomizeSpec.panelChrome;
  double height =
      KioskCustomizeSpec.headerHeight(hasDescription: hasDescription) +
          KioskCustomizeSpec.headerToPanels;

  for (int i = 0; i < variationPanels; i++) {
    if (i > 0) height += KioskCustomizeSpec.panelGap;
    height += spec + KioskCustomizeSpec.optionCardHeight;
  }
  if (hasAddOns) {
    if (variationPanels > 0) height += KioskCustomizeSpec.panelGap;
    height += spec + KioskCustomizeSpec.addOnCardHeight;
  }
  if (hasVessel) {
    if (variationPanels > 0 || hasAddOns) {
      height += KioskCustomizeSpec.panelGap;
    }
    height += spec + KioskCustomizeSpec.vesselCardHeight;
  }
  final double stacked = height + KioskCustomizeSpec.actionBarBlock;
  // Two-column landscape reports roughly half the stacked height so
  // [kioskCustomizeScale] is no longer dominated by byHeight. Guards on the
  // scale function itself are load-bearing and must not change.
  if (landscape) return stacked * 0.52;
  return stacked;
}

/// Lower bound on how far the height rule may pull the scale below the width
/// rule. Past this the screen is better off scrolling (see [kioskCustomizeFits])
/// than shrinking into illegibility.
const double kKioskCustomizeHeightPull = 0.55;

/// Absolute floor, for degenerate viewports (a 200px test window).
const double kKioskCustomizeMinScale = 0.12;

/// Artboard px -> logical px for this screen.
///
/// Bounded on both axes, the Flutter equivalent of `clamp(min, preferred, max)`:
///
///  * `width / 2572` is the preferred value — at the artboard's own width the
///    screen renders 1:1 with Figma, and it never exceeds 1.0 so a 4K display
///    gets more content rather than a magnified one (the page is additionally
///    capped and centred at [KioskCustomizeSpec.artboardWidth]).
///  * `height / artboardHeight` is the ceiling that actually fixes the old
///    screen: scaling by width alone on a viewport proportionally SHORTER than
///    the artboard is exactly why the header, cards and buttons looked
///    oversized — there was never room for them at that scale.
///  * the result is floored relative to the width rule so a short landscape
///    window scrolls instead of rendering 6px type.
double kioskCustomizeScale({
  required Size viewport,
  required double artboardHeight,
}) {
  if (viewport.width <= 0 || artboardHeight <= 0) {
    return kKioskCustomizeMinScale;
  }
  final double byWidth =
      math.min(viewport.width / KioskCustomizeSpec.artboardWidth, 1.0);
  final double byHeight = viewport.height / artboardHeight;
  final double fitted = math.min(byWidth, byHeight);
  return fitted
      .clamp(byWidth * kKioskCustomizeHeightPull, byWidth)
      .clamp(kKioskCustomizeMinScale, 1.0)
      .toDouble();
}

/// Whether the pinned Figma layout fits: header, variation panels, one add-on
/// row, cup/can and the action bar all on screen at once. False means the
/// viewport is too short even at the floored scale, and the screen falls back
/// to scrolling everything between the pinned action bar and the top.
bool kioskCustomizeFits({
  required Size viewport,
  required double artboardHeight,
  required double scale,
}) =>
    artboardHeight * scale <= viewport.height + 0.5;
