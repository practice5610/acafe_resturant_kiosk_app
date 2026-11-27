import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:acafe_customer/common/models/config_model.dart';
import 'package:acafe_customer/common/enums/data_source_enum.dart';
import 'package:acafe_customer/features/force_update/screens/force_update_screen.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_intro_image.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_session.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_ui.dart';
import 'package:acafe_customer/theme/app_page_transitions.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_welcome_screen.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_login_screen.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_bootstrap_screen.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_menu_screen.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_cart_screen.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_coupon_screen.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_checkout_name_screen.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_checkout_email_screen.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_confirm_screen.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_payment_screen.dart';
// Kiosk success/QR screen disabled — route redirects to the menu instead.
// import 'package:acafe_customer/features/kiosk/screens/kiosk_success_screen.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_language_screen.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_manager_dashboard_screen.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_manager_sales_overview_screen.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_manager_transactions_screen.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_manager_stock_screen.dart';
// Landscape kiosk (Option B) — the switch point + its placeholder shell. The
// resolver below is the only change to _routeHandler; the shell route is
// additive and touches no portrait screen.
import 'package:acafe_customer/features/kiosk/landscape/landscape_routes.dart';
import 'package:acafe_customer/features/kiosk/landscape/screens/landscape_shell_screen.dart';
import 'package:acafe_customer/features/pos/pos_router.dart';
import 'package:acafe_customer/features/maintenance/screens/maintenance_screen.dart';
import 'package:acafe_customer/features/search/screens/search_result_screen.dart';
import 'package:acafe_customer/features/search/screens/search_screen.dart';
import 'package:acafe_customer/features/search/search_flow_helper.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/theme/brand_colors.dart';
import 'package:acafe_customer/helper/kiosk_route_guard.dart';
import 'package:acafe_customer/helper/responsive_helper.dart';
import 'package:acafe_customer/main.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_web_plugins/url_strategy.dart';


enum RouteAction{push, pushReplacement, popAndPush, pushNamedAndRemoveUntil}

class RouterHelper {

  static const String splashScreen = '/splash';
  static const String kioskBootstrapScreen = '/kiosk-start';
  static const String kioskLoginScreen = '/kiosk-login';
  static const String kioskWelcomeScreen = '/welcome-kiosk';
  static const String kioskMenuScreen = '/menu-kiosk';
  static const String kioskCartScreen = '/cart-kiosk';
  static const String kioskCouponScreen = '/coupon-kiosk';
  static const String kioskCheckoutScreen = '/checkout-kiosk';
  static const String kioskCheckoutEmailScreen = '/checkout-email-kiosk';
  static const String kioskConfirmScreen = '/confirm-kiosk';
  static const String kioskPaymentScreen = '/payment-kiosk';
  static const String kioskSuccessScreen = '/success-kiosk';
  static const String kioskManagerDashboardScreen = '/manager-dashboard-kiosk';
  static const String kioskManagerSalesOverviewScreen = '/manager-sales-kiosk';
  static const String kioskManagerTransactionsScreen = '/manager-transactions-kiosk';
  static const String kioskManagerStockScreen = '/manager-stock-kiosk';
  static const String languageScreen = '/select-language';
  static const String loginScreen = '/login';
  static const String dashboard = '/';
  static const String maintain = '/maintain';
  static const String update = '/update';
  static const String searchScreen = '/search';
  static const String searchResultScreen = '/search-result';
  static const String notificationScreen = '/notification';
  static const String orderDetailsScreen = '/order-details';
  static const String chatScreen = '/messages';
  static const String wallet = '/wallet-screen';


  static HistoryUrlStrategy historyUrlStrategy = HistoryUrlStrategy();

  static String getSplashRoute({RouteAction? action}) => _navigateRoute(splashScreen, route: action);
  static String getKioskBootstrapRoute({RouteAction? action}) => _navigateRoute(kioskBootstrapScreen, route: action);
  static String getKioskLoginRoute({RouteAction? action}) => _navigateRoute(kioskLoginScreen, route: action);
  /// Opens the intro / welcome screen after warming its full-screen artwork
  /// into Flutter's image cache (bounded — never stalls navigation). Prefer
  /// this over navigating to [kioskWelcomeScreen] directly so every entry
  /// path (login, bootstrap, language, return after an order) paints without
  /// a blank flash.
  static Future<void> openKioskWelcome({
    RouteAction? action,
    BuildContext? context,
  }) async {
    final BuildContext? ctx = context ?? Get.context;
    if (ctx != null && ctx.mounted) {
      await KioskIntroImage.ensureReady(ctx);
    }
    _navigateRoute(kioskWelcomeScreen, route: action);
  }

  /// Synchronous navigate kept for call sites that cannot await (e.g. some
  /// button `onTap` wiring). Prefer [openKioskWelcome] when possible.
  static String getKioskWelcomeRoute({RouteAction? action}) =>
      _navigateRoute(kioskWelcomeScreen, route: action);
  static String getKioskMenuRoute({RouteAction? action}) => _navigateRoute(kioskMenuScreen, route: action);

  /// Makes the menu the whole stack. Within one customer's visit this lands
  /// on the live, already-painted menu (one clean slide, no rebuild); after
  /// [KioskSession.reset] it builds a fresh menu for the next customer. Use
  /// this — not push / pushReplacement — whenever a screen "returns to the
  /// menu", or the pages under it pile up for the rest of the day.
  static void goKioskMenu() => goRoutes.go(kioskMenuScreen);
  static String getKioskCartRoute({RouteAction? action}) => _navigateRoute(kioskCartScreen, route: action);
  static String getKioskCouponRoute({double? orderAmount, RouteAction? action}) =>
      _navigateRoute('$kioskCouponScreen?amount=${orderAmount ?? 0}', route: action);
  static String getKioskCheckoutRoute({RouteAction? action}) => _navigateRoute(kioskCheckoutScreen, route: action);
  static String getKioskCheckoutEmailRoute({RouteAction? action}) => _navigateRoute(kioskCheckoutEmailScreen, route: action);
  static String getKioskConfirmRoute({RouteAction? action}) => _navigateRoute(kioskConfirmScreen, route: action);
  static String getKioskPaymentRoute({RouteAction? action}) => _navigateRoute(kioskPaymentScreen, route: action);
  static String getKioskSuccessRoute({RouteAction? action}) => _navigateRoute(kioskSuccessScreen, route: action);
  static String getKioskManagerDashboardRoute({RouteAction? action}) => _navigateRoute(kioskManagerDashboardScreen, route: action);
  static String getKioskManagerSalesOverviewRoute({RouteAction? action}) => _navigateRoute(kioskManagerSalesOverviewScreen, route: action);
  static String getKioskManagerTransactionsRoute({RouteAction? action}) => _navigateRoute(kioskManagerTransactionsScreen, route: action);
  static String getKioskManagerStockRoute({RouteAction? action}) => _navigateRoute(kioskManagerStockScreen, route: action);
  static String getLanguageRoute(bool isFromMenu, {RouteAction? action}) => _navigateRoute('$languageScreen?page=${isFromMenu ? 'menu' : 'splash'}', route: action);
  static String getLoginRoute({RouteAction? action}) => getKioskLoginRoute(action: action);
  static String getMainRoute({RouteAction? action}) => _navigateRoute(dashboard, route: action);
  static String getMaintainRoute({RouteAction? action}) => _navigateRoute(maintain, route: RouteAction.pushNamedAndRemoveUntil);
  static String getUpdateRoute({RouteAction? action}) => _navigateRoute(update, route: action);
  static String getSearchRoute() => _navigateRoute(searchScreen);
  static String getSearchResultRoute(String text, {bool openFilter = false}) {
    final filter = openFilter ? '&open_filter=1' : '';
    return _navigateRoute('$searchResultScreen?text=${Uri.encodeComponent(jsonEncode(text))}$filter');
  }
  static String getNotificationRoute({bool fromSplash = false, RouteAction? action}) => _navigateRoute('$notificationScreen?from_splash=$fromSplash', route: action);
  static String getOrderDetailsRoute(String? id, {String? phoneNumber, bool fromSplash = false, RouteAction? action}) => _navigateRoute('$orderDetailsScreen?id=$id&phone=${Uri.encodeComponent('$phoneNumber')}&from_splash=$fromSplash', route: action);
  static String getChatRoute({int? orderId, RouteAction? action, bool fromSplash = false}) {
    return _navigateRoute('$chatScreen?order=$orderId&from_splash=$fromSplash', route: action);
  }
  static String getWalletRoute({String? token, String? flag, RouteAction? action}) => _navigateRoute('$wallet?token=$token&&flag=$flag', route: action);

  static String _navigateRoute( String path,{ RouteAction? route = RouteAction.push}) {

    if(route == RouteAction.pushNamedAndRemoveUntil){
      Get.context?.go(path);

      if(kIsWeb) {
        historyUrlStrategy.replaceState(null, '', '/');
      }


    }else if(route == RouteAction.pushReplacement){
      Get.context?.pushReplacement(path);

    }else{
      Get.context?.push(path);
    }
    return path;
  }


  static Widget _routeHandler(BuildContext context, Widget route,
      {bool isBranchCheck = false, required String? path}) {
    // Landscape kiosk (Option B) switch — the single decision site, live on
    // every build (current window width >= height = landscape). In landscape
    // a route shows its registered landscape variant; portrait and
    // not-yet-built routes fall through to the existing portrait screen
    // unchanged, so the app still works end to end in a landscape window.
    route = KioskLandscapeSwitch.resolve(context, path ?? '', route);

    final splashProvider =
        Provider.of<SplashProvider>(context, listen: false);
    if (splashProvider.configModel == null) {
      return _AwaitConfigShell(
        route: route,
        isBranchCheck: isBranchCheck,
      );
    }
    return _resolveRoute(context, route, isBranchCheck: isBranchCheck);
  }

  static Widget _resolveRoute(BuildContext context, Widget route,
      {bool isBranchCheck = false}) {
    final splashProvider =
        Provider.of<SplashProvider>(context, listen: false);
    if (_isMaintenance(splashProvider.configModel!)) {
      return const MaintenanceScreen();
    }
    // Kiosk always runs against a fixed branch (set at bootstrap), so there is
    // no web-style branch picker fallback here.
    return route;
  }

  static _isMaintenance(ConfigModel configModel) {
    if(configModel.maintenanceMode?.maintenanceStatus == 1){
      if( (ResponsiveHelper.isWeb() && configModel.maintenanceMode?.selectedMaintenanceSystem?.webApp == 1) ||
          (!ResponsiveHelper.isWeb() && configModel.maintenanceMode?.selectedMaintenanceSystem?.customerApp == 1)
      ){
        return true;
      }else{
        return false;
      }
    }else{
      return false;
    }
  }

  static String? _getPath(GoRouterState state)=> '${state.fullPath}?${state.uri.query}';

  /// The menu page. Its key is stable for one customer's visit, so
  /// `go(kioskMenuScreen)` from deep in the order flow (payment cancelled,
  /// order placed) lands on the SAME live menu page: go_router slides only
  /// the top page away and drops the ones between without animating them.
  /// [KioskSession.menuEpoch] moves on when a customer finishes, which makes
  /// the next `go` build a fresh menu for the next person.
  ///
  /// [GoRouterState.pageKey] is kept in the key so a menu that is ever
  /// *pushed* (unique imperative key) can never collide with the stack's one.
  static Page<void> _kioskMenuPage(GoRouterState state, Widget child) {
    return MaterialPage<void>(
      key: ValueKey<String>(
          '${state.pageKey.value}#${KioskSession.instance.menuEpoch}'),
      name: state.path,
      child: child,
    );
  }

  /// Cart, coupon, checkout, confirm and payment: the pages a customer stacks
  /// on top of the menu and backs out of again.
  ///
  /// Non-opaque on purpose. An opaque route takes the menu out of the paint
  /// tree once it has slid in, and the web engine then drops the GPU textures
  /// of every product photo on it. Backing out re-uploaded them all in ONE
  /// frame (~200 ms of texImage2D in a profile build), so the 250 ms slide
  /// froze and the menu "blinked" in. Kept painted underneath, the menu is
  /// still warm when it is revealed and the slide runs at full frame rate.
  ///
  /// The cream [Material] guarantees the page covers and absorbs everything
  /// below even before its own Scaffold has painted.
  static Page<void> _kioskFlowPage(GoRouterState state, Widget child) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      name: state.path,
      opaque: false,
      transitionDuration: const AppSlidePageTransitionsBuilder().transitionDuration,
      reverseTransitionDuration: const AppSlidePageTransitionsBuilder().transitionDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          AppSlideTransition(
            animation: animation,
            secondaryAnimation: secondaryAnimation,
            child: child,
          ),
      child: Material(color: KioskUI.pageBg, child: child),
    );
  }

  /// Email + order-summary steps swap instantly: the checkout header animates
  /// the step circles itself, so only that top row moves between steps.
  static Page<void> _kioskStepPage(GoRouterState state, Widget child) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      name: state.path,
      opaque: false,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          child,
      child: Material(color: KioskUI.pageBg, child: child),
    );
  }

  static final goRoutes = GoRouter(

    navigatorKey: navigatorKey,
    initialLocation: kioskLoginScreen,
    redirect: (context, state) =>
        KioskRouteGuard.redirect(context, state.uri.path),
    errorBuilder: (ctx, _) => const KioskLoginScreen(),
    routes: [
      GoRoute(path: splashScreen, builder: (context, state) => const KioskLoginScreen()),
      GoRoute(path: kioskBootstrapScreen, builder: (context, state) => const KioskBootstrapScreen()),
      GoRoute(path: kioskLoginScreen, builder: (context, state) => const KioskLoginScreen()),
      GoRoute(path: kioskWelcomeScreen, builder: (context, state) => const KioskWelcomeScreen()),
      GoRoute(path: kioskMenuScreen, pageBuilder: (context, state) => _kioskMenuPage(state, _routeHandler(context, path: _getPath(state), const KioskMenuScreen()))),
      // The order flow above the menu: see [_kioskFlowPage].
      GoRoute(path: kioskCartScreen, pageBuilder: (context, state) => _kioskFlowPage(state, _routeHandler(context, path: _getPath(state), const KioskCartScreen()))),
      GoRoute(path: kioskCouponScreen, pageBuilder: (context, state) => _kioskFlowPage(state, _routeHandler(context, path: _getPath(state), KioskCouponScreen(orderAmount: double.tryParse(state.uri.queryParameters['amount'] ?? '') ?? 0)))),
      GoRoute(path: kioskCheckoutScreen, pageBuilder: (context, state) => _kioskFlowPage(state, _routeHandler(context, path: _getPath(state), const KioskCheckoutNameScreen()))),
      GoRoute(path: kioskCheckoutEmailScreen, pageBuilder: (context, state) => _kioskStepPage(state, _routeHandler(context, path: _getPath(state), const KioskCheckoutEmailScreen()))),
      GoRoute(path: kioskConfirmScreen, pageBuilder: (context, state) => _kioskStepPage(state, _routeHandler(context, path: _getPath(state), const KioskConfirmScreen()))),
      GoRoute(path: kioskPaymentScreen, pageBuilder: (context, state) => _kioskFlowPage(state, _routeHandler(context, path: _getPath(state), const KioskPaymentScreen()))),
      // Kiosk success/QR screen is disabled — after an order the flow returns
      // straight to the menu (see kiosk_confirm_screen / kiosk_payment_screen).
      // Kept as a redirect so any lingering navigation to /success-kiosk is
      // harmlessly sent to the menu instead of rendering the success screen.
      GoRoute(path: kioskSuccessScreen, redirect: (context, state) => kioskMenuScreen),
      // GoRoute(path: kioskSuccessScreen, builder: (context, state) => _routeHandler(context, path: _getPath(state), const KioskSuccessScreen())),
      // POS Manager screens -- reachable only after a device with category
      // 'pos' unlocks the manager icon with its 4-digit configuration_code
      // (see kiosk_pin_entry_sheet.dart). Not in KioskRouteGuard.publicPaths,
      // so they stay behind the existing logged-in-device check too.
      GoRoute(path: kioskManagerDashboardScreen, builder: (context, state) => _routeHandler(context, path: _getPath(state), const KioskManagerDashboardScreen())),
      GoRoute(path: kioskManagerSalesOverviewScreen, builder: (context, state) => _routeHandler(context, path: _getPath(state), const KioskManagerSalesOverviewScreen())),
      GoRoute(path: kioskManagerTransactionsScreen, builder: (context, state) => _routeHandler(context, path: _getPath(state), const KioskManagerTransactionsScreen())),
      GoRoute(path: kioskManagerStockScreen, builder: (context, state) => _routeHandler(context, path: _getPath(state), const KioskManagerStockScreen())),
      GoRoute(path: maintain, builder: (context, state) => _routeHandler(context, path: _getPath(state), const MaintenanceScreen())),
      GoRoute(path: update, builder: (context, state) => _routeHandler(context, path: _getPath(state), const ForceUpdateScreen())),
      GoRoute(path: languageScreen, builder: (context, state) => KioskLanguageScreen(fromMenu: state.uri.queryParameters['page'] == 'menu')),
      // Landscape (Option B) Phase-1 placeholder shell. Additive, landscape-only,
      // touches no portrait screen; open /landscape-shell-kiosk in a landscape
      // window to confirm the switch and the scale foundation render.
      GoRoute(path: kioskLandscapeShellRoute, builder: (context, state) => const LandscapeShellScreen()),
      GoRoute(path: searchScreen, builder: (context, state) => _routeHandler(context, path: _getPath(state), const SearchScreen())),
      GoRoute(path: searchResultScreen, builder: (context, state) => _routeHandler(
        context, path: _getPath(state), SearchResultScreen(searchString: SearchFlowHelper.decodeSearchQuery(state.uri.queryParameters['text'])), isBranchCheck: true,
      )),
      // POS mode. A separate route family under the `/pos-` prefix, owned by
      // `features/pos/pos_router.dart` and reached only by a device whose
      // back-office category is 'pos' (see KioskRouteGuard). Additive: no kiosk
      // route above is altered, and a kiosk device never resolves one of these.
      ...PosRouter.routes(),
    ],
  );
}

/// Beige placeholder while config loads — replaces the old maroon [SplashScreen]
/// gate that flashed when navigating before [SplashProvider.configModel] was ready.
class _AwaitConfigShell extends StatefulWidget {
  final Widget route;
  final bool isBranchCheck;

  const _AwaitConfigShell({
    required this.route,
    required this.isBranchCheck,
  });

  @override
  State<_AwaitConfigShell> createState() => _AwaitConfigShellState();
}

class _AwaitConfigShellState extends State<_AwaitConfigShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureConfig());
  }

  Future<void> _ensureConfig() async {
    final splash = Provider.of<SplashProvider>(context, listen: false);
    if (splash.configModel != null) {
      if (mounted) setState(() {});
      return;
    }
    await splash.initConfig(context, DataSourceEnum.local);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SplashProvider>(
      builder: (context, splash, _) {
        if (splash.configModel == null) {
          return const Scaffold(
            backgroundColor: BrandColors.background,
            body: SizedBox.shrink(),
          );
        }
        return RouterHelper._resolveRoute(
          context,
          widget.route,
          isBranchCheck: widget.isBranchCheck,
        );
      },
    );
  }
}


class HistoryUrlStrategy extends PathUrlStrategy {
  @override
  void pushState(Object? state, String title, String url) => replaceState(state, title, url);
}
