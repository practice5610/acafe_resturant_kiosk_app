import 'dart:async';

import 'package:acafe_customer/di_container.dart' as di;
import 'package:acafe_customer/features/kiosk/domain/kiosk_manager_repo.dart';
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_advance_outcome.dart';
import 'package:acafe_customer/features/pos/domain/pos_order_card.dart';
import 'package:acafe_customer/features/pos/domain/pos_order_filters.dart';
import 'package:acafe_customer/features/pos/domain/pos_order_grouping.dart';
import 'package:acafe_customer/features/pos/domain/pos_orders_repo.dart';
import 'package:acafe_customer/features/pos/domain/pos_orders_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipts_spec.dart';
import 'package:acafe_customer/features/pos/providers/pos_orders_provider.dart';
import 'package:acafe_customer/features/pos/widgets/pos_filter_dropdown.dart';
import 'package:acafe_customer/features/pos/widgets/pos_filter_pill.dart';
import 'package:acafe_customer/features/pos/widgets/pos_order_card_tile.dart';
import 'package:acafe_customer/features/pos/widgets/pos_order_date_range_bar.dart';
import 'package:acafe_customer/features/pos/widgets/pos_complete_confirmation_dialog.dart';
import 'package:acafe_customer/features/pos/widgets/pos_order_detail_overlay.dart';
import 'package:acafe_customer/features/pos/widgets/pos_search_field.dart';
import 'package:acafe_customer/features/pos/domain/pos_settings_spec.dart';
import 'package:acafe_customer/features/realtime/order_changed_event.dart';
import 'package:acafe_customer/features/realtime/product_realtime_controller.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// The POS Orders board (Figma **1641:2874**).
///
/// One vertical scroll of three stacked sections, each a header with a live
/// count and a wrapping grid of cards — *not* three side-by-side columns. The
/// Figma frame draws every section at the full 1318px content width.
///
/// The provider is scoped to this screen rather than registered globally, in
/// the same way the POS Settings tabs scope theirs: the board's filters are
/// screen state, and the realtime subscription should not outlive the screen.
class PosOrdersListScreen extends StatelessWidget {
  /// Injectable for tests, which build the POS tree without a populated
  /// service locator. Production leaves it null and resolves the registered
  /// singleton.
  final PosOrdersRepo? repo;

  /// Time source for the elapsed labels. Injectable so a screenshot test can
  /// freeze it — a golden that bakes `DateTime.now()` differs on every run and
  /// is worthless as a regression guard. Production leaves it null.
  final DateTime Function()? clock;

  const PosOrdersListScreen({super.key, this.repo, this.clock});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PosOrdersProvider>(
      create: (_) => PosOrdersProvider(
        posOrdersRepo: repo ?? di.sl<PosOrdersRepo>(),
      ),
      child: _PosOrdersBoard(clock: clock),
    );
  }
}

class _PosOrdersBoard extends StatefulWidget {
  final DateTime Function()? clock;

  const _PosOrdersBoard({this.clock});

  @override
  State<_PosOrdersBoard> createState() => _PosOrdersBoardState();
}

class _PosOrdersBoardState extends State<_PosOrdersBoard> {
  final TextEditingController _searchController = TextEditingController();

  /// One clock for the whole board. Every card reads `_now` rather than owning
  /// a timer, so a hundred open orders still cost one tick per second.
  Timer? _clock;
  late DateTime _now = _read();

  DateTime _read() => (widget.clock ?? DateTime.now)();

  late final PosOrdersProvider _provider;
  ProductRealtimeController? _realtime;

  @override
  void initState() {
    super.initState();
    _provider = context.read<PosOrdersProvider>();

    // Deferred past the first frame so the initial notifyListeners() does not
    // land during build. load(), not setNow(true): the provider already starts
    // in NOW mode, and setNow would early-return on the unchanged value and
    // leave the board empty.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_provider.load());
    });

    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = _read());
    });

    // Live board. The socket, its reconnect handling and its lifecycle already
    // exist and are already mounted app-wide by ProductRealtimeScope; this
    // screen only registers interest in the branch order channel while it is
    // on screen.
    //
    // Guarded: a widget test builds the POS tree without a populated service
    // locator, and the board is still worth exercising there — it just does not
    // receive pushes.
    if (di.sl.isRegistered<ProductRealtimeController>()) {
      _realtime = di.sl<ProductRealtimeController>();
      _realtime?.addOrderListener(_onOrderEvent);
      _realtime?.addReconnectListener(_onRealtimeReconnect);
    }
  }

  void _onOrderEvent(OrderChangedEvent event) {
    if (!mounted) return;
    _provider.onRealtimeChange();
  }

  void _onRealtimeReconnect() {
    if (!mounted) return;
    _provider.onRealtimeReconnect();
  }

  @override
  void dispose() {
    _realtime?.removeOrderListener(_onOrderEvent);
    _realtime?.removeReconnectListener(_onRealtimeReconnect);
    _clock?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// The one place an order is advanced from, for every POS surface.
  ///
  /// The board card calls it directly and the detail overlay is handed it (see
  /// [_openDetail]) rather than the provider method underneath, so the
  /// confirmation below cannot be present on one surface and missing on the
  /// other — there is nowhere else for a completion to go.
  ///
  /// Only the terminal rung is gated. `preparing -> item_to_collect` and
  /// `on_hold -> preparing` advance straight through: they are recoverable,
  /// and Figma specifies a confirmation for completion alone.
  ///
  /// Returns the outcome rather than raising its own snackbar, because the two
  /// surfaces report failure differently — the board floats one over the
  /// grid, the overlay shows it without closing.
  Future<PosAdvanceResult> _advance(PosOrderCard order) async {
    final String? target = PosOrderGrouping.nextStatusFor(order.orderStatus);
    if (target == null) return const PosAdvanceResult.cancelled();

    if (target == 'completed') {
      final bool? confirmed =
          await PosCompleteConfirmationDialog.show(context);
      // Cancel, a tap outside and Escape all land here. Nothing is sent.
      if (confirmed != true || !mounted) {
        return const PosAdvanceResult.cancelled();
      }
    }

    final String? message = await _provider.advance(order);

    return message == null
        ? const PosAdvanceResult.advanced()
        : PosAdvanceResult.failed(message);
  }

  /// The board's own way of reporting a rejected transition.
  void _showAdvanceError(PosOrderCard order, String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Order #${order.id}: $message'),
          backgroundColor: PosHomeSpec.ink,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  /// Figma's `card-actions more-vertical`. "Open detail" is now wired — it
  /// opens [PosOrderDetailOverlay] over the board. The remaining entries
  /// (reprint, refund, cancel) are still separately-scoped work and stay
  /// disabled rather than faked, so nothing here pretends to do something it
  /// does not.
  Future<void> _openCardMenu(BuildContext anchor, PosOrderCard order) async {
    final RenderBox? box = anchor.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    final RenderBox? overlay =
        Overlay.of(anchor).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;

    // Measured against the overlay, because that is the box RelativeRect is
    // resolved against below.
    final Offset origin = box.localToGlobal(Offset.zero, ancestor: overlay);
    final Size overlaySize = overlay.size;

    // Figma anchors the menu's right edge to the button's right edge, which is
    // also what keeps it on screen: these buttons sit at the right of a card in
    // the rightmost column, so a left-anchored menu runs off the board. Clamped
    // to the overlay either way.
    const double menuWidth = PosHomeSpec.contextMenuWidth;
    final double maxLeft = (overlaySize.width - menuWidth - 8).clamp(8.0, double.infinity);
    final double left =
        (origin.dx + box.size.width - menuWidth).clamp(8.0, maxLeft);
    final double top = origin.dy + box.size.height + 6;

    await showMenu<void>(
      context: anchor,
      color: PosSettingsSpec.fieldFill,
      elevation: 12,
      shadowColor: const Color(0x33241F20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PosSettingsSpec.fieldRadius),
        side: const BorderSide(color: PosSettingsSpec.fieldBorder),
      ),
      // RelativeRect.fromLTRB takes *insets from each edge of the overlay*,
      // not absolute coordinates. Passing an absolute x as `right` (and an
      // absolute y as `bottom`) produced a rect wider than the screen, so the
      // menu was laid out against a degenerate box and landed down-and-left of
      // the button, on top of the cards below it.
      position: RelativeRect.fromLTRB(
        left,
        top,
        overlaySize.width - left - menuWidth,
        overlaySize.height - top,
      ),
      // Fixed, not just a minimum: the longest entry would otherwise stretch
      // the menu across several card columns.
      constraints: const BoxConstraints(
        minWidth: menuWidth,
        maxWidth: menuWidth,
      ),
      items: [
        PopupMenuItem<void>(
          enabled: false,
          height: PosReceiptsSpec.filterMenuItemHeight,
          child: Text(
            'Order #${order.id}',
            style: loewBold.copyWith(
              fontSize: PosSettingsSpec.fieldTextSize,
              color: PosSettingsSpec.ink,
            ),
          ),
        ),
        PopupMenuItem<void>(
          height: PosReceiptsSpec.filterMenuItemHeight,
          onTap: () => _openDetail(order),
          child: Text(
            'Open detail',
            style: loewRegular.copyWith(
              fontSize: PosSettingsSpec.fieldTextSize,
              color: PosSettingsSpec.ink,
            ),
          ),
        ),
        PopupMenuItem<void>(
          enabled: false,
          height: PosReceiptsSpec.filterMenuItemHeight,
          child: Text(
            'No other actions yet',
            style: loewRegular.copyWith(
              fontSize: PosSettingsSpec.fieldTextSize,
              color: PosHomeSpec.inkAlpha(0.5),
            ),
          ),
        ),
      ],
    );
  }

  /// Open the detail overlay for one card.
  ///
  /// The overlay is handed [PosOrdersProvider.advance] rather than its own
  /// transition call, so the modal's action and the card's own button run the
  /// identical optimistic-update-and-reconcile path and can never disagree
  /// about an order's next step.
  ///
  /// `useRootNavigator: false` keeps the route inside the POS shell, and the
  /// board underneath is never rebuilt or reset by opening it — its scroll
  /// offset, filters and live subscription all survive, because the board is
  /// not torn down to show a route on top of it.
  Future<void> _openDetail(PosOrderCard order) async {
    if (!di.sl.isRegistered<KioskManagerRepo>()) return;

    await showDialog<void>(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: true,
      useRootNavigator: false,
      builder: (_) => PosOrderDetailOverlay(
        order: order,
        repo: di.sl<KioskManagerRepo>(),
        onAdvance: _advance,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PosOrdersProvider>(
      builder: (context, provider, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _filters(provider),
            Expanded(child: _board(provider)),
          ],
        );
      },
    );
  }

  // ── Filter bar ───────────────────────────────────────────────────────
  Widget _filters(PosOrdersProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PosOrdersSpec.pagePadding,
        14,
        PosOrdersSpec.pagePadding,
        PosOrdersSpec.filtersBottomGap,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final bool wrap =
                  constraints.maxWidth < PosOrdersSpec.filtersWrapBelowWidth;

              final Widget range = PosOrderDateRangeBar(
                from: provider.from,
                to: provider.to,
                now: provider.now,
                onNow: provider.setNow,
                onFrom: (value) => provider.setRange(
                  from: value,
                  to: provider.to,
                  now: false,
                ),
                onTo: (value) => provider.setRange(
                  from: provider.from,
                  to: value,
                  now: false,
                ),
              );

              final Widget search = PosSearchField(
                controller: _searchController,
                hintText: 'Search in orders...',
                style: PosSearchFieldStyle.settings,
                onChanged: provider.setSearch,
              );

              // Below the break the search bar cannot share a row with the
              // date fields without either being squeezed to nothing.
              if (wrap) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    range,
                    const SizedBox(height: PosOrdersSpec.filterRowGap),
                    search,
                  ],
                );
              }

              return Row(
                children: [
                  range,
                  const SizedBox(width: PosOrdersSpec.dropdownGap),
                  Expanded(child: search),
                ],
              );
            },
          ),
          const SizedBox(height: PosOrdersSpec.filterRowGap),
          Wrap(
            spacing: PosOrdersSpec.dropdownGap,
            runSpacing: PosOrdersSpec.dropdownGap,
            children: [
              PosFilterDropdown<String?>(
                label: 'All sources',
                options: PosOrderFilters.sources,
                value: provider.source,
                onChanged: provider.setSource,
              ),
              PosFilterDropdown<String?>(
                label: 'All types',
                options: PosOrderFilters.types,
                value: provider.type,
                onChanged: provider.setType,
              ),
              PosFilterDropdown<String?>(
                label: 'All payment methods',
                options: PosOrderFilters.methods,
                value: provider.method,
                onChanged: provider.setMethod,
              ),
              PosFilterDropdown<String?>(
                label: 'Any status',
                options: PosOrderFilters.statuses,
                value: provider.status,
                onChanged: provider.setStatus,
              ),
            ],
          ),
          const SizedBox(height: PosOrdersSpec.filterRowGap),
          // A horizontal scroller, not a Wrap, and for a specific reason:
          // PosFilterPill's Container carries an `alignment` and no width, so
          // under the bounded constraints a Wrap hands out it expands to the
          // full row. The product grid already mounts these pills this way —
          // unbounded width is what makes them shrink-wrap — and it doubles as
          // the overflow behaviour on a narrow terminal.
          ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _sectionPill(provider, null, 'All', provider.totalCount),
                  const SizedBox(width: PosOrdersSpec.pillGap),
                  _sectionPill(
                    provider,
                    PosOrderSection.newOrders,
                    'New',
                    provider.countOf(PosOrderSection.newOrders),
                  ),
                  const SizedBox(width: PosOrdersSpec.pillGap),
                  _sectionPill(
                    provider,
                    PosOrderSection.inProgress,
                    'In progress',
                    provider.countOf(PosOrderSection.inProgress),
                  ),
                  const SizedBox(width: PosOrdersSpec.pillGap),
                  _sectionPill(
                    provider,
                    PosOrderSection.finished,
                    'Finished',
                    provider.countOf(PosOrderSection.finished),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionPill(
    PosOrdersProvider provider,
    PosOrderSection? section,
    String label,
    int count,
  ) {
    return PosFilterPill(
      label: count > 0 ? '$label  $count' : label,
      active: provider.section == section,
      onTap: () => provider.setSection(section),
    );
  }

  // ── Board ────────────────────────────────────────────────────────────
  Widget _board(PosOrdersProvider provider) {
    if (provider.initialLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(PosHomeSpec.ink),
        ),
      );
    }

    // A filter can legitimately empty a section but not the board; an entirely
    // empty board with an error behind it is the case worth naming.
    if (provider.orders.isEmpty) {
      return _EmptyBoard(message: provider.error);
    }

    final List<PosOrderSection> sections = provider.section == null
        ? const [
            PosOrderSection.newOrders,
            PosOrderSection.inProgress,
            PosOrderSection.finished,
          ]
        : <PosOrderSection>[provider.section!];

    return LayoutBuilder(
      builder: (context, constraints) {
        final double available =
            constraints.maxWidth - PosOrdersSpec.pagePadding * 2;

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            PosOrdersSpec.pagePadding,
            0,
            PosOrdersSpec.pagePadding,
            PosOrdersSpec.pagePadding,
          ),
          children: [
            for (final PosOrderSection section in sections) ...[
              _section(provider, section, available),
              const SizedBox(height: PosOrdersSpec.sectionGap),
            ],
          ],
        );
      },
    );
  }

  Widget _section(
    PosOrdersProvider provider,
    PosOrderSection section,
    double available,
  ) {
    final List<PosOrderCard> cards = provider.ordersIn(section);

    // Cards hold their 288px design width until the pane is narrower than one
    // card, at which point they stretch rather than overflow.
    final double cardWidth = available < PosOrdersSpec.cardWidth
        ? available.clamp(PosOrdersSpec.cardStretchBelowWidth, double.infinity)
        : PosOrdersSpec.cardWidth;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          PosOrderGrouping.labelFor(section),
          provider.countOf(section),
        ),
        const SizedBox(height: PosOrdersSpec.sectionHeaderGap),
        if (cards.isEmpty)
          Text(
            'No orders',
            style: loewRegular.copyWith(
              fontSize: PosOrdersSpec.subtitleTextSize,
              color: PosHomeSpec.inkAlpha(0.45),
            ),
          )
        else
          Wrap(
            spacing: PosOrdersSpec.cardGap,
            runSpacing: PosOrdersSpec.cardGap,
            children: [
              for (final PosOrderCard order in cards)
                SizedBox(
                  width: cardWidth,
                  child: Builder(
                    builder: (cardContext) => PosOrderCardTile(
                      order: order,
                      now: _now,
                      pending: provider.isPending(order.id),
                      onAdvance: () async {
                        final PosAdvanceResult result = await _advance(order);
                        if (result.isFailed) {
                          _showAdvanceError(order, result.message!);
                        }
                      },
                      onMenu: () => _openCardMenu(cardContext, order),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _sectionHeader(String label, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: loewBold.copyWith(
            fontSize: PosOrdersSpec.sectionHeaderSize,
            color: PosHomeSpec.ink,
          ),
        ),
        const SizedBox(width: PosOrdersSpec.badgeGap),
        Container(
          height: PosOrdersSpec.badgeHeight,
          constraints:
              const BoxConstraints(minWidth: PosOrdersSpec.badgeMinWidth),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 7),
          decoration: BoxDecoration(
            color: PosHomeSpec.inactiveFill,
            borderRadius: BorderRadius.circular(PosOrdersSpec.badgeRadius),
          ),
          child: Text(
            '$count',
            style: loewBold.copyWith(
              fontSize: PosOrdersSpec.badgeTextSize,
              color: PosHomeSpec.ink,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyBoard extends StatelessWidget {
  final String? message;

  const _EmptyBoard({this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(PosOrdersSpec.pagePadding),
        child: Text(
          message ?? 'No orders in this window',
          textAlign: TextAlign.center,
          style: loewRegular.copyWith(
            fontSize: 14,
            color: PosHomeSpec.inkAlpha(0.5),
          ),
        ),
      ),
    );
  }
}
