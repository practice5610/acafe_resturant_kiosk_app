import 'package:flutter/foundation.dart';

/// One payment already collected against a split-by-payment order.
///
/// Maps 1-to-1 with the backend's `payments[]` array in the record/balance
/// response. The reference is kept so a retry can replay the same key.
@immutable
class PosSplitPayment {
  final int seq;
  final String paidWith; // 'card' | 'cash'
  final double paidAmount;
  final String reference;

  /// `order_partial_payments.id` — what `refund/create` takes as
  /// `partial_payment_id`. Null until the backend includes it in its
  /// snapshot (backend-needs B3).
  final int? id;

  /// `succeeded` for a recorded payment.
  final String status;

  const PosSplitPayment({
    required this.seq,
    required this.paidWith,
    required this.paidAmount,
    required this.reference,
    this.id,
    this.status = 'succeeded',
  });

  /// Can this payment be refunded from the payment screen?
  bool get refundable => id != null && status == 'succeeded' && paidAmount > 0;

  factory PosSplitPayment.fromJson(Map<String, dynamic> json) =>
      PosSplitPayment(
        seq: (json['seq'] as num).toInt(),
        paidWith: (json['paid_with'] as String?) ?? '',
        paidAmount: (json['paid_amount'] as num).toDouble(),
        reference: (json['reference'] as String?) ?? '',
        id: (json['id'] as num?)?.toInt(),
        status: (json['status'] as String?) ?? 'succeeded',
      );
}

/// Snapshot of a split-by-payment order, updated after each recorded split.
///
/// Immutable: a new instance is created each time the backend confirms a split.
@immutable
class PosSplitState {
  final int orderId;
  final int deviceId;
  final double grandTotal;
  final List<PosSplitPayment> payments;
  final double paid;
  final double remaining;
  final bool fullyPaid;

  const PosSplitState({
    required this.orderId,
    required this.deviceId,
    required this.grandTotal,
    required this.payments,
    required this.paid,
    required this.remaining,
    required this.fullyPaid,
  });

  /// The next 1-based split number.
  int get nextSequence => payments.length + 1;

  /// An empty starting snapshot: order placed, no splits collected yet.
  factory PosSplitState.initial({
    required int orderId,
    required int deviceId,
    required double grandTotal,
  }) =>
      PosSplitState(
        orderId: orderId,
        deviceId: deviceId,
        grandTotal: grandTotal,
        payments: const [],
        paid: 0,
        remaining: grandTotal,
        fullyPaid: false,
      );

  /// Parse the record/balance response body.
  factory PosSplitState.fromJson(
    Map<String, dynamic> json, {
    required int deviceId,
  }) {
    final List<PosSplitPayment> payments =
        (json['payments'] as List<dynamic>? ?? [])
            .map((e) => PosSplitPayment.fromJson(e as Map<String, dynamic>))
            .toList();
    return PosSplitState(
      orderId: (json['order_id'] as num).toInt(),
      deviceId: deviceId,
      grandTotal: (json['grand_total'] as num).toDouble(),
      payments: payments,
      paid: (json['paid'] as num).toDouble(),
      remaining: (json['remaining'] as num).toDouble(),
      fullyPaid: json['fully_paid'] as bool? ?? false,
    );
  }
}

/// ValueNotifier that drives the split-by-payment UI.
///
///  * null  = not in split mode (normal single-tender sale)
///  * non-null = order placed up front; collecting splits
///
/// Held in [_PosPaymentSelectionScreenState] and disposed with the screen.
/// ValueListenableBuilder wraps the subtree that cares about it so the rebuild
/// stays surgical — no root setState.
class PosSplitSession extends ValueNotifier<PosSplitState?> {
  PosSplitSession() : super(null);

  bool get active => value != null;

  void start({
    required int orderId,
    required int deviceId,
    required double grandTotal,
  }) {
    value = PosSplitState.initial(
      orderId: orderId,
      deviceId: deviceId,
      grandTotal: grandTotal,
    );
  }

  /// Replace the snapshot after a split is recorded.
  void update(PosSplitState state) => value = state;

  /// Leave split mode (after full payment or on error before any splits).
  void clear() => value = null;
}
