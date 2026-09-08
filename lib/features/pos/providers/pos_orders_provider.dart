import 'dart:async';

import 'package:acafe_customer/common/models/api_response_model.dart';
import 'package:acafe_customer/features/pos/domain/pos_order_card.dart';
import 'package:acafe_customer/features/pos/domain/pos_order_grouping.dart';
import 'package:acafe_customer/features/pos/domain/pos_orders_repo.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

/// State behind the POS Orders board.
///
/// Two things here are load-bearing and worth reading before changing:
///
///  * **the request-id staleness guard** — the same one
///    `KioskManagerProvider.loadTransactions` uses. A socket push and a typed
///    search can be in flight at once, and an older response landing last would
///    repaint the board with a queue that no longer exists.
///  * **optimistic moves are keyed by order id, not by list position** — a
///    refetch can reorder or drop rows underneath an in-flight action, and a
///    rollback that restored "whatever is at index 4" would corrupt an
///    unrelated card.
class PosOrdersProvider extends ChangeNotifier {
  final PosOrdersRepo posOrdersRepo;

  PosOrdersProvider({required this.posOrdersRepo});

  static final DateFormat _wire = DateFormat('yyyy-MM-dd HH:mm:ss');

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
  DateTime? _from = _startOfToday();
  DateTime? _to;

  static DateTime _startOfToday() {
    final DateTime now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
  DateTime? get from => _from;
  DateTime? get to => _to;

  /// "NOW" mode: the window ends at the present moment and follows it, rather
  /// than being pinned to a chosen end time.
  bool _now = true;
  bool get now => _now;

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

  /// Coalesces a burst of socket pushes into one refetch. A busy lunch service
  /// can land several `order.changed` frames in the same second (one order
  /// placed, two advanced from the kitchen); refetching per frame would put
  /// three identical board requests on the wire.
  Timer? _realtimeDebounce;

  static const Duration searchDebounce = Duration(milliseconds: 350);
  static const Duration realtimeDebounce = Duration(milliseconds: 400);

  // ── Counts ───────────────────────────────────────────────────────────
  int countOf(PosOrderSection section) => _counts[section] ?? 0;

  int get totalCount =>
      countOf(PosOrderSection.newOrders) +
      countOf(PosOrderSection.inProgress) +
      countOf(PosOrderSection.finished);

  /// The cards for one section, newest first — the order the feed returns them.
  List<PosOrderCard> ordersIn(PosOrderSection section) =>
      _orders.where((o) => o.section == section).toList(growable: false);

  // ── Loading ──────────────────────────────────────────────────────────
  Future<void> load({bool silent = false}) async {
    final int requestId = ++_requestId;

    if (!silent) {
      _loading = true;
      notifyListeners();
    }

    final ApiResponseModel apiResponse = await posOrdersRepo.getOrders(
      dateFrom: _from == null ? null : _wire.format(_from!),
      // In NOW mode the end of the window is resolved at request time, not when
      // the toggle was pressed — otherwise a terminal left open over lunch stops
      // showing anything placed after the operator last touched the filter.
      dateTo: _now ? null : (_to == null ? null : _wire.format(_to!)),
      search: _search.isEmpty ? null : _search,
      section: _section == null
          ? null
          : PosOrderGrouping.queryValueFor(_section!),
      status: _status,
      source: _source,
      type: _type,
      method: _method,
    );

    if (requestId != _requestId) return;

    final response = apiResponse.response;
    if (response != null && response.statusCode == 200) {
      final data = Map<String, dynamic>.from(response.data as Map);
      final List raw = data['orders'] as List? ?? const [];

      _orders = raw
          .map((e) => PosOrderCard.fromJson(Map<String, dynamic>.from(e as Map)))
          // The endpoint already excludes off-board statuses; this is the
          // belt-and-braces so an unknown future status can never render as an
          // untitled section.
          .where((o) => o.section != PosOrderSection.excluded)
          .toList(growable: false);

      final counts = Map<String, dynamic>.from(data['counts'] as Map? ?? {});
      _counts = <PosOrderSection, int>{
        PosOrderSection.newOrders: int.tryParse('${counts['new']}') ?? 0,
        PosOrderSection.inProgress:
            int.tryParse('${counts['in_progress']}') ?? 0,
        PosOrderSection.finished: int.tryParse('${counts['finished']}') ?? 0,
      };
      _error = null;
      _loaded = true;
    } else {
      _error = apiResponse.error?.toString() ?? 'Could not load orders';
      // The previous board is deliberately left on screen. A failed refresh
      // should not clear a queue the counter is working from.
    }

    _loading = false;
    notifyListeners();
  }

  /// Refetch triggered by an `order.changed` push. Silent and debounced: the
  /// board updates under the operator without a spinner.
  void onRealtimeChange() {
    _realtimeDebounce?.cancel();
    _realtimeDebounce = Timer(realtimeDebounce, () => load(silent: true));
  }

  /// A dropped socket cannot be reconciled from the events themselves — the
  /// ones missed while offline are gone — so a reconnect re-pulls the board.
  void onRealtimeReconnect() {
    _realtimeDebounce?.cancel();
    unawaited(load(silent: true));
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
    _to = to;
    if (now != null) _now = now;
    unawaited(load());
  }

  void setNow(bool value) {
    if (_now == value) return;
    _now = value;
    if (value) {
      _from = _startOfToday();
      _to = null;
    }
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
    super.dispose();
  }
}
