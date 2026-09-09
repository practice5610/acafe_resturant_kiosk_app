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
import 'package:acafe_customer/features/pos/providers/pos_orders_provider.dart';
import 'package:acafe_customer/features/pos/widgets/pos_filter_dropdown.dart';
import 'package:acafe_customer/features/pos/widgets/pos_filter_pill.dart';
import 'package:acafe_customer/features/pos/widgets/pos_order_card_tile.dart';
import 'package:acafe_customer/features/pos/widgets/pos_order_date_range_bar.dart';
import 'package:acafe_customer/features/pos/widgets/pos_complete_confirmation_dialog.dart';
import 'package:acafe_customer/features/pos/widgets/pos_order_detail_overlay.dart';
import 'package:acafe_customer/features/pos/widgets/pos_search_field.dart';
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
  /// other — there is nowhere else for an advance to go.
  ///
  /// Every rung the operator can push an order forward through is confirmed
  /// before it fires — accepting a NEW order, marking one ready, marking one
  /// complete — each with copy naming what it actually does. Only
  /// `on_hold -> preparing` (Resume) is not: un-pausing an order does not
  /// progress it, so there is nothing here for the operator to confirm.
  ///
  /// Returns the outcome rather than raising its own snackbar, because the two
  /// surfaces report failure differently — the board floats one over the
  /// grid, the overlay shows it without closing.
  Future<PosAdvanceResult> _advance(PosOrderCard order) async {
    final String? target = PosOrderGrouping.nextStatusFor(order.orderStatus);
    if (target == null) return const PosAdvanceResult.cancelled();

    final _AdvanceConfirmation? confirmation =
        _AdvanceConfirmation.forTransition(order.orderStatus, target);
    if (confirmation != null) {
      final bool? confirmed = await PosCompleteConfirmationDialog.show(
        context,
        heading: confirmation.heading,
        subtext: confirmation.subtext,
        confirmLabel: confirmation.confirmLabel,
      );
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

  /// Open the detail overlay for one card.
  ///
  /// Figma has no ⋮ menu on this card — the whole card tile is the
  /// affordance, wired through [PosOrderCardTile.onTap].
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
                  child: PosOrderCardTile(
                    order: order,
                    now: _now,
                    pending: provider.isPending(order.id),
                    onAdvance: () async {
                      final PosAdvanceResult result = await _advance(order);
                      if (result.isFailed) {
                        _showAdvanceError(order, result.message!);
                      }
                    },
                    // The whole card opens the detail overlay — Figma has no
                    // ⋮ menu on this tile.
                    onTap: () => _openDetail(order),
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

/// Confirmation copy for one forward transition on the kitchen ladder.
///
/// Named on the transition, not the target status alone: `new -> preparing`
/// and `on_hold -> preparing` share a target but mean different things to the
/// operator — accepting a new order versus un-pausing one already accepted —
/// so only the first gets a prompt. See [PosOrdersListScreen._advance].
class _AdvanceConfirmation {
  final String heading;
  final String subtext;
  final String confirmLabel;

  const _AdvanceConfirmation({
    required this.heading,
    required this.subtext,
    required this.confirmLabel,
  });

  static _AdvanceConfirmation? forTransition(String fromStatus, String toStatus) {
    if (PosOrderGrouping.newStatuses.contains(fromStatus.trim().toLowerCase())) {
      return const _AdvanceConfirmation(
        heading: 'Accept this order?',
        subtext: 'This will start preparing the order.',
        confirmLabel: 'Accept',
      );
    }

    if (toStatus == 'item_to_collect') {
      return const _AdvanceConfirmation(
        heading: 'Mark order as ready?',
        subtext: 'This will notify the customer their order is ready to '
            'collect.',
        confirmLabel: 'Ready',
      );
    }

    if (toStatus == 'completed') {
      return const _AdvanceConfirmation(
        heading: PosCompleteConfirmationDialog.heading,
        subtext: PosCompleteConfirmationDialog.subtext,
        confirmLabel: PosCompleteConfirmationDialog.confirmLabel,
      );
    }

    // on_hold -> preparing (Resume): un-pausing is not progressing the order.
    return null;
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
