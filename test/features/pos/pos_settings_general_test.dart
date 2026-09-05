import 'dart:convert';
import 'dart:io';

import 'package:acafe_customer/common/models/config_model.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:acafe_customer/features/language/providers/localization_provider.dart';
import 'package:acafe_customer/features/pos/domain/pos_general_settings.dart';
import 'package:acafe_customer/features/pos/domain/pos_general_settings_repo.dart';
import 'package:acafe_customer/features/pos/domain/pos_settings_spec.dart';
import 'package:acafe_customer/features/pos/pos_shell.dart';
import 'package:acafe_customer/features/pos/providers/pos_general_settings_provider.dart';
import 'package:acafe_customer/features/pos/screens/pos_settings_screen.dart';
import 'package:acafe_customer/features/pos/widgets/pos_settings_sidebar.dart';
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
  final loader = FontLoader('Loew');
  for (final path in const [
    'assets/fonts/Loew-Regular.ttf',
    'assets/fonts/Loew-Medium.ttf',
    'assets/fonts/Loew-Bold.ttf',
    'assets/fonts/Loew-ExtraBold.ttf',
  ]) {
    loader.addFont(File(path)
        .readAsBytes()
        .then((bytes) => ByteData.view(Uint8List.fromList(bytes).buffer)));
  }
  await loader.load();
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
        socialMediaLink: [
          SocialMediaLink(name: 'Website', link: 'https://www.acafegroup.com'),
        ],
      );
}

late SharedPreferences prefs;

Future<void> _pumpSettings(
  WidgetTester tester, {
  Size size = const Size(1366, 1024),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({
    AppConstants.languageCode: 'nl',
    AppConstants.countryCode: 'NL',
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
            splashRepo:
                SplashRepo(dioClient: dio, sharedPreferences: prefs),
          ),
        ),
        ChangeNotifierProvider<LocalizationProvider>(
          create: (_) => LocalizationProvider(
            sharedPreferences: prefs,
            dioClient: dio,
          ),
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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_loadFonts);

  test('POS languages are the venue trio with matching currencies', () {
    expect(PosGeneralSettings.posLanguageCodes, ['nl', 'en', 'fr']);
    expect(
      PosGeneralSettings.languageOptions.map((o) => o.value).toList(),
      ['nl', 'en', 'fr'],
    );
    expect(
      PosGeneralSettings.currencyOptions.map((o) => o.value).toList(),
      ['EUR', 'GBP', 'USD'],
    );
    expect(PosGeneralSettings.currencyForLanguage('nl'), 'EUR');
    expect(PosGeneralSettings.currencyForLanguage('en'), 'GBP');
    expect(PosGeneralSettings.currencyForLanguage('fr'), 'EUR');
  });

  test('PosGeneralSettings.fromConfig maps restaurant + currency', () {
    final settings = PosGeneralSettings.fromConfig(
      ConfigModel(
        restaurantName: 'Café',
        restaurantAddress: 'Street 1',
        restaurantPhone: '+311',
        restaurantEmail: 'a@b.c',
        currencySymbol: '€',
        countryCode: 'NL',
      ),
      languageCode: 'nl',
    );
    expect(settings.storeName, 'Café');
    expect(settings.language, 'nl');
    expect(settings.currency, 'EUR');
    expect(settings.dateFormat, 'dd/MM/yyyy');
  });

  test('validation rejects empty required fields and bad email', () {
    final errors = PosGeneralSettingsValidation.validate(
      const PosGeneralSettings(
        storeName: '',
        address: '',
        contactPhone: '123',
        contactEmail: 'not-an-email',
        website: '',
        language: 'nl',
        currency: 'EUR',
        taxModel: 'include',
        dateFormat: 'dd/MM/yyyy',
      ),
    );
    expect(errors['storeName'], isNotNull);
    expect(errors['address'], isNotNull);
    expect(errors['contactPhone'], isNotNull);
    expect(errors['contactEmail'], isNotNull);
  });

  test('repo round-trips saved settings', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await SharedPreferences.getInstance();
    final repo = PosGeneralSettingsRepo(sharedPreferences: p);
    const original = PosGeneralSettings(
      storeName: 'Till Store',
      address: '1 Main',
      contactPhone: '+31 20 111 2222',
      contactEmail: 'till@acafe.nl',
      website: 'www.acafe.nl',
      language: 'nl',
      currency: 'EUR',
      taxModel: 'exclude',
      dateFormat: 'yyyy-MM-dd',
    );
    expect(await repo.save(original), isTrue);
    expect(repo.loadSaved()?.sameAs(original), isTrue);
    expect(p.getString(AppConstants.posGeneralSettingsKey), isNotEmpty);
  });

  test('provider language change aligns currency', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await SharedPreferences.getInstance();
    final provider = PosGeneralSettingsProvider(
      repo: PosGeneralSettingsRepo(sharedPreferences: p),
    );
    provider.hydrate(
      ConfigModel(
        restaurantName: 'A',
        restaurantAddress: 'B',
        restaurantPhone: '+31 20 555 0000',
        restaurantEmail: 'a@b.nl',
        currencySymbol: '€',
      ),
      languageCode: 'nl',
    );
    provider.setLanguage('en');
    expect(provider.draft.language, 'en');
    expect(provider.draft.currency, 'GBP');
    expect(provider.isDirty, isTrue);
  });

  test('provider save skips write when unchanged after validation', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await SharedPreferences.getInstance();
    final provider = PosGeneralSettingsProvider(
      repo: PosGeneralSettingsRepo(sharedPreferences: p),
    );
    provider.hydrate(
      ConfigModel(
        restaurantName: 'A',
        restaurantAddress: 'B',
        restaurantPhone: '+31 20 555 0000',
        restaurantEmail: 'a@b.nl',
        currencySymbol: '€',
      ),
      languageCode: 'nl',
    );
    expect(provider.isDirty, isFalse);
    expect(await provider.save(), isTrue);
    expect(p.getString(AppConstants.posGeneralSettingsKey), isNull);
  });

  testWidgets('General screen renders language + venue currencies',
      (tester) async {
    await _pumpSettings(tester);

    expect(find.text('GENERAL'), findsOneWidget);
    expect(find.text('General'), findsOneWidget);
    expect(find.text('Store Information'), findsOneWidget);
    expect(find.text('Regional Settings'), findsOneWidget);
    expect(find.text('A|CAFÉ Amsterdam'), findsOneWidget);
    expect(find.text('Dutch'), findsOneWidget);
    expect(find.text('EUR (€)'), findsOneWidget);
    expect(find.text('Prices include tax'), findsOneWidget);
    expect(find.text('DD/MM/YYYY'), findsOneWidget);
    expect(find.text('Deutsch'), findsNothing);

    final sidebarBox =
        tester.renderObject(find.byType(PosSettingsSidebar)) as RenderBox;
    expect(sidebarBox.size.width, PosSettingsSpec.sidebarWidth);
  });

  testWidgets('sidebar switches sections without losing General route',
      (tester) async {
    await _pumpSettings(tester);
    await tester.tap(find.text('STAFF'));
    await tester.pumpAndSettle();
    expect(find.text('TEAM OF THE DAY'), findsOneWidget);

    await tester.tap(find.text('GENERAL'));
    await tester.pumpAndSettle();
    expect(find.text('Store Information'), findsOneWidget);
  });

  testWidgets('editing and saving persists values', (tester) async {
    await _pumpSettings(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'A|CAFÉ Amsterdam'),
      'A|CAFÉ Utrecht',
    );
    await tester.pump();
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    final raw = prefs.getString(AppConstants.posGeneralSettingsKey);
    expect(raw, isNotNull);
    final map = jsonDecode(raw!) as Map<String, dynamic>;
    expect(map['store_name'], 'A|CAFÉ Utrecht');
    expect(map['language'], 'nl');

    await _pumpSettings(tester);
    expect(find.text('A|CAFÉ Utrecht'), findsOneWidget);
  });

  testWidgets('narrow width stays usable without overflow', (tester) async {
    await _pumpSettings(tester, size: const Size(900, 700));
    expect(tester.takeException(), isNull);
    expect(find.text('General'), findsOneWidget);
    expect(find.text('Save Changes'), findsOneWidget);
  });
}
