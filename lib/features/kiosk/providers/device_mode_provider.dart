import 'dart:async';

import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/device_mode_repo.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_manager_provider.dart';
import 'package:acafe_customer/features/kiosk/widgets/device_mode_curtain.dart';
import 'package:acafe_customer/features/pos/domain/pos_routes.dart';
import 'package:acafe_customer/features/pos/domain/pos_sale_session.dart';
import 'package:acafe_customer/features/pos/domain/pos_staff_session.dart';
import 'package:acafe_customer/features/pos/providers/pos_session_provider.dart';
import 'package:acafe_customer/features/pos/providers/pos_staff_session_provider.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// What a switch attempt came to. [message] is short enough for the PIN pad's
/// one-line status, and null on success.
class DeviceModeSwitchResult {
  final bool ok;
  final String? message;

  const DeviceModeSwitchResult.ok()
      : ok = true,
        message = null;

  const DeviceModeSwitchResult.refused(this.message) : ok = false;
}

/// Which side a switch is heading to. The curtain names it.
enum DeviceModeTarget { pos, kiosk }

/// POS ⇄ Kiosk on this till (POS_KIOSK_MODE_PHASE1.md §5).
///
/// The server holds the mode and enforces it; this asks it to switch, then
/// brings the till in line. Going into kiosk mode ends everything staff-shaped
/// on the till -- the signed-in member, both manager unlocks, the open ticket --
/// so nothing of the POS is left for a customer. Coming back hands the till to
/// the member whose PIN brought it back.
///
/// Every switch runs behind [curtain] (DeviceModeCurtain): the mode, staff
/// session, image setting and route change one after another, and none of
/// those in-between states is ever painted.
class DeviceModeProvider extends ChangeNotifier {
  final DeviceModeRepo repo;
  final KioskAuthProvider auth;
  final PosStaffSessionProvider staff;
  final PosSessionProvider posSession;
  final KioskManagerProvider kioskManager;
  final CartProvider cart;

  /// How long the curtain takes to become opaque before anything changes.
  final Duration curtainFade;

  /// How long after navigating the curtain stays up: the page slide
  /// (AppSlidePageTransitionsBuilder, 250ms) plus a frame, so the outgoing page
  /// is never painted under the new shell.
  final Duration landingDelay;

  final void Function(String path) _navigate;

  DeviceModeProvider({
    required this.repo,
    required this.auth,
    required this.staff,
    required this.posSession,
    required this.kioskManager,
    required this.cart,
    this.curtainFade = DeviceModeCurtain.fade,
    this.landingDelay = const Duration(milliseconds: 300),
    void Function(String path)? navigate,
    DioClient? dioClient,
    VoidCallback? onStaleMode,
  }) : _navigate = navigate ?? _goRouter {
    final Dio? dio = dioClient?.dio;
    if (dio != null && onStaleMode != null) {
      dio.interceptors.add(_StaleModeInterceptor(onStaleMode));
    }
  }

  static void _goRouter(String path) => RouterHelper.goRoutes.go(path);

  /// A curtain nobody lowered (a navigation that threw) comes down by itself.
  static const Duration _curtainTimeout = Duration(seconds: 6);

  bool _busy = false;
  bool get busy => _busy;

  bool _curtain = false;
  bool _covering = false;
  DeviceModeTarget? _target;
  Timer? _curtainTimeoutTimer;

  /// The curtain is up, or fading in.
  bool get curtain => _curtain;

  /// The curtain is opaque: the screen underneath is offstage.
  bool get curtainCovering => _covering;

  DeviceModeTarget? get curtainTarget => _target;

  // ── POS → Kiosk ───────────────────────────────────────────────────────

  /// [show] moves the screen to the kiosk. It runs after the mode has flipped
  /// and before the till is torn down, so the POS is never on screen signed out.
  Future<DeviceModeSwitchResult> switchToKiosk({Future<void> Function()? show}) async {
    if (_busy) return const DeviceModeSwitchResult.refused(null);
    _setBusy(true);
    auth.holdKioskMode = true;
    try {
      final DeviceModeResponse response = await repo.enterKiosk();

      if (response.ok) {
        await _raiseCurtain(DeviceModeTarget.kiosk);
        await auth.applyKioskMode(true);
        await _enterKiosk(show);
        return const DeviceModeSwitchResult.ok();
      }

      // The answer never arrived: ask the server what happened rather than
      // guess, so a lost response cannot leave the screen and server apart.
      if (response.statusCode == null) {
        await _raiseCurtain(DeviceModeTarget.kiosk);
        auth.holdKioskMode = false;
        await auth.refreshDeviceSettings();
        if (auth.kioskModeActive) {
          await _enterKiosk(show);
          return const DeviceModeSwitchResult.ok();
        }
        _lowerCurtain();
        return const DeviceModeSwitchResult.refused('No connection · try again');
      }

      return DeviceModeSwitchResult.refused(
          response.errorMessage ?? 'This till could not switch to kiosk mode.');
    } finally {
      auth.holdKioskMode = false;
      _setBusy(false);
    }
  }

  Future<void> _enterKiosk(Future<void> Function()? show) async {
    await show?.call();
    await _tearDownTill();
    landed();
  }

  // ── Kiosk → POS ───────────────────────────────────────────────────────

  /// On success the curtain stays up: the caller closes the PIN pad, moves to
  /// the till and calls [landed].
  Future<DeviceModeSwitchResult> switchToPos(String pin) async {
    if (_busy) return const DeviceModeSwitchResult.refused(null);
    _setBusy(true);
    auth.holdKioskMode = true;
    try {
      final DeviceModeResponse response = await repo.exitKiosk(pin);

      if (response.ok) {
        await _raiseCurtain(DeviceModeTarget.pos);
        final Object? session = response.data?['staff_session'];
        final Map? sessionJson = session is Map ? session : null;
        final PosStaffSession? member = PosStaffSession.fromJson(sessionJson?['staff']);
        final String token = (sessionJson?['token'] ?? '').toString();
        if (member != null && token.isNotEmpty) {
          await staff.adoptSession(
            member,
            token,
            DateTime.tryParse('${sessionJson?['expires_at']}'),
          );
        }
        await _backToPos();
        return const DeviceModeSwitchResult.ok();
      }

      if (response.statusCode == null) {
        return const DeviceModeSwitchResult.refused('No connection · try again');
      }

      // The server already has this till as a POS (the panel brought it back
      // while this screen missed the push). Catch up rather than refuse: the
      // till opens on its PIN screen, where staff sign in as usual.
      if (response.errorCode == 'not-in-kiosk-mode') {
        await _raiseCurtain(DeviceModeTarget.pos);
        auth.holdKioskMode = false;
        await auth.refreshDeviceSettings();
        if (!auth.kioskModeActive) {
          await _backToPos();
          return const DeviceModeSwitchResult.ok();
        }
        _lowerCurtain();
      }

      return DeviceModeSwitchResult.refused(_exitRefusal(response));
    } finally {
      auth.holdKioskMode = false;
      _setBusy(false);
    }
  }

  String _exitRefusal(DeviceModeResponse response) {
    final Map<String, dynamic> error = response.error;
    switch (response.errorCode) {
      case 'incorrect-pin':
        // The wrong PIN that tripped the lock says so now, not on the next try.
        if (error['locked_out'] == true) return _lockedCopy(error);
        final int left = int.tryParse('${error['attempts_remaining']}') ?? 0;
        return left > 0 ? 'Wrong PIN · $left ${left == 1 ? 'try' : 'tries'} left' : 'Wrong PIN';
      case 'exit-locked':
        return _lockedCopy(error);
      case 'invalid-pin':
        return 'Enter your 4-digit PIN';
      default:
        return response.errorMessage ?? 'Something went wrong';
    }
  }

  String _lockedCopy(Map<String, dynamic> error) {
    if (error['requires_panel_reset'] == true) {
      return 'Locked · use Return to POS in admin';
    }
    final int seconds = int.tryParse('${error['retry_after_seconds']}') ?? 0;
    final int minutes = (seconds / 60).ceil().clamp(1, 1 << 30);
    return 'Locked · try again in $minutes min';
  }

  // ── A switch made somewhere else ──────────────────────────────────────

  /// The mode changed without this till asking (Return to POS in the panel, or
  /// a switch whose response was lost): bring the till in line and move the
  /// screen. A switch this till started handles itself -- the server's echo of
  /// it must not start a second transition.
  Future<void> afterRemoteSwitch() async {
    if (_busy) return;
    if (auth.kioskModeActive) {
      // The mode has already flipped under the screen: cover it at once.
      await _raiseCurtain(DeviceModeTarget.kiosk, instant: true);
      // Move first: the POS must never sit on screen signed out.
      _navigate(RouterHelper.kioskWelcomeScreen);
      await _tearDownTill();
    } else {
      await _raiseCurtain(DeviceModeTarget.pos, instant: true);
      // Roster first: the PIN screen must be right when the till appears.
      await _backToPos();
      _navigate(PosRoutes.home);
    }
    landed();
  }

  // ── Curtain ───────────────────────────────────────────────────────────

  /// Covers the screen before anything changes. [instant] when the change has
  /// already happened under it.
  Future<void> _raiseCurtain(DeviceModeTarget target, {bool instant = false}) async {
    _target = target;
    _curtain = true;
    _covering = instant;
    _curtainTimeoutTimer?.cancel();
    _curtainTimeoutTimer = Timer(_curtainTimeout, _lowerCurtain);
    notifyListeners();
    if (instant) return;
    if (curtainFade > Duration.zero) await Future<void>.delayed(curtainFade);
    _covering = true;
    notifyListeners();
  }

  /// The destination is on screen. The curtain lifts once its page has
  /// finished sliding in.
  void landed() {
    if (!_curtain) return;
    Timer(landingDelay, _lowerCurtain);
  }

  void _lowerCurtain() {
    _curtainTimeoutTimer?.cancel();
    _curtainTimeoutTimer = null;
    if (!_curtain && !_covering) return;
    _curtain = false;
    _covering = false;
    notifyListeners();
  }

  /// The till is a POS again. Whatever a customer left in the basket is not
  /// the till's ticket, and the branch's staff-login switch has to be read
  /// afresh: asked while the till was a kiosk, the server refused, which the
  /// staff session reads as "no staff login" -- and a till that believed that
  /// would skip its PIN screen.
  Future<void> _backToPos() async {
    cart.clearCartList();
    await auth.applyKioskMode(false);
    await staff.refreshRoster();
  }

  /// Everything a customer must not inherit. The server has already killed
  /// every staff session from before the switch; this drops them on screen.
  Future<void> _tearDownTill() async {
    await staff.signOut();
    posSession.lock();
    kioskManager.lockManagerAccess();
    cart.clearCartList();
    PosSaleSession.instance.reset();
  }

  void _setBusy(bool value) {
    _busy = value;
    notifyListeners();
  }
}

/// A staff endpoint answering `device-not-in-pos-mode` means the server has
/// this till as a kiosk while the screen still shows the POS -- a switch whose
/// response was lost. Ask once to reconcile; the realtime layer moves the
/// screen.
class _StaleModeInterceptor extends Interceptor {
  final VoidCallback onStaleMode;
  DateTime? _last;

  _StaleModeInterceptor(this.onStaleMode);

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _inspect(response.statusCode, response.data);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _inspect(err.response?.statusCode, err.response?.data);
    handler.next(err);
  }

  void _inspect(int? status, Object? data) {
    if (status != 403 || data is! Map || data['errors'] is! List) return;
    final List errors = data['errors'] as List;
    if (errors.isEmpty || errors.first is! Map) return;
    if ((errors.first as Map)['code'] != 'device-not-in-pos-mode') return;

    // A screen full of refused requests is one problem, not twenty.
    final DateTime now = DateTime.now();
    if (_last != null && now.difference(_last!) < const Duration(seconds: 5)) return;
    _last = now;
    onStaleMode();
  }
}
