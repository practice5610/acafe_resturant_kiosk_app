import 'package:flutter/material.dart';
import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/responsive/kiosk_responsive.dart';
import 'package:acafe_customer/common/responsive/responsive.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/coupon/domain/models/coupon_model.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_coupon_reward.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_place_order.dart';
import 'package:acafe_customer/features/coupon/providers/coupon_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_session.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_translate.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_checkout_widgets.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_order_line_card.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_ui.dart';
import 'package:acafe_customer/helper/custom_snackbar_helper.dart';
import 'package:acafe_customer/helper/price_converter_helper.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:provider/provider.dart';

/// How long the "ORDER CONFIRMED!" tick stays up before returning to the menu.
const Duration _kConfirmedDisplay = Duration(seconds: 3);

/// Checkout step 3 — PAYMENT: order summary with the live totals breakdown.
/// "COMPLETE ORDER & PAY" places the order, shows a confirmation tick for 3s,
/// then returns to the menu for the next customer.
class KioskConfirmScreen extends StatefulWidget {
  const KioskConfirmScreen({super.key});

  @override
  State<KioskConfirmScreen> createState() => _KioskConfirmScreenState();
}

class _KioskConfirmScreenState extends State<KioskConfirmScreen> {
  bool _placing = false;

  Future<void> _complete(double amount) async {
    if (_placing) return;
    setState(() => _placing = true);

    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final shownAt = DateTime.now();
    final result = await placeKioskOrder(context, amount: amount);
    if (!mounted) return;

    if (!result.success) {
      setState(() => _placing = false);
      showCustomSnackBarHelper(
        result.message ??
            kioskTranslate(
                context, 'order_failed', 'Order could not be placed'),
        isError: true,
      );
      return;
    }

    // Keep the tick visible for the full display duration before returning to menu.
    final remaining = _kConfirmedDisplay - DateTime.now().difference(shownAt);
    if (remaining > Duration.zero) await Future.delayed(remaining);
    if (!mounted) return;

    cartProvider.clearCartList();
    Provider.of<CouponProvider>(context, listen: false).removeCouponData(false);
    KioskSession.instance.reset();
    RouterHelper.getKioskMenuRoute(action: RouteAction.pushReplacement);
  }

  @override
  Widget build(BuildContext context) {
    if (Responsive.isWide(context)) {
      return _WideConfirmScreen(placing: _placing, onComplete: _complete);
    }
    return Scaffold(
      backgroundColor: KioskUI.pageBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double s = checkoutScale(constraints.maxWidth);
            return Consumer2<CartProvider, CouponProvider>(
              builder: (context, cartProvider, couponProvider, _) {
                final cartList = cartProvider.cartList;
                final double couponDiscount = couponProvider.discount ?? 0;
                final double total =
                    kioskPayableTotal(cartList, couponDiscount);
                return Stack(
                  children: [
                    KioskCenteredContent(
                      child: Column(
                        children: [
                          KioskCheckoutHeader(s: s, activeStep: 2),
                          Expanded(
                            child: ListView(
                              padding: EdgeInsets.fromLTRB(
                                  77 * s, 40 * s, 115 * s, 40 * s),
                              children: [
                                Text(
                                  kioskTranslate(context, 'order_summary',
                                      'Order summary'),
                                  textAlign: TextAlign.center,
                                  style: loewExtraBold.copyWith(
                                      fontSize: 128 * s,
                                      height: 1,
                                      color: Colors.black),
                                ),
                                SizedBox(height: 50 * s),
                                for (int i = 0; i < cartList.length; i++)
                                  if (cartList[i] != null)
                                    Padding(
                                      padding: EdgeInsets.only(bottom: 50 * s),
                                      child: KioskOrderLineCard(
                                          s: s, cart: cartList[i]!, index: i),
                                    ),
                              ],
                            ),
                          ),
                          _SummaryFooter(
                              s: s,
                              cartList: cartList,
                              couponDiscount: couponDiscount,
                              coupon: couponProvider.coupon,
                              onComplete: () => _complete(total)),
                        ],
                      ),
                    ),
                    if (_placing)
                      Positioned.fill(child: _ConfirmedOverlay(s: s)),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _WideConfirmScreen extends StatelessWidget {
  final bool placing;
  final Future<void> Function(double amount) onComplete;

  const _WideConfirmScreen({required this.placing, required this.onComplete});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KioskUI.pageBg,
      body: SafeArea(
        child: Consumer2<CartProvider, CouponProvider>(
          builder: (context, cartProvider, couponProvider, _) {
            final cartList = cartProvider.cartList;
            final double couponDiscount = couponProvider.discount ?? 0;
            final double total = kioskPayableTotal(cartList, couponDiscount);
            return Stack(
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                        maxWidth: KioskUI.checkoutColumnMaxWidth),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(0, 24, 0, 0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const KioskBackButton(
                                fallback: RouterHelper.getKioskCartRoute,
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: KioskCheckoutStepper(activeStep: 2),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            children: [
                              Text(
                                kioskTranslate(context, 'order_summary',
                                    'Order summary'),
                                textAlign: TextAlign.center,
                                style: loewExtraBold.copyWith(
                                  fontSize: KioskUI.heading,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 24),
                              for (int i = 0; i < cartList.length; i++)
                                if (cartList[i] != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: KioskOrderLineCard(
                                      cart: cartList[i]!,
                                      index: i,
                                      compact: true,
                                    ),
                                  ),
                            ],
                          ),
                        ),
                        _WideSummaryFooter(
                          cartList: cartList,
                          couponDiscount: couponDiscount,
                          coupon: couponProvider.coupon,
                          onComplete: () => onComplete(total),
                        ),
                      ],
                    ),
                  ),
                ),
                if (placing)
                  const Positioned.fill(child: _WideConfirmedOverlay()),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _WideSummaryFooter extends StatelessWidget {
  final List<CartModel?> cartList;
  final double couponDiscount;

  /// The applied coupon, so its row can name the offer. Null when none is on.
  final CouponModel? coupon;
  final VoidCallback onComplete;

  const _WideSummaryFooter({
    required this.cartList,
    required this.couponDiscount,
    required this.coupon,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final double items = kioskItemsTotal(cartList);
    final double discount = kioskDiscountTotal(cartList);
    final double tax = kioskTaxTotal(cartList);
    final double total = kioskPayableTotal(cartList, couponDiscount);
    final bool enabled = cartList.any((c) => c != null);

    return Container(
      padding: const EdgeInsets.only(top: 16, bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _WideBreakdownRow(
            label: kioskTranslate(context, 'items_total', 'Items total')
                .toUpperCase(),
            value: PriceConverterHelper.convertPrice(items),
          ),
          if (discount > 0) ...[
            const SizedBox(height: 8),
            _WideBreakdownRow(
              label: kioskTranslate(context, 'discount', 'Discount')
                  .toUpperCase(),
              value: '- ${PriceConverterHelper.convertPrice(discount)}',
            ),
          ],
          // The artboard puts the discount between ITEMS TOTAL and TAX, so the
          // coupon's own row sits with the other money coming off.
          if (couponDiscount > 0) ...[
            const SizedBox(height: 8),
            _WideBreakdownRow(
              label: kioskCouponRowLabel(
                discountLabel:
                    kioskTranslate(context, 'discount', 'Discount'),
                title: coupon?.title,
                code: coupon?.code,
              ),
              value: '- ${PriceConverterHelper.convertPrice(couponDiscount)}',
            ),
          ],
          const SizedBox(height: 8),
          _WideBreakdownRow(
            label: kioskTranslate(context, 'tax', 'Tax').toUpperCase(),
            value: PriceConverterHelper.convertPrice(tax),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'TOTAL',
                  style: loewExtraBold.copyWith(
                    fontSize: KioskUI.heading,
                    color: Colors.black,
                  ),
                ),
              ),
              Text(
                PriceConverterHelper.convertPrice(total),
                style: loewRegular.copyWith(
                  fontSize: KioskUI.heading,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          KioskButton(
            label: kioskTranslate(context, 'complete_order_and_pay',
                    'Complete order & pay')
                .toUpperCase(),
            height: KioskUI.primaryButtonHeight,
            maxWidth: KioskUI.checkoutColumnMaxWidth,
            onTap: enabled ? onComplete : null,
          ),
        ],
      ),
    );
  }
}

class _WideBreakdownRow extends StatelessWidget {
  final String label;
  final String value;
  const _WideBreakdownRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: loewExtraBold.copyWith(
                  fontSize: KioskUI.body, color: Colors.black)),
        ),
        const SizedBox(width: 12),
        Text(value,
            style: loewRegular.copyWith(
                fontSize: KioskUI.body, color: Colors.black)),
      ],
    );
  }
}

class _WideConfirmedOverlay extends StatelessWidget {
  const _WideConfirmedOverlay();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Container(
        color: Colors.black.withValues(alpha: 0.5),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 160,
              height: 160,
              decoration: const BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.check_rounded,
                  size: 80, color: Colors.white),
            ),
            const SizedBox(height: 24),
            Text(
              kioskTranslate(context, 'order_confirmed', 'Order confirmed!')
                  .toUpperCase(),
              textAlign: TextAlign.center,
              style: loewExtraBold.copyWith(
                fontSize: KioskUI.pageTitle,
                height: 1,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dimmed "ORDER CONFIRMED!" tick shown over the summary after placing the order.
class _ConfirmedOverlay extends StatelessWidget {
  final double s;
  const _ConfirmedOverlay({required this.s});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque, // absorb taps while confirming.
      onTap: () {},
      child: Container(
        color: Colors.black.withValues(alpha: 0.5),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 1487 * s,
              height: 1487 * s,
              decoration: const BoxDecoration(
                  color: Colors.black, shape: BoxShape.circle),
              alignment: Alignment.center,
              child:
                  Icon(Icons.check_rounded, size: 820 * s, color: Colors.white),
            ),
            SizedBox(height: 120 * s),
            Text(
              kioskTranslate(context, 'order_confirmed', 'Order confirmed!')
                  .toUpperCase(),
              textAlign: TextAlign.center,
              style: loewExtraBold.copyWith(
                  fontSize: 182 * s, height: 1, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

/// Totals breakdown (ITEMS TOTAL / DISCOUNT / TAX / TOTAL) + complete button.
class _SummaryFooter extends StatelessWidget {
  final double s;
  final List<CartModel?> cartList;
  final double couponDiscount;

  /// The applied coupon, so its row can name the offer. Null when none is on.
  final CouponModel? coupon;
  final VoidCallback onComplete;
  const _SummaryFooter({
    required this.s,
    required this.cartList,
    required this.couponDiscount,
    required this.coupon,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final double items = kioskItemsTotal(cartList);
    final double discount = kioskDiscountTotal(cartList);
    final double tax = kioskTaxTotal(cartList);
    final double total = kioskPayableTotal(cartList, couponDiscount);
    final bool enabled = cartList.any((c) => c != null);

    return Container(
      decoration: BoxDecoration(
        color: kCheckoutFieldBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30 * s)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 40 * s,
              offset: Offset(0, -10 * s)),
        ],
      ),
      padding: EdgeInsets.fromLTRB(107 * s, 69 * s, 57 * s, 60 * s),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BreakdownRow(
            s: s,
            label: kioskTranslate(context, 'items_total', 'Items total')
                .toUpperCase(),
            value: PriceConverterHelper.convertPrice(items),
          ),
          if (discount > 0) ...[
            SizedBox(height: 18 * s),
            _BreakdownRow(
              s: s,
              label: kioskTranslate(context, 'discount', 'Discount')
                  .toUpperCase(),
              value: '- ${PriceConverterHelper.convertPrice(discount)}',
            ),
          ],
          // The artboard puts the discount between ITEMS TOTAL and TAX, so the
          // coupon's own row sits with the other money coming off.
          if (couponDiscount > 0) ...[
            SizedBox(height: 18 * s),
            _BreakdownRow(
              s: s,
              label: kioskCouponRowLabel(
                discountLabel:
                    kioskTranslate(context, 'discount', 'Discount'),
                title: coupon?.title,
                code: coupon?.code,
              ),
              value: '- ${PriceConverterHelper.convertPrice(couponDiscount)}',
            ),
          ],
          SizedBox(height: 18 * s),
          _BreakdownRow(
            s: s,
            label: kioskTranslate(context, 'tax', 'Tax').toUpperCase(),
            value: PriceConverterHelper.convertPrice(tax),
          ),
          SizedBox(height: 50 * s),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                  child: Text('TOTAL',
                      style: loewExtraBold.copyWith(
                          fontSize: 200 * s, height: 1, color: Colors.black))),
              Text(
                PriceConverterHelper.convertPrice(total),
                style: loewRegular.copyWith(
                    fontSize: 180 * s, height: 1, color: Colors.black),
              ),
            ],
          ),
          SizedBox(height: 50 * s),
          KioskCheckoutButton(
            s: s,
            label: kioskTranslate(context, 'complete_order_and_pay',
                    'Complete order & pay')
                .toUpperCase(),
            filled: true,
            onTap: enabled ? onComplete : null,
          ),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final double s;
  final String label;
  final String value;
  const _BreakdownRow(
      {required this.s, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // A coupon row carries the offer's name, which can be long; it shrinks
        // to fit rather than pushing the amount off the panel.
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(label,
                maxLines: 1,
                style: loewExtraBold.copyWith(
                    fontSize: 64 * s, color: Colors.black)),
          ),
        ),
        SizedBox(width: 24 * s),
        Text(value,
            textAlign: TextAlign.right,
            style: loewRegular.copyWith(
                fontSize: 100 * s, height: 1, color: Colors.black)),
      ],
    );
  }
}
