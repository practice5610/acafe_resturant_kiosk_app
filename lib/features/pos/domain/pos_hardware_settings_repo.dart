import 'dart:convert';

import 'package:acafe_customer/features/pos/domain/pos_hardware_settings.dart';
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists POS Hardware settings locally.
///
/// Same constraint as [PosGeneralSettingsRepo]: there is no device-scoped
/// endpoint to write terminal preferences back to the server — that store is
/// admin-web only, and adding one needs a migration. Until then these live in
/// SharedPreferences, per terminal, which is where printer preferences
/// arguably belong anyway.
class PosHardwareSettingsRepo {
  final SharedPreferences sharedPreferences;

  PosHardwareSettingsRepo({required this.sharedPreferences});

  PosHardwareSettings? loadSaved({required String storeName}) {
    final String? raw =
        sharedPreferences.getString(AppConstants.posHardwareSettingsKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return PosHardwareSettings.fromJson(decoded, storeName: storeName);
    } catch (_) {
      return null;
    }
  }

  Future<bool> save(PosHardwareSettings settings) {
    return sharedPreferences.setString(
      AppConstants.posHardwareSettingsKey,
      jsonEncode(settings.toJson()),
    );
  }

  Future<bool> clear() =>
      sharedPreferences.remove(AppConstants.posHardwareSettingsKey);
}
