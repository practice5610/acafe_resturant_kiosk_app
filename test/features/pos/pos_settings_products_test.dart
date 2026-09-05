import 'dart:io';

import 'package:acafe_customer/common/models/config_model.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_manager_repo.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_manager_provider.dart';
import 'package:acafe_customer/features/language/providers/localization_provider.dart';
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_products_settings_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_settings_section.dart';
import 'package:acafe_customer/features/pos/domain/pos_settings_spec.dart';
import 'package:acafe_customer/features/pos/pos_shell.dart';
import 'package:acafe_customer/features/pos/screens/pos_settings_screen.dart';
import 'package:acafe_customer/features/pos/widgets/pos_products_settings_panel.dart';
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
      );
}

/// Stands in for the network. Mirrors the real provider's contract: the panel
/// reads [products], calls [loadAllProductsWithCache] once, and toggles through
/// [toggleProductAvailability].
class _FakeManager extends KioskManagerProvider {
  _FakeManager({required super.kioskManagerRepo});

  int loadCalls = 0;
  final List<({int id, bool status})> toggles = [];
  bool failNextToggle = false;

  List<Map<String, dynamic>> _rows = [
    {
      'id': 9901,
      'name': 'Iced Strawberry',
      'sku': 'SKU-9901',
      'category_name': 'Cold Drinks',
      'price': 4.8,
      'image_full_path': '',
      'is_available': true,
    },
    {
      'id': 8104,
      'name': 'Double Matcha',
      'sku': 'SKU-8104',
      'category_name': 'Matcha',
      'price': 3.9,
      'image_full_path': '',
      'is_available': false,
    },
    {
      'id': 7001,
      'name': 'Almond Croissant',
      'sku': 'SKU-7001',
      'category_name': 'Bakery',
      'price': 2.5,
      'image_full_path': '',
      'is_available': true,
    },
  ];

  @override
  List<Map<String, dynamic>> get products => _rows;

  @override
  bool get productsLoading => false;

  @override
  Future<void> loadAllProductsWithCache() async {
    loadCalls++;
  }

  @override
  Future<bool> toggleProductAvailability(int productId, bool nextStatus) async {
    toggles.add((id: productId, status: nextStatus));
    if (failNextToggle) return false;
    _rows = _rows
        .map((row) => row['id'] == productId
            ? {...row, 'is_available': nextStatus}
            : row)
        .toList();
    notifyListeners();
    return true;
  }
}

Future<_FakeManager> _pumpProducts(
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

  await tester.tap(find.text('PRODUCTS'));
  await tester.pumpAndSettle();

  return manager;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);

  testWidgets('renders header, search, and real product rows', (tester) async {
    final manager = await _pumpProducts(tester);

    expect(find.text(PosProductsSettingsPanel.pageTitle), findsOneWidget);
    expect(find.text(PosProductsSettingsPanel.pageSubtitle), findsOneWidget);
    expect(find.text(PosProductsSettingsPanel.searchHint), findsOneWidget);

    expect(find.text('Iced Strawberry'), findsOneWidget);
    expect(find.text('SKU-9901'), findsOneWidget);
    // Formatted through the shared POS price formatter, so decimals follow
    // the live config rather than being hardcoded here.
    expect(find.text(PosHomeSpec.formatPrice(4.8)), findsOneWidget);
    expect(find.text(PosHomeSpec.formatPrice(3.9)), findsOneWidget);
    expect(find.text('Double Matcha'), findsOneWidget);
    expect(find.text('Almond Croissant'), findsOneWidget);

    // One catalogue load on entry, none per keystroke or rebuild.
    expect(manager.loadCalls, 1);
    expect(find.byType(PosToggle), findsNWidgets(3));
  });

  testWidgets('search filters by name, category, and SKU', (tester) async {
    await _pumpProducts(tester);
    final search = find.byType(TextField).first;

    await tester.enterText(search, 'croissant');
    await tester.pumpAndSettle();
    expect(find.text('Almond Croissant'), findsOneWidget);
    expect(find.text('Iced Strawberry'), findsNothing);

    // Category.
    await tester.enterText(search, 'Bakery');
    await tester.pumpAndSettle();
    expect(find.text('Almond Croissant'), findsOneWidget);
    expect(find.text('Double Matcha'), findsNothing);

    // SKU.
    await tester.enterText(search, 'SKU-8104');
    await tester.pumpAndSettle();
    expect(find.text('Double Matcha'), findsOneWidget);
    expect(find.text('Almond Croissant'), findsNothing);

    // No match.
    await tester.enterText(search, 'zzzz');
    await tester.pumpAndSettle();
    expect(find.textContaining('Nothing matches'), findsOneWidget);

    await tester.enterText(search, '');
    await tester.pumpAndSettle();
    expect(find.byType(PosToggle), findsNWidgets(3));
  });

  testWidgets('toggling a row persists through the update service',
      (tester) async {
    final manager = await _pumpProducts(tester);

    PosToggle toggleFor(String name) {
      final row = find.ancestor(
        of: find.text(name),
        matching: find.byType(Row),
      );
      return tester.widget<PosToggle>(
        find.descendant(of: row.first, matching: find.byType(PosToggle)),
      );
    }

    expect(toggleFor('Iced Strawberry').value, isTrue);
    expect(toggleFor('Double Matcha').value, isFalse);

    await tester.tap(find.descendant(
      of: find.ancestor(
        of: find.text('Double Matcha'),
        matching: find.byType(Row),
      ).first,
      matching: find.byType(PosToggle),
    ));
    await tester.pumpAndSettle();

    expect(manager.toggles, [(id: 8104, status: true)]);
    expect(toggleFor('Double Matcha').value, isTrue);
    // Other rows are untouched.
    expect(toggleFor('Iced Strawberry').value, isTrue);
  });

  testWidgets('no overflow at tablet width', (tester) async {
    await _pumpProducts(tester, size: const Size(1024, 768));
    expect(tester.takeException(), isNull);
    expect(find.text('Iced Strawberry'), findsOneWidget);
  });

  testWidgets('matches the Figma 1641:3975 frame', (tester) async {
    await _pumpProducts(tester);

    await expectLater(
      find.byType(PosSettingsScreen),
      matchesGoldenFile('goldens/pos_settings_products_1366.png'),
    );
  }, skip: !Platform.isMacOS && !Platform.isLinux);

  test('spec follows Figma 1641:3975 row geometry', () {
    expect(PosProductsSettingsSpec.rowHeight, 66);
    expect(PosProductsSettingsSpec.thumbSize, 34);
    expect(PosProductsSettingsSpec.cardRadius, 16);
    expect(PosSettingsSection.products.label, 'PRODUCTS');
  });
}
