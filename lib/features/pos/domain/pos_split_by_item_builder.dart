import 'package:flutter/foundation.dart';

/// One receipt line item with a price.
@immutable
class PosSplitByItemLineItem {
  final int id;
  final String name;
  final String variant;
  final double price;

  const PosSplitByItemLineItem({
    required this.id,
    required this.name,
    required this.variant,
    required this.price,
  });
}

/// Tracks selected items for a single payment group being assembled.
///
/// The operator checks items, and we track which ones they've selected.
/// Once they start payment, the group is finalized (sent to backend).
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

  /// Calculate the total amount for selected items.
  double calculateAmount(List<PosSplitByItemLineItem> allItems) {
    return allItems
        .where((item) => selectedItemIds.contains(item.id))
        .fold(0.0, (sum, item) => sum + item.price);
  }

  /// Check if an item is selected.
  bool isSelected(int itemId) => selectedItemIds.contains(itemId);

  /// Toggle an item's selection.
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

/// Manages the full split-by-item group assembly flow.
///
/// The operator creates multiple groups by selecting items for each one.
/// This holder tracks which items are selected for the current payment group.
class PosSplitByItemGroupsBuilder extends ValueNotifier<PosSplitByItemGroupBuilder> {
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

  /// Move to the next group after this one is paid.
  void nextGroup(int nextGroupSeq) {
    value = PosSplitByItemGroupBuilder(
      groupSeq: nextGroupSeq,
      selectedItemIds: const {},
    );
  }
}
