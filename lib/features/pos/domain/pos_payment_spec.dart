import 'package:acafe_customer/features/pos/domain/pos_responsive.dart';
import 'package:flutter/material.dart';

/// Design tokens for the POS payment screen, read from the Figma frame
/// `POS – Payment Selection` (node **1641:2757**, 1366x1024).
///
/// Colour and the receipt-card internals are **not** repeated here — the two
/// screens draw the same purchase receipt, so everything shared lives in
/// [PosHomeSpec] and is reused from there. Only the values this frame
/// introduces are below.
class PosPaymentSpec {
  PosPaymentSpec._();

  // ── back-btn-row (1641:2759) ─────────────────────────────────────────
  static const double backRowHeight = 67;
  static const double backRowPaddingH = 32;
  static const double backButtonSize = 40;
  static const double backButtonRadius = 20;
  static const double backButtonBorder = 1;
  static const double backIconSize = 18;

  // ── content-area (1641:2763) ─────────────────────────────────────────
  static const double contentPadding = 32;
  static const double contentGap = 32;

  /// Node **1641:3751** (cash entry) re-proportions the pair to two equal
  /// 634px columns, up from the 720/550 of the card-only frame — the tender
  /// keypad needs the room. Held as a ratio rather than fixed widths so the
  /// pair keeps its proportions on a narrower window, and capped by
  /// [contentMaxWidth] so a 4K terminal does not stretch a receipt to a metre
  /// wide.
  static const int receiptFlex = 634;
  static const int paymentFlex = 634;
  static const double contentMaxWidth = 1300; // 634 + 32 + 634

  /// Below this the cards stack and the page scrolls instead. Width only —
  /// see the sideBySide comment in pos_payment_selection_screen.dart.
  static const double stackedBelowWidth = 900;

  /// Above this the pair keeps the Figma proportions. Between here and
  /// [stackedBelowWidth] the window is a staff tablet or a half-screen browser
  /// window: still two columns, but the split, the gutter and the page insets
  /// all change, because the keypad has a comfortable minimum width and the
  /// receipt does not.
  ///
  /// Pinned to [PosResponsive.desktopFloor] rather than its own number: this
  /// was `1180` (a Payment-only seam independent of Home's), which meant a
  /// window between 1024 and 1180 got a *different* column split on Payment
  /// than the one it already got on Home/Customize — one more of the
  /// "several components independently reflow at their own breakpoints" the
  /// layout audit flagged. Sharing the floor makes the medium↔full swap stop
  /// existing anywhere at/above 1024, not just move.
  static const double mediumBelowWidth = PosResponsive.desktopFloor;

  /// Medium-band split. The payment column carries a 3x keypad, a five-chip
  /// denomination row and the totals; the receipt carries a list that reads
  /// fine narrow. So the room that is missing comes out of the receipt.
  static const int mediumReceiptFlex = 5;
  static const int mediumPaymentFlex = 7;

  /// Page insets and gutter for the medium band — 20 instead of 32 buys the
  /// two columns 24px each without touching either card's internals.
  static const double mediumContentPadding = 20;
  static const double mediumContentGap = 20;

  /// Stacked band: a single column of cards on a portrait tablet is capped so
  /// the receipt does not run a line of text the full width of the window.
  static const double stackedMaxWidth = 720;

  // ── Cards (1641:2764 / 1641:2838) ────────────────────────────────────
  static const double cardRadius = 16;
  static const double cardBorder = 1.5;

  // ── processing-card body (1641:2838, respaced by 1641:3808) ──────────
  /// The cash frame tightens the card to `px-24 py-16` with 16px between
  /// sections, down from the card-only frame's 24 everywhere. That is not
  /// cosmetic: the tender keypad adds ~440px, and at 24 the totals fall off
  /// the bottom of a 1024-tall terminal.
  static const double paymentCardPaddingH = 24;
  static const double paymentCardPaddingV = 16;
  static const double paymentCardGap = 16;
  static const double sectionLabelSize = 14;
  static const double sectionLabelHeight = 17 / 14;
  static const double sectionLabelTracking = 1;
  static const double sectionLabelOpacity = 0.4;

  // ── method-selectors (1641:2841) ─────────────────────────────────────
  static const double methodGap = 12;
  static const double methodHeight = 95;
  static const double methodRadius = 12;
  static const double methodBorder = 1;
  static const double methodPadding = 12;
  static const double methodInnerGap = 8;
  static const double methodTopRowHeight = 40;
  static const double methodIconBox = 32;
  static const double methodIconBoxRadius = 8;
  static const double methodIconSize = 18;
  static const double methodRadioSize = 24;
  static const double methodLabelSize = 15;
  static const double methodLabelHeight = 18 / 15;

  /// Idle icon well: `rgba(36,31,32,0.1)`. Selected wells take [PosHomeSpec.ink].
  static const Color methodIdleIconBg = Color(0x1A241F20);

  /// The selected card's outline is pure black in the file, one shade off the
  /// `#241F20` ink used everywhere else. Kept as drawn.
  static const Color methodSelectedBorder = Colors.black;

  // ── cash-payment-panel (1641:3830) ───────────────────────────────────
  /// Gap between the tender field, the chip row and the keypad.
  static const double cashPanelGap = 12;
  static const double cashFieldLabelGap = 8;
  static const double cashFieldLabelSize = 13;
  static const double cashFieldLabelHeight = 16 / 13;
  static const double cashFieldLabelOpacity = 0.53;
  static const double cashFieldPadding = 16;
  static const double cashFieldRadius = 12;
  static const double cashFieldBorder = 2;
  static const double cashAmountSize = 22;
  static const double cashAmountHeight = 27 / 22;
  static const double cashClearIconSize = 20;

  static const double denomGap = 8;
  static const double denomRadius = 10;
  static const double denomBorder = 1.5;
  static const double denomLabelSize = 14;
  static const double denomLabelHeight = 17 / 14;
  static const double denomPaddingH = 16;
  static const double denomPaddingV = 12;
  static const EdgeInsets denomPadding = EdgeInsets.symmetric(
    horizontal: denomPaddingH,
    vertical: denomPaddingV,
  );

  // ── numeric-keypad (1641:3849) ───────────────────────────────────────
  /// Mirrors `posCashKeypadStyle`. Held here as well because the column has to
  /// know how tall the pad will be *before* it builds one — see
  /// [PosPaymentDensity.fit].
  static const double keypadKeyHeight = 48;
  static const double keypadRowGap = 8;
  static const int keypadRows = 4;
  static const double _keypadHeight =
      keypadRows * keypadKeyHeight + (keypadRows - 1) * keypadRowGap;

  static const double changeBannerPadding = 16;
  static const double changeBannerRadius = 12;
  static const double changeBannerBorder = 1;
  static const double changeLabelSize = 15;
  static const double changeLabelHeight = 18 / 15;
  static const double changeValueSize = 20;
  static const double changeValueHeight = 24 / 20;
  /// `#EBF9F1` — the tint behind `change-due-banner`, paired with
  /// `PosHomeSpec.discountGreen` for its border and type.
  static const Color changeBannerFill = Color(0xFFEBF9F1);

  // ── payment-details (1641:2860) ──────────────────────────────────────
  static const double summaryPaddingTop = 16;
  static const double summaryPaddingH = 24;
  static const double summaryGap = 8;

  /// The unpinned summary's two internal gaps — above and below the rule.
  static const double _summaryGaps = summaryGap * 2;
  /// Line boxes of `PosReceiptSummary`, kept in step with `PosHomeSpec`.
  static const double _summaryRowLine = 19;
  static const double _summaryTotalLine = 29;

  // ── waiting-card (1641:4203 / 1641:4204) ─────────────────────────────
  static const double waitCardWidth = 560;
  static const double waitCardRadius = 24;
  static const double waitCardBorder = 1.5;
  static const double waitCardPaddingTop = 48;
  static const double waitCardPaddingBottom = 40;
  static const double waitCardPaddingH = 40;
  /// Between the dots, the heading, the amount box, the rule and the button.
  static const double waitCardGap = 36;
  static const double waitCardShadowBlur = 16;
  static const Offset waitCardShadowOffset = Offset(0, 12);
  static const Color waitCardShadow = Color(0x0A241F20); // 4% ink
  /// `#EAE5D5` — a warmer hairline than the receipt panel's `#F0EBD8`, and the
  /// same one the receipt context menu already uses.
  static const Color waitCardBorderColor = Color(0xFFEAE5D5);

  static const double waitDotSize = 10;
  static const double waitDotGap = 6; // 42 wide total: 3x10 + 2x6
  /// The dot green is its own value in the file — close to, but not,
  /// `PosHomeSpec.discountGreen` (#2A8456). Kept as drawn.
  static const Color waitDotColor = Color(0xFF496052);
  static const List<double> waitDotOpacities = [1.0, 0.6, 0.3];

  static const double waitHeadingSize = 28;
  static const double waitHeadingHeight = 34 / 28;

  static const double waitAmountBoxRadius = 16;
  static const double waitAmountBoxBorder = 1;
  static const double waitAmountBoxPaddingH = 32;
  static const double waitAmountBoxPaddingV = 20;
  static const double waitAmountLabelGap = 4;
  static const double waitAmountLabelSize = 13;
  static const double waitAmountLabelHeight = 16 / 13;
  static const double waitAmountLabelTracking = 1;
  static const double waitAmountLabelOpacity = 0.53;
  static const double waitAmountSize = 36;
  static const double waitAmountHeight = 43 / 36;

  static const double waitCancelRadius = 14;
  static const double waitCancelBorder = 1.5;
  static const double waitCancelPaddingV = 16;
  static const double waitCancelLabelSize = 16;
  static const double waitCancelLabelHeight = 19 / 16;

  // ── declined-card (1641:4218 / 1641:4221) ────────────────────────────
  /// The declined card is the waiting card with a different top element and a
  /// second button: same 560/r24/1.5 shell, same gaps, same amount box. Only
  /// the values below are new.
  static const double declinedIconSize = 80.84;
  static const double declinedActionsGap = 12;

  // ── sticky-bottom-bar (1641:2871) ────────────────────────────────────
  static const double barBorderTop = 2;
  static const double barPaddingTop = 16;
  static const double barPaddingBottom = 24;
  static const double barPaddingH = 32;
  static const double confirmHeight = 64;
  static const double confirmRadius = 32;
  static const double confirmLabelSize = 18;
  static const double barShadowBlur = 8;
  static const Offset barShadowOffset = Offset(0, -6);
  static const Color barShadow = Color(0x14241F20); // 8% ink

  /// Total height the bar occupies.
  static const double barHeight =
      barBorderTop + barPaddingTop + confirmHeight + barPaddingBottom;
}

/// Vertical density for the payment column.
///
/// The cash frame is authored at 1024 tall, where the card's natural height
/// (~721px with the keypad open) just clears the nav bar, the back row and the
/// sticky Confirm bar. A 1366x768 laptop, or any browser window with a bookmarks
/// bar, leaves ~150px less than that — and a till operator scrolling to reach
/// Change Due and the total is how the wrong amount gets confirmed.
///
/// So the column is *fitted* rather than scrolled: one factor derived from the
/// height actually available, applied to the card's spacing and type. Spacing
/// takes the factor whole; type takes half of it (`(1 + s) / 2`), because a
/// keypad digit that shrinks as fast as the gap around it stops being readable
/// across a counter. [fit] solves for the factor that lands the card exactly on
/// the available height under that split, so the result fits in one pass.
@immutable
class PosPaymentDensity {
  /// 1.0 = the design as drawn.
  final double scale;

  const PosPaymentDensity(this.scale);

  static const PosPaymentDensity full = PosPaymentDensity(1);

  /// Floor. Below this the type stops being counter-legible, and scrolling the
  /// last few pixels is the better trade — the column keeps its scroll view for
  /// exactly that case.
  static const double minScale = 0.7;

  /// Spacing, borders and fixed box heights.
  double px(double designPx) => designPx * scale;

  /// Type, and anything sized to read rather than to fit.
  double get textScale => (1 + scale) / 2;

  double text(double designPx) => designPx * textScale;

  bool get isFull => scale >= 1;

  /// Everything in the payment card that is a gap, a padding, a border or a
  /// fixed box height — the part that scales one-for-one.
  static double _spacing({required bool cash}) {
    const double shell = PosPaymentSpec.cardBorder * 2 + // the card outline
        PosPaymentSpec.paymentCardPaddingV * 2 +
        PosPaymentSpec.paymentCardGap + // label -> methods
        PosPaymentSpec.methodHeight +
        PosPaymentSpec.paymentCardGap + // methods -> cash panel or summary
        PosPaymentSpec.summaryPaddingTop +
        PosPaymentSpec._summaryGaps +
        1; // the rule above Total
    if (!cash) return shell;
    const double panel = PosPaymentSpec.cashFieldLabelGap +
        PosPaymentSpec.cashFieldPadding * 2 +
        PosPaymentSpec.cashFieldBorder * 2 +
        PosPaymentSpec.cashPanelGap +
        PosPaymentSpec.denomPaddingV * 2 +
        PosPaymentSpec.denomBorder * 2 +
        PosPaymentSpec.cashPanelGap +
        PosPaymentSpec._keypadHeight +
        PosPaymentSpec.paymentCardGap + // keypad -> change banner
        PosPaymentSpec.changeBannerPadding * 2 +
        PosPaymentSpec.changeBannerBorder * 2;
    return shell + PosPaymentSpec.paymentCardGap + panel;
  }

  /// Every line of type in the payment card, at its authored line height.
  static double _type({required bool cash, required bool discount}) {
    double total = PosPaymentSpec.sectionLabelSize *
            PosPaymentSpec.sectionLabelHeight +
        PosPaymentSpec._summaryRowLine +
        PosPaymentSpec._summaryTotalLine;
    if (discount) {
      total += PosPaymentSpec.summaryGap + PosPaymentSpec._summaryRowLine;
    }
    if (cash) {
      total += PosPaymentSpec.cashFieldLabelSize *
              PosPaymentSpec.cashFieldLabelHeight +
          PosPaymentSpec.cashAmountSize * PosPaymentSpec.cashAmountHeight +
          PosPaymentSpec.denomLabelSize * PosPaymentSpec.denomLabelHeight +
          PosPaymentSpec.changeValueSize * PosPaymentSpec.changeValueHeight;
    }
    return total;
  }

  /// Natural height of the payment card as drawn, for [available] to be
  /// measured against.
  static double naturalHeight({required bool cash, required bool discount}) =>
      _spacing(cash: cash) + _type(cash: cash, discount: discount);

  /// The largest factor whose card still fits in [available] logical pixels.
  ///
  /// Solved rather than searched: height(s) = A*s + B*(1+s)/2, so the exact
  /// root is `(available - B/2) / (A + B/2)`.
  factory PosPaymentDensity.fit({
    required double available,
    required bool cash,
    required bool discount,
  }) {
    if (!available.isFinite || available <= 0) return full;
    final double a = _spacing(cash: cash);
    final double b = _type(cash: cash, discount: discount);
    if (a + b <= available) return full;
    final double s = (available - b / 2) / (a + b / 2);
    return PosPaymentDensity(s.clamp(minScale, 1.0));
  }

  @override
  bool operator ==(Object other) =>
      other is PosPaymentDensity && other.scale == scale;

  @override
  int get hashCode => scale.hashCode;
}
