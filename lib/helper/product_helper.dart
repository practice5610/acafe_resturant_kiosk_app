import 'package:acafe_customer/common/models/product_model.dart';

class ProductHelper{
  /// Variations the UI/cart should use: branch pivot when it has a non-empty
  /// structure, otherwise the catalog `products.variations` template.
  static List<Variation>? effectiveVariations(Product? product) {
    final List<Variation>? branchVars = product?.branchProduct?.variations;
    if (product?.branchProduct != null &&
        (product?.branchProduct?.isAvailable ?? false) &&
        branchVars != null &&
        branchVars.isNotEmpty) {
      return branchVars;
    }
    return product?.variations;
  }

  static ({List<Variation>? variatins, double? price}) getBranchProductVariationWithPrice(Product? product){
    final List<Variation>? variationList = effectiveVariations(product);
    final double? price;
    if (product?.branchProduct != null &&
        (product?.branchProduct?.isAvailable ?? false)) {
      price = product?.branchProduct?.price;
    } else {
      price = product?.price;
    }

    return (variatins: variationList, price: price);
  }

  /// Fingerprint of fields the customize sheet must rebuild for when a
  /// product.changed socket refetch lands.
  static String catalogModifierSignature(Product? product) {
    if (product == null) return '';
    final variations = effectiveVariations(product) ?? const <Variation>[];
    final addOnGroups = product.effectiveAddOnGroups;
    final buffer = StringBuffer()
      ..write(product.id)
      ..write('|')
      ..write(product.updatedAt)
      ..write('|v:');
    for (final Variation group in variations) {
      buffer
        ..write(group.name)
        ..write(':')
        ..write(group.isMultiSelect)
        ..write(':')
        ..write(group.isRequired)
        ..write(':')
        ..write(group.min)
        ..write(':')
        ..write(group.max)
        ..write('=');
      for (final VariationValue value
          in group.variationValues ?? const <VariationValue>[]) {
        buffer
          ..write(value.level)
          ..write('@')
          ..write(value.optionPrice)
          ..write(',');
      }
      buffer.write(';');
    }
    buffer.write('|a:');
    for (final AddOnGroup group in addOnGroups) {
      buffer
        ..write(group.id)
        ..write(':')
        ..write(group.name)
        ..write(':')
        ..write(group.selectionType)
        ..write('=');
      for (final AddOns addon in group.addons) {
        buffer
          ..write(addon.id)
          ..write('@')
          ..write(addon.name)
          ..write('@')
          ..write(addon.price)
          ..write(',');
      }
      buffer.write(';');
    }
    return buffer.toString();
  }
}