import 'package:acafe_customer/common/models/api_response_model.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/exception/api_error_handler.dart';
import 'package:acafe_customer/utill/app_constants.dart';

/// API access for the invoice (Family 4) endpoints.
///
/// Additive only — never touches the existing `order/place` write path.
class PosInvoiceRepo {
  final DioClient dioClient;

  const PosInvoiceRepo({required this.dioClient});

  /// POST /customer/order/invoice/create
  ///
  /// Creates an invoice and marks the order paid. Idempotent on [reference].
  Future<ApiResponseModel> create(Map<String, dynamic> payload) async {
    try {
      final response =
          await dioClient.post(AppConstants.invoiceCreateUri, data: payload);
      return ApiResponseModel.withSuccess(response);
    } catch (e) {
      return ApiResponseModel.withError(ApiErrorHandler.getMessage(e));
    }
  }

  /// GET /customer/order/invoice/details?order_id=&device_id=
  Future<ApiResponseModel> details({
    required int orderId,
    required int deviceId,
  }) async {
    try {
      final response = await dioClient.get(
        '${AppConstants.invoiceDetailsUri}?order_id=$orderId&device_id=$deviceId',
      );
      return ApiResponseModel.withSuccess(response);
    } catch (e) {
      return ApiResponseModel.withError(ApiErrorHandler.getMessage(e));
    }
  }
}
