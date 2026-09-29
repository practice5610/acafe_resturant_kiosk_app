import 'package:acafe_customer/features/pos/domain/pos_general_settings.dart';

/// One POS permission, as the backend defines it.
///
/// The key is stable and is what gets stored and checked; the label is
/// presentation and arrives already translated. Nothing here is declared in the
/// app: this list used to be hardcoded in Dart *and* retyped in PHP, so the two
/// had to be kept in step by hand and a permission could not be added without
/// shipping a build.
class PosStaffPermission {
  final String key;
  final String label;
  final String description;

  const PosStaffPermission({
    required this.key,
    required this.label,
    this.description = '',
  });

  static PosStaffPermission? fromJson(Map<String, dynamic> json) {
    final String key = (json['key'] ?? '').toString();
    if (key.isEmpty) return null;
    return PosStaffPermission(
      key: key,
      label: (json['label'] ?? key).toString(),
      description: (json['description'] ?? '').toString(),
    );
  }
}

/// A role this branch may put someone on.
///
/// The backend withholds any role that grants admin-panel modules, so a till
/// cannot hand out back-office access.
class PosStaffRole {
  final int id;
  final String name;

  const PosStaffRole({required this.id, required this.name});

  static PosStaffRole? fromJson(Map<String, dynamic> json) {
    final int id = int.tryParse('${json['id']}') ?? 0;
    final String name = (json['name'] ?? '').toString();
    if (id == 0 || name.isEmpty) return null;
    return PosStaffRole(id: id, name: name);
  }
}

/// Everything the Staff screen used to hardcode, served by the branch.
class PosStaffCatalogue {
  final List<PosStaffPermission> permissions;
  final List<PosStaffRole> roles;
  final List<PosStaffShift> shifts;
  final String branchName;

  /// Whether this branch asks staff to sign in on the till. Shown read-only —
  /// it is an admin decision, made per branch.
  final bool staffLoginRequired;

  final int pinLength;

  const PosStaffCatalogue({
    required this.permissions,
    required this.roles,
    required this.shifts,
    required this.branchName,
    required this.staffLoginRequired,
    required this.pinLength,
  });

  /// What the screen renders before the catalogue arrives, and if it never
  /// does: no invented permissions, no invented roles.
  factory PosStaffCatalogue.empty() => const PosStaffCatalogue(
        permissions: [],
        roles: [],
        shifts: [],
        branchName: '',
        staffLoginRequired: false,
        pinLength: 4,
      );

  bool get isEmpty => permissions.isEmpty && roles.isEmpty;

  List<String> get permissionKeys => [for (final p in permissions) p.key];

  List<PosSettingsOption> get roleOptions =>
      [for (final r in roles) PosSettingsOption(value: r.name, label: r.name)];

  String labelFor(String key) {
    for (final p in permissions) {
      if (p.key == key) return p.label;
    }
    return key;
  }

  int? roleIdFor(String name) {
    for (final r in roles) {
      if (r.name == name) return r.id;
    }
    return null;
  }

  static PosStaffCatalogue? fromJson(Map<String, dynamic> json) {
    final Object? rawPermissions = json['permissions'];
    if (rawPermissions is! List) return null;

    final List<PosStaffPermission> permissions = [];
    for (final entry in rawPermissions) {
      if (entry is! Map) continue;
      final p = PosStaffPermission.fromJson(Map<String, dynamic>.from(entry));
      if (p != null) permissions.add(p);
    }

    final List<PosStaffRole> roles = [];
    if (json['roles'] is List) {
      for (final entry in json['roles'] as List) {
        if (entry is! Map) continue;
        final r = PosStaffRole.fromJson(Map<String, dynamic>.from(entry));
        if (r != null) roles.add(r);
      }
    }

    final List<PosStaffShift> shifts = [];
    if (json['shifts'] is List) {
      for (final entry in json['shifts'] as List) {
        if (entry is! Map) continue;
        final s = PosStaffShift.fromJson(Map<String, dynamic>.from(entry));
        if (s != null) shifts.add(s);
      }
    }

    final Object? branch = json['branch'];
    final Map<String, dynamic> branchMap =
        branch is Map ? Map<String, dynamic>.from(branch) : const {};

    return PosStaffCatalogue(
      permissions: permissions,
      roles: roles,
      shifts: shifts,
      branchName: (branchMap['name'] ?? '').toString(),
      staffLoginRequired: branchMap['staff_login_required'] == true,
      pinLength: int.tryParse('${json['pin_length']}') ?? 4,
    );
  }

  Map<String, dynamic> toJson() => {
        'permissions': [
          for (final p in permissions)
            {'key': p.key, 'label': p.label, 'description': p.description},
        ],
        'roles': [
          for (final r in roles) {'id': r.id, 'name': r.name},
        ],
        'shifts': [for (final s in shifts) s.toJson()],
        'branch': {'name': branchName, 'staff_login_required': staffLoginRequired},
        'pin_length': pinLength,
      };
}

/// One member of the POS roster.
class PosStaffMember {
  final String id;
  final String name;

  /// The role's display name. The id travels alongside so a save does not have
  /// to match on a string the operator can see.
  final String role;
  final int roleId;

  final bool active;

  /// Whether a PIN is set. The PIN itself never leaves the server, so this is
  /// the only thing the app can know about it.
  final bool hasPin;

  /// Effective permissions, keyed by stable key: the role's grant merged with
  /// this member's own overrides.
  final Map<String, bool> permissions;

  final List<String> shiftIds;

  const PosStaffMember({
    required this.id,
    required this.name,
    required this.role,
    this.roleId = 0,
    required this.active,
    this.hasPin = false,
    required this.permissions,
    this.shiftIds = const [],
  });

  /// What the shift chips show. Shifts are read at a glance across a busy
  /// counter, so they carry the first name only.
  String get shortName {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed.split(RegExp(r'\s+')).first;
  }

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'))
      ..removeWhere((p) => p.isEmpty);
    if (parts.isEmpty) return '?';
    // By code point rather than code unit, so an accented initial is not split.
    final String first = String.fromCharCode(parts.first.runes.first);
    final String last =
        parts.length > 1 ? String.fromCharCode(parts.last.runes.first) : '';
    return (first + last).toUpperCase();
  }

  PosStaffMember copyWith({
    String? name,
    String? role,
    int? roleId,
    bool? active,
    bool? hasPin,
    Map<String, bool>? permissions,
    List<String>? shiftIds,
  }) {
    return PosStaffMember(
      id: id,
      name: name ?? this.name,
      role: role ?? this.role,
      roleId: roleId ?? this.roleId,
      active: active ?? this.active,
      hasPin: hasPin ?? this.hasPin,
      permissions: permissions ?? this.permissions,
      shiftIds: shiftIds ?? this.shiftIds,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role,
        'role_id': roleId,
        'active': active,
        'has_pin': hasPin,
        'permissions': permissions,
        'shift_ids': shiftIds,
      };

  static PosStaffMember? fromJson(Map<String, dynamic> json) {
    final String id = (json['id'] ?? '').toString();
    final String name = (json['name'] ?? '').toString();
    if (id.isEmpty || name.isEmpty) return null;

    final Object? rawPerms = json['permissions'];
    final Map<String, bool> perms = rawPerms is Map
        ? {
            for (final entry in rawPerms.entries)
              entry.key.toString(): entry.value == true,
          }
        : const {};

    final Object? rawShifts = json['shift_ids'];

    return PosStaffMember(
      id: id,
      name: name,
      role: (json['role'] ?? '').toString(),
      roleId: int.tryParse('${json['role_id']}') ?? 0,
      active: json['active'] != false,
      hasPin: json['has_pin'] == true,
      permissions: perms,
      shiftIds: rawShifts is List
          ? [
              for (final v in rawShifts)
                if (v != null && v.toString().isNotEmpty) v.toString(),
            ]
          : const [],
    );
  }
}

/// A named service window and the members rostered onto it.
///
/// Membership is stored as ids, not names, so renaming a member cannot leave a
/// stale label behind on a shift chip.
class PosStaffShift {
  final String id;
  final String name;
  final String time;
  final List<String> memberIds;

  const PosStaffShift({
    required this.id,
    required this.name,
    required this.time,
    required this.memberIds,
  });

  PosStaffShift copyWith({List<String>? memberIds}) => PosStaffShift(
        id: id,
        name: name,
        time: time,
        memberIds: memberIds ?? this.memberIds,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'time': time,
        'member_ids': memberIds,
      };

  static PosStaffShift? fromJson(Map<String, dynamic> json) {
    final String id = (json['id'] ?? '').toString();
    if (id.isEmpty) return null;
    final Object? raw = json['member_ids'];
    return PosStaffShift(
      id: id,
      name: (json['name'] ?? '').toString(),
      time: (json['time'] ?? '').toString(),
      memberIds: raw is List
          ? [
              for (final v in raw)
                if (v != null && v.toString().isNotEmpty) v.toString(),
            ]
          : const [],
    );
  }
}

/// The whole Staff screen's data: who is on the team, and who works when.
class PosStaffRoster {
  final List<PosStaffMember> members;
  final List<PosStaffShift> shifts;

  const PosStaffRoster({required this.members, required this.shifts});

  PosStaffMember? memberById(String id) {
    for (final m in members) {
      if (m.id == id) return m;
    }
    return null;
  }

  PosStaffShift? shiftById(String id) {
    for (final s in shifts) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Rostered members of [shiftId], in roster order, skipping ids whose member
  /// no longer exists.
  List<PosStaffMember> membersOf(String shiftId) {
    final PosStaffShift? shift = shiftById(shiftId);
    if (shift == null) return const [];
    final List<PosStaffMember> out = [];
    for (final String id in shift.memberIds) {
      final PosStaffMember? m = memberById(id);
      if (m != null) out.add(m);
    }
    return out;
  }

  /// Members not yet on [shiftId] — what the "add to shift" picker offers.
  List<PosStaffMember> availableFor(String shiftId) {
    final PosStaffShift? shift = shiftById(shiftId);
    if (shift == null) return const [];
    return [
      for (final m in members)
        if (!shift.memberIds.contains(m.id)) m,
    ];
  }

  PosStaffRoster copyWith({
    List<PosStaffMember>? members,
    List<PosStaffShift>? shifts,
  }) {
    return PosStaffRoster(
      members: members ?? this.members,
      shifts: shifts ?? this.shifts,
    );
  }

  Map<String, dynamic> toJson() => {
        'members': [for (final m in members) m.toJson()],
        'shifts': [for (final s in shifts) s.toJson()],
      };

  static PosStaffRoster? fromJson(Map<String, dynamic> json) {
    final Object? rawMembers = json['members'];
    final Object? rawShifts = json['shifts'];
    if (rawMembers is! List || rawShifts is! List) return null;

    final List<PosStaffMember> members = [];
    for (final entry in rawMembers) {
      if (entry is! Map) continue;
      final PosStaffMember? m =
          PosStaffMember.fromJson(Map<String, dynamic>.from(entry));
      if (m != null) members.add(m);
    }

    final List<PosStaffShift> shifts = [];
    for (final entry in rawShifts) {
      if (entry is! Map) continue;
      final PosStaffShift? s =
          PosStaffShift.fromJson(Map<String, dynamic>.from(entry));
      if (s != null) shifts.add(s);
    }

    return PosStaffRoster(members: members, shifts: shifts);
  }

  /// Empty roster a new branch starts on. Shifts come from the catalogue, so
  /// there is nothing to invent here either.
  factory PosStaffRoster.empty() =>
      const PosStaffRoster(members: [], shifts: []);
}

/// Field-level validation for the Member Details form and the add dialog.
class PosStaffValidation {
  PosStaffValidation._();

  static const int nameMaxLength = 60;

  static String? name(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) return 'Name is required';
    if (trimmed.length > nameMaxLength) {
      return 'Name must be $nameMaxLength characters or fewer';
    }
    return null;
  }

  /// The PIN is optional when hiring — a manager can set one later — but if one
  /// is typed it has to be the right shape. The server is the authority on
  /// uniqueness; it can see the whole branch and this screen cannot.
  static String? pin(String value, {required int length, bool required = false}) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return required ? 'A PIN is required' : null;
    }
    if (!RegExp('^[0-9]{$length}\$').hasMatch(trimmed)) {
      return 'The PIN must be exactly $length digits';
    }
    return null;
  }
}
