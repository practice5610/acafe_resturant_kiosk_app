import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipt_history.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

// ── palette ───────────────────────────────────────────────────────────────────
const _bg         = Color(0xFFFBF8EF);
const _border     = Color(0xFFF0EBD8);
const _inputBorder = Color(0xFF241F20);
const _hintText   = Color(0xFFA6A199);
const _helperText = Color(0xFF78706E);
const _ctaBg      = Color(0xFF241F20);
const _ctaLabel   = Color(0xFFF7F1DE);

// ── inline SVG ────────────────────────────────────────────────────────────────
const _svgX =
    '<svg viewBox="0 0 26 26" fill="none" stroke="#241F20" stroke-width="2" '
    'stroke-linecap="round" stroke-linejoin="round" '
    'xmlns="http://www.w3.org/2000/svg">'
    '<circle cx="13" cy="13" r="11"/>'
    '<path d="m16.5 9.5-7 7"/><path d="m9.5 9.5 7 7"/></svg>';

/// Opens "Reopen receipt?" confirmation dialog — Figma **1915:20906**.
///
/// [onConfirm] is called with the optional reason text when the user taps
/// "Reopen receipt".  The dialog closes itself before calling [onConfirm].
Future<void> showPosReceiptReopenDialog({
  required BuildContext context,
  required PosReceiptDetail receipt,
  void Function(String reason)? onConfirm,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: PosHomeSpec.contextMenuBackdrop,
    pageBuilder: (_, __, ___) => Material(
      type: MaterialType.transparency,
      child: Center(
        child: _ReopenDialog(
          receipt: receipt,
          onConfirm: onConfirm,
        ),
      ),
    ),
  );
}

// ── Dialog widget ─────────────────────────────────────────────────────────────

class _ReopenDialog extends StatefulWidget {
  final PosReceiptDetail receipt;
  final void Function(String reason)? onConfirm;

  const _ReopenDialog({required this.receipt, this.onConfirm});

  @override
  State<_ReopenDialog> createState() => _ReopenDialogState();
}

class _ReopenDialogState extends State<_ReopenDialog> {
  final TextEditingController _reason = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    setState(() => _loading = true);
    final reason = _reason.text.trim();
    Navigator.of(context).pop();
    widget.onConfirm?.call(reason);
  }

  @override
  Widget build(BuildContext context) {
    final double maxH = MediaQuery.of(context).size.height * 0.90;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 560, maxHeight: maxH),
      child: Container(
        decoration: BoxDecoration(
          color: _bg,
          border: Border.all(color: _border, width: 1.5),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26000000),
              blurRadius: 16,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DialogHeader(
                receipt: widget.receipt,
                onClose: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 16),
              const Divider(color: _border, thickness: 1, height: 1),
              const SizedBox(height: 16),
              Text(
                'You can change add-ons, quantities and the customer name. '
                'If the total changes, the difference is charged or refunded on the original payment method.',
                style: loewRegular.copyWith(
                  fontSize: 14,
                  color: PosHomeSpec.ink,
                  fontFamily: 'Swiss721Light',
                ),
              ),
              const SizedBox(height: 16),
              _ReasonInput(ctrl: _reason),
              const SizedBox(height: 16),
              _Footer(
                loading: _loading,
                onCancel: () => Navigator.of(context).pop(),
                onConfirm: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _DialogHeader extends StatelessWidget {
  final PosReceiptDetail receipt;
  final VoidCallback onClose;

  const _DialogHeader({required this.receipt, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final String currentMethod = receipt.method == 'card' ? 'Card' : 'Cash';
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 34),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reopen receipt #${receipt.id}?',
                style: loewExtraBold.copyWith(
                  fontSize: 18,
                  color: PosHomeSpec.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Receipt #${receipt.id} · ${PosHomeSpec.formatPrice(receipt.total)} · paid by $currentMethod',
                style: loewBold.copyWith(
                  fontSize: 12,
                  color: PosHomeSpec.inkAlpha(0.60),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: GestureDetector(
            onTap: onClose,
            child: SvgPicture.string(_svgX, width: 26, height: 26),
          ),
        ),
      ],
    );
  }
}

// ── Reason input ──────────────────────────────────────────────────────────────

class _ReasonInput extends StatelessWidget {
  final TextEditingController ctrl;

  const _ReasonInput({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'REASON',
          style: loewBold.copyWith(
            fontSize: 11,
            color: PosHomeSpec.inkAlpha(0.60),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: _inputBorder, width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: ctrl,
            style: loewRegular.copyWith(fontSize: 14, color: PosHomeSpec.ink),
            decoration: InputDecoration(
              hintText: 'e.g. Wrong milk was selected',
              hintStyle: loewRegular.copyWith(
                fontSize: 14,
                color: _hintText,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              border: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'The original receipt is kept. Every edit is logged with your name and time.',
          style: loewBold.copyWith(fontSize: 12, color: _helperText),
        ),
      ],
    );
  }
}

// ── Footer ────────────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  final bool loading;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const _Footer({
    required this.loading,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: loading ? null : onCancel,
            child: Container(
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: PosHomeSpec.ink, width: 1.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Cancel',
                style: loewExtraBold.copyWith(
                  fontSize: 14,
                  color: PosHomeSpec.ink,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: loading ? null : onConfirm,
            child: Container(
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _ctaBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Reopen receipt',
                      style: loewExtraBold.copyWith(
                        fontSize: 14,
                        color: _ctaLabel,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
