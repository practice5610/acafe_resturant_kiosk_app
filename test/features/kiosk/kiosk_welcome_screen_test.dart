import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:acafe_customer/common/responsive/kiosk_shell.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:acafe_customer/di_container.dart' as di;
import 'package:acafe_customer/features/category/providers/category_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_deal_repo.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_deal_provider.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_welcome_screen.dart';
import 'package:acafe_customer/features/language/providers/localization_provider.dart';
import 'package:acafe_customer/features/splash/domain/reposotories/splash_repo.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/localization/app_localization.dart';
import 'package:acafe_customer/main.dart' show navigatorKey;
import 'package:acafe_customer/theme/brand_colors.dart';
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_video_player_platform.dart';
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

/// Loads the real `assets/language/<code>.json`, so a language switch visibly
/// changes the button text.
class _JsonLocalizations extends LocalizationsDelegate<AppLocalization> {
  const _JsonLocalizations();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<AppLocalization> load(Locale locale) async {
    final AppLocalization l = AppLocalization(locale);
    await l.load();
    return l;
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalization> old) =>
      false;
}

late FakeVideoPlayerPlatform video;
late RecordingMenu menu;
late LocalizationProvider localization;
late SharedPreferences prefs;

String hardwareOffering(List<String> codes) =>
    jsonEncode({'kiosk_languages': codes});

Future<void> pumpWelcome(
  WidgetTester tester, {
  Size size = const Size(1080, 1920),
  Map<String, Object> saved = const {},
  bool realTranslations = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  video = FakeVideoPlayerPlatform();
  VideoPlayerPlatform.instance = video;

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

  final Widget home = const KioskShell(
    fullBleed: true,
    child: const KioskWelcomeScreen(),
  );

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
    child: Consumer<LocalizationProvider>(
      builder: (context, loc, _) => MaterialApp(
        navigatorKey: navigatorKey,
        locale: realTranslations ? loc.locale : null,
        localizationsDelegates: realTranslations
            ? const [
                _JsonLocalizations(),
                ...GlobalMaterialLocalizations.delegates,
              ]
            : null,
        supportedLocales: realTranslations
            ? [for (final l in AppConstants.languages) Locale(l.languageCode!)]
            : const [Locale('en', 'US')],
        home: home,
      ),
    ),
  ));
  await settleKiosk(tester);
}

Finder flag(String code) => find.byKey(KioskWelcomeScreen.flagKey(code));
final Finder orderButton = find.byKey(KioskWelcomeScreen.orderButtonKey);
const Offset screenMiddle = Offset(540, 800);

const List<String> allCodes = ['nl', 'en', 'de', 'fr', 'it', 'ja', 'zh', 'es'];

Finder circleOf(String code) =>
    find.descendant(of: flag(code), matching: find.byType(AnimatedContainer));

BoxDecoration decorationOf(WidgetTester tester, String code) =>
    tester.widget<AnimatedContainer>(circleOf(code)).decoration!
        as BoxDecoration;

void main() {
  testWidgets('shows one flag per offered language, in the offered order',
      (tester) async {
    await pumpWelcome(tester);

    for (final String c in allCodes) {
      expect(flag(c), findsOneWidget, reason: '$c flag');
    }
    final List<double> xs = [
      for (final c in allCodes) tester.getCenter(flag(c)).dx
    ];
    expect([...xs]..sort(), xs, reason: 'row order follows the offering');
    // Evenly spaced and centred on the screen.
    for (int i = 1; i < xs.length; i++) {
      expect(xs[i] - xs[i - 1], closeTo(xs[1] - xs[0], 0.01));
    }
    expect((xs.first + xs.last) / 2, closeTo(540, 0.5));
    // No labels.
    for (final String name in [
      'Nederlands',
      'English',
      'Deutsch',
      'Français',
      'Italiano',
      '日本語',
      '中文',
      'Español'
    ]) {
      expect(find.text(name), findsNothing);
    }
  });

  testWidgets('the row follows AppConstants.languages (no list in the widget)',
      (tester) async {
    expect(
        AppConstants.languages.map((l) => l.languageCode).toList(), allCodes);
  });

  testWidgets('offers only the languages chosen in Settings → Hardware',
      (tester) async {
    await pumpWelcome(tester, saved: {
      AppConstants.posHardwareSettingsKey: hardwareOffering(['en', 'fr', 'ja']),
    });

    expect(flag('en'), findsOneWidget);
    expect(flag('fr'), findsOneWidget);
    expect(flag('ja'), findsOneWidget);
    expect(flag('nl'), findsNothing);
    expect(flag('de'), findsNothing);
    expect(flag('zh'), findsNothing);
  });

  testWidgets('a single offered language needs no flag row', (tester) async {
    await pumpWelcome(tester, saved: {
      AppConstants.languageCode: 'nl',
      AppConstants.countryCode: 'NL',
      AppConstants.posHardwareSettingsKey: hardwareOffering(['nl']),
    });

    expect(find.byKey(KioskWelcomeScreen.flagRowKey), findsNothing);
    expect(orderButton, findsOneWidget);
  });

  testWidgets(
      'the chosen flag sits in a solid white circle of the same size; the rest '
      'in a soft see-through one', (tester) async {
    await pumpWelcome(tester);

    expect(decorationOf(tester, 'en').color, Colors.white);
    expect(decorationOf(tester, 'en').border, isNull, reason: 'no ring');
    for (final String other in allCodes.where((c) => c != 'en')) {
      final BoxDecoration d = decorationOf(tester, other);
      expect(d.color!.a, closeTo(0.30, 0.01), reason: '$other is 30% white');
      expect(d.border, isNull);
      expect(tester.getSize(circleOf('en')).width,
          tester.getSize(circleOf(other)).width,
          reason: 'selection never changes the size');
    }
  });

  testWidgets('the flag is 72% of its circle, centred, and from the round set',
      (tester) async {
    await pumpWelcome(tester);

    for (final String c in allCodes) {
      final Finder image =
          find.descendant(of: flag(c), matching: find.byType(Image));
      final Image img = tester.widget<Image>(image);
      expect((img.image as AssetImage).assetName,
          'assets/image/flags_round/$c.png');
      expect(tester.getSize(image).width,
          closeTo(tester.getSize(circleOf(c)).width * 0.72, 0.01));
      expect((tester.getCenter(image) - tester.getCenter(circleOf(c))).distance,
          lessThan(0.01));
    }
  });

  testWidgets('tapping a flag switches language and never starts an order',
      (tester) async {
    await pumpWelcome(tester);

    await tester.tap(flag('fr'));
    await settleKiosk(tester);

    expect(localization.locale, const Locale('fr', 'FR'));
    expect(prefs.getString(AppConstants.languageCode), 'fr');
    expect(menu.warmed, ['en', 'fr']);
    expect(menu.ensured, isEmpty, reason: 'a flag tap is not an order');
    expect(find.byType(CircularProgressIndicator), findsNothing);
    // The solid white circle follows.
    expect(decorationOf(tester, 'fr').color, Colors.white);
    expect(decorationOf(tester, 'en').color!.a, closeTo(0.30, 0.01));
  });

  testWidgets('every flag switches to its own language', (tester) async {
    await pumpWelcome(tester);

    for (final String code in [...allCodes.skip(1), allCodes.first]) {
      await tester.tap(flag(code));
      await settleKiosk(tester);
      expect(localization.locale.languageCode, code);
      expect(decorationOf(tester, code).color, Colors.white);
    }
    expect(menu.warmed.toSet(), allCodes.toSet(),
        reason: 'every language loads its own menu');
    expect(menu.ensured, isEmpty);
  });

  testWidgets('tapping the language already chosen changes nothing',
      (tester) async {
    await pumpWelcome(tester);

    await tester.tap(flag('en'));
    await settleKiosk(tester);

    expect(menu.warmed, ['en']);
    expect(menu.ensured, isEmpty);
  });

  testWidgets('the button text follows the language', (tester) async {
    await pumpWelcome(tester, realTranslations: true);

    expect(find.text('ORDER HERE'), findsOneWidget);
    final Map<String, String> expected = {
      'nl': 'BESTEL HIER',
      'fr': 'COMMANDER ICI',
      'de': 'HIER BESTELLEN',
      'it': 'ORDINA QUI',
      'ja': 'ここで注文',
      'zh': '在此点餐',
      'es': 'PIDE AQUÍ',
      'en': 'ORDER HERE',
    };
    for (final MapEntry<String, String> e in expected.entries) {
      await tester.tap(flag(e.key));
      await settleKiosk(tester);
      expect(
        find.descendant(of: orderButton, matching: find.text(e.value)),
        findsOneWidget,
        reason: '${e.key} should read ${e.value}',
      );
    }
    expect(menu.ensured, isEmpty);
  });

  testWidgets('the button text is never a raw key', (tester) async {
    await pumpWelcome(tester);

    expect(find.text('ORDER HERE'), findsOneWidget);
    expect(find.textContaining('order_here', findRichText: true), findsNothing);
    expect(find.textContaining('touch_to_order', findRichText: true),
        findsNothing);
    expect(find.text('TOUCH TO ORDER'), findsNothing);
  });

  testWidgets('tapping the ORDER HERE button orders in the chosen language',
      (tester) async {
    await pumpWelcome(tester);

    await tester.tap(flag('de'));
    await settleKiosk(tester);
    await tester.tap(orderButton);
    await tester.pump();

    expect(menu.ensured, ['de']);
  });

  testWidgets('tapping the background orders too', (tester) async {
    await pumpWelcome(tester);

    await tester.tapAt(screenMiddle);
    await tester.pump();

    expect(menu.ensured, ['en']);
  });

  testWidgets('while the menu loads the button shows a spinner and blocks taps',
      (tester) async {
    await pumpWelcome(tester);

    await tester.tap(orderButton);
    await tester.pump();

    expect(
      find.descendant(
          of: orderButton, matching: find.byType(CircularProgressIndicator)),
      findsOneWidget,
    );
    expect(find.text('ORDER HERE'), findsNothing);

    await tester.tap(orderButton);
    await tester.tapAt(screenMiddle);
    await tester.tap(flag('fr'), warnIfMissed: false);
    await settleKiosk(tester);

    expect(menu.ensured, ['en'], reason: 'no second order');
    expect(localization.locale.languageCode, 'en',
        reason: 'no switch mid-load');
  });

  testWidgets(
      'no logo on the screen; the staff exit is an invisible hit area '
      'top-centre, 25% x 10% of the shortest side', (tester) async {
    await pumpWelcome(tester);

    expect(find.byType(SvgPicture), findsNothing);
    final Rect r = tester.getRect(find.byKey(KioskWelcomeScreen.staffExitKey));
    expect(r.width, closeTo(1080 * 0.25, 0.5));
    expect(r.height, closeTo(1080 * 0.10, 0.5));
    expect(r.center.dx, closeTo(540, 0.5));
    expect(r.top, closeTo(0, 0.5));

    // Inert staff exit: a tap there is still a tap anywhere.
    await tester.tapAt(r.center);
    await tester.pump();
    expect(menu.ensured, ['en']);
  });

  testWidgets('no scrim, prompt text or dropdown over the video',
      (tester) async {
    await pumpWelcome(tester);

    expect(find.text('TOUCH TO ORDER'), findsNothing);
    expect(
        find.byType(DecoratedBox).evaluate().where((e) {
          final Widget w = e.widget;
          return w is DecoratedBox &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).gradient != null;
        }),
        isEmpty,
        reason: 'no scrim over the video');
    expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        Colors.black);
  });

  group('video', () {
    testWidgets('plays the intro asset, muted-looping, created exactly once',
        (tester) async {
      await pumpWelcome(tester);

      expect(video.assets, [KioskWelcomeScreen.introVideoAsset]);
      expect(video.created, 1);
      expect(find.byType(VideoPlayer), findsOneWidget);
    });

    testWidgets('a language change does not re-create the controller',
        (tester) async {
      await pumpWelcome(tester);

      for (final String code in [...allCodes.skip(1), allCodes.first]) {
        await tester.tap(flag(code));
        await settleKiosk(tester);
      }
      expect(video.created, 1, reason: 'no restart on any of the 8 switches');
      expect(video.disposed, 0);
    });

    testWidgets('leaving the screen disposes the controller once',
        (tester) async {
      await pumpWelcome(tester);

      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      expect(video.disposed, 1);
    });
  });

  for (final Size size in [
    const Size(1080, 1920),
    const Size(1920, 1080),
    const Size(800, 1280),
    const Size(1280, 800),
    const Size(1024, 768),
    const Size(1032, 1376),
    const Size(440, 956),
    const Size(375, 667),
    const Size(412, 922),
  ]) {
    testWidgets(
        'video covers the whole screen, controls follow the spec at '
        '${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      await pumpWelcome(tester, size: size);
      expectNoOverflow(tester, size);
      final double s = size.shortestSide;
      final KioskIntroMetrics m = KioskIntroMetrics.from(size);

      // True cover: the clip is the whole screen, and the video box inside it
      // (the video's own size, scaled by FittedBox) is at least as large as the
      // screen on both axes, centred, never smaller (no bars) and with the
      // video's own aspect ratio (not stretched).
      final Rect clip = tester.getRect(find.byType(ClipRect).first);
      expect(clip, Offset.zero & size);
      final Rect box = tester.getRect(find.byType(VideoPlayer));
      expect(box.left, lessThanOrEqualTo(0.01));
      expect(box.top, lessThanOrEqualTo(0.01));
      expect(box.right, greaterThanOrEqualTo(size.width - 0.01));
      expect(box.bottom, greaterThanOrEqualTo(size.height - 0.01));
      expect(box.center.dx, closeTo(size.width / 2, 0.5));
      expect(box.center.dy, closeTo(size.height / 2, 0.5));
      expect(box.width / box.height, closeTo(576 / 1024, 0.001));

      // Button: spec width/height, centred.
      final Rect pill = tester.getRect(orderButton);
      expect(pill.width,
          closeTo(math.min(math.max(0.78 * s, 260), size.width - 32), 0.5));
      expect(pill.height, closeTo(math.max(0.085 * s, 48), 0.5));
      expect(pill.center.dx, closeTo(size.width / 2, 0.5));

      // Flags: one line, centred on the row, evenly spaced, whole row on screen.
      final Rect row =
          tester.getRect(find.byKey(KioskWelcomeScreen.flagRowKey));
      expect(row.left, greaterThanOrEqualTo(0));
      expect(row.right, lessThanOrEqualTo(size.width));
      for (int i = 1; i < allCodes.length; i++) {
        expect(
            tester.getCenter(flag(allCodes[i])).dx -
                tester.getCenter(flag(allCodes[i - 1])).dx,
            closeTo(m.pitch, 0.01));
      }
      expect(
          (tester.getCenter(flag('nl')).dx + tester.getCenter(flag('es')).dx) /
              2,
          closeTo(size.width / 2, 0.5));
      for (final String c in allCodes) {
        expect(
            tester.getCenter(flag(c)).dy, closeTo(size.height - 0.10 * s, 0.5),
            reason: '$c centre');
      }

      // Button sits 0.07 s above the selected circle; nothing overlaps.
      final Rect chosen = tester.getRect(circleOf('en'));
      expect(chosen.top - pill.bottom, closeTo(0.07 * s, 0.5));
      expect(tester.getSize(circleOf('en')).width,
          tester.getSize(circleOf('nl')).width);
    });
  }

  testWidgets('spec sizes at 1080x1920 (s = 1080)', (tester) async {
    await pumpWelcome(tester);
    const double s = 1080;

    expect(tester.getSize(circleOf('nl')).width, closeTo(0.10 * s, 0.5));
    expect(tester.getSize(circleOf('en')).width, closeTo(0.10 * s, 0.5));
    expect(tester.getCenter(flag('nl')).dx - tester.getCenter(flag('en')).dx,
        closeTo(-0.11 * s, 0.5));

    final ShapeDecoration d = tester
        .widget<Container>(
            find.descendant(of: orderButton, matching: find.byType(Container)))
        .decoration! as ShapeDecoration;
    expect(d.color, BrandColors.primaryDark);
    expect(d.shape, isA<StadiumBorder>());
    expect(d.shadows, isNull);

    final Text label = tester.widget<Text>(
        find.descendant(of: orderButton, matching: find.text('ORDER HERE')));
    expect(label.style!.fontSize, closeTo(0.026 * s, 0.01));
    expect(label.style!.fontWeight, FontWeight.w700);
    expect(label.style!.color, Colors.white);
    expect(label.style!.letterSpacing, closeTo(0.026 * s * 0.08, 0.01));
  });

  testWidgets('the OS text scale cannot change the button', (tester) async {
    await pumpWelcome(tester);
    final Size before = tester.getSize(orderButton);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pump();
    expect(tester.getSize(orderButton), before);
    expect(tester.takeException(), isNull);
  });

  for (final Size size in [
    ...kioskTargetSizes,
    const Size(768, 1366),
  ]) {
    testWidgets(
        'pill and flags are on screen and tappable at '
        '${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      await pumpWelcome(tester, size: size);
      expectNoOverflow(tester, size);

      final Rect screen = Offset.zero & size;
      expect(screen.contains(tester.getRect(orderButton).bottomRight), isTrue);
      for (final String code in allCodes) {
        final Rect r = tester.getRect(flag(code));
        expect(screen.contains(r.topLeft) && screen.contains(r.bottomRight),
            isTrue,
            reason: '$code flag is cut off: $r');
        expect(r.height, greaterThanOrEqualTo(47.9),
            reason: '$code flag slot is below the 48px touch height');
      }
    });
  }
}
