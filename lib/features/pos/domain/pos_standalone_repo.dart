import 'package:acafe_customer/common/models/api_response_model.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/exception/api_error_handler.dart';
import 'package:acafe_customer/utill/app_constants.dart';

/// API access for the stand-alone terminal payment (Family 5).
///
/// Additive only — never touches the existing `order/place` write path.
class PosStandaloneRepo {
  final DioClient dioClient;

  const PosStandaloneRepo({required this.dioClient});

  /// POST /customer/order/standalone-payment/record
  ///
  /// Records payment taken on a separate terminal and marks the order paid.
  /// Idempotent on [reference]. [approvalCode] is optional.
  Future<ApiResponseModel> record({
    required int orderId,
    required int deviceId,
    required String reference,
    String? approvalCode,
  }) async {
    try {
      final Map<String, dynamic> body = {
        'order_id': orderId,
        'device_id': deviceId,
        'reference': reference,
        if (approvalCode != null && approvalCode.isNotEmpty)
          'approval_code': approvalCode,
      };
      final response =
          await dioClient.post(AppConstants.standaloneRecordUri, data: body);
      return ApiResponseModel.withSuccess(response);
    } catch (e) {
      return ApiResponseModel.withError(ApiErrorHandler.getMessage(e));
    }
  }
}
