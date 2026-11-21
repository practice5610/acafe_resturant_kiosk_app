import 'package:flutter/widgets.dart';

import 'package:acafe_customer/features/kiosk/landscape/kiosk_orientation.dart';
import 'package:acafe_customer/features/kiosk/landscape/screens/landscape_checkout_email_screen.dart';
import 'package:acafe_customer/features/kiosk/landscape/screens/landscape_checkout_name_screen.dart';
import 'package:acafe_customer/features/kiosk/landscape/screens/landscape_menu_screen.dart';
import 'package:acafe_customer/features/kiosk/landscape/screens/landscape_order_summary_screen.dart';
import 'package:acafe_customer/features/kiosk/landscape/screens/landscape_shell_screen.dart';
import 'package:acafe_customer/helper/router_helper.dart';

/// Route for the Phase-1 placeholder landscape shell, used to confirm the switch
/// fires. Landscape-only: in portrait it shows a short "open in landscape" note.
const String kioskLandscapeShellRoute = '/landscape-shell-kiosk';

/// Menu route path (mirrors `RouterHelper.kioskMenuScreen`, kept as a literal so
/// this file has no dependency on the router).
const String _kioskMenuRoute = '/menu-kiosk';

/// Landscape screen registry: route path → landscape builder.
///
/// Every real ordering route that has no landscape screen yet is absent, so
/// [selectKioskScreen] falls back to the existing portrait screen and the app
/// still works end to end in a landscape window. Later phases add one entry
/// here per finished Option-B screen.
///  - Phase 1: the placeholder shell.
///  - Phase 2 (B2): the menu + order panel.
final Map<String, WidgetBuilder> landscapeRoutes = <String, WidgetBuilder>{
  kioskLandscapeShellRoute: (_) => const LandscapeShellScreen(),
  _kioskMenuRoute: (_) => const LandscapeMenuScreen(),
  RouterHelper.kioskCheckoutScreen: (_) => const LandscapeCheckoutNameScreen(),
  RouterHelper.kioskCheckoutEmailScreen: (_) =>
      const LandscapeCheckoutEmailScreen(),
  RouterHelper.kioskConfirmScreen: (_) => const LandscapeOrderSummaryScreen(),
};

/// Pure screen picker. Portrait always wins. In landscape a route shows its
/// registered landscape variant, else it falls back to [portrait].
Widget selectKioskScreen({
  required BuildContext context,
  required bool isLandscape,
  required String path,
  required Widget portrait,
  required Map<String, WidgetBuilder> landscapeRoutes,
}) {
  if (!isLandscape) return portrait;
  final WidgetBuilder? builder = landscapeRoutes[path];
  if (builder == null) return portrait;
  return builder(context);
}

/// The single switch point used by `router_helper._routeHandler`.
///
/// Reads the CURRENT window on every build and returns either the registered
/// landscape variant or the untouched portrait screen — a pure, live
/// recomputation (see [classifyKioskLayout]), never a cached/locked decision.
/// Resizing the window always re-decides; no re-fetch happens because the
/// decision only changes WHICH WIDGET is returned, never the shared
/// Provider state (cart, category, deals, …) backing it.
class KioskLandscapeSwitch {
  KioskLandscapeSwitch._();

  static Widget resolve(BuildContext context, String path, Widget portrait) {
    // _routeHandler hands paths as `${fullPath}?${query}`; the registry keys
    // off the clean path only.
    final String cleanPath = path.split('?').first;
    final Size window = MediaQuery.of(context).size;
    final KioskLayoutMode mode = classifyKioskLayout(window);
    return selectKioskScreen(
      context: context,
      isLandscape: mode == KioskLayoutMode.landscape,
      path: cleanPath,
      portrait: portrait,
      landscapeRoutes: landscapeRoutes,
    );
  }
}
