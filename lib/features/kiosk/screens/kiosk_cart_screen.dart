import 'package:flutter/material.dart';
import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/responsive/kiosk_responsive.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/coupon/providers/coupon_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_coupon_helper.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_coupon_reward.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_session.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_order_note_sheet.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_tap.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_ui.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_order_line_card.dart';
import 'package:acafe_customer/helper/price_converter_helper.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_upsell_sheet.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:acafe_customer/localization/language_constrants.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:provider/provider.dart';

const Color _kCardBg = Color(0xFFFBF8EF);
const Color _kCheckoutText = Color(0xFFFAF9F5);
const Color _kNoteDivider = Color(0xFFDED9C7);
const Color _kNoteHintText = Color(0xFF8A8275);

/// "MY ORDER" — review the cart, edit/remove lines, then go to checkout.
class KioskCartScreen extends StatelessWidget {
  const KioskCartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KioskUI.pageBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double s = KioskMetrics.maybeOf(context)?.scale ??
                KioskResponsive.scale(
                    constraints.maxWidth, constraints.maxHeight);
            final bool landscape =
                constraints.maxWidth > constraints.maxHeight;
            return Consumer2<CartProvider, CouponProvider>(
              builder: (context, cartProvider, couponProvider, _) {
                final cartList = cartProvider.cartList;
                final double couponDiscount = couponProvider.discount ?? 0;
                final double total =
                    kioskPayableTotal(cartList, couponDiscount);
                final int itemCount = kioskCartItemCount(cartList);
                final bool enabled = cartList.isNotEmpty;

                return KioskCenteredContent(
                  child: landscape
                      ? _LandscapeCart(
                          s: s,
                          cartList: cartList,
                          itemCount: itemCount,
                          total: total,
                          couponDiscount: couponDiscount,
                          couponCode: couponProvider.coupon?.code,
                          couponTitle: couponProvider.coupon?.title,
                          note: cartProvider.orderNote,
                          enabled: enabled,
                        )
                      : _PortraitCart(
                          s: s,
                          cartList: cartList,
                          itemCount: itemCount,
                          total: total,
                          couponDiscount: couponDiscount,
                          couponCode: couponProvider.coupon?.code,
                          couponTitle: couponProvider.coupon?.title,
                          note: cartProvider.orderNote,
                          enabled: enabled,
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

/// Figma stacked composition — production 1080×1920 and every other portrait.
class _PortraitCart extends StatelessWidget {
  final double s;
  final List<CartModel?> cartList;
  final int itemCount;
  final double total;
  final double couponDiscount;
  final String? couponCode;
  final String? couponTitle;
  final String note;
  final bool enabled;

  const _PortraitCart({
    required this.s,
    required this.cartList,
    required this.itemCount,
    required this.total,
    required this.couponDiscount,
    required this.couponCode,
    required this.couponTitle,
    required this.note,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        KioskHeaderBar(
          s: s,
          fallback: RouterHelper.getKioskMenuRoute,
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(132 * s, 0, 60 * s, 40 * s),
            children: [
              Text(getTranslated('my_order', context) ?? 'MY ORDER',
                  style: loewExtraBold.copyWith(
                      fontSize: 100 * s, height: 1, color: Colors.black)),
              SizedBox(height: 22 * s),
              Text(
                '${getTranslated('dine_in', context) ?? 'Dine in'} / $itemCount ${getTranslated('items', context) ?? 'items'}',
                style: scotchDisplayCondLight.copyWith(
                    fontSize: 68 * s, height: 1, color: Colors.black),
              ),
              SizedBox(height: 40 * s),
              if (cartList.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 200 * s),
                  child: Center(
                    child: Text(
                      getTranslated('empty_cart', context) ?? 'Empty cart',
                      style: loewRegular.copyWith(
                          fontSize: 64 * s, color: Colors.black54),
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
        if (enabled) _OrderNoteBar(s: s, note: note),
        _Footer(
          s: s,
          cartList: cartList,
          total: total,
          couponDiscount: couponDiscount,
          couponCode: couponCode,
          couponTitle: couponTitle,
          enabled: enabled,
        ),
      ],
    );
  }
}

/// Landscape: item list left, sticky scaled summary right. Same `s`, not a
/// frozen-pixel twin of the portrait artboard.
class _LandscapeCart extends StatelessWidget {
  final double s;
  final List<CartModel?> cartList;
  final int itemCount;
  final double total;
  final double couponDiscount;
  final String? couponCode;
  final String? couponTitle;
  final String note;
  final bool enabled;

  const _LandscapeCart({
    required this.s,
    required this.cartList,
    required this.itemCount,
    required this.total,
    required this.couponDiscount,
    required this.couponCode,
    required this.couponTitle,
    required this.note,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        KioskHeaderBar(
          s: s,
          fallback: RouterHelper.getKioskMenuRoute,
          verticalPadding: 28,
          rowHeight: 100,
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(64 * s, 0, 48 * s, 32 * s),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        getTranslated('my_order', context) ?? 'MY ORDER',
                        style: loewExtraBold.copyWith(
                            fontSize: 72 * s, height: 1, color: Colors.black),
                      ),
                      SizedBox(height: 12 * s),
                      Text(
                        '${getTranslated('dine_in', context) ?? 'Dine in'} / $itemCount ${getTranslated('items', context) ?? 'items'}',
                        style: scotchDisplayCondLight.copyWith(
                            fontSize: 40 * s, height: 1.2, color: Colors.black),
                      ),
                      SizedBox(height: 24 * s),
                      Expanded(
                        child: cartList.isEmpty
                            ? Center(
                                child: Text(
                                  getTranslated('empty_cart', context) ??
                                      'Empty cart',
                                  style: loewRegular.copyWith(
                                      fontSize: 40 * s, color: Colors.black54),
                                ),
                              )
                            : ListView.builder(
                                itemCount: cartList.length,
                                itemBuilder: (context, i) {
                                  if (cartList[i] == null) {
                                    return const SizedBox.shrink();
                                  }
                                  return Padding(
                                    padding: EdgeInsets.only(bottom: 24 * s),
                                    child: KioskOrderLineCard(
                                        s: s, cart: cartList[i]!, index: i),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 32 * s),
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      if (enabled) _OrderNoteBar(s: s, note: note, compact: true),
                      Expanded(
                        child: SingleChildScrollView(
                          child: _Footer(
                            s: s,
                            cartList: cartList,
                            total: total,
                            couponDiscount: couponDiscount,
                            couponCode: couponCode,
                            couponTitle: couponTitle,
                            enabled: enabled,
                            compact: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}


/// "Add an order note" strip between the item list and the footer. Tapping it
/// opens the on-screen keyboard sheet; once a note exists the row shows it back
/// so the customer can see what they wrote without reopening the editor.
class _OrderNoteBar extends StatelessWidget {
  final double s;
  final String note;
  final bool compact;
  const _OrderNoteBar({
    required this.s,
    required this.note,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasNote = note.trim().isNotEmpty;
    final EdgeInsets padding = compact
        ? EdgeInsets.fromLTRB(24 * s, 24 * s, 24 * s, 24 * s)
        : EdgeInsets.fromLTRB(132 * s, 46 * s, 132 * s, 46 * s);

    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _kNoteDivider)),
      ),
      child: KioskTap(
        onTap: () => openKioskOrderNote(context),
        child: Padding(
          padding: padding,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      getTranslated('add_an_order_note', context) ??
                          'Add an order note',
                      style: loewBold.copyWith(
                          fontSize: 46 * s, height: 1.1, color: Colors.black),
                    ),
                    SizedBox(height: 10 * s),
                    Text(
                      hasNote
                          ? note
                          : (getTranslated(
                                  'anything_we_should_know', context) ??
                              'Anything we should know?'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: loewRegular.copyWith(
                        fontSize: 38 * s,
                        height: 1.25,
                        color: hasNote ? Colors.black87 : _kNoteHintText,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 32 * s),
              // Plus while empty, pencil once written — the affordance changes
              // with what the tap will actually do.
              Icon(
                hasNote ? Icons.edit_outlined : Icons.add,
                size: (52 * s).clamp(20.0, 40.0),
                color: Colors.black87,
              ),
            ],
          ),
        ),
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

  /// The applied coupon's offer name, so its row can say what was applied.
  final String? couponTitle;
  final bool enabled;
  final bool compact;
  const _Footer({
    required this.s,
    required this.cartList,
    required this.total,
    required this.couponDiscount,
    required this.couponCode,
    required this.couponTitle,
    required this.enabled,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final double items = kioskItemsTotal(cartList);
    final double discount = kioskDiscountTotal(cartList);
    final double tax = kioskTaxTotal(cartList);

    return Container(
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: compact
            ? BorderRadius.circular(30 * s)
            : BorderRadius.vertical(top: Radius.circular(40 * s)),
        boxShadow: compact
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  offset: const Offset(0, 50),
                  blurRadius: 40.3,
                  spreadRadius: 20,
                ),
              ],
      ),
      padding: compact
          ? EdgeInsets.fromLTRB(32 * s, 36 * s, 32 * s, 36 * s)
          : EdgeInsets.fromLTRB(132 * s, 100 * s, 132 * s, 100 * s),
      child: compact ? _compactBody(context, items, discount, tax) : _portraitBody(context, items, discount, tax),
    );
  }

  Widget _portraitBody(
    BuildContext context,
    double items,
    double discount,
    double tax,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: mirrors the right column's two-block layout so the
        // divider lands in the same gap as the space between the buttons.
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Block 1: ITEMS TOTAL (top) / TAX (bottom), same height as
              // the ADD COUPON button.
              SizedBox(
                height: 180 * s,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _BreakdownRow(
                      s: s,
                      label: (getTranslated('items_total', context) ??
                              'ITEMS TOTAL')
                          .toUpperCase(),
                      value: PriceConverterHelper.convertPrice(items),
                    ),
                    if (discount > 0)
                      _BreakdownRow(
                        s: s,
                        label:
                            (getTranslated('discount', context) ?? 'DISCOUNT')
                                .toUpperCase(),
                        value:
                            '- ${PriceConverterHelper.convertPrice(discount)}',
                      ),
                    if (couponDiscount > 0)
                      _BreakdownRow(
                        s: s,
                        label: kioskCouponRowLabel(
                          discountLabel:
                              getTranslated('discount', context) ?? 'DISCOUNT',
                          title: couponTitle,
                          code: couponCode,
                        ),
                        value:
                            '- ${PriceConverterHelper.convertPrice(couponDiscount)}',
                      ),
                    _BreakdownRow(
                      s: s,
                      label: (getTranslated('tax', context) ?? 'TAX')
                          .toUpperCase(),
                      value: PriceConverterHelper.convertPrice(tax),
                    ),
                  ],
                ),
              ),
              // Divider sits centered in the same gap that separates the
              // two buttons on the right.
              SizedBox(
                height: 28 * s,
                child: Center(
                  child: Container(
                    width: double.infinity,
                    height: (2 * s).clamp(1.5, 3.0),
                    color: Colors.black.withValues(alpha: 0.4),
                  ),
                ),
              ),
              // Block 2: YOUR PAY, centered, same height as CHECK OUT.
              SizedBox(
                height: 180 * s,
                child: Center(
                  child: _BreakdownRow(
                    s: s,
                    label: (getTranslated('your_pay', context) ?? 'YOUR PAY')
                        .toUpperCase(),
                    value: PriceConverterHelper.convertPrice(total),
                    emphasized: true,
                  ),
                ),
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
              _couponButton(context, height: 180 * s),
              SizedBox(height: 28 * s),
              _checkoutButton(context, height: 180 * s),
            ],
          ),
        ),
      ],
    );
  }

  Widget _compactBody(
    BuildContext context,
    double items,
    double discount,
    double tax,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BreakdownRow(
          s: s,
          label:
              (getTranslated('items_total', context) ?? 'ITEMS TOTAL')
                  .toUpperCase(),
          value: PriceConverterHelper.convertPrice(items),
        ),
        if (discount > 0) ...[
          SizedBox(height: 12 * s),
          _BreakdownRow(
            s: s,
            label: (getTranslated('discount', context) ?? 'DISCOUNT')
                .toUpperCase(),
            value: '- ${PriceConverterHelper.convertPrice(discount)}',
          ),
        ],
        if (couponDiscount > 0) ...[
          SizedBox(height: 12 * s),
          _BreakdownRow(
            s: s,
            label: kioskCouponRowLabel(
              discountLabel:
                  getTranslated('discount', context) ?? 'DISCOUNT',
              title: couponTitle,
              code: couponCode,
            ),
            value: '- ${PriceConverterHelper.convertPrice(couponDiscount)}',
          ),
        ],
        SizedBox(height: 12 * s),
        _BreakdownRow(
          s: s,
          label: (getTranslated('tax', context) ?? 'TAX').toUpperCase(),
          value: PriceConverterHelper.convertPrice(tax),
        ),
        SizedBox(height: 16 * s),
        Container(
          height: (2 * s).clamp(1.5, 3.0),
          color: Colors.black.withValues(alpha: 0.4),
        ),
        SizedBox(height: 16 * s),
        _BreakdownRow(
          s: s,
          label: (getTranslated('your_pay', context) ?? 'YOUR PAY')
              .toUpperCase(),
          value: PriceConverterHelper.convertPrice(total),
          emphasized: true,
        ),
        SizedBox(height: 24 * s),
        _couponButton(context, height: 120 * s),
        SizedBox(height: 16 * s),
        _checkoutButton(context, height: 120 * s),
      ],
    );
  }

  Widget _couponButton(BuildContext context, {required double height}) {
    return _FooterButton(
      s: s,
      height: height,
      label: (couponDiscount > 0
              ? (couponCode ??
                  getTranslated('add_coupon', context) ??
                  'ADD COUPON')
              : (getTranslated('add_coupon', context) ?? 'ADD COUPON'))
          .toUpperCase(),
      filled: false,
      onTap: enabled
          ? () => openKioskCouponScreen(
                context,
                orderAmount: kioskOrderAmountBeforeCoupon(cartList),
              )
          : null,
    );
  }

  Widget _checkoutButton(BuildContext context, {required double height}) {
    return _FooterButton(
      s: s,
      height: height,
      label: (getTranslated('check_out', context) ?? 'CHECK OUT').toUpperCase(),
      filled: true,
      onTap: enabled ? () => openKioskCheckout(context) : null,
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
        // A coupon row carries the offer's name, which can be long; it shrinks
        // to fit rather than wrapping out of the footer's fixed-height block.
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              maxLines: 1,
              style: loewExtraBold.copyWith(
                fontSize: emphasized ? 70 * s : 44 * s,
                height: 1,
                color: Colors.black,
              ),
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
              style: (filled ? loewRegular800 : loewRegular700).copyWith(
                fontSize: 52 * s,
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
