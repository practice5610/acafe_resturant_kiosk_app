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

  /// Settings → Products (Figma **1641:4003**).
  static const PosSearchFieldStyle settings = PosSearchFieldStyle(
    height: 42,
    radius: 8,
    borderColor: PosSettingsSpec.fieldBorder,
    borderWidth: 1,
    paddingH: 16,
    gap: 12,
    iconSize: 18,
    textSize: 14,
    hintAlpha: 0.6,
  );
}

/// Product search above the grid. Filters the already-loaded branch menu
/// client-side — no network round trip, so it stays instant and works offline,
/// which matters on a counter terminal.
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

    return Container(
      height: style.height,
      padding: EdgeInsets.symmetric(horizontal: style.paddingH),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(style.radius),
        border: Border.all(
          color: style.borderColor,
          width: style.borderWidth,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: style.iconSize,
            height: style.iconSize,
            child: SvgPicture.asset(
              Images.posSearchSvg,
              width: style.iconSize,
              height: style.iconSize,
              fit: BoxFit.contain,
            ),
          ),
          SizedBox(width: style.gap),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              cursorColor: PosHomeSpec.ink,
              textAlignVertical: TextAlignVertical.center,
              style: textStyle,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: hintText,
                hintStyle: textStyle.copyWith(
                  color: PosHomeSpec.inkAlpha(style.hintAlpha),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
