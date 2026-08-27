import 'package:acafe_customer/common/models/api_response_model.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/exception/api_error_handler.dart';
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class KioskDealRepo {
  final DioClient dioClient;
  final SharedPreferences sharedPreferences;

  KioskDealRepo({required this.dioClient, required this.sharedPreferences});

  Future<ApiResponseModel> getDeals() async {
    try {
      final response = await dioClient.get(AppConstants.kioskDealsUri);
      return ApiResponseModel.withSuccess(response);
    } catch (e) {
      return ApiResponseModel.withError(ApiErrorHandler.getMessage(e));
    }
  }

  Future<ApiResponseModel> getDeal(int id) async {
    try {
      final response = await dioClient.get('${AppConstants.kioskDealsUri}/$id');
      return ApiResponseModel.withSuccess(response);
    } catch (e) {
      return ApiResponseModel.withError(ApiErrorHandler.getMessage(e));
    }
  }

  String? readCache() =>
      sharedPreferences.getString(AppConstants.kioskDealsCacheKey);

  Future<void> writeCache(String json) async {
    await sharedPreferences.setString(AppConstants.kioskDealsCacheKey, json);
  }
}
