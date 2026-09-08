import 'package:acafe_customer/features/pos/domain/pos_order_detail_spec.dart';
import 'package:acafe_customer/features/pos/widgets/pos_waiting_card.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';

/// "Mark order as complete?" — Figma **1641:4791** / `confirmation-overlay`
/// **1641:5119**.
///
/// Gates exactly one transition: `item_to_collect -> completed`, the terminal
/// rung. Every other rung on the ladder advances without a prompt, because
/// they are all recoverable — only this one closes the order.
///
/// **Copy note.** Figma's subtext reads "This will move the order to the
/// Finished section." That is not true of the transition this dialog actually
/// gates: [PosOrderGrouping] already groups `item_to_collect` under FINISHED,
/// so the card is sitting in that section before the operator taps, and
/// completing it moves nothing. (It *would* be true of
/// `preparing -> item_to_collect`, which this dialog deliberately does not
/// gate.) The heading is the half that matches the button that opens this, so
/// the heading won and the subtext was corrected to something the operator can
/// actually rely on. Signed off; layout and type follow Figma exactly.
class PosCompleteConfirmationDialog extends StatelessWidget {
  const PosCompleteConfirmationDialog({super.key});

  static const String heading = 'Mark order as complete?';
  static const String subtext = 'This will close the order.';
  static const String cancelLabel = 'Cancel';
  static const String confirmLabel = 'Complete';

  /// Returns true only when the operator confirms. A tap outside, Escape, or
  /// Cancel all resolve to null/false, which callers treat as "do nothing" —
  /// the same `Future<bool?>` contract the add-on settings confirm already
  /// uses, so no caller has to learn a second convention.
  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: PosOrderDetailSpec.confirmBackdrop,
      useRootNavigator: false,
      builder: (_) => const PosCompleteConfirmationDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size window = MediaQuery.sizeOf(context);

    // Figma fixes the card at 720. That is a maximum here, not a size: the POS
    // runs on hardware narrower than the 1366 artboard, where a fixed 720 plus
    // margins would clip.
    final double maxWidth = window.width - PosCompleteConfirmationSpec.inset * 2;

    return Material(
      color: Colors.transparent,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(PosCompleteConfirmationSpec.inset),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth < PosCompleteConfirmationSpec.cardWidth
                  ? maxWidth
                  : PosCompleteConfirmationSpec.cardWidth,
            ),
            child: Container(
              padding: const EdgeInsets.all(PosCompleteConfirmationSpec.pad),
              decoration: BoxDecoration(
                color: PosOrderDetailSpec.modalBg,
                borderRadius: BorderRadius.circular(
                  PosCompleteConfirmationSpec.radius,
                ),
                border: Border.all(
                  color: PosOrderDetailSpec.ink,
                  width: PosCompleteConfirmationSpec.border,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    heading,
                    style: loewExtraBold.copyWith(
                      fontSize: PosCompleteConfirmationSpec.headingSize,
                      color: PosOrderDetailSpec.ink,
                    ),
                  ),
                  const SizedBox(
                    height: PosCompleteConfirmationSpec.headingGap,
                  ),
                  Text(
                    subtext,
                    style: loewMedium.copyWith(
                      fontSize: PosCompleteConfirmationSpec.subtextSize,
                      color: PosOrderDetailSpec.inkAlpha(0.6),
                    ),
                  ),
                  const SizedBox(height: PosCompleteConfirmationSpec.blockGap),
                  Row(
                    children: [
                      Expanded(
                        child: PosPaymentCardButton(
                          label: cancelLabel,
                          onTap: () => Navigator.of(context).pop(false),
                          radius: PosCompleteConfirmationSpec.buttonRadius,
                          borderWidth: PosCompleteConfirmationSpec.border,
                          padding: PosCompleteConfirmationSpec.buttonPadding,
                          fontSize: PosCompleteConfirmationSpec.buttonTextSize,
                        ),
                      ),
                      const SizedBox(
                        width: PosCompleteConfirmationSpec.blockGap,
                      ),
                      Expanded(
                        child: PosPaymentCardButton(
                          label: confirmLabel,
                          filled: true,
                          onTap: () => Navigator.of(context).pop(true),
                          radius: PosCompleteConfirmationSpec.buttonRadius,
                          borderWidth: PosCompleteConfirmationSpec.border,
                          padding: PosCompleteConfirmationSpec.buttonPadding,
                          fontSize: PosCompleteConfirmationSpec.buttonTextSize,
                          filledLabelColor: PosOrderDetailSpec.cream,
                          emphasiseFilledLabel: true,
                        ),
                      ),
                    ],
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

/// Metrics for Figma `confirmation-dialog` **1641:5120**.
class PosCompleteConfirmationSpec {
  PosCompleteConfirmationSpec._();

  static const double cardWidth = 720;
  static const double radius = 20;
  static const double border = 3;
  static const double pad = 32;
  static const double inset = 24;

  static const double headingSize = 32;
  static const double headingGap = 8;
  static const double subtextSize = 26;

  /// The 24 that separates the header block from the actions, and the two
  /// buttons from each other.
  static const double blockGap = 24;

  static const double buttonRadius = 40;
  static const double buttonTextSize = 26;
  static const EdgeInsets buttonPadding =
      EdgeInsets.symmetric(horizontal: 32, vertical: 20);
}
