import 'package:acafe_customer/common/models/cart_model.dart';

/// Returns the index of a cart line that matches [candidate], or -1.
int findMatchingCartLineIndex(List<CartModel?> cartList, CartModel candidate) {
  for (int i = 0; i < cartList.length; i++) {
    final line = cartList[i];
    if (line != null && cartLinesMatch(line, candidate)) return i;
  }
  return -1;
}

/// Human-readable configuration signature of a cart line.
///
/// DIAGNOSTIC ONLY. [cartLinesMatch] stays the single authority on whether two
/// lines are the same configuration — comparing signature strings instead would
/// silently change the rules (null vs false in a variation grid, add-on order,
/// whitespace in an instruction). This exists so a test failure names the two
/// configurations it was comparing, and so a log line can say which line the
/// customer is looking at.
///
/// Two lines match under [cartLinesMatch] if and only if their signatures are
/// equal; `cart_line_matcher_test.dart` holds that invariant.
String cartLineSignature(CartModel cart) {
  if (cart.isDeal) {
    final List<String> parts = (cart.components ?? const [])
        .map(cartLineSignature)
        .toList();
    return 'deal:${cart.dealId}[${parts.join('|')}]';
  }

  // The grid's SHAPE is part of the signature, not just the ticked boxes.
  // [cartLinesMatch] rejects two lines whose grids differ in length, which is
  // what happens when the product's variation groups changed between the two
  // adds (a live catalog update). Recording only the ticks would make the
  // signature say "same" where the matcher says "different".
  final List<String> picks = [];
  final List<String> shape = [];
  final List<List<bool?>> grid = cart.variations ?? const [];
  for (int i = 0; i < grid.length; i++) {
    shape.add('${grid[i].length}');
    for (int j = 0; j < grid[i].length; j++) {
      if (grid[i][j] ?? false) picks.add('$i.$j');
    }
  }

  final List<AddOn> addOns = List<AddOn>.from(cart.addOnIds ?? const <AddOn>[])
    ..sort((x, y) => (x.id ?? 0).compareTo(y.id ?? 0));
  final List<String> extras =
      addOns.map((a) => '${a.id}x${a.quantity ?? 1}').toList();

  return 'p:${cart.product?.id}'
      '|v:${shape.join('x')}/${picks.join(',')}'
      '|a:${extras.join(',')}'
      '|n:${(cart.instruction ?? '').trim()}';
}

/// Same product + same variation picks + same add-ons + same instruction
/// => one cart line. Deal lines match on deal id + every component instead.
bool cartLinesMatch(CartModel a, CartModel b) {
  if (a.isDeal || b.isDeal) {
    if (a.dealId != b.dealId) return false;
    final List<CartModel> aParts = a.components ?? const [];
    final List<CartModel> bParts = b.components ?? const [];
    if (aParts.length != bParts.length) return false;
    for (int i = 0; i < aParts.length; i++) {
      if (!cartLinesMatch(aParts[i], bParts[i])) return false;
    }
    return true;
  }
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
