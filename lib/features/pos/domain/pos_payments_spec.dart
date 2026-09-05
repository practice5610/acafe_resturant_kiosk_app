import 'package:flutter/material.dart';

/// Design tokens for POS Settings → Payments (Figma node **1641:4235**).
///
/// Sibling to [PosHardwareSpec] and [PosProductsSettingsSpec]: the shared
/// Settings palette and panel padding stay in [PosSettingsSpec], and only what
/// this frame introduces — the method rows and the transaction card's tighter
/// field metrics — lives here.
class PosPaymentsSpec {
  PosPaymentsSpec._();

  // ── Two-column grid (1641:4263) ──────────────────────────────────────
  /// Figma pins the right column at 380px and lets the method list take the
  /// rest. Below the breakpoint the two stack, so a narrow terminal keeps the
  /// full-width rows legible instead of squeezing a 380px card beside them.
  static const double columnGap = 24;
  static const double rightColumnWidth = 380;
  static const double twoColumnBreakpoint = 900;

  static const double headerGap = 4;
  static const double headerToGridGap = 24;

  /// "PAYMENT METHODS" / "TRANSACTION SETTINGS" (1641:4265, 1641:4314).
  static const double sectionLabelSize = 16;
  static const double sectionLabelToCardGap = 16;
  static const double rightSectionLabelToCardGap = 12;

  // ── Cards (1641:4266, 1641:4315) ─────────────────────────────────────
  static const double cardRadius = 16;
  static const Color cardBorder = Color(0xFFE1DBC4);
  static const Color cardFill = Colors.white;

  // ── Method row (1641:4267) ───────────────────────────────────────────
  static const EdgeInsets rowPadding =
      EdgeInsets.symmetric(horizontal: 24, vertical: 16);
  static const Color rowDivider = Color(0xFFF0EBD8);
  static const double rowMetaGap = 16;
  static const double rowTextGap = 2;
  static const double rowNameSize = 15;
  static const double rowDescriptionSize = 13;

  /// Icon tile. Figma's glyphs are 16px (cash) and 18px (the rest) inside an
  /// 8px-padded box; the slot is fixed here so the four rows line up on one
  /// left edge rather than stepping in and out by a pixel.
  static const double iconBoxSize = 34;
  static const double iconBoxRadius = 8;
  static const Color iconBoxFill = Color(0xFFF7F1DE);

  // ── Transaction settings card (1641:4315) ────────────────────────────
  static const EdgeInsets settingsCardPadding = EdgeInsets.all(20);
  static const double settingsCardGap = 16;
  static const double inputGroupGap = 8;
  static const double inputLabelSize = 13;

  /// The transaction card's fields are tighter than the Settings default —
  /// `p-12` / `rounded-8` against General's `16/14` / `rounded-12`.
  static const double fieldRadius = 8;
  static const EdgeInsets fieldPadding = EdgeInsets.all(12);

  static const double toggleLabelSize = 13;
  static const double toggleSubtitleSize = 11;
  static const double toggleTextGap = 2;
}
