import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:acafe_customer/features/pos/providers/pos_staff_session_provider.dart';
import 'package:acafe_customer/features/pos/widgets/pos_staff_lock_screen.dart';
import 'package:flutter/material.dart';
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

  /// Who was signed in last build. When it changes, the router's redirect has
  /// to run again: it only re-evaluates on navigation, so a cashier signing in
  /// over a manager who left Settings open would otherwise be left on it.
  String? _lastStaffId;

  void _reroute() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        RouterHelper.goRoutes.refresh();
      } catch (_) {
        // No router in this tree (a test harness): nothing to re-run.
      }
    });
  }

  void _ensureBootstrapped(PosStaffSessionProvider session, bool deviceLoggedIn) {
    if (!deviceLoggedIn || session.bootstrapped || _bootstrapRequested) return;
    _bootstrapRequested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) session.bootstrap();
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
      return widget.child;
    }

    _ensureBootstrapped(session, deviceLoggedIn);

    final bool locked = session.loginRequired && !session.isSignedIn;

    final String? staffId = session.session?.id;
    if (staffId != _lastStaffId) {
      _lastStaffId = staffId;
      _reroute();
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
