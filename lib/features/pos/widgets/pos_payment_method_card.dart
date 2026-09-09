import 'dart:math' as math;

import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_payment_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_sale_session.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// One tender option from `method-selectors` (Figma 1641:2841).
///
/// Selection is drawn three ways at once — a black outline, a filled icon well
/// and a filled radio — because a counter screen is read at a glance and from
/// an angle, where a border alone is easy to miss. Figma only paints the
/// selected Card variant; the idle treatment is taken from the Cash card in
/// the same frame, so the pair is symmetric by construction.
class PosPaymentMethodCard extends StatelessWidget {
  final PosPaymentMethod method;
  final bool selected;
  final VoidCallback onTap;

  /// Fitted density for the medium/laptop band. Defaults to full size, which
  /// is the only size this card ever drew before [PosPaymentDensity] existed.
  final PosPaymentDensity density;

  const PosPaymentMethodCard({
    super.key,
    required this.method,
    required this.selected,
    required this.onTap,
    this.density = PosPaymentDensity.full,
  });

  String get _label => method == PosPaymentMethod.cash ? 'Cash' : 'Card';

  String get _icon => method == PosPaymentMethod.cash
      ? Images.posBanknoteSvg
      : Images.posCreditCardSvg;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius =
        BorderRadius.circular(PosPaymentSpec.methodRadius);

    // The design's 95px is padding + a fixed icon row + a label line, with a
    // few px of slack at full size. Text shrinks slower than spacing (see
    // [PosPaymentDensity]), so below full density that slack can invert into
    // an overflow — never shrink past what the label actually needs.
    final double contentHeight = density.px(PosPaymentSpec.methodPadding) * 2 +
        density.px(PosPaymentSpec.methodTopRowHeight) +
        density.px(PosPaymentSpec.methodInnerGap) +
        density.text(PosPaymentSpec.methodLabelSize) *
            PosPaymentSpec.methodLabelHeight;
    final double height =
        math.max(density.px(PosPaymentSpec.methodHeight), contentHeight);

    return Semantics(
      button: true,
      selected: selected,
      label: _label,
      child: Material(
        color: PosHomeSpec.tileBg,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            constraints: BoxConstraints(minHeight: height),
            padding: EdgeInsets.all(density.px(PosPaymentSpec.methodPadding)),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: selected
                    ? PosPaymentSpec.methodSelectedBorder
                    : PosHomeSpec.hairline,
                width: PosPaymentSpec.methodBorder,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: density.px(PosPaymentSpec.methodTopRowHeight),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _IconWell(
                          asset: _icon, selected: selected, density: density),
                      _Radio(selected: selected, density: density),
                    ],
                  ),
                ),
                SizedBox(height: density.px(PosPaymentSpec.methodInnerGap)),
                Text(
                  _label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: loewBold.copyWith(
                    fontSize: density.text(PosPaymentSpec.methodLabelSize),
                    color: PosHomeSpec.ink,
                    height: PosPaymentSpec.methodLabelHeight,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IconWell extends StatelessWidget {
  final String asset;
  final bool selected;
  final PosPaymentDensity density;

  const _IconWell(
      {required this.asset, required this.selected, required this.density});

  @override
  Widget build(BuildContext context) {
    final double box = density.px(PosPaymentSpec.methodIconBox);
    return Container(
      width: box,
      height: box,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? PosHomeSpec.ink : PosPaymentSpec.methodIdleIconBg,
        borderRadius:
            BorderRadius.circular(PosPaymentSpec.methodIconBoxRadius),
      ),
      // The two exports are authored for the state they appear in (banknote
      // dark on a pale well, credit-card white on a dark one), so both are
      // recoloured here rather than only one — otherwise Cash disappears the
      // moment it is selected.
      child: SvgPicture.asset(
        asset,
        width: density.px(PosPaymentSpec.methodIconSize),
        height: density.px(PosPaymentSpec.methodIconSize),
        colorFilter: ColorFilter.mode(
          selected ? PosHomeSpec.pageBg : PosHomeSpec.ink,
          BlendMode.srcIn,
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  final bool selected;
  final PosPaymentDensity density;

  const _Radio({required this.selected, required this.density});

  @override
  Widget build(BuildContext context) {
    final double size = density.px(PosPaymentSpec.methodRadioSize);
    return SizedBox(
      width: size,
      height: size,
      child: SvgPicture.asset(
        selected ? Images.posRadioOnSvg : Images.posRadioOffSvg,
        width: size,
        height: size,
        // A missing asset in a stale web AssetManifest must not leave the card
        // with no selection indicator at all — see the trash-icon note in
        // pos_receipt_line.dart.
        placeholderBuilder: (_) => Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
          size: size,
          color: selected ? PosHomeSpec.ink : PosHomeSpec.itemDivider,
        ),
      ),
    );
  }
}
