import 'dart:convert';

import 'package:acafe_customer/features/pos/domain/pos_staff.dart';
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the POS staff roster and shift assignments locally.
///
/// Same constraint as [PosGeneralSettingsRepo] and [PosHardwareSettingsRepo]:
/// the server has no POS-staff surface to write to. Employees live in the
/// `admins` table behind the admin web module (name, email, password, identity
/// documents), and there is no shift table at all — so rostering, POS
/// passcodes and floor permissions have nowhere to go server-side yet. They
/// live in SharedPreferences per terminal until those endpoints exist; the
/// model and provider above this are already shaped for that swap.
class PosStaffRepo {
  final SharedPreferences sharedPreferences;

  PosStaffRepo({required this.sharedPreferences});

  PosStaffRoster? loadSaved() {
    final String? raw =
        sharedPreferences.getString(AppConstants.posStaffRosterKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return PosStaffRoster.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<bool> save(PosStaffRoster roster) {
    return sharedPreferences.setString(
      AppConstants.posStaffRosterKey,
      jsonEncode(roster.toJson()),
    );
  }

  Future<bool> clear() =>
      sharedPreferences.remove(AppConstants.posStaffRosterKey);
}
