import 'dart:convert';

import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:acafe_customer/features/pos/domain/pos_staff.dart';
import 'package:acafe_customer/features/pos/domain/pos_staff_repo.dart';
import 'package:acafe_customer/features/pos/providers/pos_staff_provider.dart';
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_pos_staff_backend.dart';

/// PosStaffProvider against a fake that honours the real staff API.
///
/// Before the unified staff work this provider wrote locally first and synced a
/// whole-roster PUT behind it. Now the server mints roster ids, owns PIN
/// uniqueness, and receives one PATCH per change, so these tests talk to
/// something that answers like the server.
late FakePosStaffBackend backend;

Future<PosStaffProvider> _provider({FakePosStaffBackend? using}) async {
  backend = using ?? FakePosStaffBackend();
  final prefs = await SharedPreferences.getInstance();
  final Dio dio = Dio(BaseOptions(baseUrl: 'http://localhost'))
    ..httpClientAdapter = backend;
  final client = DioClient(
    'http://localhost',
    dio,
    loggingInterceptor: LoggingInterceptor(),
    sharedPreferences: prefs,
  );
  final provider = PosStaffProvider(
    repo: PosStaffRepo(sharedPreferences: prefs, dioClient: client),
  );
  await provider.hydrate();
  return provider;
}

Future<PosStaffProvider> _offlineProvider() async {
  final prefs = await SharedPreferences.getInstance();
  final provider =
      PosStaffProvider(repo: PosStaffRepo(sharedPreferences: prefs));
  await provider.hydrate();
  return provider;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('catalogue', () {
    test('permissions, roles and shifts all come from the branch', () async {
      final provider = await _provider();

      expect(provider.permissionKeys, [
        for (final p in FakePosStaffBackend.permissions) p['key'] as String,
      ]);
      expect(provider.permissionLabel('close_day'), 'Close day');
      expect(provider.catalogue.roleOptions.map((o) => o.value),
          ['Owner', 'Manager', 'Employee']);
      expect(provider.shifts.map((s) => s.id),
          ['morning', 'afternoon', 'evening']);
      expect(provider.branchName, 'Amsterdam');
      expect(provider.pinLength, 4);
    });

    test('offline with no cache, nothing is invented', () async {
      final provider = await _offlineProvider();

      // The old build fell back to a hardcoded trio of roles and seven
      // permissions. Now there is simply nothing until the branch says so.
      expect(provider.permissionKeys, isEmpty);
      expect(provider.catalogue.roles, isEmpty);
      expect(provider.members, isEmpty);
    });

    test('offline with a cache, the last known catalogue is used', () async {
      await _provider();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppConstants.posStaffCatalogueKey), isNotNull);

      final offline = await _offlineProvider();
      expect(offline.permissionKeys, isNotEmpty);
      expect(offline.members, isNotEmpty);
    });
  });

  group('roster', () {
    test('matches the Figma shift counts', () async {
      final provider = await _provider();
      expect(provider.membersOf('morning').length, 12);
      expect(provider.membersOf('afternoon').length, 11);
      expect(provider.membersOf('evening').length, 13);
    });

    test('every shift id resolves to a real member', () async {
      final provider = await _provider();
      for (final shift in provider.shifts) {
        for (final id in shift.memberIds) {
          expect(provider.roster.memberById(id), isNotNull,
              reason: '$id on ${shift.id}');
        }
      }
    });

    test('survives a JSON round trip', () async {
      final roster = (await _provider()).roster;
      final decoded =
          PosStaffRoster.fromJson(jsonDecode(jsonEncode(roster.toJson())));
      expect(decoded, isNotNull);
      expect(decoded!.members.length, roster.members.length);
      expect(decoded.membersOf('evening').length,
          roster.membersOf('evening').length);
    });

    test('permissions are keyed by stable key, never by label', () async {
      final provider = await _provider();
      final keys = provider.members.first.permissions.keys;
      expect(keys, contains('process_refunds'));
      expect(keys, isNot(contains('Process refunds')));
    });
  });

  group('hiring', () {
    test('adding a member rosters them onto the chosen shifts', () async {
      final provider = await _provider();
      final int morningBefore = provider.membersOf('morning').length;
      final int eveningBefore = provider.membersOf('evening').length;

      final String? id = await provider.addMember(
        name: 'Sanne Bakker',
        role: 'Employee',
        shiftIds: const ['morning', 'evening'],
      );

      // The server mints the id.
      expect(id, 'sanne-bakker');
      expect(provider.selectedId, id);
      expect(provider.membersOf('morning').length, morningBefore + 1);
      expect(provider.membersOf('evening').length, eveningBefore + 1);
      expect(provider.shiftsOf(id!), ['morning', 'evening']);
      // The role's grant, as the server applies it.
      expect(provider.selected!.permissions['apply_discounts'], isTrue);
      expect(provider.selected!.permissions['close_day'], isFalse);
      expect(provider.selected!.hasPin, isFalse);
    });

    test('an optional PIN is sent and recorded, never kept on the device',
        () async {
      final provider = await _provider();

      await provider.addMember(name: 'Tom', role: 'Employee', pin: '4321');

      expect(provider.selected!.hasPin, isTrue);
      final prefs = await SharedPreferences.getInstance();
      final String cached = prefs.getString(AppConstants.posStaffRosterKey)!;
      expect(cached, isNot(contains('4321')), reason: 'no PIN in the cache');
    });

    test('a blank name is rejected and nothing is sent', () async {
      final provider = await _provider();
      final int before = provider.members.length;
      backend.requests.clear();

      expect(await provider.addMember(name: '   ', role: 'Employee'), isNull);
      expect(provider.members.length, before);
      expect(provider.errors['newName'], isNotNull);
      expect(backend.requests.where((r) => r.method == 'POST'), isEmpty);
    });

    test('a malformed PIN is rejected before anything is sent', () async {
      final provider = await _provider();
      backend.requests.clear();

      expect(await provider.addMember(name: 'Tom', role: 'Employee', pin: '12'),
          isNull);
      expect(provider.errors['newPin'], isNotNull);
      expect(backend.requests.where((r) => r.method == 'POST'), isEmpty);
    });

    test('a role the branch does not offer is refused', () async {
      final provider = await _provider();

      expect(await provider.addMember(name: 'Tom', role: 'Supreme Leader'),
          isNull);
      expect(provider.errors['newRole'], isNotNull);
    });

    test('duplicate names get distinct ids from the server', () async {
      final provider = await _provider();
      final String? first =
          await provider.addMember(name: 'Jan Jansen', role: 'Employee');
      final String? second =
          await provider.addMember(name: 'Jan Jansen', role: 'Employee');
      expect(first, 'jan-jansen');
      expect(second, isNot(first));
    });
  });

  group('member details', () {
    test('a permission toggle is one PATCH for that member only', () async {
      final provider = await _provider();
      provider.select('sophie');
      backend.requests.clear();

      provider.setPermission('process_refunds', true);
      await pumpEventQueue();

      final writes = backend.requests.where((r) => r.method != 'GET').toList();
      expect(writes.length, 1);
      expect(writes.single.method, 'PATCH');
      expect(writes.single.path, endsWith('/staff/members/sophie'));
      expect(backend.member('sophie')!['permissions']['process_refunds'], isTrue);
      expect(provider.selected!.permissions['process_refunds'], isTrue);
    });

    test('a key the branch did not serve is ignored', () async {
      final provider = await _provider();
      provider.select('sophie');
      backend.requests.clear();

      provider.setPermission('launch_rockets', true);

      expect(backend.requests, isEmpty);
      expect(provider.selected!.permissions.containsKey('launch_rockets'),
          isFalse);
    });

    test('a role change sends the role id', () async {
      final provider = await _provider();
      provider.select('sophie');

      provider.setRole('Manager');
      await pumpEventQueue();

      expect(provider.selected!.role, 'Manager');
      expect(backend.member('sophie')!['role'], 'Manager');
    });

    test('a name edit is held while invalid and sent once valid', () async {
      final provider = await _provider();
      provider.select('sophie');
      backend.requests.clear();

      provider.setName('');
      expect(provider.errors['name'], isNotNull);
      expect(backend.requests, isEmpty);

      provider.setName('Sophie de Wit');
      await pumpEventQueue();
      expect(provider.errors['name'], isNull);
      expect(backend.member('sophie')!['name'], 'Sophie de Wit');
    });

    test('setting a PIN marks the member as having one', () async {
      final provider = await _provider();
      provider.select('sophie');

      expect(await provider.setPin('1234'), isNull);
      expect(provider.selected!.hasPin, isTrue);
    });

    test('a PIN in use elsewhere returns the server message', () async {
      final provider = await _provider();
      backend.setPin('thomas', '1234');
      provider.select('sophie');

      final String? error = await provider.setPin('1234');

      expect(error, 'Another staff member in this branch already uses that PIN.');
      expect(provider.selected!.hasPin, isFalse);
    });

    test('removing a member takes them off every shift', () async {
      final provider = await _provider();
      expect(provider.membersOf('morning').map((m) => m.id), contains('sophie'));

      await provider.removeMember('sophie');

      expect(provider.roster.memberById('sophie'), isNull);
      for (final shift in provider.shifts) {
        expect(shift.memberIds, isNot(contains('sophie')));
      }
    });
  });

  group('shifts', () {
    test('moving someone onto a shift is written to that member', () async {
      final provider = await _provider();
      expect(provider.shiftsOf('eva'), ['morning']);

      provider.toggleShift('evening', 'eva');
      await pumpEventQueue();

      expect(provider.shiftsOf('eva'), ['morning', 'evening']);
      expect(backend.member('eva')!['shift_ids'], ['morning', 'evening']);
    });
  });

  group('model', () {
    test('fromJson reads the new fields and never a passcode', () {
      final member = PosStaffMember.fromJson({
        'id': 'sara',
        'name': 'Sara de Vries',
        'role': 'Employee',
        'role_id': 16,
        'active': true,
        'has_pin': true,
        'permissions': {'apply_discounts': true},
        'shift_ids': ['morning'],
        'passcode': '1234',
      })!;

      expect(member.roleId, 16);
      expect(member.hasPin, isTrue);
      expect(member.shiftIds, ['morning']);
      expect(member.initials, 'SV');
      expect(jsonEncode(member.toJson()), isNot(contains('1234')));
    });

    test('PIN validation', () {
      expect(PosStaffValidation.pin('', length: 4), isNull);
      expect(PosStaffValidation.pin('', length: 4, required: true), isNotNull);
      expect(PosStaffValidation.pin('12a4', length: 4), isNotNull);
      expect(PosStaffValidation.pin('12345', length: 4), isNotNull);
      expect(PosStaffValidation.pin('1234', length: 4), isNull);
    });
  });
}
