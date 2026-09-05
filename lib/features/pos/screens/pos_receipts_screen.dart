import 'dart:async';

import 'package:acafe_customer/features/kiosk/providers/kiosk_manager_provider.dart';
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipt_export.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipt_filters.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipt_history.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipt_print.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipts_spec.dart';
import 'package:acafe_customer/features/pos/widgets/pos_filter_dropdown.dart';
import 'package:acafe_customer/features/pos/widgets/pos_receipt_detail_panel.dart';
import 'package:acafe_customer/features/pos/widgets/pos_receipts_table.dart';
import 'package:acafe_customer/features/pos/widgets/pos_search_field.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/helper/custom_snackbar_helper.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Receipts — Figma **1641:3228**.
///
/// The branch's settled orders on the left, the selected one rendered as a full
/// Purchase Receipt on the right. Both halves read the device-auth transactions
/// feed on [KioskManagerProvider]; the customer `order/list` endpoint is not an
/// option here, because POS places its orders as a guest and there is no
/// customer session behind that guard.
class PosReceiptsScreen extends StatefulWidget {
  const PosReceiptsScreen({super.key});

  @override
  State<PosReceiptsScreen> createState() => _PosReceiptsScreenState();
}

class _PosReceiptsScreenState extends State<PosReceiptsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  /// Long enough that typing a receipt number fires one branch-wide query,
  /// short enough to feel immediate — the same 350ms the manager Transaction
  /// History screen already uses.
  static const Duration _debounce = Duration(milliseconds: 350);
  Timer? _debounceTimer;

  String? _status;
  String? _channel;
  PosReceiptAmountBand? _amount;
  PosReceiptDateRange _dateRange = PosReceiptDateRange.today;

  /// Selection lives on this screen, not the provider: it is a view concern,
  /// and keeping it local means picking a row rebuilds this subtree only.
  int? _selectedId;

  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // The provider is a lazy singleton, so an earlier visit's query can
      // outlive the screen. Entering always starts from the default filter set,
      // matching the controls as drawn.
      context.read<KioskManagerProvider>().clearReceiptDetail();
      _reload();
    });
    _searchController.addListener(_onQueryChanged);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.removeListener(_onQueryChanged);
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () {
      if (!mounted) return;
      _reload();
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final KioskManagerProvider manager = context.read<KioskManagerProvider>();
    if (manager.transactionsLoading || !manager.hasMoreTransactions) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      manager.loadTransactions(reset: false);
    }
  }

  /// Re-runs the list from page one with whatever the controls currently say.
  ///
  /// `replaceFilters: true` is what lets a filter be cleared as well as set —
  /// the manager Transaction History screen leaves it false and keeps its old
  /// behaviour untouched.
  void _reload() {
    context.read<KioskManagerProvider>().loadTransactions(
          search: _searchController.text,
          reportDate: _dateRange.reportDate,
          dateFrom: _dateRange.dateFrom,
          dateTo: _dateRange.dateTo,
          status: _status,
          channel: _channel,
          amountMin: _amount?.min,
          amountMax: _amount?.max,
          replaceFilters: true,
        );
  }

  void _select(PosReceiptRow row) {
    if (_selectedId == row.id) return;
    setState(() => _selectedId = row.id);
    context.read<KioskManagerProvider>().loadReceiptDetail(row.id);
  }

  /// With both panes on screen the newest receipt opens by itself, as Figma
  /// draws it (row 0 highlighted, its breakdown beside it). An empty detail
  /// pane taking a third of a counter terminal until someone clicks is wasted
  /// space, and the newest receipt is the one an operator usually wants — a
  /// refund or a reprint of the sale that just happened.
  ///
  /// Never on the narrow layout: there the detail is a sheet, and opening one
  /// unasked would cover the list.
  void _autoSelectFirst(List<PosReceiptRow> rows, bool sideBySide) {
    if (!sideBySide || _selectedId != null || rows.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _selectedId != null || rows.isEmpty) return;
      _select(rows.first);
    });
  }

  /// The selection is dropped when the row it pointed at is no longer in the
  /// list — a filter or search that excludes it must not leave its receipt
  /// stranded in the detail pane.
  void _dropSelectionIfGone(List<PosReceiptRow> rows) {
    if (_selectedId == null || rows.isEmpty) return;
    if (rows.any((row) => row.id == _selectedId)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (rows.any((row) => row.id == _selectedId)) return;
      setState(() => _selectedId = null);
      context.read<KioskManagerProvider>().clearReceiptDetail();
    });
  }

  Future<void> _export(List<PosReceiptRow> visible) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final KioskManagerProvider manager = context.read<KioskManagerProvider>();
      // Export means the filtered result set, not the pages scrolled into
      // view — so drain the remaining pages before writing the file.
      await manager.loadAllTransactionsForExport();
      if (!mounted) return;
      final List<PosReceiptRow> rows = manager.transactions
          .map((json) => PosReceiptRow.fromJson(json))
          .toList();
      posExportReceiptsCsv(
        rows.isEmpty ? visible : rows,
        fileLabel: _dateRange.fileLabel,
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _print(PosReceiptDetail receipt) {
    try {
      posPrintReceipt(receipt);
    } catch (_) {
      // print() is only meaningful on the web build the POS actually ships as.
      showCustomSnackBarHelper('Printing is not available on this device');
    }
  }

  @override
  Widget build(BuildContext context) {
    final KioskManagerProvider manager = context.watch<KioskManagerProvider>();
    final SplashProvider splash = context.watch<SplashProvider>();

    final List<PosReceiptRow> rows = manager.transactions
        .map((json) => PosReceiptRow.fromJson(json))
        .toList();

    final Map<String, dynamic>? detailJson = manager.receiptDetail;
    // Guard against the detail of a previous selection painting under the
    // current one: the provider clears on every new request, and this checks
    // the id it did land with.
    final PosReceiptDetail? detail =
        (detailJson != null && manager.receiptDetailId == _selectedId)
            ? PosReceiptDetail.fromJson(detailJson)
            : null;
    final bool detailLoading =
        _selectedId != null && (manager.receiptDetailLoading || detail == null);

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool sideBySide =
            constraints.maxWidth >= PosReceiptsSpec.stackedBelowWidth;

        _dropSelectionIfGone(rows);
        _autoSelectFirst(rows, sideBySide);

        final Widget list = _ListPane(
          searchController: _searchController,
          onSearchChanged: (_) {},
          status: _status,
          channel: _channel,
          amount: _amount,
          dateRange: _dateRange,
          onStatus: (v) => setState(() {
            _status = v;
            _reload();
          }),
          onChannel: (v) => setState(() {
            _channel = v;
            _reload();
          }),
          onAmount: (v) => setState(() {
            _amount = v;
            _reload();
          }),
          onDateRange: (v) => setState(() {
            _dateRange = v;
            _reload();
          }),
          exporting: _exporting,
          onExport: rows.isEmpty ? null : () => _export(rows),
          rows: rows,
          selectedId: _selectedId,
          onSelect: (row) {
            _select(row);
            if (!sideBySide) _openDetailSheet(row);
          },
          scrollController: _scrollController,
          loading: manager.transactionsLoading && rows.isEmpty,
          loadingMore: manager.transactionsLoading && rows.isNotEmpty,
        );

        if (!sideBySide) {
          // Narrow: the list owns the width and the receipt opens as a sheet.
          // Two 400px-ish panes side by side stop being usable well before the
          // window does.
          return ColoredBox(color: PosHomeSpec.pageBg, child: list);
        }

        return ColoredBox(
          color: PosHomeSpec.pageBg,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: list),
              PosReceiptDetailPanel(
                receipt: detail,
                loading: detailLoading,
                imageBaseUrl: splash.baseUrls?.productImageUrl,
                onPrint: detail == null ? null : () => _print(detail),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Compact-width detail: the same panel, in a sheet.
  Future<void> _openDetailSheet(PosReceiptRow row) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.92,
          child: ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
            child: Consumer2<KioskManagerProvider, SplashProvider>(
              builder: (context, manager, splash, _) {
                final Map<String, dynamic>? json = manager.receiptDetail;
                final PosReceiptDetail? detail =
                    (json != null && manager.receiptDetailId == row.id)
                        ? PosReceiptDetail.fromJson(json)
                        : null;
                return PosReceiptDetailPanel(
                  receipt: detail,
                  loading: manager.receiptDetailLoading || detail == null,
                  imageBaseUrl: splash.baseUrls?.productImageUrl,
                  onPrint: detail == null ? null : () => _print(detail),
                  width: null,
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// `receipts-list-area` (1641:3232).
class _ListPane extends StatelessWidget {
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final String? status;
  final String? channel;
  final PosReceiptAmountBand? amount;
  final PosReceiptDateRange dateRange;
  final ValueChanged<String?> onStatus;
  final ValueChanged<String?> onChannel;
  final ValueChanged<PosReceiptAmountBand?> onAmount;
  final ValueChanged<PosReceiptDateRange> onDateRange;
  final bool exporting;
  final VoidCallback? onExport;
  final List<PosReceiptRow> rows;
  final int? selectedId;
  final ValueChanged<PosReceiptRow> onSelect;
  final ScrollController scrollController;
  final bool loading;
  final bool loadingMore;

  const _ListPane({
    required this.searchController,
    required this.onSearchChanged,
    required this.status,
    required this.channel,
    required this.amount,
    required this.dateRange,
    required this.onStatus,
    required this.onChannel,
    required this.onAmount,
    required this.onDateRange,
    required this.exporting,
    required this.onExport,
    required this.rows,
    required this.selectedId,
    required this.onSelect,
    required this.scrollController,
    required this.loading,
    required this.loadingMore,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(PosReceiptsSpec.panePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FilterHeader(
            searchController: searchController,
            onSearchChanged: onSearchChanged,
            status: status,
            channel: channel,
            amount: amount,
            dateRange: dateRange,
            onStatus: onStatus,
            onChannel: onChannel,
            onAmount: onAmount,
            onDateRange: onDateRange,
            exporting: exporting,
            onExport: onExport,
          ),
          const SizedBox(height: PosReceiptsSpec.paneGap),
          // Flexible, not Expanded: Figma sizes the table to its rows, and a
          // white box stretched to the bottom of an empty shift looks broken.
          // It still takes every pixel it needs once the rows outgrow the pane,
          // and scrolls from there.
          Flexible(
            child: PosReceiptsTable(
              rows: rows,
              selectedId: selectedId,
              onSelect: onSelect,
              controller: scrollController,
              loading: loading,
              loadingMore: loadingMore,
            ),
          ),
        ],
      ),
    );
  }
}

/// `filter-header` (1641:3233).
///
/// Search left, controls right while they fit; below that the row wraps rather
/// than squeezing the search field into a slot too small to type in.
class _FilterHeader extends StatelessWidget {
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final String? status;
  final String? channel;
  final PosReceiptAmountBand? amount;
  final PosReceiptDateRange dateRange;
  final ValueChanged<String?> onStatus;
  final ValueChanged<String?> onChannel;
  final ValueChanged<PosReceiptAmountBand?> onAmount;
  final ValueChanged<PosReceiptDateRange> onDateRange;
  final bool exporting;
  final VoidCallback? onExport;

  const _FilterHeader({
    required this.searchController,
    required this.onSearchChanged,
    required this.status,
    required this.channel,
    required this.amount,
    required this.dateRange,
    required this.onStatus,
    required this.onChannel,
    required this.onAmount,
    required this.onDateRange,
    required this.exporting,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final Widget search = SizedBox(
      width: PosReceiptsSpec.searchWidth,
      child: PosSearchField(
        controller: searchController,
        onChanged: onSearchChanged,
        hintText: 'Search receipts..',
      ),
    );

    final List<Widget> actions = [
      PosFilterDropdown<String?>(
        label: 'Status',
        options: PosReceiptFilters.statuses,
        value: status,
        onChanged: onStatus,
      ),
      PosFilterDropdown<String?>(
        label: 'Category',
        options: PosReceiptFilters.channels,
        value: channel,
        onChanged: onChannel,
      ),
      PosFilterDropdown<PosReceiptAmountBand?>(
        label: 'Amount',
        options: PosReceiptFilters.amounts,
        value: amount,
        onChanged: onAmount,
      ),
      PosFilterDropdown<PosReceiptDateRange>(
        label: 'Date',
        options: PosReceiptFilters.dates,
        value: dateRange,
        onChanged: onDateRange,
        // The date pill names its window even on the default, exactly as Figma
        // draws it ("Today").
        alwaysShowSelection: true,
      ),
      PosExportButton(
        busy: exporting,
        onTap: exporting ? null : onExport,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // 520 is roughly what the five controls need; below it they go under
        // the search field instead of being crushed against it.
        final bool inline = constraints.maxWidth >=
            PosReceiptsSpec.searchWidth + 520;

        if (inline) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              search,
              const Spacer(),
              Wrap(
                spacing: PosReceiptsSpec.filterRowGap,
                runSpacing: PosReceiptsSpec.filterRowGap,
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: actions,
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            search,
            const SizedBox(height: PosReceiptsSpec.filterRowGap),
            Wrap(
              spacing: PosReceiptsSpec.filterRowGap,
              runSpacing: PosReceiptsSpec.filterRowGap,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: actions,
            ),
          ],
        );
      },
    );
  }
}
