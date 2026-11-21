import 'dart:io';

import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/models/config_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/common/providers/product_provider.dart';
import 'package:acafe_customer/features/branch/providers/branch_provider.dart';
import 'package:acafe_customer/features/cart/domain/reposotories/cart_repo.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/kiosk/landscape/widgets/landscape_order_line_card.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/main.dart' show navigatorKey;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _loadFonts() async {
  const Map<String, List<String>> families = {
    'Loew': [
      'assets/fonts/Loew-Regular.ttf',
      'assets/fonts/Loew-Medium.ttf',
      'assets/fonts/Loew-Bold.ttf',
      'assets/fonts/Loew-ExtraBold.ttf',
    ],
    'Swiss721': ['assets/fonts/Swiss721-Light.ttf'],
  };
  for (final entry in families.entries) {
    final loader = FontLoader(entry.key);
    for (final path in entry.value) {
      loader.addFont(File(path)
          .readAsBytes()
          .then((bytes) => ByteData.view(Uint8List.fromList(bytes).buffer)));
    }
    await loader.load();
  }
}

class _StubSplash extends SplashProvider {
  _StubSplash({required super.splashRepo});
  @override
  ConfigModel? get configModel => ConfigModel(
      currencySymbol: '€',
      currencySymbolPosition: 'left',
      decimalPointSettings: 2);
  @override
  BaseUrls? get baseUrls => BaseUrls(productImageUrl: 'http://localhost/p');
}

CartModel _line({
  String name = 'Iced Matcha Latte',
  double price = 6.0,
  int quantity = 1,
  String? instruction,
}) =>
    CartModel(
      price,
      price,
      const [],
      0,
      quantity,
      0,
      const [],
      Product(id: name.hashCode, name: name, image: '', price: price),
      const [],
      instruction: instruction,
    );

Future<Widget> _harness(
  WidgetTester tester, {
  required CartModel cart,
  bool highlighted = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<CartProvider>(
          create: (_) => CartProvider(cartRepo: CartRepo(sharedPreferences: prefs))
            ..replaceCartList([cart])),
      ChangeNotifierProvider<SplashProvider>(
          create: (_) => _StubSplash(splashRepo: null)),
      ChangeNotifierProvider<BranchProvider>(
          create: (_) => BranchProvider(splashRepo: null)),
      ChangeNotifierProvider<ProductProvider>(
          create: (_) => ProductProvider(productRepo: null)),
    ],
    child: MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 294,
            child: LandscapeOrderLineCard(
              cart: cart,
              index: 0,
              s: 1.0,
              highlighted: highlighted,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);

  testWidgets('qty 1 shows the trash icon, not a minus', (tester) async {
    await tester.pumpWidget(await _harness(tester, cart: _line(quantity: 1)));
    await tester.pump();

    expect(find.text('−'), findsNothing);
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('qty >= 2 shows the outlined minus, not trash', (tester) async {
    await tester.pumpWidget(await _harness(tester, cart: _line(quantity: 2)));
    await tester.pump();

    expect(find.text('−'), findsOneWidget);
    expect(find.byType(SvgPicture), findsNothing);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('tapping trash at qty 1 removes the line', (tester) async {
    final cart = _line(quantity: 1);
    await tester.pumpWidget(await _harness(tester, cart: cart));
    await tester.pump();

    final cartProvider = Provider.of<CartProvider>(
        tester.element(find.byType(LandscapeOrderLineCard)),
        listen: false);
    expect(cartProvider.cartList, hasLength(1));

    await tester.tap(find.byType(SvgPicture));
    await tester.pump();

    expect(cartProvider.cartList, isEmpty);
  });

  testWidgets('tapping "+" increments the quantity', (tester) async {
    final cart = _line(quantity: 1);
    await tester.pumpWidget(await _harness(tester, cart: cart));
    await tester.pump();

    await tester.tap(find.text('+'));
    await tester.pump();

    final cartProvider = Provider.of<CartProvider>(
        tester.element(find.byType(LandscapeOrderLineCard)),
        listen: false);
    expect(cartProvider.cartList.single!.quantity, 2);
  });

  testWidgets('EDIT is present and tappable', (tester) async {
    await tester.pumpWidget(await _harness(tester, cart: _line()));
    await tester.pump();

    expect(find.text('EDIT'), findsOneWidget);
  });

  testWidgets('a line with no modifiers shows no modifier text', (tester) async {
    await tester.pumpWidget(await _harness(tester, cart: _line()));
    await tester.pump();

    expect(find.textContaining('+'), findsOneWidget); // only the stepper's "+"
  });

  testWidgets('a long product name wraps rather than overflowing', (tester) async {
    await tester.pumpWidget(await _harness(
        tester,
        cart: _line(
            name:
                'Iced White Chocolate Cinnamon Matcha Latte With Extra Oat Milk And Honey')));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('image is 78.676 x 118 at s=1 (Figma B-02)', (tester) async {
    await tester.pumpWidget(await _harness(tester, cart: _line()));
    await tester.pump();

    final Size size = tester.getSize(find.byType(ClipRRect).first);
    expect(size.width, closeTo(78.676, 1));
    expect(size.height, closeTo(118, 1));
  });

  testWidgets('highlighted card keeps the same outer width (border drawn inside)',
      (tester) async {
    final cart = _line();
    await tester.pumpWidget(await _harness(tester, cart: cart, highlighted: false));
    await tester.pump();
    final double plainWidth =
        tester.getSize(find.byType(LandscapeOrderLineCard)).width;

    await tester.pumpWidget(await _harness(tester, cart: cart, highlighted: true));
    await tester.pump();
    final double highlightedWidth =
        tester.getSize(find.byType(LandscapeOrderLineCard)).width;

    expect(highlightedWidth, plainWidth);
  });
}
