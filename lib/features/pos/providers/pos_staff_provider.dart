import 'package:acafe_customer/features/pos/domain/pos_staff.dart';
import 'package:acafe_customer/features/pos/domain/pos_staff_repo.dart';
import 'package:flutter/foundation.dart';

/// State for Settings → Staff: the roster, the shift board, and the Member
/// Details form bound to whichever member is selected.
///
/// Unlike [PosGeneralSettingsProvider], this screen has no Save button in
/// Figma, so it follows Products' per-control auto-save instead: every mutation
/// updates the roster in memory, notifies, and writes through to
/// [PosStaffRepo] (DB via API, with a local cache). The one exception is the
/// name field, which is held in memory while it is invalid (mid-edit blanks
/// are normal) and persisted as soon as it validates.
class PosStaffProvider extends ChangeNotifier {
  final PosStaffRepo repo;

  PosStaffProvider({required this.repo});

  PosStaffRoster _roster = PosStaffRoster.empty();
  String _selectedId = '';
  Map<String, String> _errors = {};
  bool _hydrated = false;
  bool _saving = false;
  bool _loading = false;
  String? _syncError;

  PosStaffRoster get roster => _roster;
  List<PosStaffMember> get members => _roster.members;
  List<PosStaffShift> get shifts => _roster.shifts;
  Map<String, String> get errors => _errors;
  bool get isHydrated => _hydrated;
  bool get isSaving => _saving;
  bool get isLoading => _loading;
  String? get syncError => _syncError;

  String get selectedId => _selectedId;
  PosStaffMember? get selected => _roster.memberById(_selectedId);

  /// Members rostered onto [shiftId], resolved to live records.
  List<PosStaffMember> membersOf(String shiftId) => _roster.membersOf(shiftId);

  /// Members not yet on [shiftId] — the picker's contents.
  List<PosStaffMember> availableFor(String shiftId) =>
      _roster.availableFor(shiftId);

  /// Shift ids [memberId] is currently rostered onto.
  List<String> shiftsOf(String memberId) => [
        for (final s in _roster.shifts)
          if (s.memberIds.contains(memberId)) s.id,
      ];

  /// Loads from the server when possible; otherwise local cache; otherwise
  /// an empty roster (no hardcoded demo staff).
  Future<void> hydrate() async {
    _loading = true;
    _syncError = null;
    notifyListeners();

    final PosStaffRoster? remote = await repo.fetchRemote();
    if (remote != null) {
      _roster = remote;
      await repo.saveLocal(remote);
    } else {
      _roster = repo.loadSaved() ?? PosStaffRoster.empty();
    }

    _selectedId = _defaultSelection();
    _errors = {};
    _hydrated = true;
    _loading = false;
    notifyListeners();
  }

  String _defaultSelection() {
    final PosStaffMember? manager = _firstWithRole(PosStaffRoles.manager);
    if (manager != null) return manager.id;
    return _roster.members.isEmpty ? '' : _roster.members.first.id;
  }

  PosStaffMember? _firstWithRole(String role) {
    for (final m in _roster.members) {
      if (m.role == role) return m;
    }
    return null;
  }

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
    _updateSelected((m) => m.copyWith(name: value), persist: error == null);
    if (error == null) {
      _errors.remove('name');
    } else {
      _errors['name'] = error;
    }
    notifyListeners();
  }

  void setRole(String role) {
    if (!PosStaffRoles.isValid(role)) return;
    _updateSelected((m) => m.copyWith(role: role));
    notifyListeners();
  }

  void setActive(bool active) {
    _updateSelected((m) => m.copyWith(active: active));
    notifyListeners();
  }

  void setPermission(String key, bool value) {
    if (!PosStaffPermissions.keys.contains(key)) return;
    _updateSelected((m) {
      final Map<String, bool> next = Map<String, bool>.from(m.permissions);
      next[key] = value;
      return m.copyWith(permissions: next);
    });
    notifyListeners();
  }

  void _updateSelected(
    PosStaffMember Function(PosStaffMember) transform, {
    bool persist = true,
  }) {
    final PosStaffMember? current = selected;
    if (current == null) return;
    _roster = _roster.copyWith(
      members: [
        for (final m in _roster.members)
          if (m.id == current.id) transform(m) else m,
      ],
    );
    if (persist) _persist();
  }

  // ── Roster ────────────────────────────────────────────────────────────

  /// Adds a member and selects them. Returns the new id, or `null` when the
  /// name does not validate — in which case `errors['newName']` says why.
  String? addMember({
    required String name,
    required String role,
    List<String> shiftIds = const [],
  }) {
    final String? error = PosStaffValidation.name(name);
    if (error != null) {
      _errors['newName'] = error;
      notifyListeners();
      return null;
    }

    final String trimmed = name.trim();
    final String id = _newId(trimmed);
    final String safeRole =
        PosStaffRoles.isValid(role) ? role : PosStaffRoles.employee;

    final PosStaffMember member = PosStaffMember(
      id: id,
      name: trimmed,
      role: safeRole,
      active: true,
      // POS manager access is gated by the device's own configuration_code,
      // not a per-staff code, so new members no longer get one generated.
      passcode: '',
      permissions: PosStaffRoles.defaultPermissions(safeRole),
    );

    _roster = _roster.copyWith(
      members: [..._roster.members, member],
      shifts: [
        for (final s in _roster.shifts)
          if (shiftIds.contains(s.id))
            s.copyWith(memberIds: [...s.memberIds, id])
          else
            s,
      ],
    );

    _selectedId = id;
    _errors.remove('newName');
    _errors.remove('name');
    _persist();
    notifyListeners();
    return id;
  }

  /// Removes a member from the roster and from every shift they were on.
  void removeMember(String id) {
    if (_roster.memberById(id) == null) return;
    final List<PosStaffMember> next = [
      for (final m in _roster.members)
        if (m.id != id) m,
    ];

    _roster = PosStaffRoster(
      members: next,
      shifts: [
        for (final s in _roster.shifts)
          s.copyWith(
            memberIds: [
              for (final mid in s.memberIds)
                if (mid != id) mid,
            ],
          ),
      ],
    );

    if (_selectedId == id) _selectedId = _defaultSelection();
    _persist();
    notifyListeners();
  }

  String _newId(String name) {
    final String base = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final String seed = base.isEmpty ? 'staff' : base;
    if (_roster.memberById(seed) == null) return seed;
    int n = 2;
    while (_roster.memberById('$seed-$n') != null) {
      n++;
    }
    return '$seed-$n';
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
  }

  void removeFromShift(String shiftId, String memberId) {
    final PosStaffShift? shift = _roster.shiftById(shiftId);
    if (shift == null || !shift.memberIds.contains(memberId)) return;
    _replaceShift(
      shift.copyWith(
        memberIds: [
          for (final id in shift.memberIds)
            if (id != memberId) id,
        ],
      ),
    );
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
    _persist();
    notifyListeners();
  }

  // ── Persistence ───────────────────────────────────────────────────────

  Future<void> _persist() async {
    _saving = true;
    _syncError = null;
    final PosStaffRoster snapshot = _roster;
    await repo.saveLocal(snapshot);
    final response = await repo.saveRemote(snapshot);
    if (!response.isSuccess) {
      _syncError = response.error?.toString() ?? 'Could not save staff';
    }
    if (identical(snapshot, _roster)) {
      _saving = false;
      notifyListeners();
    }
  }
}
