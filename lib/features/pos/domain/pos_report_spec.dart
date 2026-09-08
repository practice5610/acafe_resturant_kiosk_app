import 'package:flutter/material.dart';

/// Figma **1641:5518** — Report Overview.
///
/// Authored against the 1366px frame in the design file, not the 1920px board
/// the rest of POS uses. That difference is why this screen keeps its own
/// tokens instead of borrowing [PosHomeSpec]: the numbers below are literal
/// Figma values and only mean anything against that frame. They still travel
/// through `posPx()` like every other POS token, so density still follows
/// [PosMetrics].
class PosReportSpec {
  PosReportSpec._();

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
  static const double cardGap = 12;

  // ── Card ─────────────────────────────────────────────────────────────
  static const double cardRadius = 16;
  static const double cardPadding = 16;
  static const double cardInnerGap = 12;

  /// Panel titles: 16 in the middle row, 15 in the bottom row.
  static const double panelTitleSize = 16;
  static const double panelTitleSizeSmall = 15;

  /// Fixed height for the title row. Some panels carry a pill in that row and
  /// some do not; without a common height the four bottom cards start their
  /// content at different depths and the row visibly fails to line up.
  static const double panelTitleHeight = 26;

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

  // ── Responsive breakpoints (logical px of the content area) ──────────
  /// Below this the four KPI cards stop fitting in one row and go 2x2.
  static const double kpiWrapWidth = 1040;

  /// Below this the four bottom panels go 2x2, and below [stackWidth] they
  /// become a single column along with the two middle panels.
  static const double bottomWrapWidth = 1180;
  static const double stackWidth = 720;
}
