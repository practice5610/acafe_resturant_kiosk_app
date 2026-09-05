import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:intl/intl.dart';

/// One row of the Receipts list, from `GET /kiosk/manager/transactions`.
///
/// `customer_name`, `products_summary` and `display_method` are the additive
/// keys that endpoint gained for this screen — see KioskManagerController.
class PosReceiptRow {
  final int id;
  final DateTime? placedAt;
  final String customerName;
  final String productsSummary;

  /// `cash` or `card`, derived server-side. Never the wire `payment_method`,
  /// which is `cash_on_delivery` on every order this app places.
  final String method;
  final double amount;
  final String orderStatus;
  final String paymentStatus;
  final String channelKey;

  const PosReceiptRow({
    required this.id,
    required this.placedAt,
    required this.customerName,
    required this.productsSummary,
    required this.method,
    required this.amount,
    required this.orderStatus,
    required this.paymentStatus,
    required this.channelKey,
  });

  factory PosReceiptRow.fromJson(Map<String, dynamic> json) {
    return PosReceiptRow(
      id: _asInt(json['id']) ?? 0,
      placedAt: _asDate(json['created_at']),
      customerName: '${json['customer_name'] ?? ''}'.trim(),
      productsSummary: '${json['products_summary'] ?? ''}'.trim(),
      method: '${json['display_method'] ?? 'cash'}',
      amount: _asDouble(json['order_amount']) ?? 0,
      orderStatus: '${json['order_status'] ?? ''}',
      paymentStatus: '${json['payment_status'] ?? ''}',
      channelKey: '${json['channel_key'] ?? ''}',
    );
  }

  String get receiptNumber => '#$id';

  /// `23 June, 12:14 PM` — Figma 1641:3267.
  String get placedAtLabel => placedAt == null
      ? '—'
      : DateFormat('d MMMM, h:mm a').format(placedAt!.toLocal());

  String get methodLabel => method == 'card' ? 'Card' : 'Cash';
}

/// A receipt in full, from `GET /kiosk/manager/transactions/{id}`.
class PosReceiptDetail {
  final int id;
  final DateTime? placedAt;
  final String customerName;

  /// Null for every counter sale: POS does not persist a table number, so the
  /// field renders empty rather than inventing one. See Phase 1 §Q2.
  final String? table;
  final String method;
  final double subtotal;
  final double discount;
  final double total;
  final String orderStatus;

  /// Adapted into [CartModel] so the shared [PosReceiptLine] draws a historical
  /// line exactly as it draws a live one — same name, unit price, size suffix
  /// and add-on notes, with no second copy of that layout to keep in step.
  final List<CartModel> lines;

  const PosReceiptDetail({
    required this.id,
    required this.placedAt,
    required this.customerName,
    required this.table,
    required this.method,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.orderStatus,
    required this.lines,
  });

  factory PosReceiptDetail.fromJson(Map<String, dynamic> json) {
    final List<CartModel> lines = [];
    for (final dynamic entry in (json['details'] as List? ?? const [])) {
      if (entry is! Map) continue;
      final CartModel? line =
          _lineFromOrderDetail(Map<String, dynamic>.from(entry));
      if (line != null) lines.add(line);
    }

    final String? table = json['table'] == null ? null : '${json['table']}';

    return PosReceiptDetail(
      id: _asInt(json['id']) ?? 0,
      placedAt: _asDate(json['created_at']),
      customerName: '${json['customer_name'] ?? ''}'.trim(),
      table: (table == null || table.isEmpty) ? null : table,
      method: '${json['display_method'] ?? 'cash'}',
      subtotal: _asDouble(json['subtotal']) ?? 0,
      discount: _asDouble(json['discount']) ?? 0,
      total: _asDouble(json['total']) ?? 0,
      orderStatus: '${json['order_status'] ?? ''}',
      lines: lines,
    );
  }

  String get receiptNumber => '$id';
}

/// Rebuilds the cart line an order was placed from, out of the stored
/// `order_details` row.
///
/// The backend hands these back through `Helpers::order_details_formatter()`,
/// so `product_details` is a whole product (with its add-ons already resolved
/// to rows carrying `is_default`) and `add_on_ids` is the list the customer
/// actually chose. That is everything [posReceiptNotes] needs to tell a chosen
/// extra (`+ Oat milk`) from a removed default (`- Whipped cream`).
CartModel? _lineFromOrderDetail(Map<String, dynamic> detail) {
  final dynamic rawProduct = detail['product_details'];
  if (rawProduct is! Map) return null;

  final Product product =
      Product.fromJson(Map<String, dynamic>.from(rawProduct));

  // Which values of each variation group were picked, keyed by group name --
  // order_details.variation stores only the chosen ones.
  final Map<String, Set<String>> chosen = {};
  for (final dynamic group in (detail['variation'] as List? ?? const [])) {
    if (group is! Map) continue;
    final String name = '${group['name'] ?? ''}';
    final Set<String> labels = chosen.putIfAbsent(name, () => <String>{});
    for (final dynamic value in (group['values'] as List? ?? const [])) {
      if (value is Map && value['label'] != null) {
        labels.add('${value['label']}');
      }
    }
  }

  // posReceiptNotes/posReceiptUnit read this as a parallel matrix over the
  // product's own variation groups, so it has to be shaped by the product,
  // not by what the order happened to store.
  final List<List<bool?>> flags = [
    for (final Variation variation in product.variations ?? const <Variation>[])
      [
        for (final VariationValue value
            in variation.variationValues ?? const <VariationValue>[])
          chosen[variation.name ?? '']?.contains(value.level ?? '') ?? false,
      ],
  ];

  final List<AddOn> selectedAddOns = [
    for (final dynamic id in (detail['add_on_ids'] as List? ?? const []))
      if (_asInt(id) != null) AddOn(id: _asInt(id), quantity: 1),
  ];

  final double price = _asDouble(detail['price']) ?? 0;
  final double lineDiscount = _asDouble(detail['discount_on_product']) ?? 0;

  return CartModel(
    price,
    price - lineDiscount,
    const <Variation>[],
    lineDiscount,
    _asInt(detail['quantity']) ?? 1,
    _asDouble(detail['tax_amount']) ?? 0,
    selectedAddOns,
    product,
    flags,
  );
}

int? _asInt(dynamic value) =>
    value is int ? value : int.tryParse('$value'.trim());

double? _asDouble(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('$value'.trim());

DateTime? _asDate(dynamic value) =>
    value == null ? null : DateTime.tryParse('$value');
