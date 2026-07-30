import 'package:flutter/material.dart';
import 'package:acafe_customer/common/responsive/kiosk_responsive.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_manager_provider.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_checkout_widgets.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_bottom_sheet.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_ui.dart';
import 'package:acafe_customer/helper/price_converter_helper.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:provider/provider.dart';

double? _money(dynamic v) => (v as num?)?.toDouble();

/// Live daily totals for the device's branch -- doubles as both "Daily Sales
/// Summary" and "End-of-Day Report" (same underlying data either way), with
/// a "Do Z Report" action that performs the actual close.
class KioskManagerSalesOverviewScreen extends StatefulWidget {
  const KioskManagerSalesOverviewScreen({super.key});

  @override
  State<KioskManagerSalesOverviewScreen> createState() => _KioskManagerSalesOverviewScreenState();
}

class _KioskManagerSalesOverviewScreenState extends State<KioskManagerSalesOverviewScreen> {
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
            final double s = KioskResponsive.scale(constraints.maxWidth);
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
                          return const Center(child: CircularProgressIndicator());
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

class _SalesOverviewBody extends StatelessWidget {
  final double s;
  final Map<String, dynamic> data;
  const _SalesOverviewBody({required this.s, required this.data});

  @override
  Widget build(BuildContext context) {
    final bool closed = data['closed'] == true;
    final sales = Map<String, dynamic>.from(data['sales'] ?? {});
    final transactions = Map<String, dynamic>.from(data['transactions'] ?? {});
    final discounts = Map<String, dynamic>.from(data['discounts'] ?? {});
    final voided = Map<String, dynamic>.from(data['voided'] ?? {});
    final paymentMethods = Map<String, dynamic>.from(data['payment_methods'] ?? {});
    final channelBreakdown = Map<String, dynamic>.from(data['channel_breakdown'] ?? {});
    final List channelBuckets = channelBreakdown['buckets'] ?? [];
    final List payments = paymentMethods['methods'] ?? [];

    return ListView(
      padding: EdgeInsets.fromLTRB(132 * s, 0, 132 * s, 60 * s),
      children: [
        Text('${data['report_date'] ?? ''}',
            style: loewBold.copyWith(fontSize: 44 * s, color: Colors.black54)),
        SizedBox(height: 20 * s),
        if (closed)
          _ClosedBadge(s: s, data: data)
        else
          _OpenBadge(s: s),
        SizedBox(height: 48 * s),
        _SectionCard(s: s, title: 'Sales', children: [
          _StatRow(s: s, label: 'Gross sales', value: PriceConverterHelper.convertPrice(_money(sales['gross_sales']))),
          _StatRow(s: s, label: 'Net sales', value: PriceConverterHelper.convertPrice(_money(sales['net_sales']))),
          _StatRow(s: s, label: 'Total tax', value: PriceConverterHelper.convertPrice(_money(sales['total_tax']))),
          _StatRow(s: s, label: 'Total discount', value: PriceConverterHelper.convertPrice(_money(sales['total_discount']))),
          _StatRow(s: s, label: 'Average order value', value: PriceConverterHelper.convertPrice(_money(sales['average_order_value']))),
        ]),
        SizedBox(height: 32 * s),
        _SectionCard(s: s, title: 'Transactions', children: [
          _StatRow(s: s, label: 'Total orders', value: '${transactions['order_count'] ?? 0}'),
          _StatRow(s: s, label: 'Completed', value: '${transactions['completed_order_count'] ?? 0}'),
          _StatRow(s: s, label: 'Canceled/voided', value: '${transactions['canceled_order_count'] ?? 0}'),
          _StatRow(s: s, label: 'Voided value', value: PriceConverterHelper.convertPrice(_money(voided['value']))),
        ]),
        SizedBox(height: 32 * s),
        _SectionCard(s: s, title: 'Discounts', children: [
          _StatRow(s: s, label: 'Coupon', value: PriceConverterHelper.convertPrice(_money(discounts['coupon']))),
          _StatRow(s: s, label: 'Manual', value: PriceConverterHelper.convertPrice(_money(discounts['manual']))),
          _StatRow(s: s, label: 'Referral', value: PriceConverterHelper.convertPrice(_money(discounts['referral']))),
          _StatRow(s: s, label: 'Item level', value: PriceConverterHelper.convertPrice(_money(discounts['item_level']))),
        ]),
        SizedBox(height: 32 * s),
        _SectionCard(s: s, title: 'Channel breakdown', children: [
          for (final bucket in channelBuckets)
            _StatRow(
              s: s,
              label: '${bucket['channel']} (${bucket['order_count']})',
              value: '${PriceConverterHelper.convertPrice(_money(bucket['amount']))} · ${bucket['percentage']}%',
            ),
        ]),
        SizedBox(height: 32 * s),
        _SectionCard(s: s, title: 'Payment methods', children: [
          if (payments.isEmpty)
            _StatRow(s: s, label: 'No payments recorded', value: ''),
          for (final method in payments)
            _StatRow(
              s: s,
              label: '${method['method']} (${method['order_count']})',
              value: PriceConverterHelper.convertPrice(_money(method['amount'])),
            ),
        ]),
        if (closed) ...[
          SizedBox(height: 32 * s),
          _CashReconciliationCard(s: s, data: Map<String, dynamic>.from(data['cash_reconciliation'] ?? {})),
        ],
        SizedBox(height: 60 * s),
        if (!closed)
          KioskPrimaryButton(
            // KioskPrimaryButton/KioskCheckoutField are authored against the
            // narrow 1000px FORM artboard (kioskFormScale), not this page's
            // 2572px full-page artboard (KioskResponsive.scale) -- reusing
            // the page's `s` here made the label shrink to ~8px and look
            // like unreadable mush at normal browser widths.
            s: kioskFormScale(MediaQuery.sizeOf(context).width),
            label: 'CLOSE DAY',
            onTap: () => _openCloseRegisterSheet(context, data),
          ),
      ],
    );
  }

  void _openCloseRegisterSheet(BuildContext context, Map<String, dynamic> data) {
    showKioskBottomSheet(
      context,
      heightFactor: 0.75,
      maxWidth: 900,
      child: _CloseRegisterSheet(
        s: kioskFormScale(MediaQuery.sizeOf(context).width),
        reportDate: '${data['report_date']}',
        previousClosingCash: (data['previous_closing_cash'] as num?)?.toDouble(),
      ),
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
          style: loewBold.copyWith(fontSize: 32 * s, color: const Color(0xFF2E7D32))),
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
        style: loewBold.copyWith(fontSize: 32 * s, color: const Color(0xFF8A2E2E)),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final double s;
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.s, required this.title, required this.children});

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
              style: loewExtraBold.copyWith(fontSize: 36 * s, color: Colors.black)),
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
  const _StatRow({required this.s, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12 * s),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: loewRegular.copyWith(fontSize: 34 * s, color: Colors.black87)),
          ),
          Text(value, style: loewBold.copyWith(fontSize: 34 * s, color: Colors.black)),
        ],
      ),
    );
  }
}

class _CashReconciliationCard extends StatelessWidget {
  final double s;
  final Map<String, dynamic> data;
  const _CashReconciliationCard({required this.s, required this.data});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(s: s, title: 'Cash reconciliation', children: [
      _StatRow(s: s, label: 'Opening cash', value: PriceConverterHelper.convertPrice(_money(data['opening_cash']))),
      _StatRow(s: s, label: 'Expected cash', value: PriceConverterHelper.convertPrice(_money(data['expected_cash']))),
      _StatRow(s: s, label: 'Closing cash counted', value: PriceConverterHelper.convertPrice(_money(data['closing_cash_counted']))),
      _StatRow(s: s, label: 'Variance', value: PriceConverterHelper.convertPrice(_money(data['cash_variance']))),
    ]);
  }
}

/// "Do Z Report" form: opening cash / closing cash counted / optional
/// comment, then closes the day via KioskManagerProvider.closeZReport.
class _CloseRegisterSheet extends StatefulWidget {
  final double s;
  final String reportDate;
  final double? previousClosingCash;
  const _CloseRegisterSheet({required this.s, required this.reportDate, this.previousClosingCash});

  @override
  State<_CloseRegisterSheet> createState() => _CloseRegisterSheetState();
}

class _CloseRegisterSheetState extends State<_CloseRegisterSheet> {
  late final TextEditingController _openingController;
  final TextEditingController _closingController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _openingController = TextEditingController(
      text: widget.previousClosingCash != null ? widget.previousClosingCash!.toStringAsFixed(2) : '',
    );
  }

  @override
  void dispose() {
    _openingController.dispose();
    _closingController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit(KioskManagerProvider provider) async {
    final opening = double.tryParse(_openingController.text.trim());
    final closing = double.tryParse(_closingController.text.trim());
    if (opening == null || closing == null) {
      setState(() => _error = 'Enter valid amounts for opening and closing cash');
      return;
    }
    setState(() => _error = null);

    final success = await provider.closeZReport(
      reportDate: widget.reportDate,
      openingCash: opening,
      closingCashCounted: closing,
      comment: _commentController.text.trim().isEmpty ? null : _commentController.text.trim(),
    );

    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final double s = widget.s;
    return Consumer<KioskManagerProvider>(
      builder: (context, provider, _) {
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 56 * s, vertical: 48 * s),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('CLOSE DAY',
                  textAlign: TextAlign.center,
                  style: loewExtraBold.copyWith(fontSize: 60 * s, color: Colors.black)),
              SizedBox(height: 36 * s),
              KioskCheckoutField(
                s: s,
                label: 'Opening cash',
                hint: '0.00',
                controller: _openingController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              SizedBox(height: 24 * s),
              KioskCheckoutField(
                s: s,
                label: 'Closing cash counted',
                hint: '0.00',
                controller: _closingController,
                hasError: _error != null,
                errorText: _error,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              SizedBox(height: 24 * s),
              KioskCheckoutField(
                s: s,
                label: 'Comment (optional)',
                hint: 'Notes for this close',
                controller: _commentController,
              ),
              SizedBox(height: 40 * s),
              KioskPrimaryButton(
                s: s,
                label: 'CLOSE REGISTER',
                loading: provider.closingRegister,
                onTap: () => _submit(provider),
              ),
            ],
          ),
        );
      },
    );
  }
}
