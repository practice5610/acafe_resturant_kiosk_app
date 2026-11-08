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

  /// Which language a kiosk falls back to, in order, once the current one and
  /// English are not offered. An explicit list, not the display order of
  /// [AppConstants.languages]: reordering the flag row must not change it. The
  /// first four are the order the kiosk always fell back in.
  static const List<String> fallbackOrder = [
    'nl', 'en', 'fr', 'de', 'it', 'ja', 'zh', 'es',
  ];

  /// The language a kiosk offering [offered] should be in while currently in
  /// [currentCode]: that one if it is offered, otherwise English (the kiosk
  /// default), otherwise the first offered language in [fallbackOrder],
  /// otherwise the first offered.
  ///
  /// [offered] is never empty — [forDevice] falls back to every language.
  static LanguageModel selectionFor(
    List<LanguageModel> offered,
    String currentCode,
  ) {
    LanguageModel? find(String code) {
      for (final LanguageModel l in offered) {
        if (l.languageCode == code) return l;
      }
      return null;
    }

    LanguageModel? byFallbackOrder() {
      for (final String code in fallbackOrder) {
        final LanguageModel? l = find(code);
        if (l != null) return l;
      }
      return null;
    }

    return find(currentCode) ??
        find(AppConstants.defaultLanguageCode) ??
        byFallbackOrder() ??
        offered.first;
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
