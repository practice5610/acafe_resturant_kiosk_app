import 'package:acafe_customer/di_container.dart' as di;
import 'package:acafe_customer/features/kiosk/providers/kiosk_manager_provider.dart';
import 'package:acafe_customer/features/pos/domain/pos_report_data.dart';
import 'package:acafe_customer/features/pos/domain/pos_report_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_responsive.dart';
import 'package:acafe_customer/features/pos/domain/pos_routes.dart';
import 'package:acafe_customer/features/pos/domain/pos_staff.dart';
import 'package:acafe_customer/features/pos/domain/pos_staff_repo.dart';
import 'package:acafe_customer/features/pos/domain/pos_z_report_print.dart';
import 'package:acafe_customer/features/pos/widgets/pos_close_day_dialog.dart';
import 'package:acafe_customer/features/pos/widgets/pos_close_day_step2.dart';
import 'package:acafe_customer/features/pos/widgets/pos_report_date_header.dart';
import 'package:acafe_customer/features/pos/widgets/pos_report_hourly_chart.dart';
import 'package:acafe_customer/features/pos/widgets/pos_report_panels.dart';
import 'package:acafe_customer/features/pos/widgets/pos_report_summary_cards.dart';
import 'package:acafe_customer/features/pos/widgets/pos_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Report — Overview, Figma **1641:5518**.
///
/// A display layer over the Z Report, not a second one. Every figure comes from
/// `kiosk-manager/sales-overview`, which resolves to `ZReportService::preview()`
/// for an open day and to the frozen `z_reports` snapshot for a closed one — and
/// Close Day still goes through `zReportClose`, now with counted cash fields.
/// There is deliberately no day-closing, locking or snapshot logic in this file.
class PosReportScreen extends StatefulWidget {
  /// Overrides the day the screen opens on. Production always wants today, but
  /// a golden that renders `DateTime.now()` silently rots the moment the date
  /// rolls over — which is exactly how the Orders board golden became
  /// time-dependent. Pinning it here keeps the comparison stable.
  @visibleForTesting
  final DateTime? initialDate;

  /// Test seam, mirroring [PosPaymentSelectionScreen]. Production leaves this
  /// null and resolves prefs from GetIt.
  @visibleForTesting
  final SharedPreferences? sharedPreferences;

  const PosReportScreen({super.key, this.initialDate, this.sharedPreferences});

  @override
  State<PosReportScreen> createState() => _PosReportScreenState();
}

class _PosReportScreenState extends State<PosReportScreen> {
  /// The selected business day. Local to the screen, not the provider: it is a
  /// view concern, and keeping it here means stepping a day rebuilds this
  /// subtree and re-fetches exactly one day rather than disturbing app state.
  late DateTime _date;

  /// Settings → Staff's roster, read once as the screen opens. It is a
  /// per-terminal local cache (no server-side staff API exists yet — see
  /// [PosStaffRepo]), and it does not vary with the report date, so there is
  /// nothing to re-read when the operator steps between days.
  late final PosStaffRoster _staffRoster = _loadStaffRoster();

  PosStaffRoster _loadStaffRoster() {
    final SharedPreferences? prefs = widget.sharedPreferences ??
        (di.sl.isRegistered<SharedPreferences>()
            ? di.sl<SharedPreferences>()
            : null);
    if (prefs == null) return PosStaffRoster.empty();
    return PosStaffRepo(sharedPreferences: prefs).loadSaved() ??
        PosStaffRoster.empty();
  }

  @override
  void initState() {
    super.initState();
    final DateTime now = widget.initialDate ?? DateTime.now();
    _date = DateTime(now.year, now.month, now.day);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  String get _reportDate =>
      '${_date.year.toString().padLeft(4, '0')}-'
      '${_date.month.toString().padLeft(2, '0')}-'
      '${_date.day.toString().padLeft(2, '0')}';

  void _load() {
    context.read<KioskManagerProvider>().loadSalesOverview(
          reportDate: _reportDate,
        );
  }

  void _onDateChanged(DateTime date) {
    setState(() => _date = date);
    _load();
  }

  Future<void> _confirmCloseDay() async {
    final KioskManagerProvider manager = context.read<KioskManagerProvider>();

    // Only render the count modal against data that belongs to this day —
    // same guard as the dashboard body.
    final PosReportData? data = manager.salesDataDate == _reportDate
        ? PosReportData.from(manager.salesData)
        : null;
    if (data == null) return;

    // Figma **1641:6042** + **1641:6707** — Count Cash Drawer, then Review &
    // Confirm. Close Day still goes through closeZReport below.
    final PosCloseDayResult? result = await PosCloseDayDialog.show(
      context,
      date: _date,
      data: data,
      verifyManagerPin: manager.verifyCloseDayPin,
    );
    if (result == null || !mounted) return;

    if (result.action == PosCloseDayStep2Action.backToOrders) {
      context.go(PosRoutes.orders);
      return;
    }
    if (result.action != PosCloseDayStep2Action.confirm) return;

    // Captured before the await: `context` must not be touched across an async
    // gap, and this screen always has a Scaffold ancestor (PosScaffold).
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    // No opening float is sent: the server derives it from yesterday's counted
    // close, which is also where the figure shown in Step 1 came from.
    final bool success = await manager.closeZReport(
      reportDate: _reportDate,
      closingCashCounted: result.countedAmount,
      denominationBreakdown: result.denominationBreakdown,
      differenceReason: result.differenceReason,
      emailReport: result.emailReport,
    );
    if (!mounted) return;
    if (success) {
      // Printed from the close response — the frozen snapshot, carrying the
      // z_number and the counted-cash figures this close just recorded.
      final PosReportData? closed = PosReportData.from(manager.salesData);
      if (result.printZReport && closed != null) {
        posPrintZReport(closed, _date);
      }

      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: PosReportSpec.ink,
            content: Text(
              _closeMessage(
                emailRequested: result.emailReport,
                emailSent: manager.lastCloseEmailSent,
              ),
              style: PosUI.text(
                context,
                size: 14,
                weight: FontWeight.w700,
                color: PosUI.pageBg,
              ),
            ),
          ),
        );
      _load();
    }
  }

  /// A ticked "email report" box must not imply a send that didn't happen —
  /// the branch may have no email address on file, or the mail server may have
  /// refused it. The server reports what actually went out; this just says so.
  String _closeMessage({required bool emailRequested, required bool emailSent}) {
    if (!emailRequested) return 'Day closed — Z Report finalised.';
    return emailSent
        ? 'Day closed — Z Report finalised and emailed.'
        : 'Day closed — Z Report finalised, but the email could not be sent.';
  }

  @override
  Widget build(BuildContext context) {
    // context.select, not Consumer: KioskManagerProvider is one lazy singleton
    // behind the whole POS Manager area, and it notifies for transactions,
    // products and add-ons too. A Consumer here would rebuild this entire
    // dashboard -- nine panels and a chart -- every time the Receipts list
    // paged or a stock toggle flipped. Selecting the four fields this screen
    // actually reads narrows that to changes it cares about.
    return Builder(
      builder: (BuildContext context) {
        final _ReportView view = context.select<KioskManagerProvider, _ReportView>(
          (KioskManagerProvider m) => _ReportView(
            salesData: m.salesData,
            salesDataDate: m.salesDataDate,
            loading: m.salesLoading,
            closing: m.closingRegister,
          ),
        );

        // Only render figures that belong to the day on screen. The provider's
        // request-id guard already drops superseded responses, but it cannot
        // stop the PREVIOUS day's payload from sitting under the new date while
        // its replacement is still in flight -- which is exactly what rapid
        // date-stepping produces, and it is worse than a spinner because it
        // looks like real data.
        final PosReportData? data = view.salesDataDate == _reportDate
            ? PosReportData.from(view.salesData)
            : null;

        return Container(
          color: PosUI.pageBg,
          child: SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    posPx(context, PosReportSpec.bodyPaddingH),
                    posPx(context, PosReportSpec.bodyPaddingTop),
                    posPx(context, PosReportSpec.bodyPaddingH),
                    posPx(context, PosReportSpec.sectionGap),
                  ),
                  child: PosReportDateHeader(
                    date: _date,
                    onDateChanged: _onDateChanged,
                    onCloseDay: _confirmCloseDay,
                    closed: data?.closed ?? false,
                    closing: view.closing,
                  ),
                ),
                Expanded(
                  child: _Body(
                    data: data,
                    staffRoster: _staffRoster,
                    // Strictly the provider's in-flight flag. It must NOT also
                    // treat "no data for this date" as loading: a request that
                    // failed leaves the date unmatched forever, and the screen
                    // would spin indefinitely instead of offering a retry.
                    //
                    // The three states stay distinct: data for this date =>
                    // render it; a request in flight => spinner; neither =>
                    // the failure state.
                    loading: view.loading,
                    onRetry: _load,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The slice of [KioskManagerProvider] this screen reads.
///
/// Value equality is what makes `context.select` able to skip rebuilds: two
/// snapshots taken around an unrelated notification compare equal, so nothing
/// repaints. `salesData` is compared by identity on purpose -- the provider
/// replaces the map wholesale on every load, and deep-comparing a report
/// payload on every notification would cost more than the rebuild it saves.
@immutable
class _ReportView {
  final Map<String, dynamic>? salesData;
  final String? salesDataDate;
  final bool loading;
  final bool closing;

  const _ReportView({
    required this.salesData,
    required this.salesDataDate,
    required this.loading,
    required this.closing,
  });

  @override
  bool operator ==(Object other) =>
      other is _ReportView &&
      identical(other.salesData, salesData) &&
      other.salesDataDate == salesDataDate &&
      other.loading == loading &&
      other.closing == closing;

  @override
  int get hashCode =>
      Object.hash(identityHashCode(salesData), salesDataDate, loading, closing);
}

class _Body extends StatelessWidget {
  final PosReportData? data;
  final PosStaffRoster staffRoster;
  final bool loading;
  final VoidCallback onRetry;

  const _Body({
    required this.data,
    required this.staffRoster,
    required this.loading,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    // Only the very first load blanks the screen. A date change keeps the
    // previous day's panels on screen underneath a thin progress bar, so
    // stepping through days does not strobe between spinner and content.
    if (data == null) {
      return loading
          ? const Center(child: CircularProgressIndicator())
          : _Unavailable(onRetry: onRetry);
    }

    return Stack(
      children: <Widget>[
        _Dashboard(data: data!, staffRoster: staffRoster),
        if (loading)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(PosReportSpec.ink),
            ),
          ),
      ],
    );
  }
}

class _Unavailable extends StatelessWidget {
  final VoidCallback onRetry;

  const _Unavailable({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(posPx(context, PosReportSpec.bodyPaddingH)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              "Couldn't load the day's report",
              style: PosUI.text(context, size: 16, weight: FontWeight.w800),
            ),
            SizedBox(height: posPx(context, 12)),
            TextButton(
              onPressed: onRetry,
              child: Text(
                'Try again',
                style: PosUI.text(context, size: 14, weight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The panel grid.
///
/// Three rows of equal-width cards on a counter terminal, reflowing by content
/// width rather than by device class:
///
///  * `>= PosResponsive.desktopFloor` — 4 across, both the KPI row and the
///    bottom panel row: at/above the same 1024 floor Home/Payment use, column
///    counts hold steady and the cards simply grow, rather than the KPI and
///    bottom rows re-wrapping at their own separate 1040/1180 seams.
///  * `>= stackWidth`    — 2 columns everywhere else
///  * below that         — one column
///
/// Each row is an [IntrinsicHeight] so cards in a row share a height and their
/// bottom edges line up, as drawn. That is bounded work: at most four fixed
/// cards per row, never a list.
class _Dashboard extends StatelessWidget {
  final PosReportData data;
  final PosStaffRoster staffRoster;

  const _Dashboard({required this.data, required this.staffRoster});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth -
            posPx(context, PosReportSpec.bodyPaddingH) * 2;
        final double gap = posPx(context, PosReportSpec.cardGap);

        // Both rows share one floor now instead of their own separate seams
        // (formerly 1040 for the KPI row, 1180 for the bottom row) — see the
        // class doc. Below the floor, both keep exactly the 2-column /
        // 1-column behaviour they always had.
        final int kpiColumns = width >= PosResponsive.desktopFloor
            ? 4
            : width >= PosReportSpec.stackWidth
                ? 2
                : 1;
        final int midColumns = width >= PosReportSpec.stackWidth ? 2 : 1;
        final int bottomColumns = width >= PosResponsive.desktopFloor
            ? 4
            : width >= PosReportSpec.stackWidth
                ? 2
                : 1;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            posPx(context, PosReportSpec.bodyPaddingH),
            0,
            posPx(context, PosReportSpec.bodyPaddingH),
            posPx(context, PosReportSpec.bodyPaddingBottom),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _Grid(
                columns: kpiColumns,
                gap: gap,
                children: <Widget>[
                  PosReportRevenueCard(data: data),
                  PosReportSummaryCards.totalOrders(data),
                  PosReportSummaryCards.averageOrderValue(data),
                  PosReportSummaryCards.tips(data),
                ],
              ),
              SizedBox(height: gap),
              _Grid(
                columns: midColumns,
                gap: gap,
                children: <Widget>[
                  PosReportPaymentMethodsPanel(data: data),
                  PosReportTopProductsPanel(data: data),
                ],
              ),
              SizedBox(height: gap),
              PosReportHourlyChart(data: data),
              SizedBox(height: gap),
              _Grid(
                columns: bottomColumns,
                gap: gap,
                children: <Widget>[
                  PosReportCashDrawerPanel(data: data),
                  PosReportCategorySalesPanel(data: data),
                  PosReportStaffTipsPanel(data: data, roster: staffRoster),
                  PosReportRefundsPanel(data: data),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Lays [children] out in rows of [columns], padding the final row with empty
/// flex so a trailing card keeps its column width instead of stretching across
/// the gap left by its missing siblings.
class _Grid extends StatelessWidget {
  final int columns;
  final double gap;
  final List<Widget> children;

  const _Grid({
    required this.columns,
    required this.gap,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final List<Widget> rows = <Widget>[];

    for (int start = 0; start < children.length; start += columns) {
      final List<Widget> slice =
          children.sublist(start, (start + columns).clamp(0, children.length));

      final List<Widget> cells = <Widget>[];
      for (int i = 0; i < columns; i++) {
        if (i > 0) cells.add(SizedBox(width: gap));
        cells.add(
          Expanded(child: i < slice.length ? slice[i] : const SizedBox.shrink()),
        );
      }

      if (rows.isNotEmpty) rows.add(SizedBox(height: gap));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: cells,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}
