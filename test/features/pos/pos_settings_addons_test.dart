import 'dart:io';

import 'package:acafe_customer/common/models/config_model.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_manager_repo.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_manager_provider.dart';
import 'package:acafe_customer/features/language/providers/localization_provider.dart';
import 'package:acafe_customer/features/pos/domain/pos_addons_settings_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_settings_list_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_products_settings_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_settings_section.dart';
import 'package:acafe_customer/features/pos/domain/pos_settings_spec.dart';
import 'package:acafe_customer/features/pos/pos_shell.dart';
import 'package:acafe_customer/features/pos/screens/pos_settings_screen.dart';
import 'package:acafe_customer/features/pos/widgets/pos_addons_settings_panel.dart';
import 'package:acafe_customer/features/pos/widgets/pos_settings_availability_list.dart';
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

class _Splash extends SplashProvider {
  _Splash({required super.splashRepo});

  @override
  ConfigModel? get configModel => ConfigModel(
        restaurantName: 'A|CAFÉ',
        currencySymbol: '€',
        // ConfigModel defaults this to 1 when unset, but the live store sends
        // decimal_point_settings = 2 -- so pin it here, otherwise the golden
        // would compare against prices ("€ 1.5") no terminal ever shows.
        decimalPointSettings: 2,
      );
}

/// Stands in for the network. Mirrors the real provider's contract: the panel
/// reads [addons], calls [loadAllAddonsWithCache] once, and toggles through
/// [toggleAddonAvailability].
class _FakeManager extends KioskManagerProvider {
  _FakeManager({required super.kioskManagerRepo});

  int loadCalls = 0;
  final List<({int id, bool status})> toggles = [];

  /// Set to a message to simulate the server refusing a hide.
  String? refuseWith;

  List<Map<String, dynamic>> _rows = [
    {
      'id': 101,
      'name': 'Shot of Espresso',
      'sku': 'SKU-ADD-101',
      'price': 1.5,
      'image_full_path': '',
      'is_available': true,
      'group_name': 'Extras',
      'is_default': false,
      'default_product_count': 0,
      'blocks_required_group': false,
    },
    {
      'id': 205,
      'name': 'Hazelnut Syrup',
      'sku': 'SKU-ADD-205',
      'price': 0.9,
      'image_full_path': '',
      'is_available': false,
      'group_name': 'Syrups',
      'is_default': false,
      'default_product_count': 0,
      'blocks_required_group': false,
    },
    // A default add-on live on 3 products -> confirm dialog on hide.
    {
      'id': 220,
      'name': 'Oat Milk',
      'sku': 'SKU-ADD-220',
      'price': 0.0,
      'image_full_path': '',
      'is_available': true,
      'group_name': 'Milk',
      'is_default': true,
      'default_product_count': 3,
      'blocks_required_group': false,
    },
    // Sole member of a required group -> hide refused outright.
    {
      'id': 300,
      'name': 'Regular Milk',
      'sku': 'SKU-ADD-300',
      'price': 0.0,
      'image_full_path': '',
      'is_available': true,
      'group_name': 'Milk Choice',
      'is_default': false,
      'default_product_count': 0,
      'blocks_required_group': true,
    },
  ];

  @override
  List<Map<String, dynamic>> get addons => _rows;

  @override
  bool get addonsLoading => false;

  @override
  Future<void> loadAllAddonsWithCache() async {
    loadCalls++;
  }

  @override
  Future<String?> toggleAddonAvailability(int addonId, bool nextStatus) async {
    toggles.add((id: addonId, status: nextStatus));
    if (refuseWith != null) return refuseWith;
    _rows = _rows
        .map((row) =>
            row['id'] == addonId ? {...row, 'is_available': nextStatus} : row)
        .toList();
    notifyListeners();
    return null;
  }
}

Future<_FakeManager> _pumpAddons(
  WidgetTester tester, {
  Size size = const Size(1366, 1024),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({
    AppConstants.token: 'tok',
    AppConstants.branch: 1,
    AppConstants.languageCode: 'nl',
    AppConstants.countryCode: 'NL',
    AppConstants.kioskDeviceCategory: 'pos',
    AppConstants.kioskDeviceName: 'Till 1 Amsterdam',
    AppConstants.kioskBranchName: 'Amsterdam',
    AppConstants.kioskUsername: 'till1',
  });
  final prefs = await SharedPreferences.getInstance();
  final dio = DioClient(
    'http://localhost',
    null,
    loggingInterceptor: LoggingInterceptor(),
    sharedPreferences: prefs,
  );
  final manager = _FakeManager(
    kioskManagerRepo:
        KioskManagerRepo(dioClient: dio, sharedPreferences: prefs),
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SplashProvider>(
          create: (_) => _Splash(
            splashRepo: SplashRepo(dioClient: dio, sharedPreferences: prefs),
          ),
        ),
        ChangeNotifierProvider<LocalizationProvider>(
          create: (_) =>
              LocalizationProvider(sharedPreferences: prefs, dioClient: dio),
        ),
        ChangeNotifierProvider<KioskManagerProvider>.value(value: manager),
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

  // Sidebar label. Scoped with .first because the page heading uses the same
  // word once the section is open.
  await tester.tap(find.text('ADD-ONS').first);
  await tester.pumpAndSettle();

  return manager;
}

Finder _rowOf(String name) =>
    find.ancestor(of: find.text(name), matching: find.byType(Row)).first;

Future<void> _tapToggle(WidgetTester tester, String name) async {
  await tester.tap(find.descendant(
    of: _rowOf(name),
    matching: find.byType(PosToggle),
  ));
  await tester.pumpAndSettle();
}

PosToggle _toggleFor(WidgetTester tester, String name) =>
    tester.widget<PosToggle>(
      find.descendant(of: _rowOf(name), matching: find.byType(PosToggle)),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);

  testWidgets('renders header, search, and real add-on rows', (tester) async {
    final manager = await _pumpAddons(tester);

    // "ADD-ONS" is both the sidebar label and the page heading, so this is
    // scoped to the panel rather than counted globally.
    expect(
      find.descendant(
        of: find.byType(PosAddonsSettingsPanel),
        matching: find.text(PosAddonsSettingsPanel.pageTitle),
      ),
      findsOneWidget,
    );
    expect(find.text(PosAddonsSettingsPanel.pageSubtitle), findsOneWidget);
    expect(find.text(PosAddonsSettingsPanel.searchHint), findsOneWidget);

    expect(find.text('Shot of Espresso'), findsOneWidget);
    expect(find.text('SKU-ADD-101'), findsOneWidget);
    expect(find.text('Hazelnut Syrup'), findsOneWidget);
    expect(find.text(PosHomeSpec.formatPrice(1.5)), findsOneWidget);

    // One catalogue load on entry, none per keystroke or rebuild.
    expect(manager.loadCalls, 1);
    expect(find.byType(PosToggle), findsNWidgets(4));
  });

  testWidgets('default add-ons render a zero price (Decision 5)',
      (tester) async {
    await _pumpAddons(tester);

    // Two €0.00 rows: the default Oat Milk and Regular Milk. Formatted through
    // the shared POS formatter, so the symbol/decimals follow live config.
    expect(
      find.text(PosHomeSpec.formatPrice(0, padZero: false)),
      findsNWidgets(2),
      reason: 'defaults show a plain zero price, no "Included" label',
    );
    // Never the POS-home padded form, which reads as a glitch in a list.
    expect(find.textContaining('00.00'), findsNothing);
  });

  testWidgets('search filters by name and SKU with no re-fetching',
      (tester) async {
    final manager = await _pumpAddons(tester);
    final search = find.byType(TextField).first;

    await tester.enterText(search, 'hazelnut');
    await tester.pumpAndSettle();
    expect(find.text('Hazelnut Syrup'), findsOneWidget);
    expect(find.text('Shot of Espresso'), findsNothing);

    // SKU.
    await tester.enterText(search, 'SKU-ADD-101');
    await tester.pumpAndSettle();
    expect(find.text('Shot of Espresso'), findsOneWidget);
    expect(find.text('Hazelnut Syrup'), findsNothing);

    // Every term must hit — a second word narrows.
    await tester.enterText(search, 'milk oat');
    await tester.pumpAndSettle();
    expect(find.text('Oat Milk'), findsOneWidget);
    expect(find.text('Regular Milk'), findsNothing);

    await tester.enterText(search, 'zzzz');
    await tester.pumpAndSettle();
    expect(find.textContaining('Nothing matches'), findsOneWidget);

    await tester.enterText(search, '');
    await tester.pumpAndSettle();
    expect(find.byType(PosToggle), findsNWidgets(4));

    // Typing never re-hits the network.
    expect(manager.loadCalls, 1);
  });

  testWidgets('toggling on is immediate, with no dialog', (tester) async {
    final manager = await _pumpAddons(tester);

    expect(_toggleFor(tester, 'Hazelnut Syrup').value, isFalse);

    await _tapToggle(tester, 'Hazelnut Syrup');

    expect(find.byType(AlertDialog), findsNothing);
    expect(manager.toggles, [(id: 205, status: true)]);
    expect(_toggleFor(tester, 'Hazelnut Syrup').value, isTrue);
  });

  testWidgets('toggling one row leaves the others untouched', (tester) async {
    await _pumpAddons(tester);

    expect(_toggleFor(tester, 'Shot of Espresso').value, isTrue);
    await _tapToggle(tester, 'Hazelnut Syrup');

    expect(_toggleFor(tester, 'Shot of Espresso').value, isTrue);
    expect(_toggleFor(tester, 'Oat Milk').value, isTrue);
    expect(_toggleFor(tester, 'Regular Milk').value, isTrue);
  });

  testWidgets('hiding a non-default add-on asks nothing', (tester) async {
    final manager = await _pumpAddons(tester);

    await _tapToggle(tester, 'Shot of Espresso');

    expect(find.byType(AlertDialog), findsNothing);
    expect(manager.toggles, [(id: 101, status: false)]);
  });

  testWidgets('hiding a default add-on warns with the real product count',
      (tester) async {
    final manager = await _pumpAddons(tester);

    await _tapToggle(tester, 'Oat Milk');

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Hide a default add-on?'), findsOneWidget);
    expect(find.textContaining('3 products'), findsOneWidget);

    // Nothing has been sent while the question is on screen.
    expect(manager.toggles, isEmpty);
  });

  testWidgets('cancelling the warning reverts and sends no request',
      (tester) async {
    final manager = await _pumpAddons(tester);

    await _tapToggle(tester, 'Oat Milk');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(manager.toggles, isEmpty, reason: 'cancel must not hit the API');
    expect(_toggleFor(tester, 'Oat Milk').value, isTrue,
        reason: 'the toggle must snap back to its previous state');
  });

  testWidgets('confirming the warning proceeds with the hide', (tester) async {
    final manager = await _pumpAddons(tester);

    await _tapToggle(tester, 'Oat Milk');
    await tester.tap(find.text('Hide add-on'));
    await tester.pumpAndSettle();

    expect(manager.toggles, [(id: 220, status: false)]);
    expect(_toggleFor(tester, 'Oat Milk').value, isFalse);
  });

  testWidgets('hiding an add-on that would break a required group is refused',
      (tester) async {
    final manager = await _pumpAddons(tester);

    await _tapToggle(tester, 'Regular Milk');

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Cannot hide this add-on'), findsOneWidget);
    // Names the group, per the acceptance criteria.
    expect(find.textContaining('Milk Choice'), findsOneWidget);
    // Refusal has no confirm affordance at all.
    expect(find.text('Hide add-on'), findsNothing);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(manager.toggles, isEmpty, reason: 'a refusal never reaches the API');
    expect(_toggleFor(tester, 'Regular Milk').value, isTrue);
  });

  testWidgets('a server-side refusal after confirm is surfaced',
      (tester) async {
    final manager = await _pumpAddons(tester);
    manager.refuseWith =
        'Cannot hide this add-on: "Milk" requires a selection.';

    await _tapToggle(tester, 'Oat Milk');
    await tester.tap(find.text('Hide add-on'));
    await tester.pumpAndSettle();

    // The request went out, the server said no, and the row stayed visible.
    expect(manager.toggles, [(id: 220, status: false)]);
    expect(_toggleFor(tester, 'Oat Milk').value, isTrue);
  });

  testWidgets('no overflow at tablet width', (tester) async {
    await _pumpAddons(tester, size: const Size(1024, 768));
    expect(tester.takeException(), isNull);
    expect(find.text('Shot of Espresso'), findsOneWidget);
  });

  testWidgets('no overflow at a narrow POS width', (tester) async {
    await _pumpAddons(tester, size: const Size(900, 700));
    expect(tester.takeException(), isNull);
    expect(find.text('Shot of Espresso'), findsOneWidget);
  });

  testWidgets('a very long add-on name ellipsises instead of overflowing',
      (tester) async {
    final manager = await _pumpAddons(tester, size: const Size(900, 700));
    manager._rows = [
      {
        ...manager._rows.first,
        'name': 'Extra Large Double Shot Vanilla Hazelnut Caramel Oat Milk '
            'Foam Topping With Cinnamon Dusting',
      },
    ];
    manager.notifyListeners();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('reuses the shared availability card and rows, not a fork',
      (tester) async {
    await _pumpAddons(tester);

    expect(find.byType(PosSettingsAvailabilityCard), findsOneWidget);
    expect(find.byType(PosSettingsAvailabilityRow), findsNWidgets(4));
  });

  testWidgets('matches the Figma 1641:4088 frame', (tester) async {
    await _pumpAddons(tester);

    await expectLater(
      find.byType(PosSettingsScreen),
      matchesGoldenFile('goldens/pos_settings_addons_1366.png'),
    );
  }, skip: !Platform.isMacOS && !Platform.isLinux);

  test('shares Products row geometry rather than restating it', () {
    expect(PosAddonsSettingsSpec.rowHeight, PosSettingsListSpec.rowHeight);
    expect(PosAddonsSettingsSpec.rowHeight, PosProductsSettingsSpec.rowHeight);
    expect(PosAddonsSettingsSpec.thumbSize, PosProductsSettingsSpec.thumbSize);
    expect(
        PosAddonsSettingsSpec.cardRadius, PosProductsSettingsSpec.cardRadius);
    expect(PosSettingsSection.addOns.label, 'ADD-ONS');
  });
}
