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
import 'package:acafe_customer/features/language/providers/localization_provider.dart';
import 'package:acafe_customer/features/splash/domain/reposotories/splash_repo.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/localization/app_localization.dart';
import 'package:acafe_customer/main.dart' show navigatorKey;
import 'package:acafe_customer/theme/brand_colors.dart';
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../../helpers/kiosk_layout_harness.dart';

/// A video platform that records what the screen asks of it and "plays" a
/// 1080x1920 clip, so volume, looping, play and pause can be asserted.
class FakeVideoPlatform extends VideoPlayerPlatform
    with MockPlatformInterfaceMixin {
  final List<String> calls = [];
  final StreamController<VideoEvent> events = StreamController<VideoEvent>();

  @override
  Future<void> init() async {}

  @override
  Future<int?> create(DataSource dataSource) async {
    calls.add('create:${dataSource.asset}');
    events.add(VideoEvent(
      eventType: VideoEventType.initialized,
      duration: const Duration(seconds: 10),
      size: const Size(1080, 1920),
    ));
    return 1;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int textureId) => events.stream;

  @override
  Future<void> setLooping(int textureId, bool looping) async =>
      calls.add('looping:$looping');

  @override
  Future<void> setVolume(int textureId, double volume) async =>
      calls.add('volume:$volume');

  @override
  Future<void> play(int textureId) async => calls.add('play');

  @override
  Future<void> pause(int textureId) async => calls.add('pause');

  @override
  Future<void> dispose(int textureId) async => calls.add('dispose');

  @override
  Future<void> setPlaybackSpeed(int textureId, double speed) async {}

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Future<Duration> getPosition(int textureId) async => Duration.zero;

  @override
  Widget buildView(int textureId) => const SizedBox.expand();
}

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
  VideoPlayerController Function()? video,
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

  final Widget home = KioskShell(
    fullBleed: true,
    child: KioskWelcomeScreen(videoControllerFactory: video),
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

Finder circleOf(String code) =>
    find.descendant(of: flag(code), matching: find.byType(AnimatedContainer));

BoxDecoration decorationOf(WidgetTester tester, String code) =>
    tester.widget<AnimatedContainer>(circleOf(code)).decoration!
        as BoxDecoration;

void main() {
  testWidgets('shows one flag per offered language, in the offered order',
      (tester) async {
    await pumpWelcome(tester);

    expect(flag('nl'), findsOneWidget);
    expect(flag('en'), findsOneWidget);
    expect(flag('fr'), findsOneWidget);
    expect(flag('de'), findsOneWidget);

    final List<double> xs = [
      for (final c in ['nl', 'en', 'fr', 'de']) tester.getCenter(flag(c)).dx
    ];
    expect([...xs]..sort(), xs, reason: 'row order follows the offering');
    // Evenly spaced and centred on the screen.
    expect(xs[1] - xs[0], closeTo(xs[2] - xs[1], 0.01));
    expect(xs[2] - xs[1], closeTo(xs[3] - xs[2], 0.01));
    expect((xs.first + xs.last) / 2, closeTo(540, 0.5));
    // No labels.
    for (final String name in ['Dutch', 'English', 'Français', 'Deutsch']) {
      expect(find.text(name), findsNothing);
    }
  });

  testWidgets('offers only the languages chosen in Settings → Hardware',
      (tester) async {
    await pumpWelcome(tester, saved: {
      AppConstants.posHardwareSettingsKey: hardwareOffering(['en', 'fr']),
    });

    expect(flag('en'), findsOneWidget);
    expect(flag('fr'), findsOneWidget);
    expect(flag('nl'), findsNothing);
    expect(flag('de'), findsNothing);
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

  testWidgets('the chosen flag has a white ring and is larger',
      (tester) async {
    await pumpWelcome(tester);

    final Border? ring = decorationOf(tester, 'en').border as Border?;
    expect(ring, isNotNull);
    expect(ring!.top.color, Colors.white);
    for (final String other in ['nl', 'fr', 'de']) {
      expect(decorationOf(tester, other).border, isNull,
          reason: '$other must have no ring');
      expect(tester.getSize(circleOf('en')).width,
          greaterThan(tester.getSize(circleOf(other)).width));
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
    // The ring follows.
    expect(decorationOf(tester, 'fr').border, isNotNull);
    expect(decorationOf(tester, 'en').border, isNull);
  });

  testWidgets('every flag switches to its own language', (tester) async {
    await pumpWelcome(tester);

    for (final String code in ['nl', 'fr', 'de', 'en']) {
      await tester.tap(flag(code));
      await settleKiosk(tester);
      expect(localization.locale.languageCode, code);
      expect(decorationOf(tester, code).border, isNotNull);
    }
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

  testWidgets('the staff exit area sits where the logo was and still orders '
      'when the exit is inert', (tester) async {
    await pumpWelcome(tester);

    final Rect area = tester.getRect(find.byKey(KioskWelcomeScreen.staffExitKey));
    expect(area.center.dx, closeTo(540, 0.5));
    expect(area.top, closeTo(1920 * 0.035, 0.5));
    expect(area.width, closeTo(1080 * 0.26, 0.5));

    await tester.tapAt(area.center);
    await tester.pump();
    expect(menu.ensured, ['en']);
  });

  testWidgets('a video that cannot start leaves the poster, no crash',
      (tester) async {
    await pumpWelcome(
      tester,
      video: () => VideoPlayerController.asset('assets/video/missing.mp4'),
    );

    expect(find.byKey(KioskWelcomeScreen.posterKey), findsOneWidget);
    expect(find.byType(VideoPlayer), findsNothing);
    expect(orderButton, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows only the poster, the pill and the flags', (tester) async {
    await pumpWelcome(tester);

    expect(find.byKey(KioskWelcomeScreen.posterKey), findsOneWidget);
    expect(find.byType(DecoratedBox).evaluate().where((e) {
      final Widget w = e.widget;
      return w is DecoratedBox &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).gradient != null;
    }), isEmpty, reason: 'no scrim over the video');
  });

  testWidgets('the pill is near-black, 78% wide, 5% tall, 85% down',
      (tester) async {
    await pumpWelcome(tester);

    final Rect r = tester.getRect(orderButton);
    expect(r.width, closeTo(1080 * 0.78, 0.5));
    expect(r.height, closeTo(1920 * 0.05, 0.5));
    expect(r.top, closeTo(1920 * 0.85, 0.5));
    expect(r.center.dx, closeTo(540, 0.5));

    final ShapeDecoration d = tester
        .widget<Container>(find.descendant(
            of: orderButton, matching: find.byType(Container)))
        .decoration! as ShapeDecoration;
    expect(d.color, BrandColors.primaryDark);
    expect(d.shape, isA<StadiumBorder>());

    // Flags directly below, ~1.5% of the height apart.
    final Rect row = tester.getRect(find.byKey(KioskWelcomeScreen.flagRowKey));
    expect(row.top, greaterThanOrEqualTo(r.bottom));
    expect(row.top - r.bottom, lessThan(1920 * 0.05));
  });

  for (final Size size in [
    ...kioskTargetSizes,
    const Size(390, 844), // small portrait
  ]) {
    testWidgets(
        'pill and flags are on screen and tappable at '
        '${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      await pumpWelcome(tester, size: size);
      expectNoOverflow(tester, size);

      final Rect screen = Offset.zero & size;
      expect(screen.contains(tester.getRect(orderButton).bottomRight), isTrue);
      for (final String code in ['nl', 'en', 'fr', 'de']) {
        final Rect r = tester.getRect(flag(code));
        expect(screen.contains(r.topLeft) && screen.contains(r.bottomRight),
            isTrue,
            reason: '$code flag is cut off: $r');
        expect(r.height, greaterThanOrEqualTo(48),
            reason: '$code flag is below the 48px touch target');
      }
    });
  }

  group('background video', () {
    late FakeVideoPlatform platform;
    late VideoPlayerPlatform original;

    setUp(() {
      original = VideoPlayerPlatform.instance;
      platform = FakeVideoPlatform();
      VideoPlayerPlatform.instance = platform;
    });
    tearDown(() => VideoPlayerPlatform.instance = original);

    testWidgets('plays the bundled clip muted and looping, cover-fit',
        (tester) async {
      await pumpWelcome(tester);
      await settleKiosk(tester);

      expect(platform.calls.first, 'create:assets/video/kiosk_intro.mp4');
      expect(platform.calls, containsAllInOrder(
          ['volume:0.0', 'looping:true', 'play']));
      expect(find.byType(VideoPlayer), findsOneWidget);
      final FittedBox fit = tester.widget<FittedBox>(find
          .ancestor(of: find.byType(VideoPlayer), matching: find.byType(FittedBox))
          .first);
      expect(fit.fit, BoxFit.cover);
      // Poster stays underneath, so nothing is ever black.
      expect(find.byKey(KioskWelcomeScreen.posterKey), findsOneWidget);
    });

    testWidgets('pauses under another route and resumes when uncovered',
        (tester) async {
      await pumpWelcome(tester);
      await settleKiosk(tester);
      platform.calls.clear();

      navigatorKey.currentState!.push(MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('covering'))));
      await tester.pumpAndSettle();
      expect(platform.calls, contains('pause'));
      expect(platform.calls, isNot(contains('play')));

      platform.calls.clear();
      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(platform.calls, contains('play'));
    });

    testWidgets('disposes the controller when the screen leaves',
        (tester) async {
      await pumpWelcome(tester);
      await settleKiosk(tester);

      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      expect(platform.calls, contains('dispose'));
    });
  });
}
