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

  /// Advance one line item's prep status.
  ///
  /// `validateStatus` for the same reason [updateStatus] uses it: a 409 here is
  /// an ordinary outcome the overlay has to show (the item moved under us, or
  /// the order was put on hold), and letting it reach the global API checker
  /// would force-log-out the device over a race.
  Future<ApiResponseModel> updateItemStatus({
    required int orderId,
    required int orderDetailId,
    required String status,
  }) {
    return _putItemStatus(
      '/api/v1/kiosk/manager/orders/$orderId/items/$orderDetailId/status',
      status,
    );
  }

  /// Move every eligible item on the order forward. Forward-only server-side,
  /// so this can never undo an item the kitchen has already finished.
  Future<ApiResponseModel> bulkUpdateItemStatus({
    required int orderId,
    required String status,
  }) {
    return _putItemStatus(
      '/api/v1/kiosk/manager/orders/$orderId/items/status',
      status,
    );
  }

  Future<ApiResponseModel> _putItemStatus(String path, String status) async {
    try {
      final response = await dioClient.put(
        path,
        data: {'status': status},
        options:
            Options(validateStatus: (status) => status != null && status < 500),
      );
      return ApiResponseModel.withSuccess(response);
    } catch (e) {
      return ApiResponseModel.withError(ApiErrorHandler.getMessage(e));
    }
  }
}
