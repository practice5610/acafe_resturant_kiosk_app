import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_invoice_model.dart';
import 'package:acafe_customer/features/pos/domain/pos_payment_spec.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';

// ─── palette constants (Figma 1915:10440) ────────────────────────────────────
const _headerOpacity = 0.40;
const _subtitleOpacity = 0.33;
const _labelOpacity = 0.33;
const _fieldLabelOpacity = 0.53;
const _borderInactive = PosHomeSpec.tableFieldBorder; // #E0D9C8
const _borderActive = PosHomeSpec.ink;
const _divider = PosHomeSpec.hairline; // #F0EBD8

/// Right pane for the Invoice flow (Family 4) — `payment-summary-card`
/// (Figma **1915:10440**, frame 03).
///
/// p-24, gap-16: the INVOICE header, the amount to invoice, a hairline, the
/// details form (labelled fields) and the "Send by email" toggle. The pane has
/// no button of its own — the frame confirms through the screen's sticky
/// "Confirm Payment" bar, which calls [onSubmit] when the form is valid.
class PosInvoicePanel extends StatelessWidget {
  final double grandTotal;
  final PosInvoiceFormState form;
  final bool loading;

  /// Kept for callers; the sticky bar owns the submit action.
  final VoidCallback onSubmit;

  /// True in the receipt change-method flow: the panel shows the header and
  /// amount only. The details form belongs to order placement; the change
  /// flow commits through the screen's own bar.
  final bool changeMode;

  const PosInvoicePanel({
    super.key,
    required this.grandTotal,
    required this.form,
    required this.loading,
    required this.onSubmit,
    this.changeMode = false,
  });

  static const double _gap = 16;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── summary-header (1915:10441): pb-12, gap-4 ──────────────────
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'INVOICE',
                  style: loewBold.copyWith(
                    fontSize: 14,
                    letterSpacing: 1,
                    color: PosHomeSpec.inkAlpha(_headerOpacity),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Invoice details',
                  style: swiss721Light.copyWith(
                    fontSize: 12,
                    height: PosPaymentSpec.figmaLeading(12),
                    color: PosHomeSpec.inkAlpha(_subtitleOpacity),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: _gap),

          // ── invoice-total-display (1915:10444): pb-12, gap-4 ───────────
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  PosHomeSpec.formatPrice(grandTotal, padZero: false),
                  maxLines: 1,
                  style: loewExtraBold.copyWith(
                    fontSize: 48,
                    color: PosHomeSpec.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Amount to invoice',
                  style: swiss721Light.copyWith(
                    fontSize: 13,
                    height: PosPaymentSpec.figmaLeading(13),
                    color: PosHomeSpec.inkAlpha(_headerOpacity),
                  ),
                ),
              ],
            ),
          ),
          if (!changeMode) ...[
            const SizedBox(height: _gap),
            // ── divider-top (1915:10447) ─────────────────────────────────
            const ColoredBox(
              color: _divider,
              child: SizedBox(height: 1, width: double.infinity),
            ),
            const SizedBox(height: _gap),

            // ── invoice-form (1915:10448): py-12, gap-10 ─────────────────
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'INVOICE DETAILS',
                    style: loewBold.copyWith(
                      fontSize: 10,
                      letterSpacing: 0.5,
                      color: PosHomeSpec.inkAlpha(_labelOpacity),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _InvoiceTextField(
                    notifier: form.companyName,
                    label: 'Company name',
                  ),
                  const SizedBox(height: 10),
                  _InvoiceTextField(
                    notifier: form.vatNumber,
                    label: 'VAT number',
                  ),
                  const SizedBox(height: 10),
                  _InvoiceTextField(
                    notifier: form.email,
                    label: 'Email address',
                    keyboardType: TextInputType.emailAddress,
                  ),
                ],
              ),
            ),
            const SizedBox(height: _gap),

            // ── invoice-send-toggle (1915:10466) ─────────────────────────
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
                            letterSpacing: 0.5,
                            color: PosHomeSpec.inkAlpha(_labelOpacity),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Send automatically after completing',
                          style: swiss721Light.copyWith(
                            fontSize: 13,
                            height: PosPaymentSpec.figmaLeading(13),
                            color: PosHomeSpec.inkAlpha(_fieldLabelOpacity),
                          ),
                        ),
                      ],
                    ),
                  ),
                  PosPayToggle(
                    value: sendByEmail,
                    onChanged: (v) => form.sendByEmail.value = v,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// `toggle-track` (node 1915:10470): 36×20, r10, ink track with a white r8
/// thumb. Figma draws only the "on" state; "off" uses the POS inactive fill
/// with the thumb at the start.
class PosPayToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const PosPayToggle({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 36,
          height: 20,
          padding: const EdgeInsets.all(2),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          decoration: BoxDecoration(
            color: value ? PosHomeSpec.ink : PosHomeSpec.inactiveFill,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Container(
            width: 16,
            height: 16,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

/// `invoice-field-*` (node 1915:10450): a Loew Regular 12 label over a
/// 37px input (px-14 py-10, r10, 1.5px stroke — ink when focused, `#E0D9C8`
/// otherwise) carrying Loew Medium 14. Writes to a [ValueNotifier<String>].
class _InvoiceTextField extends StatefulWidget {
  final ValueNotifier<String> notifier;
  final String label;
  final TextInputType keyboardType;

  const _InvoiceTextField({
    required this.notifier,
    required this.label,
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
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          // No floating label, so no notch gap — it would inset the text 4px.
          gapPadding: 0,
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: color, width: 1.5),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.label,
          style: loewRegular.copyWith(
            fontSize: 12,
            color: PosHomeSpec.inkAlpha(_fieldLabelOpacity),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 37,
          child: TextField(
            controller: _ctrl,
            keyboardType: widget.keyboardType,
            style: loewMedium.copyWith(fontSize: 14, color: PosHomeSpec.ink),
            cursorColor: PosHomeSpec.ink,
            decoration: InputDecoration(
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              enabledBorder: border(_borderInactive),
              focusedBorder: border(_borderActive),
            ),
          ),
        ),
      ],
    );
  }
}
