import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_payment_spec.dart';
import 'package:acafe_customer/theme/text_legibility.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';

// ─── palette (Figma 1915:9648) ───────────────────────────────────────────────
const _headerOpacity = TextTones.hintOpacity; // Figma 0.40
const _subtitleOpacity = TextTones.hintOpacity; // Figma 0.33
const _stepBorder = PosPaymentSpec.v2OtherRowBorder; // #E8E3D5
const _inputBorderInactive = PosHomeSpec.tableFieldBorder; // #E0D9C8
const _divider = PosHomeSpec.hairline; // #F0EBD8

/// Right pane for the Stand-alone terminal flow (Family 5) —
/// `payment-summary-card` (Figma **1915:9648**, frame 04).
///
/// p-24, gap-16: header, the amount to key in, a hairline, then three numbered
/// steps and the optional approval code (py-12, gap-10). The pane has no button
/// of its own — the frame confirms through the screen's sticky "Confirm
/// Payment" bar, which calls [onConfirm].
///
/// The approval code field writes to [approvalCode] (a [ValueNotifier<String>])
/// so only the field widget rebuilds on typing — no root setState.
class PosStandalonePanel extends StatelessWidget {
  final double grandTotal;
  final ValueNotifier<String> approvalCode;
  final bool loading;

  /// Kept for callers; the sticky bar owns the confirm action.
  final VoidCallback onConfirm;

  /// True in the receipt change-method flow: hides the approval-code input;
  /// the screen's own Confirm change bar commits.
  final bool changeMode;

  const PosStandalonePanel({
    super.key,
    required this.grandTotal,
    required this.approvalCode,
    required this.loading,
    required this.onConfirm,
    this.changeMode = false,
  });

  static const double _gap = 16;

  @override
  Widget build(BuildContext context) {
    final String amount = PosHomeSpec.formatPrice(grandTotal, padZero: false);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── summary-header (1915:9649): gap-4, pb-12 ───────────────────
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'STAND-ALONE',
                  style: loewBold.copyWith(
                    fontSize: 14,
                    letterSpacing: 1,
                    color: PosHomeSpec.inkAlpha(_headerOpacity),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pay on the separate card terminal',
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

          // ── total display (1915:9652): gap-4, pb-12 ────────────────────
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  amount,
                  maxLines: 1,
                  style: loewExtraBold.copyWith(
                    fontSize: 48,
                    color: PosHomeSpec.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Amount to enter on the terminal',
                  style: swiss721Light.copyWith(
                    fontSize: 13,
                    height: PosPaymentSpec.figmaLeading(13),
                    color: PosHomeSpec.inkAlpha(_headerOpacity),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: _gap),

          // ── divider-top (1915:9655) ────────────────────────────────────
          const ColoredBox(
            color: _divider,
            child: SizedBox(height: 1, width: double.infinity),
          ),
          const SizedBox(height: _gap),

          // ── steps + approval code (1915:9656): py-12, gap-10 ───────────
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'HOW TO DO STAND ALONE PAYMENT',
                  style: loewBold.copyWith(
                    fontSize: 10,
                    letterSpacing: 0.5,
                    color: PosHomeSpec.inkAlpha(_subtitleOpacity),
                  ),
                ),
                const SizedBox(height: 10),
                _StepRow(
                  number: 1,
                  text: 'Enter $amount on the card terminal',
                ),
                const SizedBox(height: 10),
                const _StepRow(number: 2, text: 'Customer pays on the terminal'),
                const SizedBox(height: 10),
                const _StepRow(
                  number: 3,
                  text: 'Confirm here once the payment is approved',
                ),
                if (!changeMode) ...[
                  const SizedBox(height: 10),
                  // terminal-approval-code (1915:9670): gap-4.
                  Text(
                    'Approval code (optional)',
                    style: loewRegular.copyWith(
                      fontSize: 12,
                      color: TextTones.secondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _ApprovalCodeField(notifier: approvalCode),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One numbered instruction step (Figma: terminal-step-N).
class _StepRow extends StatelessWidget {
  final int number;
  final String text;

  const _StepRow({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _stepBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          // Step badge
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: PosHomeSpec.ink,
              borderRadius: BorderRadius.circular(5),
            ),
            alignment: Alignment.center,
            child: Text(
              '$number',
              style: loewBold.copyWith(
                fontSize: 11,
                letterSpacing: 0.5,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: loewMedium.copyWith(
                fontSize: 14,
                color: PosHomeSpec.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Approval-code text field that writes directly to a [ValueNotifier<String>].
class _ApprovalCodeField extends StatefulWidget {
  final ValueNotifier<String> notifier;

  const _ApprovalCodeField({required this.notifier});

  @override
  State<_ApprovalCodeField> createState() => _ApprovalCodeFieldState();
}

class _ApprovalCodeFieldState extends State<_ApprovalCodeField> {
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
    // `approval-code-input` (1915:9672): 37 tall, px-14 py-10, Loew Medium 14.
    return SizedBox(
      height: 37,
      child: TextField(
        controller: _ctrl,
        textCapitalization: TextCapitalization.characters,
        style: loewMedium.copyWith(fontSize: 14, color: PosHomeSpec.ink),
        cursorColor: PosHomeSpec.ink,
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Code from the terminal slip',
          hintStyle: loewMedium.copyWith(
            fontSize: 14,
            color: TextTones.hint,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          enabledBorder: border(_inputBorderInactive),
          focusedBorder: border(PosHomeSpec.ink),
        ),
      ),
    );
  }
}
