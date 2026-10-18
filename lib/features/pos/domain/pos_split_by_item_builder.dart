import 'package:acafe_customer/features/pos/domain/pos_cash_entry.dart';
import 'package:flutter/foundation.dart';

/// One receipt line as the split-by-item list shows it (Figma 1915:12931).
@immutable
class PosSplitByItemLineItem {
  /// The line's 0-based position on the ticket — what the backend stores in
  /// the guest's `item_ids`.
  final int id;
  final String name;

  /// The second line of the row: the line's add-ons and variations ("Oat milk
  /// · No whipped cream"), else its unit ("Cup"); empty for neither.
  final String detail;
  final int quantity;

  /// What the receipt charges for the whole line (unit price × quantity).
  final double price;

  const PosSplitByItemLineItem({
    required this.id,
    required this.name,
    required this.price,
    this.detail = '',
    this.quantity = 1,
  });

  /// "Cappuccino × 2" for a line of more than one (frame 21).
  String get title => quantity > 1 ? '$name × $quantity' : name;
}

/// What one guest pays for the items they picked.
@immutable
class PosSplitByItemQuote {
  /// The charge, in minor units.
  final int cents;

  /// The pick also takes every item still unpaid: this payment settles the
  /// order, so it charges exactly what is left.
  final bool settles;

  const PosSplitByItemQuote({required this.cents, required this.settles});

  static const PosSplitByItemQuote none =
      PosSplitByItemQuote(cents: 0, settles: false);

  bool get payable => cents > 0;
}

/// A guest's share for [picked] items.
///
/// Each guest pays for their own items. Any order-level difference between
/// the items and the order total — a coupon discount, a tip added before the
/// first payment — is shared in proportion to what each guest had, so nobody
/// carries another guest's discount or tip. With neither, the share is exactly
/// the picked items' sum.
///
/// The guest who takes the last unpaid items pays exactly [remaining], which
/// absorbs the rounding of the proportional shares before them, so the
/// payments always add up to the order total to the cent.
///
/// [paid] are the item ids earlier guests already paid; they can't be picked
/// again and are ignored if present in [picked].
PosSplitByItemQuote posQuoteSplitByItem({
  required List<PosSplitByItemLineItem> items,
  required Set<int> picked,
  required Set<int> paid,
  required double orderTotal,
  required double remaining,
  int decimals = 2,
}) {
  final int remainingCents = posMoneyToCents(remaining, decimals: decimals);
  final List<PosSplitByItemLineItem> open = [
    for (final PosSplitByItemLineItem i in items)
      if (!paid.contains(i.id)) i,
  ];
  final List<PosSplitByItemLineItem> mine = [
    for (final PosSplitByItemLineItem i in open)
      if (picked.contains(i.id)) i,
  ];
  if (mine.isEmpty || remainingCents <= 0) return PosSplitByItemQuote.none;

  if (mine.length == open.length) {
    return PosSplitByItemQuote(cents: remainingCents, settles: true);
  }

  int sumCents(Iterable<PosSplitByItemLineItem> of) => of.fold(
      0, (int a, PosSplitByItemLineItem i) => a + posMoneyToCents(i.price, decimals: decimals));
  final int itemsCents = sumCents(items);
  final int mineCents = sumCents(mine);
  if (itemsCents <= 0 || mineCents <= 0) return PosSplitByItemQuote.none;

  final int orderCents = posMoneyToCents(orderTotal, decimals: decimals);
  final int share = (mineCents * orderCents / itemsCents).round();
  // A share can never be more than is still owed.
  final int cents = share > remainingCents ? remainingCents : share;
  return PosSplitByItemQuote(cents: cents, settles: cents == remainingCents);
}

/// Tracks the items ticked for the payment being assembled.
@immutable
class PosSplitByItemGroupBuilder {
  final int groupSeq;
  final Set<int> selectedItemIds;

  const PosSplitByItemGroupBuilder({
    required this.groupSeq,
    required this.selectedItemIds,
  });

  PosSplitByItemGroupBuilder copyWith({Set<int>? selectedItemIds}) =>
      PosSplitByItemGroupBuilder(
        groupSeq: groupSeq,
        selectedItemIds: selectedItemIds ?? this.selectedItemIds,
      );

  /// The picked items' own sum (before any shared discount or tip).
  double calculateAmount(List<PosSplitByItemLineItem> allItems) {
    return allItems
        .where((item) => selectedItemIds.contains(item.id))
        .fold(0.0, (sum, item) => sum + item.price);
  }

  bool isSelected(int itemId) => selectedItemIds.contains(itemId);

  PosSplitByItemGroupBuilder toggleItem(int itemId) {
    final newSelected = Set<int>.from(selectedItemIds);
    if (newSelected.contains(itemId)) {
      newSelected.remove(itemId);
    } else {
      newSelected.add(itemId);
    }
    return copyWith(selectedItemIds: newSelected);
  }
}

/// The ticked items for the current payment, as a listenable so only the
/// split-by-item pane and the sticky bar rebuild on a tick.
class PosSplitByItemGroupsBuilder
    extends ValueNotifier<PosSplitByItemGroupBuilder> {
  PosSplitByItemGroupsBuilder({required int groupSeq})
      : super(PosSplitByItemGroupBuilder(
          groupSeq: groupSeq,
          selectedItemIds: const {},
        ));

  void toggleItem(int itemId) {
    value = value.toggleItem(itemId);
  }

  void clearSelection() {
    value = PosSplitByItemGroupBuilder(
      groupSeq: value.groupSeq,
      selectedItemIds: const {},
    );
  }

  /// Moves to payment [nextGroupSeq] with [preselected] already ticked.
  void nextGroup(int nextGroupSeq, {Set<int> preselected = const {}}) {
    value = PosSplitByItemGroupBuilder(
      groupSeq: nextGroupSeq,
      selectedItemIds: Set<int>.unmodifiable(preselected),
    );
  }
}
