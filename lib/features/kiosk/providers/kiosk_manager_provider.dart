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

  /// Guards against a slow page for an old query landing after a newer one
  /// and appending unrelated rows to the list on screen.
  int _transactionsRequestId = 0;

  bool get hasMoreTransactions => _transactions.length < _transactionsTotal;

  Future<void> loadTransactions({
    bool reset = true,
    String? reportDate,
    String? search,
  }) async {
    if (reset) {
      _transactionsOffset = 1;
      _transactions = [];
      _transactionsTotal = 0;
      if (search != null) _transactionsSearch = search.trim();
    }
    final int requestId = ++_transactionsRequestId;
    _transactionsLoading = true;
    notifyListeners();

    final apiResponse = await kioskManagerRepo.getTransactions(
      reportDate: reportDate,
      search: _transactionsSearch,
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
