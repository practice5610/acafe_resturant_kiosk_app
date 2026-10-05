import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/features/pos/domain/pos_staff_session.dart';
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the staff token lives between app restarts.
///
/// Held in memory by the provider; persisted here only so a reload does not
/// make everybody sign in again mid-shift. On Android/iOS this is the platform
/// keystore. On web — this app's main target — flutter_secure_storage encrypts
/// with WebCrypto into browser storage, which is weaker than it sounds, and
/// that is acceptable for this particular value: the token is opaque to the
/// client, bound server-side to this one device, expires in twelve hours, and
/// is re-validated against the live staff record on every request. Stealing it
/// gets you a session on a terminal you are already standing at.
///
/// PINs are never stored here or anywhere else on the device.
abstract class PosStaffTokenStore {
  Future<String?> read();
  Future<DateTime?> readExpiry();
  Future<void> write(String token, DateTime? expiresAt);
  Future<void> clear();
}

class SecurePosStaffTokenStore implements PosStaffTokenStore {
  final FlutterSecureStorage storage;

  const SecurePosStaffTokenStore([this.storage = const FlutterSecureStorage()]);

  @override
  Future<String?> read() async {
    try {
      return await storage.read(key: AppConstants.posStaffTokenKey);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<DateTime?> readExpiry() async {
    try {
      final String? raw = await storage.read(key: AppConstants.posStaffTokenExpiryKey);
      return raw == null ? null : DateTime.tryParse(raw);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String token, DateTime? expiresAt) async {
    try {
      await storage.write(key: AppConstants.posStaffTokenKey, value: token);
      if (expiresAt != null) {
        await storage.write(
          key: AppConstants.posStaffTokenExpiryKey,
          value: expiresAt.toIso8601String(),
        );
      }
    } catch (_) {
      // A write that fails only costs a re-sign-in after a reload.
    }
  }

  @override
  Future<void> clear() async {
    try {
      await storage.delete(key: AppConstants.posStaffTokenKey);
      await storage.delete(key: AppConstants.posStaffTokenExpiryKey);
    } catch (_) {}
  }
}

/// In-memory store for tests and for platforms where secure storage is absent.
class MemoryPosStaffTokenStore implements PosStaffTokenStore {
  String? _token;
  DateTime? _expiry;

  @override
  Future<String?> read() async => _token;

  @override
  Future<DateTime?> readExpiry() async => _expiry;

  @override
  Future<void> write(String token, DateTime? expiresAt) async {
    _token = token;
    _expiry = expiresAt;
  }

  @override
  Future<void> clear() async {
    _token = null;
    _expiry = null;
  }
}

/// The staff sign-in endpoints.
///
/// Every call treats a 4xx as an answer, never a throw: the app's global API
/// checker force-logs-out the *device* on a thrown 401, and a wrong PIN or an
/// expired staff session must never cost the terminal its device login.
class PosStaffSessionRepo {
  final DioClient? dioClient;

  PosStaffSessionRepo({this.dioClient});

  static const String _base = '/api/v1/kiosk/manager/staff';
  static final Options _keepDevice =
      Options(validateStatus: (status) => status != null && status < 500);

  /// The lock screen's faces and the branch switch. Null when unreachable.
  Future<PosSignInRoster?> signInRoster() async {
    final DioClient? client = dioClient;
    if (client == null) return null;
    try {
      final Response response =
          await client.get('$_base/sign-in-roster', options: _keepDevice);
      final int status = response.statusCode ?? 0;
      // A kiosk is refused (403) -- which simply means no staff login here.
      if (status == 403) return PosSignInRoster.off;
      if (status >= 400) return null;
      return PosSignInRoster.fromJson(response.data);
    } catch (_) {
      return null;
    }
  }

  /// Returns the session and token, or the reason it failed.
  Future<(PosStaffSession?, String?, DateTime?, PosSignInResult)> signIn(
    String pin, {
    String? memberId,
    int? roleId,
  }) async {
    final DioClient? client = dioClient;
    if (client == null) {
      return (null, null, null, const PosSignInResult(PosSignInOutcome.unavailable));
    }
    try {
      final Response response = await client.post(
        '$_base/sign-in',
        data: {
          'pin': pin,
          if (memberId != null && memberId.isNotEmpty) 'member_id': memberId,
          // Optional: the role the operator tapped. Omitted entirely when null,
          // so the request is byte-for-byte the old one on a role-less sign-in.
          if (roleId != null) 'role': roleId,
        },
        options: _keepDevice,
      );
      final int status = response.statusCode ?? 0;
      final Object? data = response.data;

      if (status == 200 && data is Map) {
        final PosStaffSession? session = PosStaffSession.fromJson(data['staff']);
        final String? token = data['token']?.toString();
        if (session != null && token != null && token.isNotEmpty) {
          return (
            session,
            token,
            DateTime.tryParse('${data['expires_at']}'),
            const PosSignInResult(PosSignInOutcome.signedIn),
          );
        }
      }

      final Map<String, dynamic> error = _firstError(data);
      final String? message = error['message']?.toString();
      final int retry = int.tryParse('${error['retry_after_seconds']}') ?? 0;

      if (status == 429 || error['locked_out'] == true) {
        return (
          null,
          null,
          null,
          PosSignInResult(
            PosSignInOutcome.lockedOut,
            message: message,
            retryAfterSeconds: retry,
          ),
        );
      }

      if (status == 422) {
        return (
          null,
          null,
          null,
          PosSignInResult(
            PosSignInOutcome.wrongPin,
            message: message,
            attemptsRemaining: int.tryParse('${error['attempts_remaining']}') ?? 0,
          ),
        );
      }

      return (
        null,
        null,
        null,
        PosSignInResult(PosSignInOutcome.unavailable, message: message),
      );
    } catch (_) {
      return (null, null, null, const PosSignInResult(PosSignInOutcome.unavailable));
    }
  }

  /// Re-validates a stored token. Null means it no longer stands for anybody.
  Future<PosStaffSession?> me(String token) async {
    final DioClient? client = dioClient;
    if (client == null) return null;
    try {
      final Response response = await client.get(
        '$_base/me',
        options: _keepDevice.copyWith(headers: {'X-Staff-Token': token}),
      );
      if ((response.statusCode ?? 0) != 200) return null;
      final Object? data = response.data;
      return data is Map ? PosStaffSession.fromJson(data['staff']) : null;
    } catch (_) {
      return null;
    }
  }

  /// Tells the backend the current staff member signed out, which is what fires
  /// the Planday punch-out. The staff token is passed explicitly rather than
  /// left to the interceptor: the session is usually being torn down at the same
  /// moment, so by the time this request is actually sent `provider.token` may
  /// already be cleared. Fire-and-forget and error-swallowing -- logout must
  /// never wait for or fail because of this call.
  Future<void> signOut({String? staffToken}) async {
    final DioClient? client = dioClient;
    if (client == null) return;
    final Options options = (staffToken != null && staffToken.isNotEmpty)
        ? _keepDevice.copyWith(headers: {'X-Staff-Token': staffToken})
        : _keepDevice;
    try {
      await client.post('$_base/sign-out', options: options);
    } catch (_) {}
  }

  Map<String, dynamic> _firstError(Object? data) {
    if (data is Map && data['errors'] is List && (data['errors'] as List).isNotEmpty) {
      final Object? first = (data['errors'] as List).first;
      if (first is Map) return Map<String, dynamic>.from(first);
    }
    return const {};
  }
}
