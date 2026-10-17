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

  const PosRefundSplit({
    required this.id,
    required this.seq,
    required this.method,
    required this.amount,
    this.reference,
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
    busy.value  = false;
    error.value = null;
  }

  /// Full reset — clears flow state AND the inbound [order] / [splits]. Call
  /// this after a successful refund or when leaving the flow entirely.
  void reset() {
    order = null;
    splits = [];
    resetFlow();
  }
}
