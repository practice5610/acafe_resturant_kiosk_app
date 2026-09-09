/// Typed view of the `kiosk-manager/sales-overview` payload for the POS Report
/// Overview screen (Figma **1641:5518**).
///
/// The endpoint returns one of two shapes — a live `preview()` for an open day
/// or a stored snapshot for a closed one — and they are deliberately identical,
/// so a single model covers both. What differs is the `recorded` flag on each
/// section: a day closed before the Report Overview columns existed reports
/// `recorded: false`, and the UI must say so rather than draw an empty chart
/// that looks like a day with no sales.
///
/// Every number is read through [_d] / [_i]. That is not defensive noise: PHP's
/// `json_encode` emits `50.0` as `50`, so a straight `as double` cast throws on
/// perfectly valid payloads — and does so only for round amounts, which is the
/// worst possible way to find out.
library;

double _d(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

int _i(dynamic v) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

Map<String, dynamic> _map(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : const <String, dynamic>{};

List<Map<String, dynamic>> _rows(dynamic v) => v is List
    ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : const <Map<String, dynamic>>[];

/// Whether a section's absence means "nothing happened" or "we don't know".
///
/// Three states have to stay distinguishable, because two of them look
/// identical once rendered as `0`:
///
///  * present with `recorded: true`  → real data, possibly a real zero
///  * present with `recorded: false` → the day was closed before this section
///    was captured
///  * **key missing entirely**       → an older backend than this build. Also
///    unknown, and treated as such.
///
/// That last case is the trap. A missing key would fall through to an empty map
/// and read as "recorded, and everything is zero" — a confident, wrong answer
/// during a deploy where the Flutter build is ahead of the API.
bool _sectionRecorded(Map<String, dynamic> raw, String key) {
  final Object? section = raw[key];
  if (section is! Map) return false;
  return section['recorded'] != false;
}

class PosReportData {
  final Map<String, dynamic> raw;

  const PosReportData(this.raw);

  static PosReportData? from(Map<String, dynamic>? json) =>
      json == null ? null : PosReportData(json);

  Map<String, dynamic> get _sales => _map(raw['sales']);
  Map<String, dynamic> get _transactions => _map(raw['transactions']);

  /// The calendar day this payload is actually for, per the server's own
  /// resolution (the branch's configured business timezone, not whatever
  /// timezone the requesting device's clock happens to be set to). Null only
  /// for a malformed/legacy payload missing the field entirely.
  DateTime? get reportDate {
    final String? raw = this.raw['report_date'] as String?;
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  bool get closed => raw['closed'] == true;
  int? get zNumber => raw['z_number'] == null ? null : _i(raw['z_number']);
  String? get closedBy => raw['closed_by'] as String?;
  bool get hasOrders => raw['has_orders'] == true || orderCount > 0;

  // ── Headline figures ──────────────────────────────────────────────────
  double get netSales => _d(_sales['net_sales']);
  double get totalTax => _d(_sales['total_tax']);

  /// Figma's "Total Revenue" / "Gross Sales" is Net Sales + BTW, which is what
  /// the customer actually paid. The service's own `sales.gross_sales` means
  /// something different (net *before discounts*) and is deliberately not used
  /// here — see the Phase 1 report, Decision 3.
  double get totalRevenue {
    final Map<String, dynamic> reconciliation = _map(raw['reconciliation']);
    if (reconciliation.containsKey('customer_paid')) {
      return _d(reconciliation['customer_paid']);
    }
    // A closed snapshot carries no reconciliation block; the identity still
    // holds from its stored parts.
    return netSales + totalTax;
  }

  double get averageOrderValue => _d(_sales['average_order_value']);
  double get totalTips => _d(_sales['total_tips']);
  int get orderCount => _i(_transactions['order_count']);
  int get completedOrderCount => _i(_transactions['completed_order_count']);
  int get pendingPrepCount => _i(raw['pending_prep_count']);

  double get previousDayRevenue => _d(raw['previous_day_revenue']);

  /// Percentage change against yesterday, or null when yesterday took nothing —
  /// a delta against zero is a division by zero, not "infinite growth".
  double? get revenueDeltaPercent {
    final double previous = previousDayRevenue;
    if (previous <= 0) return null;
    return ((totalRevenue - previous) / previous) * 100;
  }

  // ── VAT / BTW ─────────────────────────────────────────────────────────
  Map<String, dynamic> get _taxSection => _map(raw['tax_breakdown']);
  bool get taxRecorded => _sectionRecorded(raw, 'tax_breakdown');
  List<PosReportTaxRow> get taxRows =>
      _rows(_taxSection['rows']).map(PosReportTaxRow.new).toList();

  // ── Payment methods ───────────────────────────────────────────────────
  Map<String, dynamic> get _paymentSection => _map(raw['payment_methods']);
  List<PosReportPaymentRow> get paymentMethods =>
      _rows(_paymentSection['methods']).map(PosReportPaymentRow.new).toList();
  int get paymentOrderCount =>
      paymentMethods.fold(0, (sum, m) => sum + m.orderCount);

  // ── Top products ──────────────────────────────────────────────────────
  Map<String, dynamic> get _topProductsSection => _map(raw['top_products']);
  bool get topProductsRecorded => _sectionRecorded(raw, 'top_products');
  List<PosReportProductRow> get topProducts =>
      _rows(_topProductsSection['rows']).map(PosReportProductRow.new).toList();

  // ── Hourly sales ──────────────────────────────────────────────────────
  Map<String, dynamic> get _hourlySection => _map(raw['hourly_sales']);
  bool get hourlyRecorded => _sectionRecorded(raw, 'hourly_sales');
  List<PosReportHourRow> get hourlySales =>
      _rows(_hourlySection['hours']).map(PosReportHourRow.new).toList();
  double get hourlyMax => _d(_hourlySection['max_amount']);
  List<int> get peakHours => (_hourlySection['peak_hours'] is List)
      ? (_hourlySection['peak_hours'] as List).map(_i).toList()
      : const <int>[];

  /// `Peak: 12:00-13:00`, or null when the day has no sales to peak at.
  String? get peakLabel {
    if (peakHours.isEmpty || hourlyMax <= 0) return null;
    final int hour = peakHours.first;
    String two(int h) => h.toString().padLeft(2, '0');
    return 'Peak: ${two(hour)}:00-${two((hour + 1) % 24)}:00';
  }

  // ── Category sales ────────────────────────────────────────────────────
  Map<String, dynamic> get _categorySection => _map(raw['category_sales']);
  bool get categoryRecorded => _sectionRecorded(raw, 'category_sales');
  double get categoryTotal => _d(_categorySection['total']);
  List<PosReportCategoryRow> get categorySales =>
      _rows(_categorySection['buckets']).map(PosReportCategoryRow.new).toList();

  // ── Cash drawer (reduced — see Decision 1) ────────────────────────────
  Map<String, dynamic> get _cashSection => _map(raw['cash_drawer']);
  bool get cashRecorded => _sectionRecorded(raw, 'cash_drawer');
  double get cashSales => _d(_cashSection['cash_sales']);
  int get cashSalesCount => _i(_cashSection['cash_sales_count']);
  double get cashRefunds => _d(_cashSection['cash_refunds']);
  int get cashRefundsCount => _i(_cashSection['cash_refunds_count']);

  /// Opening float carried from yesterday's counted close (or 0).
  double get openingFloat => _d(_cashSection['opening_float']);

  /// `Opening float + cash sales − cash refunds` — Close Day Step 1 expected.
  double get expectedInDrawer {
    if (_cashSection.containsKey('expected_cash')) {
      return _d(_cashSection['expected_cash']);
    }
    return openingFloat + cashSales - cashRefunds;
  }

  bool get cashReconciliationAvailable =>
      _cashSection['reconciliation_available'] == true;

  /// What the drawer was actually counted at when this day was closed, or null
  /// when the close skipped counting. Absent rather than zero on purpose: a
  /// zero here would read as "counted, and the drawer was empty".
  double? get countedAmount => _cashSection['counted_amount'] == null
      ? null
      : _d(_cashSection['counted_amount']);

  /// Counted − expected, on a closed day that was counted.
  double? get discrepancyAmount => _cashSection['discrepancy_amount'] == null
      ? null
      : _d(_cashSection['discrepancy_amount']);

  String? get discrepancyNote =>
      _cashSection['discrepancy_note']?.toString();

  // ── Refunds & discounts ───────────────────────────────────────────────
  Map<String, dynamic> get _voided => _map(raw['voided']);
  Map<String, dynamic> get _discounts => _map(raw['discounts']);

  /// Cancelled orders that had already been paid — the closest thing this
  /// system has to a refund, since there is no refund entity. Falls back to the
  /// full cancelled value on snapshots that predate the narrower figure.
  double get refundValue => _voided.containsKey('approx_refund_value')
      ? _d(_voided['approx_refund_value'])
      : _d(_voided['value']);
  int get refundCount => _i(_voided['count']);

  double get staffDiscountValue => _d(_discounts['manual']);
  int get staffDiscountCount => _i(_discounts['manual_count']);
  double get promoDiscountValue => _d(_discounts['coupon']);
  int get promoDiscountCount => _i(_discounts['coupon_count']);
}

class PosReportTaxRow {
  final Map<String, dynamic> _row;
  const PosReportTaxRow(this._row);

  /// Null on the `unclassified` residual row, which exists so the buckets
  /// always sum to the headline tax figure.
  double? get rate => _row['rate'] == null ? null : _d(_row['rate']);
  String get label => (_row['label'] ?? '').toString();
  double get amount => _d(_row['amount']);
}

class PosReportPaymentRow {
  final Map<String, dynamic> _row;
  const PosReportPaymentRow(this._row);

  /// `cash`, `card` or `wallet`. There is no gift-card or mobile-pay tender in
  /// the schema, so there is no "Other" bucket to render — see Decision 5.
  String get key => (_row['method_key'] ?? '').toString();
  String get label => (_row['method'] ?? '').toString();
  int get orderCount => _i(_row['order_count']);
  double get amount => _d(_row['amount']);
}

class PosReportProductRow {
  final Map<String, dynamic> _row;
  const PosReportProductRow(this._row);

  String get name => (_row['name'] ?? '').toString();
  int get quantity => _i(_row['quantity']);
  double get amount => _d(_row['amount']);

  /// Absolute URL, or null for a product deleted since the sale.
  String? get imageUrl {
    final Object? value = _row['image_full_path'];
    if (value is! String || value.isEmpty) return null;
    return value;
  }
}

class PosReportHourRow {
  final Map<String, dynamic> _row;
  const PosReportHourRow(this._row);

  int get hour => _i(_row['hour']);
  String get label => (_row['label'] ?? '').toString();
  double get amount => _d(_row['amount']);
  int get orderCount => _i(_row['order_count']);
}

class PosReportCategoryRow {
  final Map<String, dynamic> _row;
  const PosReportCategoryRow(this._row);

  String get name => (_row['category'] ?? '').toString();
  double get amount => _d(_row['amount']);
  double get percentage => _d(_row['percentage']);
}
