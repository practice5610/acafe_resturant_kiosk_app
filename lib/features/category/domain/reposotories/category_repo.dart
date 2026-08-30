import 'package:acafe_customer/common/enums/data_source_enum.dart';
import 'package:acafe_customer/common/reposotories/data_sync_repo.dart';
import 'package:acafe_customer/data/datasource/remote/exception/api_error_handler.dart';
import 'package:acafe_customer/common/models/api_response_model.dart';
import 'package:acafe_customer/utill/app_constants.dart';

class CategoryRepo extends DataSyncRepo{
  CategoryRepo({required super.dioClient, required super.sharedPreferences});

  Future<ApiResponseModel<T>> getCategoryList<T>({required DataSourceEnum source, String query = "", int offset = 1, int limit = 24}) async {
    return await fetchData<T>("${AppConstants.categoryUri}?limit=$limit&offset=$offset&name=$query", source);
  }

  Future<ApiResponseModel> getSubCategoryList(String parentID) async {
    try {
      final response = await dioClient.get('${AppConstants.subCategoryUri}$parentID',
      );
      return ApiResponseModel.withSuccess(response);
    } catch (e) {
      return ApiResponseModel.withError(ApiErrorHandler.getMessage(e));
    }
  }

  Future<ApiResponseModel> getCategoryProductList({required String? categoryID, required int offset, int limit = 10, required String type, String? name}) async {

    try {
      final response = await dioClient.get('${AppConstants.categoryProductUri}$categoryID?offset=$offset&limit=$limit&product_type=$type${name != null ? '&search=$name' : ''}');
      return ApiResponseModel.withSuccess(response);
    } catch (e) {
      return ApiResponseModel.withError(ApiErrorHandler.getMessage(e));
    }
  }

  /// Token-scoped catalog for the signed-in kiosk device. Branch comes from
  /// the device token, never from the client `branch-id` header.
  Future<ApiResponseModel> getKioskCategoryList({
    int offset = 1,
    int limit = 24,
  }) async {
    try {
      final response = await dioClient.get(
        '${AppConstants.kioskCategoriesUri}?limit=$limit&offset=$offset',
      );
      return ApiResponseModel.withSuccess(response);
    } catch (e) {
      return ApiResponseModel.withError(ApiErrorHandler.getMessage(e));
    }
  }

  Future<ApiResponseModel> getKioskProductList({
    String? categoryID,
    required int offset,
    int limit = 10,
    String type = 'all',
    String? name,
  }) async {
    try {
      final buffer = StringBuffer(
        '${AppConstants.kioskProductsUri}?offset=$offset&limit=$limit&product_type=$type',
      );
      if (categoryID != null && categoryID.isNotEmpty) {
        buffer.write('&category_id=$categoryID');
      }
      if (name != null && name.isNotEmpty) {
        buffer.write('&name=$name');
      }
      final response = await dioClient.get(buffer.toString());
      return ApiResponseModel.withSuccess(response);
    } catch (e) {
      return ApiResponseModel.withError(ApiErrorHandler.getMessage(e));
    }
  }
}