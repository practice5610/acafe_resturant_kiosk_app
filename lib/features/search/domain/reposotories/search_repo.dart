import 'package:acafe_customer/common/enums/data_source_enum.dart';
import 'package:acafe_customer/common/reposotories/data_sync_repo.dart';
import 'package:acafe_customer/data/datasource/remote/exception/api_error_handler.dart';
import 'package:acafe_customer/common/models/api_response_model.dart';
import 'package:acafe_customer/utill/app_constants.dart';

class SearchRepo extends DataSyncRepo{
  SearchRepo({required super.dioClient, required super.sharedPreferences});

  Future<ApiResponseModel> getSearchProductList({
    required String name,
    required int offset,
    String? minPrice,
    String? maxPrice,
    List<int>? categoriesId,
    String? productType,
    String? sortBy,
    bool? halalTag,

  }) async {

    final data = {
      if (name.isNotEmpty) 'name': name,
      if (minPrice != null) 'min_price': minPrice,
      if (maxPrice != null) 'max_price': maxPrice,
      if (categoriesId != null && categoriesId.isNotEmpty) 'category_id': categoriesId,
      if (productType != null) 'product_type': productType,
      if (sortBy != null) 'sort_by': sortBy,
      if(halalTag != null) 'is_halal' : halalTag ? 1 : 0
    };


    try {
      final response = await dioClient.post('${AppConstants.searchUri}?limit=10&offset=$offset', data: data);

      return ApiResponseModel.withSuccess(response);
    } catch (e) {
      return ApiResponseModel.withError(ApiErrorHandler.getMessage(e));
    }
  }

  // for save home address
  Future<void> saveSearchAddress(String searchAddress) async {
    try {
      List<String> searchKeywordList = sharedPreferences!.getStringList(AppConstants.searchAddress) ?? [];
      if (!searchKeywordList.contains(searchAddress)) {
        searchKeywordList.add(searchAddress);
      }
      await updateSearchData(searchKeywordList);

    } catch (e) {
      rethrow;
    }
  }

  List<String> getSearchAddress() {
    return sharedPreferences!.getStringList(AppConstants.searchAddress) ?? [];
  }

  Future<bool> updateSearchData(List<String> list) async {
    return sharedPreferences!.setStringList(AppConstants.searchAddress, list);
  }


  Future<ApiResponseModel> getSuggestionList(String? name) async {
    try {
      final response = await dioClient.get('${AppConstants.searchSuggestion}?name=$name');

      return ApiResponseModel.withSuccess(response);
    } catch (e) {
      return ApiResponseModel.withError(ApiErrorHandler.getMessage(e));
    }
  }

  Future<ApiResponseModel<T>> getSearchRecommendedApi<T>({required DataSourceEnum source}) async {
    return await fetchData<T>(AppConstants.searchRecommended, source);
  }
}
