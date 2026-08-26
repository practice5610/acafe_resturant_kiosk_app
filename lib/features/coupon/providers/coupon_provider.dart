import 'package:flutter/material.dart';
import 'package:acafe_customer/common/models/api_response_model.dart';
import 'package:acafe_customer/features/coupon/domain/models/coupon_apply_result.dart';
import 'package:acafe_customer/features/coupon/domain/models/coupon_model.dart';
import 'package:acafe_customer/features/coupon/domain/reposotories/coupon_repo.dart';
import 'package:acafe_customer/helper/api_checker_helper.dart';
import 'package:acafe_customer/main.dart';
import 'package:acafe_customer/features/auth/providers/auth_provider.dart';
import 'package:provider/provider.dart';

class CouponProvider extends ChangeNotifier {
  final CouponRepo? couponRepo;
  CouponProvider({required this.couponRepo});

  List<CouponModel>? _availableCouponList;
  List<CouponModel>? _unavailableCouponList;
  List<CouponModel>? _searchedCouponList;
  CouponModel? _coupon;
  double? _discount = 0.0;
  String? _code = '';
  bool _isLoading = false;
  bool _isActiveSuffixIcon = false;
  bool _isSearchComplete = true;
  int? _selectedCouponIndex;

  CouponModel? get coupon => _coupon;
  double? get discount => _discount;
  String? get code => _code;
  bool get isLoading => _isLoading;
  bool get isActiveSuffixIcon => _isActiveSuffixIcon;
  bool get isSearchComplete => _isSearchComplete;
  int? get selectedCouponIndex => _selectedCouponIndex;
  List<CouponModel>? get availableCouponList => _availableCouponList;
  List<CouponModel>? get unavailableCouponList => _unavailableCouponList;
  List<CouponModel>? get searchedCouponList => _searchedCouponList;

  var searchController = TextEditingController();

  Future<void> getCouponList({double? orderAmount}) async {
    ApiResponseModel apiResponse = await couponRepo!.getCouponList(
      guestId: Provider.of<AuthProvider>(Get.context!, listen: false).getGuestId(),
      orderAmount: orderAmount
    );
    if (apiResponse.response != null && apiResponse.response!.statusCode == 200) {

      _availableCouponList = [];
      _unavailableCouponList = [];
      apiResponse.response!.data['available'].forEach((category) => _availableCouponList!.add(CouponModel.fromJson(category)));
      apiResponse.response!.data['unavailable'].forEach((category) => _unavailableCouponList!.add(CouponModel.fromJson(category)));

      notifyListeners();
    } else {
      ApiCheckerHelper.checkApi(apiResponse);
    }
  }

  Future<double?> applyCoupon(String coupon, double amountWithoutVat, {int? selectedIndex}) async {
    await applyCouponDetailed(coupon, amountWithoutVat, selectedIndex: selectedIndex);
    return _discount;
  }

  /// Validates [coupon] against the backend and reports *why* it ended the way
  /// it did — see [CouponApplyResult].
  ///
  /// A valid code below its `min_purchase` used to stay attached with a zero
  /// discount; it is dropped instead, because a coupon that takes nothing off
  /// should not travel with the order.
  Future<CouponApplyResult> applyCouponDetailed(String coupon, double amountWithoutVat, {int? selectedIndex}) async {
    if(selectedIndex !=null){
      _selectedCouponIndex = selectedIndex;
    }else{
      _isLoading = true;
    }
    notifyListeners();
    ApiResponseModel apiResponse = await couponRepo!.applyCoupon(coupon, guestId: Provider.of<AuthProvider>(Get.context!, listen: false).getGuestId(),);

    late final CouponApplyResult result;
    if (apiResponse.response != null && apiResponse.response!.statusCode == 200) {
      _coupon = CouponModel.fromJson(apiResponse.response!.data);
      _code = _coupon!.code;
      final double minPurchase = _coupon!.minPurchase ?? 0;
      if (minPurchase <= amountWithoutVat) {
        _discount = _discountOf(_coupon!, amountWithoutVat);
        result = CouponApplyResult.applied(coupon: _coupon, discount: _discount ?? 0);
      } else {
        result = CouponApplyResult.belowMinPurchase(coupon: _coupon, minPurchase: minPurchase);
        _coupon = null;
        _code = '';
        _discount = 0.0;
      }
    } else {
      _coupon = null;
      _code = '';
      _discount = 0.0;
      result = CouponApplyResult.failed(message: couponErrorMessage(apiResponse));
    }
    if(selectedIndex != null){
      _selectedCouponIndex = null;
    }else{
      _isLoading = false;
    }
    notifyListeners();
    return result;
  }

  /// Money off for a coupon that has already passed its min-purchase check.
  /// Percentage coupons are capped by `max_discount` when one is set.
  static double _discountOf(CouponModel coupon, double amountWithoutVat) {
    if (coupon.discountType == 'percent') {
      final double raw = (coupon.discount ?? 0) * amountWithoutVat / 100;
      final double? cap = coupon.maxDiscount;
      if (cap != null && cap != 0) {
        return raw < cap ? raw : cap;
      }
      return raw;
    }
    return coupon.discount ?? 0;
  }

  /// Pulls the backend's rejection message out of a failed response.
  ///
  /// `ApiErrorHandler` hands back `ErrorResponseModel.toJson()` for a 4xx, so
  /// the message sits at `error['errors'][0]['message']`; a transport failure
  /// arrives as a plain string instead.
  @visibleForTesting
  static String? couponErrorMessage(ApiResponseModel apiResponse) {
    final dynamic error = apiResponse.error;
    if (error is Map) {
      final dynamic errors = error['errors'];
      if (errors is List && errors.isNotEmpty && errors.first is Map) {
        final String message = '${(errors.first as Map)['message'] ?? ''}'.trim();
        if (message.isNotEmpty) return message;
      }
    }
    if (error is String && error.trim().isNotEmpty) return error.trim();
    return null;
  }

  void removeCouponData(bool notify) {
    _coupon = null;
    _isLoading = false;
    _discount = 0.0;
    _code = '';
    if(notify) {
      notifyListeners();
    }
  }

  void searchCoupon({required String query}) {
    _searchedCouponList = [];
    _searchedCouponList = _availableCouponList?.where((item) {
      final titleLower = item.title?.toLowerCase() ?? "";
      final subtitleLower = item.code?.toLowerCase() ?? "";
      final searchLower = query.toLowerCase();
      return titleLower.contains(searchLower) || subtitleLower.contains(searchLower);
    }).toList();
  }

  void showSuffixIcon(context,String text){
    if(text.isNotEmpty){
      _isActiveSuffixIcon = true;
    }else if(text.isEmpty){
      _isActiveSuffixIcon = false;
    }
    notifyListeners();
  }

  void clearSearchController({bool shouldUpdate = true} ){
    searchController.clear();
    _isSearchComplete = true;
    _isActiveSuffixIcon = false;

    if(shouldUpdate){
      notifyListeners();
    }
  }
}