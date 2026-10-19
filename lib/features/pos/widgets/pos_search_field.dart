import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_orders_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_settings_spec.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Visual variants of [PosSearchField].
///
/// [PosSearchFieldStyle.pill] is the original product-grid look and stays the
/// default so existing call sites are unchanged. [PosSearchFieldStyle.settings]
/// is the shorter, square-cornered field the Settings frames use, and
/// [PosSearchFieldStyle.orders] the Orders board's filter-row pill.
@immutable
class PosSearchFieldStyle {
  final double height;
  final double radius;
  final Color borderColor;
  final double borderWidth;
  final double paddingH;
  final double gap;
  final double iconSize;
  final double textSize;
  final double? textHeight;
  final double hintAlpha;

  /// Field fill. White everywhere except the Orders board, which draws its
  /// filter controls straight on the page.
  final Color fillColor;

  /// Search glyph. The Orders board uses its own 14px Figma export.
  final String iconAsset;

  /// Tint for [iconAsset]. Null draws the SVG in its own colours, so the
  /// product grid and Orders board are unchanged.
  final Color? iconColor;

  /// Text tracking. Null inherits the theme's (M3 bodyLarge 0.5), which keeps
  /// the product grid unchanged.
  final double? letterSpacing;

  const PosSearchFieldStyle({
    required this.height,
    required this.radius,
    required this.borderColor,
    required this.borderWidth,
    required this.paddingH,
    required this.gap,
    required this.iconSize,
    required this.textSize,
    required this.hintAlpha,
    this.textHeight,
    this.fillColor = Colors.white,
    this.iconAsset = Images.posSearchSvg,
    this.iconColor,
    this.letterSpacing,
  });

  /// This style with its geometry and type multiplied by [factor]; strokes,
  /// colours and the icon stay as they are. The home screen passes
  /// [PosResponsive.homeScale] so the field grows and shrinks with its pane.
  PosSearchFieldStyle scaled(double factor) {
    if (factor == 1) return this;
    return PosSearchFieldStyle(
      height: height * factor,
      radius: radius * factor,
      borderColor: borderColor,
      borderWidth: borderWidth,
      paddingH: paddingH * factor,
      gap: gap * factor,
      iconSize: iconSize * factor,
      textSize: textSize * factor,
      textHeight: textHeight,
      hintAlpha: hintAlpha,
      fillColor: fillColor,
      iconAsset: iconAsset,
      iconColor: iconColor,
      letterSpacing: letterSpacing == null ? null : letterSpacing! * factor,
    );
  }

  /// Product grid / receipts (Figma home frames).
  static const PosSearchFieldStyle pill = PosSearchFieldStyle(
    height: PosHomeSpec.searchHeight,
    radius: PosHomeSpec.searchRadius,
    borderColor: PosHomeSpec.ink,
    borderWidth: PosHomeSpec.searchBorder,
    paddingH: PosHomeSpec.searchPaddingH,
    gap: PosHomeSpec.searchGap,
    iconSize: PosHomeSpec.searchIconSize,
    textSize: PosHomeSpec.searchHintSize,
    textHeight: PosHomeSpec.searchHintHeight,
    hintAlpha: 0.4,
  );

  /// Settings → Products / Orders filters (Figma **1641:4003**).
  static const PosSearchFieldStyle settings = PosSearchFieldStyle(
    height: 42,
    radius: 8,
    borderColor: PosSettingsSpec.fieldBorder,
    borderWidth: 1,
    paddingH: 16,
    gap: 12,
    iconSize: 18,
    textSize: 14,
    // Match the icon box so hint + glyph share one vertical center on web.
    textHeight: 18 / 14,
    hintAlpha: 0.6,
    // Figma 1915:17573: the glyph is ink at 60%, same as the hint.
    iconColor: Color(0x99241F20),
    letterSpacing: 0,
  );

  /// Orders board filter row (Figma **1915:15790**): the same outlined r20
  /// pill as every other control in that row.
  static const PosSearchFieldStyle orders = PosSearchFieldStyle(
    height: PosOrdersSpec.searchHeight,
    radius: PosOrdersSpec.filterPillRadius,
    borderColor: PosHomeSpec.ink,
    borderWidth: PosOrdersSpec.filterPillBorder,
    paddingH: PosOrdersSpec.searchPaddingH,
    gap: PosOrdersSpec.filterIconGap - PosOrdersSpec.searchPrefixFrameworkGap,
    iconSize: PosOrdersSpec.filterIconSize,
    textSize: PosOrdersSpec.searchTextSize,
    textHeight: PosOrdersSpec.filterIconSize / PosOrdersSpec.searchTextSize,
    hintAlpha: PosOrdersSpec.searchHintAlpha,
    fillColor: Colors.transparent,
    iconAsset: Images.posOrdersSearchSvg,
    // Figma's search text has no tracking; null would inherit M3's 0.5.
    letterSpacing: 0,
  );
}

/// Search field with icon + hint kept on one horizontal baseline.
///
/// Icon lives in [InputDecoration.prefixIcon] (not a sibling [Row] child) so
/// Flutter centers the glyph with the typed / placeholder text together —
/// the old Row layout drifted on web where TextField metrics differ from SVG.
class PosSearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  /// Defaults to the product-grid hint so existing callers stay unchanged.
  final String hintText;

  /// Defaults to the product-grid look so existing callers stay unchanged.
  final PosSearchFieldStyle style;

  /// Draws the Orders board's `close-btn` chip at the trailing edge. Null (the
  /// default) draws nothing, so existing callers are unchanged.
  final VoidCallback? onClear;

  const PosSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hintText = 'Search products..',
    this.style = PosSearchFieldStyle.pill,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final TextStyle textStyle = loewRegular.copyWith(
      fontSize: style.textSize,
      color: PosHomeSpec.ink,
      height: style.textHeight,
      letterSpacing: style.letterSpacing,
    );

    return SizedBox(
      height: style.height,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        cursorColor: PosHomeSpec.ink,
        textAlignVertical: TextAlignVertical.center,
        style: textStyle,
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: style.fillColor,
          contentPadding: EdgeInsets.only(right: style.paddingH),
          prefixIcon: Padding(
            padding: EdgeInsets.only(left: style.paddingH, right: style.gap),
            child: SvgPicture.asset(
              style.iconAsset,
              width: style.iconSize,
              height: style.iconSize,
              fit: BoxFit.contain,
              alignment: Alignment.center,
              colorFilter: style.iconColor == null
                  ? null
                  : ColorFilter.mode(style.iconColor!, BlendMode.srcIn),
            ),
          ),
          prefixIconConstraints: BoxConstraints(
            minWidth: style.paddingH + style.iconSize + style.gap,
            minHeight: style.height - style.borderWidth * 2,
          ),
          suffixIcon: onClear == null ? null : _ClearChip(onTap: onClear!),
          suffixIconConstraints: onClear == null
              ? null
              : BoxConstraints(
                  minHeight: style.height - style.borderWidth * 2,
                ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(style.radius),
            borderSide: BorderSide(
              color: style.borderColor,
              width: style.borderWidth,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(style.radius),
            borderSide: BorderSide(
              color: style.borderColor,
              width: style.borderWidth,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(style.radius),
            borderSide: BorderSide(
              color: style.borderColor,
              width: style.borderWidth,
            ),
          ),
          hintText: hintText,
          hintStyle: textStyle.copyWith(
            color: PosHomeSpec.inkAlpha(style.hintAlpha),
          ),
        ),
      ),
    );
  }
}

/// `close-btn` (Figma 1915:15794): a small filled chip with a 10px ×.
class _ClearChip extends StatelessWidget {
  final VoidCallback onTap;

  const _ClearChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius =
        BorderRadius.circular(PosOrdersSpec.searchClearRadius);

    // Align, so the chip keeps its own 16px height instead of being stretched
    // to the field's by the suffix slot's constraints.
    return Padding(
      padding: const EdgeInsets.only(right: PosOrdersSpec.searchPaddingH),
      child: Align(
        widthFactor: 1,
        child: Tooltip(
          message: 'Clear search',
          child: Material(
            color: PosOrdersSpec.searchClearFill,
            borderRadius: radius,
            child: InkWell(
              onTap: onTap,
              borderRadius: radius,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: PosOrdersSpec.searchClearPadH,
                  vertical: PosOrdersSpec.searchClearPadV,
                ),
                child: SvgPicture.asset(
                  Images.posOrdersClearSvg,
                  width: PosOrdersSpec.searchClearIconSize,
                  height: PosOrdersSpec.searchClearIconSize,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
