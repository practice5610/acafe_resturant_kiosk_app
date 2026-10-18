import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/widgets/pos_waiting_card.dart';
import 'package:flutter/material.dart';

/// A payment error state, on the shared [PosPaymentStatusCard] shell — Figma
/// `declined-card` with a subtitle (nodes **1915:11287 / 11306 / 11325**).
///
/// Render-only in Phase 2a: these are built to the frames and ready to wire,
/// but nothing triggers them yet. In particular there is **no** real timeout
/// path (23) and **no** cash-validation path (24) — those are future
/// functional work. The already-wired decline uses [PosDeclinedCard]; this
/// widget covers the three new error frames.
class PosPaymentErrorCard extends StatelessWidget {
  final String title;
  final String subheading;
  final double amountDue;
  final String amountLabel;
  final String cancelLabel;
  final String primaryLabel;
  final VoidCallback? onCancel;
  final VoidCallback? onPrimary;
  final bool primaryBusy;

  const PosPaymentErrorCard({
    super.key,
    required this.title,
    required this.subheading,
    required this.amountDue,
    required this.cancelLabel,
    required this.primaryLabel,
    required this.onCancel,
    required this.onPrimary,
    this.amountLabel = 'AMOUNT DUE',
    this.primaryBusy = false,
  });

  /// 22 — Card terminal offline (node 1915:11287).
  factory PosPaymentErrorCard.terminalOffline({
    Key? key,
    required double amountDue,
    required VoidCallback? onCancel,
    required VoidCallback? onRetry,
    bool busy = false,
  }) =>
      PosPaymentErrorCard(
        key: key,
        title: 'Terminal Offline',
        subheading: 'Check the terminal connection and try again',
        amountDue: amountDue,
        cancelLabel: 'Cancel',
        primaryLabel: 'Retry connection',
        onCancel: onCancel,
        onPrimary: onRetry,
        primaryBusy: busy,
      );

  /// 23 — Payment timed out (node 1915:11306).
  factory PosPaymentErrorCard.timedOut({
    Key? key,
    required double amountDue,
    int seconds = 60,
    required VoidCallback? onCancel,
    required VoidCallback? onTryAgain,
    bool busy = false,
  }) =>
      PosPaymentErrorCard(
        key: key,
        title: 'Payment Timed Out',
        subheading: 'No card was presented within $seconds seconds',
        amountDue: amountDue,
        cancelLabel: 'Cancel',
        primaryLabel: 'Try Again',
        onCancel: onCancel,
        onPrimary: onTryAgain,
        primaryBusy: busy,
      );

  /// 24 — Cash amount too low (node 1915:11325). The amount box reads the
  /// outstanding balance under a "STILL DUE" caption.
  factory PosPaymentErrorCard.cashTooLow({
    Key? key,
    required double received,
    required double total,
    required VoidCallback? onBack,
    required VoidCallback? onAddCash,
  }) =>
      PosPaymentErrorCard(
        key: key,
        title: 'Amount Too Low',
        subheading: 'Received ${PosHomeSpec.formatPrice(received, padZero: false)}'
            ' of ${PosHomeSpec.formatPrice(total, padZero: false)}',
        amountDue: total - received,
        amountLabel: 'STILL DUE',
        cancelLabel: 'Back',
        primaryLabel: 'Add cash',
        onCancel: onBack,
        onPrimary: onAddCash,
      );

  @override
  Widget build(BuildContext context) {
    return PosPaymentStatusCard(
      indicator: const PosPaymentErrorMark(),
      heading: title,
      subheading: subheading,
      amountDue: amountDue,
      amountLabel: amountLabel,
      actions: [
        Expanded(
          child: PosPaymentCardButton(
            insideStroke: true,
            label: cancelLabel,
            onTap: onCancel,
          ),
        ),
        Expanded(
          child: PosPaymentCardButton(
            insideStroke: true,
            label: primaryBusy ? 'Starting...' : primaryLabel,
            onTap: onPrimary,
            filled: true,
          ),
        ),
      ],
    );
  }
}
