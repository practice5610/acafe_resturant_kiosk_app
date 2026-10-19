import 'dart:async';

import 'package:acafe_customer/common/models/api_response_model.dart';
import 'package:acafe_customer/features/pos/domain/pos_item_prep_status.dart';
import 'package:acafe_customer/features/pos/domain/pos_live_cache.dart';
import 'package:acafe_customer/features/pos/domain/pos_order_card.dart';
import 'package:acafe_customer/features/pos/domain/pos_order_filters.dart';
import 'package:acafe_customer/features/pos/domain/pos_order_grouping.dart';
import 'package:acafe_customer/features/pos/domain/pos_orders_repo.dart';
import 'package:acafe_customer/features/realtime/order_changed_event.dart';
import 'package:acafe_customer/features/realtime/product_realtime_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

/// State behind the POS Orders board.
///
/// Things here that are load-bearing and worth reading before changing:
///
///  * **the request-id staleness guard** — the same one
///    `KioskManagerProvider.loadTransactions` uses. A socket push and a typed
///    search can be in flight at once, and an older response landing last would
///    repaint the board with a queue that no longer exists.
///  * **optimistic moves are keyed by order id, not by list position** — a
///    refetch can reorder or drop rows underneath an in-flight action, and a
///    rollback that restored "whatever is at index 4" would corrupt an
///    unrelated card.
///  * **it outlives the screen.** Production registers ONE instance for the
///    app (see di_container), so switching tabs away and back finds the board,
///    its filters and its scroll-worthy data exactly as they were — no spinner,
///    no refetch-then-repaint. Two things keep that honest:
///     - it keeps following `order.changed` while the screen is hidden
///       ([attachRealtime]), on a slower debounce, so the board is already
///       current when the tab opens again;
///     - the default view (NOW, no filters) is written to [PosLiveCache], so a
///       cold start or a browser reload paints the last known board on its
///       first frame ([restore]) and refreshes silently behind it.
///    Filters live for the session only: a reload starts from the defaults, the
///    way a mobile app restarts.
///  * **it is scoped to the device session.** A different branch or device
///    ([scope]) drops everything — board, filters, snapshot — so one branch's
///    queue can never show on another's till.
class PosOrdersProvider extends ChangeNotifier {
  final PosOrdersRepo posOrdersRepo;

  PosOrdersProvider({
    required this.posOrdersRepo,
    PosLiveCache? cache,
    String? Function()? scope,
    bool Function()? realtimeConnected,
    DateTime Function()? clock,
  })  : _cache = cache,
        _scopeOf = scope,
        _realtimeConnected = realtimeConnected,
        _clock = clock ?? DateTime.now;

  final PosLiveCache? _cache;

  /// The device session this board belongs to ([PosLiveCache.scopeFor]); null
  /// while no branch is bound, and then nothing is written to disk.
  final String? Function()? _scopeOf;

  /// Whether the order socket is up right now. Null (a screen-scoped test
  /// provider) reads as "not live": the board then re-checks on every show and
  /// polls while visible, which is the safe side.
  final bool Function()? _realtimeConnected;

  final DateTime Function() _clock;

  static final DateFormat _wire = DateFormat('yyyy-MM-dd HH:mm:ss');

  static const String _snapshotSlot = 'orders';

  /// A board snapshot older than this is not painted. Long enough to cover an
  /// overnight terminal's first open (active orders legitimately run past
  /// midnight on the board), short enough that a till opened after a day off
  /// does not flash last week's queue.
  static const Duration snapshotMaxAge = Duration(hours: 12);

  /// With the socket up, a board synced this recently is current — showing it
  /// again does not re-fetch. Pushes keep it current between syncs.
  static const Duration liveRevalidateAfter = Duration(seconds: 15);

  /// The safety net when the socket is down (or websockets are off for this
  /// install): the visible board re-pulls on this pace instead of freezing.
  static const Duration fallbackPoll = Duration(seconds: 20);

  // ── Board state ──────────────────────────────────────────────────────
  List<PosOrderCard> _orders = const <PosOrderCard>[];
  List<PosOrderCard> get orders => _orders;

  Map<PosOrderSection, int> _counts = const <PosOrderSection, int>{};

  bool _loading = false;
  bool get loading => _loading;

  /// True only for the very first load, so a socket-driven refetch does not
  /// blank a board the operator is reading.
  bool get initialLoading => _loading && _orders.isEmpty && !_loaded;
  bool _loaded = false;
  bool get loaded => _loaded;

  String? _error;
  String? get error => _error;

  /// Orders with a status change in flight — the card shows a spinner and
  /// ignores further taps.
  final Set<int> _pending = <int>{};
  bool isPending(int orderId) => _pending.contains(orderId);

  // ── Filters ──────────────────────────────────────────────────────────
  /// Seeded to the start of today so the From field shows a real date on first
  /// paint rather than a placeholder — the same window the endpoint defaults to
  /// when no range is sent.
  late DateTime? _from = _startOfToday();
  DateTime? _to;

  /// True while From is "the start of today" by default rather than a date the
  /// operator picked. The board outlives the screen now, so a terminal left on
  /// overnight must roll its NOW window to the new day by itself — before, the
  /// screen was rebuilt (and From re-seeded) on every visit.
  bool _fromFollowsToday = true;

  DateTime _startOfToday() {
    final DateTime now = _clock();
    return DateTime(now.year, now.month, now.day);
  }

  /// The end of the device's today, on the same clock as [_startOfToday]. Sent
  /// as the NOW window's `date_to` so both bounds come from the device clock —
  /// otherwise the server fills `date_to` from its own clock, and a device that
  /// runs ahead of the server produces from > to and a spurious date-range 422.
  DateTime _endOfToday() {
    final DateTime now = _clock();
    return DateTime(now.year, now.month, now.day, 23, 59, 59);
  }
  DateTime? get from => _from;
  DateTime? get to => _to;

  /// "NOW" mode: the window ends at the present moment and follows it, rather
  /// than being pinned to a chosen end time.
  bool _now = true;
  bool get now => _now;

  /// The dropdown's own selection, tracked separately from `_from`/`_to` so it
  /// can be reset to `custom` the moment the operator edits the date fields
  /// directly — otherwise the pill would keep naming a preset ("Yesterday")
  /// next to a window it no longer describes.
  PosOrderDateRangePreset _datePreset = PosOrderDateRangePreset.custom;
  PosOrderDateRangePreset get datePreset => _datePreset;

  String _search = '';
  String get search => _search;

  String? _source;
  String? _type;
  String? _method;
  String? _status;
  PosOrderSection? _section;

  String? get source => _source;
  String? get type => _type;
  String? get method => _method;
  String? get status => _status;
  PosOrderSection? get section => _section;

  int _requestId = 0;
  Timer? _searchDebounce;

  /// Whether the server filters by the kitchen sections itself, learnt from
  /// the `counts` keys of its last answer. Until it has said so the board asks
  /// for the coarser section every backend accepts and splits it locally (see
  /// [PosOrderGrouping.legacyQueryValueFor]).
  bool _serverKnowsKitchenSections = false;

  /// Coalesces a burst of socket pushes into one refetch. A busy lunch service
  /// can land several `order.changed` frames in the same second (one order
  /// placed, two advanced from the kitchen); refetching per frame would put
  /// three identical board requests on the wire.
  Timer? _realtimeDebounce;

  static const Duration searchDebounce = Duration(milliseconds: 350);

  /// Push coalescing while the board is on screen.
  static const Duration realtimeDebounce = Duration(milliseconds: 400);

  /// Push coalescing while another tab is up. Nobody is watching, so a
  /// kitchen working a ticket item by item (one push per item) costs one
  /// refetch instead of one per item — and the board is still current well
  /// before anyone could switch back to it.
  static const Duration hiddenRealtimeDebounce = Duration(seconds: 2);

  // ── Session / visibility ─────────────────────────────────────────────
  String? _activeScope;
  bool _restoreAttempted = false;
  bool _visible = false;
  bool get visible => _visible;

  DateTime? _lastSyncAt;
  int _inFlight = 0;
  Timer? _poll;
  ProductRealtimeController? _realtime;

  // ── Counts ───────────────────────────────────────────────────────────
  int countOf(PosOrderSection section) => _counts[section] ?? 0;

  int get totalCount =>
      PosOrderGrouping.boardSections.fold(0, (sum, s) => sum + countOf(s));

  /// The cards for one section, newest first — the order the feed returns them.
  List<PosOrderCard> ordersIn(PosOrderSection section) =>
      _orders.where((o) => o.section == section).toList(growable: false);

  // ── Loading ──────────────────────────────────────────────────────────
  Future<void> load({bool silent = false}) async {
    _syncScope();
    if (_now && _fromFollowsToday) _from = _startOfToday();

    final int requestId = ++_requestId;

    if (!silent) {
      _loading = true;
      notifyListeners();
    }

    _inFlight++;
    final ApiResponseModel apiResponse;
    try {
      apiResponse = await posOrdersRepo.getOrders(
        dateFrom: _from == null ? null : _wire.format(_from!),
        // In NOW mode the end of the window is resolved at request time, not
        // when the toggle was pressed — otherwise a terminal left open over
        // lunch stops showing anything placed after the operator last touched
        // the filter. It is sent as the device's end-of-today rather than
        // omitted so both bounds share the device clock; letting the server fill
        // it from its own clock gives from > to (a date-range 422) whenever the
        // device runs ahead of the server.
        dateTo: _now
            ? _wire.format(_endOfToday())
            : (_to == null ? null : _wire.format(_to!)),
        search: _search.isEmpty ? null : _search,
        section: _section == null
            ? null
            : _serverKnowsKitchenSections
                ? PosOrderGrouping.queryValueFor(_section!)
                : PosOrderGrouping.legacyQueryValueFor(_section!),
        status: _status,
        source: _source,
        type: _type,
        method: _method,
      );
    } finally {
      _inFlight--;
    }

    if (requestId != _requestId) return;

    final response = apiResponse.response;
    if (response != null && response.statusCode == 200) {
      final data = Map<String, dynamic>.from(response.data as Map);
      _applyBoard(data);
      _error = null;
      _loaded = true;
      _lastSyncAt = _clock();
      _saveSnapshot(data);
    } else {
      _error = apiResponse.error?.toString() ?? 'Could not load orders';
      // The previous board is deliberately left on screen. A failed refresh
      // should not clear a queue the counter is working from.
    }

    _loading = false;
    notifyListeners();
  }

  /// One board answer — off the wire or off disk — into cards and counts.
  void _applyBoard(Map<String, dynamic> data) {
    final List raw = data['orders'] as List? ?? const [];

    _orders = raw
        .map((e) => PosOrderCard.fromJson(Map<String, dynamic>.from(e as Map)))
        // The endpoint already excludes off-board statuses; this is the
        // belt-and-braces so an unknown future status can never render as an
        // untitled section.
        .where((o) => o.section != PosOrderSection.excluded)
        .toList(growable: false);

    final counts = Map<String, dynamic>.from(data['counts'] as Map? ?? {});
    _serverKnowsKitchenSections = counts.containsKey(
        PosOrderGrouping.queryValueFor(PosOrderSection.preparing));
    // A backend that predates the kitchen sections only sends new /
    // in_progress / finished; its sections then count the cards it returned
    // rather than reading 0 above a row of orders.
    _counts = <PosOrderSection, int>{
      for (final PosOrderSection section in PosOrderGrouping.boardSections)
        section: counts.containsKey(PosOrderGrouping.queryValueFor(section))
            ? int.tryParse(
                    '${counts[PosOrderGrouping.queryValueFor(section)]}') ??
                0
            : _orders.where((o) => o.section == section).length,
    };
  }

  /// Only the view a fresh session opens on is worth a disk snapshot: it is
  /// the one [restore] can paint. A filtered board is the operator's own
  /// question and is re-asked over the network.
  bool get _isDefaultView =>
      _now &&
      _fromFollowsToday &&
      _datePreset == PosOrderDateRangePreset.custom &&
      _search.isEmpty &&
      _section == null &&
      _status == null &&
      _source == null &&
      _type == null &&
      _method == null;

  void _saveSnapshot(Map<String, dynamic> data) {
    final PosLiveCache? cache = _cache;
    final String? scope = _activeScope;
    if (cache == null || scope == null || !_isDefaultView) return;
    unawaited(cache.write(
      _snapshotSlot,
      scope: scope,
      data: <String, dynamic>{
        'orders': data['orders'] ?? const [],
        'counts': data['counts'] ?? const {},
      },
    ));
  }

  /// Refetch triggered by an `order.changed` push. Silent and debounced: the
  /// board updates under the operator without a spinner — and keeps updating
  /// while another tab is up, so it is current when the operator comes back.
  void onRealtimeChange() {
    _realtimeDebounce?.cancel();
    _realtimeDebounce = Timer(
      _visible ? realtimeDebounce : hiddenRealtimeDebounce,
      () => load(silent: true),
    );
  }

  /// A dropped socket cannot be reconciled from the events themselves — the
  /// ones missed while offline are gone — so a reconnect re-pulls the board.
  void onRealtimeReconnect() {
    _realtimeDebounce?.cancel();
    unawaited(load(silent: true));
  }

  // ── Session, visibility, realtime ────────────────────────────────────

  /// Paints the last known board without a request: what is in memory, else
  /// the disk snapshot for this device session. Returns whether anything
  /// changed.
  ///
  /// Does NOT notify — it is meant to run before the first frame that reads
  /// the board (a screen's initState), where a notify would mark an ancestor
  /// dirty mid-build. Callers outside a build notify on a true result.
  bool restore() {
    bool changed = _syncScope();
    if (_loaded || _restoreAttempted) return changed;
    _restoreAttempted = true;

    final PosLiveCache? cache = _cache;
    final String? scope = _activeScope;
    if (cache == null || scope == null || !_isDefaultView) return changed;

    final PosLiveSnapshot? snapshot =
        cache.read(_snapshotSlot, scope: scope, maxAge: snapshotMaxAge);
    if (snapshot == null) return changed;

    try {
      _applyBoard(snapshot.data);
      _loaded = true;
      changed = true;
    } catch (_) {
      // A snapshot this build cannot read is no snapshot; the network load
      // that follows paints the board.
      _orders = const <PosOrderCard>[];
      _counts = const <PosOrderSection, int>{};
    }
    return changed;
  }

  /// The screen is (or stops being) on screen.
  ///
  /// Showing it paints what is already known at once and re-checks the server
  /// behind it only when that knowledge could be stale. While shown with the
  /// socket down, it polls ([fallbackPoll]) rather than freezing.
  void setVisible(bool visible) {
    if (visible == _visible) return;
    _visible = visible;

    _poll?.cancel();
    _poll = null;
    if (!visible) return;

    if (restore()) notifyListeners();
    if (_needsRevalidate) unawaited(load(silent: _loaded));

    _poll = Timer.periodic(fallbackPoll, (_) {
      if (!_isLive && _inFlight == 0) unawaited(load(silent: true));
    });
  }

  /// Gets the board ready before anyone opens it (the POS shell calls this on
  /// mount), so the first visit to the tab is as instant as every later one.
  Future<void> warm() async {
    if (restore()) notifyListeners();
    if (_needsRevalidate) await load(silent: true);
  }

  /// Follow the branch order channel for as long as this store lives — not
  /// just while the screen is up. Idempotent.
  void attachRealtime(ProductRealtimeController controller) {
    if (identical(_realtime, controller)) return;
    _detachRealtime();
    _realtime = controller;
    controller.addOrderListener(_onOrderEvent);
    controller.addReconnectListener(onRealtimeReconnect);
  }

  void _detachRealtime() {
    _realtime?.removeOrderListener(_onOrderEvent);
    _realtime?.removeReconnectListener(onRealtimeReconnect);
    _realtime = null;
  }

  void _onOrderEvent(OrderChangedEvent event) => onRealtimeChange();

  bool get _isLive => _realtimeConnected?.call() ?? false;

  bool get _needsRevalidate {
    if (_inFlight > 0) return false;
    final DateTime? last = _lastSyncAt;
    if (last == null || !_isLive) return true;
    return _clock().difference(last) > liveRevalidateAfter;
  }

  /// Adopts the current device session, dropping everything that belonged to
  /// a different one. Returns whether state was dropped.
  bool _syncScope() {
    final String? scope = _scopeOf?.call();
    if (scope == _activeScope) return false;

    final bool hadSession = _activeScope != null;
    _activeScope = scope;
    if (!hadSession) return false;

    // Another branch or device: its board, filters and in-flight answers are
    // not this session's.
    _requestId++;
    _orders = const <PosOrderCard>[];
    _counts = const <PosOrderSection, int>{};
    _loaded = false;
    _loading = false;
    _error = null;
    _pending.clear();
    _lastSyncAt = null;
    _restoreAttempted = false;
    _serverKnowsKitchenSections = false;
    _searchDebounce?.cancel();
    _realtimeDebounce?.cancel();
    _from = _startOfToday();
    _fromFollowsToday = true;
    _to = null;
    _now = true;
    _datePreset = PosOrderDateRangePreset.custom;
    _search = '';
    _source = null;
    _type = null;
    _method = null;
    _status = null;
    _section = null;
    return true;
  }

  // ── Filter setters ───────────────────────────────────────────────────
  void setSearch(String value) {
    final String next = value.trim();
    if (next == _search) return;
    _search = next;
    notifyListeners();
    _searchDebounce?.cancel();
    _searchDebounce = Timer(searchDebounce, () => load(silent: true));
  }

  void setRange({DateTime? from, DateTime? to, bool? now}) {
    _from = from;
    _fromFollowsToday = false;
    _to = to;
    if (now != null) _now = now;
    _datePreset = PosOrderDateRangePreset.custom;
    unawaited(load());
  }

  void setNow(bool value) {
    if (_now == value) return;
    _now = value;
    if (value) {
      _from = _startOfToday();
      _fromFollowsToday = true;
      _to = null;
    }
    _datePreset = PosOrderDateRangePreset.custom;
    unawaited(load());
  }

  /// Applies a quick date-range preset. `custom` is not a computed range — it
  /// only marks the dropdown back to its neutral state, leaving whatever
  /// From/To the operator already set untouched.
  void setDatePreset(PosOrderDateRangePreset preset) {
    if (_datePreset == preset) return;
    _datePreset = preset;

    if (preset == PosOrderDateRangePreset.custom) {
      notifyListeners();
      return;
    }

    _from = preset.from;
    _fromFollowsToday = false;
    _to = preset.to;
    _now = preset.liveNow;
    unawaited(load());
  }

  void setSource(String? value) => _setFilter(() => _source = value, _source, value);
  void setType(String? value) => _setFilter(() => _type = value, _type, value);
  void setMethod(String? value) => _setFilter(() => _method = value, _method, value);
  void setStatus(String? value) => _setFilter(() => _status = value, _status, value);

  void setSection(PosOrderSection? value) {
    if (_section == value) return;
    _section = value;
    unawaited(load());
  }

  void _setFilter(VoidCallback assign, String? current, String? next) {
    if (current == next) return;
    assign();
    unawaited(load());
  }

  // ── Status transition ────────────────────────────────────────────────
  /// Advance one order, moving its card immediately and putting it back if the
  /// server refuses.
  ///
  /// Returns null on success, or a message to surface. The card is never
  /// removed from the board on failure — the whole point of holding the
  /// original is that a rejected transition leaves the operator looking at the
  /// order they still have to deal with.
  Future<String?> advance(PosOrderCard order) async {
    final String? target = PosOrderGrouping.nextStatusFor(order.orderStatus);
    if (target == null || _pending.contains(order.id)) return null;

    final int index = _orders.indexWhere((o) => o.id == order.id);
    if (index < 0) return null;

    final PosOrderCard original = _orders[index];

    _pending.add(order.id);
    _applyLocal(order.id, original.withStatus(target));
    _adjustCounts(from: original.section, to: PosOrderGrouping.sectionOf(target));
    notifyListeners();

    final ApiResponseModel apiResponse = await posOrdersRepo.updateStatus(
      orderId: order.id,
      orderStatus: target,
    );

    _pending.remove(order.id);

    final response = apiResponse.response;
    final int? code = response?.statusCode;

    if (response != null && code == 200) {
      notifyListeners();
      // Reconcile against the server rather than trusting the optimistic
      // guess: the transition may have raced a kitchen-side change.
      unawaited(load(silent: true));
      return null;
    }

    // Roll back to the exact card we replaced, found by id — a refetch may have
    // reordered the list while the request was in flight.
    _applyLocal(order.id, original);
    _adjustCounts(from: PosOrderGrouping.sectionOf(target), to: original.section);
    notifyListeners();

    return _messageFrom(response?.data) ??
        apiResponse.error?.toString() ??
        'Could not update the order';
  }

  /// Move every eligible item on the order forward ("Start all items" /
  /// "Mark all ready").
  ///
  /// This is what the board's forward CTA now does instead of writing
  /// `order_status`: the items move, and the server derives the order status
  /// from their aggregate exactly as it does when the kitchen moves them. That
  /// is what stops an order being marked ready while its items are still
  /// pending, only to be dragged back by the next item write.
  ///
  /// Not applied optimistically: which items actually move is the server's
  /// forward-only decision, and guessing it here would show a state the
  /// response might contradict a moment later. The board refetches instead.
  Future<String?> bulkItemStatus(PosOrderCard order, PrepStatus target) async {
    if (_pending.contains(order.id)) return null;

    _pending.add(order.id);
    notifyListeners();

    final ApiResponseModel apiResponse = await posOrdersRepo.bulkUpdateItemStatus(
      orderId: order.id,
      status: target.wire,
    );

    _pending.remove(order.id);
    notifyListeners();

    final response = apiResponse.response;
    if (response != null && response.statusCode == 200) {
      unawaited(load(silent: true));
      return null;
    }

    return _messageFrom(response?.data) ??
        apiResponse.error?.toString() ??
        'Could not update the order';
  }

  /// The order's side exits: pause, resume and cancel.
  ///
  /// Routed through the same endpoint and the same [OrderTransitionService] the
  /// kitchen's own menu uses, so a POS pause and a kitchen pause land the order
  /// in identical states. Resume sends `preparing`, which the server treats as
  /// provisional and re-derives from the item aggregate.
  Future<String?> setOrderStatus(PosOrderCard order, String status) async {
    if (_pending.contains(order.id)) return null;

    _pending.add(order.id);
    notifyListeners();

    final ApiResponseModel apiResponse = await posOrdersRepo.updateStatus(
      orderId: order.id,
      orderStatus: status,
    );

    _pending.remove(order.id);
    notifyListeners();

    final response = apiResponse.response;
    if (response != null && response.statusCode == 200) {
      unawaited(load(silent: true));
      return null;
    }

    return _messageFrom(response?.data) ??
        apiResponse.error?.toString() ??
        'Could not update the order';
  }

  void _applyLocal(int orderId, PosOrderCard card) {
    final int index = _orders.indexWhere((o) => o.id == orderId);
    if (index < 0) return;
    final List<PosOrderCard> next = List<PosOrderCard>.from(_orders);
    next[index] = card;
    _orders = next;
  }

  /// Keep the section badges honest during an optimistic move, so a card and
  /// the count above it never disagree.
  void _adjustCounts({
    required PosOrderSection from,
    required PosOrderSection to,
  }) {
    if (from == to) return;
    final Map<PosOrderSection, int> next =
        Map<PosOrderSection, int>.from(_counts);
    next[from] = ((next[from] ?? 1) - 1).clamp(0, 1 << 30);
    next[to] = (next[to] ?? 0) + 1;
    _counts = next;
  }

  static String? _messageFrom(dynamic data) {
    if (data is! Map) return null;
    final errors = data['errors'];
    if (errors is List && errors.isNotEmpty && errors.first is Map) {
      final message = (errors.first as Map)['message'];
      if (message != null) return message.toString();
    }
    final message = data['message'];
    return message?.toString();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _realtimeDebounce?.cancel();
    _poll?.cancel();
    _detachRealtime();
    super.dispose();
  }
}
