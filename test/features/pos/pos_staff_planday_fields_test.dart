import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:acafe_customer/features/pos/domain/pos_staff.dart';
import 'package:acafe_customer/features/pos/domain/pos_staff_repo.dart';
import 'package:acafe_customer/features/pos/providers/pos_staff_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_pos_staff_backend.dart';

/// When a branch is on Planday, the till's add-staff flow collects the fields
/// Planday needs to create an employee: surname, email and gender.
late FakePosStaffBackend backend;

Future<PosStaffProvider> _provider({required bool planday}) async {
  backend = FakePosStaffBackend(plandayEnabled: planday);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final Dio dio = Dio(BaseOptions(baseUrl: 'http://localhost'))
    ..httpClientAdapter = backend;
  final client = DioClient('http://localhost', dio,
      loggingInterceptor: LoggingInterceptor(), sharedPreferences: prefs);
  final provider =
      PosStaffProvider(repo: PosStaffRepo(sharedPreferences: prefs, dioClient: client));
  await provider.hydrate();
  return provider;
}

Map<String, dynamic> _lastCreateBody() {
  final req = backend.requests.lastWhere(
    (r) => r.method == 'POST' && r.path.endsWith('/staff/members'),
  );
  return Map<String, dynamic>.from(req.data as Map);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('catalogue carries the Planday flag', () {
    test('planday_enabled is parsed from the branch block', () async {
      final on = await _provider(planday: true);
      expect(on.catalogue.plandayEnabled, isTrue);

      final off = await _provider(planday: false);
      expect(off.catalogue.plandayEnabled, isFalse);
    });

    test('department + group option lists are parsed when enabled', () async {
      final on = await _provider(planday: true);
      expect(on.catalogue.plandayDepartments.map((d) => d.id), contains(18361));
      expect(on.catalogue.plandayEmployeeGroups.map((g) => g.name), contains('Bar Team'));
      // The dropdown options lead with a "— not set —" row.
      expect(on.catalogue.plandayDepartmentOptions.first.value, '');
      expect(on.catalogue.plandayEmployeeGroupOptions.first.value, '');
    });

    test('department + group lists are empty on a non-Planday branch', () async {
      final off = await _provider(planday: false);
      expect(off.catalogue.plandayDepartments, isEmpty);
      expect(off.catalogue.plandayEmployeeGroups, isEmpty);
    });
  });

  group('add-staff on a Planday branch', () {
    test('the surname, email and gender are sent to the server', () async {
      final provider = await _provider(planday: true);

      final String? id = await provider.addMember(
        name: 'Sanne',
        surname: 'Bakker',
        email: 'sanne@acafe.test',
        gender: 'Female',
        role: 'Employee',
        shiftIds: const ['morning'],
      );

      expect(id, isNotNull);
      final body = _lastCreateBody();
      expect(body['name'], 'Sanne');
      expect(body['surname'], 'Bakker');
      expect(body['email'], 'sanne@acafe.test');
      expect(body['gender'], 'Female');
    });

    test('the chosen department + group are sent to the server', () async {
      final provider = await _provider(planday: true);

      final String? id = await provider.addMember(
        name: 'Sanne',
        surname: 'Bakker',
        email: 'sanne@acafe.test',
        gender: 'Female',
        plandayDepartmentId: 18361,
        plandayGroupId: 31203,
        role: 'Employee',
        shiftIds: const ['morning'],
      );

      expect(id, isNotNull);
      final body = _lastCreateBody();
      expect(body['planday_department_id'], 18361);
      expect(body['planday_employee_group_id'], 31203);
    });

    test('leaving department + group blank sends neither', () async {
      final provider = await _provider(planday: true);

      await provider.addMember(
        name: 'Sanne',
        surname: 'Bakker',
        email: 'sanne@acafe.test',
        gender: 'Female',
        role: 'Employee',
        shiftIds: const ['morning'],
      );

      final body = _lastCreateBody();
      expect(body.containsKey('planday_department_id'), isFalse);
      expect(body.containsKey('planday_employee_group_id'), isFalse);
    });

    test('a missing surname/email/gender is refused before any request',
        () async {
      final provider = await _provider(planday: true);
      backend.requests.clear();

      final String? id = await provider.addMember(
        name: 'Sanne',
        role: 'Employee',
        shiftIds: const ['morning'],
      );

      expect(id, isNull);
      expect(provider.errors['newPlanday'], isNotNull);
      expect(
        backend.requests.any(
            (r) => r.method == 'POST' && r.path.endsWith('/staff/members')),
        isFalse,
        reason: 'nothing is sent when the Planday fields are missing',
      );
    });

    test('an invalid email is refused', () async {
      final provider = await _provider(planday: true);

      final String? id = await provider.addMember(
        name: 'Sanne',
        surname: 'Bakker',
        email: 'not-an-email',
        gender: 'Female',
        role: 'Employee',
        shiftIds: const ['morning'],
      );

      expect(id, isNull);
      expect(provider.errors['newPlanday'], contains('email'));
    });
  });

  group('add-staff on a non-Planday branch is unchanged', () {
    test('name + role alone still works, no new fields required', () async {
      final provider = await _provider(planday: false);

      final String? id = await provider.addMember(
        name: 'Tom Visser',
        role: 'Employee',
        shiftIds: const ['morning'],
      );

      expect(id, isNotNull);
      final body = _lastCreateBody();
      expect(body.containsKey('surname'), isFalse);
      expect(body.containsKey('gender'), isFalse);
    });
  });

  group('member model parses the Planday identity fields', () {
    test('first_name / surname / email / gender round-trip', () {
      final m = PosStaffMember.fromJson(const {
        'id': 'jan',
        'name': 'Jan Jansen',
        'first_name': 'Jan',
        'surname': 'Jansen',
        'email': 'jan@acafe.test',
        'gender': 'Male',
        'role': 'Employee',
        'role_id': 2,
        'active': true,
        'permissions': {},
      });

      expect(m, isNotNull);
      expect(m!.firstName, 'Jan');
      expect(m.surname, 'Jansen');
      expect(m.email, 'jan@acafe.test');
      expect(m.gender, 'Male');
    });

    test('planday department + group round-trip', () {
      final m = PosStaffMember.fromJson(const {
        'id': 'jan',
        'name': 'Jan Jansen',
        'role': 'Employee',
        'active': true,
        'permissions': {},
        'planday_department_id': 18361,
        'planday_employee_group_id': 31203,
      });

      expect(m!.plandayDepartmentId, 18361);
      expect(m.plandayGroupId, 31203);
    });

    test('absent fields stay null', () {
      final m = PosStaffMember.fromJson(const {
        'id': 'kim',
        'name': 'Kim',
        'role': 'Employee',
        'active': true,
        'permissions': {},
      });
      expect(m!.surname, isNull);
      expect(m.gender, isNull);
    });
  });
}
