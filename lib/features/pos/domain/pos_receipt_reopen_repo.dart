import 'package:acafe_customer/common/models/api_response_model.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/exception/api_error_handler.dart';

/// POST /api/v1/kiosk/manager/transactions/{id}/reopen
///
/// Marks a fulfilled receipt as reopened. Additive — does not alter payment
/// integration or existing order-writing paths.
class PosReceiptReopenRepo {
  final DioClient dioClient;

  const PosReceiptReopenRepo({required this.dioClient});

  Future<ApiResponseModel> reopen({
    required int orderId,
    String? reason,
  }) async {
    try {
      final response = await dioClient.post(
        '/api/v1/kiosk/manager/transactions/$orderId/reopen',
        data: {
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
