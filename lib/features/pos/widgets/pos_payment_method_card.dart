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

  const PosPaymentMethodCard({
    super.key,
    required this.method,
    required this.selected,
    required this.onTap,
  });

  String get _label => method == PosPaymentMethod.cash ? 'Cash' : 'Card';

  String get _icon => method == PosPaymentMethod.cash
      ? Images.posBanknoteSvg
      : Images.posCreditCardSvg;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius =
        BorderRadius.circular(PosPaymentSpec.methodRadius);

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
            height: PosPaymentSpec.methodHeight,
            padding: const EdgeInsets.all(PosPaymentSpec.methodPadding),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: PosPaymentSpec.methodTopRowHeight,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _IconWell(asset: _icon, selected: selected),
                      _Radio(selected: selected),
                    ],
                  ),
                ),
                const SizedBox(height: PosPaymentSpec.methodInnerGap),
                Text(
                  _label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: loewBold.copyWith(
                    fontSize: PosPaymentSpec.methodLabelSize,
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

  const _IconWell({required this.asset, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: PosPaymentSpec.methodIconBox,
      height: PosPaymentSpec.methodIconBox,
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
        width: PosPaymentSpec.methodIconSize,
        height: PosPaymentSpec.methodIconSize,
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

  const _Radio({required this.selected});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: PosPaymentSpec.methodRadioSize,
      height: PosPaymentSpec.methodRadioSize,
      child: SvgPicture.asset(
        selected ? Images.posRadioOnSvg : Images.posRadioOffSvg,
        width: PosPaymentSpec.methodRadioSize,
        height: PosPaymentSpec.methodRadioSize,
        // A missing asset in a stale web AssetManifest must not leave the card
        // with no selection indicator at all — see the trash-icon note in
        // pos_receipt_line.dart.
        placeholderBuilder: (_) => Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
          size: PosPaymentSpec.methodRadioSize,
          color: selected ? PosHomeSpec.ink : PosHomeSpec.itemDivider,
        ),
      ),
    );
  }
}
