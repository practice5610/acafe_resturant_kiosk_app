import 'dart:async';

import 'package:acafe_customer/common/widgets/custom_image_widget.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_manager_repo.dart';
import 'package:acafe_customer/features/pos/domain/pos_advance_outcome.dart';
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_order_card.dart';
import 'package:acafe_customer/features/pos/domain/pos_order_detail.dart';
import 'package:acafe_customer/features/pos/domain/pos_order_detail_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_item_prep_status.dart';
import 'package:acafe_customer/features/pos/domain/pos_order_grouping.dart';
import 'package:acafe_customer/features/pos/domain/pos_orders_repo.dart';
import 'package:acafe_customer/features/pos/widgets/pos_item_status_widgets.dart';
import 'package:acafe_customer/features/pos/widgets/pos_order_more_menu.dart';
import 'package:acafe_customer/features/pos/widgets/pos_order_source_icon.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';

/// The Orders board detail overlay — Figma **1641:4341** (App / NEW),
/// **1641:4490** (Kiosk), **1641:4640** (Cashier) and **1641:5129**
/// (In Progress).
///
/// Those four frames are **one modal on two independent axes**, so this is one
/// widget with two conditionals rather than four screens:
///
///   * source — `channelKey` picks the badge glyph and label, delegated whole
///     to [PosOrderSourceIcon] so the badge here and the badge on the board
///     card can never disagree about what a channel looks like.
///   * status — `orderStatus` picks the badge colour and the action.
///
/// The action is **not** hardcoded to "Mark as complete" the way Figma draws
/// it. Both its label and its target come from [PosOrderGrouping], the same
/// ladder the board card runs, so opening a card and opening its modal always
/// offer the same next step. A `preparing` order's next rung is
/// `item_to_collect`, not `completed`; labelling that "complete" would claim
/// an order was handed over when the customer has had nothing, and would skip
/// the `ready_at` stamp and the "ready to collect" push that rung fires.
///
/// Sections the mock always draws are omitted when the order has nothing real
/// behind them — see [PosOrderDetail.hasContact] and
/// [PosOrderDetail.displayNote]. Most orders are guests with no contact row at
/// all, so drawing an empty card would be the common case, not the edge one.
class PosOrderDetailOverlay extends StatefulWidget {
  final PosOrderCard order;
  final KioskManagerRepo repo;

  /// Item-status writes. Separate from [repo] because the board's own repo is
  /// where the order endpoints live; the receipts repo only reads.
  final PosOrdersRepo ordersRepo;

  /// Ask the board to refetch. Called after every successful item write so the
  /// card behind the overlay never lags the modal on top of it.
  final VoidCallback? onChanged;

  /// Pause / cancel, routed through the board so the confirmation and the error
  /// handling stay in one place. Returns null on success, or a message.
  final Future<String?> Function(PosOrderCard order, String status)? onSetStatus;

  /// Lets the board push an `order.changed` for THIS order straight into the
  /// overlay, so a kitchen change lands immediately instead of waiting out the
  /// remainder of the 10s poll. Registered on mount, released on dispose.
  final void Function(VoidCallback listener)? registerRefresh;
  final void Function(VoidCallback listener)? unregisterRefresh;

  /// Runs the transition. Supplied by the board as its own gated `_advance`,
  /// not the provider method underneath it — so the completion confirmation
  /// the board shows is the same one this CTA shows, and neither surface can
  /// grow a second completion path.
  ///
  /// The three outcomes are distinct on purpose: a cancelled confirmation must
  /// leave this overlay open and untouched, which a null-means-success return
  /// could not express.
  final Future<PosAdvanceResult> Function(PosOrderCard order)? onAdvance;

  const PosOrderDetailOverlay({
    super.key,
    required this.order,
    required this.repo,
    required this.ordersRepo,
    this.onAdvance,
    this.onChanged,
    this.onSetStatus,
    this.registerRefresh,
    this.unregisterRefresh,
  });

  @override
  State<PosOrderDetailOverlay> createState() => _PosOrderDetailOverlayState();
}

/// Per-item state the rows rebuild on.
///
/// One notifier pair per line rather than one `setState` for the modal: tapping
/// Done on a five-item order should repaint that row's chip and button, not
/// re-run the header, the money block and four untouched siblings. The rows
/// listen; the overlay writes.
class _ItemCell {
  final ValueNotifier<PrepStatus> status;
  final ValueNotifier<bool> busy;

  _ItemCell(PrepStatus initial)
      : status = ValueNotifier<PrepStatus>(initial),
        busy = ValueNotifier<bool>(false);

  void dispose() {
    status.dispose();
    busy.dispose();
  }
}

class _PosOrderDetailOverlayState extends State<PosOrderDetailOverlay> {
  PosOrderDetail? _detail;
  String? _error;
  bool _loading = true;
  bool _advancing = false;

  /// How often an open overlay re-reads the order. Matches the kitchen's own
  /// cadence (AppConstants.kitchenPollSeconds), so a change made on either
  /// screen surfaces on the other inside the same window.
  static const Duration _pollInterval = Duration(seconds: 10);

  Timer? _poll;

  /// Guards against overlapping reads: a slow tick must not stack a second
  /// request on the first, and a response from a superseded request must not
  /// repaint over a newer one.
  bool _fetching = false;
  int _fetchId = 0;

  /// Line id → its own notifiers.
  final Map<int, _ItemCell> _cells = <int, _ItemCell>{};

  /// Items with a write in flight. A poll landing mid-write must not drag the
  /// chip back to the value the server had before the write -- the same rule
  /// the kitchen applies in `_mergeItemStatesIntoCache`
  /// (order_controller.dart:521-540).
  final Set<int> _inFlight = <int>{};

  /// Order-level state the action bar and the progress header listen to,
  /// separate from the per-item notifiers so a single item move repaints the
  /// bar without rebuilding the rows.
  late final ValueNotifier<String> _orderStatus =
      ValueNotifier<String>(widget.order.orderStatus);
  late final ValueNotifier<PrepProgress> _progress =
      ValueNotifier<PrepProgress>(widget.order.progress);

  /// True while the whole order is blocked -- on hold, or a bulk write running.
  final ValueNotifier<bool> _orderBusy = ValueNotifier<bool>(false);

  bool get _locked =>
      _orderStatus.value == 'on_hold' ||
      _orderStatus.value == 'completed' ||
      _orderStatus.value == 'canceled';

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(_pollInterval, (_) => _load(silent: true));
    widget.registerRefresh?.call(_onExternalChange);
  }

  /// A socket push for this order: re-read now rather than waiting out the
  /// poll. Silent, and subject to the same in-flight and staleness guards.
  void _onExternalChange() {
    if (!mounted) return;
    unawaited(_load(silent: true));
  }

  @override
  void dispose() {
    widget.unregisterRefresh?.call(_onExternalChange);
    _poll?.cancel();
    for (final _ItemCell cell in _cells.values) {
      cell.dispose();
    }
    _orderStatus.dispose();
    _progress.dispose();
    _orderBusy.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    // A tick that arrives while the previous read is still out is dropped
    // rather than queued; the next one is only 10s away.
    if (silent && _fetching) return;

    final int fetchId = ++_fetchId;
    _fetching = true;

    final apiResponse = await widget.repo.getTransactionDetail(widget.order.id);

    _fetching = false;
    if (!mounted || fetchId != _fetchId) return;

    final response = apiResponse.response;

    if (response != null && response.statusCode == 200 && response.data is Map) {
      final PosOrderDetail detail = PosOrderDetail.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );

      _syncCells(detail);

      setState(() {
        _detail = detail;
        _error = null;
        _loading = false;
      });
      return;
    }

    // A failed silent refresh leaves what is on screen alone: the operator is
    // reading this order, and blanking it over one dropped poll is worse than
    // showing a value that is at most ten seconds stale.
    if (silent) return;

    setState(() {
      _error = apiResponse.error?.toString() ?? 'Could not load this order';
      _loading = false;
    });
  }

  /// Fold a freshly-read order into the per-item notifiers.
  ///
  /// Items with a write in flight keep their optimistic value -- their own
  /// response is the one allowed to settle them.
  void _syncCells(PosOrderDetail detail) {
    for (final PosOrderDetailItem item in detail.items) {
      final int? id = item.id;
      if (id == null) continue;

      final _ItemCell cell = _cells.putIfAbsent(
        id,
        () => _ItemCell(item.prepStatus),
      );
      if (_inFlight.contains(id)) continue;
      cell.status.value = item.prepStatus;
    }

    _orderStatus.value = detail.orderStatus;
    _progress.value = detail.progress;
  }

  /// Current per-item statuses, in the order the lines are drawn.
  List<PrepStatus> get _statuses {
    final PosOrderDetail? detail = _detail;
    if (detail == null) return const <PrepStatus>[];
    return detail.items
        .map((i) => i.id == null
            ? i.prepStatus
            : (_cells[i.id]?.status.value ?? i.prepStatus))
        .toList(growable: false);
  }

  // ── Item writes ───────────────────────────────────────────────────────

  /// Move one line, optimistically.
  ///
  /// The optimistic value is applied before the request so the chip answers the
  /// tap immediately, and the id is marked in flight before the first await so
  /// a poll cannot clobber it in the gap.
  Future<void> _setItemStatus(int detailId, PrepStatus target) async {
    final _ItemCell? cell = _cells[detailId];
    if (cell == null || cell.busy.value || _orderBusy.value || _locked) return;

    final PrepStatus original = cell.status.value;

    _inFlight.add(detailId);
    cell.busy.value = true;
    cell.status.value = target;

    final apiResponse = await widget.ordersRepo.updateItemStatus(
      orderId: widget.order.id,
      orderDetailId: detailId,
      status: target.wire,
    );

    if (!mounted) {
      _inFlight.remove(detailId);
      return;
    }

    cell.busy.value = false;
    final response = apiResponse.response;
    final int? code = response?.statusCode;

    if (response != null && code == 200 && response.data is Map) {
      _applyWriteResult(Map<String, dynamic>.from(response.data as Map));
      _inFlight.remove(detailId);
      widget.onChanged?.call();
      return;
    }

    _inFlight.remove(detailId);
    _handleWriteFailure(response, apiResponse, fallback: () {
      cell.status.value = original;
    });
  }

  /// Bulk: start everything, or mark everything ready.
  Future<void> _bulkItemStatus(PrepStatus target) async {
    if (_orderBusy.value || _locked) return;

    _orderBusy.value = true;

    final apiResponse = await widget.ordersRepo.bulkUpdateItemStatus(
      orderId: widget.order.id,
      status: target.wire,
    );

    if (!mounted) return;
    _orderBusy.value = false;

    final response = apiResponse.response;
    if (response != null && response.statusCode == 200 && response.data is Map) {
      _applyWriteResult(Map<String, dynamic>.from(response.data as Map));
      widget.onChanged?.call();
      return;
    }

    // Nothing to roll back: a bulk move is not applied optimistically, because
    // "which items actually moved" is the server's forward-only decision, not
    // something the client can predict.
    _handleWriteFailure(response, apiResponse);
  }

  /// Fold an item-status response back onto the overlay. The response carries
  /// every line's state plus the resulting order status, so one write settles
  /// the whole modal without a follow-up read.
  void _applyWriteResult(Map<String, dynamic> body) {
    final List<dynamic> states = body['item_states'] as List? ?? const [];
    final List<PosOrderDetailItem> updated = <PosOrderDetailItem>[];

    for (final dynamic raw in states) {
      if (raw is! Map) continue;
      final int? id = int.tryParse('${raw['id']}');
      if (id == null) continue;
      final PrepStatus status = PrepStatus.fromWire(raw['prep_status']);

      // An item still mid-write keeps its own optimistic value; its response
      // is the one that settles it.
      if (!_inFlight.contains(id)) {
        _cells[id]?.status.value = status;
      }
    }

    final String? orderStatus = body['order_status']?.toString();
    if (orderStatus != null && orderStatus.isNotEmpty) {
      _orderStatus.value = orderStatus;
    }

    final int? ready = int.tryParse('${body['items_ready']}');
    final int? total = int.tryParse('${body['items_total']}');
    if (ready != null && total != null && total > 0) {
      _progress.value = PrepProgress(ready: ready, total: total);
    } else {
      _progress.value = PrepProgress.fromStatuses(_statuses);
    }

    // Keep the model in step so a rebuild from any other cause redraws the
    // same thing the notifiers are showing.
    final PosOrderDetail? detail = _detail;
    if (detail != null) {
      updated.addAll(detail.items.map((item) {
        final int? id = item.id;
        if (id == null) return item;
        final PrepStatus? now = _cells[id]?.status.value;
        return now == null ? item : item.withPrepStatus(now);
      }));
      _detail = detail.copyWith(
        orderStatus: _orderStatus.value,
        items: updated,
        itemsReady: _progress.value.ready,
        itemsTotal: _progress.value.total,
      );
    }
  }

  /// One place for every non-200 on an item write.
  void _handleWriteFailure(
    dynamic response,
    dynamic apiResponse, {
    VoidCallback? fallback,
  }) {
    final int? code = response?.statusCode;
    final dynamic data = response?.data;
    final Map<String, dynamic>? error = _firstError(data);
    final String errorCode = '${error?['code'] ?? ''}';

    // Stale tap: the row moved under us. The rejection carries the state the
    // row really holds, so the chip corrects itself rather than snapping back
    // to a value that is equally wrong.
    if (code == 409 && errorCode == 'stale_transition') {
      final PrepStatus current = PrepStatus.fromWire(error?['prep_status']);
      final int? detailId = _staleDetailId(error);
      if (detailId != null) {
        _cells[detailId]?.status.value = current;
      }
      _toast('Updated elsewhere — refreshed');
      unawaited(_load(silent: true));
      return;
    }

    // The whole order is frozen (held, completed or cancelled elsewhere).
    // Re-reading settles the real status, which disables every item action.
    if (code == 409 && errorCode == 'order_locked') {
      fallback?.call();
      _toast(error?['message']?.toString() ?? 'This order is not editable right now');
      unawaited(_load(silent: true));
      return;
    }

    fallback?.call();
    _toast(
      error?['message']?.toString() ??
          apiResponse?.error?.toString() ??
          'Could not update the item',
    );
  }

  /// The line a stale rejection refers to: the one write we had in flight.
  int? _staleDetailId(Map<String, dynamic>? error) {
    final int? explicit = int.tryParse('${error?['order_detail_id']}');
    if (explicit != null) return explicit;
    return _inFlight.length == 1 ? _inFlight.first : null;
  }

  static Map<String, dynamic>? _firstError(dynamic data) {
    if (data is! Map) return null;
    final dynamic errors = data['errors'];
    if (errors is List && errors.isNotEmpty && errors.first is Map) {
      return Map<String, dynamic>.from(errors.first as Map);
    }
    return null;
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: PosOrderDetailSpec.ink,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  // ── Order-level side exits (pause / resume / cancel) ──────────────────

  Future<void> _setOrderStatus(String status) async {
    final Future<String?> Function(PosOrderCard, String)? handler =
        widget.onSetStatus;
    if (handler == null || _orderBusy.value) return;

    _orderBusy.value = true;
    final String? error =
        await handler(widget.order.withStatus(_orderStatus.value), status);
    if (!mounted) return;
    _orderBusy.value = false;

    if (error != null) {
      _toast(error);
      return;
    }

    widget.onChanged?.call();

    // Cancelling ends the operator's business with this order, so the modal
    // closes; pausing does not, so it stays open and re-reads.
    if (status == 'canceled') {
      Navigator.of(context).maybePop();
      return;
    }
    unawaited(_load(silent: true));
  }

  String get _status => _orderStatus.value;

  Future<void> _advance() async {
    final Future<PosAdvanceResult> Function(PosOrderCard)? onAdvance =
        widget.onAdvance;
    if (onAdvance == null || _advancing) return;

    setState(() => _advancing = true);
    final PosAdvanceResult result =
        await onAdvance(widget.order.withStatus(_status));
    if (!mounted) return;

    setState(() => _advancing = false);

    if (result.isAdvanced) {
      Navigator.of(context).maybePop();
      return;
    }

    // Declined confirmation: the operator is still looking at this order, so
    // the overlay stays exactly as it was and nothing is reported.
    if (!result.isFailed) return;

    _toast('Order #${widget.order.id}: ${result.message}');
  }

  @override
  Widget build(BuildContext context) {
    final Size window = MediaQuery.sizeOf(context);
    final double maxWidth = window.width - PosOrderDetailSpec.viewportInset * 2;
    final double maxHeight = window.height - PosOrderDetailSpec.viewportInset * 2;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Tapping the dim closes, matching every other POS overlay.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).maybePop(),
              child: const ColoredBox(color: PosOrderDetailSpec.backdrop),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxWidth < PosOrderDetailSpec.modalWidth
                    ? maxWidth
                    : PosOrderDetailSpec.modalWidth,
                maxHeight: maxHeight < PosOrderDetailSpec.modalHeight
                    ? maxHeight
                    : PosOrderDetailSpec.modalHeight,
              ),
              // Swallows taps so a click inside the card does not hit the
              // dismiss layer underneath.
              child: GestureDetector(
                onTap: () {},
                child: Container(
                  decoration: BoxDecoration(
                    color: PosOrderDetailSpec.modalBg,
                    borderRadius: BorderRadius.circular(
                      PosOrderDetailSpec.modalRadius,
                    ),
                    border: Border.all(
                      color: PosOrderDetailSpec.hairline,
                      width: PosOrderDetailSpec.modalBorder,
                    ),
                    boxShadow: PosOrderDetailSpec.modalShadow,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Header(
                        orderId: widget.order.id,
                        status: _status,
                        createdAt: _detail?.createdAt ?? widget.order.createdAt,
                        channelKey:
                            _detail?.channelKey ?? widget.order.channelKey,
                        onClose: () => Navigator.of(context).maybePop(),
                      ),
                      Flexible(child: _body()),
                      _actionBar(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The body, sized so the modal settles rather than snaps.
  ///
  /// The overlay opens before the order has been fetched, so its height changes
  /// exactly once — when the response lands. Two things make that change calm:
  /// the placeholders below are a *definite* height (a bare `Center` inside the
  /// `Flexible` above stretches to the modal's full 718px budget, so the first
  /// frame was drawn at full height and the loaded frame collapsed back), and
  /// this `AnimatedSize` interpolates whatever difference is left.
  Widget _body() {
    return AnimatedSize(
      duration: PosOrderDetailSpec.bodyResizeAnimation,
      curve: Curves.easeOutCubic,
      // Grow downwards from the header rather than from the middle, so the
      // content already on screen does not drift while the rest arrives.
      alignment: Alignment.topCenter,
      child: _bodyContent(),
    );
  }

  Widget _bodyContent() {
    if (_loading) {
      return const SizedBox(
        height: PosOrderDetailSpec.bodyPlaceholderHeight,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final PosOrderDetail? detail = _detail;

    if (detail == null) {
      return SizedBox(
        height: PosOrderDetailSpec.bodyPlaceholderHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: PosOrderDetailSpec.bodyPad * 2,
          ),
          child: Center(
            child: Text(
              _error ?? 'Could not load this order',
              textAlign: TextAlign.center,
              style: loewRegular.copyWith(
                fontSize: PosOrderDetailSpec.contactTextSize,
                color: PosOrderDetailSpec.inkAlpha(0.6),
              ),
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool stacked = constraints.maxWidth <
            PosOrderDetailSpec.stackColumnsBelowWidth;

        final Widget left = _leftColumn(detail);
        final Widget right = _itemsSection(detail);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(PosOrderDetailSpec.bodyPad),
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    left,
                    const SizedBox(height: PosOrderDetailSpec.columnGap),
                    right,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: left),
                    const SizedBox(width: PosOrderDetailSpec.columnGap),
                    SizedBox(
                      width: PosOrderDetailSpec.rightColumnWidth,
                      child: right,
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _leftColumn(PosOrderDetail detail) {
    final List<Widget> sections = <Widget>[];

    // Both sections are conditional: a guest order has no contact row, and most
    // notes are the name-carrier string already shown in the header.
    if (detail.hasContact) {
      sections.add(_customerSection(detail));
    }

    final String? note = detail.displayNote;
    if (note != null) {
      sections.add(_notesSection(note));
    }

    sections.add(_totalsSection(detail));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < sections.length; i++) ...[
          if (i > 0) const SizedBox(height: PosOrderDetailSpec.leftSectionGap),
          sections[i],
        ],
      ],
    );
  }

  Widget _customerSection(PosOrderDetail detail) {
    return _Section(
      label: 'Customer Details',
      gap: PosOrderDetailSpec.sectionLabelGap,
      child: Container(
        padding: const EdgeInsets.all(PosOrderDetailSpec.customerCardPad),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(PosOrderDetailSpec.customerCardRadius),
          border: Border.all(color: PosOrderDetailSpec.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (detail.customerName.isNotEmpty)
              Text(
                detail.customerName,
                style: loewExtraBold.copyWith(
                  fontSize: PosOrderDetailSpec.customerNameSize,
                  color: PosOrderDetailSpec.ink,
                ),
              ),
            const SizedBox(height: PosOrderDetailSpec.customerCardGap),
            if (detail.customerPhone != null)
              _ContactRow(
                icon: Icons.phone_outlined,
                value: detail.customerPhone!,
              ),
            if (detail.customerPhone != null && detail.customerEmail != null)
              const SizedBox(height: PosOrderDetailSpec.contactLineGap),
            if (detail.customerEmail != null)
              _ContactRow(
                icon: Icons.mail_outline,
                value: detail.customerEmail!,
              ),
          ],
        ),
      ),
    );
  }

  Widget _notesSection(String note) {
    return _Section(
      label: 'Order Notes',
      gap: PosOrderDetailSpec.customerCardGap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(PosOrderDetailSpec.notePad),
        decoration: BoxDecoration(
          color: PosOrderDetailSpec.noteBg,
          borderRadius: BorderRadius.circular(PosOrderDetailSpec.noteRadius),
          border: Border.all(color: PosOrderDetailSpec.noteBorder),
        ),
        child: Text(
          note,
          style: loewRegular.copyWith(
            fontSize: PosOrderDetailSpec.noteTextSize,
            height: PosOrderDetailSpec.noteLineHeight /
                PosOrderDetailSpec.noteTextSize,
            color: PosOrderDetailSpec.ink,
          ),
        ),
      ),
    );
  }

  /// Not in Figma's modal, but the three figures are already in the payload and
  /// already reconcile with what was charged. Added under the left column,
  /// where the mock leaves space, rather than left off a screen whose whole job
  /// is "everything about this order".
  Widget _totalsSection(PosOrderDetail detail) {
    return _Section(
      label: 'Total',
      gap: PosOrderDetailSpec.customerCardGap,
      child: Container(
        padding: const EdgeInsets.all(PosOrderDetailSpec.customerCardPad),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(PosOrderDetailSpec.customerCardRadius),
          border: Border.all(color: PosOrderDetailSpec.hairline),
        ),
        child: Column(
          children: [
            _TotalRow(label: 'Subtotal', value: detail.subtotal),
            if (detail.discount > 0) ...[
              const SizedBox(height: PosOrderDetailSpec.contactLineGap),
              _TotalRow(label: 'Discount', value: -detail.discount),
            ],
            const SizedBox(height: PosOrderDetailSpec.customerCardGap),
            _TotalRow(label: 'Total', value: detail.total, emphasised: true),
          ],
        ),
      ),
    );
  }

  Widget _itemsSection(PosOrderDetail detail) {
    return _Section(
      label: 'Order Items',
      gap: PosOrderDetailSpec.itemsLabelGap,
      // "2 of 3 ready" rides on the section header rather than taking a row of
      // its own, so adding progress costs the items list no vertical space.
      trailing: ValueListenableBuilder<PrepProgress>(
        valueListenable: _progress,
        builder: (_, progress, __) => PosItemProgressLabel(progress: progress),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ValueListenableBuilder<PrepProgress>(
            valueListenable: _progress,
            builder: (_, progress, __) => PosItemProgressBar(progress: progress),
          ),
          ValueListenableBuilder<String>(
            valueListenable: _orderStatus,
            builder: (_, status, __) => status == 'on_hold'
                ? const PosOnHoldBanner()
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: PosOrderDetailSpec.progressGap),
          for (final PosOrderDetailItem item in detail.items)
            _liveItemRow(item),
        ],
      ),
    );
  }

  /// One item row bound to its own notifiers.
  ///
  /// A line the server could not address (no id) still renders -- it simply
  /// shows its status and offers no action, rather than disappearing.
  Widget _liveItemRow(PosOrderDetailItem item) {
    final int? id = item.id;
    final _ItemCell? cell = id == null ? null : _cells[id];

    if (cell == null) {
      return _ItemRow(
        item: item,
        status: item.prepStatus,
        busy: false,
        enabled: false,
        onAction: null,
      );
    }

    return ValueListenableBuilder<PrepStatus>(
      valueListenable: cell.status,
      builder: (_, status, __) => ValueListenableBuilder<bool>(
        valueListenable: cell.busy,
        builder: (_, busy, __) => ValueListenableBuilder<bool>(
          valueListenable: _orderBusy,
          builder: (_, orderBusy, __) => ValueListenableBuilder<String>(
            valueListenable: _orderStatus,
            builder: (_, __, ___) => _ItemRow(
              item: item,
              status: status,
              busy: busy,
              enabled: !orderBusy && !_locked,
              onAction: (target) => _setItemStatus(id!, target),
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionBar() {
    return ValueListenableBuilder<String>(
      valueListenable: _orderStatus,
      builder: (_, __, ___) => ValueListenableBuilder<PrepProgress>(
        valueListenable: _progress,
        builder: (_, ____, _____) => ValueListenableBuilder<bool>(
          valueListenable: _orderBusy,
          builder: (_, orderBusy, ______) => _buildActionBar(orderBusy),
        ),
      ),
    );
  }

  /// The primary CTA, and the secondary menu beside it.
  ///
  /// The forward rungs are driven by the **items**, not by writing
  /// `order_status`: "Start all items" and "Mark all ready" bulk-move the
  /// lines and let `KitchenOrderProgressService` derive the order status, which
  /// is exactly what happens when the kitchen does the same thing. Only the
  /// last rung -- handing the order over -- is still an order-level write,
  /// because "collected" is not a fact about any item.
  Widget _buildActionBar(bool orderBusy) {
    final PosBulkItemAction? bulk = PosBulkItemAction.forStatuses(_statuses);
    final String? orderLabel = PosOrderGrouping.actionLabelFor(_status);

    // While held, the order offers no forward action at all -- Resume comes
    // from the More menu, the same place the kitchen puts it.
    final bool held = _status == 'on_hold';

    final String? label = held
        ? null
        : (bulk?.label ?? (_status == 'item_to_collect' ? orderLabel : null));

    final Widget primary = label == null
        ? _StatusLabel(status: _status)
        : _ActionButton(
            label: label,
            busy: _advancing || orderBusy,
            onTap: bulk != null
                ? () => _bulkItemStatus(bulk.target)
                : (widget.onAdvance == null ? null : _advance),
          );

    return Container(
      padding: const EdgeInsets.fromLTRB(
        PosOrderDetailSpec.barPadH,
        PosOrderDetailSpec.barPadTop,
        PosOrderDetailSpec.barPadH,
        PosOrderDetailSpec.barPadBottom,
      ),
      decoration: const BoxDecoration(
        color: PosOrderDetailSpec.cream,
        border: Border(
          top: BorderSide(
            color: PosOrderDetailSpec.ink,
            width: PosOrderDetailSpec.barTopBorder,
          ),
        ),
      ),
      child: Row(
        children: [
          // Pause / Resume / Cancel sit behind a ⋯ so they never compete with
          // the forward action, which is what staff reach for all day.
          if (widget.onSetStatus != null && _canUseMoreMenu)
            Padding(
              padding: const EdgeInsets.only(
                right: PosOrderDetailSpec.moreMenuGap,
              ),
              child: PosOrderMoreButton(
                enabled: !orderBusy,
                onSelected: _onMoreAction,
                isHeld: _status == 'on_hold',
              ),
            ),
          Expanded(child: primary),
        ],
      ),
    );
  }

  /// The menu is pointless once the order is finished -- there is nothing left
  /// to pause or cancel. Mirrors the kitchen's own rule, which never opens its
  /// status menu for a completed or cancelled order
  /// (status_action_sheet.dart:18).
  bool get _canUseMoreMenu =>
      _status != 'completed' && _status != 'canceled';

  Future<void> _onMoreAction(PosOrderMenuAction action) async {
    switch (action) {
      case PosOrderMenuAction.hold:
        await _setOrderStatus('on_hold');
        break;
      case PosOrderMenuAction.resume:
        await _setOrderStatus('preparing');
        break;
      case PosOrderMenuAction.cancel:
        final bool confirmed = await showPosCancelOrderConfirm(
          context,
          orderId: widget.order.id,
        );
        if (!confirmed || !mounted) return;
        await _setOrderStatus('canceled');
        break;
    }
  }
}

// ── Header ─────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final int orderId;
  final String status;
  final DateTime? createdAt;
  final String channelKey;
  final VoidCallback onClose;

  const _Header({
    required this.orderId,
    required this.status,
    required this.createdAt,
    required this.channelKey,
    required this.onClose,
  });

  static Color _badgeColour(String status) {
    switch (PosOrderGrouping.sectionOf(status)) {
      case PosOrderSection.newOrders:
        return PosOrderDetailSpec.badgeNew;
      case PosOrderSection.inProgress:
        return PosOrderDetailSpec.badgeInProgress;
      case PosOrderSection.finished:
        return PosOrderDetailSpec.badgeFinished;
      case PosOrderSection.excluded:
        return PosOrderDetailSpec.inkAlpha(0.4);
    }
  }

  String get _clock {
    final DateTime? at = createdAt;
    if (at == null) return '';
    return '${at.hour.toString().padLeft(2, '0')}:'
        '${at.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final String sectionLabel =
        PosOrderGrouping.labelFor(PosOrderGrouping.sectionOf(status));

    return Container(
      padding: const EdgeInsets.fromLTRB(
        PosOrderDetailSpec.headerPadH,
        PosOrderDetailSpec.headerPadTop,
        PosOrderDetailSpec.headerPadH,
        PosOrderDetailSpec.headerPadBottom,
      ),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: PosOrderDetailSpec.hairline),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: PosOrderDetailSpec.headerGap,
              runSpacing: PosOrderDetailSpec.contactLineGap,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Order #$orderId',
                  style: loewExtraBold.copyWith(
                    fontSize: PosOrderDetailSpec.titleSize,
                    color: PosOrderDetailSpec.ink,
                  ),
                ),
                if (sectionLabel.isNotEmpty)
                  _Pill(
                    background: _badgeColour(status),
                    radius: PosOrderDetailSpec.statusBadgeRadius,
                    child: Text(
                      sectionLabel,
                      style: loewExtraBold.copyWith(
                        fontSize: PosOrderDetailSpec.statusBadgeTextSize,
                        color: PosOrderDetailSpec.cream,
                      ),
                    ),
                  ),
                if (_clock.isNotEmpty)
                  _Pill(
                    background: PosOrderDetailSpec.cream,
                    radius: PosOrderDetailSpec.timeBadgeRadius,
                    padH: PosOrderDetailSpec.timeBadgePadH,
                    child: Text(
                      _clock,
                      style: loewBold.copyWith(
                        fontSize: PosOrderDetailSpec.timeBadgeTextSize,
                        color: PosOrderDetailSpec.ink,
                      ),
                    ),
                  ),
                _Pill(
                  background: PosOrderDetailSpec.cream,
                  radius: PosOrderDetailSpec.sourceBadgeRadius,
                  border: PosOrderDetailSpec.hairline,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        PosOrderSourceIcon.iconFor(channelKey),
                        size: PosOrderDetailSpec.sourceIconSize,
                        color: PosOrderDetailSpec.ink,
                      ),
                      const SizedBox(width: PosOrderDetailSpec.sourceBadgeGap),
                      Text(
                        PosOrderSourceIcon.labelFor(channelKey),
                        style: loewExtraBold.copyWith(
                          fontSize: PosOrderDetailSpec.sourceTextSize,
                          color: PosOrderDetailSpec.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: PosOrderDetailSpec.headerGap),
          IconButton(
            onPressed: onClose,
            tooltip: 'Close',
            iconSize: PosOrderDetailSpec.closeSize,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: PosOrderDetailSpec.closeSize,
              minHeight: PosOrderDetailSpec.closeSize,
            ),
            icon: Icon(
              Icons.cancel_outlined,
              size: PosOrderDetailSpec.closeSize,
              color: PosOrderDetailSpec.inkAlpha(0.6),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pieces ─────────────────────────────────────────────────────────────

class _Pill extends StatelessWidget {
  final Widget child;
  final Color background;
  final double radius;
  final double padH;
  final Color? border;

  const _Pill({
    required this.child,
    required this.background,
    required this.radius,
    this.padH = PosOrderDetailSpec.statusBadgePadH,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: padH,
        vertical: PosOrderDetailSpec.statusBadgePadV,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(radius),
        border: border == null ? null : Border.all(color: border!),
      ),
      child: child,
    );
  }
}

class _Section extends StatelessWidget {
  final String label;
  final Widget child;
  final double gap;

  /// Optional right-aligned content on the header line (the items section puts
  /// its "n of m ready" here). Null keeps the original single-Text header.
  final Widget? trailing;

  const _Section({
    required this.label,
    required this.child,
    required this.gap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final Widget heading = Text(
      label.toUpperCase(),
      style: loewBold.copyWith(
        fontSize: PosOrderDetailSpec.sectionLabelSize,
        letterSpacing: PosOrderDetailSpec.sectionLabelTracking,
        color: PosOrderDetailSpec.inkAlpha(0.6),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (trailing == null)
          heading
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(child: heading),
              trailing!,
            ],
          ),
        SizedBox(height: gap),
        child,
      ],
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String value;

  const _ContactRow({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: PosOrderDetailSpec.contactIconSize,
          color: PosOrderDetailSpec.inkAlpha(0.6),
        ),
        const SizedBox(width: PosOrderDetailSpec.contactRowGap),
        Expanded(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: loewRegular.copyWith(
              fontSize: PosOrderDetailSpec.contactTextSize,
              color: PosOrderDetailSpec.inkAlpha(0.6),
            ),
          ),
        ),
      ],
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final double value;
  final bool emphasised;

  const _TotalRow({
    required this.label,
    required this.value,
    this.emphasised = false,
  });

  @override
  Widget build(BuildContext context) {
    final TextStyle style = (emphasised ? loewExtraBold : loewRegular).copyWith(
      fontSize: emphasised
          ? PosOrderDetailSpec.customerNameSize
          : PosOrderDetailSpec.contactTextSize,
      color: emphasised
          ? PosOrderDetailSpec.ink
          : PosOrderDetailSpec.inkAlpha(0.6),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(
          PosHomeSpec.formatPrice(value, padZero: false),
          style: style,
        ),
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  final PosOrderDetailItem item;

  /// Live state, not `item.prepStatus` — the row is driven by its notifier so
  /// an optimistic move shows before the server has answered.
  final PrepStatus status;
  final bool busy;
  final bool enabled;
  final void Function(PrepStatus target)? onAction;

  const _ItemRow({
    required this.item,
    required this.status,
    required this.busy,
    required this.enabled,
    required this.onAction,
  });

  /// `€ 4.50 · Cup` — the variation labels Figma appends after the price. A
  /// line with no variation just shows the price.
  String get _meta {
    final String price = PosHomeSpec.formatPrice(item.unitPrice, padZero: false);
    if (item.variationLabels.isEmpty) return price;
    return '$price · ${item.variationLabels.join(' · ')}';
  }

  /// One line per add-on plus the line's own instruction. Figma shows a single
  /// `+ Oat Milk`; a real line can carry several add-ons and a free-text note,
  /// and dropping them would hide what the kitchen was actually told.
  List<String> get _notes {
    return <String>[
      for (final PosOrderDetailAddon addon in item.addons)
        addon.quantity > 1 ? '${addon.quantity}× ${addon.name}' : addon.name,
      if (item.instruction != null && item.instruction!.trim().isNotEmpty)
        item.instruction!.trim(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final bool done = status.isDone;

    // A finished line goes quiet: struck through, dimmed and tinted. Kitchen's
    // treatment (order_ticket_card.dart:684-735) in POS colours.
    final Color bodyInk = done
        ? PosOrderDetailSpec.inkAlpha(0.45)
        : PosOrderDetailSpec.ink;
    final TextDecoration? strike = done ? TextDecoration.lineThrough : null;

    final PrepAction? action = status.next;

    return AnimatedContainer(
      duration: PosOrderDetailSpec.itemStateAnimation,
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: done ? PosOrderDetailSpec.itemDoneRowBg : Colors.transparent,
        border: const Border(
          bottom: BorderSide(color: PosOrderDetailSpec.itemDivider),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: PosOrderDetailSpec.itemRowPadH,
          vertical: PosOrderDetailSpec.itemRowPadV,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Status accent, inside the existing padding so the row keeps its
            // width and nothing below it shifts when the colour changes.
            AnimatedContainer(
              duration: PosOrderDetailSpec.itemStateAnimation,
              curve: Curves.easeOut,
              width: PosOrderDetailSpec.itemAccentWidth,
              height: PosOrderDetailSpec.itemThumbHeight,
              decoration: BoxDecoration(
                color: status.color,
                borderRadius: BorderRadius.circular(
                  PosOrderDetailSpec.itemAccentRadius,
                ),
              ),
            ),
            const SizedBox(width: PosOrderDetailSpec.itemRowGap),
            AnimatedOpacity(
              duration: PosOrderDetailSpec.itemStateAnimation,
              opacity: done ? PosOrderDetailSpec.itemDoneThumbOpacity : 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                  PosOrderDetailSpec.itemThumbRadius,
                ),
                child: SizedBox(
                  width: PosOrderDetailSpec.itemThumbWidth,
                  height: PosOrderDetailSpec.itemThumbHeight,
                  child: CustomImageWidget(
                    image: item.image ?? '',
                    width: PosOrderDetailSpec.itemThumbWidth,
                    height: PosOrderDetailSpec.itemThumbHeight,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(width: PosOrderDetailSpec.itemRowGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: PosOrderDetailSpec.itemStateAnimation,
                    style: loewExtraBold.copyWith(
                      fontSize: PosOrderDetailSpec.itemNameSize,
                      color: bodyInk,
                      decoration: strike,
                      decorationColor: bodyInk,
                    ),
                    child: Text(
                      item.quantity > 1
                          ? '${item.quantity}× ${item.name}'
                          : item.name,
                      // Two lines then ellipsis: a long name must never push
                      // the chip and the action off the row.
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: PosOrderDetailSpec.itemDetailGap),
                  Text(
                    _meta,
                    style: loewRegular.copyWith(
                      fontSize: PosOrderDetailSpec.itemMetaSize,
                      color: done
                          ? PosOrderDetailSpec.inkAlpha(0.45)
                          : PosOrderDetailSpec.inkAlpha(0.6),
                      decoration: strike,
                      decorationColor: PosOrderDetailSpec.inkAlpha(0.45),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Only drawn where the line actually has add-ons or a note.
                  for (final String note in _notes) ...[
                    const SizedBox(height: PosOrderDetailSpec.itemDetailGap),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '+',
                          style: loewRegular.copyWith(
                            fontSize: PosOrderDetailSpec.itemMetaSize,
                            color: done
                                ? PosOrderDetailSpec.inkAlpha(0.45)
                                : PosOrderDetailSpec.itemNoteInk,
                          ),
                        ),
                        const SizedBox(
                          width: PosOrderDetailSpec.itemDetailGap,
                        ),
                        Expanded(
                          child: Text(
                            note,
                            style: loewRegular.copyWith(
                              fontSize: PosOrderDetailSpec.itemNoteSize,
                              color: done
                                  ? PosOrderDetailSpec.inkAlpha(0.45)
                                  : PosOrderDetailSpec.itemNoteInk,
                              decoration: strike,
                              decorationColor:
                                  PosOrderDetailSpec.inkAlpha(0.45),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: PosOrderDetailSpec.itemStatusGap),
            PosItemStatusChip(status: status),
            if (action != null && onAction != null) ...[
              const SizedBox(width: PosOrderDetailSpec.itemStatusGap),
              PosItemActionButton(
                action: action,
                busy: busy,
                enabled: enabled,
                onTap: () => onAction!(action.target),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final bool busy;
  final VoidCallback? onTap;

  const _ActionButton({required this.label, required this.busy, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PosOrderDetailSpec.ink,
      borderRadius: BorderRadius.circular(PosOrderDetailSpec.actionRadius),
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(PosOrderDetailSpec.actionRadius),
        child: SizedBox(
          height: PosOrderDetailSpec.actionHeight,
          child: Center(
            child: busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    label,
                    style: loewBold.copyWith(
                      fontSize: PosOrderDetailSpec.actionTextSize,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// What a finished order gets instead of a button: the state it reached.
class _StatusLabel extends StatelessWidget {
  final String status;

  const _StatusLabel({required this.status});

  String get _text {
    final String s = status.trim().toLowerCase();
    if (s == 'completed') return 'Completed';
    if (s == 'delivered') return 'Delivered';
    if (s == 'canceled') return 'Canceled';
    if (s.isEmpty) return '';
    return s[0].toUpperCase() + s.substring(1).replaceAll('_', ' ');
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: PosOrderDetailSpec.actionHeight,
      child: Center(
        child: Text(
          _text,
          style: loewBold.copyWith(
            fontSize: PosOrderDetailSpec.actionTextSize,
            color: PosOrderDetailSpec.inkAlpha(0.55),
          ),
        ),
      ),
    );
  }
}
