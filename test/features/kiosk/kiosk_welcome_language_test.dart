import 'dart:async';
import 'dart:convert';

import 'package:acafe_customer/common/responsive/kiosk_shell.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:acafe_customer/di_container.dart' as di;
import 'package:acafe_customer/features/category/providers/category_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_deal_repo.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_deal_provider.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_welcome_screen.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_welcome_language_bar.dart';
import 'package:acafe_customer/features/language/providers/localization_provider.dart';
import 'package:acafe_customer/features/splash/domain/reposotories/splash_repo.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/main.dart' show navigatorKey;
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/kiosk_layout_harness.dart';

/// Records which language's menu the welcome screen asks for, and holds the
/// tap-to-order load open so the "getting the menu ready" state is visible.
class RecordingMenu extends CategoryProvider {
  RecordingMenu() : super(categoryRepo: null);

  final List<String> warmed = [];
  final List<String> ensured = [];
  final Completer<void> gate = Completer<void>();

  @override
  Future<void> warmKioskMenuFromDisk(String localeCode) async =>
      warmed.add(localeCode);

  @override
  Future<void> ensureKioskMenuReady({required String localeCode}) {
    ensured.add(localeCode);
    return gate.future;
  }
}

/// Deals are irrelevant here; keep the screen off the network.
class _NoDeals extends KioskDealProvider {
  _NoDeals({required super.dealRepo});

  @override
  Future<void> loadCached() async {}

  @override
  Future<bool> fetchDeals() async => true;
}

late RecordingMenu menu;
late LocalizationProvider localization;
late SharedPreferences prefs;

String hardwareOffering(List<String> codes) =>
    jsonEncode({'kiosk_languages': codes});

Future<void> pumpWelcome(
  WidgetTester tester, {
  Size size = const Size(1080, 1920),
  Map<String, Object> saved = const {},
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({AppConstants.branch: 1, ...saved});
  prefs = await SharedPreferences.getInstance();
  // KioskLanguageOffering reads Settings → Hardware through the locator.
  if (di.sl.isRegistered<SharedPreferences>()) {
    await di.sl.unregister<SharedPreferences>();
  }
  di.sl.registerSingleton<SharedPreferences>(prefs);
  addTearDown(() => di.sl.unregister<SharedPreferences>());

  final DioClient dio = DioClient(
    'http://localhost',
    null,
    loggingInterceptor: LoggingInterceptor(),
    sharedPreferences: prefs,
  );
  menu = RecordingMenu();
  localization = LocalizationProvider(sharedPreferences: prefs, dioClient: dio);

  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<SplashProvider>(
        create: (_) => KioskStubSplashProvider(
          splashRepo: SplashRepo(dioClient: dio, sharedPreferences: prefs),
        ),
      ),
      ChangeNotifierProvider<CategoryProvider>.value(value: menu),
      ChangeNotifierProvider<LocalizationProvider>.value(value: localization),
      ChangeNotifierProvider<KioskDealProvider>(
        create: (_) => _NoDeals(
          dealRepo: KioskDealRepo(dioClient: dio, sharedPreferences: prefs),
        ),
      ),
    ],
    child: MaterialApp(
      navigatorKey: navigatorKey,
      home: const KioskShell(fullBleed: true, child: KioskWelcomeScreen()),
    ),
  ));
  await settleKiosk(tester);
}

Finder pill(String code) => find.byKey(KioskWelcomeLanguageBar.pillKey(code));

void expectChosen(WidgetTester tester, String code, List<String> others) {
  expect(tester.getSemantics(pill(code)),
      isSemantics(isButton: true, isSelected: true),
      reason: '$code should read as the chosen language');
  for (final String other in others) {
    expect(tester.getSemantics(pill(other)),
        isSemantics(isButton: true, isSelected: false),
        reason: '$other should not read as chosen');
  }
}

void main() {
  testWidgets('offers every kiosk language in place of the down arrow',
      (tester) async {
    await pumpWelcome(tester);

    for (final String name in ['Dutch', 'English', 'Français', 'Deutsch']) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.image(const AssetImage(Images.kioskDownArrow)), findsNothing);
  });

  testWidgets('English is the chosen language on a fresh kiosk',
      (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await pumpWelcome(tester);

    expectChosen(tester, 'en', ['nl', 'fr', 'de']);
    expect(menu.warmed, ['en']);
    semantics.dispose();
  });

  testWidgets('offers only the languages chosen in Settings → Hardware',
      (tester) async {
    await pumpWelcome(tester, saved: {
      AppConstants.posHardwareSettingsKey: hardwareOffering(['en', 'fr']),
    });

    expect(pill('en'), findsOneWidget);
    expect(pill('fr'), findsOneWidget);
    expect(pill('nl'), findsNothing);
    expect(pill('de'), findsNothing);
  });

  testWidgets('tapping a language switches to it without starting an order',
      (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await pumpWelcome(tester);

    await tester.tap(find.text('Français'));
    await settleKiosk(tester);

    expect(localization.locale, const Locale('fr', 'FR'));
    expect(prefs.getString(AppConstants.languageCode), 'fr');
    expectChosen(tester, 'fr', ['nl', 'en', 'de']);
    expect(menu.warmed, ['en', 'fr'],
        reason: 'the French menu should start loading in the background');
    expect(menu.ensured, isEmpty, reason: 'picking a language is not ordering');
    expect(find.byType(CircularProgressIndicator), findsNothing);
    semantics.dispose();
  });

  testWidgets('tapping the language already chosen changes nothing',
      (tester) async {
    await pumpWelcome(tester);

    await tester.tap(find.text('English'));
    await settleKiosk(tester);

    expect(menu.warmed, ['en']);
    expect(menu.ensured, isEmpty);
  });

  testWidgets('a tap between two language buttons does not start an order',
      (tester) async {
    await pumpWelcome(tester);

    final Rect english = tester.getRect(pill('en'));
    final Rect french = tester.getRect(pill('fr'));
    expect(french.top, english.top, reason: 'precondition: one row');
    expect(french.left, greaterThan(english.right));

    await tester.tapAt(Offset(
      (english.right + french.left) / 2,
      english.center.dy,
    ));
    await settleKiosk(tester);

    expect(menu.ensured, isEmpty);
    expect(localization.locale.languageCode, 'en');
  });

  testWidgets('touching the screen orders in the chosen language',
      (tester) async {
    await pumpWelcome(tester);

    await tester.tap(find.text('Deutsch'));
    await settleKiosk(tester);
    await tester.tapAt(const Offset(108, 960));
    await tester.pump();

    expect(menu.ensured, ['de']);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('the language buttons are locked while the menu gets ready',
      (tester) async {
    await pumpWelcome(tester);

    await tester.tapAt(const Offset(108, 960));
    await settleKiosk(tester);
    await tester.tap(find.text('Français'), warnIfMissed: false);
    await settleKiosk(tester);

    expect(localization.locale.languageCode, 'en',
        reason: 'switching now would open the menu in the wrong language');
    expect(menu.warmed, ['en']);
    expect(menu.ensured, ['en'], reason: 'and must not start a second order');
  });

  testWidgets('a kiosk left in a language no longer offered falls back to English',
      (tester) async {
    await pumpWelcome(tester, saved: {
      AppConstants.languageCode: 'de',
      AppConstants.countryCode: 'DE',
      AppConstants.posHardwareSettingsKey: hardwareOffering(['nl', 'en', 'fr']),
    });

    expect(localization.locale, const Locale('en', 'US'));
    expect(menu.warmed, ['en'], reason: 'never load a German menu first');
  });

  testWidgets('a single offered language needs no picker', (tester) async {
    await pumpWelcome(tester, saved: {
      AppConstants.languageCode: 'nl',
      AppConstants.countryCode: 'NL',
      AppConstants.posHardwareSettingsKey: hardwareOffering(['nl']),
    });

    expect(find.byType(KioskWelcomeLanguageBar), findsOneWidget);
    expect(pill('nl'), findsNothing);
    expect(find.text('Dutch'), findsNothing);
  });

  testWidgets('the prompt never shows a raw translation key', (tester) async {
    await pumpWelcome(tester);

    expect(find.text('TOUCH TO ORDER'), findsOneWidget);
    expect(find.textContaining('touch_to_order', findRichText: true),
        findsNothing);
    expect(find.textContaining('TOUCH_TO_ORDER', findRichText: true),
        findsNothing);
  });

  for (final Size size in [
    ...kioskTargetSizes,
    const Size(390, 844), // phone
    const Size(1915, 1000), // laptop browser window
  ]) {
    testWidgets(
        'every language button is on screen and tappable at '
        '${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      await pumpWelcome(tester, size: size);
      expectNoOverflow(tester, size);

      final Rect screen = Offset.zero & size;
      for (final String code in ['nl', 'en', 'fr', 'de']) {
        final Rect r = tester.getRect(pill(code));
        expect(screen.contains(r.topLeft) && screen.contains(r.bottomRight - const Offset(1, 1)),
            isTrue,
            reason: '$code button is cut off: $r');
        expect(r.height, greaterThanOrEqualTo(48),
            reason: '$code button is below the 48px touch target');
      }
    });
  }
}
