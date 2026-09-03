import 'dart:io';

import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:acafe_customer/features/cart/domain/reposotories/cart_repo.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/category/domain/category_model.dart';
import 'package:acafe_customer/features/category/providers/category_provider.dart';
import 'package:acafe_customer/features/coupon/providers/coupon_provider.dart';
import 'package:acafe_customer/features/language/providers/localization_provider.dart';
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/pos_shell.dart';
import 'package:acafe_customer/features/pos/screens/pos_home_cart_screen.dart';
import 'package:acafe_customer/features/pos/widgets/pos_category_sidebar.dart';
import 'package:acafe_customer/features/pos/widgets/pos_filter_pill.dart';
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

Future<List<SingleChildWidget>> _providers() async {
  SharedPreferences.setMockInitialValues({
    AppConstants.branch: 1,
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
      create: (_) => CategoryProvider(categoryRepo: null),
    ),
    ChangeNotifierProvider<LocalizationProvider>(
      create: (_) => LocalizationProvider(
        sharedPreferences: prefs,
        dioClient: dio,
      ),
    ),
  ];
}

Future<void> _pumpHome(
  WidgetTester tester, {
  Size size = const Size(1366, 1024),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final providers = await _providers();
  await tester.pumpWidget(
    MultiProvider(
      providers: providers,
      child: MediaQuery(
        data: MediaQueryData(size: size),
        child: PosShell(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: const Scaffold(
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
    expect(find.text('Dine In'), findsOneWidget);
    expect(find.text('Take Away'), findsOneWidget);
    expect(find.text('Order list'), findsOneWidget);
    expect(find.text('No items'), findsOneWidget);
    expect(find.text('Add items to get started'), findsOneWidget);
    expect(find.text('Customer name'), findsOneWidget);
    expect(find.text('Table'), findsOneWidget);
    expect(find.text('Subtotal'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);

    for (final label in PosHomeSpec.filterPillLabels) {
      expect(find.text(label), findsOneWidget, reason: '$label pill missing');
    }

    expect(tester.getSize(find.byType(PosCategorySidebar)).width,
        PosHomeSpec.sidebarWidth);
    expect(tester.getSize(find.byType(PosReceiptPanel)).width,
        PosHomeSpec.receiptWidth);

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

  testWidgets('a compact window drops the side receipt for a bar',
      (tester) async {
    await _pumpHome(tester, size: const Size(430, 932));

    expect(find.byType(PosReceiptPanel), findsNothing);
    expect(find.text('Purchase Receipt'), findsOneWidget);
    expect(find.byType(PosSearchField), findsOneWidget);
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
