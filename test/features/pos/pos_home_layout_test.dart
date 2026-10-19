import 'dart:io';

import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:acafe_customer/features/cart/domain/reposotories/cart_repo.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/category/domain/category_model.dart';
import 'package:acafe_customer/features/category/providers/category_provider.dart';
import 'package:acafe_customer/features/coupon/providers/coupon_provider.dart';
import 'package:acafe_customer/features/language/providers/localization_provider.dart';
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_responsive.dart';
import 'package:acafe_customer/features/pos/pos_shell.dart';
import 'package:acafe_customer/features/pos/screens/pos_home_cart_screen.dart';
import 'package:acafe_customer/features/pos/widgets/pos_category_sidebar.dart';
import 'package:acafe_customer/features/pos/widgets/pos_category_strip.dart';
import 'package:acafe_customer/features/pos/widgets/pos_filter_pill.dart';
import 'package:acafe_customer/features/pos/widgets/pos_product_tile.dart';
import 'package:acafe_customer/features/pos/widgets/pos_receipt_panel.dart';
import 'package:acafe_customer/features/pos/widgets/pos_search_field.dart';
import 'package:acafe_customer/features/splash/domain/reposotories/splash_repo.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/kiosk_layout_harness.dart';
import 'pos_test_kiosk_auth.dart';

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

  // The receipt's Subtotal/Discount rows are Swiss721. Without it the test
  // font draws every glyph a full em wide and a 1024 window's 285px receipt
  // "overflows" on text that fits with room to spare on a real device.
  final swiss = FontLoader('Swiss721')
    ..addFont(File('assets/fonts/Swiss721-Light.ttf')
        .readAsBytes()
        .then((bytes) => ByteData.view(Uint8List.fromList(bytes).buffer)));
  await swiss.load();
}

/// The branch's real top-level categories, from the screenshot that reported
/// the compact bugs.
final List<CategoryModel> _menu = [
  for (final (int i, String name) in const [
    'Coffee',
    'Macha',
    'Poffertjes',
    'Soft drinks',
    'Merchandise',
    'Other drinks',
  ].indexed)
    CategoryModel(id: i + 1, name: name),
];

final List<Product> _products = [
  for (final (int i, String name) in const [
    'Test product',
    'Americano_200',
    'Espresso',
    'Iced Latte',
    'Cortado',
    'Cappuccino',
    'Flat White',
  ].indexed)
    Product(id: i + 1, name: name, price: 4.0 + i),
];

/// A catalog that is already warm: what the PIN screen leaves behind, so the
/// screen paints its rail/strip and grid on the first frame.
class _WarmCategoryProvider extends CategoryProvider {
  _WarmCategoryProvider() : super(categoryRepo: null);

  @override
  List<CategoryModel>? get categoryList => _menu;

  @override
  String? get selectedSubCategoryId => '${_menu.first.id}';

  @override
  bool isKioskMenuReadyFor(String localeCode) => true;

  @override
  List<Product> kioskProductsForCategoryIds(List<int> categoryIds) =>
      _products;
}

Future<List<SingleChildWidget>> _providers({bool seeded = false}) async {
  SharedPreferences.setMockInitialValues({
    AppConstants.branch: 1,
    // Picture-less tiles: the grid geometry is identical, and the test
    // binding has no network to fetch product images from.
    if (seeded) AppConstants.kioskShowImages: false,
  });
  final prefs = await SharedPreferences.getInstance();
  final dio = DioClient(
    'http://localhost',
    null,
    loggingInterceptor: LoggingInterceptor(),
    sharedPreferences: prefs,
  );
  return [
    ChangeNotifierProvider<SplashProvider>(
      create: (_) => KioskStubSplashProvider(
        splashRepo: SplashRepo(dioClient: dio, sharedPreferences: prefs),
      ),
    ),
    ChangeNotifierProvider<CartProvider>(
      create: (_) => CartProvider(cartRepo: CartRepo(sharedPreferences: prefs)),
    ),
    ChangeNotifierProvider<CouponProvider>(
      create: (_) => CouponProvider(couponRepo: null),
    ),
    ChangeNotifierProvider<CategoryProvider>(
      create: (_) => seeded
          ? _WarmCategoryProvider()
          : CategoryProvider(categoryRepo: null),
    ),
    ChangeNotifierProvider<LocalizationProvider>(
      create: (_) => LocalizationProvider(
        sharedPreferences: prefs,
        dioClient: dio,
      ),
    ),
    // The grid and allergen filter read the per-device Show Images / allergen
    // flags; without it every pump threw ProviderNotFoundException.
    testKioskAuthProvider(prefs),
  ];
}

Future<void> _pumpHome(
  WidgetTester tester, {
  Size size = const Size(1366, 1024),
  bool seeded = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final providers = await _providers(seeded: seeded);
  await tester.pumpWidget(
    MultiProvider(
      providers: providers,
      child: MediaQuery(
        data: MediaQueryData(size: size),
        child: const PosShell(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: PosHomeSpec.pageBg,
              body: PosHomeCartScreen(),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);

  testWidgets('1366 frame paints the three Figma panes and chrome',
      (tester) async {
    await _pumpHome(tester);

    expect(find.byType(PosCategorySidebar), findsOneWidget);
    expect(find.byType(PosSearchField), findsOneWidget);
    expect(find.byType(PosReceiptPanel), findsOneWidget);

    expect(find.text('Search products..'), findsOneWidget);
    expect(find.text('Purchase Receipt'), findsOneWidget);
    // Dine In / Take Away toggle removed in the Browse-POS redesign.
    expect(find.text('Dine In'), findsNothing);
    expect(find.text('Take Away'), findsNothing);
    expect(find.text('Order list'), findsOneWidget);
    expect(find.text('No items'), findsOneWidget);
    expect(find.text('Add items to get started'), findsOneWidget);
    expect(find.text('Customer name'), findsOneWidget);
    // Table field removed in the Browse-POS redesign.
    expect(find.text('Table'), findsNothing);
    expect(find.text('Subtotal'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);

    for (final label in PosHomeSpec.filterPillLabels) {
      expect(find.text(label), findsOneWidget, reason: '$label pill missing');
    }

    // closeTo, not exact equality: at 1366 wide the desktop-floor proportional
    // model (width * 192/1366, width * 421/1366) reproduces the flat Figma
    // pixels to within floating-point noise, not bit-for-bit — no render
    // could ever show the difference.
    expect(tester.getSize(find.byType(PosCategorySidebar)).width,
        closeTo(PosHomeSpec.sidebarWidth, 0.01));
    expect(tester.getSize(find.byType(PosReceiptPanel)).width,
        closeTo(PosHomeSpec.receiptWidth, 0.01));

    expect(tester.takeException(), isNull);
  });

  testWidgets('POPULAR is the active pill on first paint', (tester) async {
    await _pumpHome(tester);

    final PosFilterPill popular = tester.widget<PosFilterPill>(
      find.widgetWithText(PosFilterPill, 'POPULAR'),
    );
    expect(popular.active, isTrue);

    final PosFilterPill ceremonial = tester.widget<PosFilterPill>(
      find.widgetWithText(PosFilterPill, 'CEREMONIAL'),
    );
    expect(ceremonial.active, isFalse);
  });

  testWidgets('tapping a lit pill clears the tag filter', (tester) async {
    await _pumpHome(tester);

    await tester.tap(find.widgetWithText(PosFilterPill, 'POPULAR'));
    await tester.pump();

    final PosFilterPill popular = tester.widget<PosFilterPill>(
      find.widgetWithText(PosFilterPill, 'POPULAR'),
    );
    expect(popular.active, isFalse);
  });

  testWidgets('a filled cart paints the cart-active receipt chrome',
      (tester) async {
    await _pumpHome(tester);

    final CartProvider cart =
        tester.element(find.byType(PosHomeCartScreen)).read<CartProvider>();
    cart.replaceCartList([
      CartModel(
        5.5,
        5.5,
        const [],
        0,
        1,
        0,
        const [],
        Product(id: 1, name: 'Oat Milk Matcha', price: 5.5),
        const [],
      ),
    ]);
    await tester.pump();

    expect(find.text('No items'), findsNothing);
    expect(find.text('Oat Milk Matcha'), findsOneWidget);
    expect(find.text('EDIT'), findsOneWidget);
    expect(find.textContaining('PAY /'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a compact window drops the side receipt for a bar',
      (tester) async {
    await _pumpHome(tester, size: const Size(430, 932));

    expect(find.byType(PosReceiptPanel), findsNothing);
    expect(find.text('Purchase Receipt'), findsOneWidget);
    expect(find.byType(PosSearchField), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('rail, search and tag pills scale with their panes', () {
    const List<Size> desktops = [
      Size(1024, 768),
      Size(1366, 1024),
      Size(1920, 1080),
    ];

    for (final Size window in desktops) {
      testWidgets(
          'search field, pills and rail track the window at '
          '${window.width.toInt()}x${window.height.toInt()}', (tester) async {
        await _pumpHome(tester, size: window);
        final double scale = PosResponsive.homeScale(window.width);

        expect(tester.getSize(find.byType(PosSearchField)).height,
            closeTo(PosHomeSpec.searchHeight * scale, 0.01));
        for (final label in PosHomeSpec.filterPillLabels) {
          expect(
              tester.getSize(find.widgetWithText(PosFilterPill, label)).height,
              closeTo(PosHomeSpec.pillHeight * scale, 0.01),
              reason: '$label pill height at $window');
        }
        expect(
            tester
                .widget<PosCategorySidebar>(find.byType(PosCategorySidebar))
                .scale,
            scale);
        expect(tester.takeException(), isNull);
      });

      testWidgets(
          'the pill row stays on one line at '
          '${window.width.toInt()}x${window.height.toInt()}', (tester) async {
        await _pumpHome(tester, size: window);

        final double firstTop = tester
            .getRect(find.widgetWithText(
                PosFilterPill, PosHomeSpec.filterPillLabels.first))
            .top;
        for (final label in PosHomeSpec.filterPillLabels) {
          expect(
              tester.getRect(find.widgetWithText(PosFilterPill, label)).top,
              closeTo(firstTop, 0.01),
              reason: '$label wrapped at $window');
        }
      });
    }

    // Narrower than the desktop floor too: nothing may sit past the search
    // field's right edge, where a hidden horizontal scroll used to park
    // CEREMONIAL out of reach of a mouse.
    for (final Size window in const [
      Size(950, 700),
      ...desktops,
      Size(2560, 1440),
    ]) {
      testWidgets(
          'every pill is fully visible at '
          '${window.width.toInt()}x${window.height.toInt()}', (tester) async {
        await _pumpHome(tester, size: window);

        final Rect search = tester.getRect(find.byType(PosSearchField));
        for (final label in PosHomeSpec.filterPillLabels) {
          final Rect pill =
              tester.getRect(find.widgetWithText(PosFilterPill, label));
          expect(pill.left, greaterThanOrEqualTo(search.left - 0.01),
              reason: '$label starts left of the row at $window');
          expect(pill.right, lessThanOrEqualTo(search.right + 0.01),
              reason: '$label runs off the row at $window');
        }
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('compact: phones and narrow windows', () {
    // Phones, the narrow browser window from the bug report (507), a
    // portrait tablet, and one px under the breakpoint.
    const List<Size> windows = [
      Size(320, 640),
      Size(360, 780),
      Size(375, 812),
      Size(414, 896),
      Size(507, 800),
      Size(768, 1024),
      Size(899, 700),
    ];

    for (final Size window in windows) {
      final String at = '${window.width.toInt()}x${window.height.toInt()}';

      testWidgets('$at: categories become a strip and nothing overflows',
          (tester) async {
        await _pumpHome(tester, size: window, seeded: true);

        expect(tester.takeException(), isNull);
        expect(find.byType(PosCategorySidebar), findsNothing);
        expect(find.byType(PosCategoryStrip), findsOneWidget);
        expect(find.byType(PosCategoryTab), findsNWidgets(_menu.length));
        expect(find.byKey(const Key('pos-sidebar-punch')), findsOneWidget);
        // The receipt docks as a bar rather than squeezing the products.
        expect(find.byType(PosReceiptPanel), findsNothing);
        expect(find.text('Purchase Receipt'), findsOneWidget);

        // The strip spans the screen; the punch action is on it.
        final Rect strip = tester.getRect(find.byType(PosCategoryStrip));
        expect(strip.width, closeTo(window.width, 0.01));
        final Rect punch =
            tester.getRect(find.byKey(const Key('pos-sidebar-punch')));
        expect(punch.right, lessThanOrEqualTo(window.width));
      });

      testWidgets('$at: tag pills stay one row and the search spans the pane',
          (tester) async {
        await _pumpHome(tester, size: window, seeded: true);

        final double firstTop = tester
            .getRect(find.widgetWithText(
                PosFilterPill, PosHomeSpec.filterPillLabels.first))
            .top;
        for (final label in PosHomeSpec.filterPillLabels) {
          expect(
              tester.getRect(find.widgetWithText(PosFilterPill, label)).top,
              closeTo(firstTop, 0.01),
              reason: '$label wrapped at $window');
        }

        final Rect search = tester.getRect(find.byType(PosSearchField));
        expect(search.left, closeTo(PosHomeSpec.compactGutter, 0.01));
        expect(window.width - search.right,
            closeTo(PosHomeSpec.compactGutter, 0.01));
      });

      testWidgets('$at: product tiles stay readable', (tester) async {
        await _pumpHome(tester, size: window, seeded: true);

        final Iterable<Element> tiles = find.byType(PosProductTile).evaluate();
        expect(tiles, isNotEmpty);
        for (final Element tile in tiles) {
          final Rect rect = tester.getRect(find.byWidget(tile.widget));
          // ~0.55 of the 221px design tile is where its 16px name drops
          // under 9px. A fixed three columns put phones at ~0.4.
          expect(rect.width, greaterThan(PosHomeSpec.tileWidth * 0.55),
              reason: 'tile ${rect.width.toStringAsFixed(1)}px at $window');
          expect(rect.right, lessThanOrEqualTo(window.width));
        }
      });
    }
  });

  group('grid columns', () {
    int columnsOnScreen(WidgetTester tester) => find
        .byType(PosProductTile)
        .evaluate()
        .map((e) => tester.getRect(find.byWidget(e.widget)).left.round())
        .toSet()
        .length;

    for (final (Size window, int columns) in const [
      (Size(375, 812), 2),
      (Size(507, 800), 2),
      (Size(768, 1024), 3),
      (Size(1024, 768), 3),
      (Size(1366, 1024), 3),
      (Size(1920, 1080), 3),
    ]) {
      testWidgets(
          '$columns across at ${window.width.toInt()}x${window.height.toInt()}',
          (tester) async {
        await _pumpHome(tester, size: window, seeded: true);
        expect(columnsOnScreen(tester), columns);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a large-format display adds columns', (tester) async {
      await _pumpHome(tester, size: const Size(2560, 1440), seeded: true);
      expect(columnsOnScreen(tester), greaterThan(3));
    });
  });

  testWidgets('the rail composition is untouched at the breakpoint',
      (tester) async {
    await _pumpHome(tester, size: const Size(900, 700), seeded: true);
    expect(find.byType(PosCategorySidebar), findsOneWidget);
    expect(find.byType(PosCategoryStrip), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('category sidebar renders uppercase labels and selection',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PosCategorySidebar(
            categories: [
              CategoryModel(id: 1, name: 'Matcha'),
              CategoryModel(id: 2, name: 'Coffee'),
            ],
            selectedId: '1',
            onSelect: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('MATCHA'), findsOneWidget);
    expect(find.text('COFFEE'), findsOneWidget);

    final PosCategoryItem matcha = tester.widget<PosCategoryItem>(
      find.widgetWithText(PosCategoryItem, 'MATCHA'),
    );
    expect(matcha.selected, isTrue);
  });
}
