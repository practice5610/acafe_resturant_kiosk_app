import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/models/place_order_body.dart';
import 'package:acafe_customer/features/auth/providers/auth_provider.dart';
import 'package:acafe_customer/features/branch/providers/branch_provider.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/coupon/providers/coupon_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_coupon_helper.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_session.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_tip.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/order/providers/order_provider.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:provider/provider.dart';

/// Result of submitting a kiosk order to the backend.
class KioskPlaceResult {
  final bool success;
  final String? orderId;
  final String? message;
  const KioskPlaceResult({required this.success, this.orderId, this.message});
}

/// `order_note` sent with a kiosk order: the existing "Kiosk order — <name>"
/// identifier, plus the customer's own note from the cart screen when they
/// wrote one. Kept in one place so both checkout paths format it identically.
String kioskOrderNote({
  required String name,
  required String note,
  int tipPercent = 0,
  double tipAmount = 0,
}) {
  final String base = name.isNotEmpty ? 'Kiosk order — $name' : 'Kiosk order';
  final buffer = StringBuffer(base);
  if (tipPercent > 0 && tipAmount > 0) {
    buffer.write('\nTip: $tipPercent% (${tipAmount.toStringAsFixed(2)})');
  }
  final String trimmed = note.trim();
  if (trimmed.isNotEmpty) buffer.write('\n$trimmed');
  return buffer.toString();
}

/// The `order_type` an order placed from this app carries.
///
/// The app is the same binary on both a self-service kiosk and a staffed
/// counter terminal, so the only thing that distinguishes the two is the
/// device row's `category`. Tagging the order here is what lets the backend
/// report it in the right channel; previously every order was hardcoded to
/// `take_away`, which made a POS terminal indistinguishable from a kiosk.
///
/// Fulfilment is unaffected: everything this app sells is collected at the
/// counter, and ZReportService::classifyFulfillment() maps `pos` to take-away
/// for exactly that reason.
String kioskOrderType(KioskAuthProvider kioskAuthProvider) =>
    kioskAuthProvider.isPosDevice ? 'pos' : 'take_away';

/// Places the current cart as a guest kiosk order via the SAME path as the user
/// web app (OrderProvider.placeOrder → /api/v1/customer/order/place), so it
/// lands in the orders table and kitchen app identically.
///
/// The caller is responsible for what happens on success (store the order
/// number, clear the cart, navigate). [amount] is the order total to charge.
Future<KioskPlaceResult> placeKioskOrder(
  BuildContext context, {
  required double amount,
  String? paymentRef,
}) async {
  final cartProvider = Provider.of<CartProvider>(context, listen: false);
  final orderProvider = Provider.of<OrderProvider>(context, listen: false);
  final branchProvider = Provider.of<BranchProvider>(context, listen: false);
  final splashProvider = Provider.of<SplashProvider>(context, listen: false);
  final authProvider = Provider.of<AuthProvider>(context, listen: false);
  final couponProvider = Provider.of<CouponProvider>(context, listen: false);
  final kioskAuthProvider =
      Provider.of<KioskAuthProvider>(context, listen: false);

  // Kiosk orders are placed as a guest — make sure a guest account exists so the
  // backend's required guest_id is attached by the order repository.
  if (authProvider.getGuestId() == null) {
    await authProvider.addGuest();
  }

  // Build the order cart items — mirrors the web app's confirm_button_widget.
  // A deal line is expanded into one entry per included product so kitchen
  // tickets stay one row per drink/food, tagged with deal_id.
  final List<Cart> carts = [];
  for (final cart in cartProvider.cartList) {
    if (cart == null) continue;
    if (cart.isDeal) {
      final int copies = cart.quantity ?? 1;
      for (int i = 0; i < copies; i++) {
        for (final component in cart.components ?? const []) {
          carts.add(_kioskOrderCartFromLine(component, dealId: cart.dealId));
        }
      }
    } else {
      carts.add(_kioskOrderCartFromLine(cart));
    }
  }

  final branches = splashProvider.configModel?.branches;
  final int? branchId = branchProvider.getBranch()?.id ??
      ((branches != null && branches.isNotEmpty) ? branches.first?.id : null);

  final name = KioskSession.instance.customerName;
  final String? couponCode = kioskOrderCouponCode(couponProvider);
  final int tipPercent = KioskSession.instance.tipPercentOrZero;
  final double payable =
      kioskPayableTotal(cartProvider.cartList, couponProvider.discount ?? 0);
  final double tipAmount = kioskTipAmount(payable, tipPercent);
  final placeOrderBody = PlaceOrderBody(
    cart: carts,
    couponDiscountAmount: couponProvider.discount ?? 0,
    couponDiscountTitle: couponCode,
    couponCode: couponCode,
    orderAmount: double.parse(amount.toStringAsFixed(2)),
    tipAmount: tipAmount > 0 ? tipAmount : null,
    deliveryAddressId: 0,
    deliveryAddress: null,
    orderType: kioskOrderType(kioskAuthProvider),
    paymentMethod: 'cash_on_delivery',
    branchId: branchId,
    deviceId: kioskAuthProvider.deviceId,
    customerEmail: KioskSession.instance.customerEmail,
    customerName: KioskSession.instance.customerName,
    deliveryTime: 'now',
    deliveryDate: DateFormat('yyyy-MM-dd').format(DateTime.now()),
    orderNote: kioskOrderNote(
      name: name,
      note: cartProvider.orderNote,
      tipPercent: tipPercent,
      tipAmount: tipAmount,
    ),
    distance: 0,
    isPartial: '0',
    isCutleryRequired: '0',
    transactionReference: paymentRef,
    bringChangeAmount: 0,
  );

  final completer = Completer<KioskPlaceResult>();
  orderProvider.placeOrder(placeOrderBody,
      (bool success, String? message, String orderId) {
    if (!completer.isCompleted) {
      completer.complete(KioskPlaceResult(
          success: success, orderId: orderId, message: message));
    }
  }, asGuest: true);
  return completer.future;
}

Cart _kioskOrderCartFromLine(CartModel cart, {int? dealId}) {
  final List<int?> addOnIdList = [];
  final List<int?> addOnQtyList = [];
  for (final addOn in cart.addOnIds ?? []) {
    addOnIdList.add(addOn.id);
    addOnQtyList.add(addOn.quantity);
  }

  final List<OrderVariation> variations = [];
  final productVariations = cart.product?.variations;
  final selected = cart.variations;
  if (productVariations != null && selected != null && selected.isNotEmpty) {
    for (int i = 0; i < productVariations.length; i++) {
      if (i < selected.length && selected[i].contains(true)) {
        variations.add(OrderVariation(
            name: productVariations[i].name,
            values: OrderVariationValue(label: [])));
        final values = productVariations[i].variationValues ?? [];
        for (int j = 0; j < values.length; j++) {
          if (j < selected[i].length && (selected[i][j] ?? false)) {
            variations.last.values!.label!.add(values[j].level);
          }
        }
      }
    }
  }

  return Cart(
    cart.product!.id.toString(),
    cart.discountedPrice.toString(),
    [],
    variations,
    cart.discountAmount,
    cart.quantity,
    cart.taxAmount,
    addOnIdList,
    addOnQtyList,
    instruction: cart.instruction,
    dealId: dealId,
  );
}
