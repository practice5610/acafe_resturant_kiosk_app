import 'package:flutter/material.dart';
import 'package:acafe_customer/theme/text_legibility.dart';

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

  // ── Header (Figma 1915:17909 / 17910) ────────────────────────────────
  static const double titleSize = 28;
  static const double subtitleSize = 15;

  // ── Fields (Figma 1915:17932 / 17934) ────────────────────────────────
  static const double fieldLabelSize = 14;
  static const double fieldValueSize = 15;

  /// "Save Changes" (Figma 1915:17912).
  static const double saveLabelSize = 15;

  // ── Toggle row ("Auto-Print Receipts") ───────────────────────────────
  static const double toggleRowRadius = 12;
  static const EdgeInsets toggleRowPadding =
      EdgeInsets.symmetric(horizontal: 18, vertical: 16);
  static const double toggleRowGap = 12;
  static const double toggleTitleSize = 15;
  static const double toggleSubtitleSize = 13;
  static const double toggleTextGap = 4;

  // ── Group headings ("Printer", "Receipt Format") ─────────────────────
  static const double groupTitleSize = 16;
  static const double groupGap = 14;
  static const double blockGap = 28;
  static const double helperGap = 8;

  /// "Preview: AC-0001" (Figma 1915:17935).
  static const double helperSize = 13;

  /// Copy with no Figma node (kitchen-printer note, preview disclaimer).
  static const double noteSize = 12;

  /// Muted copy on this frame — subtitle, toggle descriptions, helper,
  /// "Use store name", the Live Preview caption (Figma 1915:17910). Figma's
  /// `#7C7661` is 4.0:1 on the page; drawn in the secondary tone.
  static const Color mutedText = TextTones.secondary;

  // ── Pills ────────────────────────────────────────────────────────────
  static const double pillHeight = 36;
  static const double pillRadius = 18;
  static const double pillLabelSize = 16.2; // Figma 1915:17974
  static const double pillBorder = 1.5;
  static const Color pillInk = Color(0xFF000000);
  static const double pillGap = 10;
  static const EdgeInsets pillPadding = EdgeInsets.symmetric(horizontal: 16);

  // ── Live preview card ────────────────────────────────────────────────
  static const String previewCaption = 'LIVE PREVIEW';
  static const double captionSize = 14; // Figma 1915:17982
  static const double previewCardRadius = 14;
  static const EdgeInsets previewCardPadding =
      EdgeInsets.symmetric(horizontal: 20, vertical: 22);
  static const Color previewCardBg = Colors.white;
  // Receipt inks (Figma 1915:17983). Header, address, KvK and footer are
  // Loew; every row from "Datum" to "AKKOORD" is JetBrains Mono.
  static const Color previewInk = Color(0xFF241F20);
  static const Color previewGrey = Color(0xFF808080);
  static const Color previewDark = Color(0xFF4D4D4D);
  static const Color previewMuted = mutedText;
  static const Color previewRule = Color(0xFFE1DBC4);

  static const List<BoxShadow> previewShadow = [
    BoxShadow(
      color: Color(0x12241F20),
      offset: Offset(0, 6),
      blurRadius: 18,
    ),
  ];

  /// Receipt text sizes, one per Figma line style (1915:17994–1915:18087).
  static const double receiptBrandSize = 14;
  static const double receiptAddressSize = 11;
  static const double receiptMetaSize = 11;
  static const double receiptKassaSize = 10;
  static const double receiptItemSize = 12;
  static const double receiptAddonSize = 10;
  static const double receiptTotalSize = 14;
  static const double receiptPaySize = 10;
  static const double receiptTerminalSize = 9;
  static const double receiptKvkSize = 10;
  static const double receiptFooterSize = 11;
  static const double receiptLineGap = 2;
  static const double receiptBlockGap = 10;
}
