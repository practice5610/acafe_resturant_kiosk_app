import 'dart:async';

import 'package:acafe_customer/di_container.dart' as di;
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipt_history.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipt_send_repo.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

// ── palette ───────────────────────────────────────────────────────────────────
const _bg = Color(0xFFFBF8EF);
const _border = Color(0xFFF0EBD8);
const _ctaBg = Color(0xFF241F20);
const _ctaLabel = Color(0xFFF7F1DE);
const _hintColor = Color(0xFF78706E);
const _errorColor = Color(0xFFD32F2F);
const _sentGreen = Color(0xFF2A8456);

// ── motion ────────────────────────────────────────────────────────────────────
// Form → success cross-fade.
const _swapDuration = Duration(milliseconds: 260);
// How long the success card stays up before the dialog fades itself out.
// Long enough to read the "Sent to" address, short enough not to block the till.
const _sentHold = Duration(milliseconds: 1800);

// ── inline SVGs ───────────────────────────────────────────────────────────────
const _svgX =
    '<svg viewBox="0 0 24 24" fill="none" stroke="#241F20" stroke-width="2" '
    'stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">'
    '<circle cx="12" cy="12" r="10"/>'
    '<path d="m15 9-6 6"/><path d="m9 9 6 6"/></svg>';

// Mail envelope with a green checkmark — Figma 1915:20361.
const _svgMailCheck =
    '<svg width="48" height="48" viewBox="0 0 48 48" fill="none" '
    'xmlns="http://www.w3.org/2000/svg">'
    '<rect x="4" y="10" width="40" height="28" rx="3" stroke="#2A8456" stroke-width="2.5"/>'
    '<path d="M4 14l20 13 20-13" stroke="#2A8456" stroke-width="2.5" '
    'stroke-linecap="round" stroke-linejoin="round"/>'
    '<circle cx="36" cy="34" r="8" fill="#2A8456"/>'
    '<path d="M32 34l3 3 5-5" stroke="white" stroke-width="2" '
    'stroke-linecap="round" stroke-linejoin="round"/>'
    '</svg>';

/// Email receipt dialog (Figma 1915:20799) — States 04–07.
///
/// Triggered from the Receipts sidebar "Email receipt" button.
/// Covers: Empty → Typed → Invalid → Sent states.
Future<void> showPosReceiptEmailDialog({
  required BuildContext context,
  required PosReceiptDetail receipt,
  required int deviceId,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: PosHomeSpec.contextMenuBackdrop,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (dialogContext, _, __) => Material(
      type: MaterialType.transparency,
      child: Center(
        child: _EmailDialog(
          receipt: receipt,
          deviceId: deviceId,
        ),
      ),
    ),
    // Same fade + settle as the other POS modals. The reverse curve is what the
    // success card's auto-dismiss rides out on, together with the backdrop.
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
}

// ── Dialog widget ─────────────────────────────────────────────────────────────

class _EmailDialog extends StatefulWidget {
  final PosReceiptDetail receipt;
  final int deviceId;

  const _EmailDialog({required this.receipt, required this.deviceId});

  @override
  State<_EmailDialog> createState() => _EmailDialogState();
}

class _EmailDialogState extends State<_EmailDialog> {
  final TextEditingController _ctrl = TextEditingController();
  String? _error;
  bool _loading = false;
  bool _sent = false;
  Timer? _autoClose;

  @override
  void dispose() {
    _autoClose?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  /// Pops the dialog only while it is still the top route. A backdrop tap can
  /// close it first; without this guard the timer would then pop the
  /// Receipts screen underneath.
  void _closeIfCurrent() {
    _autoClose?.cancel();
    if (!mounted) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;
    Navigator.of(context).pop();
  }

  bool _isValidEmail(String v) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim());
  }

  Future<void> _submit() async {
    if (_loading || _sent) return;
    final String email = _ctrl.text.trim();

    if (email.isEmpty || !_isValidEmail(email)) {
      setState(() => _error = 'Please enter a valid email address.');
      return;
    }
    setState(() {
      _error = null;
      _loading = true;
    });

    final String reference =
        'pos-receipt-email-${widget.receipt.id}-${DateTime.now().millisecondsSinceEpoch}';

    final response = await di.sl<PosReceiptSendRepo>().send(
      orderId: widget.receipt.id,
      method: 'email',
      email: email,
      deviceId: widget.deviceId,
      reference: reference,
    );

    if (!mounted) return;
    if (!response.isSuccess) {
      setState(() {
        _loading = false;
        _error = response.error?.isNotEmpty == true
            ? response.error!
            : 'Could not send the receipt. Please try again.';
      });
      return;
    }

    setState(() {
      _loading = false;
      _sent = true;
      _sentEmail = _ctrl.text.trim();
    });
    // Hold time runs from the moment the success card starts to swap in.
    _autoClose = Timer(_sentHold, _closeIfCurrent);
  }

  String _sentEmail = '';

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: _swapDuration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(animation),
          child: child,
        ),
      ),
      child: _sent
          ? _SentView(
              key: const ValueKey('sent'),
              receipt: widget.receipt,
              sentEmail: _sentEmail,
              onDismiss: _closeIfCurrent,
            )
          : _buildForm(context),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Container(
      key: const ValueKey('form'),
      width: 560,
      padding: const EdgeInsets.all(20),
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
      child: _FormView(
        ctrl: _ctrl,
        error: _error,
        loading: _loading,
        onCancel: () => Navigator.of(context).pop(),
        onSubmit: _submit,
      ),
    );
  }
}

// ── Form view (States 04–06) ──────────────────────────────────────────────────

class _FormView extends StatelessWidget {
  final TextEditingController ctrl;
  final String? error;
  final bool loading;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  const _FormView({
    required this.ctrl,
    required this.error,
    required this.loading,
    required this.onCancel,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Row(
          children: [
            Expanded(
              child: Text(
                'Email receipt',
                style: loewExtraBold.copyWith(
                  fontSize: 18,
                  color: PosHomeSpec.ink,
                ),
              ),
            ),
            GestureDetector(
              onTap: onCancel,
              child: SvgPicture.string(_svgX, width: 26, height: 26),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          "Enter the customer's email address to send a digital receipt.",
          style: loewMedium.copyWith(
            fontSize: 13,
            color: _hintColor,
          ),
        ),
        const SizedBox(height: 16),
        const Divider(color: _border, thickness: 1, height: 1),
        const SizedBox(height: 16),
        // Email field label
        Text(
          'EMAIL ADDRESS',
          style: loewBold.copyWith(
            fontSize: 11,
            letterSpacing: 0.5,
            color: PosHomeSpec.inkAlpha(0.55),
          ),
        ),
        const SizedBox(height: 6),
        _EmailField(ctrl: ctrl, hasError: error != null),
        if (error != null) ...[
          const SizedBox(height: 6),
          Text(
            error!,
            style: loewMedium.copyWith(fontSize: 12, color: _errorColor),
          ),
        ] else ...[
          const SizedBox(height: 6),
          Text(
            "We'll send a digital copy of this receipt.",
            style: loewMedium.copyWith(fontSize: 12, color: _hintColor),
          ),
        ],
        const SizedBox(height: 20),
        // Actions row
        Row(
          children: [
            Expanded(
              child: _OutlinedBtn(label: 'Cancel', onTap: onCancel),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _FilledBtn(
                label: 'Send receipt',
                loading: loading,
                onTap: onSubmit,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _EmailField extends StatelessWidget {
  final TextEditingController ctrl;
  final bool hasError;

  const _EmailField({required this.ctrl, required this.hasError});

  @override
  Widget build(BuildContext context) {
    final Color borderColor =
        hasError ? _errorColor : const Color(0xFF241F20);
    return SizedBox(
      height: 48,
      child: TextField(
        controller: ctrl,
        keyboardType: TextInputType.emailAddress,
        autofocus: true,
        style: loewRegular.copyWith(fontSize: 14, color: PosHomeSpec.ink),
        decoration: InputDecoration(
          hintText: 'customer@example.com',
          hintStyle: loewRegular.copyWith(
            fontSize: 14,
            color: PosHomeSpec.inkAlpha(0.30),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: borderColor, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: borderColor, width: 1.5),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }
}

// ── Sent view (State 07) — Figma 1915:20355 ──────────────────────────────────

/// Self-dismissing confirmation: no button. It fades out after [_sentHold];
/// a tap on the card or the backdrop closes it sooner.
class _SentView extends StatelessWidget {
  final PosReceiptDetail receipt;
  final String sentEmail;
  final VoidCallback onDismiss;

  const _SentView({
    super.key,
    required this.receipt,
    required this.sentEmail,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final String customer =
        receipt.customerName.isEmpty ? '—' : receipt.customerName;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onDismiss,
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: PosHomeSpec.ink, width: 2),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: PosHomeSpec.ink.withValues(alpha: 0.07),
              blurRadius: 12,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // mail-check icon — pops in just behind the card's own fade
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 520),
              curve: const Interval(0.2, 1, curve: Curves.easeOutBack),
              builder: (_, t, child) => Opacity(
                opacity: t.clamp(0.0, 1.0),
                child: Transform.scale(scale: 0.6 + 0.4 * t, child: child),
              ),
              child: SvgPicture.string(_svgMailCheck, width: 48, height: 48),
            ),
            const SizedBox(height: 20),
            // title
            Text(
              'Email Sent Successfully',
              textAlign: TextAlign.center,
              style: loewExtraBold.copyWith(
                fontSize: 28,
                color: PosHomeSpec.ink,
              ),
            ),
            const SizedBox(height: 24),
            // divider
            const Divider(
              color: Color(0xFFEEE9D8),
              thickness: 1,
              height: 1,
            ),
            const SizedBox(height: 20),
            // receipt summary
            _SummarySection(
              receipt: receipt,
              customer: customer,
              sentEmail: sentEmail,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummarySection extends StatelessWidget {
  final PosReceiptDetail receipt;
  final String customer;
  final String sentEmail;

  const _SummarySection({
    required this.receipt,
    required this.customer,
    required this.sentEmail,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // label
        Text(
          'RECEIPT SUMMARY',
          style: loewExtraBold.copyWith(
            fontSize: 12,
            color: PosHomeSpec.inkAlpha(0.50),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 16),
        _SummaryRow(label: 'Receipt Number', value: '#${receipt.id}'),
        const SizedBox(height: 12),
        _SummaryRow(label: 'Customer', value: customer),
        const SizedBox(height: 12),
        _SummaryRow(label: 'Sent to', value: sentEmail),
        const SizedBox(height: 16),
        // total row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Total Amount',
              style: loewExtraBold.copyWith(
                fontSize: 16,
                color: PosHomeSpec.ink,
              ),
            ),
            Text(
              PosHomeSpec.formatPrice(receipt.total),
              style: loewExtraBold.copyWith(
                fontSize: 20,
                color: _sentGreen,
              ),
            ),
          ],
        ),
      ],
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
          style: loewMedium.copyWith(
            fontSize: 14,
            color: PosHomeSpec.inkAlpha(0.50),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: loewBold.copyWith(
              fontSize: 14,
              color: PosHomeSpec.ink,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Shared button widgets ─────────────────────────────────────────────────────

class _OutlinedBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _OutlinedBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: PosHomeSpec.ink, width: 1.5),
          ),
          child: Text(
            label,
            style: loewBold.copyWith(
              fontSize: 15,
              color: PosHomeSpec.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _FilledBtn extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;

  const _FilledBtn({
    required this.label,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: loading ? const Color(0xFFD4CDBA) : _ctaBg,
          borderRadius: BorderRadius.circular(10),
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
                label,
                style: loewBold.copyWith(
                  fontSize: 15,
                  color: _ctaLabel,
                ),
              ),
      ),
    );
  }
}
