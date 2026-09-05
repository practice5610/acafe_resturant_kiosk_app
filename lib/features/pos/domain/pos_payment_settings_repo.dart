import 'dart:convert';

import 'package:acafe_customer/features/pos/domain/pos_payment_settings.dart';
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists POS Payments settings locally.
///
/// Structured exactly like [PosGeneralSettingsRepo] and
/// [PosHardwareSettingsRepo], and carrying the same documented limitation:
/// there is no device-scoped endpoint to write terminal preferences back to
/// the server, so this is per-terminal SharedPreferences state rather than a
/// synced store setting.
///
/// [loadEnabledTenders] exists so callers that only need to know which methods
/// the terminal accepts — the payment selector, which runs outside the Settings
/// tab and has no provider in scope — can read that without standing up the
/// whole settings stack.
class PosPaymentSettingsRepo {
  final SharedPreferences sharedPreferences;

  PosPaymentSettingsRepo({required this.sharedPreferences});

  PosPaymentSettings? loadSaved() {
    final String? raw =
        sharedPreferences.getString(AppConstants.posPaymentSettingsKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return PosPaymentSettings.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  /// Saved settings, or the both-tenders-on default for a terminal that has
  /// never opened this screen.
  PosPaymentSettings load() => loadSaved() ?? PosPaymentSettings.initial();

  Future<bool> save(PosPaymentSettings settings) {
    return sharedPreferences.setString(
      AppConstants.posPaymentSettingsKey,
      jsonEncode(settings.toJson()),
    );
  }

  Future<bool> clear() =>
      sharedPreferences.remove(AppConstants.posPaymentSettingsKey);
}
