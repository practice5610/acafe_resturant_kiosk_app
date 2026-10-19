import 'package:acafe_customer/common/models/api_response_model.dart';
import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/exception/api_error_handler.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_place_order.dart';

/// The `lines` body of save-changes: each line's add-ons, its picks (in
/// checkout's own `cart.*.variations` shape) and its note.
///
/// Every line is sent whole. The server leaves a line whose picks did not
/// change un-repriced, and `instruction` is always present so a note cleared
/// in the editor is cleared on the order rather than left as it was.
List<Map<String, dynamic>> posReceiptSaveLines(List<CartModel> editLines) {
  return [
    for (final CartModel line in editLines)
      {
        'add_on_ids': [
          for (final AddOn addOn in line.addOnIds ?? const <AddOn>[])
            if (addOn.id != null) addOn.id!,
        ],
        'variations': [
          for (final variation in kioskOrderVariations(line)) variation.toJson(),
        ],
        'instruction': line.instruction,
      },
  ];
}

/// POST /api/v1/kiosk/manager/transactions/{id}/save-changes
///
/// Applies edited add-ons, option picks and notes to the order's detail rows,
/// recomputes the order total, closes the edit session, and writes an audit
/// log entry. Additive — does not alter payment integration or order_status.
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
      final response = await dioClient.post(
        '/api/v1/kiosk/manager/transactions/$orderId/save-changes',
        data: {'lines': posReceiptSaveLines(editLines)},
      );
      return ApiResponseModel.withSuccess(response);
    } catch (e) {
      return ApiResponseModel.withError(ApiErrorHandler.getMessage(e));
    }
  }
}
