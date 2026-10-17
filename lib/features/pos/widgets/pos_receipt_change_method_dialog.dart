import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipt_history.dart';
import 'package:acafe_customer/features/pos/domain/pos_sale_session.dart';
import 'package:acafe_customer/features/pos/widgets/pos_payment_method_selector.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

// ── palette ───────────────────────────────────────────────────────────────────
const _bg           = Color(0xFFFBF8EF);
const _border       = Color(0xFFF0EBD8);
const _hintText     = Color(0xFFA6A199);
const _helperText   = Color(0xFF78706E);
const _ctaBg        = Color(0xFF241F20);
const _ctaLabel     = Color(0xFFF7F1DE);

// ── layout constants (Figma 1915:20539) ──────────────────────────────────────
const _modalWidth       = 820.0;
const _bodyColumnGap    = 28.0;
const _reasonHeight     = 150.0;
const _reasonRadius     = 12.0;
const _sectionLabelSize = 11.0;
const _confirmRadius    = 12.0;

const _svgX =
    '<svg viewBox="0 0 26 26" fill="none" stroke="#241F20" stroke-width="2" '
    'stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">'
    '<circle cx="13" cy="13" r="11"/>'
    '<path d="m16.5 9.5-7 7"/><path d="m9.5 9.5 7 7"/></svg>';


/// The operator's choice in the change-method dialog. Not yet applied: the
/// payment screen commits it when the operator confirms there.
class PosMethodChangeDraft {
  final String method;
  final String reason;

  const PosMethodChangeDraft({required this.method, required this.reason});
}

/// Opens the "Change payment method" modal (Figma 1915:20539, State 08).
///
/// Returns the new method string (e.g. 'card', 'cash', 'invoice', 'standalone')
/// on a confirmed change, or null if the dialog was dismissed without saving.
Future<PosMethodChangeDraft?> showPosReceiptChangeMethodDialog({
  required BuildContext context,
  required PosReceiptDetail receipt,
}) {
  return showGeneralDialog<PosMethodChangeDraft>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: PosHomeSpec.contextMenuBackdrop,
    pageBuilder: (_, __, ___) => Material(
      type: MaterialType.transparency,
      child: Center(
        child: _ChangeMethodDialog(receipt: receipt),
      ),
    ),
  );
}

// ── Main dialog widget ────────────────────────────────────────────────────────

class _ChangeMethodDialog extends StatefulWidget {
  final PosReceiptDetail receipt;

  const _ChangeMethodDialog({required this.receipt});

  @override
  State<_ChangeMethodDialog> createState() => _ChangeMethodDialogState();
}

class _ChangeMethodDialogState extends State<_ChangeMethodDialog> {
  late String? _selectedMethod;
  final TextEditingController _reasonCtrl = TextEditingController();
  bool _reasonTouched = false;

  @override
  void initState() {
    super.initState();
    _selectedMethod = widget.receipt.method;
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  String get _currentMethod => _labelFor(widget.receipt.method);

  static String _labelFor(String method) {
    switch (method) {
      case 'card':       return 'Card';
      case 'invoice':    return 'Invoice';
      case 'standalone': return 'Stand-alone';
      default:           return 'Cash';
    }
  }

  /// The primary method to pass to the selector. When an OTHER method is
  /// active the primary selection is irrelevant — default to card so neither
  /// primary tile appears selected.
  PosPaymentMethod get _primaryMethod {
    if (_selectedMethod == 'cash') return PosPaymentMethod.cash;
    return PosPaymentMethod.card;
  }

  void _selectPrimary(PosPaymentMethod m) {
    setState(() {
      _selectedMethod = m == PosPaymentMethod.cash ? 'cash' : 'card';
    });
  }

  void _selectOther(String key) {
    setState(() => _selectedMethod = key);
  }

  void _cancelOther() {
    // Fall back to card when deselecting an OTHER method.
    setState(() => _selectedMethod = 'card');
  }

  void _confirm() {
    final String? method = _selectedMethod;
    final String reason = _reasonCtrl.text.trim();
    if (method == null) return;
    if (reason.isEmpty) {
      setState(() => _reasonTouched = true);
      return;
    }
    Navigator.of(context).pop(PosMethodChangeDraft(method: method, reason: reason));
  }

  @override
  Widget build(BuildContext context) {
    final bool reasonEmpty =
        _reasonTouched && _reasonCtrl.text.trim().isEmpty;

    return _SelectionModal(
      receipt: widget.receipt,
      currentMethod: _currentMethod,
      primaryMethod: _primaryMethod,
      invoiceActive: _selectedMethod == 'invoice',
      standaloneActive: _selectedMethod == 'standalone',
      onSelectPrimary: _selectPrimary,
      onInvoice: () => _selectOther('invoice'),
      onStandalone: () => _selectOther('standalone'),
      onCancelOther: _cancelOther,
      reasonCtrl: _reasonCtrl,
      reasonError: reasonEmpty ? 'Please enter a reason for this change.' : null,
      loading: false,
      onReasonChanged: (_) {
        if (_reasonTouched) setState(() {});
      },
      onConfirm: _selectedMethod != null ? _confirm : null,
      onClose: () => Navigator.of(context).pop(),
    );
  }
}

// ── State 08: Selection modal ─────────────────────────────────────────────────

class _SelectionModal extends StatelessWidget {
  final PosReceiptDetail receipt;
  final String currentMethod;
  final PosPaymentMethod primaryMethod;
  final bool invoiceActive;
  final bool standaloneActive;
  final ValueChanged<PosPaymentMethod> onSelectPrimary;
  final VoidCallback onInvoice;
  final VoidCallback onStandalone;
  final VoidCallback onCancelOther;
  final TextEditingController reasonCtrl;
  final String? reasonError;
  final bool loading;
  final ValueChanged<String> onReasonChanged;
  final VoidCallback? onConfirm;
  final VoidCallback onClose;

  const _SelectionModal({
    required this.receipt,
    required this.currentMethod,
    required this.primaryMethod,
    required this.invoiceActive,
    required this.standaloneActive,
    required this.onSelectPrimary,
    required this.onInvoice,
    required this.onStandalone,
    required this.onCancelOther,
    required this.reasonCtrl,
    required this.loading,
    required this.onReasonChanged,
    required this.onConfirm,
    required this.onClose,
    this.reasonError,
  });

  @override
  Widget build(BuildContext context) {
    final double maxH = MediaQuery.of(context).size.height * 0.90;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: _modalWidth, maxHeight: maxH),
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
              _ModalHeader(
                receipt: receipt,
                currentMethod: currentMethod,
                onClose: onClose,
              ),
              const SizedBox(height: 16),
              const Divider(color: _border, thickness: 1, height: 1),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: PosPaymentMethodSelector(
                      method: primaryMethod,
                      cashEnabled: true,
                      cardEnabled: true,
                      onSelectMethod: onSelectPrimary,
                      // Splits cannot be a receipt display override.
                      showSplitOptions: false,
                      // Invoice and Stand-alone are available.
                      onInvoice: onInvoice,
                      invoiceActive: invoiceActive,
                      onStandalone: onStandalone,
                      standaloneActive: standaloneActive,
                      onCancelActiveOther: onCancelOther,
                    ),
                  ),
                  const SizedBox(width: _bodyColumnGap),
                  Expanded(
                    child: _ReasonGroup(
                      ctrl: reasonCtrl,
                      error: reasonError,
                      onChanged: onReasonChanged,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _ConfirmButton(loading: loading, onTap: onConfirm),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModalHeader extends StatelessWidget {
  final PosReceiptDetail receipt;
  final String currentMethod;
  final VoidCallback onClose;

  const _ModalHeader({
    required this.receipt,
    required this.currentMethod,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
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
                'Change payment method',
                style: loewExtraBold.copyWith(
                  fontSize: 18,
                  color: PosHomeSpec.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Receipt #${receipt.id} · ${PosHomeSpec.formatPrice(receipt.total)} · now paid by $currentMethod',
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

// ── Reason textarea column ────────────────────────────────────────────────────

class _ReasonGroup extends StatelessWidget {
  final TextEditingController ctrl;
  final String? error;
  final ValueChanged<String>? onChanged;

  const _ReasonGroup({
    required this.ctrl,
    this.error,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasError = error != null;
    final Color borderColor = hasError ? const Color(0xFFD32F2F) : PosHomeSpec.ink;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              'REASON',
              style: loewBold.copyWith(
                fontSize: _sectionLabelSize,
                color: PosHomeSpec.inkAlpha(0.60),
                letterSpacing: 0.5,
              ),
            ),
            Text(
              ' *',
              style: loewBold.copyWith(
                fontSize: _sectionLabelSize,
                color: const Color(0xFFD32F2F),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          height: _reasonHeight,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: borderColor, width: 1.5),
            borderRadius: BorderRadius.circular(_reasonRadius),
          ),
          child: TextField(
            controller: ctrl,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            onChanged: onChanged,
            style: loewRegular.copyWith(
              fontSize: 14,
              color: PosHomeSpec.ink,
            ),
            decoration: InputDecoration(
              hintText: 'e.g. Customer paid cash after card failed',
              hintStyle: loewRegular.copyWith(
                fontSize: 14,
                color: _hintText,
              ),
              contentPadding: const EdgeInsets.only(
                left: 14,
                right: 14,
                top: 16,
                bottom: 10,
              ),
              border: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: 4),
        if (hasError)
          Text(
            error!,
            style: loewBold.copyWith(
              fontSize: 12,
              color: const Color(0xFFD32F2F),
            ),
          )
        else
          Text(
            'The amount stays the same. The change is logged with your name and time.',
            style: loewBold.copyWith(
              fontSize: 12,
              color: _helperText,
            ),
          ),
      ],
    );
  }
}

// ── Confirm button ────────────────────────────────────────────────────────────

class _ConfirmButton extends StatelessWidget {
  final bool loading;
  final VoidCallback? onTap;

  const _ConfirmButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null && !loading;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: onTap == null ? 0.40 : 1.0,
        child: Container(
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _ctaBg,
            borderRadius: BorderRadius.circular(_confirmRadius),
          ),
          child: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  'Confirm change',
                  style: loewExtraBold.copyWith(
                    fontSize: 14,
                    color: _ctaLabel,
                  ),
                ),
        ),
      ),
    );
  }
}
