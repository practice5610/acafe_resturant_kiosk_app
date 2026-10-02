import 'dart:async';

import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/features/pos/domain/pos_staff_session.dart';
import 'package:acafe_customer/features/pos/domain/pos_staff_session_repo.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Who is signed in at this till.
///
/// Sits alongside [PosSessionProvider] rather than replacing it. That one is
/// the device's manager step-up and is exactly as it was; this one only matters
/// on a branch that has switched staff sign-in on. With the switch off, nothing
/// here changes what the till shows or does.
///
/// The staff token rides on every request through an interceptor rather than a
/// default header, because DioClient.updateHeader replaces the whole header map
/// whenever it runs and would silently strip it.
class PosStaffSessionProvider extends ChangeNotifier {
  final PosStaffSessionRepo repo;
  final PosStaffTokenStore tokenStore;

  /// How long the till may sit untouched before it locks itself.
  Duration idleTimeout;

  PosStaffSessionProvider({
    required this.repo,
    PosStaffTokenStore? tokenStore,
    this.idleTimeout = defaultIdleTimeout,
    DioClient? dioClient,
  }) : tokenStore = tokenStore ?? MemoryPosStaffTokenStore() {
    final Dio? dio = dioClient?.dio;
    if (dio != null) {
      dio.interceptors.add(_StaffTokenInterceptor(this));
    }
  }

  static const Duration defaultIdleTimeout = Duration(hours: 3);

  static const String tokenHeader = 'X-Staff-Token';

  PosSignInRoster _roster = PosSignInRoster.off;
  PosStaffSession? _session;
  String? _token;
  bool _bootstrapped = false;
  bool _signingIn = false;
  Timer? _idleTimer;
  Timer? _lockoutTimer;
  int _lockoutSecondsLeft = 0;

  PosSignInRoster get roster => _roster;
  PosStaffSession? get session => _session;
  bool get loginRequired => _roster.staffLoginRequired;
  bool get isSignedIn => _session != null;
  bool get bootstrapped => _bootstrapped;
  bool get signingIn => _signingIn;
  int get lockoutSecondsLeft => _lockoutSecondsLeft;
  bool get isLockedOut => _lockoutSecondsLeft > 0;
  List<PosLockScreenMember> get members => _roster.members;
  List<PosStaffRole> get roles => _roster.roles;
  int get pinLength => _roster.pinLength;

  /// Read by the interceptor for every request.
  String? get token => _token;

  PosAccess access({required bool managerStepUp}) => PosAccess(
        loginRequired: loginRequired,
        managerStepUp: managerStepUp,
        session: _session,
      );

  // ── Bootstrap ─────────────────────────────────────────────────────────

  /// Learns whether this branch asks for staff sign-in, and restores a session
  /// that survived a reload if the server still recognises it.
  Future<void> bootstrap() async {
    final PosSignInRoster? roster = await repo.signInRoster();
    if (roster != null) {
      _roster = roster;
      _startLockout(roster.lockoutSeconds);
    }

    if (loginRequired && _session == null) {
      final String? stored = await tokenStore.read();
      final DateTime? expiry = await tokenStore.readExpiry();
      final bool fresh = expiry == null || DateTime.now().isBefore(expiry);
      if (stored != null && stored.isNotEmpty && fresh) {
        final PosStaffSession? restored = await repo.me(stored);
        if (restored != null) {
          _token = stored;
          _session = restored;
          _armIdleTimer();
        } else {
          await tokenStore.clear();
        }
      } else if (stored != null) {
        await tokenStore.clear();
      }
    }

    if (!loginRequired) {
      // Switch is off: a session left over from when it was on is meaningless
      // now, and keeping its token on requests would be misleading.
      await _dropSession();
    }

    _bootstrapped = true;
    notifyListeners();
  }

  /// Re-reads the branch switch and the faces. Cheap; called when the lock
  /// screen is shown so a newly hired member or a flipped switch appears.
  Future<void> refreshRoster() async {
    final PosSignInRoster? roster = await repo.signInRoster();
    if (roster == null) return;
    _roster = roster;
    if (!loginRequired) await _dropSession();
    notifyListeners();
  }

  // ── Sign in / out ─────────────────────────────────────────────────────

  Future<PosSignInResult> signIn(String pin, {String? memberId, int? roleId}) async {
    if (isLockedOut) {
      return PosSignInResult(
        PosSignInOutcome.lockedOut,
        retryAfterSeconds: _lockoutSecondsLeft,
      );
    }

    _signingIn = true;
    notifyListeners();

    final (session, token, expiresAt, result) =
        await repo.signIn(pin, memberId: memberId, roleId: roleId);

    _signingIn = false;

    if (result.ok && session != null && token != null) {
      _session = session;
      _token = token;
      await tokenStore.write(token, expiresAt);
      _armIdleTimer();
    } else if (result.outcome == PosSignInOutcome.lockedOut) {
      _startLockout(result.retryAfterSeconds);
    }

    notifyListeners();
    return result;
  }

  /// Back to the PIN screen. The till's sale state is untouched -- only who is
  /// operating it changes.
  Future<void> lock() async {
    await _dropSession();
    notifyListeners();
    // Pick up anyone hired, or a switch flipped, since the last time.
    unawaited(refreshRoster());
  }

  /// Same as [lock], and tells the server. There is nothing server-side to
  /// revoke today -- the token is stateless -- but the call exists so that when
  /// there is, the app already makes it.
  Future<void> signOut() async {
    unawaited(repo.signOut());
    await lock();
  }

  /// "Switch user" is a lock with a different verb on the button.
  Future<void> switchUser() => lock();

  /// A request came back saying the session is gone -- deactivated, moved
  /// branch, expired. The till locks rather than carrying on as a ghost.
  void sessionRejected() {
    if (_session == null) return;
    unawaited(lock());
  }

  Future<void> _dropSession() async {
    _session = null;
    _token = null;
    _idleTimer?.cancel();
    _idleTimer = null;
    await tokenStore.clear();
  }

  // ── Idle auto-lock ────────────────────────────────────────────────────

  /// Any touch on the till. Cheap enough to call on every pointer event.
  void touch() {
    if (_session == null) return;
    _armIdleTimer();
  }

  void _armIdleTimer() {
    _idleTimer?.cancel();
    if (!loginRequired || _session == null) return;
    _idleTimer = Timer(idleTimeout, () {
      unawaited(lock());
    });
  }

  // ── Lockout countdown ─────────────────────────────────────────────────

  void _startLockout(int seconds) {
    _lockoutTimer?.cancel();
    _lockoutSecondsLeft = seconds;
    if (seconds <= 0) return;
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      _lockoutSecondsLeft = (_lockoutSecondsLeft - 1).clamp(0, 1 << 30);
      if (_lockoutSecondsLeft == 0) t.cancel();
      notifyListeners();
    });
  }

  @visibleForTesting
  void debugSignIn(PosStaffSession session, {bool loginRequired = true}) {
    _roster = PosSignInRoster(
      staffLoginRequired: loginRequired,
      pinLength: 4,
      lockoutSeconds: 0,
      members: _roster.members,
    );
    _session = session;
    _token = 'test-token';
    _bootstrapped = true;
    notifyListeners();
  }

  @visibleForTesting
  void debugSetRoster(PosSignInRoster roster) {
    _roster = roster;
    _bootstrapped = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _lockoutTimer?.cancel();
    super.dispose();
  }
}

/// Puts the staff token on every request while somebody is signed in, and locks
/// the till if the server says that session is gone.
class _StaffTokenInterceptor extends Interceptor {
  final PosStaffSessionProvider provider;

  _StaffTokenInterceptor(this.provider);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final String? token = provider.token;
    if (token != null &&
        token.isNotEmpty &&
        !options.headers.containsKey(PosStaffSessionProvider.tokenHeader)) {
      options.headers[PosStaffSessionProvider.tokenHeader] = token;
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _inspect(response.data);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _inspect(err.response?.data);
    handler.next(err);
  }

  void _inspect(Object? data) {
    if (data is! Map || data['errors'] is! List) return;
    final List errors = data['errors'] as List;
    if (errors.isEmpty || errors.first is! Map) return;
    if ((errors.first as Map)['code'] == 'no-staff-session') {
      provider.sessionRejected();
    }
  }
}
