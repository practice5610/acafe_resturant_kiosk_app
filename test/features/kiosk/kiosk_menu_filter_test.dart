import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_menu_filter.dart';
import 'package:acafe_customer/features/search/providers/search_provider.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSearchProvider implements SearchProvider {
  _FakeSearchProvider({
    this.selectedSortByIndex,
    this.selectedPriceIndex,
    this.priceFilterList = const [],
  });

  @override
  final int? selectedSortByIndex;
  @override
  final int? selectedPriceIndex;
  @override
  final List<List<int>> priceFilterList;

  @override
  List<String> get getSortByList =>
      const ['a_to_z', 'z_to_a', 'price_high_to_low', 'price_low_to_high'];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Product _product({required String name, required double price}) {
  return Product(name: name, price: price);
}

void main() {
  group('filterKioskProducts', () {
    test('sorts products A to Z', () {
      final result = filterKioskProducts(
        products: [
          _product(name: 'Zebra', price: 10),
          _product(name: 'Apple', price: 10),
        ],
        searchProvider: _FakeSearchProvider(selectedSortByIndex: 0),
      );

      expect(result.map((p) => p.name), ['Apple', 'Zebra']);
    });

    test('filters by price range', () {
      final result = filterKioskProducts(
        products: [
          _product(name: 'Cheap', price: 5),
          _product(name: 'Expensive', price: 50),
        ],
        searchProvider: _FakeSearchProvider(
          selectedPriceIndex: 0,
          priceFilterList: const [
            [0, 10],
          ],
        ),
      );

      expect(result.length, 1);
      expect(result.first.name, 'Cheap');
    });
  });

  group('filterKioskProductsByTag', () {
    Product tagged(String name, List<String> tagNames) {
      return Product(
        name: name,
        price: 5,
        tags: tagNames.map((t) => ProductTag(tag: t)).toList(),
      );
    }

    test('keeps the full category list when no pill is selected', () {
      final products = [
        tagged('Latte', ['Popular']),
        tagged('Espresso', const []),
      ];
      expect(
        filterKioskProductsByTag(products: products, pillLabels: const {})
            .map((p) => p.name),
        ['Latte', 'Espresso'],
      );
    });

    test('shows only products with that tag in the current list', () {
      final result = filterKioskProductsByTag(
        products: [
          tagged('Latte', ['Popular']),
          tagged('Espresso', ['Signature']),
          tagged('Water', const []),
        ],
        pillLabels: const {'POPULAR'},
      );

      expect(result.map((p) => p.name), ['Latte']);
    });

    test('matches Figma CEROMONIAL to the seeded Ceremonial tag', () {
      final result = filterKioskProductsByTag(
        products: [
          tagged('Matcha', ['Ceremonial']),
          tagged('Latte', ['Popular']),
        ],
        pillLabels: const {'CEROMONIAL'},
      );

      expect(result.map((p) => p.name), ['Matcha']);
    });

    test('shows the union of several selected pills, not the intersection',
        () {
      final result = filterKioskProductsByTag(
        products: [
          tagged('Latte', ['Popular']),
          tagged('Espresso', ['Signature']),
          tagged('Mango', ['Seasonal']),
          tagged('Water', const []),
        ],
        pillLabels: const {'POPULAR', 'SIGNATURE'},
      );

      expect(result.map((p) => p.name), ['Latte', 'Espresso']);
    });

    test('lists a product carrying two selected tags only once', () {
      final result = filterKioskProductsByTag(
        products: [
          tagged('Latte', ['Popular', 'Signature']),
          tagged('Water', const []),
        ],
        pillLabels: const {'POPULAR', 'SIGNATURE'},
      );

      expect(result.map((p) => p.name), ['Latte']);
    });

    test('normalizes every selected pill, not just the first', () {
      final result = filterKioskProductsByTag(
        products: [
          tagged('Matcha', ['Ceremonial']),
          tagged('Espresso', ['Special']),
          tagged('Water', const []),
        ],
        pillLabels: const {'CEROMONIAL', 'SPECIALS'},
      );

      expect(result.map((p) => p.name), ['Matcha', 'Espresso']);
    });

    test('matches Specials pill to a Special tag', () {
      expect(
        productHasKioskTag(
          tagged('Espresso', ['Special']),
          'SPECIALS',
        ),
        isTrue,
      );
    });
  });

  group('kioskMenuCardBadgeTag', () {
    test('hides allergen-only tags from the menu card badge', () {
      final product = Product(
        name: 'New Test Live 2',
        tags: [
          ProductTag(tag: 'Egg', isAllergen: true, isKioskFilter: false),
        ],
      );

      expect(kioskMenuCardBadgeTag(product), isNull);
    });

    test('still shows a merchandising pill when allergens are also present', () {
      final product = Product(
        name: 'Latte',
        tags: [
          ProductTag(tag: 'Egg', isAllergen: true, isKioskFilter: false),
          ProductTag(tag: 'Popular', isAllergen: false, isKioskFilter: true),
        ],
      );

      expect(kioskMenuCardBadgeTag(product)?.tag, 'Popular');
    });

    test('prefers kiosk-filter pill over a plain non-allergen tag', () {
      final product = Product(
        name: 'Flat White',
        tags: [
          ProductTag(tag: 'House', isAllergen: false, isKioskFilter: false),
          ProductTag(tag: 'Seasonal', isAllergen: false, isKioskFilter: true),
        ],
      );

      expect(kioskMenuCardBadgeTag(product)?.tag, 'Seasonal');
    });
  });
}
