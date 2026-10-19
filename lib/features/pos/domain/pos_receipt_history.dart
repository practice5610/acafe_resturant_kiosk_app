import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:intl/intl.dart';

// Backend returns "Walk-in" when no customer name was entered. Treat it as
// empty so the POS UI shows the field blank rather than the backend sentinel.
String _stripWalkIn(String v) => v.toLowerCase() == 'walk-in' ? '' : v;

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
      customerName: _stripWalkIn('${json['customer_name'] ?? ''}'.trim()),
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

  String get methodLabel => _methodLabel(method);
}

String _methodLabel(String method) {
  switch (method) {
    case 'card':
      return 'Card';
    case 'invoice':
      return 'Invoice';
    case 'standalone':
      return 'Stand-alone';
    default:
      return 'Cash';
  }
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

  /// The tip, already inside [total] (`order_amount` is what was charged);
  /// shown as its own line so the subtotal no longer absorbs it.
  final double tip;
  final double total;
  final String orderStatus;
  final String paymentStatus;

  /// Adapted into [CartModel] so the shared [PosReceiptLine] draws a historical
  /// line exactly as it draws a live one — same name, unit price, size suffix
  /// and add-on notes, with no second copy of that layout to keep in step.
  final List<CartModel> lines;

  /// The card's last four digits, for "Card •••• 4242" on the refund method
  /// step (frame 26). Read from `card_last4` — which the backend does not
  /// send yet (ui-audit/backend-needs.md B5), so it is null today and the
  /// step says just "Card". Never made up.
  final String? cardLast4;

  /// The refund step offers "Store credit" only when the backend says the
  /// order can take one (`store_credit_available: true`, B5) — never today.
  final bool storeCreditAvailable;

  const PosReceiptDetail({
    required this.id,
    required this.placedAt,
    required this.customerName,
    required this.table,
    required this.method,
    required this.subtotal,
    required this.discount,
    this.tip = 0,
    required this.total,
    required this.orderStatus,
    required this.paymentStatus,
    required this.lines,
    this.cardLast4,
    this.storeCreditAvailable = false,
  });

  /// True when the order has received at least one payment and has not already
  /// been fully refunded — the condition that enables the Refund button.
  bool get isRefundable =>
      paymentStatus == 'paid' ||
      paymentStatus == 'partial_paid' ||
      paymentStatus == 'partial_refunded';

  /// Fully refunded (`refunded`, set by RefundController once the refunds
  /// cover the paid total). A refunded sale is closed: it can't be reopened
  /// or have its payment method changed.
  bool get isRefunded => paymentStatus == 'refunded';

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
      customerName: _stripWalkIn('${json['customer_name'] ?? ''}'.trim()),
      table: (table == null || table.isEmpty) ? null : table,
      method: '${json['display_method'] ?? 'cash'}',
      subtotal: _asDouble(json['subtotal']) ?? 0,
      discount: _asDouble(json['discount']) ?? 0,
      tip: _asDouble(json['tip_amount']) ?? 0,
      total: _asDouble(json['total']) ?? 0,
      orderStatus: '${json['order_status'] ?? ''}',
      paymentStatus: '${json['payment_status'] ?? ''}',
      lines: lines,
      cardLast4: _last4(json['card_last4']),
      storeCreditAvailable: json['store_credit_available'] == true,
    );
  }

  /// Exactly four digits, or nothing.
  static String? _last4(dynamic v) {
    final String text = '${v ?? ''}'.trim();
    return RegExp(r'^\d{4}$').hasMatch(text) ? text : null;
  }

  String get receiptNumber => '$id';

  String get methodLabel => _methodLabel(method);
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

  // The kitchen note typed for this line at the till (order_details.instruction).
  final String note = '${detail['instruction'] ?? ''}'.trim();

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
    instruction: note.isEmpty ? null : note,
  );
}

/// What a line's option picks add to its unit price (Large `+ €10`, Oat
/// `+ €0.50`), read off the same product variations the picks index into.
///
/// A stored line's `price` already includes this; the receipt editor uses the
/// difference between two pick sets to move that price when a pick changes.
double posLineVariationSurcharge(CartModel line) {
  final List<Variation> variations = line.product?.variations ?? const [];
  final List<List<bool?>> picks = line.variations ?? const [];
  double surcharge = 0;
  for (int i = 0; i < variations.length && i < picks.length; i++) {
    final List<VariationValue> values =
        variations[i].variationValues ?? const <VariationValue>[];
    for (int j = 0; j < values.length && j < picks[i].length; j++) {
      if (picks[i][j] == true) surcharge += values[j].optionPrice ?? 0;
    }
  }
  return surcharge;
}

int? _asInt(dynamic value) =>
    value is int ? value : int.tryParse('$value'.trim());

double? _asDouble(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('$value'.trim());

DateTime? _asDate(dynamic value) =>
    value == null ? null : DateTime.tryParse('$value');
