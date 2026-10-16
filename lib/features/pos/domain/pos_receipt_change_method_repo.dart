import 'package:acafe_customer/common/models/api_response_model.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/exception/api_error_handler.dart';

/// PATCH /api/v1/kiosk/manager/transactions/{id}/payment-method
///
/// Stores a display_method_override on the order.  Additive endpoint —
/// no existing payment or order contract is altered.
class PosReceiptChangeMethodRepo {
  final DioClient dioClient;

  const PosReceiptChangeMethodRepo({required this.dioClient});

  Future<ApiResponseModel> update({
    required int orderId,
    required String method,
    String? reason,
  }) async {
    try {
      final response = await dioClient.patch(
        '/api/v1/kiosk/manager/transactions/$orderId/payment-method',
        data: {
          'method': method,
          if (reason != null && reason.trim().isNotEmpty)
            'reason': reason.trim(),
        },
      );
      return ApiResponseModel.withSuccess(response);
    } catch (e) {
      return ApiResponseModel.withError(ApiErrorHandler.getMessage(e));
    }
  }
}
