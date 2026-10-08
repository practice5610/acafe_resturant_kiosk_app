import 'package:acafe_customer/features/pos/domain/pos_attendance.dart';
import 'package:acafe_customer/features/pos/domain/pos_attendance_source.dart';
import 'package:acafe_customer/features/pos/providers/pos_attendance_provider.dart';
import 'package:acafe_customer/features/pos/screens/pos_attendance_screen.dart';
import 'package:acafe_customer/features/pos/widgets/pos_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A stand-in for the attendance API. Returns whatever the test hands it and
/// records the date/employee it was asked for, so the date nav and the employee
/// filter can be checked without a real backend.
class _FakeAttendanceSource implements PosAttendanceSource {
  _FakeAttendanceSource(this._result);

  PosAttendance? _result;
  String? lastDate;
  int? lastEmployeeId;
  int calls = 0;

  void setResult(PosAttendance? result) => _result = result;

  @override
  Future<PosAttendance?> getAttendance({String? date, int? employeeId}) async {
    calls++;
    lastDate = date;
    lastEmployeeId = employeeId;
    return _result;
  }
}

PosAttendance _attendance({
  String scope = 'manager',
  bool plandayEnabled = true,
  bool reachable = true,
  bool linked = true,
  String? message,
  List<PosAttendanceEmployee> employees = const [],
  List<PosAttendanceRow> rows = const [],
}) {
  return PosAttendance(
    date: '2026-10-06',
    plandayEnabled: plandayEnabled,
    reachable: reachable,
    scope: scope,
    linked: linked,
    message: message,
    employees: employees,
    rows: rows,
  );
}

PosAttendanceRow _row(int id, String name, {String? role, String? clockOut = '17:00', bool isOpen = false, String? workedLabel = '8h 0m', int? workedMinutes = 480, String status = 'done'}) {
  return PosAttendanceRow(
    plandayEmployeeId: id,
    name: name,
    role: role,
    clockIn: '09:00',
    clockOut: clockOut,
    scheduledStart: null,
    scheduledEnd: null,
    workedLabel: workedLabel,
    workedMinutes: workedMinutes,
    isOpen: isOpen,
    status: status,
  );
}

Future<void> _pump(WidgetTester tester, PosAttendanceProvider provider) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ChangeNotifierProvider<PosAttendanceProvider>.value(
        value: provider,
        child: const Scaffold(body: PosAttendanceScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('manager view lists every staff member and offers the filter',
      (tester) async {
    final source = _FakeAttendanceSource(_attendance(
      scope: 'manager',
      employees: const [
        PosAttendanceEmployee(plandayEmployeeId: 111, name: 'Mary Manager'),
        PosAttendanceEmployee(plandayEmployeeId: 222, name: 'John Employee'),
      ],
      rows: [
        _row(111, 'Mary Manager', role: 'Branch Manager'),
        _row(222, 'John Employee', role: 'Employee'),
      ],
    ));
    final provider = PosAttendanceProvider(source: source);
    await provider.load();

    await _pump(tester, provider);

    expect(find.text('Mary Manager'), findsOneWidget);
    expect(find.text('John Employee'), findsOneWidget);
    // A manager with linked staff gets the per-employee filter.
    expect(find.byKey(const Key('pos-attendance-employee-filter')), findsOneWidget);
  });

  testWidgets('staff filter opens below the field and filters by employee',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final source = _FakeAttendanceSource(_attendance(
      scope: 'manager',
      employees: const [
        PosAttendanceEmployee(plandayEmployeeId: 111, name: 'Mary Manager'),
        PosAttendanceEmployee(plandayEmployeeId: 222, name: 'John Employee'),
      ],
      rows: [
        _row(111, 'Mary Manager', role: 'Branch Manager'),
        _row(222, 'John Employee', role: 'Employee'),
      ],
    ));
    final provider = PosAttendanceProvider(source: source);
    await provider.load();
    await _pump(tester, provider);

    final filter = find.byKey(const Key('pos-attendance-employee-filter'));
    final Rect field = tester.getRect(filter);
    await tester.tap(filter);
    await tester.pumpAndSettle();

    // The bug: Material's DropdownButton painted its menu over the field.
    final Rect menu = tester.getRect(find.byKey(PosDropdown.menuKey));
    expect(menu.top, greaterThanOrEqualTo(field.bottom));
    expect(menu.overlaps(field), isFalse);

    await tester.tap(find.byKey(PosDropdown.itemKey(2)));
    await tester.pumpAndSettle();
    expect(provider.employeeFilter, 222);
    expect(source.lastEmployeeId, 222);
    expect(find.byKey(PosDropdown.menuKey), findsNothing);
  });

  testWidgets('employee view shows only their own row and no filter',
      (tester) async {
    final source = _FakeAttendanceSource(_attendance(
      scope: 'self',
      employees: const [],
      rows: [_row(222, 'John Employee', role: 'Employee')],
    ));
    final provider = PosAttendanceProvider(source: source);
    await provider.load();

    await _pump(tester, provider);

    expect(find.text('John Employee'), findsOneWidget);
    expect(find.text('Mary Manager'), findsNothing);
    // No branch-wide filter for someone who can only see themselves.
    expect(find.byKey(const Key('pos-attendance-employee-filter')), findsNothing);
  });

  testWidgets('an open shift reads "still in" instead of hours', (tester) async {
    final source = _FakeAttendanceSource(_attendance(
      scope: 'self',
      rows: [
        _row(222, 'John Employee',
            clockOut: null, isOpen: true, workedLabel: null, workedMinutes: null, status: 'active'),
      ],
    ));
    final provider = PosAttendanceProvider(source: source);
    await provider.load();

    await _pump(tester, provider);

    expect(find.textContaining('Still in'), findsOneWidget);
  });

  testWidgets('an empty day shows a friendly message, not a blank list',
      (tester) async {
    final source = _FakeAttendanceSource(_attendance(rows: const []));
    final provider = PosAttendanceProvider(source: source);
    await provider.load();

    await _pump(tester, provider);

    expect(find.textContaining('No attendance'), findsOneWidget);
  });

  testWidgets('a disabled branch shows the server message', (tester) async {
    final source = _FakeAttendanceSource(_attendance(
      plandayEnabled: false,
      linked: false,
      rows: const [],
      message: 'Planday is not enabled for this branch',
    ));
    final provider = PosAttendanceProvider(source: source);
    await provider.load();

    await _pump(tester, provider);

    expect(find.textContaining('Planday is not enabled'), findsOneWidget);
  });

  testWidgets('a transport failure shows a retry', (tester) async {
    final source = _FakeAttendanceSource(null); // null = request failed
    final provider = PosAttendanceProvider(source: source);
    await provider.load();

    await _pump(tester, provider);

    expect(find.byKey(const Key('pos-attendance-retry')), findsOneWidget);
  });

  test('rows are grouped under one heading per employee', () {
    final att = _attendance(rows: [
      _row(111, 'Mary Manager', role: 'Branch Manager'),
      _row(111, 'Mary Manager', role: 'Branch Manager', clockOut: null, isOpen: true, workedLabel: null, workedMinutes: null, status: 'active'),
      _row(222, 'John Employee', role: 'Employee', workedMinutes: 60),
    ]);

    final groups = att.groups;

    expect(groups.length, 2);
    expect(groups.first.name, 'Mary Manager');
    expect(groups.first.shiftCount, 2);
    expect(groups.first.hasOpenShift, isTrue);
    expect(groups.first.totalMinutes, 480); // open shift contributes nothing
    expect(groups[1].name, 'John Employee');
    expect(groups[1].shiftCount, 1);
  });

  testWidgets('an employee with several punches shows their name once',
      (tester) async {
    final source = _FakeAttendanceSource(_attendance(
      scope: 'self',
      rows: [
        _row(222, 'John Employee', role: 'Employee'),
        _row(222, 'John Employee', role: 'Employee'),
        _row(222, 'John Employee', role: 'Employee',
            clockOut: null, isOpen: true, workedLabel: null, workedMinutes: null, status: 'active'),
      ],
    ));
    final provider = PosAttendanceProvider(source: source);
    await provider.load();

    await _pump(tester, provider);

    // Grouped like Planday: the name heads the group once, not once per row.
    expect(find.text('John Employee'), findsOneWidget);
    // All three punches are still shown beneath it.
    expect(find.textContaining('Still in'), findsOneWidget);
  });

  test('prev/next/today move the requested date', () async {
    final source = _FakeAttendanceSource(_attendance());
    final provider = PosAttendanceProvider(
      source: source,
      clock: () => DateTime(2026, 10, 6),
    );

    await provider.load();
    expect(source.lastDate, '2026-10-06');

    await provider.prevDay();
    expect(source.lastDate, '2026-10-05');

    await provider.nextDay();
    expect(source.lastDate, '2026-10-06');

    await provider.prevDay();
    await provider.today();
    expect(source.lastDate, '2026-10-06');
  });

  test('setting an employee filter re-requests with that id', () async {
    final source = _FakeAttendanceSource(_attendance());
    final provider = PosAttendanceProvider(source: source);

    await provider.load();
    expect(source.lastEmployeeId, isNull);

    await provider.setEmployeeFilter(222);
    expect(source.lastEmployeeId, 222);

    await provider.setEmployeeFilter(null);
    expect(source.lastEmployeeId, isNull);
  });
}
