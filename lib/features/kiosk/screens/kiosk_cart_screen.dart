import 'package:flutter/material.dart';
import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/responsive/kiosk_responsive.dart';
import 'package:acafe_customer/common/responsive/responsive.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/coupon/providers/coupon_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_coupon_helper.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_session.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_tap.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_ui.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_order_line_card.dart';
import 'package:acafe_customer/helper/price_converter_helper.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:acafe_customer/localization/language_constrants.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:provider/provider.dart';

const Color _kCardBg = Color(0xFFFBF8EF);
const Color _kCheckoutText = Color(0xFFFAF9F5);

/// "MY ORDER" — review the cart, edit/remove lines, then go to checkout.
class KioskCartScreen extends StatelessWidget {
  const KioskCartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (Responsive.isWide(context)) {
      return const _WideKioskCartScreen();
    }
    return Scaffold(
      backgroundColor: KioskUI.pageBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double s = KioskResponsive.scale(constraints.maxWidth);
            return Consumer2<CartProvider, CouponProvider>(
              builder: (context, cartProvider, couponProvider, _) {
                final cartList = cartProvider.cartList;
                final double couponDiscount = couponProvider.discount ?? 0;
                final double total =
                    kioskPayableTotal(cartList, couponDiscount);
                final int itemCount = kioskCartItemCount(cartList);

                return KioskCenteredContent(
                  child: Column(
                    children: [
                      _TopBar(s: s),
                      Expanded(
                        child: ListView(
                          padding: EdgeInsets.fromLTRB(
                              132 * s, 40 * s, 60 * s, 40 * s),
                          children: [
                            Text(
                                getTranslated('my_order', context) ??
                                    'My Order',
                                style: loewExtraBold.copyWith(
                                    fontSize: 128 * s,
                                    height: 1,
                                    color: Colors.black)),
                            SizedBox(height: 12 * s),
                            Text(
                              '${getTranslated('dine_in', context) ?? 'Dine in'} / $itemCount ${getTranslated('items', context) ?? 'items'}',
                              style: scotchDisplayLight.copyWith(
                                  fontSize: 88 * s,
                                  height: 1,
                                  color: Colors.black),
                            ),
                            SizedBox(height: 40 * s),
                            if (cartList.isEmpty)
                              Padding(
                                padding:
                                    EdgeInsets.symmetric(vertical: 200 * s),
                                child: Center(
                                  child: Text(
                                    getTranslated('empty_cart', context) ??
                                        'Empty cart',
                                    style: loewRegular.copyWith(
                                        fontSize: 64 * s,
                                        color: Colors.black54),
                                  ),
                                ),
                              )
                            else
                              for (int i = 0; i < cartList.length; i++)
                                if (cartList[i] != null)
                                  Padding(
                                    padding: EdgeInsets.only(bottom: 42 * s),
                                    child: KioskOrderLineCard(
                                        s: s, cart: cartList[i]!, index: i),
                                  ),
                          ],
                        ),
                      ),
                      _Footer(
                        s: s,
                        cartList: cartList,
                        total: total,
                        couponDiscount: couponDiscount,
                        couponCode: couponProvider.coupon?.code,
                        enabled: cartList.isNotEmpty,
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Wide layout: scrollable item list (left) + sticky 400px summary (right).
class _WideKioskCartScreen extends StatelessWidget {
  const _WideKioskCartScreen();

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
            final int itemCount = kioskCartItemCount(cartList);
            final bool enabled = cartList.isNotEmpty;

            return Column(
              children: [
                _WideTopBar(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(32, 16, 32, 24),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 820),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  getTranslated('my_order', context) ??
                                      'My Order',
                                  style: loewExtraBold.copyWith(
                                    fontSize: KioskUI.pageTitle,
                                    height: 1,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${getTranslated('dine_in', context) ?? 'Dine in'} / $itemCount ${getTranslated('items', context) ?? 'items'}',
                                  style: scotchDisplayLight.copyWith(
                                    fontSize: KioskUI.body,
                                    height: 1,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Expanded(
                                  child: cartList.isEmpty
                                      ? Center(
                                          child: Text(
                                            getTranslated(
                                                    'empty_cart', context) ??
                                                'Empty cart',
                                            style: loewRegular.copyWith(
                                              fontSize: KioskUI.body,
                                              color: Colors.black54,
                                            ),
                                          ),
                                        )
                                      : ListView.separated(
                                          itemCount: cartList.length,
                                          separatorBuilder: (_, __) =>
                                              const SizedBox(height: 16),
                                          itemBuilder: (context, i) {
                                            if (cartList[i] == null) {
                                              return const SizedBox.shrink();
                                            }
                                            return KioskOrderLineCard(
                                              cart: cartList[i]!,
                                              index: i,
                                              compact: true,
                                            );
                                          },
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 32),
                        SizedBox(
                          width: 400,
                          child: _WideSummaryCard(
                            cartList: cartList,
                            total: total,
                            couponDiscount: couponDiscount,
                            couponCode: couponProvider.coupon?.code,
                            enabled: enabled,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _WideTopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 0),
      child: Column(
        children: [
          SizedBox(
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                IgnorePointer(
                  child: Text(
                    'A/CAFÉ',
                    style: loewExtraBold.copyWith(
                      fontSize: 26,
                      letterSpacing: 1,
                      color: Colors.black,
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: KioskBackButton(
                    size: 56,
                    borderWidth: 2,
                    iconSize: 22,
                    fallback: RouterHelper.getKioskMenuRoute,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(height: 1.5, color: Colors.black),
        ],
      ),
    );
  }
}

class _WideSummaryCard extends StatelessWidget {
  final List<CartModel?> cartList;
  final double total;
  final double couponDiscount;
  final String? couponCode;
  final bool enabled;

  const _WideSummaryCard({
    required this.cartList,
    required this.total,
    required this.couponDiscount,
    required this.couponCode,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final double items = kioskItemsTotal(cartList);
    final double discount = kioskDiscountTotal(cartList);
    final double tax = kioskTaxTotal(cartList);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(KioskUI.radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _WideBreakdownRow(
            label: getTranslated('items_total', context) ?? 'ITEMS TOTAL',
            value: PriceConverterHelper.convertPrice(items),
          ),
          const SizedBox(height: 10),
          _WideBreakdownRow(
            label: getTranslated('tax', context) ?? 'TAX',
            value: PriceConverterHelper.convertPrice(tax),
          ),
          if (discount > 0) ...[
            const SizedBox(height: 10),
            _WideBreakdownRow(
              label: getTranslated('discount', context) ?? 'DISCOUNT',
              value: '- ${PriceConverterHelper.convertPrice(discount)}',
            ),
          ],
          if (couponDiscount > 0) ...[
            const SizedBox(height: 10),
            _WideBreakdownRow(
              label: getTranslated('coupon_discount', context) ??
                  'COUPON DISCOUNT',
              value: '- ${PriceConverterHelper.convertPrice(couponDiscount)}',
            ),
          ],
          const SizedBox(height: 14),
          Container(height: 1, color: Colors.black12),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  getTranslated('your_pay', context) ?? 'YOUR PAY',
                  style: loewExtraBold.copyWith(
                    fontSize: KioskUI.heading,
                    height: 1,
                    color: Colors.black,
                  ),
                ),
              ),
              Text(
                PriceConverterHelper.convertPrice(total),
                style: loewRegular.copyWith(
                  fontSize: KioskUI.heading,
                  height: 1,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          KioskButton.secondary(
            label: couponDiscount > 0
                ? (couponCode ??
                    getTranslated('add_coupon', context) ??
                    'ADD COUPON')
                : (getTranslated('add_coupon', context) ?? 'ADD COUPON'),
            maxWidth: double.infinity,
            onTap: enabled
                ? () => openKioskCouponSheet(
                      context,
                      orderAmount: kioskOrderAmountBeforeCoupon(cartList),
                    )
                : null,
          ),
          const SizedBox(height: 16),
          KioskButton(
            label: getTranslated('check_out', context) ?? 'CHECK OUT',
            height: KioskUI.primaryButtonHeight,
            maxWidth: double.infinity,
            onTap: enabled ? () => RouterHelper.getKioskCheckoutRoute() : null,
          ),
        ],
      ),
    );
  }
}

/// Small label/value row used by the wide summary card's price breakdown.
class _WideBreakdownRow extends StatelessWidget {
  final String label;
  final String value;
  const _WideBreakdownRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: loewBold.copyWith(
              fontSize: KioskUI.caption,
              color: Colors.black54,
            ),
          ),
        ),
        Text(
          value,
          style: loewRegular.copyWith(
            fontSize: KioskUI.body,
            color: Colors.black,
          ),
        ),
      ],
    );
  }
}

/// Top bar: back button (left), centered A/CAFÉ brand.
class _TopBar extends StatelessWidget {
  final double s;
  const _TopBar({required this.s});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(132 * s, 40 * s, 132 * s, 0),
      child: Column(
        children: [
          SizedBox(
            height: 141 * s,
            child: Stack(
              alignment: Alignment.center,
              children: [
                IgnorePointer(
                  child: Text('A/CAFÉ',
                      style: loewExtraBold.copyWith(
                          fontSize: 90 * s,
                          letterSpacing: 2 * s,
                          color: Colors.black)),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: KioskBackButton.scaled(
                    s: s,
                    size: 141,
                    border: 4,
                    icon: 56,
                    minBorder: 2,
                    fallback: RouterHelper.getKioskMenuRoute,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 30 * s),
          Container(height: (2 * s).clamp(1.0, 2.0), color: Colors.black),
        ],
      ),
    );
  }
}

/// Footer: TOTAL + price, then ADD COUPON (outlined) and CHECK OUT (filled).
class _Footer extends StatelessWidget {
  final double s;
  final List<CartModel?> cartList;
  final double total;
  final double couponDiscount;
  final String? couponCode;
  final bool enabled;
  const _Footer({
    required this.s,
    required this.cartList,
    required this.total,
    required this.couponDiscount,
    required this.couponCode,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final double items = kioskItemsTotal(cartList);
    final double discount = kioskDiscountTotal(cartList);
    final double tax = kioskTaxTotal(cartList);

    return Container(
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(40 * s)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 45 * s,
              offset: Offset(0, -1 * s)),
        ],
      ),
      padding: EdgeInsets.fromLTRB(132 * s, 50 * s, 60 * s, 50 * s),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: ITEMS TOTAL / TAX / divider / YOUR PAY breakdown.
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BreakdownRow(
                  s: s,
                  label:
                      getTranslated('items_total', context) ?? 'ITEMS TOTAL',
                  value: PriceConverterHelper.convertPrice(items),
                ),
                if (discount > 0) ...[
                  SizedBox(height: 20 * s),
                  _BreakdownRow(
                    s: s,
                    label: getTranslated('discount', context) ?? 'DISCOUNT',
                    value: '- ${PriceConverterHelper.convertPrice(discount)}',
                  ),
                ],
                SizedBox(height: 20 * s),
                _BreakdownRow(
                  s: s,
                  label: getTranslated('tax', context) ?? 'TAX',
                  value: PriceConverterHelper.convertPrice(tax),
                ),
                if (couponDiscount > 0) ...[
                  SizedBox(height: 20 * s),
                  _BreakdownRow(
                    s: s,
                    label: getTranslated('coupon_discount', context) ??
                        'COUPON DISCOUNT',
                    value:
                        '- ${PriceConverterHelper.convertPrice(couponDiscount)}',
                  ),
                ],
                SizedBox(height: 28 * s),
                Container(
                  height: 2 * s,
                  color: Colors.black.withValues(alpha: 0.15),
                ),
                SizedBox(height: 28 * s),
                _BreakdownRow(
                  s: s,
                  label: getTranslated('your_pay', context) ?? 'YOUR PAY',
                  value: PriceConverterHelper.convertPrice(total),
                  emphasized: true,
                ),
              ],
            ),
          ),
          SizedBox(width: 48 * s),
          // Right: ADD COUPON (outlined) stacked over CHECK OUT (filled).
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _FooterButton(
                  s: s,
                  height: 130 * s,
                  label: couponDiscount > 0
                      ? (couponCode ??
                          getTranslated('add_coupon', context) ??
                          'ADD COUPON')
                      : (getTranslated('add_coupon', context) ??
                          'ADD COUPON'),
                  filled: false,
                  onTap: enabled
                      ? () => openKioskCouponSheet(
                            context,
                            orderAmount:
                                kioskOrderAmountBeforeCoupon(cartList),
                          )
                      : null,
                ),
                SizedBox(height: 28 * s),
                _FooterButton(
                  s: s,
                  height: 130 * s,
                  label: getTranslated('check_out', context) ?? 'CHECK OUT',
                  filled: true,
                  onTap:
                      enabled ? () => RouterHelper.getKioskCheckoutRoute() : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Right-aligned label/value row used by the cart footer's price breakdown.
class _BreakdownRow extends StatelessWidget {
  final double s;
  final String label;
  final String value;
  final bool emphasized;
  const _BreakdownRow({
    required this.s,
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            label,
            style: loewExtraBold.copyWith(
              fontSize: emphasized ? 70 * s : 44 * s,
              height: 1,
              color: Colors.black,
            ),
          ),
        ),
        Text(
          value,
          textAlign: TextAlign.right,
          style: loewRegular.copyWith(
            fontSize: emphasized ? 62 * s : 44 * s,
            height: 1,
            color: Colors.black,
          ),
        ),
      ],
    );
  }
}

class _FooterButton extends StatelessWidget {
  final double s;
  final String label;
  final bool filled;
  final VoidCallback? onTap;
  final double height;
  const _FooterButton(
      {required this.s,
      required this.label,
      required this.filled,
      required this.onTap,
      required this.height});

  @override
  Widget build(BuildContext context) {
    final bool disabled = onTap == null;
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: Material(
        color: filled ? Colors.black : Colors.transparent,
        borderRadius: BorderRadius.circular(30 * s),
        clipBehavior: Clip.antiAlias,
        child: KioskTap(
          onTap: onTap,
          child: Container(
            height: height,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30 * s),
              border: filled
                  ? null
                  : Border.all(
                      color: Colors.black, width: (8 * s).clamp(2.0, 10.0)),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: (filled ? loewExtraBold : loewBold).copyWith(
                fontSize: 72 * s,
                letterSpacing: 1,
                color: filled ? _kCheckoutText : Colors.black,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
