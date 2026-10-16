import 'package:acafe_customer/common/models/api_response_model.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/exception/api_error_handler.dart';
import 'package:acafe_customer/utill/app_constants.dart';

/// API access for receipt send/print (Family 6).
class PosReceiptSendRepo {
  final DioClient dioClient;

  const PosReceiptSendRepo({required this.dioClient});

  /// POST /customer/order/receipt/send
  ///
  /// [method] is 'email' or 'print'. [email] is required when method='email'.
  /// Idempotent on [reference].
  Future<ApiResponseModel> send({
    required int orderId,
    required String method,
    String? email,
    required int deviceId,
    required String reference,
  }) async {
    try {
      final Map<String, dynamic> body = {
        'order_id':  orderId,
        'method':    method,
        if (email != null && email.isNotEmpty) 'email': email,
        'device_id': deviceId,
        'reference': reference,
      };
      final response =
          await dioClient.post(AppConstants.receiptSendUri, data: body);
      return ApiResponseModel.withSuccess(response);
    } catch (e) {
      return ApiResponseModel.withError(ApiErrorHandler.getMessage(e));
    }
  }
}
