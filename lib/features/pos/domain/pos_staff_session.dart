/// Who is signed in at this till, and what they may do.
///
/// Nothing here is authoritative. The server re-checks every request against
/// the staff token, so this model only decides what the screen *shows* — a
/// hidden button is a courtesy, the 403 is the lock.
class PosStaffSession {
  final String id;
  final int staffId;
  final String name;
  final String initials;
  final String role;
  final Map<String, bool> permissions;

  const PosStaffSession({
    required this.id,
    required this.staffId,
    required this.name,
    required this.initials,
    required this.role,
    required this.permissions,
  });

  bool can(String key) => permissions[key] == true;

  static PosStaffSession? fromJson(Object? json) {
    if (json is! Map) return null;
    final String id = (json['id'] ?? '').toString();
    final String name = (json['name'] ?? '').toString();
    if (id.isEmpty || name.isEmpty) return null;

    final Object? raw = json['permissions'];
    return PosStaffSession(
      id: id,
      staffId: int.tryParse('${json['staff_id']}') ?? 0,
      name: name,
      initials: (json['initials'] ?? '').toString().isEmpty
          ? name.trim().substring(0, 1).toUpperCase()
          : json['initials'].toString(),
      role: (json['role'] ?? '').toString(),
      permissions: raw is Map
          ? {for (final e in raw.entries) e.key.toString(): e.value == true}
          : const {},
    );
  }
}

/// A face on the lock screen. Deliberately thin: the sign-in roster is readable
/// before anybody has signed in, so the server sends names and initials only.
class PosLockScreenMember {
  final String id;
  final String name;
  final String initials;

  const PosLockScreenMember({
    required this.id,
    required this.name,
    required this.initials,
  });

  static PosLockScreenMember? fromJson(Object? json) {
    if (json is! Map) return null;
    final String id = (json['id'] ?? '').toString();
    final String name = (json['name'] ?? '').toString();
    if (id.isEmpty || name.isEmpty) return null;
    return PosLockScreenMember(
      id: id,
      name: name,
      initials: (json['initials'] ?? '').toString(),
    );
  }
}

/// The lock screen's view of the branch: whether it asks for a PIN at all, and
/// who may answer.
class PosSignInRoster {
  final bool staffLoginRequired;
  final int pinLength;
  final int lockoutSeconds;
  final List<PosLockScreenMember> members;

  const PosSignInRoster({
    required this.staffLoginRequired,
    required this.pinLength,
    required this.lockoutSeconds,
    required this.members,
  });

  static const PosSignInRoster off = PosSignInRoster(
    staffLoginRequired: false,
    pinLength: 4,
    lockoutSeconds: 0,
    members: [],
  );

  static PosSignInRoster? fromJson(Object? json) {
    if (json is! Map) return null;
    final Object? raw = json['members'];
    return PosSignInRoster(
      staffLoginRequired: json['staff_login_required'] == true,
      pinLength: int.tryParse('${json['pin_length']}') ?? 4,
      lockoutSeconds: int.tryParse('${json['lockout_seconds']}') ?? 0,
      members: raw is List
          ? [
              for (final m in raw)
                if (PosLockScreenMember.fromJson(m) != null)
                  PosLockScreenMember.fromJson(m)!,
            ]
          : const [],
    );
  }
}

/// What the outcome of a PIN attempt means for the lock screen.
enum PosSignInOutcome { signedIn, wrongPin, lockedOut, unavailable }

class PosSignInResult {
  final PosSignInOutcome outcome;
  final String? message;
  final int attemptsRemaining;
  final int retryAfterSeconds;

  const PosSignInResult(
    this.outcome, {
    this.message,
    this.attemptsRemaining = 0,
    this.retryAfterSeconds = 0,
  });

  bool get ok => outcome == PosSignInOutcome.signedIn;
}

/// The single answer to "may this till show or do X right now?".
///
/// Pure on purpose: routing and the nav bar both consult it, and they are only
/// safe to get subtly right if the decision needs no widget tree to test.
///
/// With branch staff sign-in OFF this reproduces today exactly: every action is
/// allowed, and Report and Settings follow the device's manager step-up. With it
/// ON, the signed-in member's permissions decide, and the step-up plays no part.
class PosAccess {
  final bool loginRequired;
  final bool managerStepUp;
  final PosStaffSession? session;

  const PosAccess({
    required this.loginRequired,
    required this.managerStepUp,
    this.session,
  });

  /// Settings is one tab holding several sections, so it opens for anyone who
  /// can change something inside it.
  static const List<String> settingsPermissions = [
    'manage_settings',
    'manage_staff',
    'manage_inventory',
  ];

  bool can(String key) {
    if (!loginRequired) return true;
    return session?.can(key) ?? false;
  }

  bool get canSeeReport =>
      loginRequired ? can('access_reports') : managerStepUp;

  bool get canSeeSettings =>
      loginRequired ? settingsPermissions.any(can) : managerStepUp;

  bool get canManageStaff => loginRequired ? can('manage_staff') : managerStepUp;

  /// True when the till should be showing the PIN screen instead of the POS.
  bool get mustSignIn => loginRequired && session == null;
}
