import 'dart:math' as math;

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

/// Artboard px a single breakdown line occupies: the 44px row plus the sliver
/// of air `spaceBetween` needs to keep four of them from touching.
const double _kBreakdownLine = 46;

/// "MY ORDER" — review the cart, edit/remove lines, then go to checkout.
///
/// One composition at every size: header, scrolling item list, order-note
/// strip, sticky summary footer. The wide layout used to split the screen —
/// items left, a summary card floating right — which reads as two unfinished
/// halves on anything between a tablet and a 4K panel, and hides the total
/// away from the items it totals. What the viewport changes now is the column
/// the content sits in and the density of the chrome around it, never the
/// composition itself.
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
            final _CartLayout layout = _CartLayout.resolve(
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
                final double total =
                    kioskPayableTotal(cartList, couponDiscount);
                final int itemCount = kioskCartItemCount(cartList);
                final bool enabled = cartList.isNotEmpty;

                return _CartBody(
                  layout: layout,
                  cartList: cartList,
                  itemCount: itemCount,
                  total: total,
                  couponDiscount: couponDiscount,
                  couponCode: couponProvider.coupon?.code,
                  couponTitle: couponProvider.coupon?.title,
                  note: cartProvider.orderNote,
                  enabled: enabled,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// The column the cart sits in, and how tight its chrome is.
///
/// Portrait is the Figma artboard untouched — the production 1080×1920 kiosk
/// resolves to exactly the numbers it always did. Landscape keeps the same
/// stacked composition but centres a reading column and trims the vertical
/// chrome, because height, not width, is what a wide screen runs out of.
class _CartLayout {
  /// Figma artboard px → logical px.
  final double s;
  final bool landscape;

  /// Logical-px insets that centre the content column inside the artboard
  /// band (what the header and the item list are laid out in).
  final double left;
  final double right;

  /// The same insets measured from the edge of the *screen*, for the note
  /// strip and the summary bar: those run full-bleed to the bezel, but their
  /// contents still line up with the items above them.
  final double pageLeft;
  final double pageRight;

  const _CartLayout({
    required this.s,
    required this.landscape,
    required this.left,
    required this.right,
    required this.pageLeft,
    required this.pageRight,
  });

  /// Share of a landscape viewport the column takes, bounded so a small
  /// tablet keeps a usable column and a large panel never stretches one cart
  /// line into a thumbnail at one end and a stepper at the other.
  static const double _columnFraction = 0.62;
  static const double _columnMin = 640;
  static const double _columnMax = 1600;

  /// Gutter floor in artboard px, so the column can never touch the bezel on
  /// a viewport too narrow for [_columnMin].
  static const double _minGutter = 48;

  factory _CartLayout.resolve({
    required double width,
    required double band,
    required bool landscape,
    required double s,
  }) {
    final double bleed = math.max((width - band) / 2, 0);
    double left;
    double right;
    if (landscape) {
      final double column = kioskBounded(
        band * _columnFraction,
        min: math.min(band, _columnMin),
        max: _columnMax,
      );
      final double side = math.max((band - column) / 2, _minGutter * s);
      left = side;
      right = side;
    } else {
      // Figma gutters: 132 left (the list's optical margin), 60 right.
      left = 132 * s;
      right = 60 * s;
    }
    return _CartLayout(
      s: s,
      landscape: landscape,
      left: left,
      right: right,
      pageLeft: bleed + left,
      pageRight: bleed + right,
    );
  }

  /// Insets for content inside the centred band.
  EdgeInsets padded({double top = 0, double bottom = 0}) =>
      EdgeInsets.fromLTRB(left, top, right, bottom);

  /// Insets for a full-bleed bar, landing on the same column as [padded].
  EdgeInsets pagePadded({double top = 0, double bottom = 0}) =>
      EdgeInsets.fromLTRB(pageLeft, top, pageRight, bottom);

  /// [KioskHeaderBar] takes artboard px, so the resolved gutter is converted
  /// back through [s] to keep the logo and its rule on the same column as
  /// everything below them.
  double get headerGutterDesign => left / s;

  // Artboard px. Landscape values are denser: the same layout, less air.
  double get headerPad => landscape ? 40 : 60;
  double get headerRow => landscape ? 120 : 141;
  double get titleSize => landscape ? 76 : 100;
  double get titleGap => landscape ? 16 : 22;
  double get subtitleSize => landscape ? 44 : 68;
  double get listGap => landscape ? 32 : 40;
  double get lineGap => landscape ? 32 : 42;
  double get notePad => landscape ? 34 : 46;
  double get footerPad => landscape ? 64 : 100;
  double get buttonHeight => landscape ? 150 : 180;

  /// Gap between the two footer buttons — and, on the left, the gap the
  /// breakdown's divider is centred in.
  double get buttonGap => 28;
}

/// Header, scrolling items, note strip, sticky footer — at every size.
class _CartBody extends StatelessWidget {
  final _CartLayout layout;
  final List<CartModel?> cartList;
  final int itemCount;
  final double total;
  final double couponDiscount;
  final String? couponCode;
  final String? couponTitle;
  final String note;
  final bool enabled;

  const _CartBody({
    required this.layout,
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
    final double s = layout.s;
    return Column(
      children: [
        // Header and items live in the centred artboard band; the note strip
        // and summary below run to the bezel so the page ends on an edge, not
        // on a floating card.
        Expanded(
          child: KioskCenteredContent(
            child: Column(
              children: [
                KioskHeaderBar(
                  s: s,
                  fallback: RouterHelper.getKioskMenuRoute,
                  horizontalPadding: layout.headerGutterDesign,
                  verticalPadding: layout.headerPad,
                  rowHeight: layout.headerRow,
                ),
                Expanded(
                  child: ListView(
                    padding: layout.padded(bottom: layout.listGap * s),
                    children: [
                      Text(getTranslated('my_order', context) ?? 'MY ORDER',
                          style: loewExtraBold.copyWith(
                              fontSize: layout.titleSize * s,
                              height: 1,
                              color: Colors.black)),
                      SizedBox(height: layout.titleGap * s),
                      Text(
                        '${getTranslated('dine_in', context) ?? 'Dine in'} / $itemCount ${getTranslated('items', context) ?? 'items'}',
                        style: scotchDisplayCondLight.copyWith(
                            fontSize: layout.subtitleSize * s,
                            height: 1,
                            color: Colors.black),
                      ),
                      SizedBox(height: layout.listGap * s),
                      if (cartList.isEmpty)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 200 * s),
                          child: Center(
                            child: Text(
                              getTranslated('empty_cart', context) ??
                                  'Empty cart',
                              style: loewRegular.copyWith(
                                  fontSize: 64 * s, color: Colors.black54),
                            ),
                          ),
                        )
                      else
                        for (int i = 0; i < cartList.length; i++)
                          if (cartList[i] != null)
                            Padding(
                              padding:
                                  EdgeInsets.only(bottom: layout.lineGap * s),
                              child: KioskOrderLineCard(
                                s: s,
                                cart: cartList[i]!,
                                index: i,
                                // Square crop on a wide screen: the portrait
                                // one makes a single line a third of the
                                // viewport, so the second item never shows.
                                imageAspect: layout.landscape
                                    ? 1
                                    : kOrderLineImageAspect,
                              ),
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (enabled) _OrderNoteBar(layout: layout, note: note),
        _Footer(
          layout: layout,
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

/// "Add an order note" strip between the item list and the footer. Tapping it
/// opens the on-screen keyboard sheet; once a note exists the row shows it back
/// so the customer can see what they wrote without reopening the editor.
class _OrderNoteBar extends StatelessWidget {
  final _CartLayout layout;
  final String note;
  const _OrderNoteBar({required this.layout, required this.note});

  @override
  Widget build(BuildContext context) {
    final double s = layout.s;
    final bool hasNote = note.trim().isNotEmpty;
    final EdgeInsets padding = layout.pagePadded(
      top: layout.notePad * s,
      bottom: layout.notePad * s,
    );

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
  final _CartLayout layout;
  final List<CartModel?> cartList;
  final double total;
  final double couponDiscount;
  final String? couponCode;

  /// The applied coupon's offer name, so its row can say what was applied.
  final String? couponTitle;
  final bool enabled;
  const _Footer({
    required this.layout,
    required this.cartList,
    required this.total,
    required this.couponDiscount,
    required this.couponCode,
    required this.couponTitle,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final double s = layout.s;
    final double items = kioskItemsTotal(cartList);
    final double discount = kioskDiscountTotal(cartList);
    final double tax = kioskTaxTotal(cartList);

    // One full-bleed bar at every size: the summary belongs under the items
    // it totals, lifted off the page by the same rounded lip and shadow the
    // portrait artboard uses.
    return Container(
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(40 * s)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            offset: const Offset(0, 50),
            blurRadius: 40.3,
            spreadRadius: 20,
          ),
        ],
      ),
      padding: layout.pagePadded(
        top: layout.footerPad * s,
        bottom: layout.footerPad * s,
      ),
      child: _summaryBody(context, items, discount, tax),
    );
  }

  /// Breakdown on the left, the two actions on the right, their blocks height
  /// matched so the divider lands in the gap between the buttons.
  Widget _summaryBody(
    BuildContext context,
    double items,
    double discount,
    double tax,
  ) {
    final double s = layout.s;
    // The breakdown block and the button stack are the same height so the
    // divider between ITEMS/TAX and YOUR PAY lands in the gap between the two
    // buttons. With both a discount AND a coupon row that block is four lines
    // — more than the landscape button height — so the height is whichever of
    // the two needs more room, and both columns follow it.
    final int rows = 2 + (discount > 0 ? 1 : 0) + (couponDiscount > 0 ? 1 : 0);
    final double blockHeight =
        math.max(layout.buttonHeight * s, rows * _kBreakdownLine * s);
    final double blockGap = layout.buttonGap * s;
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
                height: blockHeight,
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
                height: blockGap,
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
                height: blockHeight,
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
              _couponButton(context, height: blockHeight),
              SizedBox(height: blockGap),
              _checkoutButton(context, height: blockHeight),
            ],
          ),
        ),
      ],
    );
  }

  Widget _couponButton(BuildContext context, {required double height}) {
    return _FooterButton(
      s: layout.s,
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
      s: layout.s,
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
