import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_payment_spec.dart';
import 'package:acafe_customer/features/pos/widgets/pos_waiting_card.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Shown when the terminal turns a card payment down —
/// Figma `declined-card` (**1641:4218**).
///
/// The counterpart to [PosWaitingCard] and drawn on the same
/// [PosPaymentStatusCard] shell, so the two states of one payment attempt
/// cannot drift apart. It replaces the waiting card in the payment screen's
/// content area; the header and the ticket behind it are untouched.
///
/// Known limitation: the design has no line for a decline reason, so whatever
/// `KioskPaymentResult.message` carries ("insufficient funds", "card expired")
/// is not shown. The frame is followed as drawn; adding a reason line under the
/// heading is a one-line change if the design grows one.
///
/// Only reachable from `PosCheckoutStatus.paymentFailed` — a payment that was
/// never taken. The other failure, `orderFailed`, means the card *was* charged
/// and only the order post failed; offering "Try Again" under a heading that
/// says "Payment Declined" would invite a second charge for a sale that has
/// already been paid.
class PosDeclinedCard extends StatelessWidget {
  /// The sale total — the same value the waiting card was showing a moment
  /// ago, passed through rather than recomputed.
  final double amountDue;

  /// Returns to the method selector with the sale intact.
  final VoidCallback? onCancel;

  /// Starts a fresh attempt at the same amount.
  final VoidCallback? onTryAgain;

  /// True while a retry is being handed to the terminal.
  final bool retrying;

  const PosDeclinedCard({
    super.key,
    required this.amountDue,
    required this.onCancel,
    required this.onTryAgain,
    this.retrying = false,
  });

  @override
  Widget build(BuildContext context) {
    return PosPaymentStatusCard(
      indicator: const _ErrorMark(),
      heading: 'Payment Declined',
      amountDue: amountDue,
      actions: [
        Expanded(
          child: PosPaymentCardButton(
            label: 'Cancel',
            onTap: onCancel,
          ),
        ),
        Expanded(
          child: PosPaymentCardButton(
            label: retrying ? 'Starting...' : 'Try Again',
            onTap: onTryAgain,
            filled: true,
          ),
        ),
      ],
    );
  }
}

/// `error-indicator-wrapper` (1641:4222) — a ringed X.
///
/// The stroke is `#D9383A`, which the app already names as
/// [PosHomeSpec.contextMenuDanger] for destructive rows in the receipt menu.
/// Same red, not a new one.
class _ErrorMark extends StatelessWidget {
  const _ErrorMark();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: PosPaymentSpec.declinedIconSize,
      height: PosPaymentSpec.declinedIconSize,
      child: SvgPicture.asset(
        Images.posErrorCircleSvg,
        width: PosPaymentSpec.declinedIconSize,
        height: PosPaymentSpec.declinedIconSize,
        fit: BoxFit.contain,
        // A stale web AssetManifest must not leave the failure state with no
        // failure signal at all — see the trash-icon note in
        // pos_receipt_line.dart.
        placeholderBuilder: (_) => const Icon(
          Icons.highlight_off,
          size: PosPaymentSpec.declinedIconSize,
          color: PosHomeSpec.contextMenuDanger,
        ),
      ),
    );
  }
}
