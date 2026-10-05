import 'dart:convert';

import 'package:acafe_customer/common/models/api_response_model.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/exception/api_error_handler.dart';
import 'package:acafe_customer/features/pos/domain/pos_staff.dart';
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Loads and saves the POS staff roster and its catalogue.
///
/// Source of truth is the branch-scoped API. SharedPreferences caches the roster
/// and catalogue so a terminal that boots without a network still renders the
/// screen it had — never so it can invent one.
///
/// Every write is per member. The old whole-roster PUT still exists server-side
/// for older builds, but sending it from here would mean a keystroke on one
/// member could overwrite another's record, which is exactly what a second till
/// in the same branch used to do.
class PosStaffRepo {
  final SharedPreferences sharedPreferences;
  final DioClient? dioClient;

  PosStaffRepo({
    required this.sharedPreferences,
    this.dioClient,
  });

  static const String _base = '/api/v1/kiosk/manager/staff';

  /// Every staff call treats a 4xx as an ordinary response. The app's global
  /// API checker force-logs-out the device on a thrown 401, and a wrong PIN or a
  /// rejected edit must never cost the terminal its device session.
  static final Options _keepDevice =
      Options(validateStatus: (status) => status != null && status < 500);

  // ── Local cache ───────────────────────────────────────────────────────

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

  PosStaffCatalogue? loadSavedCatalogue() {
    final String? raw =
        sharedPreferences.getString(AppConstants.posStaffCatalogueKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return PosStaffCatalogue.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<bool> saveCatalogueLocal(PosStaffCatalogue catalogue) {
    return sharedPreferences.setString(
      AppConstants.posStaffCatalogueKey,
      jsonEncode(catalogue.toJson()),
    );
  }

  Future<bool> clearLocal() =>
      sharedPreferences.remove(AppConstants.posStaffRosterKey);

  // ── Reads ─────────────────────────────────────────────────────────────

  /// The permission list, assignable roles, shifts and branch for this device.
  Future<PosStaffCatalogue?> fetchCatalogue() async {
    final DioClient? client = dioClient;
    if (client == null) return null;
    try {
      final response = await client.get('$_base/catalogue', options: _keepDevice);
      if ((response.statusCode ?? 0) >= 400) return null;
      final Object? data = response.data;
      if (data is! Map) return null;
      return PosStaffCatalogue.fromJson(Map<String, dynamic>.from(data));
    } catch (_) {
      return null;
    }
  }

  Future<PosStaffRoster?> fetchRemote() async {
    final DioClient? client = dioClient;
    if (client == null) return null;
    try {
      final response = await client.get(_base, options: _keepDevice);
      if ((response.statusCode ?? 0) >= 400) return null;
      final Object? data = response.data;
      if (data is! Map) return null;
      return PosStaffRoster.fromJson(Map<String, dynamic>.from(data));
    } catch (_) {
      return null;
    }
  }

  // ── Per-member writes ─────────────────────────────────────────────────

  Future<ApiResponseModel> createMember({
    required String name,
    required int roleId,
    required List<String> shiftIds,
    String? surname,
    String? email,
    String? gender,
    String? phone,
    bool active = true,
    String? pin,
  }) {
    return _send(() => dioClient!.post('$_base/members', options: _keepDevice, data: {
          'name': name,
          // First name + surname + email + gender are what Planday needs; the
          // backend requires them only on a Planday-enabled branch.
          if (surname != null && surname.isNotEmpty) 'surname': surname,
          if (email != null && email.isNotEmpty) 'email': email,
          if (gender != null && gender.isNotEmpty) 'gender': gender,
          'role_id': roleId,
          'shift_ids': shiftIds,
          'active': active,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
          if (pin != null && pin.isNotEmpty) 'pin': pin,
        }));
  }

  /// A PATCH: anything omitted keeps its current value, so one toggle cannot
  /// blank a name or drop a shift.
  Future<ApiResponseModel> updateMember(
    String publicId, {
    String? name,
    String? surname,
    String? email,
    String? gender,
    int? roleId,
    bool? active,
    List<String>? shiftIds,
    Map<String, bool>? permissions,
  }) {
    return _send(() => dioClient!.patch('$_base/members/$publicId', options: _keepDevice, data: {
          if (name != null) 'name': name,
          if (surname != null) 'surname': surname,
          if (email != null) 'email': email,
          if (gender != null) 'gender': gender,
          if (roleId != null) 'role_id': roleId,
          if (active != null) 'active': active,
          if (shiftIds != null) 'shift_ids': shiftIds,
          if (permissions != null) 'permissions': permissions,
        }));
  }

  Future<ApiResponseModel> setPin(String publicId, String pin) {
    return _send(() => dioClient!.put('$_base/members/$publicId/pin',
        options: _keepDevice, data: {'pin': pin}));
  }

  Future<ApiResponseModel> removeMember(String publicId) {
    return _send(() => dioClient!.delete('$_base/members/$publicId', options: _keepDevice));
  }

  Future<ApiResponseModel> deactivateMember(String publicId) {
    return _send(() => dioClient!.post('$_base/members/$publicId/deactivate', options: _keepDevice));
  }

  /// Runs a call and turns a 4xx into a readable message instead of an
  /// exception, so a validation failure the server explains (a duplicate PIN,
  /// say) reaches the operator as words rather than "something went wrong".
  Future<ApiResponseModel> _send(Future<Response> Function() call) async {
    if (dioClient == null) {
      return ApiResponseModel.withSuccess(null);
    }
    try {
      final response = await call();
      final int status = response.statusCode ?? 0;
      if (status >= 200 && status < 300) {
        return ApiResponseModel.withSuccess(response);
      }
      return ApiResponseModel.withError(_messageFrom(response));
    } on DioException catch (e) {
      final Response? response = e.response;
      if (response != null) {
        return ApiResponseModel.withError(_messageFrom(response));
      }
      return ApiResponseModel.withError(ApiErrorHandler.getMessage(e));
    } catch (e) {
      return ApiResponseModel.withError(ApiErrorHandler.getMessage(e));
    }
  }

  String _messageFrom(Response response) {
    final Object? data = response.data;
    if (data is Map && data['errors'] is List && (data['errors'] as List).isNotEmpty) {
      final Object? first = (data['errors'] as List).first;
      if (first is Map && first['message'] != null) {
        return first['message'].toString();
      }
    }
    return 'Could not save that. Please try again.';
  }
}
