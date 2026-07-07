import 'package:flutter/material.dart';
import 'package:acafe_customer/common/models/api_response_model.dart';
import 'package:acafe_customer/common/models/order_details_model.dart';
import 'package:acafe_customer/common/models/place_order_body.dart';
import 'package:acafe_customer/common/models/response_model.dart';
import 'package:acafe_customer/features/auth/providers/auth_provider.dart';
import 'package:acafe_customer/features/order/domain/models/order_model.dart';
import 'package:acafe_customer/features/order/domain/reposotories/order_repo.dart';
import 'package:acafe_customer/helper/api_checker_helper.dart';
import 'package:acafe_customer/main.dart';
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OrderProvider extends ChangeNotifier {
  final OrderRepo? orderRepo;
  final SharedPreferences? sharedPreferences;
  OrderProvider({ required this.sharedPreferences,required this.orderRepo});


  OrderModel? _ongoingOrder;
  OrderModel? _historyOrder;


  List<OrderDetailsModel>? _orderDetails;
  Order? _trackModel;
  ResponseModel? _responseModel;
  bool _isLoading = false;
  bool _showCancelled = false;
  bool _isRestaurantCloseShow = true;


  OrderModel? get ongoingOrder => _ongoingOrder;
  OrderModel? get historyOrder => _historyOrder;


  List<OrderDetailsModel>? get orderDetails => _orderDetails;
  Order? get trackModel => _trackModel;
  ResponseModel? get responseModel => _responseModel;
  bool get isLoading => _isLoading;
  bool get showCancelled => _showCancelled;
  bool get isRestaurantCloseShow => _isRestaurantCloseShow;


  void changeStatus(bool status, {bool notify = false}) {
    _isRestaurantCloseShow = status;
    if(notify) {
      notifyListeners();
    }
  }

  Future<void> getOrderList(BuildContext context, {String? orderFilter, int? offset = 1, bool reload = true}) async {

    if(_ongoingOrder == null || offset != 1 || reload) {
      ApiResponseModel apiResponse = await orderRepo!.getOrderList(orderFilter: orderFilter, offset: offset);
      if (apiResponse.response != null && apiResponse.response!.statusCode == 200) {
        try {
          if(orderFilter == "ongoing"){
            if(offset == 1){
              _ongoingOrder = null;
              _ongoingOrder = OrderModel.fromJson(apiResponse.response?.data);
            } else {
              final page = OrderModel.fromJson(apiResponse.response?.data);
              _ongoingOrder?.totalSize = page.totalSize;
              _ongoingOrder?.offset = page.offset;
              _ongoingOrder?.limit = page.limit;
              _ongoingOrder?.orderList?.addAll(page.orderList ?? []);
            }

          }else{
            if(offset == 1){
              _historyOrder = null;
              _historyOrder = OrderModel.fromJson(apiResponse.response?.data);
            } else {
              final page = OrderModel.fromJson(apiResponse.response?.data);
              _historyOrder?.totalSize = page.totalSize;
              _historyOrder?.offset = page.offset;
              _historyOrder?.limit = page.limit;
              _historyOrder?.orderList?.addAll(page.orderList ?? []);
            }
          }
        } catch (error, stack) {
          debugPrint('OrderProvider.getOrderList parse error: $error\n$stack');
          final empty = OrderModel(totalSize: 0, limit: apiResponse.response?.data['limit'] ?? 10, offset: offset, orderList: []);
          if (orderFilter == 'ongoing') {
            _ongoingOrder = empty;
          } else {
            _historyOrder = empty;
          }
        }
      } else {
        ApiCheckerHelper.checkApi(apiResponse);
      }
      notifyListeners();
    }

  }




  Future<List<OrderDetailsModel>?> getOrderDetails(String orderID, {String? phoneNumber, bool isApiCheck = true,  bool isUpdate = false}) async {
    _orderDetails = null;
    _isLoading = true;
    _showCancelled = false;

    if(isUpdate) {
      notifyListeners();
    }

    ApiResponseModel apiResponse;
    if(phoneNumber != null){
      apiResponse = await orderRepo!.orderDetailsWithPhoneNumber(orderID, phoneNumber);
    }else{
      apiResponse = await orderRepo!.getOrderDetails(orderID);
    }

    if (apiResponse.response != null && apiResponse.response!.statusCode == 200) {
      _orderDetails = [];
      apiResponse.response!.data.forEach((orderDetail) => _orderDetails!.add(OrderDetailsModel.fromJson(orderDetail)));
    } else {
      _orderDetails = [];

      if(isApiCheck) {
        ApiCheckerHelper.checkApi(apiResponse);
      }
    }
    _isLoading = false;
    notifyListeners();
    return _orderDetails;
  }




  Future<ResponseModel?> trackOrder(String? orderID, {String? phoneNumber, bool isUpdate = false, Order? orderModel, bool fromTracking = true}) async {
    _trackModel = null;
    _responseModel = null;
    if(!fromTracking) {
      _orderDetails = null;
    }
    _showCancelled = false;
    try {
      if(orderModel == null) {
        _isLoading = true;
        if(isUpdate){
          notifyListeners();
        }
        ApiResponseModel apiResponse;
        if(phoneNumber != null){
          apiResponse = await orderRepo!.trackOrderWithPhoneNumber(orderID,phoneNumber);
        }else{
          apiResponse = await orderRepo!.trackOrder(
            orderID, guestId: Provider.of<AuthProvider>(Get.context!, listen: false).getGuestId(),
          );
        }

        if (apiResponse.response != null && apiResponse.response!.statusCode == 200) {
          _trackModel = Order.fromJson(apiResponse.response!.data);
          _responseModel = ResponseModel(true, apiResponse.response!.data.toString());
        } else {
          _trackModel = Order(id: -1);
          final errors = ApiCheckerHelper.getError(apiResponse).errors;
          final errorMessage = (errors != null && errors.isNotEmpty) ? (errors[0].message ?? 'Failed to load order') : 'Failed to load order';
          _responseModel = ResponseModel(false, errorMessage);
          ApiCheckerHelper.checkApi(apiResponse);
        }
      }else {
        _trackModel = orderModel;
        _responseModel = ResponseModel(true, 'Successful');
      }
    } catch(_) {
      _trackModel = Order(id: -1);
      _responseModel = ResponseModel(false, 'Failed to load order');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return _responseModel;
  }

  Future<void> placeOrder(PlaceOrderBody placeOrderBody, Function callback, {bool isUpdate = true, bool asGuest = false}) async {
    _isLoading = true;
    if(isUpdate){
      notifyListeners();
    }
    ApiResponseModel apiResponse = await orderRepo!.placeOrder(
      placeOrderBody, guestId: Provider.of<AuthProvider>(Get.context!, listen: false).getGuestId(),
      asGuest: asGuest,
    );
    _isLoading = false;
    if (apiResponse.response != null && apiResponse.response!.statusCode == 200) {
      String? message = apiResponse.response!.data['message'];
      String orderID = apiResponse.response!.data['order_id'].toString();
      callback(true, message, orderID);

      _setLastOrderPaymentMethod(placeOrderBody.paymentMethod);

    } else {
      callback(false, ApiCheckerHelper.getError(apiResponse).errors![0].message, '-1');
    }

    notifyListeners();
  }

  void stopLoader() {
    _isLoading = false;
    notifyListeners();
  }


  void clearPrevData({bool isUpdate = false}) {
    _trackModel = null;
    if(isUpdate){
      notifyListeners();
    }
  }

  void cancelOrder(String orderID, Function callback) async {
    _isLoading = true;
    notifyListeners();
    ApiResponseModel apiResponse = await orderRepo!.cancelOrder(orderID, Provider.of<AuthProvider>(Get.context!, listen: false).getGuestId());
    _isLoading = false;

    if (apiResponse.response != null && apiResponse.response!.statusCode == 200) {
      Order? orderModel;
      for (var order in _ongoingOrder?.orderList ?? []) {
        if(order.id.toString() == orderID) {
          orderModel = order;
        }
      }
      _ongoingOrder?.orderList?.remove(orderModel);
      _showCancelled = true;
      callback(apiResponse.response!.data['message'], true, orderID);
    } else {
      callback(ApiCheckerHelper.getError(apiResponse).errors?.first.message, false, '-1');
    }
    notifyListeners();
  }


  Future<void> setPlaceOrder(String placeOrder)async{
    await sharedPreferences!.setString(AppConstants.placeOrderData, placeOrder);
  }
  String? getPlaceOrder(){
    return sharedPreferences!.getString(AppConstants.placeOrderData);
  }
  Future<void> clearPlaceOrder()async{
    await sharedPreferences!.remove(AppConstants.placeOrderData);
  }

  double getDistanceBetween(LatLng startLatLng, LatLng endLatLng){
    return Geolocator.distanceBetween(
      startLatLng.latitude, startLatLng.longitude, endLatLng.latitude, endLatLng.longitude,
    );
  }

  Future<void> _setLastOrderPaymentMethod(String? placeOrder)async{
    await sharedPreferences?.setString(AppConstants.lastOrderPaymentMethod, placeOrder ?? '');
  }
  String? getLastOrderPaymentMethod(){
    return sharedPreferences!.getString(AppConstants.lastOrderPaymentMethod);
  }

}