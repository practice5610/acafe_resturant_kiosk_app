import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_report_data.dart';
import 'package:acafe_customer/features/pos/domain/pos_report_spec.dart';
import 'package:acafe_customer/features/pos/widgets/pos_report_widgets.dart';
import 'package:acafe_customer/features/pos/widgets/pos_ui.dart';
import 'package:flutter/material.dart';

/// The `kpi-row` of Figma **1641:5518** — Total Revenue, Total Orders, Average
/// Order Value, Tips Received.
///
/// The four cards are siblings in an IntrinsicHeight row so the Total Revenue
/// card's VAT table sets a common height and the other three do not float at
/// different depths.

/// One KPI card: label, big figure, a note line, and optional extra content
/// below a divider.
class PosReportKpiCard extends StatelessWidget {
  final String label;
  final String value;

  /// The small line directly under the figure (`~5% vs yesterday`).
  final String? note;

  /// The dark pill at the foot of the card (`32 pending prep`).
  final String? badge;

  /// Extra content below a hairline divider — the VAT table on Total Revenue.
  final Widget? extra;

  const PosReportKpiCard({
    super.key,
    required this.label,
    required this.value,
    this.note,
    this.badge,
    this.extra,
  });

  @override
  Widget build(BuildContext context) {
    return PosReportCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: PosUI.text(
              context,
              size: PosReportSpec.kpiLabelSize,
              weight: FontWeight.w700,
              color: PosReportSpec.inkMuted,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: posPx(context, PosReportSpec.kpiTightGap)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: PosUI.text(
                context,
                size: PosReportSpec.kpiValueSize,
                weight: FontWeight.w800,
                color: PosReportSpec.ink,
              ),
              maxLines: 1,
            ),
          ),
          if (note != null) ...<Widget>[
            SizedBox(height: posPx(context, PosReportSpec.kpiTightGap)),
            Text(
              note!,
              style: PosUI.text(
                context,
                size: PosReportSpec.kpiNoteSize,
                weight: FontWeight.w700,
                color: PosReportSpec.ink,
                height: 1.35,
              ),
            ),
          ],
          if (badge != null) ...<Widget>[
            SizedBox(height: posPx(context, PosReportSpec.cardInnerGap)),
            Align(
              alignment: Alignment.centerLeft,
              child: PosReportBadge(badge!, solid: true),
            ),
          ],
          if (extra != null) ...<Widget>[
            SizedBox(height: posPx(context, PosReportSpec.cardInnerGap)),
            Container(
              height: 1,
              width: double.infinity,
              color: PosReportSpec.cardBorder,
            ),
            SizedBox(height: posPx(context, PosReportSpec.cardInnerGap)),
            extra!,
          ],
        ],
      ),
    );
  }
}

/// Total Revenue, with the VAT/BTW table beneath.
///
/// The headline is `reconciliation.customer_paid` — Net Sales + BTW, which is
/// what Figma's own arithmetic adds up to and what the customer actually paid.
/// It is deliberately NOT `ZReportService.gross_sales`, which means net
/// *before discounts* and is a different number (Phase 1, Decision 3).
class PosReportRevenueCard extends StatelessWidget {
  final PosReportData data;

  const PosReportRevenueCard({super.key, required this.data});

  String? get _delta {
    final double? percent = data.revenueDeltaPercent;
    // No baseline: yesterday took nothing, so there is no percentage to state.
    // Saying "0%" or "+100%" would both be inventions.
    if (percent == null) return null;
    final String sign = percent >= 0 ? '+' : '−';
    return '$sign${percent.abs().toStringAsFixed(1)}% vs yesterday';
  }

  @override
  Widget build(BuildContext context) {
    final List<PosReportTaxRow> rows = data.taxRows;

    return PosReportKpiCard(
      label: 'Total Revenue',
      value: PosHomeSpec.formatPrice(data.totalRevenue, padZero: false),
      note: _delta,
      extra: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'VAT / BTW BREAKDOWN',
            style: PosUI.text(
              context,
              size: PosReportSpec.kpiSectionLabelSize,
              weight: FontWeight.w700,
              color: PosReportSpec.inkMuted,
            ).copyWith(letterSpacing: 0.5),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: posPx(context, PosReportSpec.kpiTightGap)),
          PosReportDetailRow(
            label: 'Net Sales',
            value: PosHomeSpec.formatPrice(data.netSales, padZero: false),
            size: PosReportSpec.kpiRowSize,
            valueWeight: FontWeight.w600,
          ),
          if (!data.taxRecorded) ...<Widget>[
            SizedBox(height: posPx(context, PosReportSpec.kpiTightGap)),
            PosReportDetailRow(
              label: 'VAT (rate split not captured)',
              value: PosHomeSpec.formatPrice(data.totalTax, padZero: false),
              size: PosReportSpec.kpiRowSize,
              valueWeight: FontWeight.w600,
            ),
          ] else
            for (final PosReportTaxRow row in rows) ...<Widget>[
              SizedBox(height: posPx(context, PosReportSpec.kpiTightGap)),
              PosReportDetailRow(
                label: row.label,
                value: PosHomeSpec.formatPrice(row.amount, padZero: false),
                size: PosReportSpec.kpiRowSize,
                valueWeight: FontWeight.w600,
              ),
            ],
          SizedBox(height: posPx(context, PosReportSpec.kpiTightGap)),
          PosReportDetailRow(
            // Figma's "Gross Sales" is the sum of the rows above it — the same
            // figure as the headline. It is restated here as the total of the
            // breakdown, which is what makes the little table add up on screen.
            label: 'Gross Sales',
            value: PosHomeSpec.formatPrice(data.totalRevenue, padZero: false),
            size: PosReportSpec.kpiRowSize,
            labelWeight: FontWeight.w700,
            labelColor: PosReportSpec.ink,
            valueWeight: FontWeight.w800,
          ),
        ],
      ),
    );
  }
}

/// The three simpler KPI cards.
class PosReportSummaryCards {
  PosReportSummaryCards._();

  static Widget totalOrders(PosReportData data) => PosReportKpiCard(
        label: 'Total Orders',
        value: '${data.orderCount}',
        note: '${data.completedOrderCount} completed today.',
        badge: data.pendingPrepCount > 0
            ? '${data.pendingPrepCount} pending prep'
            : null,
      );

  static Widget averageOrderValue(PosReportData data) => PosReportKpiCard(
        label: 'Average Order Value',
        value: PosHomeSpec.formatPrice(data.averageOrderValue, padZero: false),
        // Spelled out because the two cards do not divide into each other and
        // that looks like a bug otherwise: AOV is net sales over *completed*
        // orders, while Total Orders counts every non-delivery order including
        // cancelled ones. Both are correct; they measure different sets.
        note: 'Across ${data.completedOrderCount} completed orders.',
      );

  static Widget tips(PosReportData data) => PosReportKpiCard(
        label: 'Tips Received',
        value: PosHomeSpec.formatPrice(data.totalTips, padZero: false),
        // The branch-wide pool for the day. It cannot be shown per staff
        // member: orders carry no cashier attribution, and POS login is one PIN
        // per terminal rather than per person (Phase 1, Decision 2). Today this
        // figure is effectively kiosk-originated, since the POS flow has no
        // tipping step.
        note: 'Branch pool for the day.',
      );
}
