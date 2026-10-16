import 'package:acafe_customer/features/pos/domain/pos_cash_entry.dart';
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_payment_spec.dart';
import 'package:acafe_customer/features/pos/widgets/pos_pay_shell.dart';
import 'package:acafe_customer/features/pos/domain/pos_sale_session.dart';
import 'package:acafe_customer/features/pos/domain/pos_split_session.dart';
import 'package:acafe_customer/features/pos/widgets/pos_keypad.dart';
import 'package:acafe_customer/features/pos/widgets/pos_pay_summary_panel.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';

/// The right-pane summary panel in split-by-payment mode.
///
/// Figma node **1915:10034** ("split-payment-summary-pane"), part of the "05
/// enter amount" screen **1915:9902**.
///
/// Layout:
///  • SPLIT PAYMENT header + subtitle
///  • Grand total (36 ExtraBold) + "Total to pay" label
///  • Remaining bar (#F0EBD8 pill)
///  • Past-payment mini-rows (after the first split has been taken)
///  • Payment-N entry card: PAYMENT N label / amount display / Card–Cash toggle
///  • v2 keypad (same 78px keys as the cash summary panel)
///  • Tip row (inert — tip was chosen and baked in before the order was placed)
class PosSplitSummaryPanel extends StatelessWidget {
  final PosSplitState state;

  /// The amount currently keyed in for the next split.
  final PosCashEntry entry;

  /// Card or Cash for the current split.
  final PosPaymentMethod splitMethod;
  final ValueChanged<PosPaymentMethod> onSplitMethod;

  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;
  final VoidCallback onClear;

  /// The tip baked into this order when it was placed upfront. Shown as
  /// informational only — tipping is closed once the order is placed.
  final double tip;

  /// On tap: process the current split (POST record). Null = button disabled.
  final VoidCallback? onConfirm;

  /// Loading state (charge in flight).
  final bool loading;

  /// When true the panel is inside a bounded pane and uses a [LayoutBuilder]
  /// to scale the keypad so everything fits without scrolling.
  final bool fill;

  const PosSplitSummaryPanel({
    super.key,
    required this.state,
    required this.entry,
    required this.splitMethod,
    required this.onSplitMethod,
    required this.onKey,
    required this.onBackspace,
    required this.onClear,
    this.tip = 0,
    this.onConfirm,
    this.loading = false,
    this.fill = false,
  });

  // Natural keypad height: 4 rows × 78px + 3 gaps × 12px.
  static const double _kNaturalKeypad = 348.0;

  @override
  Widget build(BuildContext context) => fill ? _bodyFill() : _body();

  /// Non-fill: column sizes itself to content (natural height).
  Widget _body() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _Header(grandTotal: state.grandTotal),
        const PosPaySummaryDivider(),
        _RemainingBar(remaining: state.remaining, fullyPaid: state.fullyPaid),
        if (state.payments.isNotEmpty) ...[
          const SizedBox(height: 4),
          _PastPaymentsList(payments: state.payments),
        ],
        const SizedBox(height: 8),
        _EntryCard(seq: state.nextSequence, entry: entry, method: splitMethod, onMethod: onSplitMethod, onClear: onClear),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: PosPaymentSpec.v2CashPanelPaddingH),
          child: PosKeypad(
            rows: PosKeypad.digitRows(decimal: '.'),
            style: posCashKeypadStyleV2(backspaceAsset: Images.posKeyBackspaceSvg),
            onKey: onKey,
            onBackspace: onBackspace,
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: PosPaymentSpec.v2CashPanelPaddingH),
          child: PosPayPillBar(label: 'Start Payment ${state.nextSequence}', loading: loading, onConfirm: onConfirm),
        ),
        const SizedBox(height: 4),
        const PosPaySummaryDivider(),
        PosPayTipRow(amount: tip, onTap: null),
      ],
    );
  }

  /// Fill mode: column expands to bounded parent height; keypad takes the
  /// available slack via [Expanded] so nothing overflows.
  Widget _bodyFill() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.max,
      children: [
        _Header(grandTotal: state.grandTotal),
        const PosPaySummaryDivider(),
        _RemainingBar(remaining: state.remaining, fullyPaid: state.fullyPaid),
        if (state.payments.isNotEmpty) ...[
          const SizedBox(height: 4),
          _PastPaymentsList(payments: state.payments),
        ],
        const SizedBox(height: 8),
        _EntryCard(seq: state.nextSequence, entry: entry, method: splitMethod, onMethod: onSplitMethod, onClear: onClear),
        const SizedBox(height: 8),
        // Keypad takes all remaining space; scale = available / natural so the
        // keypad fills exactly its allocation without overflowing.
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: PosPaymentSpec.v2CashPanelPaddingH),
            child: LayoutBuilder(
              builder: (context, c) {
                final double s = (c.maxHeight / _kNaturalKeypad).clamp(0.0, 1.0);
                return PosKeypad(
                  rows: PosKeypad.digitRows(decimal: '.'),
                  style: posCashKeypadStyleV2(backspaceAsset: Images.posKeyBackspaceSvg),
                  scale: s,
                  onKey: onKey,
                  onBackspace: onBackspace,
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: PosPaymentSpec.v2CashPanelPaddingH),
          child: PosPayPillBar(label: 'Start Payment ${state.nextSequence}', loading: loading, onConfirm: onConfirm),
        ),
        const SizedBox(height: 4),
        const PosPaySummaryDivider(),
        PosPayTipRow(amount: tip, onTap: null),
      ],
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final double grandTotal;

  const _Header({required this.grandTotal});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'SPLIT PAYMENT',
            style: loewBold.copyWith(
              fontSize: PosPaymentSpec.v2SplitHeaderSize,
              letterSpacing: PosPaymentSpec.v2SplitHeaderTracking,
              color: PosPaymentSpec.v2SplitLabelInk,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Overview for split payment',
            style: swiss721Light.copyWith(
              fontSize: 10,
              color: PosPaymentSpec.v2SplitSubtitleInk,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            PosHomeSpec.formatPrice(grandTotal, padZero: false),
            maxLines: 1,
            style: loewExtraBold.copyWith(
              fontSize: PosPaymentSpec.v2SplitTotalSize,
              color: PosHomeSpec.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Total to pay',
            style: swiss721Light.copyWith(
              fontSize: 10,
              color: PosPaymentSpec.v2SplitLabelInk,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Remaining bar ─────────────────────────────────────────────────────────

class _RemainingBar extends StatelessWidget {
  final double remaining;
  final bool fullyPaid;

  const _RemainingBar({required this.remaining, required this.fullyPaid});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: PosHomeSpec.hairline, // #F0EBD8
          borderRadius: BorderRadius.circular(
              PosPaymentSpec.v2SplitRemainRadius),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: PosPaymentSpec.v2SplitRemainPaddingH,
          vertical: PosPaymentSpec.v2SplitRemainPaddingV,
        ),
        child: Row(
          children: [
            Text(
              'Remaining',
              style: loewBold.copyWith(
                fontSize: PosPaymentSpec.v2SplitRemainLabelSize,
                color: PosPaymentSpec.v2SplitLabelInk,
              ),
            ),
            const Spacer(),
            Text(
              fullyPaid
                  ? PosHomeSpec.formatPrice(0, padZero: false)
                  : PosHomeSpec.formatPrice(remaining, padZero: false),
              style: loewExtraBold.copyWith(
                fontSize: PosPaymentSpec.v2SplitRemainAmountSize,
                color: PosHomeSpec.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Past payments ─────────────────────────────────────────────────────────

class _PastPaymentsList extends StatelessWidget {
  final List<PosSplitPayment> payments;

  const _PastPaymentsList({required this.payments});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final p in payments) _PastPaymentRow(payment: p),
        ],
      ),
    );
  }
}

class _PastPaymentRow extends StatelessWidget {
  final PosSplitPayment payment;

  const _PastPaymentRow({required this.payment});

  @override
  Widget build(BuildContext context) {
    final String label =
        payment.paidWith == 'card' ? 'Card' : 'Cash';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(
            'Payment ${payment.seq}  ($label)',
            style: swiss721Light.copyWith(
              fontSize: 10,
              color: PosPaymentSpec.v2SplitSubtitleInk,
            ),
          ),
          const Spacer(),
          Text(
            PosHomeSpec.formatPrice(payment.paidAmount, padZero: false),
            style: loewBold.copyWith(
              fontSize: 11,
              color: PosHomeSpec.ink,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Entry card ────────────────────────────────────────────────────────────

class _EntryCard extends StatelessWidget {
  final int seq;
  final PosCashEntry entry;
  final PosPaymentMethod method;
  final ValueChanged<PosPaymentMethod> onMethod;
  final VoidCallback onClear;

  const _EntryCard({
    required this.seq,
    required this.entry,
    required this.method,
    required this.onMethod,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: PosPaymentSpec.v2CashPanelPaddingH,
      ),
      child: Container(
        constraints: const BoxConstraints(
          minHeight: PosPaymentSpec.v2SplitPaymentCardHeight,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: PosHomeSpec.tileBg,
          borderRadius: BorderRadius.circular(
              PosPaymentSpec.v2SplitPaymentCardRadius),
          border: Border.all(
            color: PosPaymentSpec.v2OtherRowBorder, // #E8E3D5
            width: 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'PAYMENT $seq',
                    style: loewBold.copyWith(
                      fontSize: 10,
                      letterSpacing:
                          PosPaymentSpec.v2SplitPaymentLabelTracking,
                      color: PosPaymentSpec.v2SplitLabelInk,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.isEmpty
                              ? '0.00'
                              : PosHomeSpec.formatPrice(
                                  posCentsToMoney(entry.cents,
                                      decimals: entry.decimals),
                                  padZero: false,
                                ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: loewExtraBold.copyWith(
                            fontSize:
                                PosPaymentSpec.v2SplitPaymentAmountSize,
                            color: entry.isEmpty
                                ? PosHomeSpec.inkAlpha(0.3)
                                : PosHomeSpec.ink,
                          ),
                        ),
                      ),
                      if (!entry.isEmpty)
                        GestureDetector(
                          onTap: onClear,
                          child: Padding(
                            padding:
                                const EdgeInsets.only(left: 4),
                            child: Icon(
                              Icons.close,
                              size: 14,
                              color: PosHomeSpec.inkAlpha(0.4),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _MethodToggle(method: method, onMethod: onMethod),
          ],
        ),
      ),
    );
  }
}

// ── Card / Cash toggle ────────────────────────────────────────────────────

class _MethodToggle extends StatelessWidget {
  final PosPaymentMethod method;
  final ValueChanged<PosPaymentMethod> onMethod;

  const _MethodToggle({required this.method, required this.onMethod});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(PosPaymentSpec.v2SplitTogglePadding),
      decoration: BoxDecoration(
        color: PosHomeSpec.hairline, // #F0EBD8
        borderRadius:
            BorderRadius.circular(PosPaymentSpec.v2SplitToggleRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TogglePill(
            label: 'Card',
            active: method == PosPaymentMethod.card,
            onTap: () => onMethod(PosPaymentMethod.card),
          ),
          const SizedBox(width: 2),
          _TogglePill(
            label: 'Cash',
            active: method == PosPaymentMethod.cash,
            onTap: () => onMethod(PosPaymentMethod.cash),
          ),
        ],
      ),
    );
  }
}

class _TogglePill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _TogglePill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final BorderRadius r =
        BorderRadius.circular(PosPaymentSpec.v2SplitToggleInnerRadius);
    return GestureDetector(
      onTap: active ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? PosHomeSpec.tileBg : Colors.transparent,
          borderRadius: r,
          boxShadow: active
              ? [
                  BoxShadow(
                    color: PosHomeSpec.inkAlpha(0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: loewBold.copyWith(
            fontSize: PosPaymentSpec.v2SplitToggleLabelSize,
            color: active
                ? PosHomeSpec.ink
                : PosHomeSpec.inkAlpha(0.5),
          ),
        ),
      ),
    );
  }
}
