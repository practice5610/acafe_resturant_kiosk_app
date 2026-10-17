import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_invoice_model.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';

// ─── palette constants (Figma 1915:10311) ────────────────────────────────────
const _headerOpacity = 0.40;
const _subtitleOpacity = 0.33;
const _labelOpacity = 0.33;
const _subtitleBodyOpacity = 0.53;
const _borderInactive = Color(0xFFE0D9C8);
const _borderActive = Color(0xFF241F20);
const _divider = Color(0xFFF0EBD8);

/// Right pane for the Invoice flow (Family 4, Figma 1915:10311).
///
/// Shows the order total and a compact form: company name, VAT number,
/// email, and a "Send by email" toggle. A "Create Invoice" pill CTA at
/// the bottom calls [onSubmit] when the form is valid (company name filled).
class PosInvoicePanel extends StatelessWidget {
  final double grandTotal;
  final PosInvoiceFormState form;
  final bool loading;
  final VoidCallback onSubmit;

  /// True in the receipt change-method flow: the panel shows the header and
  /// amount only. The details form and "Create Invoice" CTA belong to order
  /// placement; the change flow commits through the screen's own bar.
  final bool changeMode;

  const PosInvoicePanel({
    super.key,
    required this.grandTotal,
    required this.form,
    required this.loading,
    required this.onSubmit,
    this.changeMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── INVOICE header ──────────────────────────────────────────
          Text(
            'INVOICE',
            style: loewBold.copyWith(
              fontSize: 14,
              letterSpacing: 1,
              color: PosHomeSpec.inkAlpha(_headerOpacity),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Invoice details',
            style: swiss721Light.copyWith(
              fontSize: 12,
              color: PosHomeSpec.inkAlpha(_subtitleOpacity),
            ),
          ),
          const SizedBox(height: 12),

          // ── Grand total ─────────────────────────────────────────────
          Text(
            PosHomeSpec.formatPrice(grandTotal),
            style: loewExtraBold.copyWith(
              fontSize: 48,
              color: PosHomeSpec.ink,
              height: 1.0,
            ),
          ),
          Text(
            'Amount to invoice',
            style: swiss721Light.copyWith(
              fontSize: 13,
              color: PosHomeSpec.inkAlpha(_headerOpacity),
            ),
          ),
          if (changeMode) ...[
            const SizedBox(height: 8),
          ] else ...[
          const SizedBox(height: 16),

          // ── Divider ─────────────────────────────────────────────────
          const Divider(color: _divider, thickness: 1, height: 1),
          const SizedBox(height: 16),

          // ── INVOICE DETAILS label ───────────────────────────────────
          Text(
            'INVOICE DETAILS',
            style: loewBold.copyWith(
              fontSize: 10,
              letterSpacing: 0.5,
              color: PosHomeSpec.inkAlpha(_labelOpacity),
            ),
          ),
          const SizedBox(height: 10),

          // ── Company name ────────────────────────────────────────────
          _InvoiceTextField(
            notifier: form.companyName,
            hint: 'Company name',
          ),
          const SizedBox(height: 10),

          // ── VAT number ──────────────────────────────────────────────
          _InvoiceTextField(
            notifier: form.vatNumber,
            hint: 'VAT number',
          ),
          const SizedBox(height: 10),

          // ── Email ───────────────────────────────────────────────────
          _InvoiceTextField(
            notifier: form.email,
            hint: 'Email address',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),

          // ── Divider ─────────────────────────────────────────────────
          const Divider(color: _divider, thickness: 1, height: 1),
          const SizedBox(height: 12),

          // ── Send by email toggle row ─────────────────────────────────
          ValueListenableBuilder<bool>(
            valueListenable: form.sendByEmail,
            builder: (context, sendByEmail, _) => Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SEND BY EMAIL',
                        style: loewBold.copyWith(
                          fontSize: 12,
                          color: PosHomeSpec.inkAlpha(_labelOpacity),
                        ),
                      ),
                      Text(
                        'Send a copy to the company email',
                        style: swiss721Light.copyWith(
                          fontSize: 13,
                          color: PosHomeSpec.inkAlpha(_subtitleBodyOpacity),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: sendByEmail,
                  onChanged: (v) => form.sendByEmail.value = v,
                  activeThumbColor: PosHomeSpec.ink,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Create Invoice CTA ───────────────────────────────────────
          ValueListenableBuilder<String>(
            valueListenable: form.companyName,
            builder: (context, name, _) {
              final enabled = name.trim().isNotEmpty && !loading;
              return GestureDetector(
                onTap: enabled ? onSubmit : null,
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: enabled ? PosHomeSpec.ink : const Color(0xFFD4CDBA),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Center(
                    child: loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Create Invoice',
                            style: loewBold.copyWith(
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

/// A single text input that writes to a [ValueNotifier<String>].
class _InvoiceTextField extends StatefulWidget {
  final ValueNotifier<String> notifier;
  final String hint;
  final TextInputType keyboardType;

  const _InvoiceTextField({
    required this.notifier,
    required this.hint,
    this.keyboardType = TextInputType.text,
  });

  @override
  State<_InvoiceTextField> createState() => _InvoiceTextFieldState();
}

class _InvoiceTextFieldState extends State<_InvoiceTextField> {
  late final TextEditingController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.notifier.value);
    _ctrl.addListener(() => widget.notifier.value = _ctrl.text);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
        controller: _ctrl,
        keyboardType: widget.keyboardType,
        style: loewBold.copyWith(fontSize: 14, color: PosHomeSpec.ink),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: swiss721Light.copyWith(
            fontSize: 14,
            color: PosHomeSpec.inkAlpha(0.35),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _borderInactive, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _borderActive, width: 1.5),
          ),
        ),
    );
  }
}
