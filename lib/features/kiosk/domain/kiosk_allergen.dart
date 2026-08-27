import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/utill/images.dart';

/// The allergens the kiosk can filter on — Figma POS node 1385:15054
/// ("allergen-filter-popup").
///
/// This is a CLOSED set on purpose. The popup is the first thing a customer
/// sees when they reach for a product, so it has to stay a five-row glance, not
/// a scrolling list that grows every time someone adds a tag in the back
/// office. The backend seeds exactly these five as allergen tags; a tag that is
/// not one of them is simply not an allergen as far as the kiosk is concerned.
///
/// ## Where the data comes from
/// Allergens ride the existing `tags` pipeline rather than a new product
/// column. The kiosk products endpoint already eager-loads `tags`
/// (`KioskController::products`) and [Product.tags] already parses them, so a
/// product declares "contains nuts" by carrying the seeded `Nuts` tag with
/// `is_allergen = 1`. Two things fall out of that for free:
///
///  * **No new API surface.** The column ships in the same JSON the kiosk
///    already fetches.
///  * **Allergen tags never render as badges.** The product card only draws
///    tags with `is_kiosk_filter == true` (see `_badgeForProduct`), and an
///    allergen tag is not a merchandising pill, so "Nuts" does not suddenly
///    appear on the card next to "POPULAR".
enum KioskAllergen {
  egg(
    label: 'Egg',
    swatch: Color(0xFFE28F3D),
    icon: Images.allergenEggSvg,
    aliases: <String>['egg', 'eggs'],
  ),
  gluten(
    label: 'Gluten',
    swatch: Color(0xFFD36140),
    icon: Images.allergenGlutenSvg,
    aliases: <String>['gluten', 'wheat'],
  ),
  dairy(
    label: 'Dairy',
    swatch: Color(0xFF8B5E3C),
    icon: Images.allergenDairySvg,
    aliases: <String>['dairy', 'milk', 'lactose'],
  ),
  nuts(
    label: 'Nuts',
    swatch: Color(0xFFC24F54),
    icon: Images.allergenNutsSvg,
    aliases: <String>['nuts', 'nut', 'peanut', 'peanuts', 'tree nuts'],
  ),
  soy(
    label: 'Soy',
    swatch: Color(0xFF529B58),
    icon: Images.allergenSoySvg,
    aliases: <String>['soy', 'soya', 'soybean', 'soybeans'],
  );

  /// English fallback shown when the translation key is missing.
  final String label;

  /// Circle behind the icon. Straight from Figma — these are the only place
  /// these five colours appear, so they live here rather than in [BrandColors].
  final Color swatch;

  /// White line icon asset exported from the Figma component.
  final String icon;

  /// Tag spellings that resolve to this allergen. The back office is a free
  /// text field, so "Peanuts" and "Tree Nuts" have to land on [nuts] rather
  /// than silently failing to filter anything.
  final List<String> aliases;

  const KioskAllergen({
    required this.label,
    required this.swatch,
    required this.icon,
    required this.aliases,
  });

  /// Translation key for the row label (`allergen_egg`, `allergen_gluten`, …).
  String get translationKey => 'allergen_$name';
}

/// Normalizes a back-office tag string for allergen matching.
///
/// Mirrors [normalizeKioskTag] in `kiosk_menu_filter.dart`: lower-cased and
/// trimmed, plus separators folded to single spaces so `tree-nuts`,
/// `Tree_Nuts` and `TREE NUTS` all resolve.
String normalizeKioskAllergenTag(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'[\s_-]+'), ' ');

/// Resolves a single tag string to an allergen, or null when it is an ordinary
/// merchandising tag (POPULAR, SEASONAL, …).
KioskAllergen? kioskAllergenForTag(String value) {
  final String wanted = normalizeKioskAllergenTag(value);
  if (wanted.isEmpty) return null;
  for (final KioskAllergen allergen in KioskAllergen.values) {
    if (allergen.aliases.contains(wanted)) return allergen;
  }
  return null;
}

/// Every allergen a product declares.
///
/// A tag counts as an allergen when the backend flagged it (`is_allergen`) OR
/// when its name is one of the known allergen spellings and it is not a
/// merchandising pill. The name fallback matters: `is_allergen` arrives as
/// `false` on any response from a backend that has not run the migration yet,
/// and a kiosk in that state should still honour a product tagged "Nuts"
/// rather than silently filtering nothing.
///
/// [ProductTag.isKioskFilter] wins over both. A pill that happens to be called
/// "Nuts" is a category, not a warning, so it can never quietly hide half the
/// menu.
Set<KioskAllergen> kioskProductAllergens(Product product) {
  final Set<KioskAllergen> found = <KioskAllergen>{};
  for (final ProductTag tag in product.tags ?? const <ProductTag>[]) {
    if (tag.isKioskFilter == true) continue;
    final KioskAllergen? allergen = kioskAllergenForTag(tag.tag ?? '');
    if (allergen != null) found.add(allergen);
  }
  return found;
}

/// True when [product] contains at least one of the allergens the customer
/// asked to avoid.
bool kioskProductHasAllergen(Product product, Set<KioskAllergen> avoided) {
  if (avoided.isEmpty) return false;
  final Set<KioskAllergen> allergens = kioskProductAllergens(product);
  if (allergens.isEmpty) return false;
  return allergens.any(avoided.contains);
}

/// Drops every product containing an avoided allergen.
///
/// Returns [products] unchanged when nothing is selected, so the common path
/// (a customer who taps APPLY with no boxes ticked) allocates nothing.
List<Product> filterKioskProductsByAllergens({
  required List<Product> products,
  required Set<KioskAllergen> avoided,
}) {
  if (avoided.isEmpty) return products;
  return products
      .where((product) => !kioskProductHasAllergen(product, avoided))
      .toList();
}

/// The customer's allergen choices for the CURRENT order.
///
/// Scope is one order, matching how the kiosk treats every other "we already
/// asked this person" memory (see `resetKioskUpsellMemory`): the popup opens on
/// the first product tap, the answer filters the rest of that order, and the
/// next customer to walk up starts clean. [KioskSession.reset] clears it.
///
/// A [ChangeNotifier] rather than a plain singleton because the menu grid has
/// to re-filter the moment APPLY is tapped — the customer is looking straight
/// at the grid when the popup closes over it.
class KioskAllergenPreferences extends ChangeNotifier {
  KioskAllergenPreferences._();

  static final KioskAllergenPreferences instance = KioskAllergenPreferences._();

  final Set<KioskAllergen> _avoided = <KioskAllergen>{};

  /// Whether the popup has already been shown in this order. Set on APPLY *and*
  /// on dismiss — a customer who backs out has answered "nothing to declare",
  /// and re-asking on every single product tap would be the worst version of
  /// this feature.
  bool _asked = false;

  /// Allergens the customer is avoiding. Unmodifiable — mutate via
  /// [applySelection] so listeners actually fire.
  Set<KioskAllergen> get avoided => UnmodifiableSetView<KioskAllergen>(_avoided);

  bool get hasSelection => _avoided.isNotEmpty;

  bool get asked => _asked;

  /// Marks the popup as shown without changing the selection — used when the
  /// customer dismisses via the back arrow.
  void markAsked() {
    if (_asked) return;
    _asked = true;
    // No notify: the filter result is unchanged, so nothing needs to rebuild.
  }

  /// Commits the popup's selection.
  void applySelection(Set<KioskAllergen> selection) {
    _asked = true;
    if (setEquals(_avoided, selection)) return;
    _avoided
      ..clear()
      ..addAll(selection);
    notifyListeners();
  }

  /// New customer, new order.
  void reset() {
    _asked = false;
    if (_avoided.isEmpty) return;
    _avoided.clear();
    notifyListeners();
  }
}

/// Clears the allergen answer for the next customer. Named to match
/// [resetKioskUpsellMemory] so `KioskSession.reset` reads as a list of the
/// per-order memories being wiped.
void resetKioskAllergenMemory() => KioskAllergenPreferences.instance.reset();
