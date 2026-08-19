import 'package:acafe_customer/common/enums/data_source_enum.dart';
import 'package:acafe_customer/common/enums/product_sort_type_enum.dart';
import 'package:acafe_customer/common/models/api_response_model.dart';
import 'package:acafe_customer/common/reposotories/data_sync_repo.dart';
import 'package:acafe_customer/data/datasource/remote/exception/api_error_handler.dart';
import 'package:acafe_customer/localization/app_localization.dart';
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:dio/dio.dart';

class ProductRepo extends DataSyncRepo {
  ProductRepo({required super.dioClient, required super.sharedPreferences});

  Future<ApiResponseModel<T>> getLatestProductList<T>({required int offset, required ProductSortType type,  required DataSourceEnum source}) async {
    return await fetchData<T>('${AppConstants.latestProductUri}?limit=15&offset=$offset&sort_by=${type.name.camelCaseToSnakeCase()}', source);
  }

  // Future<ApiResponseModel> getLatestProductList(int offset, ProductSortType type) async {
  //   try {
  //     final response = await dioClient.get(
  //       '${AppConstants.latestProductUri}?limit=15&&offset=$offset&sort_by=${type.name.camelCaseToSnakeCase()}',
  //     );
  //     return ApiResponseModel.withSuccess(response);
  //   } catch (e) {
  //     return ApiResponseModel.withError(ApiErrorHandler.getMessage(e));
  //   }
  //
  // }

  Future<ApiResponseModel<T>> getRecommendedProductApi<T>({required int offset, required DataSourceEnum source}) async {
    return await fetchData<T>('${AppConstants.recommendedProductUri}?limit=100&&offset=$offset', source);
  }

  // Future<ApiResponseModel> getRecommendedProductApi(int offset) async {
  //   try {
  //     final response = await dioClient.get(
  //       '${AppConstants.recommendedProductUri}?limit=100&&offset=$offset',
  //     );
  //     return ApiResponseModel.withSuccess(response);
  //   } catch (e) {
  //     return ApiResponseModel.withError(ApiErrorHandler.getMessage(e));
  //   }
  //
  // }

  Future<ApiResponseModel<T>> getPopularProductList<T>({required int offset, required DataSourceEnum source}) async {
    return await fetchData<T>('${AppConstants.popularProductUri}?limit=10&&offset=$offset&product_type=all', source);
  }


  // Future<T> getPopularProductList<T>(int offset, {required DataSourceEnum dataSource}) async {
  //   switch(dataSource){
  //     case DataSourceEnum.client:
  //       try {
  //         final response = await dioClient!.get(
  //           '${AppConstants.popularProductUri}?limit=10&&offset=$offset&product_type=all',
  //         );
  //         await DbHelper.insertOrUpdate(id: AppConstants.popularProductUri, data: CacheResponseCompanion(
  //           endPoint: const Value(AppConstants.popularProductUri),
  //           header: Value(dioClient?.dio?.options.headers.toString() ?? ''),
  //           response: Value(jsonEncode(response.data)),
  //         ));
  //         return ApiResponseModel.withSuccess(response) as T;
  //       } catch (e) {
  //         return ApiResponseModel.withError(ApiErrorHandler.getMessage(e)) as T;
  //       }
  //     case DataSourceEnum.local:
  //       try {
  //         final CacheResponseData? cacheResponseData = await database.getCacheResponseById(AppConstants.popularProductUri);
  //         return ApiResponseModel<CacheResponseData>.withSuccess(cacheResponseData) as T;
  //
  //       } catch (e) {
  //         return ApiResponseModel.withError(ApiErrorHandler.getMessage(e)) as T;
  //       }
  //
  //
  //   }
  //
  // }

  Future<ApiResponseModel<T>> getFlavorFulMenuProductApi<T>({required int offset, required DataSourceEnum source}) async {
    return await fetchData<T>('${AppConstants.setMenuUri}?limit=12&&offset=$offset', source);
  }
  // Future<ApiResponseModel> getFlavorFulMenuProductApi(int offset) async {
  //
  //   try {
  //     final response = await dioClient!.get(
  //       '${AppConstants.setMenuUri}?limit=12&&offset=$offset',
  //     );
  //     return ApiResponseModel.withSuccess(response);
  //   } catch (e) {
  //     return ApiResponseModel.withError(ApiErrorHandler.getMessage(e));
  //   }
  //
  // }



  Future<ApiResponseModel> getFrequentlyBoughtProductApi(int offset) async {
    try {
      final response = await dioClient.get(
        '${AppConstants.frequentlyBoughtApi}?limit=4&&offset=$offset',
      );
      return ApiResponseModel.withSuccess(response);
    } catch (e) {
      return ApiResponseModel.withError(ApiErrorHandler.getMessage(e));
    }

  }

  Future<ApiResponseModel> getReorderProductApi(int? orderId) async {
    try {
      final response = await dioClient.post(AppConstants.getReorderProducts, data: {'order_id' : '$orderId'});
      return ApiResponseModel.withSuccess(response);
    } catch (e) {
      return ApiResponseModel.withError(ApiErrorHandler.getMessage(e));
    }

  }

  Future<ApiResponseModel> getProductDetails(int id) async {
    try {
      final response = await dioClient.get('${AppConstants.productDetailsUri}$id');
      return ApiResponseModel.withSuccess(response);
    } on DioException catch (e) {
      return ApiResponseModel.withError(e);
    } catch (e) {
      return ApiResponseModel.withError(ApiErrorHandler.getMessage(e));
    }
  }

  Future<ApiResponseModel> syncMenu({required int sinceRevision}) async {
    try {
      final response = await dioClient.get(
        '${AppConstants.productSyncUri}?since_revision=$sinceRevision',
      );
      return ApiResponseModel.withSuccess(response);
    } catch (e) {
      return ApiResponseModel.withError(ApiErrorHandler.getMessage(e));
    }
  }

}
