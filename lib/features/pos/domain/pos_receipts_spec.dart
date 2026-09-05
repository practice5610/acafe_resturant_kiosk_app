import 'package:flutter/material.dart';

/// Figma **1641:3228** — the Receipts list pane (`receipts-list-area`,
/// 1641:3232) and the split against the detail sidebar.
///
/// Only the left pane needs its own tokens: the right pane is the Purchase
/// Receipt panel the POS Payment screen already draws, so it reads
/// [PosHomeSpec] like every other consumer of those widgets.
class PosReceiptsSpec {
  PosReceiptsSpec._();

  // ── Split ────────────────────────────────────────────────────────────
  /// `receipt-details-sidebar` (1641:3300).
  static const double sidebarWidth = 400;

  /// Below this the two panes stop fitting side by side and the list gets the
  /// full width, with the selected receipt opening as a sheet. Chosen to match
  /// the payment screen's own threshold so the two POS split layouts break at
  /// the same place.
  static const double stackedBelowWidth = 900;

  // ── Pane ─────────────────────────────────────────────────────────────
  static const double panePadding = 24;
  static const double paneGap = 20;

  // ── Search (1641:3234) ───────────────────────────────────────────────
  static const double searchWidth = 320;
  static const double searchHeight = 44;
  static const double searchRadius = 22;
  static const double searchPaddingH = 16;
  static const double searchGap = 8;
  static const double searchIconSize = 16;
  static const double searchTextSize = 14;
  static const double searchHintOpacity = 0.25;

  // ── Filter pills (1641:3239) ─────────────────────────────────────────
  static const double filterRadius = 8;
  static const double filterPaddingH = 16;
  static const double filterPaddingV = 10;
  static const double filterGap = 6;
  static const double filterRowGap = 8;
  static const double filterLabelSize = 13;
  static const double filterChevronSize = 12;

  /// Menu row height for the dropdown the pills open.
  static const double filterMenuItemHeight = 40;

  // ── Table (1641:3257) ────────────────────────────────────────────────
  static const double tableRadius = 12;
  static const double tableBorder = 1;
  static const double cellPadding = 16;
  static const double columnGap = 20;
  static const double headerTextSize = 12;
  static const double rowTextSize = 13;

  static const double receiptColumn = 80;
  static const double dateColumn = 150;
  static const double customerColumn = 100;
  static const double methodColumn = 80;
  static const double amountColumn = 80;

  /// Below this the fixed columns no longer fit beside a readable Products
  /// cell, so the narrow columns are dropped rather than squeezed.
  static const double compactTableBelowWidth = 720;

  /// Everything but Products is fixed-width; this is what they cost together,
  /// used to decide whether the full column set still fits.
  static const double fixedColumnsWidth = receiptColumn +
      dateColumn +
      customerColumn +
      methodColumn +
      amountColumn +
      (columnGap * 5) +
      (cellPadding * 2);

  // ── Colours ──────────────────────────────────────────────────────────
  static const Color fieldBorder = Color(0xFFE1DBC4);
  static const Color rowDivider = Color(0xFFF0EBD8);
  static const Color surface = Colors.white;

  /// Text on the selected (ink-filled) row.
  static const Color selectedInk = Colors.white;

  // ── Print button (1641:3374) ─────────────────────────────────────────
  static const double printButtonHeight = 47;
  static const double printButtonRadius = 24;
  static const double printButtonBorder = 1.5;
  static const double printLabelSize = 16;
  static const double printPaddingH = 24;
  static const double printPaddingBottom = 24;

  // ── Detail states ────────────────────────────────────────────────────
  static const double emptyHeadingSize = 20;
  static const double emptySublineSize = 14;
  static const double emptyGap = 8;
}
