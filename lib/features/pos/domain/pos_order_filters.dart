import 'package:acafe_customer/features/pos/domain/pos_receipt_filters.dart';

/// The four filter dropdowns above the Orders board (Figma 1641:2903).
///
/// Reuses [PosReceiptFilterOption] and the existing [PosFilterDropdown] rather
/// than introducing a parallel option type — the control is the same one
/// Receipts already ships, only the option sets differ.
///
/// Every set opens with its "all" entry: it is both the default and the way
/// back out of a filter.
class PosOrderFilters {
  PosOrderFilters._();

  /// Source is `channel_key`, derived server-side by
  /// `ZReportService::classifyChannel()`. Three real values, three glyphs — see
  /// [PosOrderSourceIcon].
  static const List<PosReceiptFilterOption<String?>> sources = [
    PosReceiptFilterOption('All sources', null),
    PosReceiptFilterOption('Counter POS', 'counter_pos'),
    PosReceiptFilterOption('Kiosk', 'kiosk'),
    PosReceiptFilterOption('Web app', 'web_app'),
  ];

  /// Type is `orders.order_type` — a real column, distinct from source. Local
  /// data only ever carries `pos` and `take_away`, but `dine_in` and `delivery`
  /// are written by the admin POS and the web app respectively, so all four
  /// stay listed.
  static const List<PosReceiptFilterOption<String?>> types = [
    PosReceiptFilterOption('All types', null),
    PosReceiptFilterOption('Point of sale', 'pos'),
    PosReceiptFilterOption('Take away', 'take_away'),
    PosReceiptFilterOption('Dine in', 'dine_in'),
    PosReceiptFilterOption('Delivery', 'delivery'),
  ];

  /// Derived, never `payment_method` — POS orders all post
  /// `cash_on_delivery` as a placeholder. Same derivation Receipts uses.
  static const List<PosReceiptFilterOption<String?>> methods = [
    PosReceiptFilterOption('All payment methods', null),
    PosReceiptFilterOption('Cash', 'cash'),
    PosReceiptFilterOption('Card', 'card'),
  ];

  /// Board statuses only. `canceled` is absent on purpose: it has no section,
  /// so offering it as a filter would promise rows the board cannot draw.
  static const List<PosReceiptFilterOption<String?>> statuses = [
    PosReceiptFilterOption('Any status', null),
    PosReceiptFilterOption('New', 'new'),
    PosReceiptFilterOption('Preparing', 'preparing'),
    PosReceiptFilterOption('On hold', 'on_hold'),
    PosReceiptFilterOption('Ready to collect', 'item_to_collect'),
    PosReceiptFilterOption('Completed', 'completed'),
  ];
}
