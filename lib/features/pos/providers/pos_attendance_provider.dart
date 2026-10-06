import 'package:acafe_customer/features/pos/domain/pos_attendance.dart';
import 'package:acafe_customer/features/pos/domain/pos_attendance_source.dart';
import 'package:flutter/foundation.dart';

/// State for the POS Attendance tab: the selected day, an optional employee
/// filter (managers only), and the last payload the server returned.
///
/// The provider never decides who may see whom — it just asks the server for a
/// date (and, when a manager picks one, an employee) and shows what comes back.
/// A null payload means the request failed; every other "empty" case is a real
/// payload carrying the server's own message.
class PosAttendanceProvider extends ChangeNotifier {
  final PosAttendanceSource source;
  final DateTime Function() _clock;

  PosAttendanceProvider({
    required this.source,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    _date = _dateOnly(_clock());
  }

  late DateTime _date;
  int? _employeeFilter;
  PosAttendance? _model;
  bool _loading = false;
  bool _loadFailed = false;

  DateTime get date => _date;
  int? get employeeFilter => _employeeFilter;
  PosAttendance? get model => _model;
  bool get isLoading => _loading;

  /// True when the last request failed at the transport level (null payload),
  /// so the screen can offer a retry rather than a misleading empty state.
  bool get loadFailed => _loadFailed;

  bool get isToday => _sameDay(_date, _clock());

  Future<void> load() async {
    _loading = true;
    _loadFailed = false;
    notifyListeners();

    final PosAttendance? result = await source.getAttendance(
      date: _dateString(_date),
      employeeId: _employeeFilter,
    );

    _model = result;
    _loadFailed = result == null;
    _loading = false;
    notifyListeners();
  }

  Future<void> setDate(DateTime date) async {
    _date = _dateOnly(date);
    await load();
  }

  Future<void> prevDay() => setDate(_date.subtract(const Duration(days: 1)));

  Future<void> nextDay() => setDate(_date.add(const Duration(days: 1)));

  Future<void> today() => setDate(_clock());

  /// Narrow to one employee (managers only), or clear with null.
  Future<void> setEmployeeFilter(int? plandayEmployeeId) async {
    if (_employeeFilter == plandayEmployeeId) return;
    _employeeFilter = plandayEmployeeId;
    await load();
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Plain YYYY-MM-DD, built by hand so no timezone ever enters it.
  static String _dateString(DateTime d) {
    final String m = d.month.toString().padLeft(2, '0');
    final String day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }
}
