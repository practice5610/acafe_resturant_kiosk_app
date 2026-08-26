import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_upsell_sheet.dart';

/// Lightweight in-memory holder for the current kiosk checkout session.
///
/// Keeps the customer name and the last placed order number across the
/// checkout → payment → success screens without needing a global provider.
/// Reset on a fresh order / idle timeout.
class KioskSession {
  KioskSession._();
  static final KioskSession instance = KioskSession._();

  String customerName = '';
  String customerEmail = '';
  String? lastOrderNumber;
  String? lastOrderId;

  void reset() {
    customerName = '';
    customerEmail = '';
    lastOrderNumber = null;
    lastOrderId = null;
    // "We already asked this customer about a drink" must not carry over to
    // the next person to walk up to the kiosk.
    resetKioskUpsellMemory();
  }
}

/// Line total for a cart item = discounted unit price × qty + active add-ons.
double kioskLineTotal(CartModel cart) =>
    (cart.discountedPrice ?? 0) * (cart.quantity ?? 1) +
    _kioskLineAddOnsTotal(cart);

/// Line total BEFORE the product's own discount = list unit price x qty +
/// add-ons.
///
/// The order summary (Figma POS node 1385:15938) prints this struck through
/// beside [kioskLineTotal], so the customer can see what the discount took off
/// this line. Equal to [kioskLineTotal] when the product is not discounted —
/// callers compare the two rather than asking whether a discount exists.
double kioskLineOriginalTotal(CartModel cart) =>
    (cart.price ?? 0) * (cart.quantity ?? 1) + _kioskLineAddOnsTotal(cart);

/// Grand total across all cart lines.
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
    if (cart == null) continue;
    total +=
        (cart.price ?? 0) * (cart.quantity ?? 1) + _kioskLineAddOnsTotal(cart);
  }
  return total;
}

/// Total discount across all lines.
double kioskDiscountTotal(List<CartModel?> cartList) {
  double total = 0;
  for (final cart in cartList) {
    if (cart == null) continue;
    total += (cart.discountAmount ?? 0) * (cart.quantity ?? 1);
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
