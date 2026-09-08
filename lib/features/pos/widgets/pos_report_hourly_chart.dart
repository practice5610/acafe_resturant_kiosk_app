import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_report_data.dart';
import 'package:acafe_customer/features/pos/domain/pos_report_spec.dart';
import 'package:acafe_customer/features/pos/widgets/pos_report_widgets.dart';
import 'package:acafe_customer/features/pos/widgets/pos_ui.dart';
import 'package:flutter/material.dart';

/// Hourly Sales — the `bar-chart-visual` of Figma **1641:5518**.
///
/// Hand-built rather than pulled from a charting package, and deliberately so:
/// the app has no charting dependency, and this is one static bar band with a
/// two-tone highlight. `fl_chart` would be several hundred KB and a new axis of
/// styling to fight for a shape that a Row of Expanded columns draws exactly.
///
/// The peak comes from the payload's own `peak_hours`, computed over real
/// revenue. Nothing here is pinned to noon.
class PosReportHourlyChart extends StatelessWidget {
  final PosReportData data;

  const PosReportHourlyChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final List<PosReportHourRow> hours = data.hourlySales;
    final String? peak = data.peakLabel;

    return PosReportCard(
      title: 'Hourly Sales',
      trailing: peak == null
          ? null
          : Align(
              alignment: Alignment.centerRight,
              child: PosReportBadge(peak),
            ),
      child: !data.hourlyRecorded
          ? const PosReportEmptyState.notRecorded(minHeight: 120)
          : hours.isEmpty
              ? const PosReportEmptyState(
                  message: 'No sales yet today',
                  detail: 'Bars appear as orders come in.',
                  minHeight: 120,
                )
              : _Bars(
                  hours: hours,
                  max: data.hourlyMax,
                  peakHours: data.peakHours.toSet(),
                ),
    );
  }
}

class _Bars extends StatelessWidget {
  final List<PosReportHourRow> hours;
  final double max;
  final Set<int> peakHours;

  const _Bars({
    required this.hours,
    required this.max,
    required this.peakHours,
  });

  @override
  Widget build(BuildContext context) {
    final double band = posPx(context, PosReportSpec.chartBandHeight);
    final double labelHeight = posPx(context, PosReportSpec.chartLabelSize) * 1.4;
    final double gap = posPx(context, PosReportSpec.chartLabelGap);
    // The band includes the hour label underneath, so the tallest bar is what
    // is left after the label and its gap — otherwise a peak bar overflows the
    // fixed-height band by exactly the label.
    final double maxBar = (band - labelHeight - gap).clamp(1.0, band);

    return Padding(
      padding: EdgeInsets.only(top: posPx(context, PosReportSpec.chartTopPadding)),
      child: SizedBox(
        height: band,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            for (int i = 0; i < hours.length; i++) ...<Widget>[
              if (i > 0) SizedBox(width: posPx(context, PosReportSpec.chartBarGap)),
              Expanded(
                child: _Bar(
                  row: hours[i],
                  max: max,
                  maxBar: maxBar,
                  labelHeight: labelHeight,
                  gap: gap,
                  isPeak: peakHours.contains(hours[i].hour),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final PosReportHourRow row;
  final double max;
  final double maxBar;
  final double labelHeight;
  final double gap;
  final bool isPeak;

  const _Bar({
    required this.row,
    required this.max,
    required this.maxBar,
    required this.labelHeight,
    required this.gap,
    required this.isPeak,
  });

  @override
  Widget build(BuildContext context) {
    final double fraction = max > 0 ? (row.amount / max).clamp(0.0, 1.0) : 0.0;
    // A dead hour inside the trading window draws nothing at all — that is the
    // point of keeping it in the series. An hour that took money always draws
    // at least a visible stub, so a quiet hour never reads as a closed one.
    final double height = row.amount <= 0
        ? 0.0
        : (fraction * maxBar).clamp(posPx(context, PosReportSpec.chartMinBarHeight), maxBar);

    return Tooltip(
      message: '${row.label}:00 · ${PosHomeSpec.formatPrice(row.amount, padZero: false)}'
          ' · ${row.orderCount} order${row.orderCount == 1 ? '' : 's'}',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: posPx(context, PosReportSpec.chartMaxBarWidth),
            ),
            child: Container(
              height: height,
              width: double.infinity,
              decoration: BoxDecoration(
                color: isPeak ? PosReportSpec.ink : PosReportSpec.barIdle,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(
                      posPx(context, PosReportSpec.chartBarRadius)),
                ),
              ),
            ),
          ),
          SizedBox(height: gap),
          SizedBox(
            height: labelHeight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                row.label,
                style: PosUI.text(
                  context,
                  size: PosReportSpec.chartLabelSize,
                  weight: FontWeight.w700,
                  color: PosReportSpec.inkMuted,
                ),
                maxLines: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
