import 'package:dio/dio.dart';
import 'package:universal_html/html.dart' as html;

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
  /// a 401/403 response if the token was revoked / device set inactive.
  ///
  /// `validateStatus` lets 4xx come back as ordinary responses instead of
  /// throwing, and a genuine transport failure returns the DioException itself
  /// rather than a translated string. Callers MUST be able to tell "the server
  /// rejected this device" from "the server could not be reached": collapsing
  /// both into one error message is what made an offline kiosk log itself out.
  Future<ApiResponseModel> getMe() async {
    try {
      final response = await dioClient.get(
        AppConstants.kioskDeviceMeUri,
        options: Options(validateStatus: (_) => true),
      );
      return ApiResponseModel.withSuccess(response);
    } catch (e) {
      return ApiResponseModel.withError(e);
    }
  }

  /// Persist the device session: token (for auth header) + bound branch.
  Future<void> saveSession({
    required String token,
    required int branchId,
    String? branchName,
    String? branchPhone,
    String? branchEmail,
    String? branchImage,
    String? deviceName,
    String? username,
    int? deviceId,
    String? category,
    String? orderingExperience,
    bool? allergenTagEnabled,
    bool? showImages,
    bool? kioskMode,
  }) async {
    final previousBranch = getBranchId();
    await sharedPreferences.setString(AppConstants.token, token);
    await sharedPreferences.setInt(AppConstants.branch, branchId);
    if (previousBranch != branchId) {
      await sharedPreferences.remove(AppConstants.kioskMenuCacheKey);
      await sharedPreferences.remove(AppConstants.kioskDealsCacheKey);
      await sharedPreferences.remove(AppConstants.kioskManagerStockCacheKey);
    }
    if (branchName != null) {
      await sharedPreferences.setString(
          AppConstants.kioskBranchName, branchName);
    }
    if (branchPhone != null) {
      await sharedPreferences.setString(
          AppConstants.kioskBranchPhone, branchPhone);
    }
    if (branchEmail != null) {
      await sharedPreferences.setString(
          AppConstants.kioskBranchEmail, branchEmail);
    }
    if (branchImage != null) {
      await sharedPreferences.setString(
          AppConstants.kioskBranchImage, branchImage);
    }
    if (deviceName != null) {
      await sharedPreferences.setString(
          AppConstants.kioskDeviceName, deviceName);
    }
    if (username != null) {
      await sharedPreferences.setString(AppConstants.kioskUsername, username);
    }
    if (deviceId != null) {
      await sharedPreferences.setInt(AppConstants.kioskDeviceId, deviceId);
    }
    if (category != null) {
      await sharedPreferences.setString(
          AppConstants.kioskDeviceCategory, category);
    }
    if (orderingExperience != null) {
      await sharedPreferences.setString(
          AppConstants.kioskOrderingExperience, orderingExperience);
    }
    if (allergenTagEnabled != null) {
      await sharedPreferences.setBool(
          AppConstants.kioskAllergenTagEnabled, allergenTagEnabled);
    }
    if (showImages != null) {
      await sharedPreferences.setBool(
          AppConstants.kioskShowImages, showImages);
    }
    if (kioskMode != null) {
      _writeSessionKioskMode(kioskMode);
    }
    // Refresh dio headers so the new token + branch take effect immediately.
    await dioClient.updateHeader(getToken: token);
  }

  bool isLoggedIn() => sharedPreferences.containsKey(AppConstants.token);

  String getToken() => sharedPreferences.getString(AppConstants.token) ?? '';

  String getBranchName() =>
      sharedPreferences.getString(AppConstants.kioskBranchName) ?? '';

  String getBranchPhone() =>
      sharedPreferences.getString(AppConstants.kioskBranchPhone) ?? '';

  String getBranchEmail() =>
      sharedPreferences.getString(AppConstants.kioskBranchEmail) ?? '';

  String getBranchImage() =>
      sharedPreferences.getString(AppConstants.kioskBranchImage) ?? '';

  String getDeviceName() =>
      sharedPreferences.getString(AppConstants.kioskDeviceName) ?? '';

  String getUsername() =>
      sharedPreferences.getString(AppConstants.kioskUsername) ?? '';

  int? getBranchId() => sharedPreferences.containsKey(AppConstants.branch)
      ? sharedPreferences.getInt(AppConstants.branch)
      : null;

  int? getDeviceId() =>
      sharedPreferences.containsKey(AppConstants.kioskDeviceId)
          ? sharedPreferences.getInt(AppConstants.kioskDeviceId)
          : null;

  /// 'kiosk' or 'pos'. Defaults to 'kiosk' (the safe/pre-existing behavior)
  /// if a session was persisted before this field existed.
  String getDeviceCategory() =>
      sharedPreferences.getString(AppConstants.kioskDeviceCategory) ?? 'kiosk';

  /// Raw `ordering_experience` as last sent by the server, or null if this
  /// device has never seen the field (session persisted before it existed).
  /// Callers go through [KioskOrderingExperience.fromApi] rather than reading
  /// this string directly, so an unknown value always lands on Version A.
  String? getOrderingExperience() =>
      sharedPreferences.getString(AppConstants.kioskOrderingExperience);

  /// Per-branch "show allergen tags" toggle, set by branch admin. Defaults to
  /// false so a session persisted before this field existed (or a branch that
  /// never turned it on) shows no allergen disclosure.
  bool getAllergenTagEnabled() =>
      sharedPreferences.getBool(AppConstants.kioskAllergenTagEnabled) ?? false;

  /// Per-device "Show Product Images" toggle. Defaults to true so a session
  /// persisted before this field existed (or any missing value) keeps showing
  /// images exactly as today -- the picture-less mode is strictly opt-in.
  bool getShowImages() =>
      sharedPreferences.getBool(AppConstants.kioskShowImages) ?? true;

  /// Whether this POS till is currently serving as a kiosk.
  ///
  /// Read from the browser's `sessionStorage`, not SharedPreferences: the
  /// POS⇄Kiosk switch is temporary and must last only for the running browser
  /// session. A plain in-tab reload keeps the same session, so the till stays a
  /// kiosk; closing/killing the app ends the session, so a cold relaunch always
  /// reads false and reopens as POS. Defaults to false (a normal till) when
  /// absent or unreadable. Only meaningful on a `pos` device.
  bool getKioskMode() => _readSessionKioskMode();

  /// Persist the session-local kiosk flag for the current browser session.
  /// Session-scoped (see [getKioskMode]): never written to SharedPreferences,
  /// so it cannot survive a full application restart.
  Future<void> saveKioskMode(bool kioskMode) async {
    _writeSessionKioskMode(kioskMode);
  }

  /// Reads the session-scoped kiosk flag. Wrapped in try/catch because
  /// `sessionStorage` can throw or be unavailable (private browsing, blocked
  /// storage); the safe fallback is false, i.e. a normal POS till.
  bool _readSessionKioskMode() {
    try {
      return html.window.sessionStorage[AppConstants.kioskDeviceKioskMode] ==
          'true';
    } catch (_) {
      return false;
    }
  }

  /// Writes (or clears) the session-scoped kiosk flag. Silently does nothing if
  /// `sessionStorage` is unavailable -- the in-memory flag on
  /// `KioskAuthProvider` still drives the running screen either way.
  void _writeSessionKioskMode(bool kioskMode) {
    try {
      if (kioskMode) {
        html.window.sessionStorage[AppConstants.kioskDeviceKioskMode] = 'true';
      } else {
        html.window.sessionStorage.remove(AppConstants.kioskDeviceKioskMode);
      }
    } catch (_) {
      // Storage unavailable: nothing to persist for this session.
    }
  }

  /// Persist a live show-images update from the websocket (admin flipped the
  /// toggle on Device Update without forcing a re-login) -- mirrors
  /// [saveOrderingExperience].
  Future<void> saveShowImages(bool showImages) async {
    await sharedPreferences.setBool(
        AppConstants.kioskShowImages, showImages);
  }

  /// Persist a live Ordering Experience update from the websocket (admin
  /// changed Device Update without forcing a re-login).
  Future<void> saveOrderingExperience(String orderingExperience) async {
    await sharedPreferences.setString(
        AppConstants.kioskOrderingExperience, orderingExperience);
  }

  /// Persist an allergen tag toggle made from POS Settings, without a
  /// re-login -- mirrors [saveOrderingExperience].
  Future<void> saveAllergenTagEnabled(bool enabled) async {
    await sharedPreferences.setBool(
        AppConstants.kioskAllergenTagEnabled, enabled);
  }

  /// Persist the device id when an older session never stored it.
  Future<void> saveDeviceId(int deviceId) async {
    await sharedPreferences.setInt(AppConstants.kioskDeviceId, deviceId);
  }

  /// Wipe the device session (revoked/inactive/logout).
  Future<void> clearSession() async {
    await sharedPreferences.remove(AppConstants.token);
    await sharedPreferences.remove(AppConstants.branch);
    await sharedPreferences.remove(AppConstants.kioskBranchName);
    await sharedPreferences.remove(AppConstants.kioskBranchPhone);
    await sharedPreferences.remove(AppConstants.kioskBranchEmail);
    await sharedPreferences.remove(AppConstants.kioskBranchImage);
    await sharedPreferences.remove(AppConstants.kioskDeviceName);
    await sharedPreferences.remove(AppConstants.kioskUsername);
    await sharedPreferences.remove(AppConstants.kioskDeviceId);
    await sharedPreferences.remove(AppConstants.kioskDeviceCategory);
    await sharedPreferences.remove(AppConstants.kioskOrderingExperience);
    await sharedPreferences.remove(AppConstants.kioskAllergenTagEnabled);
    await sharedPreferences.remove(AppConstants.kioskShowImages);
    // Session-scoped now (sessionStorage); also drop any value an older build
    // left in SharedPreferences so a stale flag can never resurrect kiosk mode.
    _writeSessionKioskMode(false);
    await sharedPreferences.remove(AppConstants.kioskDeviceKioskMode);
    await sharedPreferences.remove(AppConstants.cartList);
    await sharedPreferences.remove(AppConstants.kioskMenuCacheKey);
    await sharedPreferences.remove(AppConstants.kioskDealsCacheKey);
    await sharedPreferences.remove(AppConstants.kioskManagerStockCacheKey);
    await dioClient.updateHeader(getToken: null);
  }
}
