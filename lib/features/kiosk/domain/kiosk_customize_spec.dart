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

  /// The photo and the space around it — everything in the header that is
  /// picture rather than words. It is two thirds of the header block, and the
  /// only part of it that can be given up: type has a legibility floor, a photo
  /// does not. See [kioskCustomizeHeroFactor].
  static const double heroBlock = heroTop + heroHeight + heroToTitle;

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
  ///
  /// This decides DENSITY — how many cards go across — and nothing else. A
  /// wrapping grid then divides its row among that many columns (see
  /// `_choiceGridTileWidth`), because a card held at exactly 96px leaves the
  /// remainder of the row as dead space against the panel's right edge.
  static const double choiceCardMaxEdgeCompact = 96;

  /// Floor on the gutter between two choice cards, in logical pixels.
  ///
  /// The design's 24px gutter is an artboard measurement like everything else,
  /// so it follows `s` — and on a phone `s` is around 0.16, which turns it into
  /// under 4px: cards that read as one continuous strip rather than as separate
  /// things to tap. The floor only ever binds below ~1080px of width, where the
  /// scaled gutter is already thinner than this.
  static const double choiceCardGapFloor = 10;

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

  /// Uppercase `cup-text` / `can-text`. The rendered word now takes the
  /// SECTION-HEADING size and weight ([panelTitleSize], Loew ExtraBold) rather
  /// than the design's own 28, so "Size", "Add add-ons" and "CUP" read as one
  /// family of labels down the column. Sizing it from the card width instead
  /// let it outgrow those headings whenever height pulled the page scale down.
  static const double vesselLabelSize = 28;

  /// Tracking as a share of the font size (3.36 / 28), so the letter-spacing
  /// follows whatever size the label ends up at.
  static const double vesselLabelTrackingRatio = 0.12;

  /// Cap on the vessel word as a share of the card width, so a narrow card
  /// ellipsizes rather than colliding with the vessel image above it.
  static const double vesselLabelMaxWidthShare = 0.18;

  /// Floor for the optional price line under the vessel word, so a short card
  /// cannot crush it. No longer applies to the word itself — that follows
  /// [panelTitleSize].
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
  final double header =
      KioskCustomizeSpec.headerHeight(hasDescription: hasDescription);

  double panels = 0;
  for (int i = 0; i < variationPanels; i++) {
    if (i > 0) panels += KioskCustomizeSpec.panelGap;
    panels += spec + KioskCustomizeSpec.optionCardHeight;
  }
  if (hasAddOns) {
    if (variationPanels > 0) panels += KioskCustomizeSpec.panelGap;
    panels += spec + KioskCustomizeSpec.addOnCardHeight;
  }
  if (hasVessel) {
    if (variationPanels > 0 || hasAddOns) {
      panels += KioskCustomizeSpec.panelGap;
    }
    panels += spec + KioskCustomizeSpec.vesselCardHeight;
  }

  // Landscape draws the header and the panels as two COLUMNS, so the page is
  // as tall as the taller of the two plus the pinned action bar — never the
  // two stacked.
  //
  // This used to be `stacked * 0.52`, a flat fudge factor, and that is the bug
  // it replaces: 0.52 of a stack is only near the true height when the panel
  // column happens to be about as tall as the header. For a product with one
  // small question — a Size row and nothing else, or Version B's single step —
  // the panel column is short, the stack is short, and half of a short stack
  // budgets LESS height than the header alone needs. The scale then came out
  // too large and the header (hero photo, name, description, quantity stepper)
  // overflowed the bottom of its column, painting over the action bar.
  //
  // The header is the floor here even when the panels are taller, because the
  // panel column scrolls and the header column does not.
  if (landscape) {
    return math.max(header, panels) + KioskCustomizeSpec.actionBarBlock;
  }
  return header +
      KioskCustomizeSpec.headerToPanels +
      panels +
      KioskCustomizeSpec.actionBarBlock;
}

/// Share of the viewport the header may claim before the hero photo starts
/// giving height back to the panels.
///
/// On the artboard the header is 1373 of 5400 — a quarter of a page the
/// customer scrolls anyway. A landscape window is the same page with a third of
/// the height, so at the scale the height-pull floor allows, that same header
/// covers over half the screen and the customer meets a giant photo where the
/// design shows a photo and two questions.
const double kKioskCustomizeHeaderShare = 0.34;

/// How far the hero may shrink. Past this it stops reading as the product's
/// photo, and a page that still does not fit is better off scrolling.
const double kKioskCustomizeHeroFloor = 0.35;

/// Fraction of [KioskCustomizeSpec.heroBlock] this viewport can afford.
///
/// 1.0 — the design's own hero — whenever the page fits at [scale]: a kiosk in
/// portrait, a tablet, a phone. Below that only on a viewport too short for the
/// stack, where every artboard pixel the photo gives back is one the Size row
/// and the add-ons take.
double kioskCustomizeHeroFactor({
  required Size viewport,
  required double artboardHeight,
  required double scale,
  required bool hasDescription,
}) {
  if (scale <= 0) return 1;
  // Looser than the pin/scroll decision: floating-point equality should not
  // shrink a photo that essentially fits. See [kKioskCustomizeHeroFitEpsilon].
  if (kioskCustomizeFits(
        viewport: viewport,
        artboardHeight: artboardHeight,
        scale: scale,
        slack: -kKioskCustomizeHeroFitEpsilon,
      )) {
    return 1;
  }
  // Artboard px the header may occupy, and what it costs before the photo.
  final double allowance =
      (viewport.height * kKioskCustomizeHeaderShare) / scale;
  final double words =
      KioskCustomizeSpec.headerHeight(hasDescription: hasDescription) -
          KioskCustomizeSpec.heroBlock;
  return ((allowance - words) / KioskCustomizeSpec.heroBlock)
      .clamp(kKioskCustomizeHeroFloor, 1.0)
      .toDouble();
}

/// Ceiling on how far the hero may grow above the design size when reclaiming
/// the scale a shorter page budget would have given the photo. Past this a
/// short window answers "the page is tiny" with "then the photo is the page".
const double kKioskCustomizeHeroGrowthMax = 1.75;

/// Artboard height of a product with no customisation questions — header,
/// optional description, quantity stepper and the action bar.
///
/// This is the page that looks "right" on a MacBook browser window: the photo
/// is large because nothing below it is competing for height. Both Ordering
/// Experiences size the hero against this budget so adding Size / Milk /
/// add-ons / cup-or-can does not shrink the product shot; those panels scroll
/// instead.
double kioskCustomizeHeroTargetArtboard({required bool hasDescription}) =>
    kioskCustomizeArtboardHeight(
      hasDescription: hasDescription,
      variationPanels: 0,
      hasAddOns: false,
      hasVessel: false,
    );

/// Hero factor that both Ordering Experiences share.
///
/// The photo is sized to match what [targetArtboardHeight] would draw on this
/// viewport (by default the no-options page from
/// [kioskCustomizeHeroTargetArtboard]) — grown via the old split-layout scale
/// when that helps, shrunk only when even that shorter target page cannot fit.
/// Extra panels on [artboardHeight] never punish the photo: the page scrolls.
///
/// [targetSplitArtboardHeight] is the old two-column budget for the target
/// page; it only ever raises the hero above 1.0.
double kioskCustomizeResolvedHeroFactor({
  required Size viewport,
  required double artboardHeight,
  required bool hasDescription,
  required double targetArtboardHeight,
  required double targetSplitArtboardHeight,
}) {
  // Shrink/grow decisions are made against the TARGET page — the size the
  // photo should read at — not against the full stacked page. A product with
  // add-ons on a MacBook landscape window used to shrink the hero because the
  // tall stack did not fit; the no-options product on the same window kept a
  // large photo. Match that large photo and let the options scroll.
  final double targetBase = kioskCustomizeScale(
      viewport: viewport, artboardHeight: targetArtboardHeight);
  final double targetShrink = kioskCustomizeHeroFactor(
    viewport: viewport,
    artboardHeight: targetArtboardHeight,
    scale: targetBase,
    hasDescription: hasDescription,
  );

  late final double targetHeroFactor;
  if (targetShrink < 1) {
    targetHeroFactor = targetShrink;
  } else {
    final double targetSplit = kioskCustomizeScale(
        viewport: viewport, artboardHeight: targetSplitArtboardHeight);
    final double floorScale = math.min(
            viewport.width / KioskCustomizeSpec.artboardWidth, 1.0) *
        kKioskCustomizeHeightPull;
    final double targetFitCap = floorScale <= 0
        ? kKioskCustomizeHeroGrowthMax
        : 1 +
            (viewport.height / floorScale - targetArtboardHeight) /
                KioskCustomizeSpec.heroBlock;
    targetHeroFactor = math.max(
      1.0,
      math.min(
        targetBase <= 0 ? 1.0 : targetSplit / targetBase,
        math.min(kKioskCustomizeHeroGrowthMax, targetFitCap),
      ),
    );
  }

  final double targetEffective = kioskCustomizeScale(
        viewport: viewport,
        artboardHeight: kioskCustomizeArtboardWithHero(
          artboardHeight: targetArtboardHeight,
          heroFactor: targetHeroFactor,
        ),
      ) *
      targetHeroFactor;

  // Map that on-screen size onto THIS page's scale. Search the full legal
  // range — including below 1 when the target itself shrank — and do not let
  // a "page still fits" cap block matching: a tall stack on a short window is
  // already scrolling, and a larger photo is what the customer asked for.
  final double loBound = kKioskCustomizeHeroFloor;
  final double hiBound = kKioskCustomizeHeroGrowthMax;
  double lo = loBound;
  double hi = hiBound;
  for (int i = 0; i < 28; i++) {
    final double mid = (lo + hi) / 2;
    final double effective = kioskCustomizeScale(
          viewport: viewport,
          artboardHeight: kioskCustomizeArtboardWithHero(
            artboardHeight: artboardHeight,
            heroFactor: mid,
          ),
        ) *
        mid;
    if (effective < targetEffective) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return (lo + hi) / 2;
}

/// The page height once the hero has been shrunk (or grown) by [heroFactor].
double kioskCustomizeArtboardWithHero({
  required double artboardHeight,
  required double heroFactor,
}) =>
    artboardHeight - KioskCustomizeSpec.heroBlock * (1 - heroFactor);

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

/// Headroom required before the pinned (non-scrolling) layout is used.
///
/// Fonts and borders routinely round a fraction of a pixel above the budgeted
/// artboard height. Claiming "fits" at exact equality produced the yellow
/// "BOTTOM OVERFLOWED BY 0.5 PIXELS" banner. Require a full pixel of slack so
/// borderline pages scroll instead of overflowing.
const double kKioskCustomizePinSlack = 1.0;

/// Float tolerance when deciding whether the hero may stay at design size.
/// Kept separate from [kKioskCustomizePinSlack]: the photo can still be full
/// size on a page that prefers to scroll.
const double kKioskCustomizeHeroFitEpsilon = 0.5;

/// Whether [artboardHeight] × [scale] fits in [viewport] with [slack] to spare.
///
/// Default [slack] is [kKioskCustomizePinSlack] — the pin/scroll decision.
/// Pass a negative slack (e.g. `-[kKioskCustomizeHeroFitEpsilon]`) for the
/// looser "is the page essentially on-screen?" check the hero factor uses.
bool kioskCustomizeFits({
  required Size viewport,
  required double artboardHeight,
  required double scale,
  double slack = kKioskCustomizePinSlack,
}) =>
    artboardHeight * scale <= viewport.height - slack;
