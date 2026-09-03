import 'package:flutter/material.dart';

/// Design tokens for POS Settings → General (Figma node **1641:3896**,
/// artboard 1366×1024).
///
/// Values are literal design pixels. The sidebar width matches the home
/// category rail so the date in [PosTopNavBar] stays aligned across tabs.
class PosSettingsSpec {
  PosSettingsSpec._();

  // ── Palette ──────────────────────────────────────────────────────────
  static const Color pageBg = Color(0xFFF7F1DE);
  static const Color ink = Color(0xFF241F20);
  static const Color fieldBorder = Color(0xFFE1DBC4);
  static const Color fieldFill = Colors.white;
  static const Color divider = Color(0xFFE1DBC4);

  static Color inkMuted([double a = 0.6]) => ink.withValues(alpha: a);

  // ── Sidebar (same metrics as PosHomeSpec category rail) ──────────────
  static const double sidebarWidth = 192;
  static const double paneBorder = 1;
  static const EdgeInsets sidebarPadding =
      EdgeInsets.symmetric(horizontal: 16, vertical: 24);
  static const double sidebarItemHeight = 56;
  static const double sidebarItemGap = 12;
  static const double sidebarItemPadding = 12;
  static const double sidebarItemRadius = 3;
  static const double sidebarLabelSize = 16;
  static const double sidebarRuleHeight = 2;
  static const double sidebarRuleOpacity = 1.0;
  static const double sidebarRuleWidth = 136;

  // ── Detail panel ─────────────────────────────────────────────────────
  static const EdgeInsets panelPadding = EdgeInsets.all(32);
  static const double headerGap = 4;
  static const double sectionGap = 24;
  static const double fieldGap = 16;
  static const double labelGap = 8;

  static const double titleSize = 24;
  static const double subtitleSize = 14;
  static const double sectionTitleSize = 16;
  static const double labelSize = 13;
  static const double fieldTextSize = 14;

  static const double fieldRadius = 12;
  static const double fieldBorderWidth = 1;
  static const EdgeInsets fieldPadding =
      EdgeInsets.symmetric(horizontal: 16, vertical: 14);
  static const double chevronSize = 18;

  // ── Save button ──────────────────────────────────────────────────────
  static const double saveRadius = 12;
  static const EdgeInsets savePadding =
      EdgeInsets.symmetric(horizontal: 18, vertical: 12);
  static const double saveLabelSize = 14;
  static const List<BoxShadow> saveShadow = [
    BoxShadow(
      color: Color(0x33241F20),
      offset: Offset(0, 6),
      blurRadius: 8,
    ),
  ];
}
