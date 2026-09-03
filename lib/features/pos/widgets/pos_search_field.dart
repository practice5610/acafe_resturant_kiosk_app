import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Product search above the grid. Filters the already-loaded branch menu
/// client-side — no network round trip, so it stays instant and works offline,
/// which matters on a counter terminal.
class PosSearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const PosSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: PosHomeSpec.searchHeight,
      padding: const EdgeInsets.symmetric(
          horizontal: PosHomeSpec.searchPaddingH),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(PosHomeSpec.searchRadius),
        border: Border.all(
          color: PosHomeSpec.ink,
          width: PosHomeSpec.searchBorder,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: PosHomeSpec.searchIconSize,
            height: PosHomeSpec.searchIconSize,
            child: SvgPicture.asset(
              Images.posSearchSvg,
              width: PosHomeSpec.searchIconSize,
              height: PosHomeSpec.searchIconSize,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: PosHomeSpec.searchGap),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              cursorColor: PosHomeSpec.ink,
              textAlignVertical: TextAlignVertical.center,
              style: loewRegular.copyWith(
                fontSize: PosHomeSpec.searchHintSize,
                color: PosHomeSpec.ink,
                height: PosHomeSpec.searchHintHeight,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'Search products..',
                hintStyle: loewRegular.copyWith(
                  fontSize: PosHomeSpec.searchHintSize,
                  color: PosHomeSpec.inkAlpha(0.4),
                  height: PosHomeSpec.searchHintHeight,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
