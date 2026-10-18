import 'package:flutter/foundation.dart';

/// One group/payment in a split-by-item order.
///
/// Maps 1-to-1 with the backend's `groups[]` array in the record/balance
/// response. The seq is 1-based and returned by the server.
@immutable
class PosSplitByItemGroup {
  final int seq;
  final List<int> itemIds;
  final double amount;
  final String paidWith; // 'card' | 'cash'
  final double paidAmount;
  final String reference;

  /// `order_split_groups.id` — what `refund/create` takes as `split_group_id`.
  /// Null until the backend includes it in its snapshot (backend-needs B3).
  final int? id;

  /// `pending` until its payment is recorded, then `succeeded`.
  final String status;

  const PosSplitByItemGroup({
    required this.seq,
    required this.itemIds,
    required this.amount,
    required this.paidWith,
    required this.paidAmount,
    required this.reference,
    this.id,
    this.status = 'succeeded',
  });

  bool get isPaid => status == 'succeeded';

  /// Can this group's payment be refunded from the payment screen?
  bool get refundable => id != null && isPaid && paidAmount > 0;

  /// The backend's group snapshot (`SplitByItemController::snapshot`) carries
  /// `seq, amount, item_ids, paid_with, status, reference` — no `paid_amount`
  /// (a recorded group is paid in full).
  factory PosSplitByItemGroup.fromJson(Map<String, dynamic> json) {
    final double amount = _num(json['amount']);
    final String status = (json['status'] as String?) ?? 'succeeded';
    return PosSplitByItemGroup(
      seq: _num(json['seq']).toInt(),
      itemIds: [
        for (final dynamic e in (json['item_ids'] as List<dynamic>? ?? const []))
          _num(e).toInt(),
      ],
      amount: amount,
      paidWith: (json['paid_with'] as String?) ?? '',
      paidAmount: json['paid_amount'] != null
          ? _num(json['paid_amount'])
          : (status == 'succeeded' ? amount : 0),
      reference: (json['reference'] as String?) ?? '',
      id: json['id'] == null ? null : _num(json['id']).toInt(),
      status: status,
    );
  }
}

double _num(dynamic v) => v is num ? v.toDouble() : (double.tryParse('$v') ?? 0);

/// Snapshot of a split-by-item order, updated after each recorded payment.
///
/// Immutable: a new instance is created each time the backend confirms a group payment.
@immutable
class PosSplitByItemState {
  final int orderId;
  final int deviceId;
  final double grandTotal;
  final List<PosSplitByItemGroup> groups;
  final double paid;
  final double remaining;
  final bool fullyPaid;

  const PosSplitByItemState({
    required this.orderId,
    required this.deviceId,
    required this.grandTotal,
    required this.groups,
    required this.paid,
    required this.remaining,
    required this.fullyPaid,
  });

  /// The next 1-based group number.
  int get nextSequence => groups.length + 1;

  /// An empty starting snapshot: order placed, no groups collected yet.
  factory PosSplitByItemState.initial({
    required int orderId,
    required int deviceId,
    required double grandTotal,
  }) =>
      PosSplitByItemState(
        orderId: orderId,
        deviceId: deviceId,
        grandTotal: grandTotal,
        groups: const [],
        paid: 0,
        remaining: grandTotal,
        fullyPaid: false,
      );

  /// The groups already paid.
  List<PosSplitByItemGroup> get paidGroups =>
      [for (final g in groups) if (g.isPaid) g];

  /// Items earlier guests already paid for.
  Set<int> get paidItemIds => {for (final g in paidGroups) ...g.itemIds};

  /// False until the first guest pays: the order is placed only then.
  bool get placed => orderId > 0;

  /// This snapshot quoting [total] — the live cart total (plus tip) while
  /// nothing is placed yet. A placed order keeps the server's figures.
  PosSplitByItemState withLiveTotal(double total) => placed
      ? this
      : PosSplitByItemState(
          orderId: orderId,
          deviceId: deviceId,
          grandTotal: total,
          groups: groups,
          paid: 0,
          remaining: total,
          fullyPaid: false,
        );

  /// The next 1-based payment number shown to the operator.
  int get nextPaymentNumber => paidGroups.length + 1;

  /// Parse a pay-items / balance response body. Should `paid` / `remaining` /
  /// `fully_paid` be missing they are derived from the groups.
  factory PosSplitByItemState.fromJson(
    Map<String, dynamic> json, {
    required int deviceId,
  }) {
    final List<PosSplitByItemGroup> groups = [
      for (final dynamic e in (json['groups'] as List<dynamic>? ?? const []))
        if (e is Map) PosSplitByItemGroup.fromJson(Map<String, dynamic>.from(e)),
    ];
    final double grand = _num(json['grand_total']);
    final double paid = json['paid'] != null
        ? _num(json['paid'])
        : groups.where((g) => g.isPaid).fold(0.0, (a, g) => a + g.amount);
    final double remaining = json['remaining'] != null
        ? _num(json['remaining'])
        : (grand - paid < 0 ? 0 : grand - paid);
    return PosSplitByItemState(
      orderId: _num(json['order_id']).toInt(),
      deviceId: deviceId,
      grandTotal: grand,
      groups: groups,
      paid: paid,
      remaining: remaining,
      fullyPaid: json['fully_paid'] as bool? ?? (remaining <= 0 && grand > 0),
    );
  }
}

/// ValueNotifier that drives the split-by-item UI.
///
///  * null  = not in split-by-item mode (normal single-tender sale)
///  * non-null = collecting guest payments; [PosSplitByItemState.placed] once
///    the first payment has placed the order
///
/// Held in [_PosPaymentSelectionScreenState] and disposed with the screen.
class PosSplitByItemSession extends ValueNotifier<PosSplitByItemState?> {
  PosSplitByItemSession() : super(null);

  bool get active => value != null;

  void start({
    required int orderId,
    required int deviceId,
    required double grandTotal,
  }) {
    value = PosSplitByItemState.initial(
      orderId: orderId,
      deviceId: deviceId,
      grandTotal: grandTotal,
    );
  }

  /// Replace the snapshot after a group payment is recorded.
  void update(PosSplitByItemState state) => value = state;

  /// The order behind the payments now exists (placed with the first one).
  void attachOrder(int orderId, double grandTotal) {
    final PosSplitByItemState? s = value;
    if (s == null) return;
    value = PosSplitByItemState(
      orderId: orderId,
      deviceId: s.deviceId,
      grandTotal: grandTotal,
      groups: s.groups,
      paid: s.paid,
      remaining: grandTotal - s.paid,
      fullyPaid: false,
    );
  }

  /// Leave split-by-item mode (after full payment or on error before any groups).
  void clear() => value = null;
}
