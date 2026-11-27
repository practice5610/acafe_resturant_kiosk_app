import 'package:flutter/material.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:go_router/go_router.dart';

/// Shared back navigation for kiosk screens (checkout, search, cart, …).
class KioskNavigationHelper {
  KioskNavigationHelper._();

  /// Pops the nearest route (overlay/modal first, then go_router page). Calls
  /// [fallback] when nothing is left to pop — avoids silent no-ops from bare
  /// `context.pop()` on deep links or single-route stacks.
  static void popOrNavigate(BuildContext context, {VoidCallback? fallback}) {
    FocusManager.instance.primaryFocus?.unfocus();

    // Navigator overlays (customize sheet, modal bottom sheets) sit above pages.
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
      return;
    }

    if (fallback != null) {
      fallback();
    } else {
      RouterHelper.getKioskMenuRoute();
    }
  }

  /// Deterministic "back" for a step of the order flow (cart, name, email,
  /// order summary, coupon). Goes to [parentPath] — the screen the customer
  /// actually came from — never to "whatever happens to be under me".
  ///
  /// A raw pop trusts the history stack, and that stack can be wrong: the
  /// cart/checkout entry points push, so repeat visits within one session pile
  /// up duplicates and back ends up bouncing between two screens (cart <->
  /// email) without ever reaching the menu. Here:
  ///  * if the page directly beneath is already [parentPath], pop it (the
  ///    normal slide-back, menu stays warm underneath);
  ///  * otherwise `go(parentPath)`, which REPLACES the stack with that screen,
  ///    so stale duplicates are discarded and the chain stays linear:
  ///    email -> name -> cart -> menu.
  static void backTo(BuildContext context, String parentPath) {
    FocusManager.instance.primaryFocus?.unfocus();
    final GoRouter router = GoRouter.of(context);
    final List<RouteMatch> stack =
        router.routerDelegate.currentConfiguration.matches;
    final String? beneath = stack.length >= 2
        ? Uri.parse(stack[stack.length - 2].matchedLocation).path
        : null;
    if (beneath == parentPath && router.canPop()) {
      router.pop();
      return;
    }
    router.go(parentPath);
  }

  /// Back from the cart: always the menu (home).
  static void backToMenu(BuildContext context) =>
      backTo(context, RouterHelper.kioskMenuScreen);
}
