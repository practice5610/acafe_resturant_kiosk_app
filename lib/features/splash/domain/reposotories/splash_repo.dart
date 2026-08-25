import 'package:acafe_customer/common/enums/data_source_enum.dart';
import 'package:acafe_customer/common/reposotories/data_sync_repo.dart';
import 'package:acafe_customer/data/datasource/remote/exception/api_error_handler.dart';
import 'package:acafe_customer/common/models/api_response_model.dart';
import 'package:acafe_customer/utill/app_constants.dart';

class SplashRepo extends DataSyncRepo {
  SplashRepo({required super.sharedPreferences, required super.dioClient});


  Future<ApiResponseModel<T>> getConfig<T>({required DataSourceEnum source}) async {
    return await fetchData<T>(AppConstants.configUri, source);
  }



  Future<bool> initSharedData() {
    if(!sharedPreferences!.containsKey(AppConstants.theme)) {
      return sharedPreferences!.setBool(AppConstants.theme, false);
    }
    if(!sharedPreferences!.containsKey(AppConstants.countryCode)) {
      return sharedPreferences!.setString(AppConstants.countryCode, AppConstants.defaultCountryCode);
    }
    if(!sharedPreferences!.containsKey(AppConstants.languageCode)) {
      return sharedPreferences!.setString(AppConstants.languageCode, AppConstants.defaultLanguageCode);
    }
    if(!sharedPreferences!.containsKey(AppConstants.onBoardingSkip)) {
      return sharedPreferences!.setBool(AppConstants.onBoardingSkip, true);
    }
    if(!sharedPreferences!.containsKey(AppConstants.cartList)) {
      return sharedPreferences!.setStringList(AppConstants.cartList, []);
    }
    // if(!sharedPreferences.containsKey(AppConstants.cookiesManagement)) {
    //   return sharedPreferences.st(AppConstants.cookiesManagement, false);
    // }
    return Future.value(true);
  }

  Future<bool> removeSharedData() {
    return sharedPreferences!.clear();
  }

  Future<ApiResponseModel<T>> getPolicyPage<T>({required DataSourceEnum source}) async {
    return await fetchData<T>(AppConstants.policyPage, source);
  }

  int getBranchId() => sharedPreferences?.getInt(AppConstants.branch) ?? -1;

  Future<void> setBranchId(int id) async {
    await sharedPreferences!.setInt(AppConstants.branch, id);
    if(id != -1) {
      await dioClient.updateHeader(getToken: sharedPreferences!.getString(AppConstants.token));
    }
  }

  Future<ApiResponseModel> getOfflinePaymentMethod() async {
    try {
      final response = await dioClient.get(AppConstants.offlinePaymentMethod);
      return ApiResponseModel.withSuccess(response);
    } catch (e) {
      return ApiResponseModel.withError(ApiErrorHandler.getMessage(e));
    }
  }

  Future<ApiResponseModel<T>> getDeliveryInfo<T>(int branchId, {required DataSourceEnum source}) async {
    return await fetchData<T>("${AppConstants.getDeliveryInfo}?branch_id=$branchId", source);


  }


}