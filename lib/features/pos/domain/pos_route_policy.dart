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

  /// Reachable only by a Manager/Owner (or an Employee with a temporary
  /// step-up grant) — see `PosSessionProvider.canAccessManagerTabs`. Hiding
  /// the tab in the nav bar stops a tap; this stops a typed URL or Back.
  static const Set<String> managerOnlyPaths = {
    PosRoutes.report,
    PosRoutes.settings,
  };

  static String? redirect({
    required String path,
    required bool isPosDevice,
    required bool isLoggedIn,
    required String kioskLoginPath,
    required String kioskWelcomePath,
    bool canAccessManagerTabs = true,
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

    // Logged in: the till is usable by anyone at the counter (POS, Orders,
    // Receipts) with no PIN gate. Any kiosk path this device wandered onto
    // resolves to the POS home.
    if (!PosRoutes.matches(path)) {
      return PosRoutes.home;
    }

    // Gate 2: Report/Settings are Manager/Owner-only, reached only via the
    // nav bar's lock icon (a temporary step-up grant) — see
    // `PosSessionProvider.canAccessManagerTabs`. An Employee typing the URL
    // or hitting Back into one of these lands on the home tab rather than
    // seeing a locked/broken screen.
    if (managerOnlyPaths.contains(path) && !canAccessManagerTabs) {
      return PosRoutes.home;
    }

    return null;
  }
}
