import 'package:acafe_customer/common/models/api_response_model.dart';
import 'package:acafe_customer/features/pos/domain/pos_staff.dart';
import 'package:acafe_customer/features/pos/domain/pos_staff_repo.dart';
import 'package:flutter/foundation.dart';

/// State for Settings → Staff: the roster, the shift board, and the Member
/// Details form bound to whichever member is selected.
///
/// Two things changed with the unified staff work. The permission list, the
/// roles and the shifts now come from the branch rather than from constants in
/// this file, so a permission can be added server-side without a new build. And
/// every mutation is a single per-member call rather than a whole-roster PUT:
/// the old behaviour meant one keystroke re-sent everybody, so a second till in
/// the same branch silently overwrote the first.
///
/// The screen still has no Save button, per Figma, so writes go through on each
/// change. The name field is the one exception: it is held in memory while it is
/// invalid, because mid-edit blanks are normal.
class PosStaffProvider extends ChangeNotifier {
  final PosStaffRepo repo;

  PosStaffProvider({required this.repo});

  PosStaffRoster _roster = PosStaffRoster.empty();
  PosStaffCatalogue _catalogue = PosStaffCatalogue.empty();
  String _selectedId = '';
  Map<String, String> _errors = {};
  bool _hydrated = false;
  bool _saving = false;
  bool _loading = false;
  String? _syncError;

  PosStaffRoster get roster => _roster;
  PosStaffCatalogue get catalogue => _catalogue;
  List<PosStaffMember> get members => _roster.members;
  List<PosStaffShift> get shifts => _roster.shifts;
  Map<String, String> get errors => _errors;
  bool get isHydrated => _hydrated;
  bool get isSaving => _saving;
  bool get isLoading => _loading;
  String? get syncError => _syncError;

  /// Permission keys in the order the branch serves them.
  List<String> get permissionKeys => _catalogue.permissionKeys;

  String permissionLabel(String key) => _catalogue.labelFor(key);

  String get branchName => _catalogue.branchName;

  bool get staffLoginRequired => _catalogue.staffLoginRequired;

  int get pinLength => _catalogue.pinLength;

  String get selectedId => _selectedId;
  PosStaffMember? get selected => _roster.memberById(_selectedId);

  List<PosStaffMember> membersOf(String shiftId) => _roster.membersOf(shiftId);

  List<PosStaffMember> availableFor(String shiftId) =>
      _roster.availableFor(shiftId);

  List<String> shiftsOf(String memberId) => [
        for (final s in _roster.shifts)
          if (s.memberIds.contains(memberId)) s.id,
      ];

  // ── Hydrate ───────────────────────────────────────────────────────────

  /// Catalogue first, then the roster. Falls back to the cache, then to empty —
  /// never to invented staff or invented permissions.
  Future<void> hydrate() async {
    _loading = true;
    _syncError = null;
    notifyListeners();

    final PosStaffCatalogue? catalogue = await repo.fetchCatalogue();
    if (catalogue != null) {
      _catalogue = catalogue;
      await repo.saveCatalogueLocal(catalogue);
    } else {
      _catalogue = repo.loadSavedCatalogue() ?? PosStaffCatalogue.empty();
    }

    final PosStaffRoster? remote = await repo.fetchRemote();
    if (remote != null) {
      _roster = _withCatalogueShifts(remote);
      await repo.saveLocal(_roster);
    } else {
      _roster = _withCatalogueShifts(repo.loadSaved() ?? PosStaffRoster.empty());
    }

    _selectedId = _defaultSelection();
    _errors = {};
    _hydrated = true;
    _loading = false;
    notifyListeners();
  }

  /// The roster carries shift membership; the catalogue carries their names and
  /// times. A roster that arrives without shift definitions borrows them.
  PosStaffRoster _withCatalogueShifts(PosStaffRoster roster) {
    if (roster.shifts.isNotEmpty) return roster;
    return roster.copyWith(
      shifts: [
        for (final s in _catalogue.shifts)
          PosStaffShift(id: s.id, name: s.name, time: s.time, memberIds: const []),
      ],
    );
  }

  String _defaultSelection() =>
      _roster.members.isEmpty ? '' : _roster.members.first.id;

  void select(String id) {
    if (id == _selectedId) return;
    if (_roster.memberById(id) == null) return;
    _selectedId = id;
    _errors.remove('name');
    notifyListeners();
  }

  // ── Member Details ────────────────────────────────────────────────────

  void setName(String value) {
    final String? error = PosStaffValidation.name(value);
    final PosStaffMember? current = selected;
    if (current == null) return;

    _applyLocal(current.id, (m) => m.copyWith(name: value));

    if (error == null) {
      _errors.remove('name');
      _push(current.id, () => repo.updateMember(current.id, name: value.trim()));
    } else {
      _errors['name'] = error;
    }
    notifyListeners();
  }

  void setRole(String roleName) {
    final PosStaffMember? current = selected;
    if (current == null) return;

    final int? roleId = _catalogue.roleIdFor(roleName);
    // A role the branch did not offer is not a role.
    if (roleId == null) return;

    _applyLocal(current.id, (m) => m.copyWith(role: roleName, roleId: roleId));
    _push(current.id, () => repo.updateMember(current.id, roleId: roleId));
    notifyListeners();
  }

  void setActive(bool active) {
    final PosStaffMember? current = selected;
    if (current == null) return;

    _applyLocal(current.id, (m) => m.copyWith(active: active));
    _push(current.id, () => repo.updateMember(current.id, active: active));
    notifyListeners();
  }

  void setPermission(String key, bool value) {
    if (!_catalogue.permissionKeys.contains(key)) return;
    final PosStaffMember? current = selected;
    if (current == null) return;

    final Map<String, bool> next = Map<String, bool>.from(current.permissions);
    next[key] = value;

    _applyLocal(current.id, (m) => m.copyWith(permissions: next));
    _push(current.id, () => repo.updateMember(current.id, permissions: next));
    notifyListeners();
  }

  /// Sets or rotates a PIN. Returns null on success, or a message to show.
  ///
  /// The server owns uniqueness — it can see the whole branch and this screen
  /// cannot — so a duplicate comes back as a message rather than being guessed
  /// at here.
  Future<String?> setPin(String pin) async {
    final PosStaffMember? current = selected;
    if (current == null) return 'Select a staff member first';

    final String? shapeError =
        PosStaffValidation.pin(pin, length: pinLength, required: true);
    if (shapeError != null) return shapeError;

    _saving = true;
    notifyListeners();

    final ApiResponseModel response = await repo.setPin(current.id, pin.trim());

    _saving = false;
    if (!response.isSuccess) {
      notifyListeners();
      return response.error?.toString() ?? 'Could not set that PIN';
    }

    _applyLocal(current.id, (m) => m.copyWith(hasPin: true));
    notifyListeners();
    return null;
  }

  // ── Roster ────────────────────────────────────────────────────────────

  /// Adds a member. Returns the new id, or null with `errors['newName']` /
  /// `errors['newPin']` set.
  Future<String?> addMember({
    required String name,
    required String role,
    List<String> shiftIds = const [],
    String? pin,
  }) async {
    final String? nameError = PosStaffValidation.name(name);
    if (nameError != null) {
      _errors['newName'] = nameError;
      notifyListeners();
      return null;
    }

    final String? pinError =
        PosStaffValidation.pin(pin ?? '', length: pinLength);
    if (pinError != null) {
      _errors['newPin'] = pinError;
      notifyListeners();
      return null;
    }

    final int? roleId = _catalogue.roleIdFor(role);
    if (roleId == null) {
      _errors['newRole'] = 'Choose a role';
      notifyListeners();
      return null;
    }

    _saving = true;
    _syncError = null;
    _errors.remove('newName');
    _errors.remove('newPin');
    _errors.remove('newRole');
    notifyListeners();

    final ApiResponseModel response = await repo.createMember(
      name: name.trim(),
      roleId: roleId,
      shiftIds: shiftIds,
      pin: pin,
    );

    _saving = false;

    if (!response.isSuccess) {
      _syncError = response.error?.toString() ?? 'Could not add that member';
      notifyListeners();
      return null;
    }

    // The server mints the roster id and says which it chose. It is read from
    // the response rather than by looking the name up afterwards: two people
    // can share a name, and a lookup would select whichever came first.
    final String? createdId = _createdId(response);

    await _reload();

    if (createdId != null && _roster.memberById(createdId) != null) {
      _selectedId = createdId;
    }
    notifyListeners();
    return createdId;
  }

  String? _createdId(ApiResponseModel response) {
    final Object? data = response.response?.data;
    if (data is Map && data['member'] is Map) {
      final Object? id = (data['member'] as Map)['id'];
      if (id != null && id.toString().isNotEmpty) return id.toString();
    }
    return null;
  }

  Future<void> removeMember(String id) async {
    if (_roster.memberById(id) == null) return;

    _saving = true;
    notifyListeners();

    final ApiResponseModel response = await repo.removeMember(id);

    _saving = false;
    if (!response.isSuccess) {
      _syncError = response.error?.toString() ?? 'Could not remove that member';
      notifyListeners();
      return;
    }

    await _reload();
    if (_selectedId == id) _selectedId = _defaultSelection();
    notifyListeners();
  }

  // ── Shifts ────────────────────────────────────────────────────────────

  void addToShift(String shiftId, Iterable<String> memberIds) {
    final PosStaffShift? shift = _roster.shiftById(shiftId);
    if (shift == null) return;

    final List<String> next = [...shift.memberIds];
    for (final String id in memberIds) {
      if (next.contains(id)) continue;
      if (_roster.memberById(id) == null) continue;
      next.add(id);
    }
    if (next.length == shift.memberIds.length) return;

    _replaceShift(shift.copyWith(memberIds: next));
    for (final String id in memberIds) {
      _pushShifts(id);
    }
  }

  void removeFromShift(String shiftId, String memberId) {
    final PosStaffShift? shift = _roster.shiftById(shiftId);
    if (shift == null || !shift.memberIds.contains(memberId)) return;

    _replaceShift(shift.copyWith(
      memberIds: [
        for (final id in shift.memberIds)
          if (id != memberId) id,
      ],
    ));
    _pushShifts(memberId);
  }

  void toggleShift(String shiftId, String memberId) {
    final PosStaffShift? shift = _roster.shiftById(shiftId);
    if (shift == null) return;
    if (shift.memberIds.contains(memberId)) {
      removeFromShift(shiftId, memberId);
    } else {
      addToShift(shiftId, [memberId]);
    }
  }

  void _replaceShift(PosStaffShift shift) {
    _roster = _roster.copyWith(
      shifts: [
        for (final s in _roster.shifts)
          if (s.id == shift.id) shift else s,
      ],
    );
    notifyListeners();
  }

  /// Shift membership is stored on the member, so a change to a shift is a write
  /// to each member it moved.
  void _pushShifts(String memberId) {
    final List<String> ids = shiftsOf(memberId);
    _applyLocal(memberId, (m) => m.copyWith(shiftIds: ids));
    _push(memberId, () => repo.updateMember(memberId, shiftIds: ids));
  }

  // ── Persistence ───────────────────────────────────────────────────────

  void _applyLocal(String id, PosStaffMember Function(PosStaffMember) transform) {
    _roster = _roster.copyWith(
      members: [
        for (final m in _roster.members)
          if (m.id == id) transform(m) else m,
      ],
    );
    repo.saveLocal(_roster);
  }

  /// Optimistic: the change is already on screen, so a failure reports itself
  /// and re-reads rather than silently diverging from the server.
  Future<void> _push(String id, Future<ApiResponseModel> Function() call) async {
    _saving = true;
    _syncError = null;
    notifyListeners();

    final ApiResponseModel response = await call();

    _saving = false;
    if (!response.isSuccess) {
      _syncError = response.error?.toString() ?? 'Could not save that change';
      await _reload();
    }
    notifyListeners();
  }

  Future<void> _reload() async {
    final PosStaffRoster? remote = await repo.fetchRemote();
    if (remote != null) {
      _roster = _withCatalogueShifts(remote);
      await repo.saveLocal(_roster);
      if (_roster.memberById(_selectedId) == null) {
        _selectedId = _defaultSelection();
      }
    }
  }

  void clearSyncError() {
    _syncError = null;
    notifyListeners();
  }
}
