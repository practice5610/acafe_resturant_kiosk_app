import 'dart:io';

import 'package:acafe_customer/common/models/config_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/features/kiosk/landscape/widgets/landscape_product_card.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

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

Widget _harness(Product product) {
  return ChangeNotifierProvider<SplashProvider>(
    create: (_) => _StubSplash(splashRepo: null),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 250,
            height: 374.95,
            child: LandscapeProductCard(
              tileWidth: 250,
              product: product,
              showImages: true,
            ),
          ),
        ),
      ),
    ),
  );
}

Product _product({
  String name = 'Iced Matcha Latte',
  BranchProduct? branchProduct,
  List<ProductTag>? tags,
}) =>
    Product(
      id: 1,
      name: name,
      description: 'Ceremonial matcha whisked over cold milk and ice.',
      image: 'matcha.webp',
      price: 6.0,
      branchProduct: branchProduct,
      tags: tags,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);

  group('out of stock', () {
    testWidgets('a product with remaining stock is tappable, no badge',
        (tester) async {
      final product = _product(
        branchProduct: BranchProduct(stockType: 'quantity', stock: 10, soldQuantity: 2),
      );
      await tester.pumpWidget(_harness(product));
      await tester.pump();

      expect(find.textContaining('OUT OF STOCK'), findsNothing);
      expect(find.byType(Opacity), findsNothing);
    });

    testWidgets('a product with zero remaining stock shows the badge at 45% opacity and is not tappable',
        (tester) async {
      final product = _product(
        branchProduct: BranchProduct(stockType: 'quantity', stock: 10, soldQuantity: 10),
      );
      bool tapped = false;
      await tester.pumpWidget(_harness(product));
      await tester.pump();

      expect(find.text('OUT OF STOCK'), findsOneWidget);
      final Opacity opacity = tester.widget(find.byType(Opacity).first);
      expect(opacity.opacity, 0.45);

      await tester.tap(find.byType(LandscapeProductCard));
      await tester.pump();
      expect(tapped, isFalse);
    });

    testWidgets('unlimited stock is never out of stock', (tester) async {
      final product = _product(
        branchProduct: BranchProduct(stockType: 'unlimited', stock: 0, soldQuantity: 999),
      );
      await tester.pumpWidget(_harness(product));
      await tester.pump();

      expect(find.text('OUT OF STOCK'), findsNothing);
    });
  });

  group('allergen row', () {
    testWidgets('no allergens renders no circles', (tester) async {
      final product = _product(tags: const []);
      await tester.pumpWidget(_harness(product));
      await tester.pump();

      expect(find.byType(Semantics, skipOffstage: false), findsWidgets);
      // No allergen-specific swatch colours present.
      expect(find.byWidgetPredicate((w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).color == const Color(0xFF8B5E3C)), findsNothing);
    });

    testWidgets('one allergen renders one dairy circle', (tester) async {
      final product = _product(tags: [
        ProductTag(tag: 'Dairy', isAllergen: true),
      ]);
      await tester.pumpWidget(_harness(product));
      await tester.pump();

      expect(find.byWidgetPredicate((w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).color == const Color(0xFF8B5E3C)), findsOneWidget);
    });

    testWidgets('two allergens render two circles (dairy + soy)', (tester) async {
      final product = _product(tags: [
        ProductTag(tag: 'Dairy', isAllergen: true),
        ProductTag(tag: 'Soy', isAllergen: true),
      ]);
      await tester.pumpWidget(_harness(product));
      await tester.pump();

      expect(find.byWidgetPredicate((w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).color == const Color(0xFF8B5E3C)), findsOneWidget);
      expect(find.byWidgetPredicate((w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).color == const Color(0xFF529B58)), findsOneWidget);
    });
  });
}
