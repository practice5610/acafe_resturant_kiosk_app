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

  const PosSplitByItemGroup({
    required this.seq,
    required this.itemIds,
    required this.amount,
    required this.paidWith,
    required this.paidAmount,
    required this.reference,
  });

  factory PosSplitByItemGroup.fromJson(Map<String, dynamic> json) =>
      PosSplitByItemGroup(
        seq: (json['seq'] as num).toInt(),
        itemIds: List<int>.from((json['item_ids'] as List<dynamic>? ?? [])
            .map((e) => (e as num).toInt())),
        amount: (json['amount'] as num).toDouble(),
        paidWith: (json['paid_with'] as String?) ?? '',
        paidAmount: (json['paid_amount'] as num).toDouble(),
        reference: (json['reference'] as String?) ?? '',
      );
}

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

  /// Parse the record/balance response body.
  factory PosSplitByItemState.fromJson(
    Map<String, dynamic> json, {
    required int deviceId,
  }) {
    final List<PosSplitByItemGroup> groups =
        (json['groups'] as List<dynamic>? ?? [])
            .map((e) => PosSplitByItemGroup.fromJson(e as Map<String, dynamic>))
            .toList();
    return PosSplitByItemState(
      orderId: (json['order_id'] as num).toInt(),
      deviceId: deviceId,
      grandTotal: (json['grand_total'] as num).toDouble(),
      groups: groups,
      paid: (json['paid'] as num).toDouble(),
      remaining: (json['remaining'] as num).toDouble(),
      fullyPaid: json['fully_paid'] as bool? ?? false,
    );
  }
}

/// ValueNotifier that drives the split-by-item UI.
///
///  * null  = not in split-by-item mode (normal single-tender sale)
///  * non-null = order placed up front; collecting item groups
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

  /// Leave split-by-item mode (after full payment or on error before any groups).
  void clear() => value = null;
}
