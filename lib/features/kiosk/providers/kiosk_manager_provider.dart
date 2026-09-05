import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_manager_repo.dart';
import 'package:acafe_customer/helper/api_checker_helper.dart';
import 'package:acafe_customer/utill/app_constants.dart';

/// Backs the PIN-gated "POS Manager" screens: the PIN check itself, the live
/// Sales Overview / Do-Z-Report action, Transaction History, and the
/// Mark-Out-of-Stock product list. One provider per feature area, mirroring
/// how KioskAuthProvider wraps KioskAuthRepo elsewhere in this app.
class KioskManagerProvider extends ChangeNotifier {
  final KioskManagerRepo kioskManagerRepo;

  KioskManagerProvider({required this.kioskManagerRepo});

  // ---- PIN gate -------------------------------------------------------
  // Verified only for the current visit to the manager subtree; cleared
  // whenever the manager leaves back to the menu (no idle timeout for v1).
  bool _isPinVerified = false;
  bool get isPinVerified => _isPinVerified;

  bool _verifyingPin = false;
  bool get verifyingPin => _verifyingPin;

  String? _pinError;
  String? get pinError => _pinError;

  Future<bool> verifyPin(String code) async {
    _verifyingPin = true;
    _pinError = null;
    notifyListeners();

    final apiResponse = await kioskManagerRepo.verifyCode(code);
    final response = apiResponse.response;

    _verifyingPin = false;
    if (response != null && response.statusCode == 200) {
      _isPinVerified = true;
      notifyListeners();
      return true;
    }

    _pinError = (response?.data is Map
            ? response!.data['message']?.toString()
            : null) ??
        'Incorrect code';
    notifyListeners();
    return false;
  }

  void clearPinError() {
    _pinError = null;
    notifyListeners();
  }

  /// Called when navigating back to the menu from anywhere in the manager
  /// subtree, so re-entering requires the PIN again.
  void lockManagerAccess() {
    _isPinVerified = false;
    _pinError = null;
    notifyListeners();
  }

  // ---- Sales overview / Z Report ---------------------------------------
  bool _salesLoading = false;
  bool get salesLoading => _salesLoading;

  Map<String, dynamic>? _salesData;
  Map<String, dynamic>? get salesData => _salesData;

  bool _closingRegister = false;
  bool get closingRegister => _closingRegister;

  Future<void> loadSalesOverview({String? reportDate}) async {
    _salesLoading = true;
    notifyListeners();

    final apiResponse =
        await kioskManagerRepo.getSalesOverview(reportDate: reportDate);
    if (apiResponse.response != null &&
        apiResponse.response!.statusCode == 200) {
      _salesData = Map<String, dynamic>.from(apiResponse.response!.data);
    } else {
      ApiCheckerHelper.checkApi(apiResponse);
    }

    _salesLoading = false;
    notifyListeners();
  }

  Future<bool> closeZReport({
    required String reportDate,
    String? comment,
  }) async {
    _closingRegister = true;
    notifyListeners();

    final apiResponse = await kioskManagerRepo.closeZReport(
      reportDate: reportDate,
      comment: comment,
    );

    _closingRegister = false;
    final success =
        apiResponse.response != null && apiResponse.response!.statusCode == 200;
    if (success) {
      final data = apiResponse.response!.data['data'];
      _salesData = data != null ? Map<String, dynamic>.from(data) : _salesData;
    } else {
      ApiCheckerHelper.checkApi(apiResponse);
    }
    notifyListeners();
    return success;
  }

  // ---- Transaction history ---------------------------------------------
  bool _transactionsLoading = false;
  bool get transactionsLoading => _transactionsLoading;

  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> get transactions => _transactions;

  int _transactionsTotal = 0;
  int get transactionsTotal => _transactionsTotal;

  int _transactionsOffset = 1;
  static const int _transactionsLimit = 25;

  /// Current server-side query. Unlike the stock screen -- which holds the
  /// whole catalog in memory and filters locally -- transactions stay
  /// paginated, so searching has to happen on the API or it would only ever
  /// match the pages already scrolled into view.
  String _transactionsSearch = '';
  String get transactionsSearch => _transactionsSearch;

  String? _transactionsReportDate;
  String? _transactionsDateFrom;
  String? _transactionsDateTo;
  String? _transactionsStatus;
  String? _transactionsChannel;
  double? _transactionsAmountMin;
  double? _transactionsAmountMax;

  String? get transactionsDateFrom => _transactionsDateFrom;
  String? get transactionsDateTo => _transactionsDateTo;

  /// Guards against a slow page for an old query landing after a newer one
  /// and appending unrelated rows to the list on screen.
  int _transactionsRequestId = 0;

  bool get hasMoreTransactions => _transactions.length < _transactionsTotal;

  /// [replaceFilters] lets the Receipts screen overwrite every filter field
  /// (including clearing with null). The manager Transaction History screen
  /// leaves it false so only search / report_date change and the rest stay
  /// untouched — same behaviour as before the Receipts filters existed.
  Future<void> loadTransactions({
    bool reset = true,
    String? reportDate,
    String? dateFrom,
    String? dateTo,
    String? search,
    String? status,
    String? channel,
    double? amountMin,
    double? amountMax,
    bool replaceFilters = false,
  }) async {
    if (reset) {
      _transactionsOffset = 1;
      _transactions = [];
      _transactionsTotal = 0;
      if (search != null) _transactionsSearch = search.trim();
      if (replaceFilters) {
        _transactionsReportDate = reportDate;
        _transactionsDateFrom = dateFrom;
        _transactionsDateTo = dateTo;
        _transactionsStatus = status;
        _transactionsChannel = channel;
        _transactionsAmountMin = amountMin;
        _transactionsAmountMax = amountMax;
      } else {
        // Straight through, exactly as the parameter was used before these
        // fields existed: a caller that does not pass a date gets the
        // endpoint's own default (today).
        _transactionsReportDate = reportDate;
        // This provider is a lazy singleton shared with the POS Receipts
        // screen, so a caller that does not manage these filters must not
        // inherit whatever Receipts last set — otherwise the manager
        // Transaction History screen silently shows, say, kiosk-only rows
        // because someone filtered by channel on the other screen. Clearing
        // here is what keeps that caller behaving exactly as it did before
        // these filters existed.
        _transactionsDateFrom = null;
        _transactionsDateTo = null;
        _transactionsStatus = null;
        _transactionsChannel = null;
        _transactionsAmountMin = null;
        _transactionsAmountMax = null;
      }
    }
    final int requestId = ++_transactionsRequestId;
    _transactionsLoading = true;
    notifyListeners();

    final apiResponse = await kioskManagerRepo.getTransactions(
      reportDate: _transactionsReportDate,
      dateFrom: _transactionsDateFrom,
      dateTo: _transactionsDateTo,
      search: _transactionsSearch,
      status: _transactionsStatus,
      channel: _transactionsChannel,
      amountMin: _transactionsAmountMin,
      amountMax: _transactionsAmountMax,
      limit: _transactionsLimit,
      offset: _transactionsOffset,
    );

    // A newer query (or a reset) started while this page was in flight -- its
    // results own the list now, so this response is dropped entirely.
    if (requestId != _transactionsRequestId) return;

    if (apiResponse.response != null &&
        apiResponse.response!.statusCode == 200) {
      final data = apiResponse.response!.data;
      _transactionsTotal = data['total_size'] ?? 0;
      final List orders = data['orders'] ?? [];
      _transactions = [
        ..._transactions,
        ...orders.map((o) => Map<String, dynamic>.from(o)),
      ];
      _transactionsOffset++;
    } else {
      ApiCheckerHelper.checkApi(apiResponse);
    }

    _transactionsLoading = false;
    notifyListeners();
  }

  /// Re-runs transaction history for [query] from page one. Passing the same
  /// query again is a no-op so a debounced keystroke that ends where it
  /// started never re-fetches.
  Future<void> searchTransactions(String query) async {
    final next = query.trim();
    if (next == _transactionsSearch) return;
    await loadTransactions(search: next);
  }

  /// Pulls every remaining page for the active filter so Export covers the
  /// full filtered result set, not only the rows already scrolled into view.
  Future<void> loadAllTransactionsForExport() async {
    while (hasMoreTransactions && !_transactionsLoading) {
      await loadTransactions(reset: false);
    }
  }

  // ---- Receipt detail (POS Receipts pane) --------------------------------
  bool _receiptDetailLoading = false;
  bool get receiptDetailLoading => _receiptDetailLoading;

  Map<String, dynamic>? _receiptDetail;
  Map<String, dynamic>? get receiptDetail => _receiptDetail;

  int? _receiptDetailId;
  int? get receiptDetailId => _receiptDetailId;

  /// Same staleness pattern as the list: a fast second row tap must never
  /// paint the first row's response.
  int _receiptDetailRequestId = 0;

  Future<void> loadReceiptDetail(int id) async {
    if (_receiptDetailId == id &&
        _receiptDetail != null &&
        !_receiptDetailLoading) {
      return;
    }
    final int requestId = ++_receiptDetailRequestId;
    _receiptDetailId = id;
    _receiptDetailLoading = true;
    // Drop the previous receipt immediately so a slow prior response cannot
    // flash under the new selection.
    _receiptDetail = null;
    notifyListeners();

    final apiResponse = await kioskManagerRepo.getTransactionDetail(id);
    if (requestId != _receiptDetailRequestId) return;

    if (apiResponse.response != null &&
        apiResponse.response!.statusCode == 200) {
      _receiptDetail =
          Map<String, dynamic>.from(apiResponse.response!.data as Map);
    } else {
      _receiptDetail = null;
      ApiCheckerHelper.checkApi(apiResponse);
    }

    _receiptDetailLoading = false;
    notifyListeners();
  }

  void clearReceiptDetail() {
    _receiptDetailRequestId++;
    _receiptDetail = null;
    _receiptDetailId = null;
    _receiptDetailLoading = false;
    notifyListeners();
  }

  // ---- Mark out of stock -------------------------------------------------
  bool _productsLoading = false;
  bool get productsLoading => _productsLoading;

  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> get products => _products;

  int _productsTotal = 0;
  int _productsOffset = 1;
  static const int _productsLimit = 100;
  String _productsSearch = '';

  bool get hasMoreProducts => _products.length < _productsTotal;

  /// Loaded-set out-of-stock count -- accurate once [loadAllProducts] has
  /// pulled every page, which is what the Mark-Out-of-Stock screen always
  /// does (a manager needs the true count, not just what's scrolled into
  /// view).
  int get outOfStockCount =>
      _products.where((p) => p['is_available'] != true).length;

  // Per-product in-flight guard so a double-tap can't queue conflicting
  // toggle requests for the same row.
  final Set<int> _togglingProductIds = {};
  bool isTogglingProduct(int id) => _togglingProductIds.contains(id);

  Future<void> loadProducts({bool reset = true, String? search}) async {
    if (reset) {
      _productsOffset = 1;
      _products = [];
      _productsSearch = search ?? '';
    }
    _productsLoading = true;
    notifyListeners();

    final apiResponse = await kioskManagerRepo.getProducts(
      search: _productsSearch,
      limit: _productsLimit,
      offset: _productsOffset,
    );

    if (apiResponse.response != null &&
        apiResponse.response!.statusCode == 200) {
      final data = apiResponse.response!.data;
      _productsTotal = data['total_size'] ?? 0;
      final List items = data['products'] ?? [];
      _products = [
        ..._products,
        ...items.map((p) => Map<String, dynamic>.from(p)),
      ];
      _productsOffset++;
    } else {
      ApiCheckerHelper.checkApi(apiResponse);
    }

    _productsLoading = false;
    notifyListeners();
  }

  /// Pulls every page for the given [search] so the stock screen's stats
  /// ("N products" / "M out of stock") and All/In-stock/Out filter always
  /// reflect the whole branch menu, not just the first page.
  Future<void> loadAllProducts({String? search}) async {
    await loadProducts(search: search);
    while (hasMoreProducts) {
      await loadProducts(reset: false);
    }
    if ((search == null || search.isEmpty)) {
      await _persistProductsToDisk();
    }
  }

  /// Instant-first-paint version of [loadAllProducts] for screen entry: shows
  /// whatever was on disk from the last session immediately (no spinner),
  /// then always re-validates against the network in the background so stock
  /// status stays accurate. Falls back to a normal (spinner-shown) load only
  /// when there is no disk cache yet -- mirrors the stale-while-revalidate
  /// pattern CategoryProvider already uses for the kiosk menu prefetch.
  ///
  /// Always re-validates, even when this session already has an in-memory
  /// list, so navigating back into the screen (or after an API scope fix)
  /// cannot keep a stale count on screen.
  Future<void> loadAllProductsWithCache() async {
    if (_products.isNotEmpty) {
      unawaited(_refreshAllProductsSilently());
      return;
    }
    if (_hydrateProductsFromDisk()) {
      notifyListeners();
      unawaited(_refreshAllProductsSilently());
    } else {
      await loadAllProducts();
    }
  }

  bool _hydrateProductsFromDisk() {
    final raw = kioskManagerRepo.sharedPreferences
        .getString(AppConstants.kioskManagerStockCacheKey);
    if (raw == null) return false;

    try {
      final List cached = jsonDecode(raw);
      final products = cached.map((p) => Map<String, dynamic>.from(p)).toList();
      if (products.isEmpty) return false;
      _products = products;
      _productsTotal = products.length;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _persistProductsToDisk() async {
    try {
      await kioskManagerRepo.sharedPreferences.setString(
        AppConstants.kioskManagerStockCacheKey,
        jsonEncode(_products),
      );
    } catch (_) {
      // Best-effort persistence -- in-memory list still works this session.
    }
  }

  // ---- Settings -> Add-Ons ----------------------------------------------
  // Mirrors the product block above (optimistic write, revert on failure).
  // Deliberately a separate set of fields rather than a generalisation of the
  // product ones: the two lists load independently and a shared cursor would
  // couple two screens that have no reason to move together.

  bool _addonsLoading = false;
  bool get addonsLoading => _addonsLoading;

  List<Map<String, dynamic>> _addons = [];
  List<Map<String, dynamic>> get addons => _addons;

  int _addonsTotal = 0;
  int _addonsOffset = 1;
  static const int _addonsLimit = 100;

  bool get hasMoreAddons => _addons.length < _addonsTotal;

  final Set<int> _togglingAddonIds = {};
  bool isTogglingAddon(int id) => _togglingAddonIds.contains(id);

  Future<void> loadAddons({bool reset = true}) async {
    if (reset) {
      _addonsOffset = 1;
      _addons = [];
    }
    _addonsLoading = true;
    notifyListeners();

    final apiResponse = await kioskManagerRepo.getAddons(
      limit: _addonsLimit,
      offset: _addonsOffset,
    );

    if (apiResponse.response != null &&
        apiResponse.response!.statusCode == 200) {
      final data = apiResponse.response!.data;
      _addonsTotal = data['total_size'] ?? 0;
      final List items = data['addons'] ?? [];
      _addons = [
        ..._addons,
        ...items.map((a) => Map<String, dynamic>.from(a)),
      ];
      _addonsOffset++;
    } else {
      ApiCheckerHelper.checkApi(apiResponse);
    }

    _addonsLoading = false;
    notifyListeners();
  }

  /// Pulls every page, so search filters the whole catalog rather than just
  /// the first page -- the Add-Ons screen filters client-side.
  Future<void> loadAllAddons() async {
    await loadAddons();
    while (hasMoreAddons) {
      await loadAddons(reset: false);
    }
  }

  /// Screen-entry load. Re-validates whenever a list is already in memory so
  /// re-entering the tab cannot show a stale toggle state. No disk cache: the
  /// add-on catalog is small and, unlike stock, is not worth showing stale
  /// after a cold start.
  Future<void> loadAllAddonsWithCache() async {
    if (_addons.isNotEmpty) {
      unawaited(_refreshAllAddonsSilently());
      return;
    }
    await loadAllAddons();
  }

  Future<void> _refreshAllAddonsSilently() async {
    final List<Map<String, dynamic>> fresh = [];
    int offset = 1;
    int total = 0;
    do {
      final apiResponse = await kioskManagerRepo.getAddons(
        limit: _addonsLimit,
        offset: offset,
      );
      if (apiResponse.response == null ||
          apiResponse.response!.statusCode != 200) {
        return;
      }
      final data = apiResponse.response!.data;
      total = data['total_size'] ?? 0;
      final List items = data['addons'] ?? [];
      fresh.addAll(items.map((a) => Map<String, dynamic>.from(a)));
      offset++;
    } while (fresh.length < total);

    _addons = fresh;
    _addonsTotal = total;
    notifyListeners();
  }

  /// Flip one add-on's kiosk visibility.
  ///
  /// Returns null on success, or the server's refusal message when it refused
  /// (a required group that would be left unsatisfiable), so the screen can
  /// show it inline. Transport failures fall through to the usual toast and
  /// return null -- there is nothing screen-specific to say about them.
  Future<String?> toggleAddonAvailability(int addonId, bool nextStatus) async {
    if (_togglingAddonIds.contains(addonId)) return null;

    final index = _addons.indexWhere((a) => a['id'] == addonId);
    if (index == -1) return null;

    // Optimistic update.
    final previous = _addons[index]['is_available'];
    _addons[index] = {..._addons[index], 'is_available': nextStatus};
    _togglingAddonIds.add(addonId);
    notifyListeners();

    final apiResponse =
        await kioskManagerRepo.setAddonStatus(id: addonId, status: nextStatus);
    final success =
        apiResponse.response != null && apiResponse.response!.statusCode == 200;

    String? refusal;
    if (!success) {
      // Revert on failure.
      _addons[index] = {..._addons[index], 'is_available': previous};
      refusal = KioskManagerRepo.addonStatusError(apiResponse.error);
      if (refusal == null) {
        ApiCheckerHelper.checkApi(apiResponse);
      }
    }

    _togglingAddonIds.remove(addonId);
    notifyListeners();

    return refusal;
  }

  /// Re-pulls the full product list without ever clearing what's already on
  /// screen, so a stale-cache refresh never flashes a loading state.
  Future<void> _refreshAllProductsSilently() async {
    final List<Map<String, dynamic>> fresh = [];
    int offset = 1;
    int total = 0;
    do {
      final apiResponse = await kioskManagerRepo.getProducts(
        limit: _productsLimit,
        offset: offset,
      );
      if (apiResponse.response == null ||
          apiResponse.response!.statusCode != 200) {
        return;
      }
      final data = apiResponse.response!.data;
      total = data['total_size'] ?? 0;
      final List items = data['products'] ?? [];
      fresh.addAll(items.map((p) => Map<String, dynamic>.from(p)));
      offset++;
    } while (fresh.length < total);

    _products = fresh;
    _productsTotal = total;
    notifyListeners();
    await _persistProductsToDisk();
  }

  Future<bool> toggleProductAvailability(int productId, bool nextStatus) async {
    if (_togglingProductIds.contains(productId)) return false;

    final index = _products.indexWhere((p) => p['id'] == productId);
    if (index == -1) return false;

    // Optimistic update.
    final previous = _products[index]['is_available'];
    _products[index] = {..._products[index], 'is_available': nextStatus};
    _togglingProductIds.add(productId);
    notifyListeners();

    final apiResponse = await kioskManagerRepo.setProductStatus(
        id: productId, status: nextStatus);
    final success =
        apiResponse.response != null && apiResponse.response!.statusCode == 200;

    if (!success) {
      // Revert on failure.
      _products[index] = {..._products[index], 'is_available': previous};
      ApiCheckerHelper.checkApi(apiResponse);
    }

    _togglingProductIds.remove(productId);
    notifyListeners();

    if (success) {
      await _persistProductsToDisk();
    }
    return success;
  }
}
