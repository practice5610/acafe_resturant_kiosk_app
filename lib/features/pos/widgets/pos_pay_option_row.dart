import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_payment_spec.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';

/// A full-width choice row with a disc radio — the split chooser's "By item /
/// Custom amount" (nodes 1915:11090 / 11096) and the refund reason / method
/// options (nodes 1915:11411 / 11515).
///
/// White, r12; selected 1.5px ink stroke, idle 1px `#E8E3D6`. These frames
/// count the stroke in the row's height (69 / 68, 55 / 54), so it is a layout
/// border here, unlike the payment tiles. Loew Bold 15 over an optional
/// Swiss 721 11 line (gap-3), and a 24px [PosPayOptionRadio].
class PosPayOptionRow extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback? onTap;

  /// p-16 on the split chooser, px-16 py-14 on the refund options.
  final EdgeInsetsGeometry padding;

  const PosPayOptionRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.padding = const EdgeInsets.symmetric(
      horizontal: PosPaymentSpec.v2OptionPaddingH,
      vertical: PosPaymentSpec.v2OptionPaddingV,
    ),
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: PosHomeSpec.tileBg,
            border: Border.all(
              color: selected
                  ? PosHomeSpec.ink
                  : PosPaymentSpec.v2OptionIdleBorder,
              width: selected
                  ? PosPaymentSpec.v2OptionSelectedBorderWidth
                  : PosPaymentSpec.v2OptionIdleBorderWidth,
            ),
            borderRadius: BorderRadius.circular(PosPaymentSpec.v2OptionRadius),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: loewBold.copyWith(
                        fontSize: PosPaymentSpec.v2OptionLabelSize,
                        color: PosHomeSpec.ink,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: PosPaymentSpec.v2OptionTextGap),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: swiss721Light.copyWith(
                          fontSize: PosPaymentSpec.v2OptionSubtitleSize,
                          height: PosPaymentSpec.figmaLeading(
                              PosPaymentSpec.v2OptionSubtitleSize),
                          color: PosPaymentSpec.v2OptionSubtitleInk,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: PosPaymentSpec.v2OptionGap),
              PosPayOptionRadio(selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}

/// 24px: an ink disc with a `#F0EBD9` r5 dot (node 1915:11094 / 11414), or a
/// 1.5px `#B9B5A6` ring (node 1915:11100 / 11419).
class PosPayOptionRadio extends StatelessWidget {
  final bool selected;

  const PosPayOptionRadio({super.key, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: PosPaymentSpec.v2OptionRadioSize,
      height: PosPaymentSpec.v2OptionRadioSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? PosHomeSpec.ink : null,
        border: selected
            ? null
            : Border.all(
                color: PosHomeSpec.itemDivider,
                width: PosPaymentSpec.v2OptionSelectedBorderWidth,
              ),
      ),
      child: selected
          ? Container(
              width: PosPaymentSpec.v2OptionRadioDot,
              height: PosPaymentSpec.v2OptionRadioDot,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: PosPaymentSpec.v2OptionRadioDotColor,
              ),
            )
          : null,
    );
  }
}

/// A section caption inside the split / refund panes — "DIVIDE BETWEEN
/// GUESTS", "SELECT ITEMS FOR PAYMENT N", "PAY WITH", "ITEMS TO REFUND":
/// Loew Bold 11, `#78706E` (node 1915:11089).
class PosPaySectionLabel extends StatelessWidget {
  final String text;

  const PosPaySectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: loewBold.copyWith(
        fontSize: PosPaymentSpec.v2SectionLabelSize,
        color: PosPaymentSpec.v2SectionLabelInk,
      ),
    );
  }
}
