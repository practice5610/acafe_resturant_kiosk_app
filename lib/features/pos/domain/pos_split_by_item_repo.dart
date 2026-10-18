import 'package:acafe_customer/common/models/api_response_model.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/exception/api_error_handler.dart';
import 'package:acafe_customer/utill/app_constants.dart';

/// API access for the split-by-item endpoints.
///
/// Additive only — never touches the existing `order/place` write path.
///
///  * [payItems]: POST /customer/order/split-by-item/pay-items
///    One guest's payment for the items they had, recorded as a paid group.
///    Called once per guest, after their money is taken. Returns the updated
///    snapshot. Idempotent: replaying the same `reference` returns the same
///    result and records nothing twice.
///
///  * [balance]: GET /customer/order/split-by-item/balance
///    Read-only snapshot; no write, no side effects.
class PosSplitByItemRepo {
  final DioClient dioClient;

  const PosSplitByItemRepo({required this.dioClient});

  Future<ApiResponseModel> payItems({
    required int orderId,
    required int deviceId,
    required List<int> itemIds,
    required double amount,
    required String paidWith,
    required String reference,
    String? transactionReference,
  }) async {
    try {
      final Map<String, dynamic> body = {
        'order_id': orderId,
        'device_id': deviceId,
        'item_ids': itemIds,
        'amount': amount,
        'paid_with': paidWith,
        'reference': reference,
        if (transactionReference != null)
          'transaction_reference': transactionReference,
      };
      final response =
          await dioClient.post(AppConstants.splitByItemPayItemsUri, data: body);
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
        '${AppConstants.splitByItemBalanceUri}?order_id=$orderId&device_id=$deviceId',
      );
      return ApiResponseModel.withSuccess(response);
    } catch (e) {
      return ApiResponseModel.withError(ApiErrorHandler.getMessage(e));
    }
  }
}
