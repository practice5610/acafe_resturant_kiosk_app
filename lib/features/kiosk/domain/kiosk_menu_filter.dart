import 'package:flutter/material.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/features/category/providers/category_provider.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_allergen_filter_row.dart';
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
    child: Builder(
      // Its own context so the allergen row can close THIS sheet before the
      // popup opens; the outer `context` belongs to the page underneath.
      builder: (sheetContext) => Container(
        decoration: const BoxDecoration(
          color: KioskSearchTheme.pageBg,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
        ),
        child: FilterWidget(
          maxValue: maxPrice,
          // Allergens sit above Sort by: a customer who waved the popup away on
          // their first product tap has no other way back to it, so this is the
          // way IN rather than a nicety, and burying it under the price chips
          // would defeat the point.
          leadingSection: KioskAllergenFilterRow(
            onBeforeOpen: () => Navigator.of(sheetContext).pop(),
          ),
          onApply: () {
            searchProvider.commitFilters();
          },
        ),
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

/// Merchandising tag to show as the menu-card corner badge, or null.
///
/// Allergen tags (Egg, Dairy, …) never qualify — they power the allergen
/// filter / customize notice only. Prefer an explicit kiosk-filter pill
/// (Popular, Seasonal, …); otherwise the first non-allergen tag wins.
ProductTag? kioskMenuCardBadgeTag(Product product) {
  final List<ProductTag> tags = product.tags ?? const <ProductTag>[];
  ProductTag? fallback;
  for (final ProductTag tag in tags) {
    if (tag.isAllergen == true) continue;
    final String raw = tag.tag?.trim() ?? '';
    if (raw.isEmpty) continue;
    if (tag.isKioskFilter == true) {
      return tag;
    }
    fallback ??= tag;
  }
  return fallback;
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
  return productHasAnyKioskTag(product, {normalizeKioskTag(pillLabel)});
}

/// True when the product carries at least one of [normalizedWanted] (values
/// already run through [normalizeKioskTag]).
bool productHasAnyKioskTag(Product product, Set<String> normalizedWanted) {
  if (normalizedWanted.isEmpty) return false;
  for (final ProductTag tag in product.tags ?? const <ProductTag>[]) {
    if (normalizedWanted.contains(normalizeKioskTag(tag.tag ?? ''))) {
      return true;
    }
  }
  return false;
}

/// Products matching ANY of the selected pills, not all of them.
///
/// The pills are merchandising tags — a drink is Popular *or* Seasonal and
/// almost never both — so intersecting them would empty the grid on the second
/// tap. Union means each extra pill widens the menu, which is what a row of
/// toggles looks like it does. An empty selection is "no tag filter".
List<Product> filterKioskProductsByTag({
  required List<Product> products,
  Set<String> pillLabels = const <String>{},
}) {
  final Set<String> wanted = pillLabels
      .map(normalizeKioskTag)
      .where((String t) => t.isNotEmpty)
      .toSet();
  if (wanted.isEmpty) {
    return products;
  }
  return products.where((p) => productHasAnyKioskTag(p, wanted)).toList();
}

/// Sort + price filtering shared by the menu (testable without providers).
///
/// Deliberately does NOT apply allergens. A price range or a sort order is a
/// preference the customer set in the filter sheet; "I can't eat nuts" is a
/// constraint that holds whether or not that sheet was ever opened. Allergens
/// are therefore applied at the display sites, next to the tag pill — see
/// [filterKioskProductsByAllergens].
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
