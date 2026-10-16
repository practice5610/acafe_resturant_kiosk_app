import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';

// ─── palette (Figma 1915:9519) ───────────────────────────────────────────────
const _headerOpacity = 0.40;
const _subtitleOpacity = 0.33;
const _stepBorder = Color(0xFFE8E3D5);
const _inputBorderInactive = Color(0xFFE0D9C8);
const _divider = Color(0xFFF0EBD8);

/// Right pane for the Stand-alone terminal flow (Family 5, Figma 1915:9519).
///
/// Displays the grand total, three numbered instruction steps, an optional
/// approval-code input, and a "Confirm Payment" pill CTA.
///
/// The approval code field writes to [approvalCode] (a [ValueNotifier<String>])
/// so only the field widget rebuilds on typing — no root setState.
class PosStandalonePanel extends StatelessWidget {
  final double grandTotal;
  final ValueNotifier<String> approvalCode;
  final bool loading;
  final VoidCallback onConfirm;

  const PosStandalonePanel({
    super.key,
    required this.grandTotal,
    required this.approvalCode,
    required this.loading,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── STAND-ALONE header ──────────────────────────────────────
          Text(
            'STAND-ALONE',
            style: loewBold.copyWith(
              fontSize: 14,
              letterSpacing: 1,
              color: PosHomeSpec.inkAlpha(_headerOpacity),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Pay on the separate card terminal',
            style: swiss721Light.copyWith(
              fontSize: 12,
              color: PosHomeSpec.inkAlpha(_subtitleOpacity),
            ),
          ),
          const SizedBox(height: 12),

          // ── Grand total ──────────────────────────────────────────────
          Text(
            PosHomeSpec.formatPrice(grandTotal),
            style: loewExtraBold.copyWith(
              fontSize: 48,
              color: PosHomeSpec.ink,
              height: 1.0,
            ),
          ),
          Text(
            'Amount to enter on the terminal',
            style: swiss721Light.copyWith(
              fontSize: 13,
              color: PosHomeSpec.inkAlpha(_headerOpacity),
            ),
          ),
          const SizedBox(height: 16),

          // ── Divider ──────────────────────────────────────────────────
          const Divider(color: _divider, thickness: 1, height: 1),
          const SizedBox(height: 16),

          // ── HOW TO label ─────────────────────────────────────────────
          Text(
            'HOW TO DO STAND ALONE PAYMENT',
            style: loewBold.copyWith(
              fontSize: 10,
              letterSpacing: 0.5,
              color: PosHomeSpec.inkAlpha(_subtitleOpacity),
            ),
          ),
          const SizedBox(height: 10),

          // ── Step 1 ───────────────────────────────────────────────────
          _StepRow(
            number: 1,
            text:
                'Enter ${PosHomeSpec.formatPrice(grandTotal)} on the card terminal',
          ),
          const SizedBox(height: 10),

          // ── Step 2 ───────────────────────────────────────────────────
          const _StepRow(number: 2, text: 'Customer pays on the terminal'),
          const SizedBox(height: 10),

          // ── Step 3 ───────────────────────────────────────────────────
          const _StepRow(
            number: 3,
            text: 'Confirm here once the payment is approved',
          ),
          const SizedBox(height: 16),

          // ── Approval code input ──────────────────────────────────────
          Text(
            'Approval code (optional)',
            style: loewRegular.copyWith(
              fontSize: 12,
              color: PosHomeSpec.inkAlpha(0.53),
            ),
          ),
          const SizedBox(height: 6),
          _ApprovalCodeField(notifier: approvalCode),
          const SizedBox(height: 20),

          // ── Confirm Payment CTA ──────────────────────────────────────
          GestureDetector(
            onTap: loading ? null : onConfirm,
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: loading ? const Color(0xFFD4CDBA) : PosHomeSpec.ink,
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
                        'Confirm Payment',
                        style: loewBold.copyWith(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 8),
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
    return TextField(
      controller: _ctrl,
      textCapitalization: TextCapitalization.characters,
      style: loewBold.copyWith(fontSize: 14, color: PosHomeSpec.ink),
      decoration: InputDecoration(
        hintText: 'Code from the terminal slip',
        hintStyle: loewMedium.copyWith(
          fontSize: 14,
          color: PosHomeSpec.inkAlpha(0.33),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: _inputBorderInactive, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: Color(0xFF241F20), width: 1.5),
        ),
      ),
    );
  }
}
