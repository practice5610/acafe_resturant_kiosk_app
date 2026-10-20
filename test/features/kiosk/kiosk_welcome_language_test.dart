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
import 'package:acafe_customer/features/kiosk/widgets/kiosk_welcome_language_picker.dart';
import 'package:acafe_customer/features/language/providers/localization_provider.dart';
import 'package:acafe_customer/features/splash/domain/reposotories/splash_repo.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/main.dart' show navigatorKey;
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

final Finder trigger = find.byKey(KioskWelcomeLanguagePicker.triggerKey);
final Finder list = find.byKey(KioskWelcomeLanguagePicker.menuKey);
Finder option(String code) =>
    find.byKey(KioskWelcomeLanguagePicker.optionKey(code));

/// A point well clear of the picker: the empty middle of the screen.
const Offset screenMiddle = Offset(108, 960);

Future<void> openList(WidgetTester tester) async {
  await tester.tap(trigger);
  await settleKiosk(tester);
  expect(list, findsOneWidget, reason: 'precondition: the list is open');
}

Future<void> pick(WidgetTester tester, String code) async {
  await openList(tester);
  await tester.tap(option(code));
  await settleKiosk(tester);
}

void expectChosen(WidgetTester tester, String code, List<String> others) {
  expect(tester.getSemantics(option(code)),
      isSemantics(isButton: true, isSelected: true),
      reason: '$code should read as the chosen language');
  for (final String other in others) {
    expect(tester.getSemantics(option(other)),
        isSemantics(isButton: true, isSelected: false),
        reason: '$other should not read as chosen');
  }
}

void main() {
  testWidgets('shows only the chosen language until the dropdown is opened',
      (tester) async {
    await pumpWelcome(tester);

    expect(find.descendant(of: trigger, matching: find.text('English')),
        findsOneWidget);
    expect(list, findsNothing);
    for (final String name in ['Dutch', 'Français', 'Deutsch']) {
      expect(find.text(name), findsNothing, reason: '$name is in the list');
    }
    expect(find.image(const AssetImage(Images.kioskDownArrow)), findsNothing);
  });

  testWidgets('opening the dropdown lists every kiosk language, English ticked',
      (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await pumpWelcome(tester);
    await openList(tester);

    for (final String name in ['Dutch', 'Français', 'Deutsch']) {
      expect(find.descendant(of: list, matching: find.text(name)),
          findsOneWidget);
    }
    expectChosen(tester, 'en', ['nl', 'fr', 'de']);
    expect(menu.warmed, ['en']);
    expect(menu.ensured, isEmpty, reason: 'opening the list is not ordering');
    semantics.dispose();
  });

  testWidgets('the list opens above the dropdown, not over it',
      (tester) async {
    await pumpWelcome(tester);
    await openList(tester);

    expect(tester.getRect(list).bottom,
        lessThanOrEqualTo(tester.getRect(trigger).top));
  });

  testWidgets('the dropdown is exactly as wide as the list it opens',
      (tester) async {
    await pumpWelcome(tester);
    await openList(tester);

    final Rect pill = tester.getRect(trigger);
    final Rect card = tester.getRect(list);
    expect(pill.width, closeTo(card.width, 0.01));
    expect(pill.center.dx, closeTo(card.center.dx, 0.01));

    // A longer name does not widen it.
    await tester.tap(option('fr'));
    await settleKiosk(tester);
    expect(tester.getRect(trigger).width, closeTo(pill.width, 0.01));
  });

  testWidgets('offers only the languages chosen in Settings → Hardware',
      (tester) async {
    await pumpWelcome(tester, saved: {
      AppConstants.posHardwareSettingsKey: hardwareOffering(['en', 'fr']),
    });
    await openList(tester);

    expect(option('en'), findsOneWidget);
    expect(option('fr'), findsOneWidget);
    expect(option('nl'), findsNothing);
    expect(option('de'), findsNothing);
  });

  testWidgets('picking a language switches to it and closes the list',
      (tester) async {
    await pumpWelcome(tester);
    await pick(tester, 'fr');

    expect(localization.locale, const Locale('fr', 'FR'));
    expect(prefs.getString(AppConstants.languageCode), 'fr');
    expect(list, findsNothing);
    expect(find.descendant(of: trigger, matching: find.text('Français')),
        findsOneWidget);
    expect(menu.warmed, ['en', 'fr'],
        reason: 'the French menu should start loading in the background');
    expect(menu.ensured, isEmpty, reason: 'picking a language is not ordering');
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('the reopened list ticks the language picked last',
      (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await pumpWelcome(tester);
    await pick(tester, 'de');
    await openList(tester);

    expectChosen(tester, 'de', ['nl', 'en', 'fr']);
    semantics.dispose();
  });

  testWidgets('picking the language already chosen changes nothing',
      (tester) async {
    await pumpWelcome(tester);
    await pick(tester, 'en');

    expect(list, findsNothing);
    expect(menu.warmed, ['en']);
    expect(menu.ensured, isEmpty);
  });

  testWidgets('a tap beside the open list closes it without ordering',
      (tester) async {
    await pumpWelcome(tester);
    await openList(tester);

    await tester.tapAt(screenMiddle);
    await settleKiosk(tester);

    expect(list, findsNothing);
    expect(menu.ensured, isEmpty);
    expect(localization.locale.languageCode, 'en');

    // Closed again, the same touch orders as usual.
    await tester.tapAt(screenMiddle);
    await tester.pump();
    expect(menu.ensured, ['en']);
  });

  testWidgets('tapping the dropdown again closes the list', (tester) async {
    await pumpWelcome(tester);
    await openList(tester);

    await tester.tap(trigger);
    await settleKiosk(tester);

    expect(list, findsNothing);
    expect(menu.ensured, isEmpty);
  });

  testWidgets('Escape closes the list', (tester) async {
    await pumpWelcome(tester);
    await openList(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settleKiosk(tester);

    expect(list, findsNothing);
  });

  testWidgets('a list left open closes by itself for the next guest',
      (tester) async {
    await pumpWelcome(tester);
    await openList(tester);

    await tester.pump(const Duration(seconds: 16));
    await settleKiosk(tester);

    expect(list, findsNothing);
    expect(menu.ensured, isEmpty);
  });

  testWidgets('a tap just beside the dropdown does not start an order',
      (tester) async {
    await pumpWelcome(tester);

    final Rect pill = tester.getRect(trigger);
    await tester.tapAt(pill.centerRight + const Offset(4, 0));
    await settleKiosk(tester);

    expect(menu.ensured, isEmpty);
    expect(list, findsNothing);
  });

  testWidgets('touching the screen orders in the chosen language',
      (tester) async {
    await pumpWelcome(tester);

    await pick(tester, 'de');
    await tester.tapAt(screenMiddle);
    await tester.pump();

    expect(menu.ensured, ['de']);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('the dropdown is locked while the menu gets ready',
      (tester) async {
    await pumpWelcome(tester);

    await tester.tapAt(screenMiddle);
    await settleKiosk(tester);
    await tester.tap(trigger, warnIfMissed: false);
    await settleKiosk(tester);

    expect(list, findsNothing,
        reason: 'switching now would open the menu in the wrong language');
    expect(localization.locale.languageCode, 'en');
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

    expect(find.byType(KioskWelcomeLanguagePicker), findsOneWidget);
    expect(trigger, findsNothing);
    expect(find.text('Dutch'), findsNothing);
  });

  testWidgets('the prompt never shows a raw translation key', (tester) async {
    await pumpWelcome(tester);

    expect(find.text('TOUCH TO ORDER'), findsOneWidget);
    expect(find.textContaining('touch_to_order', findRichText: true),
        findsNothing);
    expect(find.textContaining('TOUCH_TO_ORDER', findRichText: true),
        findsNothing);
    await openList(tester);
    expect(find.textContaining('SELECT_LANGUAGE', findRichText: true),
        findsNothing);
  });

  for (final Size size in [
    ...kioskTargetSizes,
    const Size(390, 844), // phone
    const Size(1915, 1000), // laptop browser window
  ]) {
    testWidgets(
        'the dropdown and every language in it are on screen and tappable at '
        '${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      await pumpWelcome(tester, size: size);
      expectNoOverflow(tester, size);

      final Rect screen = Offset.zero & size;
      bool onScreen(Rect r) =>
          screen.contains(r.topLeft) &&
          screen.contains(r.bottomRight - const Offset(1, 1));

      final Rect pill = tester.getRect(trigger);
      expect(onScreen(pill), isTrue, reason: 'dropdown is cut off: $pill');
      expect(pill.height, greaterThanOrEqualTo(48),
          reason: 'dropdown is below the 48px touch target');

      await openList(tester);
      expectNoOverflow(tester, size);
      expect(pill.width, closeTo(tester.getRect(list).width, 0.01),
          reason: 'dropdown and list should be one width');
      expect(onScreen(tester.getRect(list)), isTrue,
          reason: 'list is cut off: ${tester.getRect(list)}');
      for (final String code in ['nl', 'en', 'fr', 'de']) {
        final Rect r = tester.getRect(option(code));
        expect(onScreen(r), isTrue, reason: '$code row is cut off: $r');
        expect(r.height, greaterThanOrEqualTo(48),
            reason: '$code row is below the 48px touch target');
      }
    });
  }
}
