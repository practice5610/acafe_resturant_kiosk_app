import 'package:acafe_customer/common/models/api_response_model.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/exception/api_error_handler.dart';
import 'package:acafe_customer/utill/app_constants.dart';

/// API access for the refund endpoints (Family 7).
///
/// Additive only — never touches any existing payment write path.
///
///  * [create]:  POST /customer/order/refund/create
///    Validates the refund request, computes the ceiling, inserts a pending row.
///    Idempotent on [reference].
///
///  * [confirm]: POST /customer/order/refund/confirm
///    Marks the pending row as succeeded, records the approval code (card),
///    updates orders.payment_status.
///
///  * [list]:    GET  /customer/order/refund/list?order_id=&device_id=
///    Returns all refund rows for an order.
class PosRefundRepo {
  final DioClient dioClient;

  const PosRefundRepo({required this.dioClient});

  Future<ApiResponseModel> create({
    required int orderId,
    required int deviceId,
    required String reference,
    String? reason,
    List<int>? itemsJson,
    int? partialPaymentId,
    int? splitGroupId,
  }) async {
    try {
      final Map<String, dynamic> body = {
        'order_id': orderId,
        'device_id': deviceId,
        'reference': reference,
        if (reason != null) 'reason': reason,
        if (itemsJson != null && itemsJson.isNotEmpty) 'items_json': itemsJson,
        if (partialPaymentId != null) 'partial_payment_id': partialPaymentId,
        if (splitGroupId != null) 'split_group_id': splitGroupId,
      };
      final response =
          await dioClient.post(AppConstants.refundCreateUri, data: body);
      return ApiResponseModel.withSuccess(response);
    } catch (e) {
      return ApiResponseModel.withError(ApiErrorHandler.getMessage(e));
    }
  }

  Future<ApiResponseModel> confirm({
    required int orderId,
    required int refundSeq,
    required String method,
    required String reference,
    required int deviceId,
    String? approvalCode,
  }) async {
    try {
      final Map<String, dynamic> body = {
        'order_id': orderId,
        'refund_seq': refundSeq,
        'method': method,
        'reference': reference,
        'device_id': deviceId,
        if (approvalCode != null && approvalCode.isNotEmpty)
          'approval_code': approvalCode,
      };
      final response =
          await dioClient.post(AppConstants.refundConfirmUri, data: body);
      return ApiResponseModel.withSuccess(response);
    } catch (e) {
      return ApiResponseModel.withError(ApiErrorHandler.getMessage(e));
    }
  }

  Future<ApiResponseModel> list({
    required int orderId,
    required int deviceId,
  }) async {
    try {
      final response = await dioClient.get(
        '${AppConstants.refundListUri}?order_id=$orderId&device_id=$deviceId',
      );
      return ApiResponseModel.withSuccess(response);
    } catch (e) {
      return ApiResponseModel.withError(ApiErrorHandler.getMessage(e));
    }
  }
}
