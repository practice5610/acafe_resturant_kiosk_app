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

  /// Height of the loading / error placeholder that stands in for the body.
  ///
  /// Definite on purpose. The body sits in a `Flexible`, so a bare `Center`
  /// placeholder expands to the modal's whole [modalHeight] budget — the
  /// spinner frame was drawn full height and the loaded frame collapsed back to
  /// whatever the order actually needs, which is the snap this replaces. A
  /// short fixed block keeps the modal roughly order-sized from the first
  /// frame, so [bodyResizeAnimation] only has a small distance to cover.
  static const double bodyPlaceholderHeight = 240;

  /// The body grows or shrinks into its new content instead of jumping — the
  /// one size change the modal makes is when the fetch lands.
  static const Duration bodyResizeAnimation = Duration(milliseconds: 220);

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

  // ── Per-item kitchen status ──────────────────────────────────────────
  // The chip and action live on the trailing edge of the existing item row --
  // the row gains a child, not a new layout.

  /// Status accent down the row's leading edge. Matches the kitchen's 3px bar
  /// (order_ticket_card.dart:712) so the two screens read the same at a glance.
  static const double itemAccentWidth = 3;
  static const double itemAccentRadius = 2;

  /// Gap between the row content, the chip and the action button.
  static const double itemStatusGap = 12;

  /// Status pill. Reuses the order-level statusBadge metrics at item scale.
  static const double itemChipRadius = statusBadgeRadius;
  static const double itemChipPadH = 10;
  static const double itemChipPadV = 5;
  static const double itemChipTextSize = 12;
  static const double itemChipDot = 6;
  static const double itemChipDotGap = 6;

  /// Tint strength for the chip fill behind its status colour.
  static const double itemChipFillOpacity = 0.12;

  /// Action button. 44px is the floor for a comfortable touch target on a
  /// counter terminal -- below that, staff mis-tap the neighbouring row.
  static const double itemActionHeight = 44;
  static const double itemActionMinWidth = 92;
  static const double itemActionRadius = 22;
  static const double itemActionPadH = 14;
  static const double itemActionBorder = 1;
  static const double itemActionTextSize = 13;
  static const double itemActionIconSize = 18;
  static const double itemActionGap = 6;
  static const double itemActionSpinner = 16;
  static const double itemActionSpinnerStroke = 2;

  /// Disabled action (order on hold, or another write in flight).
  static const double itemActionDisabledOpacity = 0.4;

  /// A finished line goes quiet: struck through, thumbnail dimmed, row tinted.
  /// Kitchen's treatment (order_ticket_card.dart:684-735), POS colours.
  static const double itemDoneThumbOpacity = 0.5;
  static const Color itemDoneRowBg = cream;

  /// State changes cross-fade rather than snapping, and never reflow the row.
  static const Duration itemStateAnimation = Duration(milliseconds: 180);

  // ── Items section header + progress ──────────────────────────────────
  static const double progressBarHeight = 4;
  static const double progressBarRadius = 2;
  static const double progressGap = 8;
  static const double progressLabelSize = 12;

  // ── On-hold banner ───────────────────────────────────────────────────
  static const double holdBannerRadius = 8;
  static const double holdBannerPadH = 12;
  static const double holdBannerPadV = 10;
  static const double holdBannerGap = 8;
  static const double holdBannerTextSize = 12;
  static const double holdBannerIconSize = 16;

  /// The kitchen's on-hold brown, the one status tone the POS palette has no
  /// equivalent for. Carried across deliberately: "paused" has no other colour
  /// in either app, and inventing a POS-only one would make the same state look
  /// like two different things on the two screens.
  static const Color holdTone = Color(0xFF795548);
  static const double holdBannerFillOpacity = 0.10;

  // ── Secondary "More" menu ────────────────────────────────────────────
  static const double moreButtonSize = 64;
  static const double moreButtonRadius = 32;
  static const double moreButtonIconSize = 24;
  static const double moreMenuWidth = 236;
  static const double moreMenuRadius = 12;
  static const double moreMenuPadV = 6;
  static const double moreMenuRowHeight = 48;
  static const double moreMenuRowPadH = 16;
  static const double moreMenuIconSize = 18;
  static const double moreMenuIconGap = 12;
  static const double moreMenuTextSize = 14;
  static const double moreMenuGap = 12;

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
