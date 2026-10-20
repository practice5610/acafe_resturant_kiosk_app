import 'package:flutter/material.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipt_history.dart';
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/theme/text_legibility.dart';
import 'package:acafe_customer/utill/styles.dart';

// ─── Design tokens (State 13, Figma 1915:21106) ────────────────────────────
const _kModalBg = Color(0xFFFBF8EF);
const _kModalBorder = Color(0xFFF0EBD8);
const _kInk = PosHomeSpec.ink;
const _kCream = Color(0xFFF7F1DE);
const _kWidth = 560.0;
const _kRadius = 16.0;
const _kButtonRadius = 12.0;
const _kButtonHeight = 47.0;

/// Shows the "Save changes?" confirmation overlay (State 13).
///
/// [newTotal] is the computed receipt total after edits.
/// [delta] is `newTotal - receipt.total`; positive = charge, negative = refund.
/// [onConfirm] is called when the user confirms — the caller then calls the
/// save-changes endpoint and shows State 14.
Future<void> showPosReceiptConfirmChangesDialog({
  required BuildContext context,
  required PosReceiptDetail receipt,
  required double newTotal,
  required double delta,
  required VoidCallback onConfirm,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'ConfirmChanges',
    barrierColor: PosHomeSpec.contextMenuBackdrop,
    pageBuilder: (dialogContext, _, __) => Material(
      type: MaterialType.transparency,
      child: Center(
        child: _ConfirmChangesModal(
          receipt: receipt,
          newTotal: newTotal,
          delta: delta,
          onConfirm: () {
            Navigator.of(dialogContext).pop();
            onConfirm();
          },
          onCancel: () => Navigator.of(dialogContext).pop(),
        ),
      ),
    ),
  );
}

class _ConfirmChangesModal extends StatelessWidget {
  final PosReceiptDetail receipt;
  final double newTotal;
  final double delta;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _ConfirmChangesModal({
    required this.receipt,
    required this.newTotal,
    required this.delta,
    required this.onConfirm,
    required this.onCancel,
  });

  String get _ctaLabel {
    if (delta.abs() < 0.005) return 'Save changes';
    final abs = delta.abs();
    final formatted = PosHomeSpec.formatPrice(abs);
    return delta > 0 ? 'Charge $formatted' : 'Refund $formatted';
  }

  String get _bodyText {
    final method = receipt.methodLabel;
    final newFmt = PosHomeSpec.formatPrice(newTotal);
    final origFmt = PosHomeSpec.formatPrice(receipt.total);
    if (delta.abs() < 0.005) {
      return 'Receipt #${receipt.receiptNumber} will be updated from '
          '$origFmt to $newFmt with no change to the total amount.';
    }
    final absDelta = PosHomeSpec.formatPrice(delta.abs());
    if (delta > 0) {
      return 'Receipt #${receipt.receiptNumber} will be updated to '
          '$newFmt. The difference of $absDelta will be charged on the '
          'original payment method ($method).';
    } else {
      return 'Receipt #${receipt.receiptNumber} will be updated to '
          '$newFmt. The difference of $absDelta will be refunded to the '
          'original payment method ($method).';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _kWidth,
      decoration: BoxDecoration(
        color: _kModalBg,
        borderRadius: BorderRadius.circular(_kRadius),
        border: Border.all(color: _kModalBorder, width: 1.5),
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
          _ModalHeader(
            receiptNumber: receipt.receiptNumber,
            newTotal: newTotal,
            onClose: onCancel,
          ),
          const _ModalDivider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Text(
              _bodyText,
              style: swiss721Light.copyWith(
                fontSize: 14,
                color: _kInk,
                height: 20 / 14,
              ),
            ),
          ),
          const _ModalDivider(),
          _ModalFooter(
            ctaLabel: _ctaLabel,
            onCancel: onCancel,
            onConfirm: onConfirm,
          ),
        ],
      ),
    );
  }
}

class _ModalHeader extends StatelessWidget {
  final String receiptNumber;
  final double newTotal;
  final VoidCallback onClose;

  const _ModalHeader({
    required this.receiptNumber,
    required this.newTotal,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Save changes?',
                  style: loewExtraBold.copyWith(
                    fontSize: 18,
                    color: _kInk,
                    height: 24 / 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Receipt #$receiptNumber · new total '
                  '${PosHomeSpec.formatPrice(newTotal)}',
                  style: loewBold.copyWith(
                    fontSize: 12,
                    color: TextTones.secondary,
                    height: 16 / 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onClose,
            child: const _CloseCircle(),
          ),
        ],
      ),
    );
  }
}

class _CloseCircle extends StatelessWidget {
  const _CloseCircle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _kInk.withValues(alpha: 0.2), width: 1.5),
      ),
      child: Icon(Icons.close, size: 14, color: _kInk.withValues(alpha: 0.6)),
    );
  }
}

class _ModalDivider extends StatelessWidget {
  const _ModalDivider();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: _kModalBorder,
      child: SizedBox(height: 1, width: double.infinity),
    );
  }
}

class _ModalFooter extends StatelessWidget {
  final String ctaLabel;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const _ModalFooter({
    required this.ctaLabel,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _OutlinedBtn(label: 'Cancel', onTap: onCancel),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _FilledBtn(label: ctaLabel, onTap: onConfirm),
          ),
        ],
      ),
    );
  }
}

class _OutlinedBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _OutlinedBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(_kButtonRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_kButtonRadius),
        child: Container(
          height: _kButtonHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_kButtonRadius),
            border: Border.all(color: _kInk, width: 1.5),
          ),
          child: Text(
            label,
            style: loewExtraBold.copyWith(fontSize: 14, color: _kInk),
          ),
        ),
      ),
    );
  }
}

class _FilledBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _FilledBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _kInk,
      borderRadius: BorderRadius.circular(_kButtonRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_kButtonRadius),
        child: SizedBox(
          height: _kButtonHeight,
          child: Center(
            child: Text(
              label,
              style: loewExtraBold.copyWith(fontSize: 14, color: _kCream),
            ),
          ),
        ),
      ),
    );
  }
}
