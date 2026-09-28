/// One order, fully expanded, as `GET /api/v1/kiosk/manager/transactions/{id}`
/// returns it for the Orders board detail overlay (Figma **1641:4341**,
/// **1641:4490**, **1641:4640**, **1641:5129**).
///
/// The four Figma frames are one modal on two independent axes — `channelKey`
/// picks the source badge, `orderStatus` picks the status badge and the action
/// — so there is one model here, not one per frame.
///
/// Three of the fields the mock draws are absent on most real orders. Rather
/// than defaulting them to empty strings and letting the widget draw hollow
/// chrome, each is exposed as a nullable plus a `has…` predicate the overlay
/// uses to omit the whole section. See [hasContact] and [displayNote].
library;

import 'package:acafe_customer/features/pos/domain/pos_item_prep_status.dart';

class PosOrderDetail {
  final int id;
  final DateTime? createdAt;
  final String orderStatus;
  final String orderType;
  final String channelKey;
  final String displayMethod;
  final String paymentStatus;
  final String? table;

  final String customerName;

  /// Null for a guest order — there is no `users` row to read these off, which
  /// is the common case rather than the exception.
  final String? customerPhone;
  final String? customerEmail;

  /// Raw `orders.order_note`. Not for display as-is: see [displayNote].
  final String? orderNote;

  final List<PosOrderDetailItem> items;

  /// Server-side "n of m ready" (`items_ready` / `items_total`), counted the
  /// same way `KitchenOrderProgressService` aggregates the order status — so
  /// the counter on screen can never disagree with the status beside it.
  final int itemsReady;
  final int itemsTotal;

  final double subtotal;
  final double discount;
  final double total;

  const PosOrderDetail({
    required this.id,
    required this.createdAt,
    required this.orderStatus,
    required this.orderType,
    required this.channelKey,
    required this.displayMethod,
    required this.paymentStatus,
    required this.table,
    required this.customerName,
    required this.customerPhone,
    required this.customerEmail,
    required this.orderNote,
    required this.items,
    required this.itemsReady,
    required this.itemsTotal,
    required this.subtotal,
    required this.discount,
    required this.total,
  });

  /// Whether the Customer Details card has anything to put in it beyond the
  /// name, which is already in the header. A guest order has neither, so the
  /// section is dropped rather than drawn empty.
  /// Prefers the server's counts, falling back to counting the lines we were
  /// given -- an older build of the API omits the counters but still sends the
  /// per-item statuses, and a progress bar that silently reads 0 of 0 would be
  /// worse than one derived locally.
  PrepProgress get progress => itemsTotal > 0
      ? PrepProgress(ready: itemsReady, total: itemsTotal)
      : PrepProgress.fromStatuses(items.map((i) => i.prepStatus));

  /// The bulk move this order offers, or null when every item is ready.
  PosBulkItemAction? get bulkAction =>
      PosBulkItemAction.forStatuses(items.map((i) => i.prepStatus));

  bool get hasContact =>
      (customerPhone?.trim().isNotEmpty ?? false) ||
      (customerEmail?.trim().isNotEmpty ?? false);

  /// The note with the name-carrier line removed, or null if nothing is left.
  ///
  /// `orders.order_note` does double duty: for a counter or kiosk sale the
  /// backend writes the operator-typed customer name into its first line as
  /// `Kiosk order - <name>`, and `displayCustomerName()` parses it back out —
  /// so that line is *already on screen* as [customerName]. Rendering the raw
  /// column would print the customer's name twice, once labelled "Order
  /// Notes", which reads as a note the customer left.
  ///
  /// Only that first line is dropped, and only when it really is the carrier:
  /// an order with a genuine note underneath keeps it.
  String? get displayNote {
    final String raw = (orderNote ?? '').trim();
    if (raw.isEmpty) return null;

    final List<String> lines = raw.split('\n');
    // Mirrors the server-side regex in KioskManagerController::
    // displayCustomerName() — em dash, en dash or hyphen.
    final RegExp carrier = RegExp(
      r'^\s*Kiosk order\s*[—–-]\s*(.+)$',
      caseSensitive: false,
    );

    final RegExpMatch? match = carrier.firstMatch(lines.first);
    if (match != null) {
      final String carried = (match.group(1) ?? '').trim();
      // Only strip it when it is the name we are already showing. A note that
      // merely starts with those words but carries someone else's text stays.
      if (carried.isNotEmpty && carried == customerName.trim()) {
        lines.removeAt(0);
      }
    }

    final String rest = lines.join('\n').trim();
    return rest.isEmpty ? null : rest;
  }

  /// Replace the lines and the counters after a write, keeping the header,
  /// money and customer blocks the overlay already drew. Used to apply an
  /// item-status response without a second fetch.
  PosOrderDetail copyWith({
    String? orderStatus,
    List<PosOrderDetailItem>? items,
    int? itemsReady,
    int? itemsTotal,
  }) =>
      PosOrderDetail(
        id: id,
        createdAt: createdAt,
        orderStatus: orderStatus ?? this.orderStatus,
        orderType: orderType,
        channelKey: channelKey,
        displayMethod: displayMethod,
        paymentStatus: paymentStatus,
        table: table,
        customerName: customerName,
        customerPhone: customerPhone,
        customerEmail: customerEmail,
        orderNote: orderNote,
        items: items ?? this.items,
        itemsReady: itemsReady ?? this.itemsReady,
        itemsTotal: itemsTotal ?? this.itemsTotal,
        subtotal: subtotal,
        discount: discount,
        total: total,
      );

  factory PosOrderDetail.fromJson(Map<String, dynamic> json) {
    return PosOrderDetail(
      id: int.tryParse('${json['id']}') ?? 0,
      createdAt: DateTime.tryParse('${json['created_at']}')?.toLocal(),
      orderStatus: '${json['order_status'] ?? ''}',
      orderType: '${json['order_type'] ?? ''}',
      channelKey: '${json['channel_key'] ?? ''}',
      displayMethod: '${json['display_method'] ?? ''}',
      paymentStatus: '${json['payment_status'] ?? ''}',
      table: _nullableString(json['table']),
      customerName: '${json['customer_name'] ?? ''}'.trim(),
      customerPhone: _nullableString(json['customer_phone']),
      customerEmail: _nullableString(json['customer_email']),
      orderNote: _nullableString(json['order_note']),
      items: (json['items'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => PosOrderDetailItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false),
      itemsReady: int.tryParse('${json['items_ready']}') ?? 0,
      itemsTotal: int.tryParse('${json['items_total']}') ?? 0,
      subtotal: _asDouble(json['subtotal']) ?? 0,
      discount: _asDouble(json['discount']) ?? 0,
      total: _asDouble(json['total']) ?? 0,
    );
  }
}

/// One line on the order.
///
/// `addons` and `instruction` arrive already resolved by the server's
/// `OrderPreviewPresenter` — the raw `order_details.add_on_ids` column holds
/// bare ids, so nothing here decodes them.
class PosOrderDetailItem {
  /// `order_details.id` -- what the item-status endpoint addresses. Nullable
  /// because a line the server could not identify must still render; it simply
  /// offers no action.
  final int? id;

  /// This line's own kitchen state, independent of every other line and of the
  /// order's status. Mixed orders (one coffee ready, one dish still cooking)
  /// are the normal case, not the exception.
  final PrepStatus prepStatus;

  final String name;
  final String? image;
  final int quantity;
  final double unitPrice;

  /// Free text the customer left against this line, not against the order.
  final String? instruction;

  /// Chosen variation labels, flattened for the `€ 4.50 · Cup` sub-line.
  final List<String> variationLabels;

  final List<PosOrderDetailAddon> addons;

  const PosOrderDetailItem({
    required this.id,
    required this.prepStatus,
    required this.name,
    required this.image,
    required this.quantity,
    required this.unitPrice,
    required this.instruction,
    required this.variationLabels,
    required this.addons,
  });

  /// Whether this line has anything to draw under its price row. Figma always
  /// shows an `item-note`, but a line with no add-ons and no instruction has
  /// nothing to put there, so the row is omitted rather than left blank.
  bool get hasNotes => addons.isNotEmpty || (instruction?.trim().isNotEmpty ?? false);

  /// Only a line the server can address is actionable.
  bool get isActionable => id != null;

  /// Copy with a different prep status -- the optimistic move, before the
  /// server has confirmed it. A copy rather than a mutation so a rollback is
  /// just putting the original back, the same shape [PosOrderCard.withStatus]
  /// uses on the board.
  PosOrderDetailItem withPrepStatus(PrepStatus status) => PosOrderDetailItem(
        id: id,
        prepStatus: status,
        name: name,
        image: image,
        quantity: quantity,
        unitPrice: unitPrice,
        instruction: instruction,
        variationLabels: variationLabels,
        addons: addons,
      );

  factory PosOrderDetailItem.fromJson(Map<String, dynamic> json) {
    final List<String> labels = <String>[];

    for (final dynamic group in (json['variations'] as List? ?? const [])) {
      if (group is! Map) continue;
      for (final dynamic option in (group['options'] as List? ?? const [])) {
        if (option is! Map) continue;
        final String label = '${option['label'] ?? ''}'.trim();
        if (label.isNotEmpty) labels.add(label);
      }
    }

    return PosOrderDetailItem(
      id: int.tryParse('${json['id']}'),
      prepStatus: PrepStatus.fromWire(json['prep_status']),
      name: '${json['name'] ?? ''}',
      image: _nullableString(json['image']),
      quantity: int.tryParse('${json['quantity']}') ?? 1,
      unitPrice: _asDouble(json['unit_price']) ?? 0,
      instruction: _nullableString(json['instruction']),
      variationLabels: labels,
      addons: (json['addons'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => PosOrderDetailAddon.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false),
    );
  }
}

class PosOrderDetailAddon {
  final String name;
  final int quantity;

  const PosOrderDetailAddon({required this.name, required this.quantity});

  factory PosOrderDetailAddon.fromJson(Map<String, dynamic> json) {
    return PosOrderDetailAddon(
      name: '${json['name'] ?? ''}',
      quantity: int.tryParse('${json['quantity']}') ?? 1,
    );
  }
}

String? _nullableString(dynamic value) {
  if (value == null) return null;
  final String s = '$value'.trim();
  return s.isEmpty ? null : s;
}

double? _asDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse('$value');
}
