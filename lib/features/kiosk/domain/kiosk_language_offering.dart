import 'dart:convert';

import 'package:acafe_customer/common/models/language_model.dart';
import 'package:acafe_customer/di_container.dart' as di;
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which languages this terminal offers guests, per Settings → Hardware.
///
/// Reads the saved Hardware preference directly rather than through
/// `PosHardwareSettingsProvider`: the guest picker must not depend on a POS
/// settings form being mounted, and this is a read of one list of codes.
///
/// Every failure mode falls back to [AppConstants.languages] in full — an
/// unreadable preference, an empty selection, or codes that no longer ship a
/// translation file. A guest picker with nothing in it would be worse than one
/// that ignores the setting.
class KioskLanguageOffering {
  KioskLanguageOffering._();

  /// Resolves prefs from the service locator, tolerating its absence.
  ///
  /// The guest pickers are leaf widgets that get pumped directly in widget
  /// tests, where GetIt is not wired. An unguarded `di.sl<SharedPreferences>()`
  /// throws there mid-build, so the lookup is guarded and simply falls through
  /// to the full language list — the same fallback every other failure mode
  /// takes.
  static List<LanguageModel> forThisDevice() {
    return forDevice(
      di.sl.isRegistered<SharedPreferences>()
          ? di.sl<SharedPreferences>()
          : null,
    );
  }

  static List<LanguageModel> forDevice(SharedPreferences? prefs) {
    final List<String>? codes = _savedCodes(prefs);
    if (codes == null || codes.isEmpty) return AppConstants.languages;

    final List<LanguageModel> offered = AppConstants.languages
        .where((l) => codes.contains(l.languageCode))
        .toList();

    return offered.isEmpty ? AppConstants.languages : offered;
  }

  static List<String>? _savedCodes(SharedPreferences? prefs) {
    final String? raw =
        prefs?.getString(AppConstants.posHardwareSettingsKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final Object? codes = decoded['kiosk_languages'];
      if (codes is! List) return null;
      return codes.map((e) => e.toString()).toList();
    } catch (_) {
      return null;
    }
  }
}
