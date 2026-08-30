import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:acafe_customer/common/enums/data_source_enum.dart';
import 'package:acafe_customer/common/models/api_response_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/common/providers/data_sync_provider.dart';
import 'package:acafe_customer/data/datasource/local/cache_response.dart';
import 'package:acafe_customer/features/category/domain/category_model.dart';
import 'package:acafe_customer/features/category/domain/reposotories/category_repo.dart';
import 'package:acafe_customer/helper/api_checker_helper.dart';
import 'package:acafe_customer/utill/app_constants.dart';

class CategoryProvider extends DataSyncProvider {
  final CategoryRepo? categoryRepo;

  CategoryProvider({required this.categoryRepo});

  static const Duration _kioskMenuCacheMaxAge = Duration(minutes: 10);
  static const int _kioskPrefetchProductLimit = 50;

  CategoryData? _categoryModel;
  CategoryData? _searchCategoryModel;

  List<CategoryModel>? _categoryList;
  List<CategoryModel>? _searchCategoryList;
  List<CategoryModel>? _suggestionList;

  List<CategoryModel>? _subCategoryList;
  ProductModel? _categoryProductModel;
  bool _pageFirstIndex = true;
  bool _pageLastIndex = false;
  bool _isLoading = false;
  String? _selectedSubCategoryId;
  final TextEditingController _searchController = TextEditingController();
  int _searchLength = 0;
  bool _isSearch = true;

  // Kiosk menu prefetch cache (singleton — shared between welcome + menu screens).
  String? _kioskPrefetchLocale;
  int? _kioskPrefetchBranchId;
  bool _kioskMenuLoaded = false;
  Future<void>? _kioskPrefetchFuture;
  final Map<String, ProductModel> _kioskProductsByCategory = {};

  int? get _sessionBranchId {
    final id = categoryRepo?.sharedPreferences?.getInt(AppConstants.branch);
    if (id == null || id <= 0) return null;
    return id;
  }

  /// True while a prefetch is in flight (used by the ORDER HERE button spinner).
  bool get isKioskMenuPrefetching => _kioskPrefetchFuture != null;

  /// All products loaded during kiosk prefetch (every category).
  Iterable<Product> get allPrefetchedProducts sync* {
    for (final model in _kioskProductsByCategory.values) {
      for (final product in model.products ?? <Product>[]) {
        yield product;
      }
    }
  }

  /// Whether the in-memory menu matches this locale and the signed-in branch.
  /// An empty menu is a valid ready state — a new branch with zero products
  /// must not keep showing another branch's cached catalog.
  bool isKioskMenuReadyFor(String localeCode) {
    final branchId = _sessionBranchId;
    if (branchId == null || !_kioskMenuLoaded) return false;
    return _kioskPrefetchLocale == localeCode &&
        _kioskPrefetchBranchId == branchId;
  }

  /// Drop the in-memory (+ optional disk) menu so the next prefetch cannot
  /// leak another branch's products after login / logout / rebind.
  Future<void> clearKioskMenu({bool persist = true}) async {
    _categoryList = null;
    _categoryModel = null;
    _categoryProductModel = null;
    _selectedSubCategoryId = null;
    _kioskProductsByCategory.clear();
    _kioskPrefetchLocale = null;
    _kioskPrefetchBranchId = null;
    _kioskMenuLoaded = false;
    if (persist) {
      await categoryRepo?.sharedPreferences?.remove(AppConstants.kioskMenuCacheKey);
    }
    notifyListeners();
  }

  /// Prefetch categories + all category products for the kiosk welcome screen.
  /// Non-blocking when called without await. Safe to call multiple times.
  /// Does not hit the network when the in-memory menu is already ready, unless
  /// [force] is true (language change).
  Future<void> prefetchKioskMenu({
    required String localeCode,
    bool force = false,
    bool background = false, // ignored; kept for existing call sites
  }) {
    if (!force && isKioskMenuReadyFor(localeCode)) {
      return Future.value();
    }

    if (_kioskPrefetchFuture != null) {
      return _kioskPrefetchFuture!;
    }

    _kioskPrefetchFuture = _runKioskPrefetch(
      localeCode: localeCode,
      force: force,
    );
    return _kioskPrefetchFuture!.whenComplete(() => _kioskPrefetchFuture = null);
  }

  /// Blocks until menu data is ready (waits on in-flight prefetch or fetches).
  Future<void> ensureKioskMenuReady({required String localeCode}) async {
    if (isKioskMenuReadyFor(localeCode)) return;

    await prefetchKioskMenu(localeCode: localeCode);

    if (isKioskMenuReadyFor(localeCode)) return;

    // Silent retry once, then proceed — menu screen falls back to its own loader.
    await prefetchKioskMenu(localeCode: localeCode, force: true);
  }

  /// Instantly hide (or restore via network refresh) a product on the kiosk
  /// menu after the POS manager toggles availability. The menu is otherwise
  /// served from memory/disk and would keep showing an out-of-stock item
  /// until a full restart.
  void applyKioskAvailability({required int productId, required bool isAvailable}) {
    if (!isAvailable) {
      var changed = false;
      for (final model in _kioskProductsByCategory.values) {
        final list = model.products;
        if (list == null) continue;
        final before = list.length;
        list.removeWhere((p) => p.id == productId);
        if (list.length != before) {
          changed = true;
          final total = model.totalSize;
          if (total != null && total > 0) {
            model.totalSize = total - 1;
          }
        }
      }
      if (changed) {
        notifyListeners();
        final locale = _kioskPrefetchLocale;
        if (locale != null) {
          _persistKioskMenuToDisk(locale);
        }
      }
    }

    final locale = _kioskPrefetchLocale;
    if (locale != null) {
      prefetchKioskMenu(localeCode: locale, force: true);
    }
  }

  /// Hydrate from SharedPreferences. Network prefetch only if the cache is empty.
  Future<void> warmKioskMenuFromDisk(String localeCode) async {
    _discardStaleKioskMenuIfNeeded();
    if (_hydrateKioskMenuFromDisk(localeCode)) {
      notifyListeners();
    }
    if (isKioskMenuReadyFor(localeCode)) return;
    await prefetchKioskMenu(localeCode: localeCode);
  }

  /// Poll the network for menu changes (newly-published/removed products,
  /// price/availability edits, new categories) and refresh the kiosk grid in
  /// place. Runs entirely in the background: it never shows a loader, preserves
  /// the category the customer is browsing, and only rebuilds the UI when the
  /// menu actually changed — so an idle grid stays perfectly still while a new
  /// product pops in on the next poll. No-ops when the menu hasn't loaded yet
  /// or another fetch is already in flight. Used by the kiosk menu screen's
  /// auto-refresh timer (kiosks are never manually reloaded).
  Future<void> pollKioskMenuForUpdates() {
    final localeCode = _kioskPrefetchLocale;
    if (localeCode == null) return Future.value();
    if (_kioskPrefetchFuture != null) return _kioskPrefetchFuture!;

    _kioskPrefetchFuture = _runKioskMenuPoll(localeCode);
    return _kioskPrefetchFuture!
        .whenComplete(() => _kioskPrefetchFuture = null);
  }

  Future<void> _runKioskMenuPoll(String localeCode) async {
    final signatureBefore = _kioskMenuSignature();

    final ok = await _fetchKioskMenuFromNetwork(localeCode);
    if (!ok) return;

    _kioskPrefetchLocale = localeCode;
    await _persistKioskMenuToDisk(localeCode);

    // Only rebuild when the menu genuinely changed, so the grid doesn't flicker
    // every poll for identical data.
    if (_kioskMenuSignature() != signatureBefore) {
      notifyListeners();
    }
  }

  /// Compact fingerprint of the loaded menu (per category: product id, price,
  /// availability status and last-updated stamp). Changes whenever a product is
  /// added, removed, re-priced, toggled available, or edited.
  String _kioskMenuSignature() {
    final buffer = StringBuffer();
    for (final id in _kioskProductsByCategory.keys.toList()..sort()) {
      buffer.write(id);
      buffer.write('=');
      for (final product in _kioskProductsByCategory[id]?.products ??
          const <Product>[]) {
        buffer
          ..write(product.id)
          ..write(':')
          ..write(product.price)
          ..write(':')
          ..write(product.status)
          ..write(':')
          ..write(product.branchProduct?.isAvailable)
          ..write(':')
          ..write(product.updatedAt)
          ..write(':')
          ..write((product.tags ?? const <ProductTag>[])
              .map((t) => t.tag)
              .join('|'))
          ..write(',');
      }
      buffer.write(';');
    }
    return buffer.toString();
  }

  void _discardStaleKioskMenuIfNeeded() {
    final branchId = _sessionBranchId;
    if (!_kioskMenuLoaded) return;
    if (branchId != null && _kioskPrefetchBranchId == branchId) return;
    _categoryList = null;
    _categoryModel = null;
    _categoryProductModel = null;
    _selectedSubCategoryId = null;
    _kioskProductsByCategory.clear();
    _kioskPrefetchLocale = null;
    _kioskPrefetchBranchId = null;
    _kioskMenuLoaded = false;
  }

  Future<void> _runKioskPrefetch({
    required String localeCode,
    bool force = false,
  }) async {
    _discardStaleKioskMenuIfNeeded();
    if (!force) {
      final hydrated = _hydrateKioskMenuFromDisk(localeCode);
      if (hydrated && isKioskMenuReadyFor(localeCode)) {
        notifyListeners();
        return;
      }
      if (isKioskMenuReadyFor(localeCode)) return;
    }

    var ok = await _fetchKioskMenuFromNetwork(localeCode);
    if (!ok) {
      ok = await _fetchKioskMenuFromNetwork(localeCode);
    }

    if (ok) {
      _kioskPrefetchLocale = localeCode;
      await _persistKioskMenuToDisk(localeCode);
    }
    notifyListeners();
  }

  bool _hydrateKioskMenuFromDisk(String localeCode) {
    final prefs = categoryRepo?.sharedPreferences;
    if (prefs == null) return false;

    final raw = prefs.getString(AppConstants.kioskMenuCacheKey);
    if (raw == null) return false;

    try {
      final Map<String, dynamic> data = jsonDecode(raw);
      final storedLocale = data['locale'] as String?;
      final fetchedAtMs = data['fetchedAt'] as int?;
      final storedBranch = int.tryParse('${data['branchId']}');
      final branchId = _sessionBranchId;
      if (storedLocale != localeCode ||
          fetchedAtMs == null ||
          branchId == null ||
          storedBranch != branchId) {
        return false;
      }

      final age = DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch(fetchedAtMs),
      );
      if (age > _kioskMenuCacheMaxAge) return false;

      final categoriesJson = data['categories'];
      final productsJson = data['productsByCategory'] as Map<String, dynamic>?;
      if (categoriesJson == null || productsJson == null) return false;

      _categoryList = [];
      _categoryModel = CategoryData.fromJson(categoriesJson);
      _categoryList!.addAll(_categoryModel?.categories ?? []);

      _kioskProductsByCategory.clear();
      productsJson.forEach((id, value) {
        _kioskProductsByCategory[id] = ProductModel.fromJson(value);
      });

      if (_categoryList!.isNotEmpty) {
        _selectedSubCategoryId = '${_categoryList!.first.id}';
        _categoryProductModel = _kioskProductsByCategory[_selectedSubCategoryId];
      }

      _kioskPrefetchLocale = localeCode;
      _kioskPrefetchBranchId = branchId;
      _kioskMenuLoaded = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _fetchKioskMenuFromNetwork(String localeCode) async {
    if (categoryRepo == null) return false;
    final branchId = _sessionBranchId;
    if (branchId == null) return false;

    try {
      final ApiResponseModel catResponse =
          await categoryRepo!.getKioskCategoryList(limit: 24, offset: 1);
      if (catResponse.response?.statusCode != 200) return false;

      final categoryModel = CategoryData.fromJson(catResponse.response!.data);
      final categories = categoryModel.categories ?? [];
      final Map<String, ProductModel> productsByCategory = {};

      for (final category in categories) {
        final ApiResponseModel prodResponse =
            await categoryRepo!.getKioskProductList(
          categoryID: '${category.id}',
          offset: 1,
          type: 'all',
          limit: _kioskPrefetchProductLimit,
        );
        if (prodResponse.response?.statusCode == 200) {
          productsByCategory['${category.id}'] =
              ProductModel.fromJson(prodResponse.response!.data);
        }
      }

      _applyFetchedKioskMenu(
        localeCode: localeCode,
        branchId: branchId,
        categoryModel: categoryModel,
        categories: categories,
        productsByCategory: productsByCategory,
      );
      _isLoading = false;
      return true;
    } catch (_) {
      return false;
    }
  }

  void _applyFetchedKioskMenu({
    required String localeCode,
    required int branchId,
    required CategoryData categoryModel,
    required List<CategoryModel> categories,
    required Map<String, ProductModel> productsByCategory,
  }) {
    _categoryList = List<CategoryModel>.from(categories);
    _categoryModel = categoryModel;
    _kioskProductsByCategory
      ..clear()
      ..addAll(productsByCategory);
    _kioskPrefetchLocale = localeCode;
    _kioskPrefetchBranchId = branchId;
    _kioskMenuLoaded = true;

    // Preserve the category the user is currently browsing across refreshes
    // (a background poll must not yank them back to the first category). Fall
    // back to the first category only when the previous selection is gone.
    final previousSelection = _selectedSubCategoryId;
    if (previousSelection != null &&
        _kioskProductsByCategory.containsKey(previousSelection)) {
      _selectedSubCategoryId = previousSelection;
    } else if (_categoryList!.isNotEmpty) {
      _selectedSubCategoryId = '${_categoryList!.first.id}';
    } else {
      _selectedSubCategoryId = null;
    }
    _categoryProductModel = _selectedSubCategoryId == null
        ? null
        : _kioskProductsByCategory[_selectedSubCategoryId];
  }

  Future<void> _persistKioskMenuToDisk(String localeCode) async {
    final prefs = categoryRepo?.sharedPreferences;
    if (prefs == null || _categoryModel == null) return;

    try {
      final productsMap = <String, dynamic>{};
      _kioskProductsByCategory.forEach((id, model) {
        productsMap[id] = model.toJson();
      });

      await prefs.setString(
        AppConstants.kioskMenuCacheKey,
        jsonEncode({
          'locale': localeCode,
          'branchId': _kioskPrefetchBranchId ?? _sessionBranchId,
          'fetchedAt': DateTime.now().millisecondsSinceEpoch,
          'categories': {
            'total_size': _categoryModel!.totalSize,
            'limit': _categoryModel!.limit,
            'offset': _categoryModel!.offset,
            'categories': (_categoryList ?? []).map((c) => c.toJson()).toList(),
          },
          'productsByCategory': productsMap,
        }),
      );
    } catch (_) {
      // Best-effort persistence — in-memory cache still works.
    }
  }

  /// Highlight [categoryID] in the rail immediately WITHOUT swapping the visible
  /// products. Lets the menu warm the target category's images first and swap
  /// the grid in only once they're ready, so a category switch never flickers.
  void setSelectedCategoryHighlight(String categoryID) {
    if (_selectedSubCategoryId == categoryID) return;
    _selectedSubCategoryId = categoryID;
    notifyListeners();
  }

  /// Switch the kiosk menu to [categoryID] using cached products for an instant,
  /// loading-free swap. Falls back to a network load only when that category was
  /// never prefetched.
  Future<void> selectKioskCategory(String categoryID) async {
    final cached = _kioskProductsByCategory[categoryID];

    if (cached != null) {
      _selectedSubCategoryId = categoryID;
      _categoryProductModel = cached;
      notifyListeners();
      return;
    }

    // Not prefetched (e.g. deep-link/cold start) — token-scoped kiosk catalog.
    if (categoryRepo != null) {
      final ApiResponseModel apiResponse = await categoryRepo!.getKioskProductList(
        categoryID: categoryID,
        offset: 1,
        type: 'all',
        limit: _kioskPrefetchProductLimit,
      );
      if (apiResponse.response != null &&
          apiResponse.response!.statusCode == 200) {
        _categoryProductModel =
            ProductModel.fromJson(apiResponse.response?.data);
        _kioskProductsByCategory[categoryID] = _categoryProductModel!;
        _selectedSubCategoryId = categoryID;
        notifyListeners();
        return;
      }
    }

    await getCategoryProductList(categoryID, 1, limit: _kioskPrefetchProductLimit);
    if (_categoryProductModel != null) {
      _kioskProductsByCategory[categoryID] = _categoryProductModel!;
    }
  }

  List<CategoryModel>? get categoryList => _categoryList;
  List<CategoryModel>? get suggestionList => _suggestionList;
  List<CategoryModel>? get searchCategoryList => _searchCategoryList;

  List<CategoryModel>? get subCategoryList => _subCategoryList;
  ProductModel? get categoryProductModel => _categoryProductModel;

  CategoryData? get categoryModel => _categoryModel;
  CategoryData? get searchCategoryModel => _searchCategoryModel;

  bool get pageFirstIndex => _pageFirstIndex;
  bool get pageLastIndex => _pageLastIndex;
  bool get isLoading => _isLoading;
  String? get selectedSubCategoryId => _selectedSubCategoryId;
  TextEditingController get searchController => _searchController;
  int get searchLength => _searchLength;
  bool get isSearch => _isSearch;

  Future<void> getCategoryList(bool reload,
      {DataSourceEnum source = DataSourceEnum.local,
      int limit = 24,
      int offset = 1}) async {
    if (_categoryList == null || reload || offset != 1) {
      _isLoading = true;

      if (offset == 1) {
        await fetchAndSyncData(
          fetchFromLocal: () => categoryRepo!
              .getCategoryList<CacheResponseData>(source: DataSourceEnum.local),
          fetchFromClient: () => categoryRepo!.getCategoryList(
              source: DataSourceEnum.client, limit: limit, offset: offset),
          onResponse: (data, _) {
            _categoryList = [];
            try {
              _categoryModel = CategoryData.fromJson(data);
              _categoryList!.addAll(_categoryModel?.categories ?? []);

              if (_categoryList!.isNotEmpty) {
                _selectedSubCategoryId = '${_categoryList?.first.id}';
              }
            } catch (_) {
              _categoryList = [];
            }
            _isLoading = false;

            notifyListeners();
          },
        );
      } else {
        if (_categoryModel == null || offset != 1) {
          ApiResponseModel? response = await categoryRepo!.getCategoryList(
              source: DataSourceEnum.client, limit: limit, offset: offset);
          if (response.response?.data != null &&
              response.response?.statusCode == 200) {
            if (offset == 1) {
              _categoryList = [];
              _categoryModel = CategoryData.fromJson(response.response?.data);
              _categoryList!.addAll(_categoryModel?.categories ?? []);
            } else {
              _categoryModel = CategoryData.fromJson(response.response?.data);
              _categoryList?.addAll(
                  CategoryData.fromJson(response.response?.data).categories ??
                      []);
            }
            _isLoading = false;
            notifyListeners();
          } else {
            ApiCheckerHelper.checkApi(response);
          }
        }
      }
    }
  }

  Future<void> getSearchCategoryList(
      {int limit = 24, int offset = 1, String? query}) async {
    _isLoading = true;
    notifyListeners();

    ApiResponseModel? response = await categoryRepo!.getCategoryList(
        source: DataSourceEnum.client,
        limit: limit,
        offset: offset,
        query: query ?? "");
    if (response.response?.data != null &&
        response.response?.statusCode == 200) {
      if (offset == 1) {
        _searchCategoryList = [];
        _searchCategoryModel = CategoryData.fromJson(response.response?.data);
        _searchCategoryList!.addAll(_searchCategoryModel?.categories ?? []);
      } else {
        _searchCategoryModel = CategoryData.fromJson(response.response?.data);
        _searchCategoryList?.addAll(
            CategoryData.fromJson(response.response?.data).categories ?? []);
      }
    } else {
      ApiCheckerHelper.checkApi(response);
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> getSuggestionCategoryList() async {
    ApiResponseModel? response = await categoryRepo!.getCategoryList(
        source: DataSourceEnum.client,
        limit: 5,
        offset: 1,
        query: _searchController.text);

    if (response.response?.data != null &&
        response.response?.statusCode == 200) {
      if (response.response?.data['categories'].isNotEmpty) {
        _suggestionList = [];
        response.response?.data['categories'].forEach((category) =>
            _suggestionList!.add(CategoryModel.fromJson(category)));
      }
      notifyListeners();
    }
  }

  void getSubCategoryList(String categoryID,
      {String type = 'all', String? name}) async {
    _subCategoryList = null;
    _isLoading = true;
    ApiResponseModel apiResponse =
        await categoryRepo!.getSubCategoryList(categoryID);
    if (apiResponse.response != null &&
        apiResponse.response!.statusCode == 200) {
      _subCategoryList = [];
      apiResponse.response!.data.forEach((category) =>
          _subCategoryList!.add(CategoryModel.fromJson(category)));
      getCategoryProductList(categoryID, 1, type: type);
    } else {
      ApiCheckerHelper.checkApi(apiResponse);
    }
    _isLoading = false;
    notifyListeners();
  }

  Future getCategoryProductList(String? categoryID, int offset,
      {String type = 'all', String? name, int limit = 10}) async {
    if (_selectedSubCategoryId != categoryID || offset == 1) {
      _categoryProductModel = null;
    }
    _selectedSubCategoryId = categoryID;
    notifyListeners();

    if (_categoryProductModel == null || offset != 1) {
      ApiResponseModel apiResponse = await categoryRepo!.getCategoryProductList(
          categoryID: categoryID,
          offset: offset,
          type: type,
          name: name,
          limit: limit);

      if (apiResponse.response != null &&
          apiResponse.response!.statusCode == 200) {
        if (offset == 1) {
          _categoryProductModel =
              ProductModel.fromJson(apiResponse.response?.data);
        } else {
          _categoryProductModel?.totalSize =
              ProductModel.fromJson(apiResponse.response?.data).totalSize;
          _categoryProductModel?.offset =
              ProductModel.fromJson(apiResponse.response?.data).offset;
          _categoryProductModel?.products?.addAll(
              ProductModel.fromJson(apiResponse.response?.data).products ?? []);
        }
      } else {
        ApiCheckerHelper.checkApi(apiResponse);
      }
    }

    notifyListeners();
  }

  /// Products for the given category IDs from the kiosk prefetch cache.
  List<Product> kioskProductsForCategoryIds(List<int> categoryIds) {
    final List<Product> products = [];
    for (final id in categoryIds) {
      products.addAll(_kioskProductsByCategory['$id']?.products ?? const []);
    }
    return products;
  }

  int _selectCategory = -1;
  final List<int> _selectedCategoryList = [];

  int get selectCategory => _selectCategory;
  List<int> get selectedCategoryList => _selectedCategoryList;

  void updateSelectCategory({required int id}) {
    _selectCategory = id;
    if (_selectedCategoryList.contains(id)) {
      _selectedCategoryList.remove(id);
    } else {
      _selectedCategoryList.add(id);
    }

    debugPrint(selectedCategoryList.toString());
    notifyListeners();
  }

  void clearSelectedCategory() {
    _selectedCategoryList.clear();
    notifyListeners();
  }

  updateProductCurrentIndex(int index, int totalLength) {
    if (index > 0) {
      _pageFirstIndex = false;
      notifyListeners();
    } else {
      _pageFirstIndex = true;
      notifyListeners();
    }
    if (index + 1 == totalLength) {
      _pageLastIndex = true;
      notifyListeners();
    } else {
      _pageLastIndex = false;
      notifyListeners();
    }
  }

  getSearchText(String searchText, {bool isUpdate = true}) {
    _searchLength = searchText.length;

    if (_searchLength < 1) {
      _searchCategoryModel = null;
      _searchCategoryList = null;
    }
    if (isUpdate) {
      notifyListeners();
    }
  }

  searchDone() {
    _isSearch = !_isSearch;
    notifyListeners();
  }

  int _menuRevision = 0;
  int get menuRevision => _menuRevision;
  void setMenuRevision(int revision) {
    if (revision > _menuRevision) {
      _menuRevision = revision;
    }
  }

  /// Latest cached copy of a product across every prefetched category bucket.
  /// Used by the open customize sheet to pick up product.changed refetches.
  Product? findCachedProduct(int? productId) {
    if (productId == null) return null;
    for (final model in _kioskProductsByCategory.values) {
      final list = model.products;
      if (list == null) continue;
      for (final product in list) {
        if (product.id == productId) {
          return product;
        }
      }
    }
    final selected = _categoryProductModel?.products;
    if (selected != null) {
      for (final product in selected) {
        if (product.id == productId) {
          return product;
        }
      }
    }
    return null;
  }

  void applyRealtimeRemove(int productId) {
    var changed = false;
    for (final model in _kioskProductsByCategory.values) {
      final list = model.products;
      if (list == null) continue;
      final before = list.length;
      list.removeWhere((p) => p.id == productId);
      if (list.length != before) {
        changed = true;
        final total = model.totalSize;
        if (total != null && total > 0) {
          model.totalSize = total - 1;
        }
      }
    }
    if (changed) {
      notifyListeners();
      final locale = _kioskPrefetchLocale;
      if (locale != null) {
        _persistKioskMenuToDisk(locale);
      }
    }
  }

  void applyRealtimeUpsert(Product product) {
    final int? id = product.id;
    if (id == null) return;
    if (_sessionBranchId == null ||
        _kioskPrefetchBranchId != _sessionBranchId) {
      return;
    }

    var found = false;
    for (final model in _kioskProductsByCategory.values) {
      final list = model.products;
      if (list == null) continue;
      final index = list.indexWhere((p) => p.id == id);
      if (index >= 0) {
        list[index] = product;
        found = true;
      }
    }

    if (!found) {
      String? categoryId;
      if (product.categoryIds != null) {
        for (final cat in product.categoryIds!) {
          final cid = cat.id;
          if (cid != null && _kioskProductsByCategory.containsKey(cid)) {
            categoryId = cid;
            break;
          }
        }
        categoryId ??= product.categoryIds!.isNotEmpty
            ? product.categoryIds!.first.id
            : null;
      }
      categoryId ??= _selectedSubCategoryId;
      if (categoryId == null) return;

      final ProductModel model = _kioskProductsByCategory.putIfAbsent(
        categoryId,
        () => ProductModel.fromJson({'products': <dynamic>[]}),
      );
      model.products ??= [];
      model.products!.insert(0, product);
      model.totalSize = (model.totalSize ?? model.products!.length - 1) + 1;
    }

    if (_selectedSubCategoryId != null) {
      _categoryProductModel = _kioskProductsByCategory[_selectedSubCategoryId];
    }
    notifyListeners();
    final locale = _kioskPrefetchLocale;
    if (locale != null) {
      _persistKioskMenuToDisk(locale);
    }
  }
}
