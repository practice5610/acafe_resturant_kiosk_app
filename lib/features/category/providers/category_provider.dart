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
  DateTime? _kioskPrefetchCompletedAt;
  Future<void>? _kioskPrefetchFuture;
  final Map<String, ProductModel> _kioskProductsByCategory = {};

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

  /// Whether categories + first-category products are ready for instant menu render.
  bool isKioskMenuReadyFor(String localeCode) {
    return _categoryList != null &&
        _categoryList!.isNotEmpty &&
        _categoryProductModel != null &&
        _kioskPrefetchLocale == localeCode;
  }

  /// Prefetch categories + all category products for the kiosk welcome screen.
  /// Non-blocking when called without await. Safe to call multiple times.
  Future<void> prefetchKioskMenu({
    required String localeCode,
    bool force = false,
    bool background = false,
  }) {
    if (!force &&
        !background &&
        isKioskMenuReadyFor(localeCode) &&
        _kioskPrefetchCompletedAt != null &&
        DateTime.now().difference(_kioskPrefetchCompletedAt!) <
            _kioskMenuCacheMaxAge) {
      return Future.value();
    }

    if (_kioskPrefetchFuture != null) {
      return _kioskPrefetchFuture!;
    }

    _kioskPrefetchFuture =
        _runKioskPrefetch(localeCode: localeCode, background: background);
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

  /// Hydrate from SharedPreferences then refresh in the background (SWR).
  Future<void> warmKioskMenuFromDisk(String localeCode) async {
    if (_hydrateKioskMenuFromDisk(localeCode)) {
      notifyListeners();
    }
    prefetchKioskMenu(localeCode: localeCode, background: true);
  }

  Future<void> _runKioskPrefetch({
    required String localeCode,
    required bool background,
  }) async {
    if (!background) {
      final hydrated = _hydrateKioskMenuFromDisk(localeCode);
      if (hydrated && isKioskMenuReadyFor(localeCode)) {
        notifyListeners();
      }
    }

    var ok = await _fetchKioskMenuFromNetwork(localeCode);
    if (!ok) {
      ok = await _fetchKioskMenuFromNetwork(localeCode);
    }

    if (ok) {
      _kioskPrefetchLocale = localeCode;
      _kioskPrefetchCompletedAt = DateTime.now();
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
      if (storedLocale != localeCode || fetchedAtMs == null) return false;

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
      _kioskPrefetchCompletedAt =
          DateTime.fromMillisecondsSinceEpoch(fetchedAtMs);
      return _categoryProductModel != null;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _fetchKioskMenuFromNetwork(String localeCode) async {
    if (categoryRepo == null) return false;

    try {
      final ApiResponseModel catResponse = await categoryRepo!.getCategoryList(
        source: DataSourceEnum.client,
        limit: 24,
        offset: 1,
      );
      if (catResponse.response?.statusCode != 200) return false;

      final categories =
          CategoryData.fromJson(catResponse.response!.data).categories ?? [];
      if (categories.isEmpty) return false;

      final Map<String, ProductModel> productsByCategory = {};

      for (final category in categories) {
        final ApiResponseModel prodResponse =
            await categoryRepo!.getCategoryProductList(
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

      if (productsByCategory.isEmpty) return false;

      _categoryList = List<CategoryModel>.from(categories);
      _categoryModel = CategoryData.fromJson(catResponse.response!.data);
      _kioskProductsByCategory
        ..clear()
        ..addAll(productsByCategory);

      _selectedSubCategoryId = '${_categoryList!.first.id}';
      _categoryProductModel = _kioskProductsByCategory[_selectedSubCategoryId];
      _isLoading = false;
      return _categoryProductModel != null;
    } catch (_) {
      return false;
    }
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
          'fetchedAt': DateTime.now().millisecondsSinceEpoch,
          'categories': {
            'total_size': _categoryModel!.totalSize,
            'limit': _categoryModel!.limit,
            'offset': _categoryModel!.offset,
            'categories': _categoryList!.map((c) => c.toJson()).toList(),
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
  /// never prefetched. When the cache is stale it refreshes silently in the
  /// background (the grid stays visible — the update is applied in place).
  Future<void> selectKioskCategory(String categoryID) async {
    final cached = _kioskProductsByCategory[categoryID];

    if (cached != null) {
      _selectedSubCategoryId = categoryID;
      _categoryProductModel = cached;
      notifyListeners();

      final fresh = _kioskPrefetchCompletedAt != null &&
          DateTime.now().difference(_kioskPrefetchCompletedAt!) <
              _kioskMenuCacheMaxAge;
      if (!fresh) {
        _refreshKioskCategorySilently(categoryID);
      }
      return;
    }

    // Not prefetched (e.g. deep-link/cold start) — normal load with skeleton.
    await getCategoryProductList(categoryID, 1, limit: _kioskPrefetchProductLimit);
    if (_categoryProductModel != null) {
      _kioskProductsByCategory[categoryID] = _categoryProductModel!;
    }
  }

  /// Re-pull one category's products and update the cache without ever clearing
  /// the currently-shown products (so there is no loading flash on the grid).
  Future<void> _refreshKioskCategorySilently(String categoryID) async {
    if (categoryRepo == null) return;
    try {
      final ApiResponseModel resp = await categoryRepo!.getCategoryProductList(
        categoryID: categoryID,
        offset: 1,
        type: 'all',
        limit: _kioskPrefetchProductLimit,
      );
      if (resp.response?.statusCode != 200) return;

      final model = ProductModel.fromJson(resp.response!.data);
      _kioskProductsByCategory[categoryID] = model;
      if (_selectedSubCategoryId == categoryID) {
        _categoryProductModel = model;
        notifyListeners();
      }
      if (_kioskPrefetchLocale != null) {
        await _persistKioskMenuToDisk(_kioskPrefetchLocale!);
      }
    } catch (_) {
      // Best-effort silent refresh — the cached data stays on screen.
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
}
