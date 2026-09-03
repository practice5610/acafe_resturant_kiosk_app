import 'package:flutter/material.dart';

/// Design tokens for POS product customize — Figma
/// `POS – Product Detail (Landscape)` node **1641:7080** (1280×1024).
class PosCustomizeSpec {
  PosCustomizeSpec._();

  static const double frameWidth = 1280;
  static const double frameHeight = 1024;

  /// Left customize pane width on the 1280 board (receipt takes the rest).
  static const double customizeWidth = 901;
  static const double receiptWidth = 379;

  static const Color pageBg = Color(0xFFF7F1DE);
  static const Color panelBg = Color(0xFFFBF8EF);
  static const Color ink = Color(0xFF0D0D0D);
  static const Color mutedBorder = Color(0xFFB9B5A6);
  static const Color plusLabel = Color(0xFFFAF9F5);

  static const double panePadding = 32;
  static const double sectionGap = 24;
  static const double sectionTitleGap = 16;
  static const double sectionTitleSize = 20;

  static const double backButton = 48;
  static const double backButtonRadius = 24;
  static const double backButtonBorder = 2;
  static const double backIcon = 16;
  static const double headerGap = 16;
  static const double titleSize = 24;

  static const double qtyButton = 42;
  static const double qtyRadius = 9;
  static const double qtyBorder = 1.875;
  static const double qtyGap = 12;
  static const double qtyGlyph = 21;
  static const double qtyValueSize = 24;

  // Dietary cards (Figma ~148.2 × 112.35)
  static const double dietaryCardWidth = 148.2;
  static const double dietaryCardHeight = 112.35;
  static const double dietaryCardRadius = 7.875;
  static const double dietaryCardGap = 10.8;
  static const double dietaryImage = 68;
  static const double dietaryLabelSize = 11.34;
  static const double dietaryBorder = 0.787;
  static const double dietaryBorderSelected = 1.313;
  static const double dietaryRadio = 11.1;

  // Add-on cards (Figma 203 × 160)
  static const double addonCardWidth = 203;
  static const double addonCardHeight = 160;
  static const double addonCardRadius = 7.875;
  static const double addonCardGapH = 5;
  static const double addonCardGapV = 20;
  static const double addonPriceSize = 9;
  static const double addonLabelSize = 11.25;
  static const double addonPadH = 6;
  static const double addonPadTop = 10;
  static const double addonPadBottom = 6;
  static const int addonColumns = 4;

  // Cup / can (Figma two large cards)
  static const double vesselCardHeight = 220;
  static const double vesselCardGap = 16;
  static const double vesselCardRadius = 12;
  static const double vesselLabelSize = 16;

  /// Footer strip under both panes (Figma `footer` 1641:7525).
  static const double footerHeight = 92;
  static const double footerPadH = 32;
  static const double footerPadV = 16;
  static const double footerBorder = 1.5;
  static const double ctaRadius = 20;
  static const double ctaLabelSize = 18;
  static const double ctaLetterSpacing = 0.72;

  static const double addonMiniQty = 18;
  static const double addonMiniQtyGap = 3;
  static const double addonMiniQtyRadius = 3.75;
  static const double addonMiniQtyBorder = 0.788;
  static const double addonMiniQtyGlyph = 14;
}
