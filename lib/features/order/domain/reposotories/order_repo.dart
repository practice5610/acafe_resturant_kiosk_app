import 'package:dio/dio.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/exception/api_error_handler.dart';
import 'package:acafe_customer/common/models/place_order_body.dart';
import 'package:acafe_customer/common/models/api_response_model.dart';
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OrderRepo {
  final DioClient? dioClient;
  final SharedPreferences? sharedPreferences;
  OrderRepo({required this.dioClient, required this.sharedPreferences});

  Future<ApiResponseModel> getOrderList({String? orderFilter, int? offset = 1}) async {
    try {
      final response = await dioClient!.get("${AppConstants.orderListUri}?order_filter=$orderFilter&offset=$offset&limit=10");
      return ApiResponseModel.withSuccess(response);
    } catch (e) {
      return ApiResponseModel.withError(ApiErrorHandler.getMessage(e));
    }
  }

  Future<ApiResponseModel> getOrderDetails(String orderID) async {
    try {
      final response = await dioClient!.get('${AppConstants.orderDetailsUri}$orderID');
      return ApiResponseModel.withSuccess(response);
    } catch (e) {
      return ApiResponseModel.withError(ApiErrorHandler.getMessage(e));
    }
  }

  Future<ApiResponseModel> cancelOrder(String orderID, String? guestId ) async {
    try {
      Map<String, dynamic> data = <String, dynamic>{};
      data['order_id'] = orderID;
      data['_method'] = 'put';

      if(guestId != null){
        data.addAll({'guest_id' : guestId});
      }

      final response = await dioClient!.post(AppConstants.orderCancelUri, data: data);
      return ApiResponseModel.withSuccess(response);
    } catch (e) {
      return ApiResponseModel.withError(ApiErrorHandler.getMessage(e));
    }
  }


  Future<ApiResponseModel> trackOrder(String? orderID, {String? guestId, String? phoneNumber}) async {
    try {
      final response = await dioClient!.get('${AppConstants.trackUri}$orderID${guestId != null ? '&guest_id=$guestId' : ''}');
      return ApiResponseModel.withSuccess(response);
    } catch (e) {
      return ApiResponseModel.withError(ApiErrorHandler.getMessage(e));
    }
  }

  Future<ApiResponseModel> orderDetailsWithPhoneNumber(String? orderID, String phoneNumber) async {
    try {
      final response = await dioClient!.post(AppConstants.guestOrderDetailsUrl, data: {
      'order_id' : orderID,
      'phone' : phoneNumber,
      });
      return ApiResponseModel.withSuccess(response);
    } catch (e) {
      return ApiResponseModel.withError(ApiErrorHandler.getMessage(e));
    }
  }

  Future<ApiResponseModel> trackOrderWithPhoneNumber(String? orderID, String phoneNumber) async {
    try {
      final response = await dioClient!.post(AppConstants.guestTrackUrl, data: {
        'order_id' : orderID,
        'phone' : phoneNumber,
      });
      return ApiResponseModel.withSuccess(response);
    } catch (e) {
      return ApiResponseModel.withError(ApiErrorHandler.getMessage(e));
    }
  }

  Future<ApiResponseModel> placeOrder(PlaceOrderBody orderBody,
      {String? guestId, bool asGuest = false}) async {
    try {
      Map<String, dynamic> data = orderBody.toJson();

      if(guestId != null){
        data.addAll({'guest_id' : guestId});
      }
      // Kiosk orders are always guest orders. The DioClient attaches the stored
      // Authorization token to every request; on a device that carries a real
      // customer token (e.g. left over in web storage) the backend would attach
      // the order to that customer instead of the guest. Force an anonymous
      // request so the order lands on the guest_id — mirrors the web app's
      // not-logged-in `Bearer null` guest requests.
      final Options? options = asGuest
          ? Options(headers: {'Authorization': 'Bearer null'})
          : null;
      final response = await dioClient!
          .post(AppConstants.placeOrderUri, data: data, options: options);
      return ApiResponseModel.withSuccess(response);
    } catch (e) {
      return ApiResponseModel.withError(ApiErrorHandler.getMessage(e));
    }
  }

  Future<ApiResponseModel> getDeliveryManData({int? deliverymanId, int? orderId}) async {
    try {
      final response = await dioClient!.get('${AppConstants.lastLocationUri}$deliverymanId&order_id=$orderId');
      return ApiResponseModel.withSuccess(response);
    } catch (e) {
      return ApiResponseModel.withError(ApiErrorHandler.getMessage(e));
    }
  }

  Future<ApiResponseModel> getDistanceInMeter(LatLng originLatLng, LatLng destinationLatLng) async {
    try {
      Response response = await dioClient!.get('${AppConstants.distanceMatrixUri}'
          '?origin_lat=${originLatLng.latitude}&origin_lng=${originLatLng.longitude}'
          '&destination_lat=${destinationLatLng.latitude}&destination_lng=${destinationLatLng.longitude}');
      return ApiResponseModel.withSuccess(response);
    } catch (e) {
      return ApiResponseModel.withError(ApiErrorHandler.getMessage(e));
    }
  }

}