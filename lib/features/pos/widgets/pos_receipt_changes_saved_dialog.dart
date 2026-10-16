import 'package:flutter/material.dart';
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipt_history.dart';
import 'package:acafe_customer/utill/styles.dart';

// ─── Design tokens (State 14) ─────────────────────────────────────────────────
const _kCardBg = Color(0xFFFBF8EF);
const _kBorder = Color(0xFFF0EBD8);
const _kInk = PosHomeSpec.ink;
const _kCream = Color(0xFFF7F1DE);
const _kSuccessGreen = Color(0xFF3DAA72);
const _kWidth = 520.0;
const _kRadius = 16.0;

/// Shows the "Changes saved" confirmation overlay (State 14).
///
/// [newTotal] is the confirmed new order amount after save.
/// [onDone] is called when the user dismisses — the caller resets edit mode
/// and optionally refreshes the receipt detail.
Future<void> showPosReceiptChangesSavedDialog({
  required BuildContext context,
  required PosReceiptDetail receipt,
  required double newTotal,
  required VoidCallback onDone,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'ChangesSaved',
    barrierColor: PosHomeSpec.contextMenuBackdrop,
    pageBuilder: (dialogContext, _, __) => Material(
      type: MaterialType.transparency,
      child: Center(
        child: _ChangesSavedCard(
          receipt: receipt,
          newTotal: newTotal,
          onDone: () {
            Navigator.of(dialogContext).pop();
            onDone();
          },
        ),
      ),
    ),
  );
}

class _ChangesSavedCard extends StatelessWidget {
  final PosReceiptDetail receipt;
  final double newTotal;
  final VoidCallback onDone;

  const _ChangesSavedCard({
    required this.receipt,
    required this.newTotal,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_kRadius),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SuccessHeader(),
            const _Divider(),
            _ReceiptSummarySection(
              receipt: receipt,
              newTotal: newTotal,
            ),
            const _Divider(),
            _BackBar(onTap: onDone),
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
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: _kSuccessGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 20),
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
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
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

// ─── Back bar ─────────────────────────────────────────────────────────────────

class _BackBar extends StatelessWidget {
  final VoidCallback onTap;

  const _BackBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _kInk,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 56,
          child: Center(
            child: Text(
              'BACK TO RECEIPTS',
              style: loewExtraBold.copyWith(
                fontSize: 14,
                color: _kCream,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ),
      ),
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
