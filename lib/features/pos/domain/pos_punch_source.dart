import 'package:dio/dio.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';

/// The outcome of a punch attempt, flattened for the screen.
///
/// The first four mirror the server's own `status`; the last three are decided
/// client-side from the HTTP status so the PIN card can tell a wrong PIN (shake
/// and retry) from a lockout (freeze) from a transport failure (retry later).
enum PosPunchStatus {
  ok,
  alreadyOpen,
  alreadyClosed,
  skipped,
  failed,
  invalidPin,
  lockedOut,
  unavailable,
}

/// A single punch result. Carries the server's own message so the screen never
/// has to second-guess the copy, plus the counters the PIN card shows.
class PosPunchResult {
  final PosPunchStatus status;

  /// 'in' or 'out' — echoed back so a result can be shown without the screen
  /// tracking which button was tapped.
  final String direction;

  /// A plain-language line to show the operator. Server-provided when it can be,
  /// a client fallback otherwise.
  final String message;

  final String? staffName;
  final int attemptsRemaining;
  final int retryAfterSeconds;

  const PosPunchResult(
    this.status, {
    this.direction = '',
    this.message = '',
    this.staffName,
    this.attemptsRemaining = 0,
    this.retryAfterSeconds = 0,
  });

  /// The PIN itself was rejected — the card should stay up, show the note, and
  /// let the operator try again (or wait, if locked out).
  bool get pinRejected =>
      status == PosPunchStatus.invalidPin || status == PosPunchStatus.lockedOut;

  /// Planday actually recorded (or already had) the punch.
  bool get recorded =>
      status == PosPunchStatus.ok ||
      status == PosPunchStatus.alreadyOpen ||
      status == PosPunchStatus.alreadyClosed;

  /// A hard failure to surface on the screen (the PIN was fine, Planday could
  /// not be reached). A skip is shown as "not recorded" too, but in its own
  /// colour, so it is not conflated with a server error.
  bool get isError => status == PosPunchStatus.failed;
}

/// What the Punch screen talks to. An interface so the screen can be driven by a
/// fake in tests without a Dio stack, and by [PosPunchRepo] against the real
/// device-authenticated endpoints in the app.
abstract class PosPunchSource {
  Future<PosPunchResult> punch({required String direction, required String pin});
}

/// Device-authenticated punch in / out.
///
/// Reuses the existing PIN validation and the existing Planday punch service on
/// the server (no new punch logic). PIN-gated, not session-gated: whoever types
/// their own PIN is punched, independent of who is signed in at the till. A 4xx
/// is treated as an answer, never a throw, so a wrong PIN or a lockout never
/// trips the global 401-logout the way an unguarded throw would.
class PosPunchRepo implements PosPunchSource {
  final DioClient? dioClient;

  const PosPunchRepo({this.dioClient});

  static const String _base = '/api/v1/kiosk/manager/staff';
  static final Options _keepDevice =
      Options(validateStatus: (status) => status != null && status < 500);

  @override
  Future<PosPunchResult> punch({
    required String direction,
    required String pin,
  }) async {
    final DioClient? client = dioClient;
    if (client == null) {
      return PosPunchResult(PosPunchStatus.unavailable, direction: direction);
    }

    final String path =
        direction == 'out' ? '$_base/punch-out' : '$_base/punch-in';

    try {
      final Response response = await client.post(
        path,
        data: {'pin': pin},
        options: _keepDevice,
      );
      final int status = response.statusCode ?? 0;
      final Object? data = response.data;

      if (status == 200 && data is Map) {
        return PosPunchResult(
          _statusFromServer('${data['status']}'),
          direction: '${data['direction'] ?? direction}',
          message: '${data['message'] ?? ''}',
          staffName: (data['staff'] is Map)
              ? data['staff']['name']?.toString()
              : null,
        );
      }

      final Map<String, dynamic> error = _firstError(data);
      final String message = error['message']?.toString() ?? '';
      final int retry = int.tryParse('${error['retry_after_seconds']}') ?? 0;

      if (status == 429 || error['locked_out'] == true) {
        return PosPunchResult(
          PosPunchStatus.lockedOut,
          direction: direction,
          message: message,
          retryAfterSeconds: retry,
        );
      }
      if (status == 422) {
        return PosPunchResult(
          PosPunchStatus.invalidPin,
          direction: direction,
          message: message,
          attemptsRemaining:
              int.tryParse('${error['attempts_remaining']}') ?? 0,
        );
      }

      return PosPunchResult(
        PosPunchStatus.unavailable,
        direction: direction,
        message: message,
      );
    } catch (_) {
      return PosPunchResult(PosPunchStatus.unavailable, direction: direction);
    }
  }

  PosPunchStatus _statusFromServer(String status) {
    switch (status) {
      case 'ok':
        return PosPunchStatus.ok;
      case 'already_open':
        return PosPunchStatus.alreadyOpen;
      case 'already_closed':
        return PosPunchStatus.alreadyClosed;
      case 'skipped':
        return PosPunchStatus.skipped;
      default:
        return PosPunchStatus.failed;
    }
  }

  Map<String, dynamic> _firstError(Object? data) {
    if (data is Map &&
        data['errors'] is List &&
        (data['errors'] as List).isNotEmpty) {
      final Object? first = (data['errors'] as List).first;
      if (first is Map) return Map<String, dynamic>.from(first);
    }
    return <String, dynamic>{};
  }
}
