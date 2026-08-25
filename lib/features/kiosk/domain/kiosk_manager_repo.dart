import 'package:dio/dio.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/exception/api_error_handler.dart';
import 'package:acafe_customer/common/models/api_response_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-authenticated "POS Manager" calls: PIN check, live sales overview,
/// Z Report close, transaction history, and the stock-toggle screen. All
/// endpoints are branch-scoped server-side from the device's own token -- no
/// branch/device id is ever sent from the client.
class KioskManagerRepo {
  final DioClient dioClient;
  final SharedPreferences sharedPreferences;

  KioskManagerRepo({required this.dioClient, required this.sharedPreferences});

  /// Checks the entered 4-digit PIN against the device's configuration_code.
  ///
  /// Deliberately bypasses the normal try/catch-throws-on-4xx pattern: a
  /// wrong PIN response (422) must never be treated like a generic API
  /// error, since ApiCheckerHelper.checkApi() force-logs-out the device on a
  /// 401 and would otherwise show a raw/ugly error for a simple mistyped
  /// PIN. `validateStatus` lets 4xx responses come back as normal Response
  /// objects (never thrown), so the caller can read `response.statusCode`
  /// and `response.data['message']` directly.
  Future<ApiResponseModel> verifyCode(String code) async {
    try {
      final response = await dioClient.post(
        '/api/v1/kiosk/manager/verify-code',
        data: {'code': code},
        options:
            Options(validateStatus: (status) => status != null && status < 500),
      );
      return ApiResponseModel.withSuccess(response);
    } catch (e) {
      return ApiResponseModel.withError(ApiErrorHandler.getMessage(e));
    }
  }

  Future<ApiResponseModel> getSalesOverview({String? reportDate}) async {
    try {
      final response = await dioClient.get(
        '/api/v1/kiosk/manager/sales-overview',
        queryParameters:
            reportDate != null ? {'report_date': reportDate} : null,
      );
      return ApiResponseModel.withSuccess(response);
    } catch (e) {
      return ApiResponseModel.withError(ApiErrorHandler.getMessage(e));
    }
  }

  Future<ApiResponseModel> closeZReport({
    required String reportDate,
    required double openingCash,
    required double closingCashCounted,
    String? comment,
  }) async {
    try {
      final response = await dioClient.post(
        '/api/v1/kiosk/manager/z-report/close',
        data: {
          'report_date': reportDate,
          'opening_cash': openingCash,
          'closing_cash_counted': closingCashCounted,
          'closing_comment': comment,
        },
      );
      return ApiResponseModel.withSuccess(response);
    } catch (e) {
      return ApiResponseModel.withError(ApiErrorHandler.getMessage(e));
    }
  }

  Future<ApiResponseModel> getTransactions({
    String? reportDate,
    int limit = 25,
    int offset = 1,
  }) async {
    try {
      final response = await dioClient.get(
        '/api/v1/kiosk/manager/transactions',
        queryParameters: {
          if (reportDate != null) 'report_date': reportDate,
          'limit': limit,
          'offset': offset,
        },
      );
      return ApiResponseModel.withSuccess(response);
    } catch (e) {
      return ApiResponseModel.withError(ApiErrorHandler.getMessage(e));
    }
  }

  Future<ApiResponseModel> getProducts({
    String? search,
    int limit = 25,
    int offset = 1,
  }) async {
    try {
      final response = await dioClient.get(
        '/api/v1/kiosk/manager/products',
        queryParameters: {
          if (search != null && search.isNotEmpty) 'search': search,
          'limit': limit,
          'offset': offset,
        },
      );
      return ApiResponseModel.withSuccess(response);
    } catch (e) {
      return ApiResponseModel.withError(ApiErrorHandler.getMessage(e));
    }
  }

  Future<ApiResponseModel> setProductStatus(
      {required int id, required bool status}) async {
    try {
      final response = await dioClient.post(
        '/api/v1/kiosk/manager/products/status',
        data: {'id': id, 'status': status ? 1 : 0},
      );
      return ApiResponseModel.withSuccess(response);
    } catch (e) {
      return ApiResponseModel.withError(ApiErrorHandler.getMessage(e));
    }
  }
}
