import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_settings_spec.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Visual variants of [PosSearchField].
///
/// [PosSearchFieldStyle.pill] is the original product-grid look and stays the
/// default so existing call sites are unchanged. [PosSearchFieldStyle.settings]
/// is the shorter, square-cornered field the Settings frames use.
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
  });

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

  const PosSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hintText = 'Search products..',
    this.style = PosSearchFieldStyle.pill,
  });

  @override
  Widget build(BuildContext context) {
    final TextStyle textStyle = loewRegular.copyWith(
      fontSize: style.textSize,
      color: PosHomeSpec.ink,
      height: style.textHeight,
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
          fillColor: Colors.white,
          contentPadding: EdgeInsets.only(right: style.paddingH),
          prefixIcon: Padding(
            padding: EdgeInsets.only(left: style.paddingH, right: style.gap),
            child: SvgPicture.asset(
              Images.posSearchSvg,
              width: style.iconSize,
              height: style.iconSize,
              fit: BoxFit.contain,
              alignment: Alignment.center,
            ),
          ),
          prefixIconConstraints: BoxConstraints(
            minWidth: style.paddingH + style.iconSize + style.gap,
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
