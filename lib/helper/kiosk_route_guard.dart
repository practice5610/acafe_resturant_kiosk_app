import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
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
}
