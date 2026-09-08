import 'package:acafe_customer/features/category/providers/category_provider.dart';
import 'package:acafe_customer/features/search/providers/search_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SearchProvider filter state', () {
    late SearchProvider provider;
    late CategoryProvider categoryProvider;

    setUp(() {
      provider = SearchProvider(searchRepo: null);
      categoryProvider = CategoryProvider(categoryRepo: null);
    });

    test('sort selection toggles off when tapped again', () {
      provider.onChangeSortByIndex(1);
      expect(provider.selectedSortByIndex, 1);

      provider.onChangeSortByIndex(1);
      expect(provider.selectedSortByIndex, isNull);
    });

    test('price selection toggles off when tapped again', () {
      provider.updatePriceFilter(0);
      expect(provider.selectedPriceIndex, 0);

      provider.updatePriceFilter(0);
      expect(provider.selectedPriceIndex, isNull);
    });

    test('resetFilterData clears all selections', () {
      provider.onChangeSortByIndex(0);
      provider.updatePriceFilter(0);
      provider.onChangeHalalTagStatus(status: true);

      provider.resetFilterData(isUpdate: false, categoryProvider: categoryProvider);

      expect(provider.selectedSortByIndex, isNull);
      expect(provider.selectedPriceIndex, isNull);
      expect(provider.halalTagStatus, isFalse);
    });

    test('hasActiveFilters reflects provider + category selections', () {
      provider.onChangeSortByIndex(2);
      expect(provider.hasActiveFilters(categoryProvider.selectedCategoryList), isTrue);

      provider.resetFilterData(isUpdate: false, categoryProvider: categoryProvider);
      expect(provider.hasActiveFilters(categoryProvider.selectedCategoryList), isFalse);

      categoryProvider.updateSelectCategory(id: 3);
      expect(provider.hasActiveFilters(categoryProvider.selectedCategoryList), isTrue);
    });
  });
}
