import 'dart:convert';

import 'package:acafe_customer/features/pos/domain/pos_general_settings.dart';
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists POS General settings locally.
///
/// There is no authenticated client API to write restaurant identity back to
/// the admin `business_settings` store — that path is admin-web only. Until a
/// device-scoped update endpoint exists, saved values live in
/// SharedPreferences and overlay the read-only [ConfigModel] seed on load.
class PosGeneralSettingsRepo {
  final SharedPreferences sharedPreferences;

  PosGeneralSettingsRepo({required this.sharedPreferences});

  PosGeneralSettings? loadSaved() {
    final String? raw =
        sharedPreferences.getString(AppConstants.posGeneralSettingsKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return PosGeneralSettings.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<bool> save(PosGeneralSettings settings) {
    return sharedPreferences.setString(
      AppConstants.posGeneralSettingsKey,
      jsonEncode(settings.toJson()),
    );
  }

  Future<bool> clear() =>
      sharedPreferences.remove(AppConstants.posGeneralSettingsKey);
}
