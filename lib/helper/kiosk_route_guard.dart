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

  /// Returns a redirect path, or null when navigation may proceed.
  static String? redirect(BuildContext context, String path) {
    if (path == RouterHelper.dashboard ||
        path.isEmpty ||
        path == RouterHelper.loginScreen) {
      return RouterHelper.kioskLoginScreen;
    }

    if (!kIsWeb) return null;
    if (publicPaths.contains(path)) return null;

    final isLoggedIn =
        Provider.of<KioskAuthProvider>(context, listen: false).isLoggedIn();
    if (!isLoggedIn) {
      return RouterHelper.kioskLoginScreen;
    }

    return null;
  }
}
