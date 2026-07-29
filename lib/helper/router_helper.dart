import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:acafe_customer/common/models/config_model.dart';
import 'package:acafe_customer/common/enums/data_source_enum.dart';
import 'package:acafe_customer/features/force_update/screens/force_update_screen.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_welcome_screen.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_login_screen.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_bootstrap_screen.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_menu_screen.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_cart_screen.dart';
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
  static String getKioskWelcomeRoute({RouteAction? action}) => _navigateRoute(kioskWelcomeScreen, route: action);
  static String getKioskMenuRoute({RouteAction? action}) => _navigateRoute(kioskMenuScreen, route: action);
  static String getKioskCartRoute({RouteAction? action}) => _navigateRoute(kioskCartScreen, route: action);
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
      GoRoute(path: kioskMenuScreen, builder: (context, state) => _routeHandler(context, path: _getPath(state), const KioskMenuScreen())),
      GoRoute(path: kioskCartScreen, builder: (context, state) => _routeHandler(context, path: _getPath(state), const KioskCartScreen())),
      GoRoute(path: kioskCheckoutScreen, builder: (context, state) => _routeHandler(context, path: _getPath(state), const KioskCheckoutNameScreen())),
      GoRoute(path: kioskCheckoutEmailScreen, builder: (context, state) => _routeHandler(context, path: _getPath(state), const KioskCheckoutEmailScreen())),
      GoRoute(path: kioskConfirmScreen, builder: (context, state) => _routeHandler(context, path: _getPath(state), const KioskConfirmScreen())),
      GoRoute(path: kioskPaymentScreen, builder: (context, state) => _routeHandler(context, path: _getPath(state), const KioskPaymentScreen())),
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
      GoRoute(path: searchScreen, builder: (context, state) => _routeHandler(context, path: _getPath(state), const SearchScreen())),
      GoRoute(path: searchResultScreen, builder: (context, state) => _routeHandler(
        context, path: _getPath(state), SearchResultScreen(searchString: SearchFlowHelper.decodeSearchQuery(state.uri.queryParameters['text'])), isBranchCheck: true,
      )),
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
