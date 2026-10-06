import 'package:dio/dio.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/features/pos/domain/pos_attendance.dart';

/// What the attendance screen reads from. An interface so the provider can be
/// driven by a fake in tests without a Dio stack, and by [PosAttendanceRepo]
/// against the real device-authenticated endpoint in the app.
abstract class PosAttendanceSource {
  /// Returns the day's attendance, or null when the request itself failed
  /// (a transport error). The server's own empty states — Planday off, not
  /// linked, Planday unreachable — come back as a normal [PosAttendance] with
  /// its message set, never as null.
  Future<PosAttendance?> getAttendance({String? date, int? employeeId});
}

/// Device-authenticated attendance read. Branch scope and who may see whom are
/// decided entirely server-side from the device token and the signed-in staff
/// token; nothing here says which branch or widens who is visible. Read only —
/// there is no write method on this repo by design.
class PosAttendanceRepo implements PosAttendanceSource {
  final DioClient dioClient;

  PosAttendanceRepo({required this.dioClient});

  @override
  Future<PosAttendance?> getAttendance({String? date, int? employeeId}) async {
    try {
      final response = await dioClient.get(
        '/api/v1/kiosk/manager/attendance',
        queryParameters: {
          if (date != null && date.isNotEmpty) 'date': date,
          if (employeeId != null) 'employee_id': employeeId,
        },
        // Keep the device signed in on a 4xx: the server answers this endpoint's
        // empty states with 200, but a stray 4xx must still never trip the
        // global 401 logout the way an unguarded throw would.
        options:
            Options(validateStatus: (status) => status != null && status < 500),
      );

      if (response.statusCode != null && response.statusCode! >= 400) {
        return null;
      }

      return PosAttendance.fromJson(response.data);
    } catch (_) {
      // A transport failure is a null result; the screen offers a retry rather
      // than ever breaking the till.
      return null;
    }
  }
}
