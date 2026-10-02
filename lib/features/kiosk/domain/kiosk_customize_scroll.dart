import 'package:flutter/widgets.dart';

import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/common/providers/product_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_customize_sections.dart';

/// Scroll-to-error support for the product customize screens (POS + Kiosk).
///
/// This file adds NO validation rules. It reuses the exact same conditions the
/// screens already check in `_validate*`, only so the screen can learn WHICH
/// section is the first invalid one and scroll it into view. The snackbar and
/// the add-to-cart gate are untouched.
///
/// Sections are returned in the same top-to-bottom order both screens render
/// them: size → dietary → add-on groups → cup/can. Validating in this order is
/// what lets "scroll to the first problem" match what the customer sees, rather
/// than raw variation index order.

/// Which kind of section a reference points at.
enum ProductSectionKind { size, dietary, addOn, cupCan }

/// Identifies one rendered section so a [GlobalKey] can be hung on it and looked
/// up again when scrolling. Used as a map key, hence the value equality.
@immutable
class ProductSectionRef {
  final ProductSectionKind kind;

  /// Variation index for size / dietary / cup-can sections.
  final int? variationIndex;

  /// Add-on group id for add-on sections.
  final int? addOnGroupId;

  const ProductSectionRef._(this.kind, {this.variationIndex, this.addOnGroupId});

  factory ProductSectionRef.size(int variationIndex) =>
      ProductSectionRef._(ProductSectionKind.size, variationIndex: variationIndex);
  factory ProductSectionRef.dietary(int variationIndex) =>
      ProductSectionRef._(ProductSectionKind.dietary,
          variationIndex: variationIndex);
  factory ProductSectionRef.cupCan(int variationIndex) =>
      ProductSectionRef._(ProductSectionKind.cupCan,
          variationIndex: variationIndex);
  factory ProductSectionRef.addOn(int addOnGroupId) =>
      ProductSectionRef._(ProductSectionKind.addOn, addOnGroupId: addOnGroupId);

  @override
  bool operator ==(Object other) =>
      other is ProductSectionRef &&
      other.kind == kind &&
      other.variationIndex == variationIndex &&
      other.addOnGroupId == addOnGroupId;

  @override
  int get hashCode => Object.hash(kind, variationIndex, addOnGroupId);
}

/// Same single-select / multi-select / minimum rules the screens already apply
/// to a variation — expressed read-only so it can be asked "is this section
/// still a problem?" without touching the snackbar.
bool _variationValid(Variation v, int index, ProductProvider pp) {
  if (index < 0 || index >= pp.selectedVariations.length) return true;
  if (!v.isMultiSelect! &&
      v.isRequired! &&
      !pp.selectedVariations[index].contains(true)) {
    return false;
  }
  if (v.isMultiSelect! &&
      (v.isRequired! || pp.selectedVariations[index].contains(true)) &&
      v.min! > pp.selectedVariationLength(pp.selectedVariations, index)) {
    return false;
  }
  return true;
}

/// Same add-on group minimum rule the screens already apply.
bool _addOnGroupValid(AddOnGroup group, Product product, ProductProvider pp) {
  int selected = 0;
  for (final addon in group.addons) {
    final int? i = product.indexOfAddOn(addon.id);
    if (i != null &&
        i < pp.addOnActiveList.length &&
        pp.addOnActiveList[i]) {
      selected++;
    }
  }
  final bool required = group.isRequired || group.min > 0;
  final int min = group.isSingle ? (required ? 1 : 0) : group.min;
  return !(required && selected < min);
}

/// Every section this product renders, in on-screen order.
List<ProductSectionRef> orderedProductSections(Product product) {
  final sections = KioskCustomizeSections.of(product);
  return [
    for (final e in sections.size) ProductSectionRef.size(e.key),
    for (final e in sections.dietary) ProductSectionRef.dietary(e.key),
    for (final g in product.effectiveAddOnGroups)
      if (g.id != null) ProductSectionRef.addOn(g.id!),
    for (final e in sections.cupCan) ProductSectionRef.cupCan(e.key),
  ];
}

/// The first section that fails validation, scanning top to bottom, or null when
/// every section is valid. Reuses the screens' existing rules — adds none.
ProductSectionRef? firstInvalidProductSection(
    Product product, ProductProvider pp) {
  final sections = KioskCustomizeSections.of(product);

  for (final e in sections.size) {
    if (!_variationValid(e.value, e.key, pp)) {
      return ProductSectionRef.size(e.key);
    }
  }
  for (final e in sections.dietary) {
    if (!_variationValid(e.value, e.key, pp)) {
      return ProductSectionRef.dietary(e.key);
    }
  }
  for (final g in product.effectiveAddOnGroups) {
    if (g.id != null && !_addOnGroupValid(g, product, pp)) {
      return ProductSectionRef.addOn(g.id!);
    }
  }
  for (final e in sections.cupCan) {
    if (!_variationValid(e.value, e.key, pp)) {
      return ProductSectionRef.cupCan(e.key);
    }
  }
  return null;
}

/// Smoothly bring the section carrying [key] to near the top of its enclosing
/// scroll view. No-ops when the key is not mounted or not inside a scrollable
/// (e.g. the kiosk pinned layout, where the section is already on screen).
void scrollProductSectionIntoView(GlobalKey key) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final BuildContext? ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      // Near the top of the viewport, leaving a little breathing room below any
      // sticky chrome above the scroll area.
      alignment: 0.05,
    );
  });
}
