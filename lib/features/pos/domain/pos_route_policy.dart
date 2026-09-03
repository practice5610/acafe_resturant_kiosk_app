import 'package:acafe_customer/features/pos/domain/pos_routes.dart';

/// Where a POS-category device may go, as a pure function.
///
/// Kept free of `BuildContext` on purpose: routing rules are the part of this
/// feature most likely to be got subtly wrong (a redirect loop, a Back button
/// that re-locks the till mid-sale), and they are only cheap to test if the
/// decision does not need a widget tree to make it. [KioskRouteGuard] gathers
/// the three booleans and calls this.
///
/// Returns a path to redirect to, or null to allow navigation.
class PosRoutePolicy {
  PosRoutePolicy._();

  /// Paths whose meaning outranks both gates. A terminal in maintenance or
  /// forced update has to be able to say so.
  static const Set<String> passthroughPaths = {
    '/maintain',
    '/update',
  };

  static String? redirect({
    required String path,
    required bool isPosDevice,
    required bool isLoggedIn,
    required bool isPinVerified,
    required String kioskLoginPath,
    required String kioskWelcomePath,
  }) {
    // A kiosk device that lands on a POS path — a stale bookmark, a typed URL —
    // goes back to its own tree rather than being shown a staff interface.
    if (!isPosDevice) {
      return isLoggedIn ? kioskWelcomePath : kioskLoginPath;
    }

    if (passthroughPaths.contains(path)) return null;

    // Gate 1: the terminal must be bound to a branch. Device login is shared
    // with kiosk — same screen, same endpoint, only the destination differs.
    if (!isLoggedIn) {
      return path == kioskLoginPath ? null : kioskLoginPath;
    }

    // Gate 2: the shift PIN (the device's `configuration_code`).
    if (!isPinVerified) {
      return path == PosRoutes.login ? null : PosRoutes.login;
    }

    // Unlocked. The PIN screen becomes unreachable so a stray Back cannot
    // re-lock the till mid-sale, and any kiosk path this device wandered onto
    // resolves to the POS home.
    if (path == PosRoutes.login || !PosRoutes.matches(path)) {
      return PosRoutes.home;
    }

    return null;
  }
}
