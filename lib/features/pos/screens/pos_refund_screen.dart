import 'package:acafe_customer/common/models/api_response_model.dart';
import 'package:acafe_customer/di_container.dart' as di;
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_payment_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_refund_repo.dart';
import 'package:acafe_customer/features/pos/domain/pos_refund_session.dart';
import 'package:acafe_customer/features/pos/domain/pos_routes.dart';
import 'package:acafe_customer/features/pos/widgets/pos_payment_success_card.dart';
import 'package:acafe_customer/features/pos/widgets/pos_top_nav_bar.dart';
import 'package:acafe_customer/features/pos/widgets/pos_waiting_card.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

/// Figma nodes 1915:11344 (Screen 25), 1915:11448 (26), 1915:11777 (27),
/// 1915:11551 (28), 1915:12443 (29), 1915:12462 (30).
///
/// Entered from [PosReceiptDetailPanel] after the manager permission guard.
/// Uses [PosRefundSession] as shared state so sub-widgets rebuild independently.
///
/// Steps:
///   _RefundStep.selectItems  → Screen 25 (item checklist + reason)
///   _RefundStep.chooseMethod → Screen 26 (single-payment) or
///   _RefundStep.chooseSplit  → Screen 29 (split-order: pick which split)
///   _RefundStep.waiting      → Screen 27 (waiting for terminal / cash confirm)
///   _RefundStep.complete     → Screen 28 / 30 (success)
class PosRefundScreen extends StatefulWidget {
  const PosRefundScreen({super.key});

  @override
  State<PosRefundScreen> createState() => _PosRefundScreenState();
}

enum _RefundStep { selectItems, chooseSplit, chooseMethod, waiting, complete }

class _PosRefundScreenState extends State<PosRefundScreen> {
  final PosRefundSession _session = PosRefundSession.instance;
  _RefundStep _step = _RefundStep.selectItems;

  @override
  void initState() {
    super.initState();
    // Reset so a re-entry is clean.
    _session.reset();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PosHomeSpec.panelBg,
      body: Column(
        children: [
          PosTopNavBar(
            currentPath: PosRoutes.receipts,
          ),
          Expanded(child: _body),
        ],
      ),
    );
  }

  String get _navTitle {
    final id = _session.order?.id;
    return id == null ? 'Refund' : 'Refund / Order #$id';
  }

  bool get _canGoBack =>
      _step == _RefundStep.selectItems ||
      _step == _RefundStep.chooseSplit ||
      _step == _RefundStep.chooseMethod;

  void _handleBack() {
    switch (_step) {
      case _RefundStep.chooseMethod:
        setState(() => _step = _session.isSplitOrder
            ? _RefundStep.chooseSplit
            : _RefundStep.selectItems);
      case _RefundStep.chooseSplit:
        setState(() => _step = _RefundStep.selectItems);
      default:
        context.go(PosRoutes.receipts);
    }
  }

  Widget get _body {
    switch (_step) {
      case _RefundStep.selectItems:
        return _SelectItemsStep(
          onContinue: () => setState(() => _step = _session.isSplitOrder
              ? _RefundStep.chooseSplit
              : _RefundStep.chooseMethod),
        );
      case _RefundStep.chooseSplit:
        return _ChooseSplitStep(
          onContinue: () => _createRefund(),
        );
      case _RefundStep.chooseMethod:
        return _ChooseMethodStep(
          onContinue: () => _createRefund(),
        );
      case _RefundStep.waiting:
        return _WaitingStep(
          onConfirm: () => _confirmRefund(),
          onCancel: () => setState(() =>
              _step = _session.isSplitOrder
                  ? _RefundStep.chooseSplit
                  : _RefundStep.chooseMethod),
        );
      case _RefundStep.complete:
        return _CompleteStep(
          onDone: () {
            _session.reset();
            context.go(PosRoutes.receipts);
          },
        );
    }
  }

  Future<void> _createRefund() async {
    _session.busy.value = true;
    _session.error.value = null;

    final int deviceId =
        Provider.of<KioskAuthProvider>(context, listen: false).deviceId ?? 0;
    final String ref =
        'refund-${_session.order!.id}-${DateTime.now().millisecondsSinceEpoch}';
    _session.pendingRef.value = ref;

    final ApiResponseModel result =
        await di.sl<PosRefundRepo>().create(
      orderId: _session.order!.id,
      deviceId: deviceId,
      reference: ref,
      reason: _session.reason.value?.label,
      partialPaymentId: _session.selectedSplit.value?.id,
    );

    _session.busy.value = false;

    if (!mounted) return;

    if (!result.response.statusCode.toString().startsWith('2')) {
      _session.error.value =
          result.error ?? 'Failed to create refund. Please try again.';
      return;
    }

    final Map<String, dynamic> body =
        result.response.data as Map<String, dynamic>;
    _session.pendingRefundId.value  = body['refund_id'] as int?;
    _session.pendingRefundSeq.value = body['refund_seq'] as int?;
    _session.refundAmount.value     = (body['amount'] as num?)?.toDouble() ?? 0;
    _session.refundMethod.value     = (body['method'] as String?) ?? 'cash';

    setState(() => _step = _RefundStep.waiting);
  }

  Future<void> _confirmRefund() async {
    _session.busy.value = true;
    _session.error.value = null;

    final int deviceId =
        Provider.of<KioskAuthProvider>(context, listen: false).deviceId ?? 0;

    final ApiResponseModel result =
        await di.sl<PosRefundRepo>().confirm(
      orderId: _session.order!.id,
      refundSeq: _session.pendingRefundSeq.value ?? 1,
      method: _session.refundMethod.value,
      reference: _session.pendingRef.value ?? '',
      deviceId: deviceId,
      approvalCode: _session.approvalCode.text.trim().isEmpty
          ? null
          : _session.approvalCode.text.trim(),
    );

    _session.busy.value = false;

    if (!mounted) return;

    if (!result.response.statusCode.toString().startsWith('2')) {
      _session.error.value =
          result.error ?? 'Failed to confirm refund. Please try again.';
      return;
    }

    setState(() => _step = _RefundStep.complete);
  }
}

// ── Screen 25 — Select Items + Reason ─────────────────────────────────────────

class _SelectItemsStep extends StatelessWidget {
  final VoidCallback onContinue;
  const _SelectItemsStep({required this.onContinue});

  @override
  Widget build(BuildContext context) {
    final PosRefundSession session = PosRefundSession.instance;
    final lines = session.order?.lines ?? [];

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(PosPaymentSpec.contentPadding),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Reason
                _SectionLabel('Reason for refund'),
                const SizedBox(height: 12),
                ValueListenableBuilder<PosRefundReason?>(
                  valueListenable: session.reason,
                  builder: (_, current, __) => Column(
                    children: PosRefundReason.values.map((r) {
                      return _RadioRow(
                        label: r.label,
                        selected: current == r,
                        onTap: () => session.reason.value = r,
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 28),
                _SectionLabel('Items to refund'),
                const SizedBox(height: 12),
                if (lines.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text('Full order refund',
                        style: loewRegular.copyWith(
                            fontSize: 15, color: PosHomeSpec.inkAlpha(0.6))),
                  ),
                ...List.generate(lines.length, (i) {
                  final line = lines[i];
                  return ValueListenableBuilder<Set<int>>(
                    valueListenable: session.selectedItemIndices,
                    builder: (_, selected, __) => _ItemRow(
                      name: line.product?.name ?? '',
                      qty: line.quantity ?? 1,
                      selected: selected.contains(i) || lines.isEmpty,
                      onToggle: lines.isEmpty
                          ? null
                          : (v) {
                              final next = Set<int>.from(selected);
                              if (v == true) {
                                next.add(i);
                              } else {
                                next.remove(i);
                              }
                              session.selectedItemIndices.value = next;
                            },
                    ),
                  );
                }),

                const SizedBox(height: 28),
                ValueListenableBuilder<bool>(
                  valueListenable: session.busy,
                  builder: (_, busy, __) => _PrimaryButton(
                    label: 'Continue to refund method',
                    onTap: busy ? null : onContinue,
                  ),
                ),
                ValueListenableBuilder<String?>(
                  valueListenable: session.error,
                  builder: (_, err, __) => err == null
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(err,
                              style: loewRegular.copyWith(
                                  fontSize: 13, color: const Color(0xFFB5490A)),
                              textAlign: TextAlign.center),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Screen 26 — Choose refund method (single-payment orders) ──────────────────

class _ChooseMethodStep extends StatelessWidget {
  final VoidCallback onContinue;
  const _ChooseMethodStep({required this.onContinue});

  @override
  Widget build(BuildContext context) {
    final PosRefundSession session = PosRefundSession.instance;
    final String detectedMethod = session.order?.method ?? 'cash';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(PosPaymentSpec.contentPadding),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SectionLabel('Refund method'),
                const SizedBox(height: 8),
                Text(
                  'Original payment method: ${detectedMethod == 'card' ? 'Card' : 'Cash'}',
                  style: loewRegular.copyWith(
                      fontSize: 14, color: PosHomeSpec.inkAlpha(0.6)),
                ),
                const SizedBox(height: 20),
                ValueListenableBuilder<String>(
                  valueListenable: session.refundMethod,
                  builder: (_, method, __) => Column(
                    children: [
                      _RadioRow(
                        label: 'Card — process on physical terminal',
                        selected: method == 'card',
                        onTap: () => session.refundMethod.value = 'card',
                      ),
                      _RadioRow(
                        label: 'Cash — hand to customer from drawer',
                        selected: method == 'cash',
                        onTap: () => session.refundMethod.value = 'cash',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                ValueListenableBuilder<bool>(
                  valueListenable: session.busy,
                  builder: (_, busy, __) => _PrimaryButton(
                    label: busy ? 'Processing…' : 'Confirm refund method',
                    onTap: busy ? null : onContinue,
                  ),
                ),
                _ErrorText(session.error),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Screen 29 — Choose which split to refund ──────────────────────────────────

class _ChooseSplitStep extends StatelessWidget {
  final VoidCallback onContinue;
  const _ChooseSplitStep({required this.onContinue});

  @override
  Widget build(BuildContext context) {
    final PosRefundSession session = PosRefundSession.instance;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(PosPaymentSpec.contentPadding),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SectionLabel('Select payment to refund'),
                const SizedBox(height: 8),
                Text(
                  'Choose which split payment to refund. Each split is refunded independently.',
                  style: loewRegular.copyWith(
                      fontSize: 14, color: PosHomeSpec.inkAlpha(0.6)),
                ),
                const SizedBox(height: 20),
                ValueListenableBuilder<PosRefundSplit?>(
                  valueListenable: session.selectedSplit,
                  builder: (_, selected, __) => Column(
                    children: session.splits.map((s) {
                      return _RadioRow(
                        label: s.label,
                        selected: selected?.id == s.id,
                        onTap: () {
                          session.selectedSplit.value = s;
                          session.refundMethod.value = s.method;
                        },
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 28),
                ValueListenableBuilder<PosRefundSplit?>(
                  valueListenable: session.selectedSplit,
                  builder: (_, selected, __) =>
                      ValueListenableBuilder<bool>(
                    valueListenable: session.busy,
                    builder: (_, busy, __) => _PrimaryButton(
                      label: busy ? 'Processing…' : 'Confirm split selection',
                      onTap: (selected == null || busy) ? null : onContinue,
                    ),
                  ),
                ),
                _ErrorText(session.error),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Screen 27 — Waiting for terminal / cash confirm ───────────────────────────

class _WaitingStep extends StatelessWidget {
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  const _WaitingStep({required this.onConfirm, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final PosRefundSession session = PosRefundSession.instance;

    return ValueListenableBuilder<String>(
      valueListenable: session.refundMethod,
      builder: (_, method, __) {
        return ValueListenableBuilder<double>(
          valueListenable: session.refundAmount,
          builder: (_, amount, __) {
            if (method == 'card') {
              return _CardWaitingView(
                amount: amount,
                onConfirm: onConfirm,
                onCancel: onCancel,
              );
            }
            return _CashConfirmView(
              amount: amount,
              onConfirm: onConfirm,
              onCancel: onCancel,
            );
          },
        );
      },
    );
  }
}

class _CardWaitingView extends StatelessWidget {
  final double amount;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  const _CardWaitingView(
      {required this.amount,
      required this.onConfirm,
      required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final PosRefundSession session = PosRefundSession.instance;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(PosPaymentSpec.contentPadding),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
                maxWidth: PosPaymentSpec.v2SuccessCardWidth),
            child: Container(
              padding: const EdgeInsets.all(PosPaymentSpec.v2SuccessCardPadding),
              decoration: BoxDecoration(
                color: PosHomeSpec.panelBg,
                borderRadius: BorderRadius.circular(
                    PosPaymentSpec.v2SuccessCardRadius),
                border: Border.all(
                    color: PosHomeSpec.hairline,
                    width: PosPaymentSpec.v2SuccessCardBorder),
              ),
              child: Column(
                children: [
                  const PosWaitingDots(),
                  const SizedBox(height: 20),
                  Text('Refunding…',
                      style: loewBold.copyWith(fontSize: 22),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(
                    'Process the refund on the physical terminal.\nThen enter the approval code below.',
                    style: loewRegular.copyWith(
                        fontSize: 14, color: PosHomeSpec.inkAlpha(0.6)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  _AmountBox(amount: amount, label: 'REFUND AMOUNT'),
                  const SizedBox(height: 20),
                  TextField(
                    controller: session.approvalCode,
                    decoration: InputDecoration(
                      labelText: 'Approval code (optional)',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'[A-Za-z0-9\-]'))
                    ],
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _SecondaryButton(
                          label: 'Cancel',
                          onTap: onCancel,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ValueListenableBuilder<bool>(
                          valueListenable: session.busy,
                          builder: (_, busy, __) => _PrimaryButton(
                            label: busy ? 'Confirming…' : 'Confirm Refund',
                            onTap: busy ? null : onConfirm,
                          ),
                        ),
                      ),
                    ],
                  ),
                  _ErrorText(session.error),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CashConfirmView extends StatelessWidget {
  final double amount;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  const _CashConfirmView(
      {required this.amount,
      required this.onConfirm,
      required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final PosRefundSession session = PosRefundSession.instance;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(PosPaymentSpec.contentPadding),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
                maxWidth: PosPaymentSpec.v2SuccessCardWidth),
            child: Container(
              padding: const EdgeInsets.all(PosPaymentSpec.v2SuccessCardPadding),
              decoration: BoxDecoration(
                color: PosHomeSpec.panelBg,
                borderRadius: BorderRadius.circular(
                    PosPaymentSpec.v2SuccessCardRadius),
                border: Border.all(
                    color: PosHomeSpec.hairline,
                    width: PosPaymentSpec.v2SuccessCardBorder),
              ),
              child: Column(
                children: [
                  Text('Cash Refund',
                      style: loewBold.copyWith(fontSize: 22),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(
                    'Hand the cash to the customer from the drawer.',
                    style: loewRegular.copyWith(
                        fontSize: 14, color: PosHomeSpec.inkAlpha(0.6)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  _AmountBox(amount: amount, label: 'REFUND AMOUNT'),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _SecondaryButton(
                          label: 'Cancel',
                          onTap: onCancel,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ValueListenableBuilder<bool>(
                          valueListenable: session.busy,
                          builder: (_, busy, __) => _PrimaryButton(
                            label: busy ? 'Confirming…' : 'Confirm Refund',
                            onTap: busy ? null : onConfirm,
                          ),
                        ),
                      ),
                    ],
                  ),
                  _ErrorText(session.error),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Screen 28 / 30 — Refund Complete ─────────────────────────────────────────

class _CompleteStep extends StatelessWidget {
  final VoidCallback onDone;
  const _CompleteStep({required this.onDone});

  @override
  Widget build(BuildContext context) {
    final PosRefundSession session = PosRefundSession.instance;
    final bool isSplit = session.isSplitOrder;
    final int? splitSeq = session.selectedSplit.value?.seq;

    return ValueListenableBuilder<double>(
      valueListenable: session.refundAmount,
      builder: (_, amount, __) => PosPaymentSuccessCard(
        title: isSplit
            ? 'Split Payment ${splitSeq ?? ''} Refunded'
            : 'Refund Complete',
        amount: amount,
        amountLabel: 'AMOUNT REFUNDED',
        buttonLabel: 'Back to Receipts',
        onContinue: onDone,
      ),
    );
  }
}

// ── Shared small widgets ───────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: loewBold.copyWith(
            fontSize: 13,
            letterSpacing: 0.06,
            color: PosHomeSpec.inkAlpha(0.5)));
  }
}

class _RadioRow extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _RadioRow(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? PosHomeSpec.ink.withValues(alpha: 0.06)
              : Colors.transparent,
          border: Border.all(
            color: selected ? PosHomeSpec.ink : PosHomeSpec.hairline,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 18,
              color: selected ? PosHomeSpec.ink : PosHomeSpec.inkAlpha(0.4),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: loewRegular.copyWith(fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final String name;
  final int qty;
  final bool selected;
  final ValueChanged<bool?>? onToggle;
  const _ItemRow(
      {required this.name,
      required this.qty,
      required this.selected,
      required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: PosHomeSpec.hairline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Checkbox(
            value: selected,
            onChanged: onToggle,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text('$name × $qty', style: loewRegular.copyWith(fontSize: 15)),
          ),
        ],
      ),
    );
  }
}

class _AmountBox extends StatelessWidget {
  final double amount;
  final String label;
  const _AmountBox({required this.amount, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: PosHomeSpec.hairline.withValues(alpha: 0.4),
        borderRadius:
            BorderRadius.circular(PosPaymentSpec.v2SuccessAmountBoxRadius),
      ),
      child: Column(
        children: [
          Text(label,
              style: loewBold.copyWith(
                  fontSize: 11,
                  letterSpacing: 0.08,
                  color: PosHomeSpec.inkAlpha(0.5))),
          const SizedBox(height: 4),
          Text('€${amount.toStringAsFixed(2)}',
              style: loewBold.copyWith(fontSize: 28)),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const _PrimaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 52,
        decoration: BoxDecoration(
          color: enabled ? PosHomeSpec.ink : PosHomeSpec.inkAlpha(0.2),
          borderRadius:
              BorderRadius.circular(PosPaymentSpec.v2SuccessButtonRadius),
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: loewBold.copyWith(
                fontSize: PosPaymentSpec.v2SuccessButtonLabelSize,
                color: Colors.white)),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const _SecondaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          border: Border.all(color: PosHomeSpec.hairline, width: 1.5),
          borderRadius:
              BorderRadius.circular(PosPaymentSpec.v2SuccessButtonRadius),
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: loewRegular.copyWith(
                fontSize: PosPaymentSpec.v2SuccessButtonLabelSize)),
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  final ValueNotifier<String?> notifier;
  const _ErrorText(this.notifier);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: notifier,
      builder: (_, err, __) => err == null
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(err,
                  style: loewRegular.copyWith(
                      fontSize: 13, color: const Color(0xFFB5490A)),
                  textAlign: TextAlign.center),
            ),
    );
  }
}
