import 'package:flutter/material.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_manager_repo.dart';
import 'package:acafe_customer/helper/api_checker_helper.dart';

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

    _pinError = (response?.data is Map ? response!.data['message']?.toString() : null) ??
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

    final apiResponse = await kioskManagerRepo.getSalesOverview(reportDate: reportDate);
    if (apiResponse.response != null && apiResponse.response!.statusCode == 200) {
      _salesData = Map<String, dynamic>.from(apiResponse.response!.data);
    } else {
      ApiCheckerHelper.checkApi(apiResponse);
    }

    _salesLoading = false;
    notifyListeners();
  }

  Future<bool> closeZReport({
    required String reportDate,
    required double openingCash,
    required double closingCashCounted,
    String? comment,
  }) async {
    _closingRegister = true;
    notifyListeners();

    final apiResponse = await kioskManagerRepo.closeZReport(
      reportDate: reportDate,
      openingCash: openingCash,
      closingCashCounted: closingCashCounted,
      comment: comment,
    );

    _closingRegister = false;
    final success = apiResponse.response != null && apiResponse.response!.statusCode == 200;
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

  bool get hasMoreTransactions => _transactions.length < _transactionsTotal;

  Future<void> loadTransactions({bool reset = true, String? reportDate}) async {
    if (reset) {
      _transactionsOffset = 1;
      _transactions = [];
    }
    _transactionsLoading = true;
    notifyListeners();

    final apiResponse = await kioskManagerRepo.getTransactions(
      reportDate: reportDate,
      limit: _transactionsLimit,
      offset: _transactionsOffset,
    );

    if (apiResponse.response != null && apiResponse.response!.statusCode == 200) {
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

  // ---- Mark out of stock -------------------------------------------------
  bool _productsLoading = false;
  bool get productsLoading => _productsLoading;

  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> get products => _products;

  int _productsTotal = 0;
  int _productsOffset = 1;
  static const int _productsLimit = 25;
  String _productsSearch = '';

  bool get hasMoreProducts => _products.length < _productsTotal;

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

    if (apiResponse.response != null && apiResponse.response!.statusCode == 200) {
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

  Future<void> toggleProductAvailability(int productId, bool nextStatus) async {
    if (_togglingProductIds.contains(productId)) return;

    final index = _products.indexWhere((p) => p['id'] == productId);
    if (index == -1) return;

    // Optimistic update.
    final previous = _products[index]['is_available'];
    _products[index] = {..._products[index], 'is_available': nextStatus};
    _togglingProductIds.add(productId);
    notifyListeners();

    final apiResponse =
        await kioskManagerRepo.setProductStatus(id: productId, status: nextStatus);
    final success = apiResponse.response != null && apiResponse.response!.statusCode == 200;

    if (!success) {
      // Revert on failure.
      _products[index] = {..._products[index], 'is_available': previous};
      ApiCheckerHelper.checkApi(apiResponse);
    }

    _togglingProductIds.remove(productId);
    notifyListeners();
  }
}
