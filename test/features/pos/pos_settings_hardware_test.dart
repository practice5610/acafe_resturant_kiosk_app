import 'dart:convert';
import 'dart:io';

import 'package:acafe_customer/common/models/config_model.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_language_offering.dart';
import 'package:acafe_customer/features/language/providers/localization_provider.dart';
import 'package:acafe_customer/features/pos/domain/pos_general_settings.dart';
import 'package:acafe_customer/features/pos/domain/pos_general_settings_repo.dart';
import 'package:acafe_customer/features/pos/domain/pos_hardware_settings.dart';
import 'package:acafe_customer/features/pos/domain/pos_hardware_settings_repo.dart';
import 'package:acafe_customer/features/pos/domain/pos_settings_spec.dart';
import 'package:acafe_customer/features/pos/pos_shell.dart';
import 'package:acafe_customer/features/pos/providers/pos_hardware_settings_provider.dart';
import 'package:acafe_customer/features/pos/screens/pos_settings_screen.dart';
import 'package:acafe_customer/features/pos/widgets/pos_receipt_preview_card.dart';
import 'package:acafe_customer/features/pos/widgets/pos_settings_pill.dart';
import 'package:acafe_customer/features/pos/widgets/pos_toggle.dart';
import 'package:acafe_customer/features/splash/domain/reposotories/splash_repo.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/main.dart' show navigatorKey;
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _loadFonts() async {
  final loew = FontLoader('Loew');
  for (final path in const [
    'assets/fonts/Loew-Regular.ttf',
    'assets/fonts/Loew-Medium.ttf',
    'assets/fonts/Loew-Bold.ttf',
    'assets/fonts/Loew-ExtraBold.ttf',
  ]) {
    loew.addFont(File(path)
        .readAsBytes()
        .then((bytes) => ByteData.view(Uint8List.fromList(bytes).buffer)));
  }
  await loew.load();

  // The receipt preview is the reason this font is bundled at all — a test
  // that laid it out in a fallback face would not be measuring the real card.
  final mono = FontLoader('RobotoMono');
  for (final path in const [
    'assets/fonts/RobotoMono-Regular.ttf',
    'assets/fonts/RobotoMono-Bold.ttf',
  ]) {
    mono.addFont(File(path)
        .readAsBytes()
        .then((bytes) => ByteData.view(Uint8List.fromList(bytes).buffer)));
  }
  await mono.load();
}

class _SettingsSplash extends SplashProvider {
  _SettingsSplash({required super.splashRepo});

  @override
  ConfigModel? get configModel => ConfigModel(
        restaurantName: 'A|CAFÉ Amsterdam',
        restaurantAddress: 'Nieuwendijk 123, 1012 MD Amsterdam',
        restaurantPhone: '+31 20 555 3829',
        restaurantEmail: 'info@acafe.nl',
        currencySymbol: '€',
        currencySymbolPosition: 'left',
        countryCode: 'NL',
        decimalPointSettings: 2,
      );
}

late SharedPreferences prefs;

ConfigModel _config() => ConfigModel(
      restaurantName: 'A|CAFÉ Amsterdam',
      restaurantAddress: 'Nieuwendijk 123, 1012 MD Amsterdam',
      restaurantPhone: '+31 20 555 3829',
      restaurantEmail: 'info@acafe.nl',
      currencySymbol: '€',
      countryCode: 'NL',
    );

Future<PosHardwareSettingsProvider> _provider({
  Map<String, Object> seed = const {},
}) async {
  SharedPreferences.setMockInitialValues(seed);
  final p = await SharedPreferences.getInstance();
  final provider = PosHardwareSettingsProvider(
    repo: PosHardwareSettingsRepo(sharedPreferences: p),
    generalRepo: PosGeneralSettingsRepo(sharedPreferences: p),
  );
  provider.hydrate(_config(), languageCode: 'nl');
  return provider;
}

/// Pumps the whole Settings shell and lands on the Hardware tab, so the tests
/// exercise the real sidebar routing rather than the panel in isolation.
Future<void> _pumpHardware(
  WidgetTester tester, {
  Size size = const Size(1366, 1024),
  Map<String, Object> seed = const {},
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({
    AppConstants.languageCode: 'nl',
    AppConstants.countryCode: 'NL',
    ...seed,
  });
  prefs = await SharedPreferences.getInstance();
  final dio = DioClient(
    'http://localhost',
    null,
    loggingInterceptor: LoggingInterceptor(),
    sharedPreferences: prefs,
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SplashProvider>(
          create: (_) => _SettingsSplash(
            splashRepo: SplashRepo(dioClient: dio, sharedPreferences: prefs),
          ),
        ),
        ChangeNotifierProvider<LocalizationProvider>(
          create: (_) =>
              LocalizationProvider(sharedPreferences: prefs, dioClient: dio),
        ),
      ],
      child: MediaQuery(
        data: MediaQueryData(size: size),
        child: PosShell(
          child: MaterialApp(
            navigatorKey: navigatorKey,
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: PosSettingsSpec.pageBg,
              body: PosSettingsScreen(sharedPreferences: prefs),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('HARDWARE'));
  await tester.pumpAndSettle();
}

/// The header field, addressed by position rather than by content so the tests
/// keep working when the store name changes.
Finder _headerField() => find.byType(TextField).at(1);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_loadFonts);

  // ── Order number formatting ────────────────────────────────────────────

  group('PosOrderNumber', () {
    test('pads to four digits and prefixes', () {
      expect(PosOrderNumber.format(1, 'AC-'), 'AC-0001');
      expect(PosOrderNumber.format(42, 'AC-'), 'AC-0042');
      expect(PosOrderNumber.format(100001, 'AC-'), 'AC-100001');
    });

    test('an empty prefix leaves the number bare', () {
      expect(PosOrderNumber.format(7, ''), '0007');
      expect(PosOrderNumber.format(7, '   '), '0007');
    });

    test('preview demonstrates the format with a literal sample id', () {
      expect(PosOrderNumber.preview('AC-'), 'AC-0001');
      expect(PosOrderNumber.preview('TILL/'), 'TILL/0001');
    });
  });

  // ── Language sourcing ──────────────────────────────────────────────────

  group('kiosk languages', () {
    test('offers every installed locale, unlike the POS staff trio', () {
      expect(
        PosHardwareSettings.allKioskLanguageCodes,
        AppConstants.languages.map((l) => l.languageCode).toList(),
      );
      // Deutsch is deliberately absent from the staff terminal list but
      // present in the guest offering.
      expect(PosHardwareSettings.allKioskLanguageCodes, contains('de'));
      expect(PosGeneralSettings.posLanguageCodes, isNot(contains('de')));
    });

    test('every offered code has a translation file on disk', () {
      for (final code in PosHardwareSettings.allKioskLanguageCodes) {
        expect(File('assets/language/$code.json').existsSync(), isTrue,
            reason: 'missing assets/language/$code.json for "$code"');
      }
    });

    test('saved codes that are no longer installed are dropped', () {
      final settings = PosHardwareSettings.fromJson(
        {
          'kiosk_languages': ['nl', 'ja', 'ko'],
        },
        storeName: 'Store',
      );
      expect(settings.kioskLanguages, ['nl']);
    });

    test('an all-unknown selection falls back to the full offering', () {
      final settings = PosHardwareSettings.fromJson(
        {
          'kiosk_languages': ['ja', 'zh'],
        },
        storeName: 'Store',
      );
      expect(
        settings.kioskLanguages,
        PosHardwareSettings.allKioskLanguageCodes,
      );
    });
  });

  group('KioskLanguageOffering', () {
    Future<SharedPreferences> seeded(Map<String, Object> values) async {
      SharedPreferences.setMockInitialValues(values);
      return SharedPreferences.getInstance();
    }

    test('honours the saved Hardware selection', () async {
      final p = await seeded({
        AppConstants.posHardwareSettingsKey: jsonEncode({
          'kiosk_languages': ['nl', 'en'],
        }),
      });
      expect(
        KioskLanguageOffering.forDevice(p).map((l) => l.languageCode).toList(),
        ['nl', 'en'],
      );
    });

    test('falls back to every locale when nothing is configured', () async {
      final p = await seeded({});
      expect(
        KioskLanguageOffering.forDevice(p).length,
        AppConstants.languages.length,
      );
    });

    test('falls back rather than showing an empty picker', () async {
      final p = await seeded({
        AppConstants.posHardwareSettingsKey: jsonEncode({
          'kiosk_languages': ['ja'],
        }),
      });
      expect(
        KioskLanguageOffering.forDevice(p).length,
        AppConstants.languages.length,
      );
    });

    test('survives a corrupt preference', () async {
      final p = await seeded({
        AppConstants.posHardwareSettingsKey: 'not json',
      });
      expect(
        KioskLanguageOffering.forDevice(p).length,
        AppConstants.languages.length,
      );
    });
  });

  // ── Validation ─────────────────────────────────────────────────────────

  group('validation', () {
    PosHardwareSettings base() =>
        PosHardwareSettings.initial(storeName: 'A|CAFÉ');

    test('accepts the shipped defaults', () {
      expect(PosHardwareSettingsValidation.validate(base()), isEmpty);
    });

    test('rejects an over-long prefix', () {
      final errors = PosHardwareSettingsValidation.validate(
        base().copyWith(orderNumberPrefix: 'VERYLONGPREFIX'),
      );
      expect(errors['orderNumberPrefix'], isNotNull);
    });

    test('rejects punctuation a print head would mangle', () {
      expect(
        PosHardwareSettingsValidation.validate(
          base().copyWith(orderNumberPrefix: 'A C'),
        )['orderNumberPrefix'],
        isNotNull,
      );
      expect(
        PosHardwareSettingsValidation.validate(
          base().copyWith(orderNumberPrefix: 'AC-'),
        )['orderNumberPrefix'],
        isNull,
      );
    });

    test('an empty prefix is allowed', () {
      expect(
        PosHardwareSettingsValidation.validate(
          base().copyWith(orderNumberPrefix: ''),
        )['orderNumberPrefix'],
        isNull,
      );
    });

    test('header is required only when "Use store name" is off', () {
      expect(
        PosHardwareSettingsValidation.validate(
          base().copyWith(useStoreName: true, receiptHeader: ''),
        )['receiptHeader'],
        isNull,
      );
      expect(
        PosHardwareSettingsValidation.validate(
          base().copyWith(useStoreName: false, receiptHeader: '  '),
        )['receiptHeader'],
        isNotNull,
      );
    });

    test('rejects an over-long footer and an empty language set', () {
      final errors = PosHardwareSettingsValidation.validate(
        base().copyWith(
          receiptFooter: 'x' * 200,
          kioskLanguages: const [],
        ),
      );
      expect(errors['receiptFooter'], isNotNull);
      expect(errors['kioskLanguages'], isNotNull);
    });
  });

  // ── Repo + provider ────────────────────────────────────────────────────

  test('repo round-trips saved settings', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await SharedPreferences.getInstance();
    final repo = PosHardwareSettingsRepo(sharedPreferences: p);
    const original = PosHardwareSettings(
      autoPrintReceipts: true,
      kitchenTicketPrinting: false,
      orderNumberPrefix: 'TILL-',
      useStoreName: false,
      receiptHeader: 'A|CAFÉ Utrecht',
      receiptFooter: 'Tot ziens!',
      kioskLanguages: ['nl', 'de'],
    );
    expect(await repo.save(original), isTrue);
    expect(repo.loadSaved(storeName: 'x')?.sameAs(original), isTrue);
  });

  test('repo returns null rather than throwing on a corrupt payload',
      () async {
    SharedPreferences.setMockInitialValues({
      AppConstants.posHardwareSettingsKey: '{{{',
    });
    final p = await SharedPreferences.getInstance();
    expect(
      PosHardwareSettingsRepo(sharedPreferences: p).loadSaved(storeName: 'x'),
      isNull,
    );
  });

  test('hydrates the header from the live store name', () async {
    final provider = await _provider();
    expect(provider.storeName, 'A|CAFÉ Amsterdam');
    expect(provider.draft.useStoreName, isTrue);
    expect(provider.effectiveHeader, 'A|CAFÉ Amsterdam');
    expect(provider.isDirty, isFalse);
  });

  test('a General store-name override wins over the backend config', () async {
    final provider = await _provider(seed: {
      AppConstants.posGeneralSettingsKey: jsonEncode(const PosGeneralSettings(
        storeName: 'A|CAFÉ Utrecht',
        address: 'Oudegracht 1',
        contactPhone: '+31 30 111 2222',
        contactEmail: 'utrecht@acafe.nl',
        website: '',
        language: 'nl',
        currency: 'EUR',
        taxModel: 'include',
        dateFormat: 'dd/MM/yyyy',
      ).toJson()),
    });
    expect(provider.storeName, 'A|CAFÉ Utrecht');
    expect(provider.effectiveHeader, 'A|CAFÉ Utrecht');
    expect(provider.general.address, 'Oudegracht 1');
  });

  test('turning "Use store name" off keeps the text, then frees it', () async {
    final provider = await _provider();
    provider.setUseStoreName(false);
    expect(provider.draft.receiptHeader, 'A|CAFÉ Amsterdam');

    provider.setReceiptHeader('Custom Header');
    expect(provider.effectiveHeader, 'Custom Header');

    provider.setUseStoreName(true);
    expect(provider.effectiveHeader, 'A|CAFÉ Amsterdam');
  });

  test('language pills multi-select but refuse to empty the picker', () async {
    final provider = await _provider();
    expect(provider.draft.kioskLanguages.length, 4);

    provider.toggleKioskLanguage('de');
    expect(provider.isKioskLanguageSelected('de'), isFalse);
    provider.toggleKioskLanguage('de');
    expect(provider.isKioskLanguageSelected('de'), isTrue);

    for (final code in ['de', 'fr', 'en']) {
      provider.toggleKioskLanguage(code);
    }
    expect(provider.draft.kioskLanguages, ['nl']);
    provider.toggleKioskLanguage('nl');
    expect(provider.draft.kioskLanguages, ['nl']);
  });

  test('save validates first and writes trimmed values', () async {
    final provider = await _provider();
    provider.setUseStoreName(false);
    provider.setReceiptHeader('   ');
    expect(await provider.save(), isFalse);
    expect(provider.errors['receiptHeader'], isNotNull);

    provider.setReceiptHeader('  A|CAFÉ Utrecht  ');
    provider.setOrderNumberPrefix('  AC-  ');
    expect(await provider.save(), isTrue);
    expect(provider.saved.receiptHeader, 'A|CAFÉ Utrecht');
    expect(provider.saved.orderNumberPrefix, 'AC-');
    expect(provider.isDirty, isFalse);
  });

  test('save skips the write when nothing changed', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await SharedPreferences.getInstance();
    final provider = PosHardwareSettingsProvider(
      repo: PosHardwareSettingsRepo(sharedPreferences: p),
      generalRepo: PosGeneralSettingsRepo(sharedPreferences: p),
    );
    provider.hydrate(_config(), languageCode: 'nl');
    expect(provider.isDirty, isFalse);
    expect(await provider.save(), isTrue);
    expect(p.getString(AppConstants.posHardwareSettingsKey), isNull);
  });

  // ── Screen ─────────────────────────────────────────────────────────────

  testWidgets('Hardware section renders both columns', (tester) async {
    await _pumpHardware(tester);

    expect(find.text('Hardware'), findsOneWidget);
    expect(
      find.text('Printer, receipt format, and device preferences'),
      findsOneWidget,
    );
    expect(find.text('Printer'), findsOneWidget);
    expect(find.text('Receipt Format'), findsOneWidget);
    expect(find.text('Auto-Print Receipts'), findsOneWidget);
    expect(find.text('Kitchen Ticket Printing'), findsOneWidget);
    expect(find.text('Save Changes'), findsOneWidget);

    expect(find.byType(PosReceiptPreviewCard), findsOneWidget);
    expect(find.text('LIVE PREVIEW'), findsOneWidget);

    // Store identity in the preview is live, not a second hardcoded copy.
    expect(find.text('A|CAFÉ AMSTERDAM'), findsOneWidget);
    expect(find.text('Nieuwendijk 123, 1012 MD Amsterdam'), findsOneWidget);
    expect(find.text('Tel: +31 20 555 3829'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('kiosk language pills show every installed locale',
      (tester) async {
    await _pumpHardware(tester);

    expect(find.byType(PosSettingsPill), findsNWidgets(4));
    for (final label in ['DUTCH', 'ENGLISH', 'FRANÇAIS', 'DEUTSCH']) {
      expect(find.text(label), findsOneWidget);
    }
    // Figma's aspirational locales have no translation files and must not be
    // offered as if they worked.
    expect(find.text('JAPANESE'), findsNothing);
    expect(find.text('Show more'), findsNothing);
  });

  testWidgets('deselecting a pill persists on save', (tester) async {
    await _pumpHardware(tester);

    await tester.tap(find.widgetWithText(PosSettingsPill, 'DEUTSCH'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    final raw = prefs.getString(AppConstants.posHardwareSettingsKey);
    expect(raw, isNotNull);
    final map = jsonDecode(raw!) as Map<String, dynamic>;
    expect((map['kiosk_languages'] as List).contains('de'), isFalse);

    // …and the guest picker honours it.
    expect(
      KioskLanguageOffering.forDevice(prefs)
          .map((l) => l.languageCode)
          .toList(),
      isNot(contains('de')),
    );
  });

  testWidgets('order number prefix drives the helper line live',
      (tester) async {
    await _pumpHardware(tester);
    expect(find.text('Preview: AC-0001'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'TILL/');
    await tester.pump();
    expect(find.text('Preview: TILL/0001'), findsOneWidget);
    expect(find.text('Preview: AC-0001'), findsNothing);
  });

  testWidgets('prefix and footer reach the preview without saving',
      (tester) async {
    await _pumpHardware(tester);
    expect(find.text('Bon: AC-0001'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'X-');
    // Past the preview's debounce.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.text('Bon: X-0001'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'Tot ziens!');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    // Once in the footer field, once on the ticket.
    expect(find.text('Tot ziens!'), findsNWidgets(2));

    // Nothing has been committed yet.
    expect(prefs.getString(AppConstants.posHardwareSettingsKey), isNull);
  });

  testWidgets('"Use store name" locks the header and syncs it', (tester) async {
    await _pumpHardware(tester);

    final TextField locked = tester.widget<TextField>(_headerField());
    expect(locked.readOnly, isTrue);
    expect(locked.controller!.text, 'A|CAFÉ Amsterdam');

    await tester.tap(find.byWidgetPredicate(
      (w) => w is PosToggle && w.semanticLabel == 'Use store name',
    ));
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(_headerField()).readOnly, isFalse);

    await tester.enterText(_headerField(), 'A|CAFÉ Utrecht');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.text('A|CAFÉ UTRECHT'), findsOneWidget);

    // Back on: the field re-adopts the real store name from General.
    await tester.tap(find.byWidgetPredicate(
      (w) => w is PosToggle && w.semanticLabel == 'Use store name',
    ));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(_headerField()).controller!.text,
      'A|CAFÉ Amsterdam',
    );
    expect(find.text('A|CAFÉ AMSTERDAM'), findsOneWidget);
  });

  testWidgets('Save Changes persists the whole form and survives a remount',
      (tester) async {
    await _pumpHardware(tester);

    await tester.tap(find.byWidgetPredicate(
      (w) => w is PosToggle && w.semanticLabel == 'Auto-Print Receipts',
    ));
    await tester.enterText(find.byType(TextField).first, 'TILL-');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    final raw = prefs.getString(AppConstants.posHardwareSettingsKey);
    expect(raw, isNotNull);
    final map = jsonDecode(raw!) as Map<String, dynamic>;
    expect(map['auto_print_receipts'], isTrue);
    expect(map['order_number_prefix'], 'TILL-');
    expect(map['use_store_name'], isTrue);

    await _pumpHardware(tester, seed: {AppConstants.posHardwareSettingsKey: raw});
    expect(find.text('Preview: TILL-0001'), findsOneWidget);
  });

  testWidgets('an invalid prefix blocks the save', (tester) async {
    await _pumpHardware(tester);

    await tester.enterText(find.byType(TextField).first, 'WAY TOO LONG');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(prefs.getString(AppConstants.posHardwareSettingsKey), isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Kitchen Ticket Printing is flagged as unbacked',
      (tester) async {
    await _pumpHardware(tester);
    expect(
      find.textContaining('No kitchen printer is paired'),
      findsOneWidget,
    );
  });

  testWidgets('the preview never claims to be a real transaction',
      (tester) async {
    await _pumpHardware(tester);
    expect(find.textContaining('Sample transaction'), findsOneWidget);
  });

  testWidgets('other Settings sections still route correctly',
      (tester) async {
    await _pumpHardware(tester);

    await tester.tap(find.text('GENERAL'));
    await tester.pumpAndSettle();
    expect(find.text('Store Information'), findsOneWidget);
    expect(find.text('Regional Settings'), findsOneWidget);

    await tester.tap(find.text('STAFF'));
    await tester.pumpAndSettle();
    expect(find.text('TEAM OF THE DAY'), findsOneWidget);

    await tester.tap(find.text('HARDWARE'));
    await tester.pumpAndSettle();
    expect(find.text('Printer'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // ── Responsive ─────────────────────────────────────────────────────────

  for (final size in const [
    Size(1366, 1024), // POS terminal
    Size(1512, 982), // desktop
    Size(1180, 820), // landscape tablet
    Size(1024, 768), // small landscape — stacks
    Size(900, 700), // narrow — stacks
  ]) {
    testWidgets('no overflow at ${size.width.toInt()}x${size.height.toInt()}',
        (tester) async {
      await _pumpHardware(tester, size: size);

      expect(tester.takeException(), isNull);
      expect(find.text('Hardware'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);
      // The preview must stay reachable at every width, not be clipped away.
      expect(find.byType(PosReceiptPreviewCard), findsOneWidget);

      // Scroll from the group heading rather than a pill: in the stacked
      // layout the pills sit below the fold, and grabbing an off-screen
      // widget would be testing the finder, not the scroll.
      await tester.drag(find.text('Printer'), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(PosSettingsPill), findsNWidgets(4));
    });
  }
}
