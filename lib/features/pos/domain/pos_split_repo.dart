import 'package:acafe_customer/common/models/api_response_model.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/exception/api_error_handler.dart';
import 'package:acafe_customer/utill/app_constants.dart';

/// API access for the split-by-payment endpoints.
///
/// Additive only — never touches the existing `order/place` write path.
///
///  * [record]: POST /customer/order/split-payment/record
///    Records one split; returns the updated snapshot (paid / remaining).
///    Idempotent: replaying the same `reference` returns the same result.
///
///  * [balance]: GET /customer/order/split-payment/balance
///    Read-only snapshot; no write, no side effects.
class PosSplitRepo {
  final DioClient dioClient;

  const PosSplitRepo({required this.dioClient});

  Future<ApiResponseModel> record({
    required int orderId,
    required String paidWith,
    required double paidAmount,
    required int deviceId,
    required String reference,
    String? transactionReference,
  }) async {
    try {
      final Map<String, dynamic> body = {
        'order_id': orderId,
        'paid_with': paidWith,
        'paid_amount': paidAmount,
        'device_id': deviceId,
        'reference': reference,
        if (transactionReference != null)
          'transaction_reference': transactionReference,
      };
      final response =
          await dioClient.post(AppConstants.splitRecordUri, data: body);
      return ApiResponseModel.withSuccess(response);
    } catch (e) {
      return ApiResponseModel.withError(ApiErrorHandler.getMessage(e));
    }
  }

  Future<ApiResponseModel> balance({
    required int orderId,
    required int deviceId,
  }) async {
    try {
      final response = await dioClient.get(
        '${AppConstants.splitBalanceUri}?order_id=$orderId&device_id=$deviceId',
      );
      return ApiResponseModel.withSuccess(response);
    } catch (e) {
      return ApiResponseModel.withError(ApiErrorHandler.getMessage(e));
    }
  }
}
