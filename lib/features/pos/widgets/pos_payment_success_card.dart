import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_payment_spec.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// A payment success state — Figma `success-card` (nodes **1915:9317** /
/// **1915:12227**).
///
/// 640 wide, p-32, r20, `#F0EBD8` 1.5px inside stroke, `0 8 12` 4% shadow:
/// the check, a heading, the amount box and one or two r32 pills. With a
/// single button (frame 08) the sections sit 24 apart; with a secondary
/// outline button above the filled one (frames 18 / 28) they sit 16 apart.
class PosPaymentSuccessCard extends StatelessWidget {
  /// e.g. "Split Payment 1 Successful".
  final String title;
  final double amount;
  final String amountLabel;

  /// The filled ink pill, last in the card.
  final String buttonLabel;
  final VoidCallback? onContinue;

  /// Optional outline pill drawn above the filled one ("Receipt").
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool busy;

  const PosPaymentSuccessCard({
    super.key,
    required this.title,
    required this.amount,
    required this.buttonLabel,
    required this.onContinue,
    this.amountLabel = 'AMOUNT PAID',
    this.secondaryLabel,
    this.onSecondary,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool enabled = onContinue != null && !busy;
    final double gap = secondaryLabel == null
        ? PosPaymentSpec.v2SuccessCardGap
        : PosPaymentSpec.v2SuccessCardGapTwoButtons;
    final BorderRadius radius =
        BorderRadius.circular(PosPaymentSpec.v2SuccessCardRadius);

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
                borderRadius: radius,
                boxShadow: const [
                  BoxShadow(
                    color: PosPaymentSpec.v2SuccessShadow,
                    offset: PosPaymentSpec.v2SuccessShadowOffset,
                    blurRadius: PosPaymentSpec.v2SuccessShadowBlur,
                  ),
                ],
              ),
              // Inside stroke: it does not add to the p-32.
              foregroundDecoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(
                  color: PosHomeSpec.hairline, // #F0EBD8
                  width: PosPaymentSpec.v2SuccessCardBorder,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // status-header (1915:9318): check + heading, gap-16.
                  Center(
                    child: SvgPicture.string(
                      _checkSvg,
                      width: PosPaymentSpec.v2SuccessIconSize,
                      height: PosPaymentSpec.v2SuccessIconSize,
                    ),
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
                  SizedBox(height: gap),
                  _AmountPaid(amount: amount, label: amountLabel),
                  if (secondaryLabel != null) ...[
                    SizedBox(height: gap),
                    // receipt-btn (1915:12236): outline pill.
                    PosSuccessPill(
                      label: secondaryLabel!,
                      onTap: busy ? null : onSecondary,
                      filled: false,
                    ),
                  ],
                  SizedBox(height: gap),
                  // print-receipt-btn / next-order-btn: ink pill.
                  PosSuccessPill(
                    label: busy ? 'Working...' : buttonLabel,
                    onTap: enabled ? onContinue : null,
                    filled: true,
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

/// The success card's r32 pill (nodes 1915:9326 / 12236 / 12238): py-14,
/// 1.5px ink inside stroke, Loew Bold 16 — ink fill with white label, or white
/// with ink label.
class PosSuccessPill extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool filled;

  const PosSuccessPill({
    super.key,
    required this.label,
    required this.onTap,
    required this.filled,
  });

  @override
  Widget build(BuildContext context) {
    final BorderRadius pill =
        BorderRadius.circular(PosPaymentSpec.v2SuccessButtonRadius);
    return Opacity(
      opacity: onTap != null ? 1 : 0.5,
      child: Material(
        color: filled ? PosHomeSpec.ink : PosHomeSpec.tileBg,
        borderRadius: pill,
        child: InkWell(
          onTap: onTap,
          borderRadius: pill,
          child: Container(
            padding: const EdgeInsets.symmetric(
              vertical: PosPaymentSpec.v2SuccessButtonPaddingV,
            ),
            alignment: Alignment.center,
            foregroundDecoration: BoxDecoration(
              borderRadius: pill,
              border: Border.all(color: PosHomeSpec.ink, width: 1.5),
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: loewBold.copyWith(
                fontSize: PosPaymentSpec.v2SuccessButtonLabelSize,
                color: filled ? Colors.white : PosHomeSpec.ink,
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
      ),
      // Inside stroke: the box is 95 tall (16 + 16 + 4 + 43 + 16).
      foregroundDecoration: BoxDecoration(
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

/// `mingcute:check-fill` (node 1915:9319), the frame's own 45×45 vector,
/// inlined so a stale web AssetManifest cannot blank it.
const String _checkSvg =
    '<svg width="45" height="45" viewBox="0 0 45 45" fill="none" xmlns="http://www.w3.org/2000/svg">'
    '<path d="M40.3988 9.58416C40.9261 10.1116 41.2223 10.8268 41.2223 11.5726C41.2223 12.3184 40.9261 13.0336 40.3988 13.561L19.185 34.7748C18.6576 35.3021 17.9424 35.5983 17.1966 35.5983C16.4508 35.5983 15.7356 35.3021 15.2082 34.7748L4.6013 24.1679C4.33268 23.9085 4.11841 23.5981 3.97101 23.255C3.82361 22.9119 3.74603 22.5428 3.74278 22.1694C3.73954 21.7959 3.8107 21.4256 3.95211 21.0799C4.09353 20.7343 4.30236 20.4203 4.56644 20.1562C4.83051 19.8921 5.14453 19.6833 5.49018 19.5419C5.83582 19.4004 6.20617 19.3293 6.57961 19.3325C6.95306 19.3358 7.32211 19.4134 7.66525 19.5608C8.00838 19.7082 8.31873 19.9224 8.57817 20.191L17.1957 28.8085L36.42 9.58416C36.6812 9.32281 36.9914 9.11548 37.3327 8.97403C37.6741 8.83257 38.0399 8.75977 38.4094 8.75977C38.7789 8.75977 39.1448 8.83257 39.4861 8.97403C39.8275 9.11548 40.1376 9.32281 40.3988 9.58416Z" '
    'fill-rule="evenodd" clip-rule="evenodd" fill="black"/></svg>';
