import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_payment_spec.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// A payment success state — Figma `success-card` (node **1915:9317**).
///
/// A distinct shell from the declined/error card: 640 wide, r20, a `#F0EBD8`
/// 1.5px border, a lighter shadow, and a pill button. Render-only in Phase 2a
/// (the live card/cash flow navigates home on success rather than showing this
/// card; it is built to the frame and ready to wire — the frame is the split
/// flow's "Payment 1 paid, continue" state).
class PosPaymentSuccessCard extends StatelessWidget {
  /// e.g. "Split Payment 1 Successful".
  final String title;
  final double amount;
  final String amountLabel;
  final String buttonLabel;
  final VoidCallback? onContinue;
  final bool busy;

  const PosPaymentSuccessCard({
    super.key,
    required this.title,
    required this.amount,
    required this.buttonLabel,
    required this.onContinue,
    this.amountLabel = 'AMOUNT PAID',
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final BorderRadius pill =
        BorderRadius.circular(PosPaymentSpec.v2SuccessButtonRadius);
    final bool enabled = onContinue != null && !busy;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(PosPaymentSpec.contentPadding),
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: PosPaymentSpec.v2SuccessCardWidth),
            child: Container(
              padding: const EdgeInsets.all(PosPaymentSpec.v2SuccessCardPadding),
              decoration: BoxDecoration(
                color: PosHomeSpec.panelBg,
                borderRadius:
                    BorderRadius.circular(PosPaymentSpec.v2SuccessCardRadius),
                border: Border.all(
                  color: PosHomeSpec.hairline, // #F0EBD8
                  width: PosPaymentSpec.v2SuccessCardBorder,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: PosPaymentSpec.v2SuccessShadow,
                    offset: PosPaymentSpec.v2SuccessShadowOffset,
                    blurRadius: PosPaymentSpec.v2SuccessShadowBlur,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // status-header (1915:9318): check + heading.
                  SvgPicture.string(
                    _checkSvg,
                    width: PosPaymentSpec.v2SuccessIconSize,
                    height: PosPaymentSpec.v2SuccessIconSize,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: PosPaymentSpec.v2SuccessHeaderGap),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: loewExtraBold.copyWith(
                      fontSize: PosPaymentSpec.v2SuccessHeadingSize,
                      color: PosHomeSpec.ink,
                    ),
                  ),
                  const SizedBox(height: PosPaymentSpec.v2SuccessCardGap),
                  _AmountPaid(amount: amount, label: amountLabel),
                  const SizedBox(height: PosPaymentSpec.v2SuccessCardGap),
                  // print-receipt-btn (1915:9326): dark pill.
                  Opacity(
                    opacity: enabled ? 1 : 0.5,
                    child: Material(
                      color: PosHomeSpec.ink,
                      borderRadius: pill,
                      child: InkWell(
                        onTap: enabled ? onContinue : null,
                        borderRadius: pill,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: PosPaymentSpec.v2SuccessButtonPaddingV,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            busy ? 'Working...' : buttonLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: loewBold.copyWith(
                              fontSize: PosPaymentSpec.v2SuccessButtonLabelSize,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `total-display` (1915:9323): white box, `#E0D9C8` 1px border, r12, p16.
class _AmountPaid extends StatelessWidget {
  final double amount;
  final String label;

  const _AmountPaid({required this.amount, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(PosPaymentSpec.v2SuccessAmountBoxPadding),
      decoration: BoxDecoration(
        color: PosHomeSpec.tileBg,
        borderRadius:
            BorderRadius.circular(PosPaymentSpec.v2SuccessAmountBoxRadius),
        border: Border.all(color: PosHomeSpec.tableFieldBorder), // #E0D9C8 1px
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: loewBold.copyWith(
              fontSize: PosPaymentSpec.waitAmountLabelSize, // 13
              letterSpacing: PosPaymentSpec.waitAmountLabelTracking, // 1
              color: PosHomeSpec.inkAlpha(PosPaymentSpec.waitAmountLabelOpacity),
            ),
          ),
          const SizedBox(height: PosPaymentSpec.waitAmountLabelGap), // 4
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              PosHomeSpec.formatPrice(amount, padZero: false),
              maxLines: 1,
              style: loewExtraBold.copyWith(
                fontSize: PosPaymentSpec.waitAmountSize, // 36
                color: PosHomeSpec.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A bold checkmark (node `mingcute:check-fill` 1915:9319), inlined so a stale
/// web AssetManifest cannot blank it.
const String _checkSvg =
    '<svg viewBox="0 0 24 24" fill="none" stroke="#241F20" stroke-width="3" '
    'stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">'
    '<path d="M20 6 9 17l-5-5"/></svg>';
