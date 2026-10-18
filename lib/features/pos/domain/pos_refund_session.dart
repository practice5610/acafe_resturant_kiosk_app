import 'package:acafe_customer/features/pos/domain/pos_receipt_history.dart';
import 'package:flutter/material.dart';

/// Refund reason options shown in Screen 25.
enum PosRefundReason {
  wrongItem('Wrong item'),
  customerChanged('Customer changed mind'),
  qualityIssue('Quality issue'),
  overcharge('Overcharged'),
  other('Other');

  const PosRefundReason(this.label);
  final String label;
}

/// A split payment row as loaded from the order's partial-payment list,
/// used in Screen 26 / 29 to let the operator pick which split to refund.
class PosRefundSplit {
  final int id;
  final int seq;
  final String method;
  final double amount;
  final String? reference;

  /// A split-by-item group (`order_split_groups`, refunded by
  /// `split_group_id`) rather than a split-by-payment row
  /// (`order_partial_payments`, by `partial_payment_id`).
  final bool itemGroup;

  /// What the payment covered, for frame 29's "Cash · Oat Milk Matcha, …"
  /// line: the group's item names. Null for a split by payment.
  final String? items;

  const PosRefundSplit({
    required this.id,
    required this.seq,
    required this.method,
    required this.amount,
    this.reference,
    this.itemGroup = false,
    this.items,
  });

  String get label =>
      'Split $seq — ${method == 'card' ? 'Card' : 'Cash'} €${amount.toStringAsFixed(2)}';
}

/// The refund flow's shared state, driven by [ValueNotifier] so screens
/// rebuild independently without root `setState`.
///
/// Lifecycle:
///  1. Caller sets [order] and [splits] before navigating to /pos-refund.
///  2. Screen 25 writes [selectedItems] + [reason].
///  3. For split orders, Screen 26/29 writes [selectedSplit].
///  4. `create` API call → [pendingRefundSeq] + [refundAmount] + [refundMethod].
///  5. Screen 27 (card): operator types [approvalCode].
///  6. `confirm` API call → done.
///  7. [reset] after success or cancel.
class PosRefundSession {
  PosRefundSession._();
  static final PosRefundSession instance = PosRefundSession._();

  // ── set before entering the flow ──────────────────────────────────────
  PosReceiptDetail? order;
  List<PosRefundSplit> splits = [];

  /// Opened from a paid row's Refund pill on the payment screen (frames
  /// 09–12, 16) for the one payment in [splits]: the screen opens on frame 29
  /// and Back / "Back to order" return to the sale instead of Receipts.
  bool fromPayment = false;

  // ── screen 25 ─────────────────────────────────────────────────────────
  final ValueNotifier<Set<int>> selectedItemIndices =
      ValueNotifier(<int>{});   // indices into order.lines
  final ValueNotifier<PosRefundReason?> reason = ValueNotifier(null);

  // ── screen 26/29 ──────────────────────────────────────────────────────
  final ValueNotifier<PosRefundSplit?> selectedSplit = ValueNotifier(null);

  // ── returned by create ────────────────────────────────────────────────
  final ValueNotifier<int?> pendingRefundId  = ValueNotifier(null);
  final ValueNotifier<int?> pendingRefundSeq = ValueNotifier(null);
  final ValueNotifier<double> refundAmount   = ValueNotifier(0.0);
  final ValueNotifier<String> refundMethod   = ValueNotifier('cash');
  final ValueNotifier<String?> pendingRef    = ValueNotifier(null);

  // ── screen 27 (card) ──────────────────────────────────────────────────
  final TextEditingController approvalCode = TextEditingController();

  // ── refundable balance, read from GET refund/list ─────────────────────
  /// The backend's `refund/list` payload for [order], or null until it has
  /// loaded (or if it failed). Drives [refundableFor] — the amount the
  /// backend will actually refund, which is what the screen quotes.
  final ValueNotifier<Map<String, dynamic>?> refundLedger = ValueNotifier(null);

  /// What `refund/create` will refund for the current selection, or null while
  /// the ledger is unknown. See [posRefundableAmount].
  double? refundableFor(PosRefundSplit? split) {
    final Map<String, dynamic>? ledger = refundLedger.value;
    if (ledger == null) return null;
    return posRefundableAmount(ledger: ledger, split: split);
  }

  // ── busy/error ─────────────────────────────────────────────────────────
  final ValueNotifier<bool>    busy  = ValueNotifier(false);
  final ValueNotifier<String?> error = ValueNotifier(null);

  bool get isSplitOrder => splits.isNotEmpty;

  /// Clears per-flow state (selections, reason, pending result, errors, busy)
  /// WITHOUT touching [order] / [splits], which the caller sets before
  /// navigating in. Use this at the top of the refund screen so a re-entry is
  /// clean but the order it was opened with is preserved.
  void resetFlow() {
    selectedItemIndices.value = {};
    reason.value = null;
    selectedSplit.value = null;
    pendingRefundId.value  = null;
    pendingRefundSeq.value = null;
    refundAmount.value = 0.0;
    refundMethod.value = 'cash';
    pendingRef.value = null;
    approvalCode.clear();
    refundLedger.value = null;
    busy.value  = false;
    error.value = null;
  }

  /// Full reset — clears flow state AND the inbound [order] / [splits]. Call
  /// this after a successful refund or when leaving the flow entirely.
  void reset() {
    order = null;
    splits = [];
    fromPayment = false;
    resetFlow();
  }
}

/// The amount `POST refund/create` refunds, mirrored from the backend
/// (`RefundController::create`), so the screen can quote it before anything
/// is created.
///
/// The backend ignores `items_json` for the money: a refund is always the
/// whole remaining balance of its source —
///  * a split payment: that split's amount minus the refunds already
///    reserved against it (`pending` + `succeeded`);
///  * otherwise the order: `refundable_remaining` from `refund/list`, minus
///    order-level refunds still `pending` (the backend reserves those too).
///
/// [ledger] is the `refund/list` response. Never negative; rounded to cents.
double posRefundableAmount({
  required Map<String, dynamic> ledger,
  PosRefundSplit? split,
}) {
  int cents(dynamic v) => ((num.tryParse('${v ?? 0}') ?? 0) * 100).round();
  final List<Map<String, dynamic>> refunds = [
    for (final dynamic r in (ledger['refunds'] as List? ?? const []))
      if (r is Map) Map<String, dynamic>.from(r),
  ];

  int remaining;
  if (split != null) {
    final String source =
        split.itemGroup ? 'split_group_id' : 'partial_payment_id';
    final int reserved = refunds
        .where((r) =>
            '${r[source]}' == '${split.id}' &&
            (r['status'] == 'pending' || r['status'] == 'succeeded'))
        .fold(0, (sum, r) => sum + cents(r['amount']));
    remaining = (split.amount * 100).round() - reserved;
  } else {
    final int pendingOrderLevel = refunds
        .where((r) =>
            r['partial_payment_id'] == null &&
            r['split_group_id'] == null &&
            r['status'] == 'pending')
        .fold(0, (sum, r) => sum + cents(r['amount']));
    remaining = cents(ledger['refundable_remaining']) - pendingOrderLevel;
  }
  if (remaining < 0) remaining = 0;
  return remaining / 100;
}
