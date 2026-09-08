import 'package:acafe_customer/common/models/api_response_model.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/exception/api_error_handler.dart';
import 'package:dio/dio.dart';

/// Device-authenticated Orders board calls.
///
/// Branch-scoped server-side from the device's own token — no branch or device
/// id is ever sent from the client, same principle as [KioskManagerRepo].
///
/// Deliberately separate from the transactions feed: Receipts depends on that
/// endpoint's shape, its today-only default and its exclusion of delivery
/// orders, none of which suit a live board.
class PosOrdersRepo {
  final DioClient dioClient;

  PosOrdersRepo({required this.dioClient});

  Future<ApiResponseModel> getOrders({
    String? dateFrom,
    String? dateTo,
    String? search,
    String? section,
    String? status,
    String? source,
    String? type,
    String? method,
    int limit = 200,
  }) async {
    try {
      final Map<String, dynamic> query = <String, dynamic>{'limit': limit};
      void put(String key, String? value) {
        if (value != null && value.isNotEmpty) query[key] = value;
      }

      put('date_from', dateFrom);
      put('date_to', dateTo);
      put('search', search);
      put('section', section);
      put('status', status);
      put('source', source);
      put('type', type);
      put('method', method);

      final response = await dioClient.get(
        '/api/v1/kiosk/manager/orders',
        queryParameters: query,
      );
      return ApiResponseModel.withSuccess(response);
    } catch (e) {
      return ApiResponseModel.withError(ApiErrorHandler.getMessage(e));
    }
  }

  /// Advance one order.
  ///
  /// `validateStatus` lets 4xx come back as a normal response rather than a
  /// throw, for the same reason [KioskManagerRepo.verifyCode] does it: the
  /// global API checker force-logs-out a device on a 401, and a rejected
  /// transition (422 "cannot be moved backwards", 404 wrong branch) is an
  /// ordinary outcome the board has to show as a message, not a logout.
  Future<ApiResponseModel> updateStatus({
    required int orderId,
    required String orderStatus,
  }) async {
    try {
      final response = await dioClient.post(
        '/api/v1/kiosk/manager/orders/$orderId/status',
        data: {'order_status': orderStatus},
        options:
            Options(validateStatus: (status) => status != null && status < 500),
      );
      return ApiResponseModel.withSuccess(response);
    } catch (e) {
      return ApiResponseModel.withError(ApiErrorHandler.getMessage(e));
    }
  }
}
