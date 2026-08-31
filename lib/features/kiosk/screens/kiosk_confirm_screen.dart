import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/responsive/kiosk_responsive.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/coupon/domain/models/coupon_model.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_coupon_helper.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_coupon_reward.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_place_order.dart';
import 'package:acafe_customer/features/coupon/providers/coupon_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_session.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_tip.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_translate.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_checkout_widgets.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_order_line_card.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_order_success_screen.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_tip_sheet.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_ui.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_upsell_sheet.dart';
import 'package:acafe_customer/helper/custom_snackbar_helper.dart';
import 'package:acafe_customer/helper/price_converter_helper.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:provider/provider.dart';

/// Checkout step 3 — PAYMENT: order summary with the live totals breakdown.
/// "COMPLETE ORDER & PAY" opens the tip sheet, then upsells, then places the
/// order and plays the confirmation animation.
class KioskConfirmScreen extends StatefulWidget {
  const KioskConfirmScreen({super.key});

  @override
  State<KioskConfirmScreen> createState() => _KioskConfirmScreenState();
}

class _KioskConfirmScreenState extends State<KioskConfirmScreen> {
  bool _busy = false;
  bool _placing = false;

  Future<void> _onPay() async {
    if (_busy) return;
    setState(() => _busy = true);

    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final couponProvider = Provider.of<CouponProvider>(context, listen: false);

    double payable() => kioskPayableTotal(
          cartProvider.cartList,
          couponProvider.discount ?? 0,
        );

    try {
      if (!KioskSession.instance.hasLockedInTip) {
        final int? choice = await openKioskTipSheet(
          context,
          payableTotal: payable(),
        );
        if (!mounted) return;
        if (choice == null) return;
        setState(() => KioskSession.instance.applyTip(choice));
      }

      await offerKioskPayUpsell(context);
      if (!mounted) return;

      setState(() => _placing = true);
      final double amount = kioskTotalWithTip(
        payable(),
        KioskSession.instance.tipPercentOrZero,
      );
      final result = await placeKioskOrder(context, amount: amount);
      if (result.success) {
        // Drop the coupon immediately so it cannot ride into the next basket
        // if this widget unmounts during the confirmation animation.
        couponProvider.removeCouponData(true);
      }
      if (!mounted) {
        if (result.success) {
          endKioskCustomerSession(
            null,
            cart: cartProvider,
            coupon: couponProvider,
          );
        }
        return;
      }

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

      final String name = KioskSession.instance.customerName;
      final String rawId = result.orderId ?? '';
      final String orderNumber = rawId.isEmpty || rawId == '-1'
          ? '#'
          : (rawId.startsWith('#') ? rawId : '#$rawId');

      await Navigator.of(context).push(KioskOrderSuccessScreen.route(
        orderNumber: orderNumber,
        thankYouText: _thankYouLabel(context, name),
        pickupMessage: kioskTranslate(
          context,
          'grab_it_at_the_counter',
          'Grab it at the counter when your name shows up enjoy!',
        ),
        confirmedText: kioskTranslate(
          context,
          'order_confirmed',
          'Order confirmed!',
        ).toUpperCase(),
      ));

      // Providers are app-scoped — always clear, even if confirm unmounted.
      endKioskCustomerSession(
        mounted ? context : null,
        cart: cartProvider,
        coupon: couponProvider,
      );
      if (!mounted) return;
      RouterHelper.getKioskMenuRoute(action: RouteAction.pushReplacement);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _placing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KioskUI.pageBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double s = KioskMetrics.maybeOf(context)?.scale ??
                checkoutScale(constraints.maxWidth, constraints.maxHeight);
            final _ConfirmLayout layout = _ConfirmLayout.resolve(
              width: constraints.maxWidth,
              // The shell centres content at the artboard width, so the
              // column is measured against that band, not against 4K of glass.
              band: math.min(constraints.maxWidth, kKioskContentMaxWidth),
              landscape: constraints.maxWidth > constraints.maxHeight,
              s: s,
            );
            return Consumer2<CartProvider, CouponProvider>(
              builder: (context, cartProvider, couponProvider, _) {
                final cartList = cartProvider.cartList;
                final double couponDiscount = couponProvider.discount ?? 0;
                return Stack(
                  children: [
                    Column(
                      children: [
                        // Stepper and items sit in the centred artboard band;
                        // the totals bar below runs to the bezel so the page
                        // ends on an edge, not on a floating panel.
                        Expanded(
                          child: KioskCenteredContent(
                            child: Column(
                              children: [
                                KioskCheckoutHeader(
                                  s: s,
                                  activeStep: 2,
                                  horizontalPadding: layout.headerGutterDesign,
                                  verticalPadding: layout.headerPad,
                                ),
                                Expanded(
                                  child: _ConfirmLineList(
                                    layout: layout,
                                    cartList: cartList,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        _SummaryFooter(
                          layout: layout,
                          cartList: cartList,
                          couponDiscount: couponDiscount,
                          coupon: couponProvider.coupon,
                          payEnabled: !_busy,
                          onPay: _onPay,
                        ),
                      ],
                    ),
                    if (_placing)
                      const Positioned.fill(child: _PlacingOverlay()),
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

/// The column the order summary sits in, and how tight its chrome is.
///
/// Same rule as the cart: portrait is the Figma artboard untouched, landscape
/// keeps the identical stacked composition but centres a reading column and
/// trims the vertical chrome. The three portrait gutters differ per band
/// (the artboard indents the header, the list and the totals panel by
/// different amounts), so each gets its own insets; in landscape they all
/// collapse onto the one column.
class _ConfirmLayout {
  /// Figma artboard px → logical px.
  final double s;
  final bool landscape;
  final KioskReadingInsets header;
  final KioskReadingInsets list;
  final KioskReadingInsets footer;

  const _ConfirmLayout({
    required this.s,
    required this.landscape,
    required this.header,
    required this.list,
    required this.footer,
  });

  /// Gutter floor in artboard px, so the column never touches the bezel on a
  /// viewport too narrow for the column's own minimum.
  static const double _minGutter = 48;

  factory _ConfirmLayout.resolve({
    required double width,
    required double band,
    required bool landscape,
    required double s,
  }) {
    KioskReadingInsets band_(double left, double right) =>
        KioskReadingInsets.resolve(
          width: width,
          band: band,
          landscape: landscape,
          portraitLeft: left * s,
          portraitRight: right * s,
          minGutter: _minGutter * s,
        );
    return _ConfirmLayout(
      s: s,
      landscape: landscape,
      header: band_(107, 107),
      list: band_(77, 115),
      footer: band_(107, 57),
    );
  }

  /// [KioskCheckoutHeader] takes artboard px, so the resolved gutter is
  /// converted back through [s] to land on the same column as the body.
  double get headerGutterDesign => header.left / s;

  // Artboard px. Landscape values are denser: the same layout, less air.
  double get headerPad => landscape ? 84 : 121;
  double get listPad => landscape ? 20 : 40;
  double get titleSize => landscape ? 88 : 128;
  double get titleGap => landscape ? 32 : 50;
  double get lineGap => landscape ? 32 : 50;
  double get footerPadTop => landscape ? 48 : 69;
  double get footerPadBottom => landscape ? 48 : 60;
  double get rowLabelSize => landscape ? 52 : 64;
  double get rowValueSize => landscape ? 76 : 100;
  double get rowGap => landscape ? 14 : 18;
  double get totalGap => landscape ? 32 : 50;
  double get totalLabelSize => landscape ? 120 : 200;
  double get totalValueSize => landscape ? 108 : 180;
  double get payButtonHeight => landscape ? 180 : 252;

  /// Square thumbnails on a wide screen: the Figma portrait crop makes a
  /// single line a third of the viewport, so the next item never shows.
  double get lineImageAspect => landscape ? 1 : kOrderLineImageAspect;
}

String _thankYouLabel(BuildContext context, String name) {
  final String trimmed = name.trim();
  if (trimmed.isEmpty) {
    return kioskTranslate(context, 'thank_you', 'Thank you!').toUpperCase();
  }
  return kioskTranslate(context, 'thank_you_name', 'Thank you, {name}!')
      .replaceAll('{name}', trimmed)
      .toUpperCase();
}

class _ConfirmLineList extends StatelessWidget {
  final _ConfirmLayout layout;
  final List<CartModel?> cartList;

  const _ConfirmLineList({required this.layout, required this.cartList});

  @override
  Widget build(BuildContext context) {
    final double s = layout.s;
    return ListView(
      padding: layout.list.padded(
        top: layout.listPad * s,
        bottom: layout.listPad * s,
      ),
      children: [
        Text(
          kioskTranslate(context, 'order_summary', 'Order summary'),
          textAlign: TextAlign.center,
          style: loewExtraBold.copyWith(
            fontSize: layout.titleSize * s,
            height: 1,
            color: Colors.black,
          ),
        ),
        SizedBox(height: layout.titleGap * s),
        for (int i = 0; i < cartList.length; i++)
          if (cartList[i] != null)
            Padding(
              padding: EdgeInsets.only(bottom: layout.lineGap * s),
              child: KioskOrderLineCard(
                s: s,
                cart: cartList[i]!,
                index: i,
                imageAspect: layout.lineImageAspect,
              ),
            ),
      ],
    );
  }
}

class _PlacingOverlay extends StatelessWidget {
  const _PlacingOverlay();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Container(
        color: Colors.black.withValues(alpha: 0.28),
        alignment: Alignment.center,
        child: const SizedBox(
          width: 48,
          height: 48,
          child: CircularProgressIndicator(
            strokeWidth: 4,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Totals breakdown (ITEMS TOTAL / DISCOUNT / TAX / TIP / TOTAL) + pay button.
/// One full-bleed bar at every size: the total belongs under the items it
/// totals, not in a panel beside them.
class _SummaryFooter extends StatelessWidget {
  final _ConfirmLayout layout;
  final List<CartModel?> cartList;
  final double couponDiscount;

  /// The applied coupon, so its row can name the offer. Null when none is on.
  final CouponModel? coupon;
  final bool payEnabled;
  final VoidCallback onPay;
  const _SummaryFooter({
    required this.layout,
    required this.cartList,
    required this.couponDiscount,
    required this.coupon,
    required this.payEnabled,
    required this.onPay,
  });

  @override
  Widget build(BuildContext context) {
    final double s = layout.s;
    final double items = kioskItemsTotal(cartList);
    final double discount = kioskDiscountTotal(cartList);
    final double tax = kioskTaxTotal(cartList);
    final double payable = kioskPayableTotal(cartList, couponDiscount);
    final int tipPercent = KioskSession.instance.tipPercentOrZero;
    final double tip = kioskTipAmount(payable, tipPercent);
    final double total = payable + tip;
    final bool enabled = payEnabled && cartList.any((c) => c != null);

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
      padding: layout.footer.pagePadded(
        top: layout.footerPadTop * s,
        bottom: layout.footerPadBottom * s,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BreakdownRow(
            layout: layout,
            label: kioskTranslate(context, 'items_total', 'Items total')
                .toUpperCase(),
            value: PriceConverterHelper.convertPrice(items),
          ),
          if (discount > 0) ...[
            SizedBox(height: layout.rowGap * s),
            _BreakdownRow(
              layout: layout,
              label:
                  kioskTranslate(context, 'discount', 'Discount').toUpperCase(),
              value: '- ${PriceConverterHelper.convertPrice(discount)}',
            ),
          ],
          // The artboard puts the discount between ITEMS TOTAL and TAX, so the
          // coupon's own row sits with the other money coming off.
          if (couponDiscount > 0) ...[
            SizedBox(height: layout.rowGap * s),
            _BreakdownRow(
              layout: layout,
              label: kioskCouponRowLabel(
                discountLabel: kioskTranslate(context, 'discount', 'Discount'),
                title: coupon?.title,
                code: coupon?.code,
              ),
              value: '- ${PriceConverterHelper.convertPrice(couponDiscount)}',
            ),
          ],
          SizedBox(height: layout.rowGap * s),
          _BreakdownRow(
            layout: layout,
            label: kioskTranslate(context, 'tax', 'Tax').toUpperCase(),
            value: PriceConverterHelper.convertPrice(tax),
          ),
          if (tip > 0) ...[
            SizedBox(height: layout.rowGap * s),
            _BreakdownRow(
              layout: layout,
              label: kioskTranslate(context, 'tip', 'Tip').toUpperCase(),
              value: PriceConverterHelper.convertPrice(tip),
            ),
          ],
          SizedBox(height: layout.totalGap * s),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text('TOTAL',
                      style: loewExtraBold.copyWith(
                          fontSize: layout.totalLabelSize * s,
                          height: 1,
                          color: Colors.black)),
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  PriceConverterHelper.convertPrice(total),
                  style: loewRegular.copyWith(
                      fontSize: layout.totalValueSize * s,
                      height: 1,
                      color: Colors.black),
                ),
              ),
            ],
          ),
          SizedBox(height: layout.totalGap * s),
          KioskCheckoutButton(
            s: s,
            label: kioskTranslate(
                    context, 'complete_order_and_pay', 'Complete order & pay')
                .toUpperCase(),
            filled: true,
            height: layout.payButtonHeight,
            onTap: enabled ? onPay : null,
          ),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final _ConfirmLayout layout;
  final String label;
  final String value;
  const _BreakdownRow(
      {required this.layout, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final double s = layout.s;
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
                    fontSize: layout.rowLabelSize * s, color: Colors.black)),
          ),
        ),
        SizedBox(width: 24 * s),
        Text(value,
            textAlign: TextAlign.right,
            style: loewRegular.copyWith(
                fontSize: layout.rowValueSize * s,
                height: 1,
                color: Colors.black)),
      ],
    );
  }
}
