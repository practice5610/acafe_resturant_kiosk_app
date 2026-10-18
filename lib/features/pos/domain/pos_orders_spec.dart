import 'package:acafe_customer/features/pos/domain/pos_payment_spec.dart';
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

  /// Figma's `leading-normal` for Swiss 721 Light (11 → 13, 12 → 14). Loew's
  /// own metrics already match; Swiss's run ~2px taller. The same rule the
  /// payment screens use.
  static double swissLeading(double fontSize) =>
      PosPaymentSpec.figmaLeading(fontSize);

  /// `filters-area` (1915:15771): 14 above and below, rows 10 apart, and a
  /// 1px ink rule separating it from the board.
  static const double filtersPaddingV = 14;
  static const double filterRowGap = 10;
  static const double filtersDivider = 1;

  /// `orders-scroll-area` starts its content 20 below that rule.
  static const double boardPaddingTop = 20;

  // ── Filter controls (1915:15772 / 1915:15797) ────────────────────────
  /// Every control in the filter area is the same outlined pill — NOW, the
  /// date fields, the presets, search and the dropdowns: 1.5px ink, r20, 8 top
  /// and bottom. Active ones fill with ink.
  static const double filterPillRadius = 20;
  static const double filterPillBorder = 1.5;
  static const double filterPillPaddingV = 8;
  static const double filterIconSize = 14;
  static const double filterIconGap = 6;

  // ── Date row (1915:15772) ────────────────────────────────────────────
  static const double nowButtonWidth = 62;
  static const double nowPaddingH = 14;
  static const double dateFieldPaddingH = 10;

  /// Between the row's groups (presets, NOW, From, To, search).
  static const double dateGap = 8;

  /// `FROM` / `TO` to their field.
  static const double dateLabelGap = 6;
  static const double dateLabelSize = 12;
  static const double dateTextSize = 12;

  // ── Search (1915:15790) ──────────────────────────────────────────────
  static const double searchHeight = 32;
  static const double searchPaddingH = 10;
  static const double searchTextSize = 12;
  static const double searchHintAlpha = 0.38;
  static const double searchClearRadius = 4;
  static const double searchClearPadH = 6;
  static const double searchClearPadV = 3;
  static const double searchClearIconSize = 10;
  static const Color searchClearFill = Color(0xFFE1DBC4);

  /// Material 3's InputDecorator puts 4px of its own after a prefix icon.
  /// Figma's search text starts 6 after the glyph, so the field asks for 2.
  static const double searchPrefixFrameworkGap = 4;

  /// Figma's search fills whatever the date row leaves. Below this content
  /// width the presets, NOW and the two date fields already take most of the
  /// row, so search drops onto its own full-width line instead of squeezing.
  static const double searchInlineMinWidth = 1100;

  // ── Dropdown row (1915:15797) ────────────────────────────────────────
  static const double dropdownGap = 8;
  static const double dropdownPaddingLeft = 12;
  static const double dropdownPaddingRight = 10;
  static const double dropdownLabelSize = 13;
  static const double chevronSize = 14;

  /// `filter-btn`: ink-filled while the dropdowns are shown, outlined when
  /// they are folded away.
  static const double filterButtonPaddingH = 16;

  // ── Status pills (1915:15818) ────────────────────────────────────────
  /// The pills themselves are [PosFilterPill], already Figma's r20 / 1.5 / 13.
  static const double pillGap = 8;

  // ── Sections (1915:15831 / 15968 / 16050) ──────────────────────────
  static const double sectionHeaderSize = 15;
  /// `section-header-*` to `*-cards-grid`.
  static const double sectionHeaderGap = 12;
  /// Between one section's grid and the next section's header.
  static const double sectionGap = 20;

  static const double badgeHeight = 17;
  static const double badgeMinWidth = 23;
  static const double badgeRadius = 8.5;
  static const double badgePaddingH = 8;
  static const double badgeTextSize = 11;
  static const double badgeGap = 8;

  /// Count badge fills, one per section (`new-badge` / `progress-badge` /
  /// `finished-badge`). NEW's and IN PROGRESS's are the same hexes the detail
  /// modal's status badge uses.
  static const Color sectionBadgeNew = Color(0xFF496052);
  static const Color sectionBadgeInProgress = Color(0xFF2D9CDB);
  static const Color sectionBadgeFinished = Color(0xFF59B86B);

  // ── Cards (1915:15837 and variants) ─────────────────────────────────
  /// `card-*` is 288 wide with a 300 pitch → a 12px gap on both axes.
  static const double cardWidth = 288;
  static const double cardGap = 12;
  static const double cardRadius = 10;
  static const double cardPadding = 12;

  /// Every card, in every section, is white with a 1.5px ink outline, drawn
  /// inside the card like Figma's stroke — it does not move the content.
  static const double cardBorder = 1.5;

  /// `card-*` is 155 tall in every section. A card with more to say grows.
  static const double cardMinHeight = 155;

  /// `urgent-border`: the 4px bar down the left edge of a late card.
  static const double urgentBarWidth = 4;

  /// `card-top`: the dot-and-clock row.
  static const double cardTopHeight = 16;

  static const double statusDotSize = 8;
  static const double clockTextSize = 13;
  static const double clockGap = 6;

  /// `source-badge`: a 24px cream disc with a 1.5px ink ring (FINISHED cards
  /// drop the ring) holding a 14px glyph.
  static const double sourceBadgeSize = 24;
  static const double sourceBadgeBorder = 1.5;
  static const double sourceIconSize = 14;

  /// `card-actions` ⋮. Figma parks it under the source badge, where it cannot
  /// be seen or tapped, so it sits just left of the badge instead, in a hit
  /// box the badge's size.
  static const double menuIconSize = 14;
  static const double menuHitSize = 24;
  static const double menuGap = 6;
  static const double menuDisabledOpacity = 0.35;
  static const double pendingSpinnerSize = 14;

  static const double nameTextSize = 14;
  static const double subtitleTextSize = 11;
  static const double subtitleLineGap = 2;
  static const double subtitleAlpha = 0.6;
  static const double timerTextSize = 11;
  static const double priceTextSize = 14;

  /// `card-top` → `customer-info`, `customer-info` → `timer-section`,
  /// `timer-section` → `card-footer`.
  static const double cardBlockGap = 8;

  /// `station-pill` in the card footer (1915:15995): solid status fill,
  /// white ExtraBold 10, 4 apart, right of the price.
  static const double stationPillRadius = 12;
  static const double stationPillPadH = 8;
  static const double stationPillPadV = 3;
  static const double stationPillTextSize = 10;
  static const double stationPillGap = 4;

  // ── Card colours ─────────────────────────────────────────────────────
  /// The `time-row` dot is coloured by **section**. Figma's layer names say so
  /// (`status-dot-yellow` / `-blue` / `-green`); its NEW and IN PROGRESS fills
  /// do not, and were ruled a Figma slip. FINISHED's green is Figma's own.
  static const Color dotNew = Color(0xFFE0A11B);
  static const Color dotInProgress = Color(0xFF2F6FB5);
  static const Color dotFinished = Color(0xFF59B86B);

  /// The late card's bar, dot and clock (`urgent-border` / `urgent-dot`).
  static const Color urgentAccent = Color(0xFFEB5757);

  /// `timer-row` text: on time, getting late, late. "Done" is [timerNormal].
  static const Color timerNormal = Color(0xFF2EBD6B);
  static const Color timerWarning = Color(0xFFF29E26);
  static const Color timerUrgent = Color(0xFFE33836);

  // ── Responsive ───────────────────────────────────────────────────────
  /// Below this the fixed 288px card is wider than the content area, so cards
  /// stretch to the available width instead of overflowing.
  static const double cardStretchBelowWidth = 320;

  // ── Item progress on the card (DS5) ──────────────────────────────────
  /// A compact "2/3 ready" line plus one bar segment per item, so the counter
  /// can see how far an order has got without opening it.
  static const double progressGap = 6;
  static const double progressLabelSize = 11;
  static const double progressBarHeight = 4;
  static const double progressBarRadius = 2;
  static const double progressSegmentGap = 2;

  /// Segment fill for an item nobody has started. Deliberately faint: the bar
  /// should read as "how much is done", not as three competing colours.
  static const Color progressTrack = Color(0xFFE6E1D2);
}
