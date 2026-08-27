import 'package:flutter/material.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/features/category/providers/category_provider.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_bottom_sheet.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_ui.dart';
import 'package:acafe_customer/features/search/providers/search_provider.dart';
import 'package:acafe_customer/features/search/widget/filter_widget.dart';
import 'package:acafe_customer/features/search/widget/kiosk_search_theme.dart';
import 'package:acafe_customer/helper/price_converter_helper.dart';
import 'package:provider/provider.dart';

/// Opens the shared search [FilterWidget] sheet for the kiosk menu.
void openKioskMenuFilterSheet(BuildContext context) {
  final categoryProvider =
      Provider.of<CategoryProvider>(context, listen: false);
  final searchProvider = Provider.of<SearchProvider>(context, listen: false);

  if (categoryProvider.categoryList == null) {
    categoryProvider.getCategoryList(true);
  }

  final double maxPrice = kioskMenuMaxProductPrice(categoryProvider);
  searchProvider.initPriceFilterList(maxPrice);

  showKioskBottomSheet<void>(
    context,
    maxWidth: KioskUI.filterSheetMaxWidth,
    heightFactor: 0.65,
    expandToHeightFactor: true,
    child: Container(
      decoration: const BoxDecoration(
        color: KioskSearchTheme.pageBg,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: FilterWidget(
        maxValue: maxPrice,
        onApply: () {
          searchProvider.commitFilters();
        },
      ),
    ),
  );
}

/// Highest discounted unit price across prefetched kiosk products (for price chips).
double kioskMenuMaxProductPrice(CategoryProvider categoryProvider) {
  double max = 0;
  for (final product in categoryProvider.allPrefetchedProducts) {
    final price = kioskProductUnitPrice(product);
    if (price > max) max = price;
  }
  return max > 0 ? max.ceilToDouble() : 1000;
}

double kioskProductUnitPrice(Product product) {
  return PriceConverterHelper.convertWithDiscount(
        product.price,
        product.discount,
        product.discountType,
      ) ??
      product.price ??
      0;
}

/// Applies the shared search filter state to kiosk menu products.
List<Product> applyKioskMenuFilters({
  required CategoryProvider categoryProvider,
  required SearchProvider searchProvider,
}) {
  final List<Product> source = categoryProvider.selectedCategoryList.isNotEmpty
      ? categoryProvider.kioskProductsForCategoryIds(
          categoryProvider.selectedCategoryList,
        )
      : List<Product>.from(
          categoryProvider.categoryProductModel?.products ?? const [],
        );

  return filterKioskProducts(
    products: source,
    searchProvider: searchProvider,
  );
}

/// Case-insensitive match of a hardcoded kiosk pill (POPULAR, CEROMONIAL, …)
/// against a product's tags from the backend. Figma's "CEROMONIAL" spelling
/// and "Special"/"Specials" both resolve to the seeded tag names.
String normalizeKioskTag(String value) {
  final String s = value.trim().toLowerCase();
  switch (s) {
    case 'ceromonial':
      return 'ceremonial';
    case 'special':
      return 'specials';
    default:
      return s;
  }
}

bool productHasKioskTag(Product product, String pillLabel) {
  final String wanted = normalizeKioskTag(pillLabel);
  if (wanted.isEmpty) return false;
  for (final ProductTag tag in product.tags ?? const <ProductTag>[]) {
    if (normalizeKioskTag(tag.tag ?? '') == wanted) {
      return true;
    }
  }
  return false;
}

List<Product> filterKioskProductsByTag({
  required List<Product> products,
  String? pillLabel,
}) {
  if (pillLabel == null || pillLabel.trim().isEmpty) {
    return products;
  }
  return products.where((p) => productHasKioskTag(p, pillLabel)).toList();
}

/// Sort + price filtering shared by the menu (testable without providers).
List<Product> filterKioskProducts({
  required List<Product> products,
  required SearchProvider searchProvider,
}) {
  List<Product> filtered = List<Product>.from(products);

  final int? priceIndex = searchProvider.selectedPriceIndex;
  if (priceIndex != null &&
      priceIndex < searchProvider.priceFilterList.length) {
    final range = searchProvider.priceFilterList[priceIndex];
    final double min = range.first.toDouble();
    final double max = range.last.toDouble();
    filtered = filtered.where((p) {
      final price = kioskProductUnitPrice(p);
      return price >= min && price <= max;
    }).toList();
  }

  final int? sortIndex = searchProvider.selectedSortByIndex;
  if (sortIndex != null && sortIndex < searchProvider.getSortByList.length) {
    final String sortKey = searchProvider.getSortByList[sortIndex];
    switch (sortKey) {
      case 'a_to_z':
        filtered.sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));
      case 'z_to_a':
        filtered.sort((a, b) => (b.name ?? '').compareTo(a.name ?? ''));
      case 'price_high_to_low':
        filtered.sort(
          (a, b) =>
              kioskProductUnitPrice(b).compareTo(kioskProductUnitPrice(a)),
        );
      case 'price_low_to_high':
        filtered.sort(
          (a, b) =>
              kioskProductUnitPrice(a).compareTo(kioskProductUnitPrice(b)),
        );
    }
  }

  return filtered;
}

bool kioskMenuFiltersActive(
  CategoryProvider categoryProvider,
  SearchProvider searchProvider,
) {
  return searchProvider.filtersCommitted &&
      searchProvider.hasActiveFilters(categoryProvider.selectedCategoryList);
}
