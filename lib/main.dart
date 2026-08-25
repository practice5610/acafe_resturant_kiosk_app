import 'dart:async';
import 'dart:io';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:acafe_customer/common/enums/data_source_enum.dart';
import 'package:acafe_customer/data/datasource/local/cache_response.dart';
import 'package:acafe_customer/helper/responsive_helper.dart';
import 'package:acafe_customer/common/responsive/breakpoints.dart';
import 'package:acafe_customer/helper/kiosk_browser_gestures.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:acafe_customer/localization/app_localization.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_login_screen.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/realtime/product_realtime_scope.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_manager_provider.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_ui.dart';
import 'package:acafe_customer/features/auth/providers/auth_provider.dart';
import 'package:acafe_customer/features/branch/providers/branch_provider.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/category/providers/category_provider.dart';
import 'package:acafe_customer/features/coupon/providers/coupon_provider.dart';
import 'package:acafe_customer/features/language/providers/language_provider.dart';
import 'package:acafe_customer/features/language/providers/localization_provider.dart';
import 'package:acafe_customer/features/order/providers/order_provider.dart';
import 'package:acafe_customer/common/providers/product_provider.dart';
import 'package:acafe_customer/features/search/providers/search_provider.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/common/providers/theme_provider.dart';
import 'package:acafe_customer/theme/brand_colors.dart';
import 'package:acafe_customer/theme/dark_theme.dart';
import 'package:acafe_customer/theme/light_theme.dart';
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_strategy/url_strategy.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_customize_analytics.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_experiment_session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'di_container.dart' as di;
import 'package:universal_html/html.dart' as html;

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final database = AppDatabase();

Future<void> main() async {
  if (ResponsiveHelper.isMobilePhone()) {
    HttpOverrides.global = MyHttpOverrides();
  }
  setPathUrlStrategy();
  disableKioskBrowserHistorySwipe();
  final WidgetsBinding widgetsBinding =
      WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  }

  // The kiosk shows many product photos. Give the image cache more headroom so
  // decoded (downscaled) images aren't evicted and re-decoded — which otherwise
  // shows as a shimmer "pop" when scrolling the grid or switching categories.
  PaintingBinding.instance.imageCache
    ..maximumSize = 2000
    ..maximumSizeBytes = 450 << 20; // 450 MB (default is 100 MB)

  await Future.wait([
    di.init(),
    AppLocalization.preloadDefault(),
  ]);

  // Customization A/B telemetry. Both are inert until something calls them,
  // and every failure path inside them is swallowed, so this cannot affect
  // ordering, payment or the menu.
  KioskExperimentSession.instance.init(di.sl<SharedPreferences>());
  KioskCustomizeAnalytics.instance.init(di.sl<DioClient>());

  GoRouter.optionURLReflectsImperativeAPIs = true;

  String? path;
  if (!kIsWeb) {
    try {
      path = await initDynamicLinks();
    } catch (e) {
      debugPrint('initDynamicLinks: $e');
    }
  }

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (context) => di.sl<ThemeProvider>()),
      ChangeNotifierProvider(create: (context) => di.sl<SplashProvider>()),
      ChangeNotifierProvider(create: (context) => di.sl<LanguageProvider>()),
      ChangeNotifierProvider(create: (context) => di.sl<CategoryProvider>()),
      ChangeNotifierProvider(create: (context) => di.sl<ProductProvider>()),
      ChangeNotifierProvider(
          create: (context) => di.sl<LocalizationProvider>()),
      ChangeNotifierProvider(create: (context) => di.sl<KioskAuthProvider>()),
      ChangeNotifierProvider(create: (context) => di.sl<KioskManagerProvider>()),
      ChangeNotifierProvider(create: (context) => di.sl<AuthProvider>()),
      ChangeNotifierProvider(create: (context) => di.sl<CartProvider>()),
      ChangeNotifierProvider(create: (context) => di.sl<OrderProvider>()),
      ChangeNotifierProvider(create: (context) => di.sl<CouponProvider>()),
      ChangeNotifierProvider(create: (context) => di.sl<SearchProvider>()),
      ChangeNotifierProvider(create: (context) => di.sl<BranchProvider>()),
    ],
    child: MyApp(orderId: null, isWeb: !kIsWeb, route: path),
  ));
}

class MyApp extends StatefulWidget {
  final int? orderId;
  final bool isWeb;
  final String? route;
  const MyApp(
      {super.key, required this.orderId, required this.isWeb, this.route});

  @override
  State<MyApp> createState() => _MyAppState();
}

Future<String?> initDynamicLinks() async {
  final appLinks = AppLinks();
  final uri = await appLinks.getInitialLink();
  String? path;
  if (uri != null) {
    path = uri.path;
  } else {
    path = null;
  }
  return path;
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();

    if (kIsWeb) {
      disableKioskBrowserHistorySwipe();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        disableKioskBrowserHistorySwipe();
        _onRemoveLoader();
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FlutterNativeSplash.remove();
      });
    }

    _loadData();
  }

  void _loadData() async {
    final splashProvider = Provider.of<SplashProvider>(context, listen: false);

    splashProvider.initSharedData();
    Provider.of<CartProvider>(context, listen: false).getCartData(context);

    // Config in background — login screen renders immediately. Policy pages and
    // categories load after kiosk login (see KioskMenuScreen), not at boot.
    _route();
  }

  void _route() {
    final SplashProvider splashProvider =
        Provider.of<SplashProvider>(context, listen: false);

    splashProvider
        .initConfig(context, DataSourceEnum.local)
        .then((value) async {
      if (value != null) {
        _onRemoveLoader();
      }
    });
  }

  void _onRemoveLoader() {
    for (final selector in [
      '#kiosk-boot-shell',
      '#splash',
      '#splash-branding',
      'flutter-loader',
      '.flutter-loader',
      '#flutter-loading',
      '.loading-progress',
      '.preloader',
      '.header',
      '#loading',
      'progress',
    ]) {
      html.document.querySelectorAll(selector).forEach((el) => el.remove());
    }
    html.document.getElementById('splash-screen-style')?.remove();
    html.document.body?.style.background = '#E8E6DF';
    html.document.body?.style.backgroundImage = 'none';
  }

  @override
  Widget build(BuildContext context) {
    List<Locale> locals = [];
    for (var language in AppConstants.languages) {
      locals.add(Locale(language.languageCode!, language.countryCode));
    }

    final splashProvider = Provider.of<SplashProvider>(context, listen: false);

    return ProductRealtimeScope(
      child: MaterialApp.router(
        routerConfig: RouterHelper.goRoutes,
      title: splashProvider.configModel?.restaurantName ?? AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: Provider.of<ThemeProvider>(context).darkTheme
          ? dark.copyWith(
              primaryColor: BrandColors.primary,
              scaffoldBackgroundColor: BrandColors.backgroundDark,
              canvasColor: BrandColors.backgroundDark,
            )
          : light.copyWith(
              primaryColor: BrandColors.primary,
              scaffoldBackgroundColor: BrandColors.background,
              canvasColor: BrandColors.background,
            ),
      locale: Provider.of<LocalizationProvider>(context).locale,
      localizationsDelegates: const [
        AppLocalization.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: locals,
      scrollBehavior: const MaterialScrollBehavior().copyWith(dragDevices: {
        PointerDeviceKind.mouse,
        PointerDeviceKind.touch,
        PointerDeviceKind.stylus,
        PointerDeviceKind.unknown
      }),
      builder: (context, child) {
        Widget content = child ?? const KioskLoginScreen();
        // Large-screen cap: center the app content at
        // kKioskContentMaxWidth (1600) so wide/full-screen kiosk
        // displays don't sprawl. The beige page colour fills the
        // screen edge-to-edge *behind* the cap. Below 1600px the cap
        // never binds, so small/medium screens are unaffected. The
        // full-screen welcome video opts out to stay full-bleed.
        final String path =
            RouterHelper.goRoutes.routeInformationProvider.value.uri.path;
        if (path != RouterHelper.kioskWelcomeScreen) {
          content = ColoredBox(
            color: KioskUI.pageBg,
            child: Center(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: kKioskContentMaxWidth),
                child: content,
              ),
            ),
          );
        }
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(
                  MediaQuery.sizeOf(context).width < 380 ? 0.9 : 1)),
          child: content,
        );
      },
    ),
    );
  }
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

class Get {
  static BuildContext? get context => navigatorKey.currentContext;
  static NavigatorState? get navigator => navigatorKey.currentState;
}
