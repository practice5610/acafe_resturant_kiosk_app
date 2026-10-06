import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/pos/domain/pos_route_policy.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:acafe_customer/features/pos/providers/pos_staff_session_provider.dart';
import 'package:acafe_customer/features/pos/widgets/pos_staff_lock_screen.dart';
import 'package:acafe_customer/features/pos/widgets/pos_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

/// Puts the PIN screen in front of the till when, and only when, it is needed.
///
/// Three conditions, all required: the device itself is logged in (this sits
/// inside [PosShell], which also wraps the device-login screen), the branch has
/// switched staff sign-in on, and nobody is signed in. With the switch off this
/// widget adds nothing to the screen and the till is exactly as it was.
///
/// The POS stays mounted underneath rather than being swapped out, so a sale in
/// progress survives a lock or a change of cashier. It is taken out of hit
/// testing, focus and animation while covered, so nothing behind the lock
/// screen can be reached or keeps ticking.
///
/// Every pointer event on the till resets the idle timer. A Listener, not a
/// GestureDetector, so it observes touches without competing for them.
class PosStaffGate extends StatefulWidget {
  final Widget child;

  const PosStaffGate({super.key, required this.child});

  @override
  State<PosStaffGate> createState() => _PosStaffGateState();
}

class _PosStaffGateState extends State<PosStaffGate> {
  bool _bootstrapRequested = false;

  /// Who was signed in last build. When it changes to a *new* signed-in member
  /// we only need to act if they are sitting on a manager-only route they may
  /// not see (a manager locked the till on Settings, an employee signed in).
  String? _lastStaffId;

  void _ensureBootstrapped(PosStaffSessionProvider session, bool deviceLoggedIn) {
    if (!deviceLoggedIn || session.bootstrapped || _bootstrapRequested) return;
    _bootstrapRequested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) session.bootstrap();
    });
  }

  /// A fresh sign-in starts a new shift, so it returns to the till's home
  /// screen rather than leaving the incoming operator on whatever tab the last
  /// one left open -- and that also covers the old concern of landing someone on
  /// a Report/Settings route their permissions do not cover, since home is
  /// always allowed. Already on home changes nothing and triggers no navigation.
  /// A post-frame `context.go` (not `goRoutes.refresh()`) so sign-in does not
  /// shove the router mid-transition.
  void _landOnHomeAfterSignIn(PosStaffSessionProvider session) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || session.session == null) return;

      final String path =
          RouterHelper.goRoutes.routeInformationProvider.value.uri.path;
      final String? dest = PosRoutePolicy.landingAfterSignIn(path);
      // Only when this subtree is actually under a router -- a sign-in harness
      // that mounts the gate on its own (no GoRouter) must not crash here.
      if (dest != null && GoRouter.maybeOf(context) != null) {
        context.go(dest);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final PosStaffSessionProvider? session =
        Provider.of<PosStaffSessionProvider?>(context);
    final KioskAuthProvider? auth = Provider.of<KioskAuthProvider?>(context);

    // Not wired (a test harness, or a build without staff sign-in): pass through.
    if (session == null || auth == null) return widget.child;

    final bool deviceLoggedIn = auth.isLoggedIn();
    if (!deviceLoggedIn) {
      // Device logged out: the next login starts from a fresh read of the
      // branch switch rather than whatever the previous device session saw.
      _bootstrapRequested = false;
      _lastStaffId = null;
      return widget.child;
    }

    _ensureBootstrapped(session, deviceLoggedIn);

    // Until the branch switch has been read, decide nothing from the default
    // "off" roster -- that is exactly what made the PIN flash over the welcome
    // screen. Hold a neutral branded surface instead, no content and no PIN.
    if (!session.bootstrapped) {
      return const ColoredBox(color: PosUI.pageBg, child: SizedBox.expand());
    }

    final bool locked = session.loginRequired && !session.isSignedIn;

    final String? staffId = session.session?.id;
    if (staffId != _lastStaffId) {
      final bool becameSignedIn = staffId != null;
      _lastStaffId = staffId;
      if (becameSignedIn) _landOnHomeAfterSignIn(session);
    }

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => session.touch(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          TickerMode(
            enabled: !locked,
            child: ExcludeFocus(
              excluding: locked,
              child: IgnorePointer(
                ignoring: locked,
                child: ExcludeSemantics(excluding: locked, child: widget.child),
              ),
            ),
          ),
          if (locked) const PosStaffLockScreen(),
        ],
      ),
    );
  }
}
