import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_order_composition.dart';

/// One add-on / variation line under a receipt item (`+ Oat milk`, `- Whipped cream`).
class PosReceiptNote {
  final bool included;
  final String label;

  const PosReceiptNote({required this.included, required this.label});
}

String posReceiptLineName(CartModel line) {
  if (line.isDeal) return line.dealTitle ?? '';
  return line.product?.name ?? '';
}

/// Cup/Can selection for the `€ 5.50 · Cup` price line. Null when the product
/// has no vessel variation.
String? posReceiptUnit(CartModel line) {
  final List<Variation> variations = line.product?.variations ?? const [];
  final List<List<bool?>>? selected = line.variations;
  for (int i = 0; i < variations.length; i++) {
    if (!kioskCupCanPattern.hasMatch(variations[i].name ?? '')) continue;
    final List<VariationValue> values =
        variations[i].variationValues ?? const [];
    final List<bool?> flags =
        (selected != null && i < selected.length) ? selected[i] : const [];
    for (int j = 0; j < values.length && j < flags.length; j++) {
      if (flags[j] == true) {
        final String label = values[j].level ?? '';
        if (label.isNotEmpty) return label;
      }
    }
  }
  return null;
}

List<PosReceiptNote> posReceiptNotes(CartModel line) {
  final List<PosReceiptNote> notes = [];

  if (line.isDeal) {
    for (final CartModel component in line.components ?? const []) {
      final String name = component.product?.name ?? '';
      if (name.isNotEmpty) {
        notes.add(PosReceiptNote(included: true, label: name));
      }
      notes.addAll(posReceiptNotes(component));
    }
    return notes;
  }

  final Product? product = line.product;
  final List<Variation> variations = product?.variations ?? const [];
  final List<List<bool?>>? selected = line.variations;
  for (int i = 0; i < variations.length; i++) {
    if (kioskCupCanPattern.hasMatch(variations[i].name ?? '')) continue;
    final List<VariationValue> values =
        variations[i].variationValues ?? const [];
    final List<bool?> flags =
        (selected != null && i < selected.length) ? selected[i] : const [];
    for (int j = 0; j < values.length && j < flags.length; j++) {
      if (flags[j] != true) continue;
      final String label = values[j].level ?? '';
      if (label.isEmpty) continue;
      notes.add(PosReceiptNote(included: true, label: label));
    }
  }

  final Set<int> selectedAddOnIds = {
    for (final AddOn addOn in line.addOnIds ?? const [])
      if (addOn.id != null) addOn.id!,
  };

  for (final AddOns addOn in product?.addOns ?? const []) {
    final int? id = addOn.id;
    final String name = addOn.name ?? '';
    if (id == null || name.isEmpty) continue;
    if (selectedAddOnIds.contains(id)) {
      if (!addOn.isDefault) {
        notes.add(PosReceiptNote(included: true, label: name));
      }
    } else if (addOn.isDefault) {
      notes.add(PosReceiptNote(included: false, label: name));
    }
  }

  return notes;
}
