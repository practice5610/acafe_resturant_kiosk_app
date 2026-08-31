import 'package:acafe_customer/common/models/cart_model.dart';

/// Line total for a cart item = (discounted unit price + per-unit add-ons) × qty.
///
/// Add-ons are configured per unit on the customize screen, so they must scale
/// with [CartModel.quantity]. Otherwise bumping qty dilutes the per-unit price
/// shown on the menu cart bar and undercharges extras on multi-qty lines.
double kioskLineTotal(CartModel cart) {
  final int qty = cart.quantity ?? 1;
  final double addons = _kioskLineAddOnsTotal(cart);
  return (_kioskUnitPayable(cart) + addons) * qty;
}

/// Payable price of a single unit of this line (discounted price + add-ons).
///
/// Stable as quantity changes — use this for the menu "latest item" card so
/// the price under the name does not shrink when the customer taps "+".
double kioskLineUnitPrice(CartModel cart) {
  return _kioskUnitPayable(cart) + _kioskLineAddOnsTotal(cart);
}

/// What one unit of this line costs after its own discount, excluding add-ons.
///
/// [CartModel.discountedPrice] is the single source of truth for what a unit
/// costs; every screen that quotes a price goes through here, and the order
/// summary's discount is measured back to it (see [kioskDiscountTotal]) so the
/// two can never name different numbers for the same line.
double _kioskUnitPayable(CartModel cart) =>
    cart.discountedPrice ?? ((cart.price ?? 0) - (cart.discountAmount ?? 0));

/// Line total BEFORE the product's own discount = (list unit price + add-ons)
/// × qty.
///
/// The order summary (Figma POS node 1385:15938) prints this struck through
/// beside [kioskLineTotal], so the customer can see what the discount took off
/// this line. Equal to [kioskLineTotal] when the product is not discounted —
/// callers compare the two rather than asking whether a discount exists.
double kioskLineOriginalTotal(CartModel cart) {
  final int qty = cart.quantity ?? 1;
  final double addons = _kioskLineAddOnsTotal(cart);
  return ((cart.price ?? 0) + addons) * qty;
}

/// Sum of every line's own total, before tax and before any cart-level coupon.
///
/// Screens that quote the customer a total want [kioskPayableTotal] instead;
/// this is the lines on their own.
double kioskCartTotal(List<CartModel?> cartList) {
  double total = 0;
  for (final cart in cartList) {
    if (cart != null) total += kioskLineTotal(cart);
  }
  return total;
}

/// Total number of items (sum of quantities) in the cart.
int kioskCartItemCount(List<CartModel?> cartList) {
  int count = 0;
  for (final cart in cartList) {
    if (cart != null) count += cart.quantity ?? 1;
  }
  return count;
}

/// Sum of all add-ons on a line (qty-aware), used by the order summary.
double _kioskLineAddOnsTotal(CartModel cart) {
  double total = _kioskAddOnsOn(cart);
  for (final CartModel component in cart.components ?? const []) {
    total += _kioskAddOnsOn(component);
  }
  return total;
}

double _kioskAddOnsOn(CartModel cart) {
  double total = 0;
  for (final addOn in cart.addOnIds ?? []) {
    final qty = addOn.quantity ?? 1;
    final match = (cart.product?.addOns ?? []).where((a) => a.id == addOn.id);
    if (match.isNotEmpty) total += (match.first.price ?? 0) * qty;
  }
  return total;
}

/// Pre-discount items subtotal (product price incl. variations + add-ons) × qty.
double kioskItemsTotal(List<CartModel?> cartList) {
  double total = 0;
  for (final cart in cartList) {
    if (cart != null) total += kioskLineOriginalTotal(cart);
  }
  return total;
}

/// Total discount across all lines: what [kioskItemsTotal] has to come down by
/// to reach what the lines are actually worth.
///
/// Measured as list price minus payable price rather than read from
/// [CartModel.discountAmount], so `items - discount` is the sum of the line
/// totals by construction. Reading the stored field instead let the cart
/// screen's YOUR PAY drift away from the menu cart bar whenever the two
/// disagreed — which they did for every line carrying a paid variation.
double kioskDiscountTotal(List<CartModel?> cartList) {
  double total = 0;
  for (final cart in cartList) {
    if (cart == null) continue;
    final double payable = _kioskUnitPayable(cart);
    total += ((cart.price ?? payable) - payable) * (cart.quantity ?? 1);
  }
  return total;
}

/// Total tax across all lines.
double kioskTaxTotal(List<CartModel?> cartList) {
  double total = 0;
  for (final cart in cartList) {
    if (cart == null) continue;
    total += (cart.taxAmount ?? 0) * (cart.quantity ?? 1);
  }
  return total;
}

/// Grand total shown on the order summary = items − discount + tax.
double kioskGrandTotal(List<CartModel?> cartList) =>
    kioskItemsTotal(cartList) -
    kioskDiscountTotal(cartList) +
    kioskTaxTotal(cartList);

/// Subtotal used for coupon min-purchase checks (before tax and coupon).
double kioskOrderAmountBeforeCoupon(List<CartModel?> cartList) =>
    kioskItemsTotal(cartList) - kioskDiscountTotal(cartList);

/// Payable total after a coupon discount is applied.
double kioskPayableTotal(List<CartModel?> cartList, double couponDiscount) =>
    kioskGrandTotal(cartList) - couponDiscount;
