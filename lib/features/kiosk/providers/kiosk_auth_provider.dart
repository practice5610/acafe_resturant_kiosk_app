import 'package:flutter/material.dart';
import 'package:acafe_customer/common/models/api_response_model.dart';
import 'package:acafe_customer/common/models/response_model.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_auth_repo.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_ordering_experience.dart';
import 'package:acafe_customer/helper/api_checker_helper.dart';

/// Manages the persistent kiosk device session: one-time login, boot-time
/// token validation, and revocation handling. Extends the existing networking
/// layer rather than replacing it.
class KioskAuthProvider extends ChangeNotifier {
  final KioskAuthRepo kioskAuthRepo;

  KioskAuthProvider({required this.kioskAuthRepo});

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String _loginError = '';
  String get loginError => _loginError;

  bool isLoggedIn() => kioskAuthRepo.isLoggedIn();

  String get branchName => kioskAuthRepo.getBranchName();
  String get deviceName => kioskAuthRepo.getDeviceName();
  int? get deviceId => kioskAuthRepo.getDeviceId();
  int? get branchId => kioskAuthRepo.getBranchId();

  /// Which customization flow this device renders, chosen by admin on the
  /// Device Update screen. Always resolves to a flow the app can render, even
  /// for a session persisted before the setting existed.
  KioskOrderingExperience get orderingExperience =>
      KioskOrderingExperience.fromApi(kioskAuthRepo.getOrderingExperience());

  /// 'kiosk' or 'pos' -- gates whether the manager icon is shown.
  String get category => kioskAuthRepo.getDeviceCategory();
  bool get isPosDevice => category == 'pos';

  /// Apply an Ordering Experience push from Reverb. Ignores events aimed at
  /// another device. When this session never persisted a device id (older
  /// login), adopts [deviceId] from the event so subsequent filters work.
  /// Returns true when the local cached value actually changed.
  Future<bool> applyOrderingExperienceFromRealtime({
    required int deviceId,
    required String orderingExperience,
  }) async {
    if (deviceId <= 0) {
      return false;
    }
    final int? localDeviceId = kioskAuthRepo.getDeviceId();
    if (localDeviceId != null && localDeviceId != deviceId) {
      return false;
    }
    final next = KioskOrderingExperience.fromApi(orderingExperience);
    if (this.orderingExperience == next &&
        kioskAuthRepo.getOrderingExperience() == next.apiValue) {
      return false;
    }
    await kioskAuthRepo.saveOrderingExperience(next.apiValue);
    if (localDeviceId == null) {
      await kioskAuthRepo.saveDeviceId(deviceId);
    }
    notifyListeners();
    return true;
  }

  /// Re-read this device's back-office settings from `/device/me` and apply the
  /// Ordering Experience the server reports. Returns true when the cached value
  /// actually changed.
  ///
  /// Called when the catalog socket reconnects. Reverb does not replay: a
  /// `device.ordering_experience.changed` push sent while the kiosk was
  /// disconnected -- Reverb restarted, wifi dropped, tablet asleep, or the
  /// broadcast itself failed because the socket server was down -- is gone for
  /// good. Without this, the only thing that refreshed the setting was a cold
  /// boot, so an admin's switch appeared to do nothing until someone killed the
  /// app.
  ///
  /// Deliberately never clears the session, unlike [validateSession]. A
  /// reconnect is exactly when a transient failure is most likely, and logging
  /// a kiosk out mid-service over one failed request would be far worse than
  /// running a stale flow until the next attempt.
  Future<bool> refreshDeviceSettings() async {
    if (!kioskAuthRepo.isLoggedIn()) {
      return false;
    }

    final ApiResponseModel apiResponse = await kioskAuthRepo.getMe();
    if (apiResponse.response?.statusCode != 200) {
      return false;
    }
    final dynamic data = apiResponse.response!.data;
    final dynamic device = data is Map ? data['device'] : null;
    if (device is! Map) {
      return false;
    }

    // An absent/empty field means "this server build does not report it", not
    // "reset to Version A" -- fromApi() would fall back and silently downgrade
    // a Version B kiosk on every reconnect.
    final String? experience = device['ordering_experience']?.toString();
    if (experience == null || experience.isEmpty) {
      return false;
    }

    final int deviceId = device['id'] is int
        ? device['id'] as int
        : int.tryParse('${device['id']}') ?? (kioskAuthRepo.getDeviceId() ?? 0);

    return applyOrderingExperienceFromRealtime(
      deviceId: deviceId,
      orderingExperience: experience,
    );
  }

  /// One-time device login. On success persists token + bound branch and
  /// returns success; on failure returns the server message (wrong creds /
  /// inactive device).
  Future<ResponseModel> login(String username, String password) async {
    _isLoading = true;
    _loginError = '';
    notifyListeners();

    final ApiResponseModel apiResponse =
        await kioskAuthRepo.login(username.trim(), password);
    ResponseModel responseModel;

    if (apiResponse.response != null &&
        apiResponse.response!.statusCode == 200) {
      final Map data = apiResponse.response!.data;
      final String token = data['token'];
      final Map branch = data['branch'] ?? {};
      final Map device = data['device'] ?? {};

      await kioskAuthRepo.saveSession(
        token: token,
        branchId: branch['id'] is int
            ? branch['id']
            : int.tryParse('${branch['id']}') ?? -1,
        branchName: branch['name']?.toString(),
        deviceName: device['name']?.toString(),
        username: device['username']?.toString(),
        deviceId: device['id'] is int
            ? device['id']
            : int.tryParse('${device['id']}'),
        category: device['category']?.toString(),
        orderingExperience: device['ordering_experience']?.toString(),
      );
      responseModel = ResponseModel(true, 'logged_in');
    } else {
      _loginError =
          ApiCheckerHelper.getError(apiResponse).errors![0].message ?? '';
      responseModel = ResponseModel(false, _loginError);
    }

    _isLoading = false;
    notifyListeners();
    return responseModel;
  }

  /// Validate a stored token on boot. true = valid (branch hydrated/refreshed),
  /// false = no token or revoked/inactive (session wiped by caller intent).
  Future<bool> validateSession() async {
    if (!kioskAuthRepo.isLoggedIn()) {
      return false;
    }

    final ApiResponseModel apiResponse = await kioskAuthRepo.getMe();
    if (apiResponse.response != null &&
        apiResponse.response!.statusCode == 200) {
      final Map data = apiResponse.response!.data;
      final Map branch = data['branch'] ?? {};
      final Map device = data['device'] ?? {};
      if (branch.isNotEmpty) {
        // Refresh the persisted branch/device labels in case admin renamed them.
        await kioskAuthRepo.saveSession(
          token: kioskAuthRepo.getToken(),
          branchId: branch['id'] is int
              ? branch['id']
              : int.tryParse('${branch['id']}') ?? -1,
          branchName: branch['name']?.toString(),
          deviceName: device['name']?.toString(),
          username: device['username']?.toString(),
          deviceId: device['id'] is int
              ? device['id']
              : int.tryParse('${device['id']}'),
          category: device['category']?.toString(),
          orderingExperience: device['ordering_experience']?.toString(),
        );
      }
      // ProductRealtimeScope watches this provider, so the restored session has
      // to announce itself -- otherwise a device that admin re-bound to another
      // branch keeps listening on the old branch's channel. login() and
      // logout() already notify; this path was the only one that did not.
      notifyListeners();
      return true;
    }

    // Revoked / inactive / network-invalid token: wipe so the kiosk re-logs in.
    await kioskAuthRepo.clearSession();
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    await kioskAuthRepo.clearSession();
    notifyListeners();
  }
}
