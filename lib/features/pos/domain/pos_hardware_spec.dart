import 'package:flutter/material.dart';

/// Design tokens for POS Settings → Hardware (Figma node **1641:8685**).
///
/// Sibling to `PosSettingsSpec` in the same way `PosProductsSettingsSpec` is:
/// the shared Settings palette/metrics stay in `PosSettingsSpec`, and only what
/// is specific to this frame — the toggle rows and the receipt preview card —
/// lives here.
class PosHardwareSpec {
  PosHardwareSpec._();

  // ── Two-column layout ────────────────────────────────────────────────
  /// Measured against the *content* width the panel is handed, not the window:
  /// the shared sidebar (192) and panel padding (2x32) are already spent by the
  /// time this widget lays out. The Figma frame is 1152 wide, which leaves 896
  /// here — so the threshold has to sit below that or the reference width would
  /// stack instead of showing two columns.
  static const double twoColumnBreakpoint = 860;

  /// Figma's preview card spans x=836..1120 on the 1152 frame.
  static const double previewColumnWidth = 284;
  static const double columnGap = 32;

  // ── Toggle row ("Auto-Print Receipts") ───────────────────────────────
  static const double toggleRowRadius = 12;
  static const EdgeInsets toggleRowPadding =
      EdgeInsets.symmetric(horizontal: 18, vertical: 16);
  static const double toggleRowGap = 12;
  static const double toggleTitleSize = 15;
  static const double toggleSubtitleSize = 12.5;
  static const double toggleTextGap = 4;

  // ── Group headings ("Printer", "Receipt Format") ─────────────────────
  static const double groupTitleSize = 16;
  static const double groupGap = 14;
  static const double blockGap = 28;
  static const double helperGap = 8;
  static const double helperSize = 12;

  // ── Pills ────────────────────────────────────────────────────────────
  static const double pillHeight = 36;
  static const double pillRadius = 18;
  static const double pillLabelSize = 12.5;
  static const double pillBorder = 1.5;
  static const double pillGap = 10;
  static const EdgeInsets pillPadding = EdgeInsets.symmetric(horizontal: 16);

  // ── Live preview card ────────────────────────────────────────────────
  static const String previewCaption = 'LIVE PREVIEW';
  static const double captionSize = 11.5;
  static const double captionTracking = 1.2;
  static const double previewCardRadius = 14;
  static const EdgeInsets previewCardPadding =
      EdgeInsets.symmetric(horizontal: 20, vertical: 22);
  static const Color previewCardBg = Colors.white;
  static const Color previewInk = Color(0xFF1A1614);
  static const Color previewRule = Color(0xFFCFC8B4);

  static const List<BoxShadow> previewShadow = [
    BoxShadow(
      color: Color(0x12241F20),
      offset: Offset(0, 6),
      blurRadius: 18,
    ),
  ];

  /// Thermal tickets are 72 mm at ~10 px monospace. These sizes reproduce that
  /// density on screen; the card scrolls horizontally rather than wrapping if a
  /// long store name ever exceeds the column.
  static const double receiptBrandSize = 13;
  static const double receiptBodySize = 10.5;
  static const double receiptSmallSize = 8.5;
  static const double receiptTotalSize = 12;
  static const double receiptLineGap = 2;
  static const double receiptBlockGap = 10;
}
