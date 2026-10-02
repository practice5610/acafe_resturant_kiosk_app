import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// An in-memory stand-in for the POS staff API, honouring the real contract
/// (shapes taken from PosStaffController on the backend).
///
/// Widget tests used to exercise a provider that wrote locally first. Now that
/// the server mints roster ids and owns PIN uniqueness, a test that wants to see
/// "hire → appears on the shift board" needs something that answers like the
/// server does. This is that, and nothing more: it validates what the real
/// controller validates and returns what it returns.
class FakePosStaffBackend implements HttpClientAdapter {
  FakePosStaffBackend({
    List<Map<String, dynamic>>? members,
    this.branchName = 'Amsterdam',
    this.staffLoginRequired = false,
    List<Map<String, dynamic>>? rolesOverride,
  })  : _members = members ?? figmaDemoMembers(),
        _roles = rolesOverride ?? roles;

  /// The roles this backend serves from the catalogue. Defaults to [roles]; a
  /// test can pass an empty list to exercise the "no roles available" path, or
  /// change it mid-test via [setRoles] to mimic an admin creating roles after
  /// the POS screen has already mounted.
  List<Map<String, dynamic>> _roles;

  /// Mimic the admin panel adding roles after the POS screen hydrated.
  void setRoles(List<Map<String, dynamic>> roles) => _roles = roles;

  final List<Map<String, dynamic>> _members;
  final String branchName;
  bool staffLoginRequired;

  /// PINs the fake "stores", so uniqueness and sign-in can be checked. A real
  /// server keeps only hashes; the fake keeps plain values because it is a fake.
  final Map<String, String> _pins = {};

  /// Every request seen, for assertions about what the app actually sent.
  final List<RequestOptions> requests = [];

  // Sign-in state, mirroring PosStaffTokenService: five wrong PINs per device
  // lock it out; tokens are opaque and re-checked against the live member.
  int failedPins = 0;
  int lockoutSeconds = 0;
  final Map<String, String> _tokens = {};
  int _tokenSeq = 0;

  /// Deactivate a member, as a manager would in the admin panel.
  void deactivate(String memberId) => _find(memberId)?['active'] = false;

  static const List<Map<String, dynamic>> permissions = [
    {'key': 'process_refunds', 'label': 'Process refunds', 'description': ''},
    {'key': 'apply_discounts', 'label': 'Apply discounts', 'description': ''},
    {'key': 'void_orders', 'label': 'Void orders', 'description': ''},
    {'key': 'access_reports', 'label': 'Access reports', 'description': ''},
    {'key': 'manage_inventory', 'label': 'Manage inventory', 'description': ''},
    {'key': 'access_cash_drawer', 'label': 'Access cash drawer', 'description': ''},
    {'key': 'manage_staff', 'label': 'Manage staff', 'description': ''},
    {'key': 'close_day', 'label': 'Close day', 'description': ''},
    {'key': 'view_orders', 'label': 'View orders', 'description': ''},
    {'key': 'manage_orders', 'label': 'Manage orders', 'description': ''},
    {'key': 'manage_item_status', 'label': 'Manage item status', 'description': ''},
    {'key': 'manage_settings', 'label': 'Manage POS settings', 'description': ''},
  ];

  static const List<Map<String, dynamic>> roles = [
    {'id': 14, 'name': 'Owner'},
    {'id': 15, 'name': 'Manager'},
    {'id': 16, 'name': 'Employee'},
  ];

  static const List<Map<String, dynamic>> shiftDefs = [
    {'id': 'morning', 'name': 'Morning', 'time': '08:00-14:00'},
    {'id': 'afternoon', 'name': 'Afternoon', 'time': '14:00-20:00'},
    {'id': 'evening', 'name': 'Evening', 'time': '20:00-22:00'},
  ];

  void setPin(String memberId, String pin) {
    _pins[memberId] = pin;
    _find(memberId)?['has_pin'] = true;
  }

  Map<String, dynamic>? member(String id) => _find(id);

  Map<String, dynamic>? _find(String id) {
    for (final m in _members) {
      if (m['id'] == id) return m;
    }
    return null;
  }

  String _slug(String name) {
    final String base = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final String seed = base.isEmpty ? 'staff' : base;
    if (_find(seed) == null) return seed;
    int n = 2;
    while (_find('$seed-$n') != null) {
      n++;
    }
    return '$seed-$n';
  }

  Map<String, dynamic> _roster() {
    final Map<String, List<String>> byShift = {
      for (final s in shiftDefs) s['id'] as String: <String>[],
    };
    for (final m in _members) {
      for (final String shift in List<String>.from(m['shift_ids'] as List)) {
        byShift[shift]?.add(m['id'] as String);
      }
    }
    return {
      'members': _members.map(_public).toList(),
      'shifts': [
        for (final s in shiftDefs) {...s, 'member_ids': byShift[s['id']]},
      ],
    };
  }

  /// The PIN never leaves the server, so the fake never returns it either.
  Map<String, dynamic> _public(Map<String, dynamic> m) =>
      Map<String, dynamic>.from(m)..remove('pin');

  bool _pinTaken(String pin, {String? exceptId}) {
    for (final entry in _pins.entries) {
      if (entry.key != exceptId && entry.value == pin) return true;
    }
    return false;
  }

  ResponseBody _json(int status, Object body) => ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  ResponseBody _error(int status, String code, String message, [Map<String, dynamic> extra = const {}]) =>
      _json(status, {
        'errors': [
          {'code': code, 'message': message, ...extra},
        ],
      });

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final String path = Uri.parse(options.path).path;
    final String method = options.method.toUpperCase();
    final Map<String, dynamic> data = options.data is Map
        ? Map<String, dynamic>.from(options.data as Map)
        : <String, dynamic>{};

    const String base = '/api/v1/kiosk/manager/staff';

    if (method == 'GET' && path.endsWith('$base/catalogue')) {
      return _json(200, {
        'permissions': permissions,
        'roles': _roles,
        'shifts': shiftDefs,
        'branch': {
          'id': 1,
          'name': branchName,
          'staff_login_required': staffLoginRequired,
        },
        'pin_length': 4,
      });
    }

    if (method == 'GET' && path.endsWith(base)) {
      return _json(200, _roster());
    }

    if (method == 'GET' && path.endsWith('$base/sign-in-roster')) {
      return _json(200, {
        'staff_login_required': staffLoginRequired,
        'pin_length': 4,
        'lockout_seconds': lockoutSeconds,
        'roles': _roles,
        'members': [
          for (final m in _members)
            if (m['active'] == true && _pins.containsKey(m['id']))
              {
                'id': m['id'],
                'name': m['name'],
                'initials': _initials(m['name'] as String),
              },
        ],
      });
    }

    if (method == 'POST' && path.endsWith('$base/sign-in')) {
      if (lockoutSeconds > 0) {
        return _error(429, 'locked-out', 'Too many wrong PINs. Try again shortly.',
            {'retry_after_seconds': lockoutSeconds});
      }
      final String pin = (data['pin'] ?? '').toString();
      final String? memberId = data['member_id']?.toString();
      // Optional role binding, mirroring PosStaffTokenService::staffForPin: when
      // a role is sent, only members of that role are candidates. An unknown role
      // id matches nobody, so it reads as a wrong PIN (never a 500).
      final int? roleId = data['role'] == null ? null : int.tryParse('${data['role']}');
      final bool roleValid = roleId == null || _roles.any((r) => r['id'] == roleId);
      String? matched;
      if (roleValid) {
        for (final entry in _pins.entries) {
          final Map<String, dynamic>? m = _find(entry.key);
          if (m == null || m['active'] != true) continue;
          if (memberId != null && memberId.isNotEmpty && entry.key != memberId) continue;
          if (roleId != null && m['role_id'] != roleId) continue;
          if (entry.value == pin) matched = entry.key;
        }
      }
      // The Employee/Manager button, mirroring PosStaffController::signInGroup:
      // a matched account must be in the tapped group or it reads as a wrong PIN.
      final String? group = data['group']?.toString();
      if (matched != null && (group == 'manager' || group == 'employee')) {
        if (_groupFor(matched) != group) matched = null;
      }
      if (matched == null) {
        failedPins++;
        final bool locked = failedPins >= 5;
        if (locked) lockoutSeconds = 300;
        return _error(422, 'incorrect-pin', 'That PIN was not recognised.', {
          'attempts_remaining': (5 - failedPins).clamp(0, 5),
          'locked_out': locked,
          'retry_after_seconds': lockoutSeconds,
        });
      }
      failedPins = 0;
      final String token = 'tok-${++_tokenSeq}';
      _tokens[token] = matched;
      return _json(200, {
        'token': token,
        'expires_at': DateTime.now().add(const Duration(hours: 12)).toIso8601String(),
        'staff': _sessionPayload(matched),
      });
    }

    if (method == 'GET' && path.endsWith('$base/me')) {
      final String? token = options.headers['X-Staff-Token']?.toString();
      final String? id = token == null ? null : _tokens[token];
      final Map<String, dynamic>? m = id == null ? null : _find(id);
      if (m == null || m['active'] != true) {
        return _error(401, 'no-staff-session', 'Sign in to continue.');
      }
      return _json(200, {'staff': _sessionPayload(id!)});
    }

    if (method == 'POST' && path.endsWith('$base/sign-out')) {
      return _json(200, {'success': true});
    }

    if (method == 'POST' && path.endsWith('$base/members')) {
      final String name = (data['name'] ?? '').toString().trim();
      if (name.isEmpty) return _error(422, 'validation', 'Name is required.');
      final String? pin = data['pin']?.toString();
      if (pin != null && pin.isNotEmpty && _pinTaken(pin)) {
        return _error(422, 'validation', 'Another staff member in this branch already uses that PIN.');
      }
      final int roleId = int.tryParse('${data['role_id']}') ?? 16;
      final String roleName = roles.firstWhere(
        (r) => r['id'] == roleId,
        orElse: () => roles.last,
      )['name'] as String;
      final String id = _slug(name);
      final Map<String, dynamic> m = {
        'id': id,
        'name': name,
        'role': roleName,
        'role_id': roleId,
        'active': true,
        'has_pin': pin != null && pin.isNotEmpty,
        'permissions': _presetFor(roleName),
        'shift_ids': List<String>.from((data['shift_ids'] as List?) ?? const []),
      };
      _members.add(m);
      if (pin != null && pin.isNotEmpty) _pins[id] = pin;
      return _json(201, {'member': _public(m)});
    }

    final RegExpMatch? pinMatch = RegExp('$base/members/([^/]+)/pin\$').firstMatch(path);
    if (method == 'PUT' && pinMatch != null) {
      final String id = pinMatch.group(1)!;
      if (_find(id) == null) return _error(404, 'not-found', 'Not on this branch.');
      final String pin = (data['pin'] ?? '').toString();
      if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
        return _error(422, 'validation', 'The PIN must be exactly 4 digits.');
      }
      if (_pinTaken(pin, exceptId: id)) {
        return _error(422, 'validation', 'Another staff member in this branch already uses that PIN.');
      }
      setPin(id, pin);
      return _json(200, {'member': _public(_find(id)!)});
    }

    final RegExpMatch? memberMatch = RegExp('$base/members/([^/]+)\$').firstMatch(path);
    if (memberMatch != null) {
      final String id = memberMatch.group(1)!;
      final Map<String, dynamic>? m = _find(id);
      if (m == null) return _error(404, 'not-found', 'Not on this branch.');

      if (method == 'PATCH') {
        if (data.containsKey('name')) m['name'] = data['name'];
        if (data.containsKey('active')) m['active'] = data['active'] == true;
        if (data.containsKey('shift_ids')) {
          m['shift_ids'] = List<String>.from(data['shift_ids'] as List);
        }
        if (data.containsKey('permissions')) {
          m['permissions'] = Map<String, dynamic>.from(data['permissions'] as Map);
        }
        if (data.containsKey('role_id')) {
          final int roleId = int.tryParse('${data['role_id']}') ?? 0;
          for (final r in roles) {
            if (r['id'] == roleId) {
              m['role_id'] = roleId;
              m['role'] = r['name'];
            }
          }
        }
        return _json(200, {'member': _public(m)});
      }

      if (method == 'DELETE') {
        _members.remove(m);
        _pins.remove(id);
        return _json(200, {'success': true, 'removed': 'staff_record'});
      }
    }

    return _error(404, 'not-found', 'No fake route for $method $path');
  }

  /// 'manager' when the member can open Report or Settings, else 'employee' --
  /// the same permission set PosStaffController::signInGroup uses.
  static const List<String> _managerPermissions = [
    'access_reports',
    'manage_settings',
    'manage_staff',
    'manage_inventory',
  ];

  String _groupFor(String id) {
    final Object? perms = _find(id)?['permissions'];
    final Map<String, dynamic> map =
        perms is Map ? Map<String, dynamic>.from(perms) : const {};
    for (final String key in _managerPermissions) {
      if (map[key] == true) return 'manager';
    }
    return 'employee';
  }

  Map<String, dynamic> _sessionPayload(String id) {
    final Map<String, dynamic> m = _find(id)!;
    return {
      'id': id,
      'staff_id': _members.indexOf(m) + 100,
      'name': m['name'],
      'initials': _initials(m['name'] as String),
      'role': m['role'],
      'permissions': m['permissions'],
    };
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final String first = parts.first.substring(0, 1);
    final String last = parts.length > 1 ? parts.last.substring(0, 1) : '';
    return (first + last).toUpperCase();
  }

  Map<String, bool> _presetFor(String role) {
    final List<String> keys = [for (final p in permissions) p['key'] as String];
    switch (role) {
      case 'Owner':
        return {for (final k in keys) k: true};
      case 'Manager':
        return {for (final k in keys) k: k != 'manage_staff'};
      default:
        const granted = {
          'apply_discounts', 'access_cash_drawer', 'view_orders',
          'manage_orders', 'manage_item_status',
        };
        return {for (final k in keys) k: granted.contains(k)};
    }
  }

  @override
  void close({bool force = false}) {}

  /// The legacy Figma demo roster: 15 people across three shifts. It used to
  /// live in production code as PosStaffRoster.seed(); it is fixture data, so it
  /// lives with the tests now.
  static List<Map<String, dynamic>> figmaDemoMembers() {
    Map<String, dynamic> m(String id, String name, String role, List<String> shifts,
        {bool active = true}) {
      final backend = FakePosStaffBackend(members: const []);
      return {
        'id': id,
        'name': name,
        'role': role,
        'role_id': roles.firstWhere((r) => r['name'] == role)['id'],
        'active': active,
        'has_pin': false,
        'permissions': backend._presetFor(role),
        'shift_ids': shifts,
      };
    }

    const mo = 'morning', af = 'afternoon', ev = 'evening';
    return [
      m('maria', 'Maria van den Berg', 'Owner', [mo, ev]),
      m('thomas', 'Thomas de Vries', 'Manager', [af, ev]),
      m('sophie', 'Sophie Jansen', 'Employee', [mo, af, ev]),
      m('liam', 'Liam Bakker', 'Employee', [mo, af, ev]),
      m('emma', 'Emma Visser', 'Employee', [af, ev], active: false),
      m('eva', 'Eva Smit', 'Employee', [mo]),
      m('noah', 'Noah Dekker', 'Employee', [mo, af, ev]),
      m('olivia', 'Olivia Meijer', 'Employee', [mo, ev]),
      m('lucas', 'Lucas Bos', 'Employee', [mo, af, ev]),
      m('mila', 'Mila Vos', 'Employee', [mo, af, ev]),
      m('finn', 'Finn Peters', 'Employee', [mo, af, ev]),
      m('sara', 'Sara Willems', 'Employee', [mo, af, ev]),
      m('jesse', 'Jesse Hendriks', 'Employee', [mo, af, ev]),
      m('nina', 'Nina Kuipers', 'Employee', [mo]),
      m('ava', 'Ava Mulder', 'Employee', [af, ev]),
    ];
  }
}
