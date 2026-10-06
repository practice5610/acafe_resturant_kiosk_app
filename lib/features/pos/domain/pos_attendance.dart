/// POS Attendance: a day's punch-clock records for the till's branch, read from
/// Planday through the backend. Nothing here is authoritative — the server
/// decides scope (a manager sees the whole branch, anyone else only themselves)
/// and already filters the rows; this is only what the screen renders.
///
/// Times are the naive Amsterdam wall-clock Planday reports ("09:00"), passed
/// through as plain strings. They are never parsed into a local [DateTime],
/// because doing so would re-interpret them in the device's own zone — the one
/// mistake this feature exists to avoid.
class PosAttendance {
  final String date;
  final bool plandayEnabled;
  final bool reachable;

  /// 'manager' (sees the whole branch) or 'self' (only their own punches).
  final String scope;

  /// Whether there is anybody to show: false when the branch is off, or the
  /// viewer is not linked to Planday, or nobody is signed in.
  final bool linked;

  /// A friendly explanation for an empty payload, straight from the server.
  final String? message;

  /// The branch roster a manager may filter by. Empty in self scope.
  final List<PosAttendanceEmployee> employees;

  final List<PosAttendanceRow> rows;

  const PosAttendance({
    required this.date,
    required this.plandayEnabled,
    required this.reachable,
    required this.scope,
    required this.linked,
    required this.message,
    required this.employees,
    required this.rows,
  });

  bool get isManager => scope == 'manager';

  static PosAttendance? fromJson(Object? json) {
    if (json is! Map) return null;

    final Object? rawRows = json['rows'];
    final Object? rawEmployees = json['employees'];

    return PosAttendance(
      date: (json['date'] ?? '').toString(),
      plandayEnabled: json['planday_enabled'] == true,
      reachable: json['reachable'] == true,
      scope: (json['scope'] ?? 'self').toString(),
      linked: json['linked'] == true,
      message: json['message']?.toString(),
      employees: rawEmployees is List
          ? [
              for (final e in rawEmployees)
                if (PosAttendanceEmployee.fromJson(e) != null)
                  PosAttendanceEmployee.fromJson(e)!,
            ]
          : const [],
      rows: rawRows is List
          ? [
              for (final r in rawRows)
                if (PosAttendanceRow.fromJson(r) != null)
                  PosAttendanceRow.fromJson(r)!,
            ]
          : const [],
    );
  }
}

/// One staff member in the manager's filter.
class PosAttendanceEmployee {
  final int plandayEmployeeId;
  final String name;

  const PosAttendanceEmployee({
    required this.plandayEmployeeId,
    required this.name,
  });

  static PosAttendanceEmployee? fromJson(Object? json) {
    if (json is! Map) return null;
    final int? id = int.tryParse('${json['planday_employee_id']}');
    final String name = (json['name'] ?? '').toString();
    if (id == null || name.isEmpty) return null;
    return PosAttendanceEmployee(plandayEmployeeId: id, name: name);
  }
}

/// One punch-clock entry as a row on the screen.
class PosAttendanceRow {
  final int plandayEmployeeId;
  final String name;
  final String? role;

  /// Wall-clock "HH:MM" strings, exactly as Planday sent them. Null clockOut
  /// means the shift is still open.
  final String? clockIn;
  final String? clockOut;
  final String? scheduledStart;
  final String? scheduledEnd;

  /// "8h 30m" / "45m", or null while the shift is open.
  final String? workedLabel;
  final int? workedMinutes;

  final bool isOpen;

  /// 'active' (still in), 'approved', or 'done'.
  final String status;

  const PosAttendanceRow({
    required this.plandayEmployeeId,
    required this.name,
    required this.role,
    required this.clockIn,
    required this.clockOut,
    required this.scheduledStart,
    required this.scheduledEnd,
    required this.workedLabel,
    required this.workedMinutes,
    required this.isOpen,
    required this.status,
  });

  bool get hasSchedule =>
      (scheduledStart != null && scheduledStart!.isNotEmpty) ||
      (scheduledEnd != null && scheduledEnd!.isNotEmpty);

  static PosAttendanceRow? fromJson(Object? json) {
    if (json is! Map) return null;
    final String name = (json['name'] ?? '').toString();
    return PosAttendanceRow(
      plandayEmployeeId: int.tryParse('${json['planday_employee_id']}') ?? 0,
      name: name,
      role: json['role']?.toString(),
      clockIn: _str(json['clock_in']),
      clockOut: _str(json['clock_out']),
      scheduledStart: _str(json['scheduled_start']),
      scheduledEnd: _str(json['scheduled_end']),
      workedLabel: _str(json['worked_label']),
      workedMinutes: json['worked_minutes'] == null
          ? null
          : int.tryParse('${json['worked_minutes']}'),
      isOpen: json['is_open'] == true,
      status: (json['status'] ?? 'done').toString(),
    );
  }

  static String? _str(Object? value) {
    if (value == null) return null;
    final String s = value.toString();
    return s.isEmpty ? null : s;
  }
}
