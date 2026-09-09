import 'dart:convert';

import 'package:acafe_customer/features/pos/domain/pos_staff.dart';
import 'package:acafe_customer/features/pos/domain/pos_staff_repo.dart';
import 'package:acafe_customer/features/pos/providers/pos_staff_provider.dart';
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<PosStaffProvider> _provider() async {
  final prefs = await SharedPreferences.getInstance();
  final provider = PosStaffProvider(repo: PosStaffRepo(sharedPreferences: prefs))
    ..hydrate();
  return provider;
}

Future<Map<String, dynamic>?> _stored() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  final String? raw = prefs.getString(AppConstants.posStaffRosterKey);
  if (raw == null) return null;
  return jsonDecode(raw) as Map<String, dynamic>;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('seed roster', () {
    test('matches the Figma shift counts', () {
      final roster = PosStaffRoster.seed();
      expect(roster.membersOf(PosStaffShift.morning).length, 12);
      expect(roster.membersOf(PosStaffShift.afternoon).length, 11);
      expect(roster.membersOf(PosStaffShift.evening).length, 13);
    });

    test('every shift id resolves to a real member', () {
      final roster = PosStaffRoster.seed();
      for (final shift in roster.shifts) {
        for (final id in shift.memberIds) {
          expect(roster.memberById(id), isNotNull, reason: '$id on ${shift.id}');
        }
      }
    });

    test('survives a JSON round trip', () {
      final roster = PosStaffRoster.seed();
      final decoded =
          PosStaffRoster.fromJson(jsonDecode(jsonEncode(roster.toJson())));
      expect(decoded, isNotNull);
      expect(decoded!.members.length, roster.members.length);
      expect(
        decoded.membersOf(PosStaffShift.evening).length,
        roster.membersOf(PosStaffShift.evening).length,
      );
    });
  });

  group('roster edits', () {
    test('adding a member rosters them onto the chosen shifts', () async {
      final provider = await _provider();
      final int morningBefore =
          provider.membersOf(PosStaffShift.morning).length;
      final int eveningBefore =
          provider.membersOf(PosStaffShift.evening).length;

      final String? id = provider.addMember(
        name: 'Sanne Bakker',
        role: PosStaffRoles.employee,
        shiftIds: const [PosStaffShift.morning, PosStaffShift.evening],
      );

      expect(id, 'sanne-bakker');
      expect(provider.selectedId, id);
      expect(provider.membersOf(PosStaffShift.morning).length,
          morningBefore + 1);
      expect(provider.membersOf(PosStaffShift.evening).length,
          eveningBefore + 1);
      // Not asked for, so not rostered.
      expect(
        provider.shiftsOf(id!),
        [PosStaffShift.morning, PosStaffShift.evening],
      );
      expect(provider.selected!.passcode.length, PosStaffPasscode.length);
      expect(
        provider.selected!.permissions,
        PosStaffRoles.defaultPermissions(PosStaffRoles.employee),
      );
    });

    test('a blank name is rejected and nothing is added', () async {
      final provider = await _provider();
      final int before = provider.members.length;

      expect(provider.addMember(name: '   ', role: PosStaffRoles.employee),
          isNull);
      expect(provider.members.length, before);
      expect(provider.errors['newName'], isNotNull);
    });

    test('duplicate names get distinct ids', () async {
      final provider = await _provider();
      final String? first =
          provider.addMember(name: 'Jan Jansen', role: PosStaffRoles.employee);
      final String? second =
          provider.addMember(name: 'Jan Jansen', role: PosStaffRoles.employee);
      expect(first, 'jan-jansen');
      expect(second, 'jan-jansen-2');
    });

    test('generated passcodes do not collide with the roster', () async {
      final provider = await _provider();
      final String? code = provider.regeneratePasscode();
      expect(code, isNotNull);
      final others = [
        for (final m in provider.members)
          if (m.id != provider.selectedId) m.passcode,
      ];
      expect(others.contains(code), isFalse);
    });

    test('removing a member clears them from every shift', () async {
      final provider = await _provider();
      provider.removeMember('liam');
      expect(provider.roster.memberById('liam'), isNull);
      for (final shift in provider.shifts) {
        expect(shift.memberIds.contains('liam'), isFalse);
      }
    });

    test('the last member cannot be removed', () async {
      final provider = await _provider();
      for (final m in [...provider.members]) {
        provider.removeMember(m.id);
      }
      expect(provider.members.length, 1);
    });
  });

  group('shift assignment', () {
    test('addToShift ignores unknown ids and duplicates', () async {
      final provider = await _provider();
      final int before = provider.membersOf(PosStaffShift.morning).length;

      // 'thomas' is only on afternoon/evening in the seed; 'maria' is already
      // on morning; 'ghost' does not exist.
      provider.addToShift(PosStaffShift.morning, ['thomas', 'maria', 'ghost']);

      expect(provider.membersOf(PosStaffShift.morning).length, before + 1);
      expect(provider.shiftsOf('thomas'), contains(PosStaffShift.morning));
    });

    test('toggleShift adds then removes', () async {
      final provider = await _provider();
      provider.toggleShift(PosStaffShift.evening, 'nina');
      expect(provider.shiftsOf('nina'), contains(PosStaffShift.evening));
      provider.toggleShift(PosStaffShift.evening, 'nina');
      expect(provider.shiftsOf('nina'), isNot(contains(PosStaffShift.evening)));
    });

    test('availableFor excludes members already on the shift', () async {
      final provider = await _provider();
      final available = provider.availableFor(PosStaffShift.morning);
      expect(available.map((m) => m.id), isNot(contains('maria')));
      expect(available.map((m) => m.id), contains('thomas'));
    });

    test('renaming a member updates the shift chip label', () async {
      final provider = await _provider();
      provider.select('maria');
      provider.setName('Marieke Visser');
      final chips = provider
          .membersOf(PosStaffShift.morning)
          .map((m) => m.shortName)
          .toList();
      expect(chips, contains('Marieke'));
      expect(chips, isNot(contains('Maria')));
    });
  });

  group('persistence', () {
    test('shift changes are written through', () async {
      final provider = await _provider();
      provider.addToShift(PosStaffShift.morning, ['thomas']);
      await Future<void>.delayed(Duration.zero);

      final stored = await _stored();
      expect(stored, isNotNull);
      final reloaded = PosStaffRoster.fromJson(stored!)!;
      expect(
        reloaded.shiftById(PosStaffShift.morning)!.memberIds,
        contains('thomas'),
      );
    });

    test('permission toggles are written through', () async {
      final provider = await _provider();
      provider.select('sophie');
      provider.setPermission(PosStaffPermissions.processRefunds, true);
      await Future<void>.delayed(Duration.zero);

      final reloaded = PosStaffRoster.fromJson((await _stored())!)!;
      expect(
        reloaded.memberById('sophie')!
            .permissions[PosStaffPermissions.processRefunds],
        isTrue,
      );
    });

    test('a half-typed name is not persisted, a valid one is', () async {
      final provider = await _provider();
      provider.select('sophie');

      provider.setName('');
      await Future<void>.delayed(Duration.zero);
      expect(provider.errors['name'], isNotNull);
      expect(await _stored(), isNull);

      provider.setName('Sophie de Wit');
      await Future<void>.delayed(Duration.zero);
      expect(provider.errors['name'], isNull);
      final reloaded = PosStaffRoster.fromJson((await _stored())!)!;
      expect(reloaded.memberById('sophie')!.name, 'Sophie de Wit');
    });

    test('a saved roster is preferred over the seed on hydrate', () async {
      final first = await _provider();
      first.addMember(
        name: 'Bram Post',
        role: PosStaffRoles.manager,
        shiftIds: const [PosStaffShift.evening],
      );
      await Future<void>.delayed(Duration.zero);

      final second = await _provider();
      expect(second.roster.memberById('bram-post'), isNotNull);
      expect(second.shiftsOf('bram-post'), [PosStaffShift.evening]);
    });

    test('a corrupt record falls back to the seed', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.posStaffRosterKey, '{not json');
      final provider = await _provider();
      expect(provider.members.length, PosStaffRoster.seed().members.length);
    });

    test('a record missing a permission key loads with it defaulted', () {
      final member = PosStaffMember.fromJson({
        'id': 'x',
        'name': 'X Y',
        'role': PosStaffRoles.employee,
        'active': true,
        'passcode': '1234',
        'permissions': {PosStaffPermissions.applyDiscounts: true},
      });
      expect(member, isNotNull);
      expect(member!.permissions.keys, PosStaffPermissions.keys);
      expect(member.permissions[PosStaffPermissions.manageStaff], isFalse);
    });
  });
}
