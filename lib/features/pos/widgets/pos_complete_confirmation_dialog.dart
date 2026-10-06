import 'package:acafe_customer/features/pos/domain/pos_order_detail_spec.dart';
import 'package:acafe_customer/features/pos/widgets/pos_waiting_card.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';

/// "Mark order as complete?" — Figma **1641:4791** / `confirmation-overlay`
/// **1641:5119**. The same card also backs every other forward transition on
/// the ladder (`new -> preparing`, `preparing -> item_to_collect`) with its
/// own heading/subtext/confirm label, passed in by the caller — see
/// [PosOrdersListScreen._advance]. Every rung the operator can push an order
/// through is confirmed before it fires; only `on_hold -> preparing` (Resume)
/// is not, because un-pausing an order is not progressing it.
///
/// **Copy note.** Figma's completion subtext reads "This will move the order
/// to the Finished section." That is not true of the transition this dialog
/// actually gates: [PosOrderGrouping] already groups `item_to_collect` under
/// FINISHED, so the card is sitting in that section before the operator taps,
/// and completing it moves nothing. (It *would* be true of
/// `preparing -> item_to_collect`.) The heading is the half that matches the
/// button that opens this, so the heading won and the subtext was corrected to
/// something the operator can actually rely on. Signed off; layout and type
/// follow Figma exactly.
class PosCompleteConfirmationDialog extends StatelessWidget {
  /// Defaults to the completion copy so every existing no-arg call site (and
  /// the `.heading` / `.subtext` / `.cancelLabel` / `.confirmLabel` constants
  /// other screens read) keeps behaving exactly as before.
  final String titleText;
  final String bodyText;
  final String cancelText;
  final String confirmText;

  /// A smaller, tighter card for simple yes/no prompts (e.g. "Log out this
  /// terminal?") that are not the order-completion flow. The order confirmations
  /// keep the full Figma sizing; only prompts that opt in shrink.
  final bool compact;

  const PosCompleteConfirmationDialog({
    super.key,
    this.titleText = heading,
    this.bodyText = subtext,
    this.cancelText = cancelLabel,
    this.confirmText = confirmLabel,
    this.compact = false,
  });

  static const String heading = 'Mark order as complete?';
  static const String subtext = 'This will close the order.';
  static const String cancelLabel = 'Cancel';
  static const String confirmLabel = 'Complete';

  /// Returns true only when the operator confirms. A tap outside, Escape, or
  /// Cancel all resolve to null/false, which callers treat as "do nothing" —
  /// the same `Future<bool?>` contract the add-on settings confirm already
  /// uses, so no caller has to learn a second convention.
  static Future<bool?> show(
    BuildContext context, {
    String heading = PosCompleteConfirmationDialog.heading,
    String subtext = PosCompleteConfirmationDialog.subtext,
    String cancelLabel = PosCompleteConfirmationDialog.cancelLabel,
    String confirmLabel = PosCompleteConfirmationDialog.confirmLabel,
    bool compact = false,
  }) {
    // showGeneralDialog (not showDialog) so the card fades in and out rather
    // than popping; the barrier still fades with it. Opacity-only, so the dialog
    // is hittable from the first frame and nothing has to wait on the animation.
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: PosOrderDetailSpec.confirmBackdrop,
      useRootNavigator: false,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, __, ___) => PosCompleteConfirmationDialog(
        titleText: heading,
        bodyText: subtext,
        cancelText: cancelLabel,
        confirmText: confirmLabel,
        compact: compact,
      ),
      transitionBuilder: (_, animation, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size window = MediaQuery.sizeOf(context);
    final PosCompleteConfirmationMetrics m = compact
        ? PosCompleteConfirmationMetrics.compact
        : PosCompleteConfirmationMetrics.regular;

    // The card width is a maximum, not a fixed size: the POS runs on hardware
    // narrower than the artboard, where a fixed width plus margins would clip.
    // Clamping to the window is what keeps it responsive on a small tablet.
    final double maxWidth = window.width - m.inset * 2;

    final double cardWidth = maxWidth < m.cardWidth ? maxWidth : m.cardWidth;

    // The card is width-constrained and centred, so everything around it is
    // transparent and not hit-tested. A tap out there falls through to the
    // route's dismiss barrier (barrierDismissible) and closes the dialog; a tap
    // on the card hits the card, not the barrier, so it never dismisses.
    return Center(
      child: Padding(
        padding: EdgeInsets.all(m.inset),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: cardWidth,
            maxHeight: window.height - m.inset * 2,
          ),
          child: Material(
            color: Colors.transparent,
            child: SingleChildScrollView(
              child: Container(
                padding: EdgeInsets.all(m.pad),
                decoration: BoxDecoration(
                  color: PosOrderDetailSpec.modalBg,
                  borderRadius: BorderRadius.circular(m.radius),
                  border: Border.all(
                    color: PosOrderDetailSpec.ink,
                    width: m.border,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      titleText,
                      style: loewExtraBold.copyWith(
                        fontSize: m.headingSize,
                        color: PosOrderDetailSpec.ink,
                      ),
                    ),
                    SizedBox(height: m.headingGap),
                    Text(
                      bodyText,
                      style: loewMedium.copyWith(
                        fontSize: m.subtextSize,
                        color: PosOrderDetailSpec.inkAlpha(0.6),
                      ),
                    ),
                    SizedBox(height: m.blockGap),
                    Row(
                      children: [
                        Expanded(
                          child: PosPaymentCardButton(
                            label: cancelText,
                            onTap: () => Navigator.of(context).pop(false),
                            radius: m.buttonRadius,
                            borderWidth: m.border,
                            padding: m.buttonPadding,
                            fontSize: m.buttonTextSize,
                          ),
                        ),
                        SizedBox(width: m.blockGap),
                        Expanded(
                          child: PosPaymentCardButton(
                            label: confirmText,
                            filled: true,
                            onTap: () => Navigator.of(context).pop(true),
                            radius: m.buttonRadius,
                            borderWidth: m.border,
                            padding: m.buttonPadding,
                            fontSize: m.buttonTextSize,
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
      ),
    );
  }
}

/// The two size sets this card renders at. `regular` is the Figma order-flow
/// dialog; `compact` is a tighter card for a simple yes/no prompt.
class PosCompleteConfirmationMetrics {
  final double cardWidth;
  final double radius;
  final double border;
  final double pad;
  final double inset;
  final double headingSize;
  final double headingGap;
  final double subtextSize;
  final double blockGap;
  final double buttonRadius;
  final double buttonTextSize;
  final EdgeInsets buttonPadding;

  const PosCompleteConfirmationMetrics({
    required this.cardWidth,
    required this.radius,
    required this.border,
    required this.pad,
    required this.inset,
    required this.headingSize,
    required this.headingGap,
    required this.subtextSize,
    required this.blockGap,
    required this.buttonRadius,
    required this.buttonTextSize,
    required this.buttonPadding,
  });

  /// Figma `confirmation-dialog` 1641:5120, sized for the 1366 artboard.
  static const PosCompleteConfirmationMetrics regular =
      PosCompleteConfirmationMetrics(
    cardWidth: 720,
    radius: 20,
    border: 3,
    pad: 32,
    inset: 24,
    headingSize: 32,
    headingGap: 8,
    subtextSize: 26,
    blockGap: 24,
    buttonRadius: 40,
    buttonTextSize: 26,
    buttonPadding: EdgeInsets.symmetric(horizontal: 32, vertical: 20),
  );

  /// A normal-looking modal for simple prompts -- about the proportions of the
  /// app's other cards rather than the full-screen order overlay.
  static const PosCompleteConfirmationMetrics compact =
      PosCompleteConfirmationMetrics(
    cardWidth: 400,
    radius: 18,
    border: 2,
    pad: 24,
    inset: 24,
    headingSize: 20,
    headingGap: 6,
    subtextSize: 14,
    blockGap: 16,
    buttonRadius: 100,
    buttonTextSize: 15,
    buttonPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
  );
}
