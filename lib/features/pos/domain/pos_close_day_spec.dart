import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/theme/text_legibility.dart';
import 'package:flutter/material.dart';

/// Close Day modal — Figma **1915:18618** (Step 1), **1915:18940** (Step 1 with
/// the denomination table open), **1915:19286** / **1915:19604** (Step 2).
///
/// Authored against the 560×719 modal card on the 1366 frame. Values are
/// literal design px from those nodes. Strokes are drawn inside, as Figma
/// does, so outlined boxes and buttons keep the heights drawn.
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

  /// Step 1 tightens to 20 while the denomination table is open.
  static const double denomSectionGap = 20;

  /// The rules under the header and above the footer (Figma `Line`).
  static const Color dividerColor = PosHomeSpec.hairline;

  /// Figma 1915:18940 widens the card while the denomination table is open;
  /// the width eases over [cardResizeDuration] rather than jumping.
  static const double cardWidthDenomination = 580;
  static const Duration cardResizeDuration = Duration(milliseconds: 150);

  /// Card, fields and the quantity boxes.
  static const Color surface = Colors.white;

  /// Label on the filled secondary buttons (`Accept difference`) and the
  /// checkbox tick — Figma's `text-white`, not the page cream.
  static const Color onInk = Colors.white;

  // ── Type ─────────────────────────────────────────────────────────────
  /// Figma sets no letter-spacing. Pinned explicitly because the Material 3
  /// theme would lend every un-tracked line 0.25px (0.5 inside text fields).
  static const double tracking = 0;

  /// [face] (one of the app's Loew styles) at [size] in [color], with
  /// Figma's tracking pinned — see [tracking].
  static TextStyle text(
    TextStyle face,
    double size, {
    Color color = ink,
    double letterSpacing = tracking,
  }) =>
      face.copyWith(fontSize: size, color: color, letterSpacing: letterSpacing);
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
  static const Color stepColor = TextTones.secondary; // Figma 60% ink

  // ── Close button ─────────────────────────────────────────────────────
  /// Figma draws a bare 14px x-circle here — too small to find or hit on a
  /// touch till. The button is a cream disc in the Expected box's palette,
  /// centred on the title + step block, which at ~45px is tall enough to
  /// hold [closeHitSize] without pushing anything below it down.
  static const double closeButtonSize = 40;
  static const double closeHitSize = 44;
  static const double closeGlyphSize = 12;
  static const double closeGlyphStroke = 2;

  /// Title block → close button.
  static const double closeButtonGap = 16;
  static const Color closeFill = pageBg;
  static const Color closeFillHover = Color(0xFFF0E8D0);
  static const Color closeFillPressed = Color(0xFFE6DDC1);
  static const Color closeBorder = cardBorderColor;
  static const double closeFocusBorder = 2;
  static const double closePressedScale = 0.92;
  static const Duration closeStateDuration = Duration(milliseconds: 120);

  /// Figma's `rgba(36,31,32,0.6)` for labels and hints.
  static const Color inkMuted = TextTones.secondary; // Figma ink @0.6

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
  static const Color expectedHintColor = TextTones.hint; // Figma 40% ink
  static const Color expectedBorder = Color(0xFFE1DBC4);
  static const double hairlineWidth = 1;

  /// With the denomination table open the box drops its formula line and
  /// shrinks to one row.
  static const double expectedCompactPadding = 12;
  static const double expectedCompactLabelSize = 13;
  static const double expectedCompactAmountSize = 16;

  // ── Actual counted input ─────────────────────────────────────────────
  static const double inputGroupGap = 6;
  static const double inputLabelSize = 11;
  static const double inputRadius = 10;
  static const double inputBorder = 1.5;
  static const EdgeInsets inputPadding =
      EdgeInsets.symmetric(horizontal: 16, vertical: 12);
  static const double inputTextSize = 14;
  static const Color inputPlaceholder = TextTones.hint; // Figma 40% ink
  static const Color inputBorderColor = Color(0xFFE1DBC4);

  /// Keyboard focus: the stroke goes ink, as the denomination quantity boxes
  /// do, easing over [inputFocusDuration] rather than snapping.
  static const Color inputFocusBorderColor = ink;
  static const Duration inputFocusDuration = Duration(milliseconds: 120);

  /// The caret after the typed figure while the field has keyboard focus —
  /// Flutter's own text-field metrics: 2px wide, blinking every 500ms.
  static const double caretWidth = 2;

  /// Kept inside the 14px figure's line box, so focusing never moves the card.
  static const double caretHeight = 16;
  static const double caretGap = 1;
  static const Duration caretBlink = Duration(milliseconds: 500);

  /// Material 3 adds an `OutlineInputBorder`'s gap padding (4 by default) as
  /// horizontal padding inside the field; Figma's fields have none, and these
  /// carry no floating label that would need the notch.
  static const double fieldGapPadding = 0;

  /// The amount field while the table drives it: page-coloured, 10 top and
  /// bottom, the figure in ExtraBold.
  static const EdgeInsets inputFilledPadding =
      EdgeInsets.symmetric(horizontal: 16, vertical: 10);

  // ── Keypad (matches posPaymentKeypadStyle / Figma numeric-keypad) ────────
  static const double keypadGapAbove = 6; // group gap already covers label→field
  static const Color keypadBorder = Color(0xFFF0EBD8);

  // ── Denomination toggle ──────────────────────────────────────────────
  static const double denomChevronW = 10;
  static const double denomChevronH = 6;
  static const double denomGap = 8;
  static const double denomLabelSize = 14;

  // ── Denomination table (expanded — Figma 1915:18961) ─────────────────
  static const double denomHeaderSize = 10;
  static const Color denomHeaderColor = TextTones.hint; // Figma 40% ink

  /// Header row's own bottom padding, before the table's row gap.
  static const double denomHeaderGap = 4;
  static const double denomRowHeight = 34;
  static const double denomRowPadding = 6;
  static const double denomRowRadius = 8;

  /// Quantity and subtotal of a denomination nobody counted.
  static const Color denomZeroColor = TextTones.hint; // Figma 40% ink
  static const double denomRowGap = 6;
  static const double denomQtyWidth = 80;
  static const double denomQtyHeight = 22;
  static const double denomQtyRadius = 6;
  static const double denomQtyPaddingV = 4;
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

  // ── Step 2 Review & Confirm (Figma 1915:19286) ───────────────────────
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
  static const Color discrepancyRed = TextTones.danger; // Figma #EB5757 (3.1:1)
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
  static const double warningIconGap = 10;
  static const double warningTextSize = 13;

  static const double checkboxSize = 20;
  static const double checkboxRadius = 6;
  static const double checkboxBorder = 2;
  static const double checkboxGap = 12;
  static const double checkboxLabelSize = 14;
  static const double checkIconWidth = 10;
  static const double checkIconHeight = 8;
  static const double actionsListGap = 12;

  static const double pinLabelSize = 12;
  static const double pinLabelTracking = 0.5;
  static const double pinFieldRadius = 10;
  static const EdgeInsets pinFieldPadding =
      EdgeInsets.symmetric(horizontal: 14, vertical: 10);
  static const double reasonFieldRadius = 10;

  static const double footerHintSize = 12;
  static const double footerHintGap = 8;

  // ── Inset from screen edges on narrow terminals ──────────────────────
  static const double screenInset = 24;
}
