import 'package:flutter/material.dart';

/// Tokens for the POS "Add tip" modal.
///
/// There is no tip-modal frame in the POS file, so the modal is built on the
/// layer's own modal — "Apply discount" (Figma **1915:14411**, 1080 wide):
/// the same header, two-column body, custom card with its % / € switch,
/// preview card and sticky ink bar. Values marked "discount" are read from that
/// node; the rest are the tip-specific parts (two-line preset tiles, the
/// keypad, the tip summary) sized on the same grid.
class PosTipSpec {
  PosTipSpec._();

  // ── Shell (discount 1915:14411) ─────────────────────────────────────────
  static const double modalMaxWidth = 1080;
  static const double modalRadius = 16;
  static const double modalBorderWidth = 1.5;
  static const Color modalBg = Color(0xFFFBF8EF);
  static const Color hairline = Color(0xFFEAE5D5);
  static const Color muted = Color(0xFF6F6A67);
  static const BoxShadow modalShadow = BoxShadow(
    color: Color(0x33000000), // rgba(0,0,0,0.2)
    offset: Offset(0, 18),
    blurRadius: 48,
    spreadRadius: -12,
  );
  static const Color scrim = Color(0x66241F20); // ink at 40%

  /// Around the modal on every side of the window.
  static const double screenMargin = 24;

  /// Below this modal width the two columns stack.
  static const double twoColumnMinWidth = 760;

  // ── Header (discount 1915:14412) ────────────────────────────────────────
  static const EdgeInsets headerPadding = EdgeInsets.fromLTRB(24, 22, 24, 18);
  static const double titleSize = 22; // Loew ExtraBold
  static const double descriptionSize = 13; // Swiss 721 Light, 18 line
  static const double descriptionLine = 18;
  static const double headingGap = 6;
  static const double closeSize = 30;
  static const double closeIconSize = 18;

  // ── Body (discount 1915:14418) ──────────────────────────────────────────
  static const double bodyPadding = 24;
  static const double columnGap = 32;
  static const double rightColumnWidth = 420;
  static const double leftSectionGap = 24;
  static const double rightSectionGap = 18;
  static const double sectionLabelSize = 11; // Loew Bold, tracking 1
  static const double sectionLabelTracking = 1;
  static const double labelToContentGap = 10;

  // ── Preset tiles (tip) ──────────────────────────────────────────────────
  /// Two lines — the percentage and what it comes to — so the operator sees
  /// the money before choosing.
  static const double presetHeight = 64;
  static const double presetRadius = 12;
  static const double presetGap = 12; // discount preset gap
  static const double presetLabelSize = 16; // Loew Bold
  static const double presetAmountSize = 12; // Swiss 721 Light
  static const double presetLineGap = 4;
  static const Color presetIdleBorder = Color(0xFFE8E3D5);
  static const double presetIdleBorderWidth = 1;
  static const Color presetActiveFill = Color(0xFF241F20);
  static const Color presetActiveAmount = Color(0xB3FFFFFF); // white 70%

  // ── Custom card (discount 1915:14426) ───────────────────────────────────
  static const Color customFill = Color(0xFFF7F1DE);
  static const double customRadius = 12;
  static const double customPadding = 16;
  static const double customGap = 12;
  static const double customLabelSize = 14; // Loew ExtraBold
  static const double customHintSize = 12; // Swiss 721 Light
  static const double customCopyGap = 4;

  // % / € switch (discount 1915:14431)
  static const double unitSwitchPadding = 3;
  static const EdgeInsets unitSegmentPadding =
      EdgeInsets.symmetric(horizontal: 13, vertical: 5);
  static const double unitLabelSize = 11; // Loew Bold

  // Input (discount 1915:14436)
  static const double inputHeight = 64;
  static const double inputRadius = 6;
  static const double inputBorderWidth = 1.5;
  static const double inputPaddingH = 16;
  static const double inputValueSize = 24; // Loew Bold
  static const double inputSuffixSize = 14; // Loew Bold
  static const Color inputPlaceholder = Color(0xFFB9B5A6);

  /// The payment keypad (78px keys) at 56px — it sits under the input inside
  /// the custom card.
  static const double keypadScale = 56 / 78;

  // ── Tip summary + preview (discount preview 1915:14464) ─────────────────
  static const double cardRadius = 12;
  static const double cardPadding = 16;
  static const double cardGap = 12;
  static const double summaryAmountSize = 40; // Loew ExtraBold, tip
  static const double summaryCaptionSize = 12; // Swiss 721 Light
  static const double previewRowSize = 13; // Loew Bold / ExtraBold for Total
  static const double previewRowGap = 10;
  static const Color tipGreen = Color(0xFF2A8456);
  static const Color errorInk = Color(0xFFB5490A);
  static const double noteSize = 12;

  // ── Sticky bar (discount 1915:14477) ────────────────────────────────────
  static const EdgeInsets barPadding = EdgeInsets.fromLTRB(24, 16, 24, 24);
  static const Color barFill = Color(0xFFF7F1DE);
  static const double barTopBorder = 2;
  static const BoxShadow barShadow = BoxShadow(
    color: Color(0x14241F20), // rgba(36,31,32,0.08)
    offset: Offset(0, -6),
    blurRadius: 16,
  );
  static const double buttonHeight = 64;
  static const double buttonRadius = 32;
  static const double buttonLabelSize = 18; // Loew Bold
  static const double buttonDisabledOpacity = 0.4;

  // ── Rules ───────────────────────────────────────────────────────────────
  /// The presets offered (0 = "No tip"), the kiosk's percentages.
  static const List<int> presets = [0, 5, 10, 15];

  /// A tip may not exceed the amount due — the guard against keying "500"
  /// for "5.00". Also the ceiling for a custom percentage.
  static const int maxPercent = 100;
}
