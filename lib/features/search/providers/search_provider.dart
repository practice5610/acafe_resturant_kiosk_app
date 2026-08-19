import 'package:flutter/material.dart';
import 'package:acafe_customer/common/enums/data_source_enum.dart';
import 'package:acafe_customer/common/models/api_response_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/common/providers/data_sync_provider.dart';
import 'package:acafe_customer/features/category/providers/category_provider.dart';
import 'package:acafe_customer/features/search/search_flow_helper.dart';
import 'package:acafe_customer/features/search/domain/models/search_recommend_model.dart';
import 'package:acafe_customer/features/search/domain/reposotories/search_repo.dart';
import 'package:acafe_customer/helper/api_checker_helper.dart';
import 'package:acafe_customer/main.dart';
import 'package:provider/provider.dart';


class SearchProvider extends DataSyncProvider {
  final SearchRepo? searchRepo;

  SearchProvider({required this.searchRepo});

  int? _selectedPriceIndex;
  List<List<int>> _priceList = [];
  // final List<int> _priceList = [10, 100, 1000, 10000];


  final List<String> _sortByList = [
    'a_to_z',
    'z_to_a',
    'price_high_to_low',
    'price_low_to_high',
  ];
  List<String> _historyList = [];
  final Map<String, String> _historyMap = {};
  bool _isSearch = true;
  final TextEditingController _searchController = TextEditingController();
  int _searchLength = 0;
  bool _isLoading = false;
  ProductModel? _searchProductModel;
  List<String>? _productSearchName;
  List<String>? _autoCompletedName;
  SearchRecommendModel? _searchRecommendModel;
  int? _selectedSortByIndex;
  bool _halalTagStatus = false;
  bool _filtersCommitted = false;


  int? get selectedPriceIndex => _selectedPriceIndex;
  List<List<int>> get priceFilterList => _priceList;
  List<String> get historyList => _historyList;
  Map<String, String> get historyMap => _historyMap;
  TextEditingController  get searchController=> _searchController;
  int get searchLength => _searchLength;
  bool get isSearch => _isSearch;
  bool get isLoading => _isLoading;
  ProductModel? get searchProductModel=> _searchProductModel;
  List<String>? get productSearchName=> _productSearchName;
  List<String>? get autoCompletedName=> _autoCompletedName;
  SearchRecommendModel? get searchRecommendModel=> _searchRecommendModel;
  List<String> get getSortByList => _sortByList;
  int? get selectedSortByIndex => _selectedSortByIndex;
  bool get halalTagStatus => _halalTagStatus;
  bool get filtersCommitted => _filtersCommitted;




  searchDone(){
    _isSearch = !_isSearch;
    notifyListeners();
  }

  getSearchText(String searchText){
    _searchLength = searchText.length;
    notifyListeners();
  }

  void _setPriceIndex(int? index) {
    _selectedPriceIndex = index;
    notifyListeners();
  }



  void updatePriceFilter(int? index){
    if(index != _selectedPriceIndex){
      _setPriceIndex(index);

    }else{
      _setPriceIndex(null);
      debugPrint('Removed Price Filter');
    }
    // notifyListeners();
  }


  void onClearSearchSuggestion()=> _autoCompletedName = null;

  Future<void> getProductSearchTagList(String? name, {bool isReload = false}) async {

    ApiResponseModel apiResponse = await searchRepo!.getSuggestionList(name);

    if (apiResponse.response?.statusCode == 200 && apiResponse.response?.data != null) {
      // _productSearchName = apiResponse.response?.data.map((item)=> SuggestionModel(
      //   suggestion: item,
      //   type: SuggestionType.search,
      // ));

      _productSearchName = apiResponse.response?.data.cast<String>();
    }
    notifyListeners();
  }

  Future<void> getSearchRecommendedData({bool isReload = false}) async {
    if(isReload) {
      _searchRecommendModel = null;
    }

    if(_searchRecommendModel == null) {
      fetchAndSyncData(
        fetchFromLocal:()=> searchRepo!.getSearchRecommendedApi(source: DataSourceEnum.local),
        fetchFromClient: ()=> searchRepo!.getSearchRecommendedApi(source: DataSourceEnum.client),
        onResponse: (data, _) {
          _searchRecommendModel = SearchRecommendModel.fromJson(data);
          notifyListeners();
        },
      );

    }
  }



  bool _isClear = true;
  String _searchText = '';



  bool get isClear => _isClear;

  String get searchText => _searchText;

  void setSearchText(String text) {
    _searchText = text;
    // notifyListeners();
  }

  void cleanSearchProduct() {
    _isClear = true;
    _searchText = '';
   // notifyListeners();
  }

  Future<void> searchProduct({
    required int offset,
    required String name,
    required BuildContext context,
    bool isUpdate = true,
    String? productType,
  }) async {
    _searchText = name;
    _isLoading = true;

    if(offset == 1) {
      _searchProductModel = null;

      if(isUpdate) {
        notifyListeners();
      }
    }



    if(isUpdate) {
      notifyListeners();
    }
    final CategoryProvider categoryProvider = Provider.of<CategoryProvider>(context, listen: false);


    ApiResponseModel apiResponse = await searchRepo!.getSearchProductList(
      name: name,  offset: offset, productType: productType,
      categoriesId: categoryProvider.selectedCategoryList,
      minPrice: _selectedPriceIndex != null ? _priceList[_selectedPriceIndex!].first.toString(): null,
      maxPrice: _selectedPriceIndex != null ? _priceList[_selectedPriceIndex!].last.toString() : null,
      sortBy: _selectedSortByIndex != null ? _sortByList[_selectedSortByIndex!] : null,
      halalTag: halalTagStatus
    );

    if (apiResponse.response != null && apiResponse.response!.statusCode == 200) {

      if(offset == 1) {
        _searchProductModel = ProductModel.fromJson(apiResponse.response?.data);
        _createFilterPriceList(_searchProductModel?.productMaxPrice ?? 0);

      }else {
        _searchProductModel?.totalSize = ProductModel.fromJson(apiResponse.response?.data).totalSize;
        _searchProductModel?.offset = ProductModel.fromJson(apiResponse.response?.data).offset;
        _searchProductModel?.products?.addAll(ProductModel.fromJson(apiResponse.response?.data).products ?? []);
      }
    } else {
      ApiCheckerHelper.checkApi(apiResponse);
    }

    _isLoading = false;
    notifyListeners();
  }

  void initHistoryList() {
    _historyList = [];
    _historyList.addAll(searchRepo!.getSearchAddress());

    _addLocalSearchToMap();


  }

  void _addLocalSearchToMap()=> _historyMap.addEntries(_historyList.map((item) => MapEntry(item, item)));

  void saveSearchAddress(String searchAddress) async {
    if (!_historyList.contains(searchAddress)) {
      _historyList.add(searchAddress);
      searchRepo!.saveSearchAddress(searchAddress);
      // notifyListeners();
    }
  }

  void removeHistoryItemByIndex(int index){
    _historyList.removeAt(index);
    searchRepo?.updateSearchData(_historyList);

    notifyListeners();
  }

  void clearSearchAddress() async {
    searchRepo!.updateSearchData([]);
    _historyList = [];
    notifyListeners();
  }

  void commitFilters() {
    _filtersCommitted = true;
    notifyListeners();
  }

  void resetFilterData({bool isUpdate = true, CategoryProvider? categoryProvider}) {
    _selectedPriceIndex = null;
    _selectedSortByIndex = null;
    _halalTagStatus = false;
    _filtersCommitted = false;
    final category = categoryProvider ??
        (Get.context != null
            ? Provider.of<CategoryProvider>(Get.context!, listen: false)
            : null);
    category?.clearSelectedCategory();

    if(isUpdate) {
      notifyListeners();
    }

  }

  bool hasActiveFilters(List<int> selectedCategoryIds) {
    return SearchFlowHelper.hasActiveFilters(
      selectedSortByIndex: _selectedSortByIndex,
      selectedPriceIndex: _selectedPriceIndex,
      halalTagStatus: _halalTagStatus,
      selectedCategoryIds: selectedCategoryIds,
    );
  }

  Future<void> onChangeAutoCompleteTag({String? searchText}) async {
    _autoCompletedName = null;
    notifyListeners();

    await getProductSearchTagList(searchText);

    final normalizedSearchText = searchText?.toLowerCase().replaceAll(' ', '') ?? '';

    _autoCompletedName = [
      ..._historyList.where(
            (tag) => tag.toLowerCase().replaceAll(' ', '').contains(normalizedSearchText),
      ),
      ...?_productSearchName
    ];

    notifyListeners();
  }


  void _createFilterPriceList(double amount) {
     _priceList = [];
    int digit = '${amount.ceil()}'.length;

    for (int i = 0; i < digit; i++) {

      int min = i == 0 ? 0 : int.parse('1${'0' * i}');
      int max = int.parse('1${'0' * (i + 1)}');

      _priceList.add([min, max]);
    }

  }

  void initPriceFilterList(double maxPrice) {
    _createFilterPriceList(maxPrice);
    notifyListeners();
  }

  void onChangeSortByIndex(int? index) {
    _selectedSortByIndex = _selectedSortByIndex == index ? null : index;
    notifyListeners();
  }

  void onChangeHalalTagStatus({bool? status }) {
    _halalTagStatus = status ?? false;
    notifyListeners();
  }





}

// enum SuggestionType {
//   history,
//   search,
// }
// class SuggestionModel {
//   final String suggestion;
//   final SuggestionType type;
//
//   SuggestionModel({required this.suggestion, required this.type});
// }