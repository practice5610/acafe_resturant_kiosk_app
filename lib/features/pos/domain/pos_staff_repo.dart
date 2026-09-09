import 'dart:convert';

import 'package:acafe_customer/common/models/api_response_model.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/exception/api_error_handler.dart';
import 'package:acafe_customer/features/pos/domain/pos_staff.dart';
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Loads and saves the POS staff roster.
///
/// Source of truth is the branch-scoped API (`/api/v1/kiosk/manager/staff`).
/// SharedPreferences is only a boot cache for when the network is down.
class PosStaffRepo {
  final SharedPreferences sharedPreferences;
  final DioClient? dioClient;

  PosStaffRepo({
    required this.sharedPreferences,
    this.dioClient,
  });

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

  Future<bool> saveLocal(PosStaffRoster roster) {
    return sharedPreferences.setString(
      AppConstants.posStaffRosterKey,
      jsonEncode(roster.toJson()),
    );
  }

  Future<bool> clearLocal() =>
      sharedPreferences.remove(AppConstants.posStaffRosterKey);

  /// Fetches the branch roster from the server. Returns `null` when there is
  /// no Dio client (unit tests) or the request fails — caller falls back to
  /// cache / empty.
  Future<PosStaffRoster?> fetchRemote() async {
    final DioClient? client = dioClient;
    if (client == null) return null;
    try {
      final response = await client.get('/api/v1/kiosk/manager/staff');
      final Object? data = response.data;
      if (data is! Map) return null;
      return PosStaffRoster.fromJson(Map<String, dynamic>.from(data));
    } catch (_) {
      return null;
    }
  }

  /// Replaces the branch roster on the server. Returns false on failure so
  /// the provider can keep the optimistic local copy and surface an error.
  Future<ApiResponseModel> saveRemote(PosStaffRoster roster) async {
    final DioClient? client = dioClient;
    if (client == null) {
      return ApiResponseModel.withSuccess(null);
    }
    try {
      final response = await client.put(
        '/api/v1/kiosk/manager/staff',
        data: roster.toJson(),
      );
      return ApiResponseModel.withSuccess(response);
    } catch (e) {
      return ApiResponseModel.withError(ApiErrorHandler.getMessage(e));
    }
  }

  /// @deprecated Prefer [saveLocal] — kept so older call sites compile during
  /// the cutover.
  Future<bool> save(PosStaffRoster roster) => saveLocal(roster);

  Future<bool> clear() => clearLocal();
}
