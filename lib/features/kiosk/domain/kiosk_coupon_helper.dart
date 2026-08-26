import 'package:flutter/material.dart';
import 'package:acafe_customer/features/auth/providers/auth_provider.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:provider/provider.dart';

/// Ensures a guest account exists so coupon API calls can attach guest_id.
Future<void> ensureKioskGuestForCoupon(BuildContext context) async {
  final auth = Provider.of<AuthProvider>(context, listen: false);
  if (auth.getGuestId() == null) {
    await auth.addGuest();
  }
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
