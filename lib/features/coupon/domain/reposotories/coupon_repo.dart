import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/exception/api_error_handler.dart';
import 'package:acafe_customer/common/models/api_response_model.dart';
import 'package:acafe_customer/utill/app_constants.dart';

class CouponRepo {
  final DioClient? dioClient;
  CouponRepo({required this.dioClient});

  Future<ApiResponseModel> getCouponList({String? guestId, double? orderAmount}) async {
    try {
      final response = await dioClient!.get(guestId != null ? '${AppConstants.couponUri}?guest_id=$guestId&amount=${orderAmount ?? ""}' : "${AppConstants.couponUri}?amount=${orderAmount??""}");
      return ApiResponseModel.withSuccess(response);
    } catch (e) {
      return ApiResponseModel.withError(ApiErrorHandler.getMessage(e));
    }
  }

  Future<ApiResponseModel> applyCoupon(String couponCode, {String? guestId}) async {
    try {
      final response = await dioClient!.get('${AppConstants.couponApplyUri}$couponCode${guestId != null ? '&guest_id=$guestId' : ''}');
      return ApiResponseModel.withSuccess(response);
    } catch (e) {
      return ApiResponseModel.withError(ApiErrorHandler.getMessage(e));
    }
  }
}