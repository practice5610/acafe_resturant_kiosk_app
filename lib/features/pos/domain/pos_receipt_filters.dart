import 'package:intl/intl.dart';

/// One entry in a Receipts filter dropdown.
class PosReceiptFilterOption<T> {
  final String label;
  final T value;

  const PosReceiptFilterOption(this.label, this.value);
}

/// The four filter pills above the Receipts table (Figma 1641:3238).
///
/// Each pill shows its own label until something is picked, then the picked
/// option's label — which is why every set opens with an "all" entry: it is
/// both the default and the way back out of a filter.
class PosReceiptFilters {
  PosReceiptFilters._();

  /// Status maps to `order_status`, except the two payment states, which the
  /// endpoint routes to `payment_status` instead. One control, two columns.
  static const List<PosReceiptFilterOption<String?>> statuses = [
    PosReceiptFilterOption('All statuses', null),
    PosReceiptFilterOption('Paid', 'paid'),
    PosReceiptFilterOption('Unpaid', 'unpaid'),
    PosReceiptFilterOption('New', 'new'),
    PosReceiptFilterOption('Preparing', 'preparing'),
    PosReceiptFilterOption('To collect', 'item_to_collect'),
    PosReceiptFilterOption('Delivered', 'delivered'),
    PosReceiptFilterOption('Canceled', 'canceled'),
  ];

  /// "Category" is the sales channel — the one value a receipt actually
  /// carries. See Phase 1 Q1: product category is multi-valued per receipt and
  /// would need a join per row.
  static const List<PosReceiptFilterOption<String?>> channels = [
    PosReceiptFilterOption('All channels', null),
    PosReceiptFilterOption('Counter POS', 'counter_pos'),
    PosReceiptFilterOption('Kiosk', 'kiosk'),
    PosReceiptFilterOption('Web app', 'web_app'),
  ];

  static const List<PosReceiptFilterOption<PosReceiptAmountBand?>> amounts = [
    PosReceiptFilterOption('Any amount', null),
    PosReceiptFilterOption('Under € 10', PosReceiptAmountBand(null, 10)),
    PosReceiptFilterOption('€ 10 – € 25', PosReceiptAmountBand(10, 25)),
    PosReceiptFilterOption('€ 25 – € 50', PosReceiptAmountBand(25, 50)),
    PosReceiptFilterOption('Over € 50', PosReceiptAmountBand(50, null)),
  ];

  static const List<PosReceiptFilterOption<PosReceiptDateRange>> dates = [
    PosReceiptFilterOption('Today', PosReceiptDateRange.today),
    PosReceiptFilterOption('Yesterday', PosReceiptDateRange.yesterday),
    PosReceiptFilterOption('Last 7 days', PosReceiptDateRange.last7Days),
    PosReceiptFilterOption('This month', PosReceiptDateRange.thisMonth),
  ];
}

class PosReceiptAmountBand {
  final double? min;
  final double? max;

  const PosReceiptAmountBand(this.min, this.max);
}

enum PosReceiptDateRange { today, yesterday, last7Days, thisMonth }

/// Resolved query window for a [PosReceiptDateRange].
///
/// Today stays a single `report_date` rather than a one-day range, so the
/// default request is byte-for-byte the one the endpoint already served before
/// these filters existed.
extension PosReceiptDateRangeQuery on PosReceiptDateRange {
  static final DateFormat _wire = DateFormat('yyyy-MM-dd');

  DateTime get _today => DateUtilsToday.value;

  String? get reportDate =>
      this == PosReceiptDateRange.today ? _wire.format(_today) : null;

  String? get dateFrom {
    switch (this) {
      case PosReceiptDateRange.today:
        return null;
      case PosReceiptDateRange.yesterday:
        return _wire.format(_today.subtract(const Duration(days: 1)));
      case PosReceiptDateRange.last7Days:
        return _wire.format(_today.subtract(const Duration(days: 6)));
      case PosReceiptDateRange.thisMonth:
        return _wire.format(DateTime(_today.year, _today.month, 1));
    }
  }

  String? get dateTo {
    switch (this) {
      case PosReceiptDateRange.today:
        return null;
      case PosReceiptDateRange.yesterday:
        return _wire.format(_today.subtract(const Duration(days: 1)));
      case PosReceiptDateRange.last7Days:
      case PosReceiptDateRange.thisMonth:
        return _wire.format(_today);
    }
  }

  /// Used in the export filename so a downloaded file says what it covers.
  String get fileLabel {
    switch (this) {
      case PosReceiptDateRange.today:
        return _wire.format(_today);
      case PosReceiptDateRange.yesterday:
        return _wire.format(_today.subtract(const Duration(days: 1)));
      case PosReceiptDateRange.last7Days:
        return '${dateFrom}_to_$dateTo';
      case PosReceiptDateRange.thisMonth:
        return DateFormat('yyyy-MM').format(_today);
    }
  }
}

/// Midnight today, read once per call rather than held, so a terminal left on
/// overnight rolls to the new day without a restart.
class DateUtilsToday {
  DateUtilsToday._();

  static DateTime get value {
    final DateTime now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
}
