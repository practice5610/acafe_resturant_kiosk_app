import 'package:flutter/material.dart';

/// Figma **1641:6042** — Close Day Step 1 / Count Cash Drawer modal.
///
/// Authored against the 560×719 modal card on the 1366 frame. Values are
/// literal design px from that node.
class PosCloseDaySpec {
  PosCloseDaySpec._();

  // ── Overlay / card ───────────────────────────────────────────────────
  static const Color backdrop = Color(0x99241F20); // rgba(36,31,32,0.6)
  static const double cardWidth = 560;
  static const double cardRadius = 18;
  static const double cardBorder = 2;
  static const Color cardBorderColor = Color(0xFFE1DBC4);
  static const double cardPadding = 32;
  static const double sectionGap = 24;
  static const List<BoxShadow> cardShadow = <BoxShadow>[
    BoxShadow(
      color: Color(0x26000000), // 15% black
      offset: Offset(0, 12),
      blurRadius: 16,
    ),
  ];

  // ── Header ───────────────────────────────────────────────────────────
  static const double titleSize = 20;
  static const double stepSize = 13;
  static const double headerGap = 8;
  static const double closeIconSize = 14;
  static const Color stepColor = Color(0x99241F20); // 60% ink

  // ── Body copy ────────────────────────────────────────────────────────
  static const double sectionTitleSize = 16;
  static const Color ink = Color(0xFF241F20);
  static const Color pageBg = Color(0xFFF7F1DE);

  // ── Expected box ─────────────────────────────────────────────────────
  static const double expectedRadius = 12;
  static const double expectedPadding = 16;
  static const double expectedGap = 8;
  static const double expectedLabelSize = 14;
  static const double expectedAmountSize = 18;
  static const double expectedHintSize = 12;
  static const Color expectedHintColor = Color(0x66241F20); // 40% ink
  static const Color expectedBorder = Color(0xFFE1DBC4);

  // ── Actual counted input ─────────────────────────────────────────────
  static const double inputGroupGap = 6;
  static const double inputLabelSize = 11;
  static const double inputRadius = 10;
  static const double inputBorder = 1.5;
  static const EdgeInsets inputPadding =
      EdgeInsets.symmetric(horizontal: 16, vertical: 12);
  static const double inputTextSize = 14;
  static const Color inputPlaceholder = Color(0x66241F20); // 40% ink
  static const Color inputBorderColor = Color(0xFFE1DBC4);

  // ── Keypad (matches posCashKeypadStyle / Figma numeric-keypad) ────────
  static const double keypadGapAbove = 6; // group gap already covers label→field
  static const Color keypadBorder = Color(0xFFF0EBD8);

  // ── Denomination toggle ──────────────────────────────────────────────
  static const double denomChevronW = 10;
  static const double denomChevronH = 6;
  static const double denomGap = 8;
  static const double denomLabelSize = 14;

  // ── Denomination table (expanded — sibling frame 1641:6101) ──────────
  static const double denomHeaderSize = 11;
  static const double denomRowHeight = 34;
  static const double denomRowGap = 6;
  static const double denomQtyWidth = 80;
  static const double denomQtyHeight = 22;
  static const double denomQtyRadius = 6;
  static const double denomSubtotalWidth = 100;
  static const double denomValueSize = 13;
  static const double denomQtySize = 12;

  /// Euro denomination minor units, largest first — Figma denomination rows.
  static const List<int> denominationCents = <int>[
    5000, 2000, 1000, 500, 200, 100, 50, 20, 10, 5,
  ];

  // ── Footer ───────────────────────────────────────────────────────────
  static const double footerGap = 16;
  static const double buttonRadius = 12;
  static const double buttonBorder = 1.5;
  static const EdgeInsets buttonPadding =
      EdgeInsets.symmetric(horizontal: 24, vertical: 14);
  static const double buttonTextSize = 14;
  static const double continueDisabledOpacity = 0.30;

  // ── Step 2 Review & Confirm (Figma 1641:6707) ────────────────────────
  static const double step2Gap = 20;
  static const double summaryRadius = 12;
  static const double summaryPadding = 16;
  static const double summaryColGap = 24;
  static const double summaryLabelSize = 11;
  static const double summaryValueSize = 18;
  static const double summaryInnerGap = 4;

  static const double discrepancyTitleSize = 14;
  static const double discrepancyBadgeRadius = 6;
  static const EdgeInsets discrepancyBadgePadding =
      EdgeInsets.symmetric(horizontal: 8, vertical: 4);
  static const double discrepancyBadgeSize = 13;
  static const Color discrepancyBadgeBg = Color(0xFFFDF0F0);
  static const Color discrepancyRed = Color(0xFFEB5757);
  static const double discrepancyActionGap = 12;
  static const double discrepancyHintSize = 12;
  static const double discrepancySectionGap = 10;
  static const EdgeInsets secondaryButtonPadding =
      EdgeInsets.symmetric(horizontal: 16, vertical: 10);
  static const double secondaryButtonRadius = 10;
  static const double secondaryButtonTextSize = 13;

  static const Color warningBannerBg = Color(0xFFFDF9EB);
  static const double warningBannerRadius = 10;
  static const EdgeInsets warningBannerPadding =
      EdgeInsets.symmetric(horizontal: 16, vertical: 12);
  static const double warningIconSize = 16;
  static const double warningTextSize = 13;

  static const double checkboxSize = 20;
  static const double checkboxRadius = 6;
  static const double checkboxBorder = 2;
  static const double checkboxGap = 12;
  static const double checkboxLabelSize = 14;
  static const double actionsListGap = 12;

  static const double pinLabelSize = 12;
  static const double pinFieldRadius = 10;
  static const EdgeInsets pinFieldPadding =
      EdgeInsets.symmetric(horizontal: 14, vertical: 10);
  static const double reasonFieldRadius = 10;

  static const double footerHintSize = 12;
  static const double footerHintGap = 8;

  // ── Inset from screen edges on narrow terminals ──────────────────────
  static const double screenInset = 24;
}
