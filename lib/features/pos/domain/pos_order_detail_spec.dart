import 'package:flutter/material.dart';

/// Metrics for the Orders detail overlay (Figma **1641:4425** / **1641:5453**).
///
/// Figma draws the modal at a fixed 1120×718 inside a 1366×1024 frame. Those
/// are kept as *maximums*, not fixed sizes — the POS runs on hardware narrower
/// than 1366 (see [PosResponsive]), and a fixed 1120 would clip there. The
/// overlay takes the lesser of the Figma width and the space available.
class PosOrderDetailSpec {
  PosOrderDetailSpec._();

  // ── Shell ────────────────────────────────────────────────────────────
  static const double modalWidth = 1120;
  static const double modalHeight = 718;
  static const double modalRadius = 16;
  static const double modalBorder = 1.5;

  /// Minimum breathing room between the modal and the screen edge when the
  /// viewport is smaller than the Figma frame.
  static const double viewportInset = 24;

  static const Color modalBg = Color(0xFFFBF8EF);
  static const Color hairline = Color(0xFFF0EBD8);
  static const Color ink = Color(0xFF241F20);
  static const Color cream = Color(0xFFF7F1DE);
  static const Color backdrop = Color(0x66241F20);

  /// The complete-confirmation dialog dims harder than the detail overlay
  /// (Figma 1641:5119 draws rgba(36,31,32,0.7)). Both are real: the detail
  /// overlay is a place you read from, this one asks a question that has to
  /// pull focus off the board behind it.
  static const Color confirmBackdrop = Color(0xB3241F20);

  static const List<BoxShadow> modalShadow = [
    BoxShadow(
      color: Color(0x33000000),
      blurRadius: 48,
      spreadRadius: -12,
      offset: Offset(0, 18),
    ),
  ];

  // ── Header ───────────────────────────────────────────────────────────
  static const double headerPadTop = 24;
  static const double headerPadBottom = 16;
  static const double headerPadH = 24;
  static const double headerGap = 12;
  static const double titleSize = 22;

  static const double statusBadgeRadius = 11;
  static const double statusBadgePadH = 10;
  static const double statusBadgePadV = 4;
  static const double statusBadgeTextSize = 12;

  static const double timeBadgeRadius = 6;
  static const double timeBadgePadH = 8;
  static const double timeBadgeTextSize = 13;

  static const double sourceBadgeRadius = 6;
  static const double sourceBadgePadH = 10;
  static const double sourceBadgeGap = 6;
  static const double sourceIconSize = 14;
  static const double sourceTextSize = 13;

  static const double closeSize = 26;

  /// Status badge fills. Figma gives NEW (#496052) and IN PROGRESS (#2D9CDB)
  /// directly; it draws no finished variant, so that reuses the board's own
  /// finished dot colour rather than inventing a third green.
  static const Color badgeNew = Color(0xFF496052);
  static const Color badgeInProgress = Color(0xFF2D9CDB);
  static const Color badgeFinished = Color(0xFF3F8A4F);

  // ── Body ─────────────────────────────────────────────────────────────
  static const double bodyPad = 24;
  static const double columnGap = 32;
  static const double rightColumnWidth = 420;
  static const double leftSectionGap = 24;

  /// Below this the two columns stack instead of sitting side by side.
  static const double stackColumnsBelowWidth = 900;

  static const double sectionLabelSize = 12;
  static const double sectionLabelTracking = 1;
  static const double sectionLabelGap = 10;

  // Customer card
  static const double customerCardRadius = 12;
  static const double customerCardPad = 16;
  static const double customerCardGap = 8;
  static const double customerNameSize = 16;
  static const double contactRowGap = 8;
  static const double contactIconSize = 14;
  static const double contactTextSize = 13;
  static const double contactLineGap = 4;

  // Notes card
  static const double noteRadius = 10;
  static const double notePad = 14;
  static const double noteTextSize = 13;
  static const double noteLineHeight = 18;
  static const Color noteBg = Color(0xFFFFF8EE);
  static const Color noteBorder = Color(0xFFF2C94C);

  // Items
  static const double itemsLabelGap = 4;
  static const double itemRowPadH = 16;
  static const double itemRowPadV = 12;
  static const double itemRowGap = 12;
  static const double itemThumbWidth = 52;
  static const double itemThumbHeight = 62;
  static const double itemThumbRadius = 12;
  static const double itemNameSize = 14;
  static const double itemMetaSize = 12;
  static const double itemNoteSize = 11;
  static const double itemDetailGap = 4;
  static const Color itemDivider = Color(0xFFB9B5A6);
  static const Color itemNoteInk = Color(0x87241F20);

  // ── Sticky action bar ────────────────────────────────────────────────
  static const double barPadTop = 16;
  static const double barPadBottom = 24;
  static const double barPadH = 24;
  static const double barTopBorder = 2;
  static const double actionHeight = 64;
  static const double actionRadius = 32;
  static const double actionTextSize = 18;

  static Color inkAlpha(double opacity) => ink.withValues(alpha: opacity);
}
