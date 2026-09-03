import 'package:acafe_customer/features/pos/domain/pos_responsive.dart';
import 'package:acafe_customer/features/pos/domain/pos_routes.dart';
import 'package:acafe_customer/features/pos/screens/pos_browse_products_screen.dart';
import 'package:acafe_customer/features/pos/screens/pos_cash_payment_entry_screen.dart';
import 'package:acafe_customer/features/pos/screens/pos_home_cart_screen.dart';
import 'package:acafe_customer/features/pos/screens/pos_login_screen.dart';
import 'package:acafe_customer/features/pos/screens/pos_orders_list_screen.dart';
import 'package:acafe_customer/features/pos/screens/pos_payment_selection_screen.dart';
import 'package:acafe_customer/features/pos/screens/pos_payment_success_screen.dart';
import 'package:acafe_customer/features/pos/screens/pos_receipts_screen.dart';
import 'package:acafe_customer/features/pos/screens/pos_report_screen.dart';
import 'package:acafe_customer/features/pos/screens/pos_settings_screen.dart';
import 'package:acafe_customer/features/pos/screens/pos_waiting_for_payment_screen.dart';
import 'package:acafe_customer/features/pos/widgets/pos_top_nav_bar.dart';
import 'package:acafe_customer/features/pos/widgets/pos_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The POS route table, spliced into the app's single [GoRouter].
///
/// One router, not two. Swapping `MaterialApp.router`'s `routerConfig` at
/// runtime would rebuild `Router`, recreate the navigator and drop all route
/// state — which matters because `device.settings.changed` can re-categorise a
/// device mid-service — and two routers cannot share the one global
/// `navigatorKey` that `RouterHelper`/`Get.context` navigate through. Isolation
/// here comes from the `/pos-` path prefix plus the guard branch in
/// [KioskRouteGuard], which is what actually keeps the two trees apart.
class PosRouter {
  PosRouter._();

  /// Spliced into `RouterHelper.goRoutes.routes`.
  static List<RouteBase> routes() => [
        // Outside the shell: no nav chrome before the shift PIN.
        GoRoute(
          path: PosRoutes.login,
          builder: (context, state) => const PosLoginScreen(),
        ),

        // Tabs. The chrome is mounted once by the ShellRoute so switching tabs
        // does not rebuild the nav bar or lose its state.
        ShellRoute(
          builder: (context, state, child) => PosScaffold(
            currentPath: state.uri.path,
            child: child,
          ),
          routes: [
            GoRoute(
              path: PosRoutes.home,
              builder: (context, state) => const PosHomeCartScreen(),
            ),
            GoRoute(
              path: PosRoutes.browse,
              builder: (context, state) => const PosBrowseProductsScreen(),
            ),
            GoRoute(
              path: PosRoutes.report,
              builder: (context, state) => const PosReportScreen(),
            ),
            GoRoute(
              path: PosRoutes.orders,
              builder: (context, state) => const PosOrdersListScreen(),
            ),
            GoRoute(
              path: PosRoutes.receipts,
              builder: (context, state) => const PosReceiptsScreen(),
            ),
            GoRoute(
              path: PosRoutes.settings,
              builder: (context, state) => const PosSettingsScreen(),
            ),
          ],
        ),

        // Payment is a full-screen takeover, deliberately outside the shell:
        // tab switching mid-payment is how a terminal ends up with a charged
        // card and no order.
        GoRoute(
          path: PosRoutes.payment,
          builder: (context, state) => const PosPaymentSelectionScreen(),
        ),
        GoRoute(
          path: PosRoutes.paymentCash,
          builder: (context, state) => const PosCashPaymentEntryScreen(),
        ),
        GoRoute(
          path: PosRoutes.paymentWait,
          builder: (context, state) => const PosWaitingForPaymentScreen(),
        ),
        GoRoute(
          path: PosRoutes.paymentSuccess,
          builder: (context, state) => const PosPaymentSuccessScreen(),
        ),
      ];
}

/// Persistent POS chrome: the top nav bar above the routed tab content.
class PosScaffold extends StatelessWidget {
  final String currentPath;
  final Widget child;

  const PosScaffold({
    super.key,
    required this.currentPath,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final double s = PosMetrics.maybeOf(context)?.scale ?? 1.0;
    return Scaffold(
      backgroundColor: PosUI.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            PosTopNavBar(currentPath: currentPath),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(PosUI.gutter * s),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
