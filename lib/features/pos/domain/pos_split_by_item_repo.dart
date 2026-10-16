import 'package:acafe_customer/common/models/api_response_model.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/exception/api_error_handler.dart';
import 'package:acafe_customer/utill/app_constants.dart';

/// API access for the split-by-item endpoints.
///
/// Additive only — never touches the existing `order/place` write path.
///
///  * [createGroups]: POST /customer/order/split-by-item/create-groups
///    Creates all groups at once; returns the initial snapshot.
///
///  * [recordPayment]: POST /customer/order/split-by-item/record-payment
///    Records one group payment; returns the updated snapshot.
///    Idempotent: replaying the same `reference` returns the same result.
///
///  * [balance]: GET /customer/order/split-by-item/balance
///    Read-only snapshot; no write, no side effects.
class PosSplitByItemRepo {
  final DioClient dioClient;

  const PosSplitByItemRepo({required this.dioClient});

  Future<ApiResponseModel> createGroups({
    required int orderId,
    required int deviceId,
    required List<Map<String, dynamic>> groups,
  }) async {
    try {
      final Map<String, dynamic> body = {
        'order_id': orderId,
        'device_id': deviceId,
        'groups': groups,
      };
      final response =
          await dioClient.post(AppConstants.splitByItemCreateGroupsUri, data: body);
      return ApiResponseModel.withSuccess(response);
    } catch (e) {
      return ApiResponseModel.withError(ApiErrorHandler.getMessage(e));
    }
  }

  Future<ApiResponseModel> recordPayment({
    required int orderId,
    required int groupSeq,
    required String paidWith,
    required double paidAmount,
    required int deviceId,
    required String reference,
    String? transactionReference,
  }) async {
    try {
      final Map<String, dynamic> body = {
        'order_id': orderId,
        'group_seq': groupSeq,
        'paid_with': paidWith,
        'paid_amount': paidAmount,
        'device_id': deviceId,
        'reference': reference,
        if (transactionReference != null)
          'transaction_reference': transactionReference,
      };
      final response =
          await dioClient.post(AppConstants.splitByItemRecordPaymentUri, data: body);
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
