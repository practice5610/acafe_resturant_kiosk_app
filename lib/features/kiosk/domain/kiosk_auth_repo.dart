import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/exception/api_error_handler.dart';
import 'package:acafe_customer/common/models/api_response_model.dart';
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Data layer for kiosk device authentication.
///
/// The device token is stored under [AppConstants.token] so the existing
/// [DioClient] interceptor attaches `Authorization: Bearer <token>` to every
/// request automatically. The bound branch id is stored under
/// [AppConstants.branch] so the existing branch-scoped catalog pipeline shows
/// the device's branch. The branch itself is always validated/derived
/// server-side from the token — the client never asks for another branch.
class KioskAuthRepo {
  final DioClient dioClient;
  final SharedPreferences sharedPreferences;

  KioskAuthRepo({required this.dioClient, required this.sharedPreferences});

  Future<ApiResponseModel> login(String username, String password) async {
    try {
      final response = await dioClient.post(
        AppConstants.kioskDeviceLoginUri,
        data: {'username': username, 'password': password},
      );
      return ApiResponseModel.withSuccess(response);
    } catch (e) {
      return ApiResponseModel.withError(ApiErrorHandler.getMessage(e));
    }
  }

  /// Validate the stored token on boot. Returns the branch+device payload, or
  /// an error (401/403) if the token was revoked / device set inactive.
  Future<ApiResponseModel> getMe() async {
    try {
      final response = await dioClient.get(AppConstants.kioskDeviceMeUri);
      return ApiResponseModel.withSuccess(response);
    } catch (e) {
      return ApiResponseModel.withError(ApiErrorHandler.getMessage(e));
    }
  }

  /// Persist the device session: token (for auth header) + bound branch.
  Future<void> saveSession({
    required String token,
    required int branchId,
    String? branchName,
    String? deviceName,
    String? username,
    int? deviceId,
    String? category,
  }) async {
    await sharedPreferences.setString(AppConstants.token, token);
    await sharedPreferences.setInt(AppConstants.branch, branchId);
    if (branchName != null) {
      await sharedPreferences.setString(AppConstants.kioskBranchName, branchName);
    }
    if (deviceName != null) {
      await sharedPreferences.setString(AppConstants.kioskDeviceName, deviceName);
    }
    if (username != null) {
      await sharedPreferences.setString(AppConstants.kioskUsername, username);
    }
    if (deviceId != null) {
      await sharedPreferences.setInt(AppConstants.kioskDeviceId, deviceId);
    }
    if (category != null) {
      await sharedPreferences.setString(AppConstants.kioskDeviceCategory, category);
    }
    // Refresh dio headers so the new token + branch take effect immediately.
    await dioClient.updateHeader(getToken: token);
  }

  bool isLoggedIn() => sharedPreferences.containsKey(AppConstants.token);

  String getToken() => sharedPreferences.getString(AppConstants.token) ?? '';

  String getBranchName() =>
      sharedPreferences.getString(AppConstants.kioskBranchName) ?? '';

  String getDeviceName() =>
      sharedPreferences.getString(AppConstants.kioskDeviceName) ?? '';

  int? getBranchId() => sharedPreferences.containsKey(AppConstants.branch)
      ? sharedPreferences.getInt(AppConstants.branch)
      : null;

  int? getDeviceId() => sharedPreferences.containsKey(AppConstants.kioskDeviceId)
      ? sharedPreferences.getInt(AppConstants.kioskDeviceId)
      : null;

  /// 'kiosk' or 'pos'. Defaults to 'kiosk' (the safe/pre-existing behavior)
  /// if a session was persisted before this field existed.
  String getDeviceCategory() =>
      sharedPreferences.getString(AppConstants.kioskDeviceCategory) ?? 'kiosk';

  /// Wipe the device session (revoked/inactive/logout).
  Future<void> clearSession() async {
    await sharedPreferences.remove(AppConstants.token);
    await sharedPreferences.remove(AppConstants.kioskBranchName);
    await sharedPreferences.remove(AppConstants.kioskDeviceName);
    await sharedPreferences.remove(AppConstants.kioskUsername);
    await sharedPreferences.remove(AppConstants.kioskDeviceId);
    await sharedPreferences.remove(AppConstants.kioskDeviceCategory);
    await sharedPreferences.remove(AppConstants.cartList);
    await dioClient.updateHeader(getToken: null);
  }
}
