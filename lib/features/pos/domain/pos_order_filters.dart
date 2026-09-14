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

  /// Quick date-range presets, mirroring the admin dashboard's
  /// `date-filter-pills` (Yesterday / Last 7 days / This month). No "Custom"
  /// button — the From/To fields already sitting in this row are the custom
  /// picker, so a third way to say "custom" would just be a dead click.
  static const List<PosReceiptFilterOption<PosOrderDateRangePreset>>
      dateRangePresets = [
    PosReceiptFilterOption('Yesterday', PosOrderDateRangePreset.yesterday),
    PosReceiptFilterOption('Last 7 days', PosOrderDateRangePreset.last7Days),
    PosReceiptFilterOption('This month', PosOrderDateRangePreset.thisMonth),
  ];
}

/// A quick preset for the Orders date range bar. `custom` is not a computed
/// range — it is what the preset resets to the moment the operator edits the
/// From/To fields by hand, so the dropdown never shows a stale preset label
/// next to a window that preset no longer describes.
enum PosOrderDateRangePreset { custom, yesterday, last7Days, thisMonth }

/// Resolves a [PosOrderDateRangePreset] to the From/To/NOW state
/// [PosOrdersProvider.setDatePreset] applies.
///
/// Yesterday is the only preset with a fixed end — Last 7 days and This month
/// leave `to` unset and turn NOW mode on instead, the same way the existing
/// NOW pill works, so a terminal left open through service keeps showing
/// orders placed after the preset was picked.
extension PosOrderDateRangePresetQuery on PosOrderDateRangePreset {
  static DateTime get _today {
    final DateTime now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime? get from {
    switch (this) {
      case PosOrderDateRangePreset.custom:
        return null;
      case PosOrderDateRangePreset.yesterday:
        return _today.subtract(const Duration(days: 1));
      case PosOrderDateRangePreset.last7Days:
        return _today.subtract(const Duration(days: 6));
      case PosOrderDateRangePreset.thisMonth:
        return DateTime(_today.year, _today.month, 1);
    }
  }

  DateTime? get to {
    if (this != PosOrderDateRangePreset.yesterday) return null;
    final DateTime yesterday = _today.subtract(const Duration(days: 1));
    return DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59);
  }

  bool get liveNow =>
      this == PosOrderDateRangePreset.last7Days ||
      this == PosOrderDateRangePreset.thisMonth;
}
