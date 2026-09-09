import 'dart:math';

import 'package:acafe_customer/features/pos/domain/pos_general_settings.dart';

/// Roles a POS staff member can hold.
///
/// Deliberately a fixed trio rather than a mirror of `admin_roles`: the POS
/// terminal grants floor permissions, and the admin role table carries
/// back-office module access that has no meaning here.
class PosStaffRoles {
  PosStaffRoles._();

  static const String owner = 'Owner';
  static const String manager = 'Manager';
  static const String employee = 'Employee';

  static const List<String> all = [owner, manager, employee];

  static const List<PosSettingsOption> options = [
    PosSettingsOption(value: owner, label: owner),
    PosSettingsOption(value: manager, label: manager),
    PosSettingsOption(value: employee, label: employee),
  ];

  static bool isValid(String role) => all.contains(role);

  /// Permission preset a newly added member of [role] starts on. The operator
  /// can override any of them afterwards — this is a starting point, not a
  /// constraint enforced on save.
  static Map<String, bool> defaultPermissions(String role) {
    switch (role) {
      case owner:
        return {for (final k in PosStaffPermissions.keys) k: true};
      case manager:
        return {
          for (final k in PosStaffPermissions.keys)
            k: k != PosStaffPermissions.voidOrders &&
                k != PosStaffPermissions.manageStaff,
        };
      default:
        return {
          for (final k in PosStaffPermissions.keys)
            k: k == PosStaffPermissions.applyDiscounts ||
                k == PosStaffPermissions.accessCashDrawer,
        };
    }
  }
}

/// The permission rows shown in Member Details, in Figma order.
class PosStaffPermissions {
  PosStaffPermissions._();

  static const String processRefunds = 'Process refunds';
  static const String applyDiscounts = 'Apply discounts';
  static const String voidOrders = 'Void orders';
  static const String accessReports = 'Access reports';
  static const String manageInventory = 'Manage inventory';
  static const String accessCashDrawer = 'Access cash drawer';
  static const String manageStaff = 'Manage staff';

  static const List<String> keys = [
    processRefunds,
    applyDiscounts,
    voidOrders,
    accessReports,
    manageInventory,
    accessCashDrawer,
    manageStaff,
  ];

  /// Fills in any key the stored record predates and drops any it no longer
  /// knows, so a roster written by an older build still loads.
  static Map<String, bool> normalize(Map<String, bool> raw) =>
      {for (final k in keys) k: raw[k] ?? false};
}

/// One member of the POS roster.
class PosStaffMember {
  final String id;
  final String name;
  final String role;
  final bool active;

  /// Four-digit POS access passcode. Never rendered — Member Details masks it
  /// as `****` exactly as Figma shows.
  final String passcode;

  final Map<String, bool> permissions;

  const PosStaffMember({
    required this.id,
    required this.name,
    required this.role,
    required this.active,
    required this.passcode,
    required this.permissions,
  });

  /// What the shift chips show. Shifts are read at a glance across a busy
  /// counter, so they carry the first name only.
  String get shortName {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed.split(RegExp(r'\s+')).first;
  }

  PosStaffMember copyWith({
    String? name,
    String? role,
    bool? active,
    String? passcode,
    Map<String, bool>? permissions,
  }) {
    return PosStaffMember(
      id: id,
      name: name ?? this.name,
      role: role ?? this.role,
      active: active ?? this.active,
      passcode: passcode ?? this.passcode,
      permissions: permissions ?? this.permissions,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role,
        'active': active,
        'passcode': passcode,
        'permissions': permissions,
      };

  static PosStaffMember? fromJson(Map<String, dynamic> json) {
    final String id = (json['id'] ?? '').toString();
    final String name = (json['name'] ?? '').toString();
    if (id.isEmpty || name.isEmpty) return null;

    final String role = (json['role'] ?? '').toString();
    final Object? rawPerms = json['permissions'];
    final Map<String, bool> perms = rawPerms is Map
        ? {
            for (final entry in rawPerms.entries)
              entry.key.toString(): entry.value == true,
          }
        : const {};

    return PosStaffMember(
      id: id,
      name: name,
      role: PosStaffRoles.isValid(role) ? role : PosStaffRoles.employee,
      active: json['active'] != false,
      passcode: (json['passcode'] ?? '').toString(),
      permissions: PosStaffPermissions.normalize(perms),
    );
  }
}

/// A named service window and the members rostered onto it.
///
/// Membership is stored as ids, not names, so renaming a member in Member
/// Details cannot leave a stale label behind on a shift chip.
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

  static const String morning = 'morning';
  static const String afternoon = 'afternoon';
  static const String evening = 'evening';

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
    if (members.isEmpty) return null;

    final List<PosStaffShift> shifts = [];
    for (final entry in rawShifts) {
      if (entry is! Map) continue;
      final PosStaffShift? s =
          PosStaffShift.fromJson(Map<String, dynamic>.from(entry));
      if (s != null) shifts.add(s);
    }
    if (shifts.isEmpty) return null;

    return PosStaffRoster(members: members, shifts: shifts);
  }

  /// The roster a terminal starts on — the Figma team (1641:8484).
  ///
  /// It is a seed, not a fixture: the first edit persists over it, so nothing
  /// below survives an operator's changes.
  factory PosStaffRoster.seed() {
    PosStaffMember member(
      String id,
      String name,
      String role, {
      bool active = true,
      String passcode = '0000',
    }) {
      return PosStaffMember(
        id: id,
        name: name,
        role: role,
        active: active,
        passcode: passcode,
        permissions: PosStaffRoles.defaultPermissions(role),
      );
    }

    final List<PosStaffMember> members = [
      member('maria', 'Maria van den Berg', PosStaffRoles.owner),
      member('thomas', 'Thomas de Vries', PosStaffRoles.manager),
      member('sophie', 'Sophie Jansen', PosStaffRoles.employee),
      member('liam', 'Liam Bakker', PosStaffRoles.employee),
      member('emma', 'Emma Visser', PosStaffRoles.employee, active: false),
      member('eva', 'Eva Smit', PosStaffRoles.employee),
      member('noah', 'Noah Dekker', PosStaffRoles.employee),
      member('olivia', 'Olivia Meijer', PosStaffRoles.employee),
      member('lucas', 'Lucas Bos', PosStaffRoles.employee),
      member('mila', 'Mila Vos', PosStaffRoles.employee),
      member('finn', 'Finn Peters', PosStaffRoles.employee),
      member('sara', 'Sara Willems', PosStaffRoles.employee),
      member('jesse', 'Jesse Hendriks', PosStaffRoles.employee),
      member('nina', 'Nina Kuipers', PosStaffRoles.employee),
      member('ava', 'Ava Mulder', PosStaffRoles.employee),
    ];

    const List<PosStaffShift> shifts = [
      PosStaffShift(
        id: PosStaffShift.morning,
        name: 'Morning',
        time: '08:00-14:00',
        memberIds: [
          'maria',
          'sophie',
          'liam',
          'eva',
          'noah',
          'olivia',
          'lucas',
          'mila',
          'finn',
          'sara',
          'jesse',
          'nina',
        ],
      ),
      PosStaffShift(
        id: PosStaffShift.afternoon,
        name: 'Afternoon',
        time: '14:00-20:00',
        memberIds: [
          'thomas',
          'liam',
          'ava',
          'emma',
          'noah',
          'sophie',
          'lucas',
          'mila',
          'finn',
          'sara',
          'jesse',
        ],
      ),
      PosStaffShift(
        id: PosStaffShift.evening,
        name: 'Evening',
        time: '20:00-22:00',
        memberIds: [
          'maria',
          'thomas',
          'noah',
          'liam',
          'sophie',
          'ava',
          'emma',
          'olivia',
          'lucas',
          'mila',
          'finn',
          'sara',
          'jesse',
        ],
      ),
    ];

    return PosStaffRoster(members: members, shifts: shifts);
  }
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
}

/// Passcode helper — four digits, unique across the roster.
class PosStaffPasscode {
  PosStaffPasscode._();

  static const int length = 4;

  static String generate(
    Iterable<String> taken, {
    Random? random,
  }) {
    final Random rng = random ?? Random();
    final Set<String> used = taken.toSet();
    // 10k codes, a roster of dozens — collisions are rare, but bounded retries
    // keep this from spinning if a venue ever fills the space.
    for (int i = 0; i < 200; i++) {
      final String code = rng.nextInt(10000).toString().padLeft(length, '0');
      if (!used.contains(code)) return code;
    }
    return rng.nextInt(10000).toString().padLeft(length, '0');
  }
}
