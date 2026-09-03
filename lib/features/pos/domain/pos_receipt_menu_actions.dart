import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/coupon/providers/coupon_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_cart_totals.dart';
import 'package:acafe_customer/features/pos/widgets/pos_coupon_apply_dialog.dart';
import 'package:acafe_customer/features/pos/widgets/pos_receipt_context_menu.dart';
import 'package:acafe_customer/helper/custom_snackbar_helper.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

/// Runs one [PosReceiptMenuAction] against the live cart and coupon state.
///
/// Lives here rather than on the counter screen because the payment screen
/// carries the same ⋯ button over the same receipt: a discount applied from
/// either place has to land in [CouponProvider] identically, or the two screens
/// would quote different totals for one sale.
///
/// Actions with no POS backend fall through silently — the menu matches Figma
/// 1641:3570 in full, and the unimplemented entries are chrome, not stubs
/// pretending to work.
Future<void> handlePosReceiptMenuAction(
  BuildContext context,
  PosReceiptMenuAction action,
) async {
  final CouponProvider coupon = context.read<CouponProvider>();
  final CartProvider cart = context.read<CartProvider>();
  final double orderAmount = kioskOrderAmountBeforeCoupon(cart.cartList);

  switch (action) {
    case PosReceiptMenuAction.applyDiscount:
      await showPosCouponApplyDialog(
        context: context,
        orderAmount: orderAmount,
        title: 'Apply discount',
      );
    case PosReceiptMenuAction.applyCustomDiscount:
      await showPosCouponApplyDialog(
        context: context,
        orderAmount: orderAmount,
        title: 'Apply custom discount',
      );
    case PosReceiptMenuAction.removeDiscount:
      if ((coupon.discount ?? 0) <= 0 && coupon.coupon == null) {
        showCustomSnackBarHelper('No discount to remove', isError: false);
        return;
      }
      coupon.removeCouponData(true);
      showCustomSnackBarHelper('Discount removed', isError: false);
    case PosReceiptMenuAction.priceOverride:
    case PosReceiptMenuAction.taxExempt:
    case PosReceiptMenuAction.compItem:
    case PosReceiptMenuAction.moveTable:
    case PosReceiptMenuAction.holdFire:
    case PosReceiptMenuAction.sendKitchen:
    case PosReceiptMenuAction.repeatItem:
    case PosReceiptMenuAction.partialPayment:
    case PosReceiptMenuAction.giftCard:
    case PosReceiptMenuAction.loyaltyPoints:
      break;
  }
}
