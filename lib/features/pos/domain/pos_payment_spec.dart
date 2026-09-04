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

  /// Below either of these the cards stack and the page scrolls instead.
  static const double stackedBelowWidth = 900;
  static const double stackedBelowHeight = 560;

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
  static const EdgeInsets denomPadding =
      EdgeInsets.symmetric(horizontal: 16, vertical: 12);

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
