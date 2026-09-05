import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:acafe_customer/common/models/api_response_model.dart';
import 'package:acafe_customer/common/models/response_model.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_auth_repo.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_ordering_experience.dart';
import 'package:acafe_customer/helper/api_checker_helper.dart';

/// What a device-settings push (or a reconnect reconciliation) did to the
/// local session. The realtime controller drives navigation off this.
enum KioskDeviceSettingsOutcome {
  /// Nothing to do: duplicate, another device, or identical to what is stored.
  ignored,

  /// New settings stored (category / ordering experience / name).
  applied,

  /// Stored AND the device now belongs to a different branch: the menu, the
  /// socket subscription and the cart all belong to the old branch.
  reboundBranch,

  /// Device deactivated or deleted -- session wiped, kiosk must return to the
  /// device login screen.
  signedOut,
}

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
  String get branchPhone => kioskAuthRepo.getBranchPhone();
  String get branchEmail => kioskAuthRepo.getBranchEmail();
  String get branchImageUrl => kioskAuthRepo.getBranchImage();
  String get deviceName => kioskAuthRepo.getDeviceName();
  String get username => kioskAuthRepo.getUsername();
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

  /// Apply a `device.settings.changed` push: device type (category), status,
  /// name, branch and ordering experience in one shot.
  ///
  /// Everything is optional in the payload sense -- an empty string means "the
  /// server did not report this field", never "clear it". Blindly writing an
  /// absent field is how a kiosk silently downgrades itself on an older server
  /// build.
  Future<KioskDeviceSettingsOutcome> applyDeviceSettingsFromRealtime({
    required int deviceId,
    int branchId = 0,
    String category = '',
    String status = '',
    String name = '',
    String orderingExperience = '',
    bool signOut = false,
  }) async {
    if (deviceId <= 0) {
      return KioskDeviceSettingsOutcome.ignored;
    }
    final int? localDeviceId = kioskAuthRepo.getDeviceId();
    if (localDeviceId != null && localDeviceId != deviceId) {
      return KioskDeviceSettingsOutcome.ignored;
    }
    if (!kioskAuthRepo.isLoggedIn()) {
      return KioskDeviceSettingsOutcome.ignored;
    }

    if (signOut) {
      await kioskAuthRepo.clearSession();
      notifyListeners();
      return KioskDeviceSettingsOutcome.signedOut;
    }

    final int? localBranchId = kioskAuthRepo.getBranchId();
    final bool branchChanged =
        branchId > 0 && localBranchId != null && branchId != localBranchId;

    final String? nextExperience = orderingExperience.isEmpty
        ? null
        : KioskOrderingExperience.fromApi(orderingExperience).apiValue;
    final bool experienceChanged = nextExperience != null &&
        nextExperience != kioskAuthRepo.getOrderingExperience();
    final bool categoryChanged =
        category.isNotEmpty && category != kioskAuthRepo.getDeviceCategory();
    final bool nameChanged =
        name.isNotEmpty && name != kioskAuthRepo.getDeviceName();

    if (!branchChanged &&
        !experienceChanged &&
        !categoryChanged &&
        !nameChanged &&
        localDeviceId != null) {
      return KioskDeviceSettingsOutcome.ignored;
    }

    // saveSession is what clears the branch-scoped menu/deal/stock caches when
    // the branch id actually changes -- writing the keys individually here
    // would leave the old branch's menu on screen.
    await kioskAuthRepo.saveSession(
      token: kioskAuthRepo.getToken(),
      branchId: branchId > 0 ? branchId : (localBranchId ?? -1),
      deviceName: name.isEmpty ? null : name,
      deviceId: deviceId,
      category: category.isEmpty ? null : category,
      orderingExperience: nextExperience,
    );
    notifyListeners();

    return branchChanged
        ? KioskDeviceSettingsOutcome.reboundBranch
        : KioskDeviceSettingsOutcome.applied;
  }

  /// Re-read this device's back-office settings from `/device/me` and apply
  /// all of them. Returns what changed.
  ///
  /// Called whenever the catalog socket (re)connects and whenever the app comes
  /// back to the foreground. Reverb does not replay: a `device.settings.changed`
  /// push sent while the kiosk was disconnected -- Reverb restarted, wifi
  /// dropped, tablet asleep, or the broadcast itself failed because the socket
  /// server was down -- is gone for good. Without this pass, the only thing
  /// that refreshed these settings was a cold boot.
  Future<KioskDeviceSettingsOutcome> refreshDeviceSettings() async {
    if (!kioskAuthRepo.isLoggedIn()) {
      return KioskDeviceSettingsOutcome.ignored;
    }

    final ApiResponseModel apiResponse = await kioskAuthRepo.getMe();
    final int? statusCode = _statusCodeOf(apiResponse);

    // Token revoked while the socket was down -- the device was deactivated or
    // deleted and the push never arrived. This IS the authoritative answer, so
    // act on it.
    if (statusCode == 401 || statusCode == 403) {
      await kioskAuthRepo.clearSession();
      notifyListeners();
      return KioskDeviceSettingsOutcome.signedOut;
    }

    // Anything else -- offline, DNS failure, 500, gateway timeout -- is not
    // evidence about this device. Never log a kiosk out mid-service over one
    // failed request; the next reconnect tries again.
    if (statusCode != 200) {
      return KioskDeviceSettingsOutcome.ignored;
    }

    final dynamic data = apiResponse.response!.data;
    final dynamic device = data is Map ? data['device'] : null;
    if (device is! Map) {
      return KioskDeviceSettingsOutcome.ignored;
    }
    final dynamic branch = data is Map ? data['branch'] : null;

    final int deviceId = _asInt(device['id']) ?? (kioskAuthRepo.getDeviceId() ?? 0);
    final int branchId = (branch is Map ? _asInt(branch['id']) : null) ?? 0;
    final String status = device['status']?.toString() ?? '';

    // A device reported inactive is a sign-out even if the token still works.
    if (status.isNotEmpty && status != 'active') {
      await kioskAuthRepo.clearSession();
      notifyListeners();
      return KioskDeviceSettingsOutcome.signedOut;
    }

    return applyDeviceSettingsFromRealtime(
      deviceId: deviceId,
      branchId: branchId,
      category: device['category']?.toString() ?? '',
      status: status,
      name: device['name']?.toString() ?? '',
      // An absent/empty field means "this server build does not report it",
      // not "reset to Version A" -- fromApi() would fall back and silently
      // downgrade a Version B kiosk on every reconnect.
      orderingExperience: device['ordering_experience']?.toString() ?? '',
    );
  }

  /// HTTP status of a response OR of the DioException behind a failed one.
  /// `ApiResponseModel.response` is null on transport failures, which is
  /// exactly the case that must NOT be read as "the server rejected us".
  static int? _statusCodeOf(ApiResponseModel apiResponse) {
    final int? code = apiResponse.response?.statusCode;
    if (code != null) {
      return code;
    }
    final dynamic error = apiResponse.error;
    if (error is DioException) {
      return error.response?.statusCode;
    }
    return null;
  }

  static int? _asInt(dynamic value) =>
      value is int ? value : int.tryParse('$value');

  /// One-time device login. On success persists token + bound branch and
  /// returns success; on failure returns the server message (wrong creds /
  /// inactive device).
  Future<ResponseModel> login(String username, String password) async {
    _isLoading = true;
    _loginError = '';
    notifyListeners();

    final ApiResponseModel apiResponse =
        await kioskAuthRepo.login(username.trim(), password.trim());
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
        branchPhone: branch['phone']?.toString(),
        branchEmail: branch['email']?.toString(),
        branchImage: (branch['image_full_path'] ?? branch['image'])?.toString(),
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
          branchPhone: branch['phone']?.toString(),
          branchEmail: branch['email']?.toString(),
          branchImage:
              (branch['image_full_path'] ?? branch['image'])?.toString(),
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

    // Only an authoritative rejection wipes the session. A kiosk that boots
    // with the network down would otherwise be thrown to a login screen it
    // cannot complete -- while a perfectly good token and a cached menu sit in
    // storage. Offline boots continue into the app; the next successful
    // /device/me (reconnect or resume) re-validates.
    final int? statusCode = _statusCodeOf(apiResponse);
    if (statusCode == 401 || statusCode == 403) {
      await kioskAuthRepo.clearSession();
      notifyListeners();
      return false;
    }

    notifyListeners();
    return kioskAuthRepo.isLoggedIn();
  }

  Future<void> logout() async {
    await kioskAuthRepo.clearSession();
    notifyListeners();
  }
}
