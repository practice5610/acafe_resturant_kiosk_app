import 'package:flutter/material.dart';
import 'package:acafe_customer/common/models/api_response_model.dart';
import 'package:acafe_customer/features/auth/domain/reposotories/auth_repo.dart';

/// Slim kiosk auth provider — the kiosk only needs a guest account so the
/// backend can attach the required `guest_id` when placing/cancelling orders
/// and applying coupons. All customer-account/login flows live in the user
/// web app, not the kiosk.
class AuthProvider extends ChangeNotifier {
  final AuthRepo? authRepo;

  AuthProvider({required this.authRepo});

  bool isLoggedIn() => authRepo?.isLoggedIn() ?? false;

  /// The kiosk always places orders as a guest. The device *is* "logged in"
  /// (its device token lives under [AppConstants.token]), but that is not a
  /// customer account — so, unlike the web app, we must NOT null out the guest
  /// id when logged in, or the backend rejects the order ("guest id required").
  String? getGuestId() => authRepo?.getGuestId();

  Future<bool> addGuest() async {
    final String? fcmToken = await authRepo?.getDeviceToken();
    final ApiResponseModel apiResponse = await authRepo!.addGuest(fcmToken);

    final bool isSuccess = apiResponse.response != null &&
        apiResponse.response!.statusCode == 200 &&
        apiResponse.response?.data['guest']['id'] != null;

    if (isSuccess) {
      await authRepo?.saveGuestId('${apiResponse.response?.data['guest']['id']}');
      notifyListeners();
    }

    return isSuccess;
  }
}
