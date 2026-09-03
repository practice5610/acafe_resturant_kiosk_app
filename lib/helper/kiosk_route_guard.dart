import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_manager_provider.dart';
import 'package:acafe_customer/features/pos/domain/pos_route_policy.dart';
import 'package:acafe_customer/features/pos/domain/pos_routes.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:provider/provider.dart';

/// Web-only route protection for the kiosk flow.
/// Native apps keep using bootstrap/login screen redirects.
class KioskRouteGuard {
  KioskRouteGuard._();

  static const Set<String> publicPaths = {
    RouterHelper.dashboard,
    RouterHelper.splashScreen,
    RouterHelper.kioskBootstrapScreen,
    RouterHelper.kioskLoginScreen,
    RouterHelper.loginScreen,
    RouterHelper.maintain,
    RouterHelper.update,
    RouterHelper.languageScreen,
  };

  /// Paths that only make sense while the device is *not* bound to a branch.
  /// Once it is logged in these all bounce to the welcome screen, so the
  /// browser Back button can never land back on the login form.
  static const Set<String> _authEntryPaths = {
    RouterHelper.dashboard,
    RouterHelper.splashScreen,
    RouterHelper.loginScreen,
    RouterHelper.kioskLoginScreen,
  };

  /// Returns a redirect path, or null when navigation may proceed.
  static String? redirect(BuildContext context, String path) {
    // POS branch, evaluated first so a POS-category device never falls through
    // into the kiosk funnel below. Purely additive: for a kiosk-category device
    // `isPosDevice` is false and no `/pos-` path is ever resolved, so the
    // original logic runs unchanged.
    final KioskAuthProvider auth =
        Provider.of<KioskAuthProvider>(context, listen: false);
    if (auth.isPosDevice || PosRoutes.matches(path)) {
      return _posRedirect(
        context,
        path,
        isPosDevice: auth.isPosDevice,
        isLoggedIn: auth.isLoggedIn(),
      );
    }

    final bool isAuthEntry = path.isEmpty || _authEntryPaths.contains(path);

    if (!kIsWeb) {
      // Native keeps the old behaviour: '/' and '/login' funnel to kiosk login.
      if (isAuthEntry && path != RouterHelper.kioskLoginScreen) {
        return RouterHelper.kioskLoginScreen;
      }
      return null;
    }

    final isLoggedIn =
        Provider.of<KioskAuthProvider>(context, listen: false).isLoggedIn();

    // Already bound to a branch -> the login screen is unreachable. This is what
    // stops browser Back (and a manually typed /kiosk-login) from showing the
    // login form again after a successful device login. `/kiosk-start` is
    // deliberately not in this set: bootstrap still needs to run so it can
    // re-validate the session.
    if (isLoggedIn && isAuthEntry) {
      return RouterHelper.kioskWelcomeScreen;
    }

    if (isAuthEntry && path != RouterHelper.kioskLoginScreen) {
      return RouterHelper.kioskLoginScreen;
    }

    if (publicPaths.contains(path)) return null;

    if (!isLoggedIn) {
      return RouterHelper.kioskLoginScreen;
    }

    return null;
  }

  /// Gathers the three booleans the POS routing rules depend on and defers the
  /// decision to [PosRoutePolicy], which is pure and unit-tested.
  static String? _posRedirect(
    BuildContext context,
    String path, {
    required bool isPosDevice,
    required bool isLoggedIn,
  }) {
    return PosRoutePolicy.redirect(
      path: path,
      isPosDevice: isPosDevice,
      isLoggedIn: isLoggedIn,
      // In-memory by design: a reload re-locks the terminal, which is the point
      // of a shift PIN on a counter device left unattended.
      isPinVerified: isPosDevice &&
          Provider.of<KioskManagerProvider>(context, listen: false)
              .isPinVerified,
      kioskLoginPath: RouterHelper.kioskLoginScreen,
      kioskWelcomePath: RouterHelper.kioskWelcomeScreen,
    );
  }
}
