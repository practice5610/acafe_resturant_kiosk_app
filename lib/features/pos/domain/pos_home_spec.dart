import 'package:acafe_customer/helper/price_converter_helper.dart';
import 'package:flutter/material.dart';

/// Design tokens for the POS home screen, read from the Figma frame
/// `POS - Browse Products (Empty Cart)` (node **1642:1087**, 1366x1024).
///
/// Values are literal design pixels. The screen is authored at 1366 wide and
/// the three panes sum to it exactly (192 + 753 + 421), so the side panes hold
/// their measured widths and the centre pane takes the remainder.
class PosHomeSpec {
  PosHomeSpec._();

  // ── Palette (from the design file, not the general brand tokens) ──────
  static const Color pageBg = Color(0xFFF7F1DE);
  static const Color ink = Color(0xFF241F20);
  static const Color panelBg = Color(0xFFFBF8EF);
  static const Color tileBg = Colors.white;
  static const Color hairline = Color(0xFFF0EBD8);
  static const Color inactiveFill = Color(0xFFDED9C7);
  static const Color tableFieldBorder = Color(0xFFE0D9C8);

  static Color inkAlpha(double a) => ink.withValues(alpha: a);

  // ── Panes ────────────────────────────────────────────────────────────
  static const double sidebarWidth = 192;
  static const double receiptWidth = 421;
  static const double paneBorder = 2;

  // ── Category sidebar ─────────────────────────────────────────────────
  static const EdgeInsets sidebarPadding =
      EdgeInsets.symmetric(horizontal: 16, vertical: 24);
  static const double sidebarItemHeight = 56;
  static const double sidebarItemGap = 12;
  static const double sidebarItemPadding = 12;
  static const double sidebarItemRadius = 3;
  static const double sidebarLabelSize = 16;
  static const double sidebarLabelHeight = 19 / 16;
  static const double sidebarRuleHeight = 2;
  static const double sidebarRuleOpacity = 0.25;

  // ── Content area ─────────────────────────────────────────────────────
  static const double contentPaddingLeft = 32;
  /// Smaller than the left inset: the 4px scroll track sits in this gutter.
  static const double contentPaddingRight = 24;
  static const double contentPaddingTop = 24;

  static const double searchHeight = 50;
  static const double searchRadius = 25;
  static const double searchBorder = 1.5;
  static const double searchPaddingH = 20;
  static const double searchGap = 10;
  static const double searchIconSize = 20;
  static const double searchHintSize = 16;
  /// 19px line box at 16px, measured off `Search products..`.
  static const double searchHintHeight = 19 / 16;

  /// search -> pills, and pills -> grid.
  static const double sectionGap = 20;

  static const double pillHeight = 32;
  static const double pillRadius = 20;
  static const double pillGap = 8;
  static const double pillBorder = 1.5;
  static const double pillLabelSize = 13;
  static const EdgeInsets pillPadding =
      EdgeInsets.symmetric(horizontal: 18, vertical: 8);

  /// Merchandising tags from the Figma pill row. Filtering uses
  /// `filterKioskProductsByTag` / `normalizeKioskTag` so CEREMONIAL still
  /// matches the seeded `CEROMONIAL` spelling.
  static const List<String> filterPillLabels = [
    'POPULAR',
    'SIGNATURE',
    'SEASONAL',
    'SPECIALS',
    'PURE',
    'CEREMONIAL',
  ];

  static const double contentFadeHeight = 160;
  static const double scrollbarWidth = 4;
  static const double scrollbarThumbLength = 220;
  static const double scrollbarRadius = 2;
  /// Content-area right edge → scrollbar track (`x=737` in a 753 pane).
  static const double scrollbarInset = 12;
  static const double searchPaddingRight = 24;
  static const double gridPaddingRight = 25;

  static const int gridColumns = 3;
  static const double gridColumnGap = 16;
  static const double gridRowGap = 20;
  static const double tileWidth = 221.3333;
  static const double tileHeight = 320;
  static const double tilePadding = 16;
  static const double tileRadius = 16;
  static const double tileImageRadius = 8;
  /// Image block -> info block.
  static const double tileImageGap = 12;
  /// Text block -> the 22px action row beneath it.
  static const double tileInfoGap = 10;
  static const double tileNameGap = 3;
  static const double tileNameSize = 16;
  /// 19px line box at 16px (`Iced Strawberry`).
  static const double tileNameHeight = 19 / 16;
  static const double tileNameBox = 19;
  static const double tilePriceSize = 13;
  /// 16px line box at 13px (`€ 6.00`).
  static const double tilePriceHeight = 16 / 13;
  static const double tilePriceBox = 16;
  static const double tileTextBlockHeight = 38;
  static const double tileInfoHeight = 70;
  static const double tileImageHeight = 220;
  static const double tileBottomPadding = 2;
  static const double tileActionRowHeight = 22;
  static const double qtyBadgeSize = 26.4;
  static const double qtyBadgeLabelSize = 13.2;
  static const double qtyBadgeInset = 16;

  // ── Receipt panel ────────────────────────────────────────────────────
  static const double panelPaddingH = 24;

  static const double headerHeight = 75;
  static const double headerPaddingTop = 24;
  static const double headerPaddingBottom = 16;
  static const double headerTitleSize = 16;
  static const double headerTitleHeight = 19 / 16;
  static const double headerNumberSize = 12;
  static const double headerNumberHeight = 14 / 12;
  static const double headerTitleGap = 2;
  static const String placeholderOrderNumber = '27362';
  static const double optionsButtonSize = 32;
  static const double optionsButtonRadius = 16;
  static const double optionsIconSize = 17;

  static const double orderTypeHeight = 65;
  static const double orderTypePaddingTop = 16;
  static const double orderTypePaddingBottom = 12;
  static const double orderTypeGap = 7;
  static const double orderTypeRadius = 10;
  static const double orderTypeButtonHeight = 37;
  static const double orderTypeLabelSize = 14;
  static const double orderTypeLabelHeight = 17 / 14;
  static const EdgeInsets orderTypePadding =
      EdgeInsets.symmetric(horizontal: 20, vertical: 10);

  static const double orderListLabelSize = 14;
  static const double orderListLabelHeight = 17 / 14;
  static const double orderListLabelBlockHeight = 25;
  static const double orderListLabelPaddingBottom = 8;

  static const double fieldGap = 12;
  static const double fieldLabelGap = 6;
  static const double fieldLabelSize = 12;
  static const double fieldLabelHeight = 14 / 12;
  static const double fieldTextSize = 14;
  static const double fieldTextHeight = 17 / 14;
  static const double fieldRadius = 10;
  static const double fieldBorder = 1.5;
  static const double fieldInputHeight = 37;
  static const EdgeInsets fieldPadding =
      EdgeInsets.symmetric(horizontal: 14, vertical: 10);
  static const double tableFieldWidth = 80;
  static const double customerInfoHeight = 73;
  static const double customerInfoPaddingBottom = 16;

  static const double emptyStateGap = 12;
  static const double emptyHeadingSize = 16;
  static const double emptyHeadingHeight = 19 / 16;
  static const double emptySublineSize = 13;
  static const double emptySublineHeight = 16 / 13;

  static const double summaryHeight = 97;
  /// Cart-active payment block from the hidden `payment-details` variant.
  static const double summaryHeightWithDiscount = 122;
  static const double summaryPaddingTop = 16;
  /// Right pad inside the grid viewport so cards stay 696 in a 753 pane
  /// (25px from the pane edge minus the 12px scrollbar inset already applied).
  static const double gridViewportRightPad = 13;
  static const double scrollbarTrackBottom = 130;
  static const double summaryGap = 8;
  static const double summaryRowSize = 16;
  static const double summaryRowHeight = 19 / 16;
  static const double summaryTotalSize = 24;
  static const double summaryTotalHeight = 29 / 24;

  /// Figma prices are `€ 6.00` / `€ 00.00` — a space after the symbol, and
  /// two digits before the decimal when the amount is zero.
  static String formatPrice(double amount) {
    final String raw = PriceConverterHelper.convertPrice(amount);
    if (amount == 0) {
      return raw.replaceFirst(RegExp(r'0+[.,]00'), '00.00').replaceFirstMapped(
            RegExp(r'^([^\d\s.,-]+)(\d)'),
            (m) => '${m[1]} ${m[2]}',
          );
    }
    return raw.replaceFirstMapped(
      RegExp(r'^([^\d\s.,-]+)(\d)'),
      (m) => '${m[1]} ${m[2]}',
    );
  }
}
