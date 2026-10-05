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
