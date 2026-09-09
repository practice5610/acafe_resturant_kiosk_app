import 'package:flutter/material.dart';

/// Figma **1641:2874** — the Orders board.
///
/// The board is one vertical scroll of three stacked sections
/// (`section-new` → `section-in-progress` → `section-finished`), each a header
/// plus a wrapping grid of 288px cards. It is deliberately *not* three
/// side-by-side columns; the frame draws every section at the full 1318px
/// content width.
///
/// Palette comes from [PosHomeSpec] — this screen adds only the few colours
/// Figma introduces for the status dots and the finished-card treatment.
class PosOrdersSpec {
  PosOrdersSpec._();

  // ── Frame ────────────────────────────────────────────────────────────
  /// `body` sits under the 80px nav bar; every row insets 24 from the edges.
  static const double pagePadding = 24;

  /// `filters-area` is 144 tall: three 32px rows at y=14 / 56 / 98.
  static const double filterRowHeight = 32;
  static const double filterRowGap = 10;
  static const double filtersBottomGap = 20;

  // ── Date row (1641:2878) ─────────────────────────────────────────────
  static const double nowButtonWidth = 62;
  static const double dateFieldHeight = 30;
  static const double dateFieldRadius = 6;
  static const double dateFieldPaddingH = 10;
  static const double dateIconSize = 14;
  static const double dateGap = 8;
  static const double dateLabelSize = 12;
  static const double dateTextSize = 12;

  // ── Dropdown row (1641:2903) ─────────────────────────────────────────
  static const double dropdownHeight = 32;
  static const double dropdownRadius = 8;
  static const double dropdownPaddingH = 12;
  static const double dropdownGap = 8;
  static const double dropdownLabelSize = 13;
  static const double chevronSize = 14;

  // ── Status pills (1641:2924) ─────────────────────────────────────────
  static const double pillHeight = 32;
  static const double pillRadius = 16;
  static const double pillPaddingH = 18;
  static const double pillGap = 8;
  static const double pillLabelSize = 13;

  // ── Sections ─────────────────────────────────────────────────────────
  static const double sectionHeaderSize = 14;
  /// `section-header-*` to `*-cards-grid`.
  static const double sectionHeaderGap = 30;
  /// Between one section's grid and the next section's header.
  static const double sectionGap = 40;

  static const double badgeHeight = 17;
  static const double badgeMinWidth = 23;
  static const double badgeRadius = 8.5;
  static const double badgeTextSize = 11;
  static const double badgeGap = 8;

  // ── Cards ────────────────────────────────────────────────────────────
  /// `card-*` is 288 wide with a 300 pitch → a 12px gap on both axes.
  static const double cardWidth = 288;
  static const double cardGap = 12;
  static const double cardRadius = 10;
  static const double cardPadding = 12;
  static const double cardBorder = 1.5;

  /// `urgent-border`: the 4px bar down the left edge of a late card.
  static const double urgentBarWidth = 4;

  static const double statusDotSize = 8;
  static const double clockTextSize = 13;
  static const double clockGap = 6;

  /// The per-card status chip ("NEW" / "IN PROGRESS" / "FINISHED"). Not a
  /// Figma element — the section dot alone wasn't legible enough as a status
  /// indicator on the card itself, so this spells it out in words too,
  /// coloured to match that same dot.
  static const double statusChipHeight = 18;
  static const double statusChipRadius = 9;
  static const double statusChipPaddingH = 8;
  static const double statusChipTextSize = 9;
  static const double statusChipGap = 8;

  static const double sourceBadgeSize = 24;
  static const double sourceIconSize = 14;

  static const double nameTextSize = 14;
  static const double subtitleTextSize = 11;
  static const double subtitleLineGap = 2;
  static const double timerTextSize = 11;
  static const double priceTextSize = 14;
  static const double menuIconSize = 14;

  /// `card-top` → `customer-info`, `customer-info` → `timer-section`,
  /// `timer-section` → `card-footer`.
  static const double cardBlockGap = 8;

  static const double completeButtonHeight = 21;
  static const double completeButtonRadius = 10.5;
  static const double completeButtonPaddingH = 12;
  static const double completeLabelSize = 11;
  static const double checkIconSize = 14;

  // ── Section colours (Figma `status-dot-*`) ───────────────────────────
  static const Color dotNew = Color(0xFFE0A11B);
  static const Color dotInProgress = Color(0xFF2F6FB5);
  static const Color dotFinished = Color(0xFF3F8A4F);

  /// FINISHED cards are the outlined, muted variant — `card-inner` is inset
  /// 1.5px inside the frame, i.e. a border rather than a fill.
  static const Color finishedCardBg = Color(0xFFFDFBF4);

  // ── Responsive ───────────────────────────────────────────────────────
  /// Below this the fixed 288px card is wider than the content area, so cards
  /// stretch to the available width instead of overflowing.
  static const double cardStretchBelowWidth = 320;

  /// Below this the filter rows stop fitting on one line and wrap.
  static const double filtersWrapBelowWidth = 900;
}
