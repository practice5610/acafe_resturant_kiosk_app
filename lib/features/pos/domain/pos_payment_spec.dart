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

  /// `purchase-receipt-sidebar` is a fixed 720 in a 1366 frame; the payment
  /// card takes the remaining 550. Held as a ratio rather than two fixed
  /// widths so the pair keeps its proportions on a narrower window, and
  /// capped by [contentMaxWidth] so a 4K terminal does not stretch a receipt
  /// to a metre wide.
  static const int receiptFlex = 720;
  static const int paymentFlex = 550;
  static const double contentMaxWidth = 1302; // 720 + 32 + 550

  /// Below either of these the cards stack and the page scrolls instead.
  static const double stackedBelowWidth = 900;
  static const double stackedBelowHeight = 560;

  // ── Cards (1641:2764 / 1641:2838) ────────────────────────────────────
  static const double cardRadius = 16;
  static const double cardBorder = 1.5;

  // ── processing-card body (1641:2838) ─────────────────────────────────
  static const double paymentCardPadding = 24;
  static const double paymentCardGap = 24;
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

  /// Total height the bar occupies, so the scrolling content can reserve it.
  static const double barHeight =
      barBorderTop + barPaddingTop + confirmHeight + barPaddingBottom;
}
