import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_order_composition.dart';
import 'package:acafe_customer/helper/price_converter_helper.dart';
import 'package:acafe_customer/helper/product_helper.dart';
import 'package:acafe_customer/utill/images.dart';

/// Size groups (Small / Medium / Large) — often stored as separate one-option
/// variations. Shared by kiosk + POS customize so both classify the same way.
final RegExp kioskSizeVariationPattern =
    RegExp(r'(small|medium|large|\bsizes?\b)', caseSensitive: false);

bool kioskIsSizeVariation(Variation variation) {
  final name = (variation.name ?? '').trim();
  if (kioskSizeVariationPattern.hasMatch(name)) return true;
  final values = variation.variationValues ?? [];
  if (values.length == 1) {
    return kioskSizeVariationPattern.hasMatch((values.first.level ?? '').trim());
  }
  return false;
}

/// Bundled cup/can artwork when the option has no uploaded image.
String? kioskLocalVesselAsset(String label) {
  final String value = label.toLowerCase().trim();
  if (value.contains('cup')) return Images.kioskCupImage;
  if (value.contains('can')) return Images.kioskCanImage;
  return null;
}

/// Figma add-on / option surcharge label: `€ +1.50` when the symbol leads.
String kioskAddonPriceLabel(double price) {
  if (price <= 0) return '';
  final String converted = PriceConverterHelper.convertPrice(price);
  final Match? leading = RegExp(r'^([^\d\s]+)\s*(.*)').firstMatch(converted);
  if (leading != null) {
    final String symbol = leading.group(1)!.trim();
    final String amount = leading.group(2)!.trim();
    if (symbol.isNotEmpty && amount.isNotEmpty) {
      return '$symbol +$amount';
    }
  }
  return '+ $converted';
}

/// The three logical groups a product's variations fall into.
///
/// Version A stacks all three; Version B steps them; POS landscape stacks them
/// beside the receipt — the split must stay identical across all three.
class KioskCustomizeSections {
  final List<MapEntry<int, Variation>> size;
  final List<MapEntry<int, Variation>> dietary;
  final List<MapEntry<int, Variation>> cupCan;

  const KioskCustomizeSections({
    required this.size,
    required this.dietary,
    required this.cupCan,
  });

  factory KioskCustomizeSections.of(Product product) {
    final variations = ProductHelper.effectiveVariations(product) ?? [];
    final indexed =
        List.generate(variations.length, (i) => MapEntry(i, variations[i]));
    bool isCupCan(MapEntry<int, Variation> e) =>
        kioskCupCanPattern.hasMatch(e.value.name ?? '');

    return KioskCustomizeSections(
      cupCan: indexed.where(isCupCan).toList(),
      size: indexed
          .where((e) => !isCupCan(e) && kioskIsSizeVariation(e.value))
          .toList(),
      dietary: indexed
          .where((e) => !isCupCan(e) && !kioskIsSizeVariation(e.value))
          .toList(),
    );
  }

  bool get hasMilkStep => size.isNotEmpty || dietary.isNotEmpty;
}
