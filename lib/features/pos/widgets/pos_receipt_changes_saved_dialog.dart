import 'dart:async';

import 'package:flutter/material.dart';
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipt_history.dart';
import 'package:acafe_customer/utill/styles.dart';

// ─── Design tokens (State 14) ─────────────────────────────────────────────────
const _kCardBg = Color(0xFFFBF8EF);
const _kBorder = Color(0xFFF0EBD8);
const _kInk = PosHomeSpec.ink;
const _kSuccessGreen = Color(0xFF3DAA72);
const _kWidth = 520.0;
const _kRadius = 16.0;

// ─── Motion ───────────────────────────────────────────────────────────────────
// Same fade + settle as the email receipt's "Sent" card.
const _kTransition = Duration(milliseconds: 220);
// How long the card stays up before it fades itself out. Long enough to read
// the new total, short enough not to hold up the till.
const _kHold = Duration(milliseconds: 1800);

/// Shows the "Changes saved" confirmation overlay (State 14).
///
/// No button: the card fades in, holds for a moment, then fades itself out.
/// A tap on the card or the backdrop closes it early.
///
/// [newTotal] is the confirmed new order amount after save.
/// [onDone] runs as the card starts to close, however it was closed — the
/// caller leaves edit mode, so the receipt is back in view as the card fades.
Future<void> showPosReceiptChangesSavedDialog({
  required BuildContext context,
  required PosReceiptDetail receipt,
  required double newTotal,
  required VoidCallback onDone,
}) async {
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'ChangesSaved',
    barrierColor: PosHomeSpec.contextMenuBackdrop,
    transitionDuration: _kTransition,
    pageBuilder: (_, __, ___) => Material(
      type: MaterialType.transparency,
      child: Center(
        child: _ChangesSavedCard(receipt: receipt, newTotal: newTotal),
      ),
    ),
    // The reverse curve is what the auto-dismiss rides out on, together with
    // the backdrop.
    transitionBuilder: (context, animation, _, child) {
      final Animation<double> curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.97, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
  onDone();
}

class _ChangesSavedCard extends StatefulWidget {
  final PosReceiptDetail receipt;
  final double newTotal;

  const _ChangesSavedCard({required this.receipt, required this.newTotal});

  @override
  State<_ChangesSavedCard> createState() => _ChangesSavedCardState();
}

class _ChangesSavedCardState extends State<_ChangesSavedCard> {
  Timer? _autoClose;

  @override
  void initState() {
    super.initState();
    // Hold time runs from the moment the card starts to fade in.
    _autoClose = Timer(_kHold, _closeIfCurrent);
  }

  @override
  void dispose() {
    _autoClose?.cancel();
    super.dispose();
  }

  /// Pops the card only while it is still the top route. A tap can close it
  /// first; without this guard the timer would then pop the Receipts screen
  /// underneath.
  void _closeIfCurrent() {
    _autoClose?.cancel();
    if (!mounted) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _closeIfCurrent,
      child: Container(
        width: _kWidth,
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(_kRadius),
          border: Border.all(color: _kBorder, width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26000000),
              blurRadius: 16,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SuccessHeader(),
            const _Divider(),
            _ReceiptSummarySection(
              receipt: widget.receipt,
              newTotal: widget.newTotal,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _SuccessHeader extends StatelessWidget {
  const _SuccessHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      child: Row(
        children: [
          // Check pops in just behind the card's own fade.
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 520),
            curve: const Interval(0.2, 1, curve: Curves.easeOutBack),
            builder: (_, t, child) => Opacity(
              opacity: t.clamp(0.0, 1.0),
              child: Transform.scale(scale: 0.6 + 0.4 * t, child: child),
            ),
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: _kSuccessGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Changes saved',
                  style: loewExtraBold.copyWith(
                    fontSize: 18,
                    color: _kInk,
                    height: 24 / 18,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'The receipt has been updated successfully.',
                  style: swiss721Light.copyWith(
                    fontSize: 12,
                    color: _kInk.withValues(alpha: 0.6),
                    height: 16 / 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Receipt summary ──────────────────────────────────────────────────────────

class _ReceiptSummarySection extends StatelessWidget {
  final PosReceiptDetail receipt;
  final double newTotal;

  const _ReceiptSummarySection({
    required this.receipt,
    required this.newTotal,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SummaryLabel(),
          const SizedBox(height: 14),
          _SummaryRow(
            label: 'Receipt',
            value: '#${receipt.receiptNumber}',
          ),
          const SizedBox(height: 8),
          _SummaryRow(
            label: 'Items',
            value: '${receipt.lines.length}',
          ),
          const SizedBox(height: 8),
          _SummaryRow(
            label: 'Payment method',
            value: receipt.methodLabel,
          ),
          const SizedBox(height: 12),
          const ColoredBox(
            color: _kBorder,
            child: SizedBox(height: 1, width: double.infinity),
          ),
          const SizedBox(height: 12),
          _TotalRow(newTotal: newTotal),
        ],
      ),
    );
  }
}

class _SummaryLabel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text(
      'RECEIPT SUMMARY',
      style: loewBold.copyWith(
        fontSize: 11,
        color: _kInk.withValues(alpha: 0.4),
        letterSpacing: 0.8,
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: swiss721Light.copyWith(
            fontSize: 13,
            color: _kInk.withValues(alpha: 0.6),
            height: 18 / 13,
          ),
        ),
        Text(
          value,
          style: loewBold.copyWith(
            fontSize: 13,
            color: _kInk,
            height: 18 / 13,
          ),
        ),
      ],
    );
  }
}

class _TotalRow extends StatelessWidget {
  final double newTotal;

  const _TotalRow({required this.newTotal});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'New total',
          style: loewExtraBold.copyWith(
            fontSize: 15,
            color: _kInk,
          ),
        ),
        Text(
          PosHomeSpec.formatPrice(newTotal),
          style: loewExtraBold.copyWith(
            fontSize: 15,
            color: _kInk,
          ),
        ),
      ],
    );
  }
}

// ─── Shared hairline ──────────────────────────────────────────────────────────

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: _kBorder,
      child: SizedBox(height: 1, width: double.infinity),
    );
  }
}
