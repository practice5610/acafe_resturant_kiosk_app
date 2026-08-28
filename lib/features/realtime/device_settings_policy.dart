import 'package:acafe_customer/features/realtime/device_settings_event.dart';

/// What the kiosk should do with a device settings push.
enum DeviceSettingsClientAction {
  /// Duplicate, malformed, or addressed to a different device.
  ignore,

  /// Store the new settings. The Ordering Experience is read fresh every time
  /// a customization screen opens, so this alone is the whole A/B switch.
  apply,

  /// Settings changed AND the device was moved to another branch: the menu,
  /// the socket subscription and the cart all belong to the old branch.
  applyAndRebind,

  /// Device deactivated or deleted — drop the session and go back to login.
  signOut,
}

/// Pure rules for device settings events. No transport, no providers, no I/O,
/// so every branch of the decision is cheap to test.
class DeviceSettingsPolicy {
  static DeviceSettingsClientAction decide({
    required DeviceSettingsEvent event,
    required int? currentDeviceId,
    required int? currentBranchId,
    required bool duplicateEventId,
  }) {
    if (duplicateEventId || event.deviceId <= 0) {
      return DeviceSettingsClientAction.ignore;
    }
    // The channel is per-device, but a stale subscription after an admin
    // re-binds a kiosk would otherwise let another device's settings through.
    if (currentDeviceId != null && currentDeviceId != event.deviceId) {
      return DeviceSettingsClientAction.ignore;
    }
    if (event.isSignOut) {
      return DeviceSettingsClientAction.signOut;
    }
    if (event.branchId > 0 &&
        currentBranchId != null &&
        currentBranchId > 0 &&
        event.branchId != currentBranchId) {
      return DeviceSettingsClientAction.applyAndRebind;
    }
    return DeviceSettingsClientAction.apply;
  }
}
