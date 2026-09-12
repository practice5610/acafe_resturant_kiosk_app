import 'package:flutter/material.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_manager_repo.dart';

/// Manager step-up for a POS terminal.
///
/// The terminal itself needs no PIN: anyone at the counter can use POS,
/// Orders and Receipts once the device is logged in. Report and Settings are
/// hidden until the nav bar's lock icon is tapped and the device's own
/// manager code (Admin -> Kiosk -> Configuration Code, one code per device,
/// not per employee) is entered ([elevate]). [lock] drops that grant again.
///
/// Reuses the existing `POST /api/v1/kiosk/manager/verify-code` check --
/// the same single-code gate the POS Manager subtree has always used, not a
/// second auth scheme.
///
/// In-memory only, on purpose: a reload re-locks the terminal. No idle
/// timeout in this pass.
class PosSessionProvider extends ChangeNotifier {
  final KioskManagerRepo kioskManagerRepo;

  PosSessionProvider({required this.kioskManagerRepo});

  bool _elevated = false;
  bool get canAccessManagerTabs => _elevated;

  bool _verifying = false;
  bool get verifying => _verifying;

  String? _error;
  String? get error => _error;

  /// The device's manager code temporarily unlocks the manager tabs.
  Future<bool> elevate(String pin) async {
    _verifying = true;
    _error = null;
    notifyListeners();

    final apiResponse = await kioskManagerRepo.verifyCode(pin);
    final response = apiResponse.response;
    _verifying = false;

    if (response != null && response.statusCode == 200) {
      _elevated = true;
      notifyListeners();
      return true;
    }

    _error = (response?.data is Map
            ? response!.data['message']?.toString()
            : null) ??
        'Incorrect code';
    notifyListeners();
    return false;
  }

  /// Drops a step-up grant.
  void lock() {
    _elevated = false;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Grants (or clears) manager access without a network round trip, for
  /// widget tests.
  @visibleForTesting
  void debugSetElevated(bool granted) {
    _elevated = granted;
    notifyListeners();
  }
}
