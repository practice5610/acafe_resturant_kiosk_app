import 'package:flutter/material.dart';
import 'package:acafe_customer/features/auth/providers/auth_provider.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/coupon/providers/coupon_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_session.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:provider/provider.dart';

/// Ensures a guest account exists so coupon API calls can attach guest_id.
Future<void> ensureKioskGuestForCoupon(BuildContext context) async {
  final auth = Provider.of<AuthProvider>(context, listen: false);
  if (auth.getGuestId() == null) {
    await auth.addGuest();
  }
}

T? _readProvider<T>(BuildContext? context) {
  if (context == null) return null;
  try {
    return Provider.of<T>(context, listen: false);
  } catch (_) {
    return null;
  }
}

/// Code currently taking money off this basket. A leftover code with a zero
/// discount (previous order, failed apply) must not be prefilled or sent with
/// the next order — that is how the last customer's coupon was riding through.
String kioskActiveCouponCode(CouponProvider coupon) {
  if ((coupon.discount ?? 0) <= 0) return '';
  return coupon.coupon?.code ?? coupon.code ?? '';
}

/// Coupon code attached to a place-order request. `null` when nothing is
/// actually discounting this basket, so a stale code cannot be re-applied
/// by the backend.
String? kioskOrderCouponCode(CouponProvider coupon) {
  final String code = kioskActiveCouponCode(coupon);
  return code.isEmpty ? null : code;
}

/// Drops any coupon attached to this kiosk so it cannot ride into the next
/// customer's order. Safe when no coupon is on, and when [CouponProvider] is
/// not in the tree (widget tests).
void clearKioskCoupon(
  BuildContext? context, {
  CouponProvider? coupon,
  bool notify = true,
}) {
  (coupon ?? _readProvider<CouponProvider>(context))?.removeCouponData(notify);
}

/// Ends the current kiosk customer's checkout: empty cart, drop coupon, reset
/// the in-memory session. Call after an order is placed — even if the confirm
/// widget has already unmounted. Pass [cart] / [coupon] when [context] may
/// already be unmounted; the providers themselves are app-scoped.
void endKioskCustomerSession(
  BuildContext? context, {
  CartProvider? cart,
  CouponProvider? coupon,
}) {
  final CartProvider? cartProvider =
      cart ?? _readProvider<CartProvider>(context);
  cartProvider?.clearCartList();
  clearKioskCoupon(context, coupon: coupon);
  KioskSession.instance.reset();
}

/// Opens the kiosk coupon entry screen (Figma POS node 1385:15500).
///
/// This used to raise a bottom sheet over the cart; the redesign is a full
/// screen with its own on-screen keyboard, so it is pushed as a route and the
/// cart is restored when the customer taps BACK or CONTINUE.
Future<void> openKioskCouponScreen(
  BuildContext context, {
  required double orderAmount,
}) async {
  await ensureKioskGuestForCoupon(context);
  if (!context.mounted) return;

  RouterHelper.getKioskCouponRoute(orderAmount: orderAmount);
}
