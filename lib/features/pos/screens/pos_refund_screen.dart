import 'package:acafe_customer/common/models/api_response_model.dart';
import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/di_container.dart' as di;
import 'package:acafe_customer/features/kiosk/domain/kiosk_cart_totals.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_payment_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipt_history.dart';
import 'package:acafe_customer/features/pos/domain/pos_refund_repo.dart';
import 'package:acafe_customer/features/pos/domain/pos_refund_session.dart';
import 'package:acafe_customer/features/pos/domain/pos_routes.dart';
import 'package:acafe_customer/features/pos/widgets/pos_pay_option_row.dart';
import 'package:acafe_customer/features/pos/widgets/pos_pay_shell.dart';
import 'package:acafe_customer/features/pos/widgets/pos_payment_success_card.dart';
import 'package:acafe_customer/features/pos/widgets/pos_receipt_dialog.dart';
import 'package:acafe_customer/features/pos/widgets/pos_receipt_line.dart';
import 'package:acafe_customer/features/pos/widgets/pos_receipt_panel.dart';
import 'package:acafe_customer/features/pos/widgets/pos_split_summary_panel.dart';
import 'package:acafe_customer/features/pos/widgets/pos_waiting_card.dart';
import 'package:acafe_customer/theme/text_legibility.dart';
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
/// The selection steps use the payment layer's chrome — back row, the three
/// panes (receipt · reason / method · refund summary) and the sticky pill —
/// and the terminal / confirm / done steps use its full-screen cards.
///
/// Steps:
///   _RefundStep.selectItems  → Screen 25 (item checklist + reason)
///   _RefundStep.chooseMethod → Screen 26 (single-payment) or
///   _RefundStep.chooseSplit  → (split order: pick which split; no frame —
///                              drawn like 26)
///   _RefundStep.confirmSplit → Screen 29 before anything is created: opened
///                              from a paid row's Refund pill on the payment
///                              screen ([PosRefundSession.fromPayment])
///   _RefundStep.waiting      → Screen 27 (card) / 29 (cash confirm)
///   _RefundStep.complete     → Screen 28 / 30 (success)
class PosRefundScreen extends StatefulWidget {
  const PosRefundScreen({super.key});

  @override
  State<PosRefundScreen> createState() => _PosRefundScreenState();
}

enum _RefundStep {
  selectItems,
  chooseSplit,
  chooseMethod,
  confirmSplit,
  waiting,
  complete,
}

class _PosRefundScreenState extends State<PosRefundScreen> {
  final PosRefundSession _session = PosRefundSession.instance;
  _RefundStep _step = _RefundStep.selectItems;

  /// The receipt sidebar's customer field reads the order's name (read-only).
  late final TextEditingController _customerName =
      TextEditingController(text: _session.order?.customerName ?? '');
  final TextEditingController _table = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Clear per-flow state so a re-entry is clean, but KEEP the inbound
    // order / splits that the caller just set — a full reset would wipe them
    // and _createRefund would crash on _session.order!.id.
    _session.resetFlow();
    // One payment, from its Refund pill: straight to frame 29 for it.
    if (_session.fromPayment && _session.splits.length == 1) {
      final PosRefundSplit split = _session.splits.single;
      _session.selectedSplit.value = split;
      _session.refundMethod.value = split.method;
      _step = _RefundStep.confirmSplit;
    }
    _loadLedger();
  }

  /// Reads `refund/list` so the screen can quote the amount the backend will
  /// refund (see [posRefundableAmount]). Read-only; a failure leaves the
  /// quote blank ("—") and changes nothing else — the confirmation card after
  /// `create` still shows the backend's own figure before any money moves.
  Future<void> _loadLedger() async {
    final order = _session.order;
    if (order == null || !di.sl.isRegistered<PosRefundRepo>()) return;
    final int deviceId =
        Provider.of<KioskAuthProvider>(context, listen: false).deviceId ?? 0;
    final ApiResponseModel result = await di
        .sl<PosRefundRepo>()
        .list(orderId: order.id, deviceId: deviceId);
    if (!mounted) return;
    final dynamic data = result.response?.data;
    if (result.isSuccess && data is Map) {
      _session.refundLedger.value = Map<String, dynamic>.from(data);
    }
  }

  @override
  void dispose() {
    _customerName.dispose();
    _table.dispose();
    super.dispose();
  }

  /// Back from the selection steps: to the receipt the refund was opened on,
  /// or to the sale when opened from a payment row.
  void _back() {
    if (_session.fromPayment) {
      _leaveToSale();
    } else {
      context.go(PosRoutes.receipts);
    }
  }

  /// Frame 28's "Next order": the refund is done; back to the counter.
  void _nextOrder() {
    _session.reset();
    context.go(PosRoutes.home);
  }

  /// Frame 28's "Receipt": the existing receipt options (email / print, the
  /// dialog of frames 18a / 18b) for this order; once sent, on to the next
  /// order as after a payment.
  void _openReceipt() {
    final order = _session.order;
    if (order == null) return;
    final int deviceId =
        Provider.of<KioskAuthProvider>(context, listen: false).deviceId ?? 0;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'receipt',
      // `dim-overlay` (1915:13039): ink at 40%.
      barrierColor: PosPaymentSpec.v2DialogScrim,
      pageBuilder: (dialogContext, anim, secAnim) => PosPayCanvas(
        child: PosReceiptDialog(
          orderId: order.id,
          total: order.total,
          deviceId: deviceId,
          onComplete: () {
            Navigator.pop(dialogContext);
            _nextOrder();
          },
          onSkip: () => Navigator.pop(dialogContext),
        ),
      ),
    );
  }

  /// Back to the payment screen this refund was pushed from — still holding
  /// its split session underneath.
  void _leaveToSale() {
    _session.reset();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(PosRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    // The selection steps carry the back row; the terminal / confirm / done
    // cards are full-screen (frames 27–30), as in the payment layer.
    final bool selecting = _step == _RefundStep.selectItems ||
        _step == _RefundStep.chooseMethod ||
        _step == _RefundStep.chooseSplit;
    final int? id = _session.order?.id;
    return Scaffold(
      backgroundColor: PosHomeSpec.pageBg,
      body: PosPayTextScope(
        child: SafeArea(
          // Laid out at Figma's 1366×1024 and scaled to the window.
          child: PosPayCanvas(
            child: Column(
              children: [
                if (selecting)
                  PosPayBackRow(
                    onBack: _back,
                    // `Refund / Order #27362` (node 1915:11349).
                    label: id == null ? 'Refund' : 'Refund / Order #$id',
                  ),
                Expanded(child: _body),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The repo hands back a message string, or an error object, or nothing.
  static String? _errorText(dynamic error) {
    if (error == null) return null;
    final String text = '$error'.trim();
    return text.isEmpty ? null : text;
  }

  static String _confirmLabel(double? amount) => amount == null
      ? 'Confirm refund'
      : 'Confirm refund · ${PosHomeSpec.formatPrice(amount, padZero: false)}';

  Widget get _body {
    switch (_step) {
      case _RefundStep.selectItems:
        return _SelectionFrame(
          middle: const _ReasonPane(),
          summary: const _RefundSummaryPane(
            subtitle: 'Select items and a reason',
            mode: _SummaryMode.items,
          ),
          barLabel: (_) => 'Continue to refund method',
          barEnabled: () => true,
          onBar: () {
            // Frame 26 opens on "Original payment".
            if (!_session.isSplitOrder) {
              _session.refundMethod.value =
                  _session.order?.method == 'card' ? 'card' : 'cash';
            }
            setState(() => _step = _session.isSplitOrder
                ? _RefundStep.chooseSplit
                : _RefundStep.chooseMethod);
          },
          customerName: _customerName,
          table: _table,
        );
      case _RefundStep.chooseSplit:
        return _SelectionFrame(
          middle: const _SplitPane(),
          summary: const _RefundSummaryPane(
            subtitle: 'Choose which payment to refund',
            mode: _SummaryMode.split,
          ),
          barLabel: _confirmLabel,
          barEnabled: () => _session.selectedSplit.value != null,
          onBar: () => _createRefund(),
          customerName: _customerName,
          table: _table,
        );
      case _RefundStep.chooseMethod:
        return _SelectionFrame(
          middle: const _MethodPane(),
          summary: const _RefundSummaryPane(
            subtitle: 'Choose where the money goes',
            mode: _SummaryMode.method,
          ),
          barLabel: _confirmLabel,
          barEnabled: () => true,
          onBar: () => _createRefund(),
          customerName: _customerName,
          table: _table,
        );
      case _RefundStep.confirmSplit:
        return _SplitConfirmStep(
          onCancel: _leaveToSale,
          onRefund: _refundOneSplit,
        );
      case _RefundStep.waiting:
        return _WaitingStep(
          onConfirm: () => _confirmRefund(),
          onCancel: () => setState(() => _step = _session.fromPayment
              ? _RefundStep.confirmSplit
              : _session.isSplitOrder
                  ? _RefundStep.chooseSplit
                  : _RefundStep.chooseMethod),
        );
      case _RefundStep.complete:
        // Frame 28: Receipt above Next order (DD4). Frame 30 (one payment of
        // a sale still in progress) has only "Back to order".
        return _CompleteStep(
          onReceipt: _session.fromPayment ? null : _openReceipt,
          onDone: _session.fromPayment ? _leaveToSale : _nextOrder,
        );
    }
  }

  Future<void> _createRefund() async {
    final order = _session.order;
    if (order == null) {
      _session.error.value =
          'Refund session has no order. Please re-open the refund from the receipt.';
      return;
    }

    _session.busy.value = true;
    _session.error.value = null;

    final int deviceId =
        Provider.of<KioskAuthProvider>(context, listen: false).deviceId ?? 0;
    final String ref =
        'refund-${order.id}-${DateTime.now().millisecondsSinceEpoch}';
    _session.pendingRef.value = ref;
    final PosRefundSplit? split = _session.selectedSplit.value;

    final ApiResponseModel result =
        await di.sl<PosRefundRepo>().create(
      orderId: order.id,
      deviceId: deviceId,
      reference: ref,
      reason: _session.reason.value?.label,
      partialPaymentId: split != null && !split.itemGroup ? split.id : null,
      splitGroupId: split != null && split.itemGroup ? split.id : null,
    );

    _session.busy.value = false;

    if (!mounted) return;

    // A failed call comes back as `withError` with no response at all, so
    // the status is read null-safely; the flow stays where it is.
    if (!result.isSuccess ||
        !'${result.response?.statusCode}'.startsWith('2')) {
      _session.error.value = _errorText(result.error) ??
          'Failed to create refund. Please try again.';
      return;
    }

    final Map<String, dynamic> body =
        result.response.data as Map<String, dynamic>;
    _session.pendingRefundId.value  = body['refund_id'] as int?;
    _session.pendingRefundSeq.value = body['refund_seq'] as int?;
    _session.refundAmount.value     = (body['amount'] as num?)?.toDouble() ?? 0;
    // `create` answers with the source's original method; the refund goes
    // out the way the operator chose on frame 26 (confirm records the method
    // it is sent). Only an empty choice falls back to the backend's.
    if (_session.refundMethod.value.isEmpty) {
      _session.refundMethod.value = (body['method'] as String?) ?? 'cash';
    }

    setState(() => _step = _RefundStep.waiting);
  }

  Future<void> _confirmRefund() async {
    final order = _session.order;
    if (order == null) {
      _session.error.value =
          'Refund session has no order. Please re-open the refund from the receipt.';
      return;
    }

    _session.busy.value = true;
    _session.error.value = null;

    final int deviceId =
        Provider.of<KioskAuthProvider>(context, listen: false).deviceId ?? 0;

    final ApiResponseModel result =
        await di.sl<PosRefundRepo>().confirm(
      orderId: order.id,
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

    // A failed call comes back as `withError` with no response at all, so
    // the status is read null-safely; the flow stays where it is.
    if (!result.isSuccess ||
        !'${result.response?.statusCode}'.startsWith('2')) {
      _session.error.value = _errorText(result.error) ??
          'Failed to confirm refund. Please try again.';
      return;
    }

    setState(() => _step = _RefundStep.complete);
  }

  /// Frame 29's "Refund € X" for one payment: create the refund (only now —
  /// the backend reserves it, and has no way to release one), then on cash
  /// pay it out straight away when the backend's figure is the one the
  /// operator just confirmed; on card, frame 27 while the terminal refunds.
  Future<void> _refundOneSplit() async {
    // Created already on this visit (the terminal step was cancelled): carry
    // on with that refund rather than reserving a second one.
    if (_session.pendingRefundSeq.value != null) {
      setState(() => _step = _RefundStep.waiting);
      return;
    }
    final double? quoted = _session.refundableFor(_session.selectedSplit.value);
    await _createRefund();
    if (!mounted || _step != _RefundStep.waiting) return;
    final bool sameAmount = quoted != null &&
        (quoted * 100).round() == (_session.refundAmount.value * 100).round();
    if (_session.refundMethod.value == 'cash' && sameAmount) {
      await _confirmRefund();
    }
  }
}

// ── Amounts shown while choosing ─────────────────────────────────────────────

/// What one receipt line refunds: its unit price × quantity.
double _lineAmount(CartModel line) =>
    kioskLineUnitPrice(line) * (line.quantity ?? 1);

/// The figure the summary quotes before the refund is created: what
/// `refund/create` will refund for the current selection — the backend's
/// remaining balance for the order or the picked split. Null until the ledger
/// has loaded. The ticked items do not change it: the backend records them but
/// always refunds the whole remaining balance (see [posRefundableAmount]).
double? _quotedAmount(PosRefundSession session) =>
    session.refundableFor(session.isSplitOrder ? session.selectedSplit.value : null);

/// Rebuilds [builder] whenever anything the selection panes show changes.
class _SessionBuilder extends StatelessWidget {
  final Widget Function(BuildContext context) builder;

  const _SessionBuilder({required this.builder});

  @override
  Widget build(BuildContext context) {
    final PosRefundSession s = PosRefundSession.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([
        s.selectedItemIndices,
        s.reason,
        s.selectedSplit,
        s.refundMethod,
        s.busy,
        s.error,
        s.refundLedger,
      ]),
      builder: (context, _) => builder(context),
    );
  }
}

// ── Screens 25 / 26 — the three-pane selection frame ─────────────────────────

class _SelectionFrame extends StatelessWidget {
  final Widget middle;
  final Widget summary;
  final String Function(double? amount) barLabel;
  final bool Function() barEnabled;
  final VoidCallback onBar;
  final TextEditingController customerName;
  final TextEditingController table;

  const _SelectionFrame({
    required this.middle,
    required this.summary,
    required this.barLabel,
    required this.barEnabled,
    required this.onBar,
    required this.customerName,
    required this.table,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: PosPayThreePane(
            receipt: (fill) => _RefundReceiptCard(
              fill: fill,
              customerName: customerName,
              table: table,
            ),
            method: (fill) => PosPayCard(
              padding: const EdgeInsets.all(PosPaymentSpec.v2MethodCardPadding),
              child: fill ? SingleChildScrollView(child: middle) : middle,
            ),
            summary: (fill) => PosPayCard(
              borderColor: PosSplitSummaryPanel.borderColor,
              borderWidth: PosSplitSummaryPanel.borderWidth,
              child: summary,
            ),
          ),
        ),
        _SessionBuilder(
          builder: (context) {
            final PosRefundSession s = PosRefundSession.instance;
            return PosPayPillBar(
              label: barLabel(_quotedAmount(s)),
              loading: s.busy.value,
              onConfirm: !s.busy.value && barEnabled() ? onBar : null,
            );
          },
        ),
      ],
    );
  }
}

/// `purchase-receipt-sidebar` on the refund frames (node 1915:11354): the
/// payment layer's receipt card with a checkbox in place of the stepper; a
/// picked line is tinted `rgba(240,235,217,0.55)` (node 1915:11370).
class _RefundReceiptCard extends StatelessWidget {
  final bool fill;
  final TextEditingController customerName;
  final TextEditingController table;

  const _RefundReceiptCard({
    required this.fill,
    required this.customerName,
    required this.table,
  });

  static const Color _pickedFill = Color(0x8CF0EBD9);

  @override
  Widget build(BuildContext context) {
    final PosRefundSession s = PosRefundSession.instance;
    final List<CartModel> lines = s.order?.lines ?? const [];

    final Widget list = ValueListenableBuilder<Set<int>>(
      valueListenable: s.selectedItemIndices,
      builder: (context, picked, _) => ListView.builder(
        shrinkWrap: !fill,
        physics: fill ? null : const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: PosHomeSpec.panelPaddingH),
        itemCount: lines.length,
        itemBuilder: (context, i) {
          final bool on = picked.contains(i);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              final Set<int> next = Set<int>.from(picked);
              on ? next.remove(i) : next.add(i);
              s.selectedItemIndices.value = next;
            },
            child: PosReceiptLine(
              line: lines[i],
              imageUrl: '',
              inset: true,
              background: on ? _pickedFill : null,
              trailing: PosPayCheckbox(checked: on),
            ),
          );
        },
      ),
    );

    return PosPayCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
        children: [
          // A settled receipt: the ⋯ button is drawn but has nothing to offer.
          PosReceiptHeader(orderNumber: s.order?.id.toString()),
          PosReceiptCustomerInfo(
            nameController: customerName,
            tableController: table,
            readOnly: true,
            showBottomHairline: false,
            paddingTop: PosPaymentSpec.v2CustomerInfoPaddingTop,
            insideStroke: true,
          ),
          const PosReceiptOrderListLabel(),
          if (fill) Expanded(child: list) else list,
        ],
      ),
    );
  }
}

// ── Middle panes ─────────────────────────────────────────────────────────────

/// "REFUND REASON" (node 1915:11407): the frame's four reasons, in its order.
class _ReasonPane extends StatelessWidget {
  const _ReasonPane();

  static const List<PosRefundReason> _shown = [
    PosRefundReason.customerChanged,
    PosRefundReason.wrongItem,
    PosRefundReason.qualityIssue,
    PosRefundReason.other,
  ];

  @override
  Widget build(BuildContext context) {
    final PosRefundSession s = PosRefundSession.instance;
    return ValueListenableBuilder<PosRefundReason?>(
      valueListenable: s.reason,
      builder: (context, current, _) => _OptionColumn(
        title: 'REFUND REASON',
        options: [
          for (final PosRefundReason r in _shown)
            PosPayOptionRow(
              label: r.label,
              selected: current == r,
              onTap: () => s.reason.value = r,
            ),
        ],
      ),
    );
  }
}

/// "REFUND METHOD" (node 1915:11511). The original tender, and cash.
class _MethodPane extends StatelessWidget {
  const _MethodPane();

  @override
  Widget build(BuildContext context) {
    final PosRefundSession s = PosRefundSession.instance;
    final String original = s.order?.method ?? 'cash';
    return ValueListenableBuilder<String>(
      valueListenable: s.refundMethod,
      builder: (context, method, _) => _OptionColumn(
        title: 'REFUND METHOD',
        options: [
          PosPayOptionRow(
            label: 'Original payment',
            subtitle: original == 'card' ? _cardLabel(s.order) : 'Cash',
            selected: method == original,
            onTap: () => s.refundMethod.value = original,
          ),
          if (original != 'cash')
            PosPayOptionRow(
              label: 'Cash',
              subtitle: 'Pay out from the cash drawer',
              selected: method == 'cash',
              onTap: () => s.refundMethod.value = 'cash',
            ),
          // Frame 26's third option, only when the backend offers it (B5).
          if (s.order?.storeCreditAvailable ?? false)
            PosPayOptionRow(
              label: 'Store credit',
              subtitle: 'Add to customer balance',
              selected: method == _storeCredit,
              onTap: () => s.refundMethod.value = _storeCredit,
            ),
        ],
      ),
    );
  }
}

/// Split orders: which payment to refund (no frame; drawn like 26).
class _SplitPane extends StatelessWidget {
  const _SplitPane();

  @override
  Widget build(BuildContext context) {
    final PosRefundSession s = PosRefundSession.instance;
    return ValueListenableBuilder<PosRefundSplit?>(
      valueListenable: s.selectedSplit,
      builder: (context, selected, _) => _OptionColumn(
        title: 'PAYMENT TO REFUND',
        options: [
          for (final PosRefundSplit split in s.splits)
            PosPayOptionRow(
              label: 'Payment ${split.seq}',
              subtitle:
                  '${split.method == 'card' ? 'Card' : 'Cash'} · ${PosHomeSpec.formatPrice(split.amount, padZero: false)}',
              selected: selected?.id == split.id,
              onTap: () {
                s.selectedSplit.value = split;
                s.refundMethod.value = split.method;
              },
            ),
        ],
      ),
    );
  }
}

/// `payment-method-card` on the refund frames: a 14px tracked title, gap-20,
/// then the options at gap-12.
class _OptionColumn extends StatelessWidget {
  final String title;
  final List<Widget> options;

  const _OptionColumn({required this.title, required this.options});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: loewBold.copyWith(
            fontSize: PosPaymentSpec.v2MethodHeaderSize,
            letterSpacing: PosPaymentSpec.v2MethodHeaderTracking,
            color: PosHomeSpec.inkAlpha(PosPaymentSpec.v2MethodHeaderOpacity),
          ),
        ),
        const SizedBox(height: PosPaymentSpec.v2MethodCardGap),
        for (int i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          options[i],
        ],
      ],
    );
  }
}

/// `RefundController` method key for store credit, once it exists (B5).
const String _storeCredit = 'store_credit';

/// "Card •••• 4242" (node 1915:11518) when the backend sent the last four
/// digits, else plain "Card".
String _cardLabel(PosReceiptDetail? order) {
  final String? last4 = order?.cardLast4;
  return last4 == null ? 'Card' : 'Card •••• $last4';
}

/// The "Refund to" value (node 1915:11549).
String _refundToLabel(PosRefundSession s) => switch (s.refundMethod.value) {
      'card' => _cardLabel(s.order),
      _storeCredit => 'Store credit',
      _ => 'Cash',
    };

const _labelInk = TextTones.secondary; // Figma #78706E (4.3:1)
const _noteInk = TextTones.hint; // Figma #A6A199 (2.3:1)
const _rowBorder = Color(0xFFE8E3D6);
const _summaryRowFill = Color(0xFFF0EBD9);

// ── Right pane — the refund summary ──────────────────────────────────────────

enum _SummaryMode { items, method, split }

/// `Column/Right` on the refund frames (node 1915:11428): REFUND header, the
/// amount, the order-total bar, ITEMS TO REFUND, a summary row and a note —
/// pt-24 px-20 pb-14, gap-12.
class _RefundSummaryPane extends StatelessWidget {
  final String subtitle;
  final _SummaryMode mode;

  const _RefundSummaryPane({required this.subtitle, required this.mode});

  @override
  Widget build(BuildContext context) {
    return _SessionBuilder(builder: (context) {
      final PosRefundSession s = PosRefundSession.instance;
      final List<CartModel> lines = s.order?.lines ?? const [];
      final Set<int> picked = s.selectedItemIndices.value;
      const double gap = PosPaymentSpec.v2SplitItemGap;

      final List<Widget> items = [
        if (mode == _SummaryMode.split && s.selectedSplit.value != null)
          _RefundItem(
            name: 'Payment ${s.selectedSplit.value!.seq}',
            amount: s.selectedSplit.value!.amount,
          )
        else if (lines.isEmpty || picked.isEmpty)
          _RefundItem(name: 'Full order', amount: s.order?.total ?? 0)
        else
          for (final int i in (picked.toList()..sort()))
            if (i < lines.length)
              _RefundItem(
                name: lines[i].product?.name ?? '',
                amount: _lineAmount(lines[i]),
              ),
      ];

      final String method = _refundToLabel(s);
      final String note = switch (mode) {
        _SummaryMode.items =>
          'Tap items on the left to include them in this refund.',
        _ => switch (s.refundMethod.value) {
            'card' =>
              'Refunds to the original payment method can take 3–5 business days.',
            _storeCredit => 'Added to the customer balance.',
            _ => 'Hand the cash to the customer from the drawer.',
          },
      };

      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PosSplitSummaryHeader(
              title: 'REFUND',
              subtitle: subtitle,
              total: _quotedAmount(s) ?? 0,
              totalText: _quotedAmount(s) == null ? '—' : null,
              totalLabel: 'Refund amount',
              remaining: s.order?.total ?? 0,
              barLabel: 'Order total',
            ),
            const SizedBox(height: gap),
            const PosPaySectionLabel('ITEMS TO REFUND'),
            for (final Widget item in items) ...[
              const SizedBox(height: gap),
              item,
            ],
            const SizedBox(height: gap),
            _SummaryRow(
              label: mode == _SummaryMode.items ? 'Items selected' : 'Refund to',
              value: mode == _SummaryMode.items
                  ? '${picked.length} of ${lines.length}'
                  : method,
            ),
            const SizedBox(height: gap),
            Text(
              note,
              style: swiss721Light.copyWith(
                fontSize: 11,
                height: PosPaymentSpec.figmaLeading(11),
                color: _noteInk,
              ),
            ),
            _ErrorText(s.error),
          ],
        ),
      );
    });
  }
}

/// `refund-item` (node 1915:11441): white, 1px `#E8E3D6`, r12, px-16 py-14.
class _RefundItem extends StatelessWidget {
  final String name;
  final double amount;

  const _RefundItem({required this.name, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: PosHomeSpec.tileBg,
        border: Border.all(color: _rowBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: loewBold.copyWith(fontSize: 14, color: PosHomeSpec.ink),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            PosHomeSpec.formatPrice(amount, padZero: false),
            style: loewExtraBold.copyWith(fontSize: 14, color: PosHomeSpec.ink),
          ),
        ],
      ),
    );
  }
}

/// `refund-summary-row` (node 1915:11444): `#F0EBD9`, r8, px-12 py-8.
class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _summaryRowFill,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: loewBold.copyWith(fontSize: 11, color: _labelInk)),
          Text(
            value,
            style: loewExtraBold.copyWith(fontSize: 13, color: PosHomeSpec.ink),
          ),
        ],
      ),
    );
  }
}

// ── Screen 27 / 29 — terminal wait (card) and cash confirmation ──────────────

/// Frame 29's line under the heading: the tender, and what the payment
/// covered when it was a split by item ("Cash · Oat Milk Matcha, …").
String _splitSubheading(PosRefundSplit split) {
  final String? items = split.items;
  if (items != null && items.isNotEmpty) {
    return '${split.method == 'card' ? 'Card' : 'Cash'} · $items';
  }
  return split.method == 'card'
      ? 'Card · refunded on the terminal'
      : 'Cash · hand the refund to the customer from the drawer';
}

/// Frame 29 before the refund exists — "Refund Payment N?" for the one
/// payment its Refund pill was tapped on: the backend's quote for it ("—"
/// until loaded), Cancel / "Refund € X". Nothing is created until Refund.
class _SplitConfirmStep extends StatelessWidget {
  final VoidCallback onCancel;
  final VoidCallback onRefund;

  const _SplitConfirmStep({required this.onCancel, required this.onRefund});

  @override
  Widget build(BuildContext context) {
    final PosRefundSession s = PosRefundSession.instance;
    return _SessionBuilder(builder: (context) {
      final PosRefundSplit? split = s.selectedSplit.value;
      if (split == null) return const SizedBox.shrink();
      final double? quoted = s.refundableFor(split);
      final bool busy = s.busy.value;
      final bool nothingLeft = quoted != null && quoted <= 0;
      return PosPaymentStatusCard(
        heading: 'Refund Payment ${split.seq}?',
        subheading: _splitSubheading(split),
        amountDue: quoted ?? 0,
        amountText: quoted == null ? '—' : null,
        amountLabel: 'REFUND AMOUNT',
        belowAmount: s.error.value != null
            ? _ErrorText(s.error)
            : nothingLeft
                ? const _Note('This payment has already been refunded.')
                : null,
        actions: [
          Expanded(
            child: PosPaymentCardButton(
              insideStroke: true,
              label: 'Cancel',
              onTap: busy ? null : onCancel,
            ),
          ),
          Expanded(
            child: PosPaymentCardButton(
              insideStroke: true,
              label: busy
                  ? 'Refunding...'
                  : quoted == null
                      ? 'Refund'
                      : 'Refund ${PosHomeSpec.formatPrice(quoted, padZero: false)}',
              filled: true,
              onTap: busy || quoted == null || nothingLeft ? null : onRefund,
            ),
          ),
        ],
      );
    });
  }
}

class _WaitingStep extends StatelessWidget {
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  const _WaitingStep({required this.onConfirm, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final PosRefundSession s = PosRefundSession.instance;
    return _SessionBuilder(builder: (context) {
      return ValueListenableBuilder<double>(
        valueListenable: s.refundAmount,
        builder: (context, amount, _) {
          final bool busy = s.busy.value;
          final String amountText =
              PosHomeSpec.formatPrice(amount, padZero: false);
          final PosRefundSplit? split = s.selectedSplit.value;

          if (s.refundMethod.value == 'card') {
            // Frame 27: dots · "Waiting for card on terminal..." · REFUND
            // AMOUNT · Cancel Refund. The terminal is operated by hand, so the
            // card also carries the optional approval code and the confirm
            // action the refund needs (not drawn in the frame).
            return PosPaymentStatusCard(
              indicator: const PosWaitingDots(),
              heading: 'Waiting for card on terminal...',
              amountDue: amount,
              amountLabel: 'REFUND AMOUNT',
              belowAmount: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _ApprovalCodeField(),
                  _ErrorText(s.error),
                ],
              ),
              actions: [
                Expanded(
                  child: PosPaymentCardButton(
                    insideStroke: true,
                    label: 'Cancel Refund',
                    onTap: busy ? null : onCancel,
                  ),
                ),
                Expanded(
                  child: PosPaymentCardButton(
                    insideStroke: true,
                    label: busy ? 'Confirming...' : 'Confirm Refund',
                    filled: true,
                    onTap: busy ? null : onConfirm,
                  ),
                ),
              ],
            );
          }
          // Frame 29: "Refund Payment N?" · tender · REFUND AMOUNT · Cancel /
          // Refund € X. A single-payment cash refund uses the same card.
          final bool credit = s.refundMethod.value == _storeCredit;
          return PosPaymentStatusCard(
            heading: split != null
                ? 'Refund Payment ${split.seq}?'
                : credit
                    ? 'Store Credit Refund'
                    : 'Cash Refund',
            subheading: split != null
                ? _splitSubheading(split)
                : credit
                    ? 'Store credit · added to the customer balance'
                    : 'Cash · hand the refund to the customer from the drawer',
            amountDue: amount,
            amountLabel: 'REFUND AMOUNT',
            belowAmount: s.error.value == null ? null : _ErrorText(s.error),
            actions: [
              Expanded(
                child: PosPaymentCardButton(
                  insideStroke: true,
                  label: 'Cancel',
                  onTap: busy ? null : onCancel,
                ),
              ),
              Expanded(
                child: PosPaymentCardButton(
                  insideStroke: true,
                  label: busy ? 'Confirming...' : 'Refund $amountText',
                  filled: true,
                  onTap: busy ? null : onConfirm,
                ),
              ),
            ],
          );
        },
      );
    });
  }
}

/// Optional approval code from the terminal slip — the stand-alone pane's
/// input (37px, Loew Medium 14, `#E0D9C8` / ink when focused).
class _ApprovalCodeField extends StatelessWidget {
  const _ApprovalCodeField();

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          gapPadding: 0,
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: color, width: 1.5),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Approval code (optional)',
          style: loewRegular.copyWith(
            fontSize: 12,
            color: TextTones.secondary,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 37,
          child: TextField(
            controller: PosRefundSession.instance.approvalCode,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-]')),
            ],
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
              enabledBorder: border(PosHomeSpec.tableFieldBorder),
              focusedBorder: border(PosHomeSpec.ink),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Screen 28 / 30 — Refund Complete ─────────────────────────────────────────

class _CompleteStep extends StatelessWidget {
  final VoidCallback onDone;

  /// Frame 28's outline "Receipt"; null on frame 30.
  final VoidCallback? onReceipt;

  const _CompleteStep({required this.onDone, this.onReceipt});

  @override
  Widget build(BuildContext context) {
    final PosRefundSession session = PosRefundSession.instance;
    final bool isSplit = session.isSplitOrder;
    final int? splitSeq = session.selectedSplit.value?.seq;

    return ValueListenableBuilder<double>(
      valueListenable: session.refundAmount,
      builder: (_, amount, __) => PosPaymentSuccessCard(
        // Frame 28 "Refund Successful"; frame 30 "Payment 1 Refunded".
        title: isSplit
            ? 'Payment ${splitSeq ?? ''} Refunded'
            : 'Refund Successful',
        amount: amount,
        amountLabel: 'AMOUNT REFUNDED',
        secondaryLabel: onReceipt == null ? null : 'Receipt',
        onSecondary: onReceipt,
        buttonLabel: isSplit ? 'Back to order' : 'Next order',
        onContinue: onDone,
      ),
    );
  }
}

class _Note extends StatelessWidget {
  final String text;
  const _Note(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(text,
          style: loewRegular.copyWith(
              fontSize: 13, color: const Color(0xFFB5490A)),
          textAlign: TextAlign.center),
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
