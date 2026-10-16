import 'package:acafe_customer/common/models/api_response_model.dart';
import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/exception/api_error_handler.dart';

/// POST /api/v1/kiosk/manager/transactions/{id}/save-changes
///
/// Applies edited add-on selections to the order's detail rows, recomputes the
/// order total, closes the edit session, and writes an audit log entry.
/// Additive — does not alter payment integration or order_status.
class PosReceiptSaveChangesRepo {
  final DioClient dioClient;

  const PosReceiptSaveChangesRepo({required this.dioClient});

  /// [editLines] must be in the same positional order as the original receipt
  /// lines (index 0 = first order_detail by id ASC), matching how the detail
  /// endpoint returns them.
  Future<ApiResponseModel> saveChanges({
    required int orderId,
    required List<CartModel> editLines,
  }) async {
    try {
      final lines = editLines.map((line) {
        final ids = (line.addOnIds ?? const <AddOn>[])
            .where((a) => a.id != null)
            .map((a) => a.id!)
            .toList();
        return {'add_on_ids': ids};
      }).toList();

      final response = await dioClient.post(
        '/api/v1/kiosk/manager/transactions/$orderId/save-changes',
        data: {'lines': lines},
      );
      return ApiResponseModel.withSuccess(response);
    } catch (e) {
      return ApiResponseModel.withError(ApiErrorHandler.getMessage(e));
    }
  }
}
