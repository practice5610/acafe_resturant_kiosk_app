import 'package:flutter/material.dart';
import 'package:acafe_customer/common/responsive/kiosk_layout.dart';
import 'package:acafe_customer/common/responsive/kiosk_responsive.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_manager_provider.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_checkout_widgets.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_ui.dart';
import 'package:acafe_customer/helper/price_converter_helper.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:provider/provider.dart';

double? _money(dynamic v) => (v as num?)?.toDouble();

/// Laravel serializes an empty PHP associative array as a JSON `[]`, not
/// `{}` -- indistinguishable from a genuinely empty list. `countBy()` in
/// ZReportService hits exactly this on a day with zero orders (e.g.
/// `by_order_type`), so `Map<String, dynamic>.from(x)` would otherwise throw
/// "List<dynamic> is not a subtype of Map" the first time a report has no
/// transactions yet. Treat anything that isn't already a Map as empty.
Map<String, dynamic> _asMap(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

/// "dine_in" -> "Dine-in", "take_away" -> "Takeaway", "pos" -> "Takeaway".
String _titleCase(String raw) {
  switch (raw.toLowerCase()) {
    case 'dine_in':
      return 'Dine-in';
    case 'take_away':
    case 'pos':
      return 'Takeaway';
    default:
      if (raw.isEmpty) return raw;
      return raw
          .split('_')
          .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
          .join(' ');
  }
}

/// "2026-07-30 10:15:00" -> "10:15".
String _timeOfDay(String? iso) {
  if (iso == null || iso.length < 16) return '--:--';
  return iso.substring(11, 16);
}

/// Live daily totals for the device's branch -- doubles as both "Daily Sales
/// Summary" and "End-of-Day Report" (same underlying data either way), with
/// a "Close Day" action (mirrors the admin/branch Z Report screen) that
/// performs the actual close, inline on this same page.
class KioskManagerSalesOverviewScreen extends StatefulWidget {
  const KioskManagerSalesOverviewScreen({super.key});

  @override
  State<KioskManagerSalesOverviewScreen> createState() =>
      _KioskManagerSalesOverviewScreenState();
}

class _KioskManagerSalesOverviewScreenState
    extends State<KioskManagerSalesOverviewScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<KioskManagerProvider>().loadSalesOverview();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KioskUI.pageBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double s = KioskLayout.scaleOf(context, constraints);
            return KioskCenteredContent(
              child: Column(
                children: [
                  KioskHeaderBar(
                    s: s,
                    title: 'SALES OVERVIEW',
                    fallback: RouterHelper.getKioskManagerDashboardRoute,
                  ),
                  Expanded(
                    child: Consumer<KioskManagerProvider>(
                      builder: (context, provider, _) {
                        final data = provider.salesData;
                        if (provider.salesLoading && data == null) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        if (data == null) {
                          return Center(
                            child: Text('Unable to load sales data',
                                style: loewMedium.copyWith(fontSize: 44 * s)),
                          );
                        }
                        return _SalesOverviewBody(s: s, data: data);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SalesOverviewBody extends StatefulWidget {
  final double s;
  final Map<String, dynamic> data;
  const _SalesOverviewBody({required this.s, required this.data});

  @override
  State<_SalesOverviewBody> createState() => _SalesOverviewBodyState();
}

class _SalesOverviewBodyState extends State<_SalesOverviewBody> {
  late final TextEditingController _openingController;
  final TextEditingController _closingController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    final previous = (widget.data['previous_closing_cash'] as num?)?.toDouble();
    _openingController = TextEditingController(
        text: previous != null ? previous.toStringAsFixed(2) : '');
    _openingController.addListener(_onCashChanged);
    _closingController.addListener(_onCashChanged);
  }

  @override
  void dispose() {
    _openingController.removeListener(_onCashChanged);
    _closingController.removeListener(_onCashChanged);
    _openingController.dispose();
    _closingController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _onCashChanged() => setState(() {});

  double get _expectedCashSales =>
      ((widget.data['cash'] as Map?)?['expected_cash_sales'] as num?)
          ?.toDouble() ??
      0;
  double get _openingCash =>
      double.tryParse(_openingController.text.trim()) ?? 0;
  double get _closingCash =>
      double.tryParse(_closingController.text.trim()) ?? 0;
  double get _expectedCash => _openingCash + _expectedCashSales;
  double get _variance =>
      double.parse((_closingCash - _expectedCash).toStringAsFixed(2));

  Future<void> _closeDay(KioskManagerProvider provider) async {
    final opening = double.tryParse(_openingController.text.trim());
    final closing = double.tryParse(_closingController.text.trim());
    if (opening == null || closing == null) {
      setState(
          () => _error = 'Enter valid amounts for opening and closing cash');
      return;
    }
    setState(() => _error = null);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _CloseDayConfirmDialog(s: widget.s),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    await provider.closeZReport(
      reportDate: '${widget.data['report_date']}',
      openingCash: opening,
      closingCashCounted: closing,
      comment: _commentController.text.trim().isEmpty
          ? null
          : _commentController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double s = widget.s;
    final data = widget.data;
    final provider = context.watch<KioskManagerProvider>();

    final bool closed = data['closed'] == true;
    final sales = _asMap(data['sales']);
    final tradingWindow = _asMap(sales['trading_window']);
    final transactions = _asMap(data['transactions']);
    final byOrderType = _asMap(transactions['by_order_type']);
    final discounts = _asMap(data['discounts']);
    final voided = _asMap(data['voided']);
    final paymentMethods = _asMap(data['payment_methods']);
    final List payments = paymentMethods['methods'] ?? [];
    final channelBreakdown = _asMap(data['channel_breakdown']);
    final List channelBuckets = channelBreakdown['buckets'] ?? [];
    final double? approxRefundValue = _money(voided['approx_refund_value']);

    return ListView(
      padding: EdgeInsets.fromLTRB(132 * s, 0, 132 * s, 60 * s),
      children: [
        Text('${data['report_date'] ?? ''}',
            style: loewBold.copyWith(fontSize: 44 * s, color: Colors.black54)),
        SizedBox(height: 20 * s),
        if (closed) _ClosedBadge(s: s, data: data) else _OpenBadge(s: s),
        SizedBox(height: 48 * s),
        _SectionCard(s: s, title: 'Sales', children: [
          _StatRow(
              s: s,
              label: 'Gross sales',
              value: PriceConverterHelper.convertPrice(
                  _money(sales['gross_sales']))),
          _StatRow(
              s: s,
              label: 'Net sales',
              value: PriceConverterHelper.convertPrice(
                  _money(sales['net_sales']))),
          _StatRow(
              s: s,
              label: 'Total tax',
              value: PriceConverterHelper.convertPrice(
                  _money(sales['total_tax']))),
          _StatRow(
              s: s,
              label: 'Total discount',
              value: PriceConverterHelper.convertPrice(
                  _money(sales['total_discount']))),
          _StatRow(
              s: s,
              label: 'Average order value',
              value: PriceConverterHelper.convertPrice(
                  _money(sales['average_order_value']))),
          _StatRow(
            s: s,
            label: 'Trading window',
            value: tradingWindow['first_order_at'] != null
                ? '${_timeOfDay(tradingWindow['first_order_at'])} – ${_timeOfDay(tradingWindow['last_order_at'])}'
                : '—',
          ),
        ]),
        SizedBox(height: 32 * s),
        _SectionCard(s: s, title: 'Transactions', children: [
          _StatRow(
              s: s,
              label: 'Total orders',
              value: '${transactions['order_count'] ?? 0}'),
          _StatRow(
              s: s,
              label: 'Completed',
              value: '${transactions['completed_order_count'] ?? 0}'),
          _StatRow(
              s: s,
              label: 'Canceled/voided',
              value: '${transactions['canceled_order_count'] ?? 0}'),
          if (byOrderType.isNotEmpty) ...[
            SizedBox(height: 8 * s),
            for (final entry in byOrderType.entries)
              _StatRow(
                  s: s, label: _titleCase(entry.key), value: '${entry.value}'),
          ],
        ]),
        SizedBox(height: 32 * s),
        _SectionCard(s: s, title: 'Cancelled / voided', children: [
          _StatRow(s: s, label: 'Count', value: '${voided['count'] ?? 0}'),
          _StatRow(
              s: s,
              label: 'Value',
              value:
                  PriceConverterHelper.convertPrice(_money(voided['value']))),
          if (approxRefundValue != null && approxRefundValue > 0)
            Padding(
              padding: EdgeInsets.only(top: 8 * s),
              child: Text(
                'Approx. refund of previously paid orders: ${PriceConverterHelper.convertPrice(approxRefundValue)}',
                style: loewRegular.copyWith(
                    fontSize: 26 * s, color: Colors.black45),
              ),
            ),
        ]),
        SizedBox(height: 32 * s),
        _SectionCard(s: s, title: 'Discounts', children: [
          _StatRow(
              s: s,
              label: 'Coupon',
              value: PriceConverterHelper.convertPrice(
                  _money(discounts['coupon']))),
          _StatRow(
              s: s,
              label: 'Manual',
              value: PriceConverterHelper.convertPrice(
                  _money(discounts['manual']))),
          _StatRow(
              s: s,
              label: 'Referral',
              value: PriceConverterHelper.convertPrice(
                  _money(discounts['referral']))),
          _StatRow(
              s: s,
              label: 'Item level',
              value: PriceConverterHelper.convertPrice(
                  _money(discounts['item_level']))),
          _StatRow(
              s: s,
              label: 'Total',
              value:
                  PriceConverterHelper.convertPrice(_money(discounts['total'])),
              bold: true),
        ]),
        SizedBox(height: 32 * s),
        _SectionCard(s: s, title: 'Order source', children: [
          if (channelBuckets.isEmpty)
            _StatRow(s: s, label: 'No orders recorded', value: ''),
          for (final bucket in channelBuckets)
            _StatRow(
              s: s,
              label: '${bucket['channel']} (${bucket['order_count']})',
              value:
                  PriceConverterHelper.convertPrice(_money(bucket['amount'])),
            ),
        ]),
        SizedBox(height: 32 * s),
        _SectionCard(s: s, title: 'Payment breakdown', children: [
          if (payments.isEmpty)
            _StatRow(s: s, label: 'No payments recorded', value: ''),
          for (final method in payments)
            _StatRow(
              s: s,
              label: '${method['method']} (${method['order_count']})',
              value:
                  PriceConverterHelper.convertPrice(_money(method['amount'])),
            ),
        ]),
        SizedBox(height: 32 * s),
        if (closed)
          _CashReconciliationCard(
              s: s,
              data: _asMap(data['cash_reconciliation']),
              comment: data['closing_comment'] as String?)
        else
          _CloseDaySection(
            s: s,
            openingController: _openingController,
            closingController: _closingController,
            commentController: _commentController,
            expectedCash: _expectedCash,
            variance: _variance,
            error: _error,
            loading: provider.closingRegister,
            onCloseDay: () => _closeDay(provider),
          ),
      ],
    );
  }
}

class _OpenBadge extends StatelessWidget {
  final double s;
  const _OpenBadge({required this.s});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 28 * s, vertical: 14 * s),
      decoration: BoxDecoration(
        color: const Color(0xFFE9F5E9),
        borderRadius: BorderRadius.circular(40 * s),
      ),
      child: Text('LIVE · REGISTER OPEN',
          style: loewBold.copyWith(
              fontSize: 32 * s, color: const Color(0xFF2E7D32))),
    );
  }
}

class _ClosedBadge extends StatelessWidget {
  final double s;
  final Map<String, dynamic> data;
  const _ClosedBadge({required this.s, required this.data});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 28 * s, vertical: 14 * s),
      decoration: BoxDecoration(
        color: const Color(0xFFF5EAEA),
        borderRadius: BorderRadius.circular(40 * s),
      ),
      child: Text(
        'CLOSED · Z#${data['z_number'] ?? '-'} · ${data['closed_by'] ?? ''}',
        style:
            loewBold.copyWith(fontSize: 32 * s, color: const Color(0xFF8A2E2E)),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final double s;
  final String title;
  final List<Widget> children;
  const _SectionCard(
      {required this.s, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(40 * s),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24 * s),
        border: Border.all(color: Colors.black12, width: 2 * s),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(),
              style: loewExtraBold.copyWith(
                  fontSize: 36 * s, color: Colors.black)),
          SizedBox(height: 24 * s),
          ...children,
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final double s;
  final String label;
  final String value;
  final bool bold;
  const _StatRow(
      {required this.s,
      required this.label,
      required this.value,
      this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12 * s),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: (bold ? loewBold : loewRegular)
                    .copyWith(fontSize: 34 * s, color: Colors.black87)),
          ),
          Text(value,
              style: loewBold.copyWith(fontSize: 34 * s, color: Colors.black)),
        ],
      ),
    );
  }
}

class _CashReconciliationCard extends StatelessWidget {
  final double s;
  final Map<String, dynamic> data;
  final String? comment;
  const _CashReconciliationCard(
      {required this.s, required this.data, this.comment});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(s: s, title: 'Cash reconciliation', children: [
      _StatRow(
          s: s,
          label: 'Opening cash',
          value:
              PriceConverterHelper.convertPrice(_money(data['opening_cash']))),
      _StatRow(
          s: s,
          label: 'Expected cash',
          value:
              PriceConverterHelper.convertPrice(_money(data['expected_cash']))),
      _StatRow(
          s: s,
          label: 'Closing cash counted',
          value: PriceConverterHelper.convertPrice(
              _money(data['closing_cash_counted']))),
      _StatRow(
          s: s,
          label: 'Variance',
          value:
              PriceConverterHelper.convertPrice(_money(data['cash_variance']))),
      if (comment != null && comment!.trim().isNotEmpty) ...[
        SizedBox(height: 8 * s),
        Text('Comment',
            style:
                loewRegular.copyWith(fontSize: 28 * s, color: Colors.black45)),
        SizedBox(height: 4 * s),
        Text(comment!,
            style:
                loewRegular.copyWith(fontSize: 32 * s, color: Colors.black87)),
      ],
    ]);
  }
}

/// Inline "Close Day" form -- opening cash / closing cash counted / optional
/// comment plus the CLOSE DAY action, merged directly into the Sales
/// Overview page (no separate popup/sheet).
class _CloseDaySection extends StatelessWidget {
  final double s;
  final TextEditingController openingController;
  final TextEditingController closingController;
  final TextEditingController commentController;
  final double expectedCash;
  final double variance;
  final String? error;
  final bool loading;
  final VoidCallback onCloseDay;

  const _CloseDaySection({
    required this.s,
    required this.openingController,
    required this.closingController,
    required this.commentController,
    required this.expectedCash,
    required this.variance,
    required this.error,
    required this.loading,
    required this.onCloseDay,
  });

  Color _varianceColor() {
    if (variance > 0) return const Color(0xFF2E7D32);
    if (variance < 0) return const Color(0xFF8A2E2E);
    return Colors.black;
  }

  String _varianceText() {
    final sign = variance > 0 ? '+' : (variance < 0 ? '-' : '');
    return '$sign${PriceConverterHelper.convertPrice(variance.abs())}';
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(s: s, title: 'Close day', children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _CashInputField(
              s: s,
              label: 'Opening cash',
              controller: openingController,
            ),
          ),
          SizedBox(width: 32 * s),
          Expanded(
            child: _CashReadout(
                s: s,
                label: 'Expected cash',
                value: PriceConverterHelper.convertPrice(expectedCash)),
          ),
        ],
      ),
      SizedBox(height: 24 * s),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _CashInputField(
              s: s,
              label: 'Closing cash counted',
              controller: closingController,
              hasError: error != null,
            ),
          ),
          SizedBox(width: 32 * s),
          Expanded(
            child: _CashReadout(
                s: s,
                label: 'Variance',
                value: _varianceText(),
                color: _varianceColor()),
          ),
        ],
      ),
      if (error != null) ...[
        SizedBox(height: 12 * s),
        Text(error!,
            style: loewRegular.copyWith(
                fontSize: 28 * s, color: const Color(0xFFEF4444))),
      ],
      SizedBox(height: 24 * s),
      _CashInputField(
        s: s,
        label: 'Comment (optional)',
        controller: commentController,
        isNumeric: false,
      ),
      SizedBox(height: 36 * s),
      KioskPrimaryButton(
        s: s,
        label: 'CLOSE DAY',
        icon: Icons.lock_outline,
        loading: loading,
        onTap: onCloseDay,
      ),
      SizedBox(height: 16 * s),
      Text(
        'Closing a day is permanent and cannot be undone.',
        style: loewRegular.copyWith(fontSize: 26 * s, color: Colors.black45),
      ),
    ]);
  }
}

class _CashInputField extends StatelessWidget {
  final double s;
  final String label;
  final TextEditingController controller;
  final bool isNumeric;
  final bool hasError;
  const _CashInputField({
    required this.s,
    required this.label,
    required this.controller,
    this.isNumeric = true,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
                loewRegular.copyWith(fontSize: 28 * s, color: Colors.black54)),
        SizedBox(height: 10 * s),
        Container(
          height: 84 * s,
          padding: EdgeInsets.symmetric(horizontal: 24 * s),
          decoration: BoxDecoration(
            color: const Color(0xFFFBF8EF),
            borderRadius: BorderRadius.circular(16 * s),
            border: Border.all(
              color:
                  hasError ? const Color(0xFFEF4444) : const Color(0xFFB9B5A6),
              width: 2 * s,
            ),
          ),
          alignment: Alignment.centerLeft,
          child: TextField(
            controller: controller,
            keyboardType: isNumeric
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
            style: loewRegular.copyWith(fontSize: 32 * s, color: Colors.black),
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              hintText: isNumeric ? '0.00' : 'Notes for this close',
              hintStyle: loewRegular.copyWith(
                  fontSize: 32 * s, color: const Color(0xFFB9B5A6)),
            ),
          ),
        ),
      ],
    );
  }
}

class _CashReadout extends StatelessWidget {
  final double s;
  final String label;
  final String value;
  final Color? color;
  const _CashReadout(
      {required this.s, required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
                loewRegular.copyWith(fontSize: 28 * s, color: Colors.black54)),
        SizedBox(height: 10 * s),
        Container(
          height: 84 * s,
          alignment: Alignment.centerLeft,
          child: Text(value,
              style: loewBold.copyWith(
                  fontSize: 34 * s, color: color ?? Colors.black)),
        ),
      ],
    );
  }
}

class _CloseDayConfirmDialog extends StatelessWidget {
  final double s;
  const _CloseDayConfirmDialog({required this.s});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lock_outline, color: Colors.black, size: 28),
                const SizedBox(width: 12),
                Text('Close day?',
                    style: loewExtraBold.copyWith(
                        fontSize: 32, color: Colors.black)),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'This finalizes today\'s Z Report and sends it to the admin. It is permanent and cannot be undone.',
              style: loewRegular.copyWith(fontSize: 22, color: Colors.black87),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      side: const BorderSide(color: Colors.black26),
                    ),
                    child: Text('CANCEL',
                        style: loewBold.copyWith(
                            fontSize: 20, color: Colors.black87)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text('CLOSE DAY',
                        style: loewBold.copyWith(
                            fontSize: 20, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
