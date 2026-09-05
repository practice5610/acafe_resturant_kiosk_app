import 'dart:convert';
import 'dart:io';

import 'package:acafe_customer/common/models/config_model.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_auth_repo.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/language/providers/localization_provider.dart';
import 'package:acafe_customer/features/pos/domain/pos_general_settings.dart';
import 'package:acafe_customer/features/pos/domain/pos_general_settings_repo.dart';
import 'package:acafe_customer/features/pos/domain/pos_hardware_settings.dart';
import 'package:acafe_customer/features/pos/domain/pos_hardware_settings_repo.dart';
import 'package:acafe_customer/features/pos/domain/pos_payment_settings.dart';
import 'package:acafe_customer/features/pos/domain/pos_payment_settings_repo.dart';
import 'package:acafe_customer/features/pos/domain/pos_sale_session.dart';
import 'package:acafe_customer/features/pos/domain/pos_settings_spec.dart';
import 'package:acafe_customer/features/cart/domain/reposotories/cart_repo.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/coupon/providers/coupon_provider.dart';
import 'package:acafe_customer/features/pos/pos_shell.dart';
import 'package:acafe_customer/features/pos/screens/pos_payment_selection_screen.dart';
import 'package:acafe_customer/features/pos/widgets/pos_payment_method_card.dart';
import 'package:acafe_customer/features/pos/providers/pos_payment_settings_provider.dart';
import 'package:acafe_customer/features/pos/screens/pos_settings_screen.dart';
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
}

class _SettingsSplash extends SplashProvider {
  _SettingsSplash({required super.splashRepo});

  @override
  ConfigModel? get configModel => _config();
}

ConfigModel _config() => ConfigModel(
      restaurantName: 'A|CAFÉ Amsterdam',
      restaurantAddress: 'Nieuwendijk 123, 1012 MD Amsterdam',
      restaurantPhone: '+31 20 555 3829',
      restaurantEmail: 'info@acafe.nl',
      currencySymbol: '€',
      countryCode: 'NL',
      decimalPointSettings: 2,
    );

late SharedPreferences prefs;

Future<PosPaymentSettingsProvider> _provider({
  Map<String, Object> seed = const {},
}) async {
  SharedPreferences.setMockInitialValues(seed);
  final p = await SharedPreferences.getInstance();
  final provider = PosPaymentSettingsProvider(
    repo: PosPaymentSettingsRepo(sharedPreferences: p),
    generalRepo: PosGeneralSettingsRepo(sharedPreferences: p),
    hardwareRepo: PosHardwareSettingsRepo(sharedPreferences: p),
  );
  provider.hydrate(_config(), languageCode: 'nl');
  return provider;
}

/// Pumps the whole Settings shell and lands on the Payments tab, so the tests
/// exercise the real sidebar routing rather than the panel in isolation.
Future<void> _pumpPayments(
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
  await tester.tap(find.text('PAYMENTS'));
  await tester.pumpAndSettle();
}

/// The toggle on the row whose label is [name].
///
/// `find.ancestor` yields nearest-first, so `.first` is the row's own Row
/// rather than one of the layout Rows further up the settings shell.
Finder _rowToggle(String name) => find.descendant(
      of: find
          .ancestor(
            of: find.text(name),
            matching: find.byType(Row),
          )
          .first,
      matching: find.byType(PosToggle),
    );

bool _enabled(WidgetTester tester, Finder toggle) =>
    tester.widget<PosToggle>(toggle).onChanged != null;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_loadFonts);

  // ── Model ──────────────────────────────────────────────────────────────

  group('PosPaymentSettings', () {
    test('a fresh terminal takes both tenders', () {
      final s = PosPaymentSettings.initial();
      expect(s.cashEnabled, isTrue);
      expect(s.cardEnabled, isTrue);
    });

    test('inert flags default off, so nothing claims a rail that is absent',
        () {
      final s = PosPaymentSettings.initial();
      expect(s.mobilePayEnabled, isFalse);
      expect(s.giftCardsEnabled, isFalse);
      expect(s.tippingEnabled, isFalse);
    });

    test('isLastTender is true only when exactly one tender survives', () {
      final both = PosPaymentSettings.initial();
      expect(both.isLastTender, isFalse);
      expect(both.cashLocked, isFalse);
      expect(both.cardLocked, isFalse);

      final cashOnly = both.copyWith(cardEnabled: false);
      expect(cashOnly.isLastTender, isTrue);
      expect(cashOnly.cashLocked, isTrue);
      expect(cashOnly.cardLocked, isFalse);
    });

    test('round-trips through JSON', () {
      final s = PosPaymentSettings.initial().copyWith(
        cardEnabled: false,
        giftCardsEnabled: true,
        defaultTaxRate: '9%',
      );
      final back = PosPaymentSettings.fromJson(jsonDecode(jsonEncode(s.toJson())));
      expect(back.sameAs(s), isTrue);
    });

    test('a stored payload with no tenders restores cash rather than bricking '
        'checkout', () {
      final back = PosPaymentSettings.fromJson(const {
        'cash_enabled': false,
        'card_enabled': false,
      });
      expect(back.cashEnabled, isTrue);
      expect(back.cardEnabled, isFalse);
    });

    test('a malformed payload falls back to defaults field by field', () {
      final back = PosPaymentSettings.fromJson(const {'default_tax_rate': '  '});
      expect(back.defaultTaxRate, PosPaymentSettings.defaultTaxRateLabel);
      expect(back.cashEnabled, isTrue);
    });
  });

  // ── Default tender resolution ──────────────────────────────────────────

  group('posDefaultPaymentMethod', () {
    test('prefers card, as Figma paints it', () {
      expect(
        posDefaultPaymentMethod(cashEnabled: true, cardEnabled: true),
        PosPaymentMethod.card,
      );
    });

    test('falls back to cash when card is switched off', () {
      expect(
        posDefaultPaymentMethod(cashEnabled: true, cardEnabled: false),
        PosPaymentMethod.cash,
      );
    });
  });

  group('PosSaleSession tender resolution', () {
    tearDown(() {
      PosSaleSession.instance.applyEnabledTenders(cash: true, card: true);
      PosSaleSession.instance.reset();
    });

    test('applyEnabledTenders moves a sale off a disabled tender', () {
      final session = PosSaleSession.instance
        ..paymentMethod = PosPaymentMethod.card;
      session.applyEnabledTenders(cash: true, card: false);
      expect(session.paymentMethod, PosPaymentMethod.cash);
    });

    test('a deliberate cash choice survives on a terminal that takes both', () {
      final session = PosSaleSession.instance
        ..applyEnabledTenders(cash: true, card: true)
        ..paymentMethod = PosPaymentMethod.cash;
      session.applyEnabledTenders(cash: true, card: true);
      expect(session.paymentMethod, PosPaymentMethod.cash);
    });

    test('reset never restores a disabled tender', () {
      final session = PosSaleSession.instance
        ..applyEnabledTenders(cash: true, card: false);
      session.reset();
      expect(session.paymentMethod, PosPaymentMethod.cash);
    });
  });

  // ── Provider ───────────────────────────────────────────────────────────

  group('PosPaymentSettingsProvider', () {
    test('refuses to disable the last remaining tender', () async {
      final provider = await _provider();
      provider.setCardEnabled(false);
      expect(provider.settings.cardEnabled, isFalse);

      provider.setCashEnabled(false);
      expect(
        provider.settings.cashEnabled,
        isTrue,
        reason: 'the terminal must keep a way to take money',
      );
    });

    test('writes tenders straight through — no Save button on this screen',
        () async {
      SharedPreferences.setMockInitialValues({});
      final p = await SharedPreferences.getInstance();
      final repo = PosPaymentSettingsRepo(sharedPreferences: p);
      final provider = PosPaymentSettingsProvider(
        repo: repo,
        generalRepo: PosGeneralSettingsRepo(sharedPreferences: p),
        hardwareRepo: PosHardwareSettingsRepo(sharedPreferences: p),
      )..hydrate(_config(), languageCode: 'nl');

      provider.setCardEnabled(false);
      await Future<void>.delayed(Duration.zero);
      expect(repo.load().cardEnabled, isFalse);
    });

    test('currency writes into General\'s record, not a second copy', () async {
      SharedPreferences.setMockInitialValues({});
      final p = await SharedPreferences.getInstance();
      final generalRepo = PosGeneralSettingsRepo(sharedPreferences: p);
      final provider = PosPaymentSettingsProvider(
        repo: PosPaymentSettingsRepo(sharedPreferences: p),
        generalRepo: generalRepo,
        hardwareRepo: PosHardwareSettingsRepo(sharedPreferences: p),
      )..hydrate(_config(), languageCode: 'nl');

      expect(provider.currency, 'EUR');
      provider.setCurrency('GBP');
      await Future<void>.delayed(Duration.zero);

      expect(generalRepo.loadSaved()!.currency, 'GBP');
      expect(
        p.getString(AppConstants.posPaymentSettingsKey),
        isNot(contains('GBP')),
        reason: 'currency must not be duplicated into the Payments record',
      );
    });

    test('changing currency preserves the rest of General\'s record', () async {
      SharedPreferences.setMockInitialValues({});
      final p = await SharedPreferences.getInstance();
      final generalRepo = PosGeneralSettingsRepo(sharedPreferences: p);
      await generalRepo.save(
        PosGeneralSettings.fromConfig(_config(), languageCode: 'nl')
            .copyWith(storeName: 'Kept Name', taxModel: 'exclude'),
      );

      final provider = PosPaymentSettingsProvider(
        repo: PosPaymentSettingsRepo(sharedPreferences: p),
        generalRepo: generalRepo,
        hardwareRepo: PosHardwareSettingsRepo(sharedPreferences: p),
      )..hydrate(_config(), languageCode: 'nl');

      provider.setCurrency('USD');
      await Future<void>.delayed(Duration.zero);

      final saved = generalRepo.loadSaved()!;
      expect(saved.currency, 'USD');
      expect(saved.storeName, 'Kept Name');
      expect(saved.taxModel, 'exclude');
    });

    test('auto-print writes into Hardware\'s record, the flag the payment '
        'flow already reads', () async {
      SharedPreferences.setMockInitialValues({});
      final p = await SharedPreferences.getInstance();
      final hardwareRepo = PosHardwareSettingsRepo(sharedPreferences: p);
      final provider = PosPaymentSettingsProvider(
        repo: PosPaymentSettingsRepo(sharedPreferences: p),
        generalRepo: PosGeneralSettingsRepo(sharedPreferences: p),
        hardwareRepo: hardwareRepo,
      )..hydrate(_config(), languageCode: 'nl');

      expect(provider.autoPrintReceipts, isFalse);
      provider.setAutoPrintReceipts(true);
      await Future<void>.delayed(Duration.zero);

      expect(
        hardwareRepo.loadSaved(storeName: '')!.autoPrintReceipts,
        isTrue,
      );
    });

    test('auto-print set on Hardware shows through on Payments', () async {
      SharedPreferences.setMockInitialValues({});
      final p = await SharedPreferences.getInstance();
      final hardwareRepo = PosHardwareSettingsRepo(sharedPreferences: p);
      await hardwareRepo.save(
        PosHardwareSettings.initial(storeName: 'A|CAFÉ Amsterdam')
            .copyWith(autoPrintReceipts: true),
      );

      final provider = PosPaymentSettingsProvider(
        repo: PosPaymentSettingsRepo(sharedPreferences: p),
        generalRepo: PosGeneralSettingsRepo(sharedPreferences: p),
        hardwareRepo: hardwareRepo,
      )..hydrate(_config(), languageCode: 'nl');

      expect(provider.autoPrintReceipts, isTrue);
    });

    test('the tax rate is stored and read by nothing that computes a total',
        () async {
      final provider = await _provider();
      provider.setDefaultTaxRate('9%');
      expect(provider.settings.defaultTaxRate, '9%');
    });
  });

  // ── The tender gate reaches the payment selector ───────────────────────

  group('POS payment selector honours the enabled tenders', () {
    /// Pumps the real payment screen with [seed] already in prefs, using the
    /// screen's test seam rather than GetIt.
    Future<void> pumpSelector(
      WidgetTester tester, {
      required Map<String, Object> seed,
    }) async {
      tester.view.physicalSize = const Size(1366, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({
        AppConstants.branch: 1,
        AppConstants.kioskDeviceCategory: 'pos',
        ...seed,
      });
      final p = await SharedPreferences.getInstance();
      final dio = DioClient(
        'http://localhost',
        null,
        loggingInterceptor: LoggingInterceptor(),
        sharedPreferences: p,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<KioskAuthProvider>(
              create: (_) => KioskAuthProvider(
                kioskAuthRepo:
                    KioskAuthRepo(dioClient: dio, sharedPreferences: p),
              ),
            ),
            ChangeNotifierProvider<SplashProvider>(
              create: (_) => _SettingsSplash(
                splashRepo: SplashRepo(dioClient: dio, sharedPreferences: p),
              ),
            ),
            ChangeNotifierProvider<CartProvider>(
              create: (_) => CartProvider(
                cartRepo: CartRepo(sharedPreferences: p),
              ),
            ),
            ChangeNotifierProvider<CouponProvider>(
              create: (_) => CouponProvider(couponRepo: null),
            ),
          ],
          child: MediaQuery(
            data: const MediaQueryData(size: Size(1366, 1024)),
            child: PosShell(
              child: MaterialApp(
                navigatorKey: navigatorKey,
                debugShowCheckedModeBanner: false,
                home: PosPaymentSelectionScreen(sharedPreferences: p),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('offers both tenders on a default terminal', (tester) async {
      await pumpSelector(tester, seed: const {});
      expect(find.byType(PosPaymentMethodCard), findsNWidgets(2));
    });

    testWidgets('drops the Card option once Card is switched off',
        (tester) async {
      await pumpSelector(tester, seed: {
        AppConstants.posPaymentSettingsKey: jsonEncode(
          PosPaymentSettings.initial().copyWith(cardEnabled: false).toJson(),
        ),
      });

      expect(find.byType(PosPaymentMethodCard), findsOneWidget);
      expect(
        PosSaleSession.instance.paymentMethod,
        PosPaymentMethod.cash,
        reason: 'the sale must not open on a tender that is not offered',
      );
    });

    testWidgets('drops the Cash option once Cash is switched off',
        (tester) async {
      await pumpSelector(tester, seed: {
        AppConstants.posPaymentSettingsKey: jsonEncode(
          PosPaymentSettings.initial().copyWith(cashEnabled: false).toJson(),
        ),
      });

      expect(find.byType(PosPaymentMethodCard), findsOneWidget);
      expect(PosSaleSession.instance.paymentMethod, PosPaymentMethod.card);
    });
  });

  // ── Screen ─────────────────────────────────────────────────────────────

  group('Payments panel', () {
    testWidgets('renders the header and both column labels', (tester) async {
      await _pumpPayments(tester);
      expect(find.text('Payments'), findsOneWidget);
      expect(find.text('Tenders and payment terminals'), findsOneWidget);
      expect(find.text('PAYMENT METHODS'), findsOneWidget);
      expect(find.text('TRANSACTION SETTINGS'), findsOneWidget);
    });

    testWidgets('renders all four method rows', (tester) async {
      await _pumpPayments(tester);
      expect(find.text('Cash'), findsOneWidget);
      expect(find.text('Credit / Debit Card'), findsOneWidget);
      expect(find.text('Mobile Pay'), findsOneWidget);
      expect(find.text('Gift Cards'), findsOneWidget);
    });

    testWidgets('unbacked controls are disabled, never silently faked',
        (tester) async {
      await _pumpPayments(tester);
      expect(_enabled(tester, _rowToggle('Mobile Pay')), isFalse);
      expect(_enabled(tester, _rowToggle('Gift Cards')), isFalse);
      expect(_enabled(tester, _rowToggle('ENABLE TIPPING SCREEN')), isFalse);
    });

    testWidgets('backed controls stay interactive', (tester) async {
      await _pumpPayments(tester);
      expect(_enabled(tester, _rowToggle('Cash')), isTrue);
      expect(_enabled(tester, _rowToggle('Credit / Debit Card')), isTrue);
      expect(_enabled(tester, _rowToggle('RECEIPT AUTO-PRINT')), isTrue);
    });

    testWidgets('turning off Card locks the last remaining tender',
        (tester) async {
      await _pumpPayments(tester);
      await tester.tap(_rowToggle('Credit / Debit Card'));
      await tester.pumpAndSettle();

      expect(
        _enabled(tester, _rowToggle('Cash')),
        isFalse,
        reason: 'Cash is now the only way to take money',
      );
      expect(_enabled(tester, _rowToggle('Credit / Debit Card')), isTrue);
    });

    testWidgets('a tender toggle persists across a tab round-trip',
        (tester) async {
      await _pumpPayments(tester);
      await tester.tap(_rowToggle('Credit / Debit Card'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('GENERAL'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('PAYMENTS'));
      await tester.pumpAndSettle();

      expect(tester.widget<PosToggle>(_rowToggle('Credit / Debit Card')).value,
          isFalse);
    });

    testWidgets('the tax rate carries its VAT Standard suffix', (tester) async {
      await _pumpPayments(tester);
      expect(find.text('VAT Standard'), findsOneWidget);
      expect(find.text('DEFAULT TAX RATE'), findsOneWidget);
    });

    testWidgets('currency changed here shows through on General',
        (tester) async {
      await _pumpPayments(tester);
      await tester.tap(find.text('EUR (€)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('GBP (£)').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('GENERAL'));
      await tester.pumpAndSettle();

      expect(
        find.text('GBP (£)'),
        findsOneWidget,
        reason: 'General and Payments must not hold diverging currencies',
      );
    });

    testWidgets('stacks into one column on a narrow terminal', (tester) async {
      await _pumpPayments(tester, size: const Size(1024, 1024));
      expect(find.text('PAYMENT METHODS'), findsOneWidget);
      expect(find.text('TRANSACTION SETTINGS'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
