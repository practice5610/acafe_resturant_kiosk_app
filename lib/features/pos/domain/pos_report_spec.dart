import 'package:acafe_customer/features/pos/domain/pos_close_day_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:flutter/material.dart';

/// Figma **1915:18091** (redesign of 1641:5518) — Report Overview.
///
/// Authored against the 1366px frame in the design file, not the 1920px board
/// the rest of POS uses. That difference is why this screen keeps its own
/// tokens instead of borrowing [PosHomeSpec]: the numbers below are literal
/// Figma values and only mean anything against that frame. They still travel
/// through `posPx()` like every other POS token, but never below [minScale] —
/// see `PosReportScreen`.
class PosReportSpec {
  PosReportSpec._();

  /// Floor for the shell's density scale on this screen. The shell scales
  /// against the 1920 board, which would draw these 1366-frame values at
  /// ~71% on the very 1366 terminal they were designed for. Larger displays
  /// still scale up as before.
  static const double minScale = 1.0;

  // ── Palette ──────────────────────────────────────────────────────────
  /// The report frames use `#E1DBC4` for card borders — a step warmer than
  /// [PosUI.border] (`#DED9C7`) and visible against the white card fill.
  static const Color cardBorder = Color(0xFFE1DBC4);

  /// Recessed fill inside a card: payment rows, table rows, legend chips. Same
  /// value as the page background, by design — rows read as cut-outs.
  static const Color rowFill = Color(0xFFF7F1DE);

  static const Color ink = Color(0xFF241F20);

  /// Figma writes muted text as `rgba(36,31,32,0.6)` rather than a named grey.
  static const Color inkMuted = Color(0x99241F20);

  /// Unhighlighted hourly bar / neutral chart fill.
  static const Color barIdle = Color(0xFFE1DBC4);

  /// In-card rules (VAT breakdown, cash drawer) — Figma's `Line` stroke,
  /// lighter than [cardBorder].
  static const Color divider = PosHomeSpec.hairline;

  /// Label on the dark KPI pills (`32 pending prep`).
  static const Color solidBadgeText = Colors.white;

  /// Cash drawer `Difference` row — the same red pair Close Day uses for its
  /// discrepancy badge.
  static const Color negativeText = PosCloseDaySpec.discrepancyRed;
  static const Color negativeFill = PosCloseDaySpec.discrepancyBadgeBg;

  /// Category stacked-bar palette, in order. Cycled when a day has more
  /// categories than colours.
  static const List<Color> categoryColors = <Color>[
    Color(0xFF241F20),
    Color(0xFF3D2B1F),
    Color(0xFF6B6055),
    Color(0xFFF5E6D3),
    Color(0xFFC8A97E),
    Color(0xFF8A8275),
  ];

  // ── Body ─────────────────────────────────────────────────────────────
  static const double bodyPaddingH = 24;
  static const double bodyPaddingTop = 16;
  static const double bodyPaddingBottom = 24;
  static const double sectionGap = 16;

  /// Between cards in a row.
  static const double cardGap = 12;

  /// Between the rows themselves (KPI → middle → hourly → bottom): the
  /// `body` auto-layout gap, wider than the in-row gap.
  static const double rowGap = 16;

  // ── Type ─────────────────────────────────────────────────────────────
  /// Figma sets no letter-spacing. Pinned explicitly because the Material 3
  /// theme would otherwise lend every un-tracked line 0.25px per glyph.
  static const double tracking = 0;

  /// `VAT / BTW BREAKDOWN`.
  static const double sectionLabelTracking = 0.5;

  /// Figma writes negatives with a hyphen (`-€ 32.00`), not U+2212.
  static const String minusSign = '-';

  /// Card strokes and in-card rules.
  static const double hairlineWidth = 1;

  // ── Card ─────────────────────────────────────────────────────────────
  static const double cardRadius = 16;
  static const double cardPadding = 16;
  static const double cardInnerGap = 12;

  /// Title → header chip, and label → value on a detail row.
  static const double inlineGap = 8;

  /// Panel titles: 16 in the middle row, 15 in the bottom row. The title row
  /// hugs its content, as drawn: 23 with a pill and 19 without at 16px, 21
  /// and 18 at 15px.
  static const double panelTitleSize = 16;
  static const double panelTitleSizeSmall = 15;

  // ── Badge pill ───────────────────────────────────────────────────────
  static const double badgeRadius = 999;
  static const double badgePaddingH = 10;
  static const double badgePaddingV = 4;
  static const double badgeTextSize = 12;

  // ── KPI card ─────────────────────────────────────────────────────────
  static const double kpiLabelSize = 13;
  static const double kpiValueSize = 26;
  static const double kpiNoteSize = 12;
  static const double kpiSectionLabelSize = 11;
  static const double kpiRowSize = 12;
  static const double kpiTightGap = 4;

  /// The note + pill block under the figure on Orders / AOV / Tips: 8 above,
  /// 8 between.
  static const double kpiFootPaddingTop = 8;
  static const double kpiFootGap = 8;

  /// `Gross Sales` sits 2 lower than the other VAT rows.
  static const double kpiTotalRowPaddingTop = 2;

  /// Payment method name → transaction count.
  static const double paymentTextGap = 2;

  // ── Date header ──────────────────────────────────────────────────────
  static const double controlRadius = 12;
  static const double controlHeight = 40;
  static const double datePickerPaddingH = 14;
  static const double datePickerPaddingV = 10;
  static const double datePickerGap = 8;
  static const double dateTextSize = 14;
  static const double dateIconSize = 16;
  static const double chevronSize = 14;
  static const double navIconSize = 18;
  static const double controlGap = 12;

  // ── Close Day CTA ────────────────────────────────────────────────────
  static const double ctaRadius = 14;
  static const double ctaPaddingH = 18;
  static const double ctaPaddingV = 12;
  static const double ctaGap = 10;
  static const double ctaIconSize = 18;
  static const double ctaTextSize = 14;

  // ── Payment row ──────────────────────────────────────────────────────
  static const double paymentRowHeight = 68;
  static const double paymentRowRadius = 12;
  static const double paymentRowPadding = 10;
  static const double paymentRowGap = 12;
  static const double paymentIconBox = 32;
  static const double paymentIconBoxRadius = 8;
  static const double paymentIconSize = 18;
  static const double paymentNameSize = 13;
  static const double paymentSubSize = 11;
  static const double paymentAmountSize = 14;
  static const double panelListGap = 8;

  // ── Tables (top products, staff) ─────────────────────────────────────
  static const double tableGap = 6;
  static const double tableHeaderSize = 11;
  static const double tableRowSize = 13;
  static const double featuredRowHeight = 78;
  static const double featuredRowRadius = 10;
  static const double featuredRowPadding = 8;
  static const double featuredThumbWidth = 49;
  static const double featuredThumbHeight = 62;
  static const double featuredThumbRadius = 12;
  static const double featuredInfoGap = 16;
  static const double compactRowHeight = 36;
  static const double qtyColumnWidth = 80;
  static const double revenueColumnWidth = 100;

  // ── Hourly chart ─────────────────────────────────────────────────────
  static const double chartBandHeight = 120;
  static const double chartTopPadding = 8;
  static const double chartBarGap = 8;
  static const double chartBarRadius = 4;
  static const double chartLabelSize = 10;

  /// Inter 10's `leading-normal` line box.
  static const double chartLabelHeight = 12;
  static const double chartLabelGap = 4;

  /// Widest a single bar is allowed to get. Figma's day spans fifteen hours,
  /// which lands each bar near this width. A five-hour day would otherwise
  /// stretch five bars across the whole card and read as a different chart
  /// entirely, so bars cap here and centre in their column instead.
  static const double chartMaxBarWidth = 84;

  /// Shortest a bar with real sales in it may be drawn. A quiet hour that took
  /// 0.4% of the peak still has to be visibly a bar rather than a hairline, or
  /// the chart reads as "closed" for hours the shop was open.
  static const double chartMinBarHeight = 4;

  // ── Bottom-row panels ────────────────────────────────────────────────
  static const double detailRowSize = 12;
  static const double detailRowGap = 6;
  static const double refundRowGap = 8;
  static const double stackedBarHeight = 12;
  static const double stackedBarRadius = 6;
  static const double stackedBarGap = 4;
  static const double legendDotSize = 8;
  static const double legendGap = 6;
  static const double legendRowGap = 4;
  static const double staffRowRadius = 8;
  static const double staffRowPadding = 6;
  static const double staffColumnWidth = 80;

  /// Table header insets: Top Products `px-8 pb-4`, Staff `px-4 pb-2`.
  static const double productHeaderPaddingH = 8;
  static const double productHeaderPaddingBottom = 4;
  static const double staffHeaderPaddingH = 4;
  static const double staffHeaderPaddingBottom = 2;

  /// The small explanatory line under the staff table.
  static const double footnoteSize = 11;

  /// `refunds-rows` sit 4 below the title gap.
  static const double refundsPaddingTop = 4;

  /// Placeholder glyph in a missing product thumbnail.
  static const double thumbIconSize = 20;
  static const double differenceRowPadding = 6;
  static const double differenceRowRadius = 8;

  // ── Device breakdown cards ("Revenue by Terminal") ────────────────────
  // Not in Figma; built from the payment-row tokens above so it reads as
  // part of the same set.
  static const double deviceCardWidth = 176;
  static const double deviceCardHeight = 116;
  static const double deviceShareBarHeight = 6;

  // ── Empty / unavailable states (not in Figma) ────────────────────────
  static const double emptyPaddingV = 16;
  static const double emptyPaddingH = 12;
  static const double emptyTextGap = 4;

  // ── Control states ───────────────────────────────────────────────────
  /// Next-day arrow on today; Close Day once the day is closed or closing.
  static const double stepDisabledAlpha = 0.25;
  static const double ctaDisabledAlpha = 0.35;
  static const double ctaSpinnerStroke = 2;

  // ── Responsive breakpoints (logical px of the content area) ──────────
  /// The KPI row's own `1040` and the bottom row's own `1180` seams are
  /// gone — both now go to 4 columns at `PosResponsive.desktopFloor` (1024)
  /// instead, the same floor Home/Payment share, so the dashboard doesn't
  /// re-wrap at a width nothing else on the screen reacts to. See
  /// `_Dashboard` in `pos_report_screen.dart`.
  static const double stackWidth = 720;
}
