import 'package:acafe_customer/common/models/cart_model.dart';

/// Returns the index of a cart line that matches [candidate], or -1.
int findMatchingCartLineIndex(List<CartModel?> cartList, CartModel candidate) {
  for (int i = 0; i < cartList.length; i++) {
    final line = cartList[i];
    if (line != null && cartLinesMatch(line, candidate)) return i;
  }
  return -1;
}

/// Same product + same variation picks + same add-ons + same instruction
/// => one cart line.
bool cartLinesMatch(CartModel a, CartModel b) {
  if (a.product?.id != b.product?.id) return false;
  if (!_variationSelectionsMatch(a.variations, b.variations)) return false;
  if (!_addOnsMatch(a.addOnIds, b.addOnIds)) return false;
  if ((a.instruction ?? '').trim() != (b.instruction ?? '').trim()) return false;
  return true;
}

bool _variationSelectionsMatch(List<List<bool?>>? a, List<List<bool?>>? b) {
  final listA = a ?? const [];
  final listB = b ?? const [];
  if (listA.isEmpty && listB.isEmpty) return true;
  if (listA.length != listB.length) return false;
  for (int i = 0; i < listA.length; i++) {
    if (listA[i].length != listB[i].length) return false;
    for (int j = 0; j < listA[i].length; j++) {
      if ((listA[i][j] ?? false) != (listB[i][j] ?? false)) return false;
    }
  }
  return true;
}

bool _addOnsMatch(List<AddOn>? a, List<AddOn>? b) {
  final listA = a ?? const [];
  final listB = b ?? const [];
  if (listA.isEmpty && listB.isEmpty) return true;
  if (listA.length != listB.length) return false;

  final sortedA = List<AddOn>.from(listA)
    ..sort((x, y) => (x.id ?? 0).compareTo(y.id ?? 0));
  final sortedB = List<AddOn>.from(listB)
    ..sort((x, y) => (x.id ?? 0).compareTo(y.id ?? 0));

  for (int i = 0; i < sortedA.length; i++) {
    if (sortedA[i].id != sortedB[i].id) return false;
    if ((sortedA[i].quantity ?? 1) != (sortedB[i].quantity ?? 1)) return false;
  }
  return true;
}
