import 'package:acafe_customer/features/kiosk/domain/kiosk_chrome_spec.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_navigation_helper.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_checkout_widgets.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/responsive/kiosk_responsive.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/coupon/providers/coupon_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_cart_totals.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_coupon_helper.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_session.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_order_note_sheet.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_tap.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_ui.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_order_line_card.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_upsell_sheet.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/localization/language_constrants.dart';
import 'package:acafe_customer/main.dart';
import 'package:acafe_customer/theme/text_legibility.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:provider/provider.dart';

const Color _kCardBg = Color(0xFFFBF8EF);

/// "€ 17,50" — the cart TOTAL row (Figma 2305:15652) wants a comma decimal,
/// unlike the app's usual dot-decimal "€17.50" (`PriceConverterHelper.
/// convertPrice`). Keeps the same currency symbol/position/decimal-count
/// config so only the separator and the space after the symbol differ.
String kioskCommaPrice(double amount) {
  final BuildContext? ctx = Get.context;
  final configModel =
      ctx == null ? null : Provider.of<SplashProvider>(ctx, listen: false).configModel;
  final int decimals = configModel?.decimalPointSettings ?? 2;
  final String symbol = configModel?.currencySymbol ?? '€';
  final String position = configModel?.currencySymbolPosition ?? 'left';

  final List<String> parts = amount.toStringAsFixed(decimals).split('.');
  final String wholePart = parts[0].replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (Match m) => '${m[1]}.',
  );
  final String formatted =
      parts.length > 1 ? '$wholePart,${parts[1]}' : wholePart;

  return position == 'left' ? '$symbol $formatted' : '$formatted $symbol';
}

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
  final KioskReadingInsets insets;

  /// Width of the column the action bar sits in: the reading column on a
  /// landscape window, the artboard band otherwise.
  final double column;

  const _CartLayout({
    required this.s,
    required this.landscape,
    required this.insets,
    required this.column,
  });

  /// Gutter floor in artboard px, so the column can never touch the bezel on
  /// a viewport too narrow for the column's own minimum.
  static const double _minGutter = 48;

  factory _CartLayout.resolve({
    required double width,
    required double band,
    required bool landscape,
    required double s,
  }) {
    return _CartLayout(
      s: s,
      landscape: landscape,
      column: landscape
          ? kioskReadingColumnWidth(width: band, landscape: true)
          : band,
      insets: KioskReadingInsets.resolve(
        width: width,
        band: band,
        landscape: landscape,
        // Figma 2305:16932: cards run 96 in from both edges.
        portraitLeft: 96 * s,
        portraitRight: 96 * s,
        minGutter: _minGutter * s,
      ),
    );
  }

  /// Insets for content inside the centred band.
  EdgeInsets padded({double top = 0, double bottom = 0}) =>
      insets.padded(top: top, bottom: bottom);

  /// Insets for a full-bleed bar, landing on the same column as [padded].
  EdgeInsets pagePadded({double top = 0, double bottom = 0}) =>
      insets.pagePadded(top: top, bottom: bottom);

  // Artboard px. Landscape values are denser: the same layout, less air.
  double get titleSize => landscape ? 76 : 92;
  double get titleGap => landscape ? 16 : 18;
  double get subtitleSize => landscape ? 44 : 60;
  double get listGap => landscape ? 32 : 40;
  double get lineGap => landscape ? 32 : 56;
  double get notePad => landscape ? 34 : 40;
  double get footerTop => landscape ? 48 : 69;
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
                // The header sits in the same column as the action bar and the
                // checkout screens, so the back button's inset is identical.
                KioskCenteredContent(
                  maxWidth: layout.column,
                  child: KioskHeaderBar(
                    s: s,
                    onBack: () => KioskNavigationHelper.backToMenu(context),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: layout.padded(bottom: layout.listGap * s),
                    children: [
                      Text(
                          (getTranslated('my_order', context) ?? 'MY ORDER')
                              .toUpperCase(),
                          style: loewExtraBold.copyWith(
                              fontSize: layout.titleSize * s,
                              height: 1,
                              color: Colors.black)),
                      SizedBox(height: layout.titleGap * s),
                      Text(
                        // Figma uses the plain body sans here (not the condensed
                        // display face) and a lowercase "items".
                        '${getTranslated('dine_in', context) ?? 'Dine in'} / $itemCount ${(getTranslated('items', context) ?? 'items').toLowerCase()}',
                        style: loewRegular.copyWith(
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
                                  fontSize: 64 * s, color: TextTones.secondary),
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
                                // Keyed on the LINE, not its position. A merge
                                // (editing line 2 into line 1's milk) shortens
                                // the list, and an index key would hand the
                                // surviving card the removed line's state.
                                key: ValueKey(cartList[i]!.lineId),
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
        // One shadow for the whole bottom block (note strip + summary), cast
        // upward onto the item list like the Order Summary screen's footer.
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: enabled
                ? BorderRadius.zero
                : BorderRadius.vertical(top: Radius.circular(30 * s)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 40 * s,
                offset: Offset(0, -10 * s),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
  final _CartLayout layout;
  final String note;
  const _OrderNoteBar({required this.layout, required this.note});

  @override
  Widget build(BuildContext context) {
    final double s = layout.s;
    final bool hasNote = note.trim().isNotEmpty;
    // Figma 2305:16923: text 128 in, plus 80 from the right edge.
    final EdgeInsets base = layout.pagePadded(
      top: layout.notePad * s,
      bottom: layout.notePad * s,
    );
    final EdgeInsets padding = base.copyWith(
      left: base.left + 32 * s,
      right: math.max(0, base.right - 16 * s),
    );
    // Design hairline, not a fixed 2 logical px — every other divider in this
    // screen (header rule, item-list gaps) scales with `s`, and a bare "2"
    // read as a bold rule next to already-scaled-down 56-72px type.
    final double borderWidth = (2 * s).clamp(0.5, 1.0);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: _kCardBg,
        border: Border(
          top: BorderSide(color: Colors.black, width: borderWidth),
          bottom: BorderSide(color: Colors.black, width: borderWidth),
        ),
      ),
      child: KioskTap(
        onTap: () => openKioskOrderNote(context),
        child: Padding(
          padding: padding,
          child: Row(
            children: [
              // Empty: "Add an order note" title + muted prompt, two lines.
              // Written: the row collapses to just the note itself, one line
              // — the title would be redundant once there is something to
              // read, and Figma drops it for that state.
              Expanded(
                child: hasNote
                    ? Text(
                        note,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: loewRegular.copyWith(
                          fontSize: 56 * s,
                          height: 1,
                          color: Colors.black,
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            getTranslated('add_an_order_note', context) ??
                                'Add an order note',
                            style: loewExtraBold.copyWith(
                                fontSize: 72 * s,
                                height: 1,
                                color: const Color(0xFF231F20)),
                          ),
                          SizedBox(height: 20 * s),
                          Text(
                            getTranslated(
                                    'anything_we_should_know', context) ??
                                'Anything we should know?',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: loewRegular.copyWith(
                              fontSize: 56 * s,
                              height: 1,
                              color: TextTones.hint,
                            ),
                          ),
                        ],
                      ),
              ),
              SizedBox(width: 80 * s),
              // Plus while empty, plain pencil once written — no circular
              // wrapper on the written state, matching the Figma note row.
              Icon(
                hasNote ? Icons.edit_outlined : Icons.add,
                size: (hasNote ? 64 * s : 80 * s).clamp(32.0, 100.0),
                color: hasNote
                    ? Colors.black
                    : Colors.black.withValues(alpha: 0.6),
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

  /// Footer drawn at 80% of the Figma artboard (user asked for smaller).
  double get _s => layout.s * 0.80;

  @override
  Widget build(BuildContext context) {
    final double s = _s;

    // One full-bleed bar at every size: the summary belongs under the items
    // it totals, lifted off the page by the same rounded lip and shadow the
    // portrait artboard uses.
    //
    // The TOTAL block is content and keeps its 0.8 scale (a deliberate client
    // request). The two buttons below it are CHROME: the shared action bar at
    // the chrome scale, with its own insets and 87 bottom gap.
    return Container(
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30 * s)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            // Figma 2305:16922: 107 left / 57 right around the summary.
            padding: layout
                .pagePadded(top: layout.footerTop * s)
                .copyWith(
                  left: layout.pagePadded().left + 11 * layout.s,
                  right: math.max(0, layout.pagePadded().right - 39 * layout.s),
                ),
            child: _totalRow(context),
          ),
          KioskCenteredContent(
            maxWidth: layout.column,
            child: KioskActionBar(
              s: KioskChrome.scaleOf(context),
              actions: [
                KioskBarAction(
                  label: (couponDiscount > 0
                          ? (couponCode ??
                              getTranslated('add_coupon', context) ??
                              'ADD COUPON')
                          : (getTranslated('add_coupon', context) ??
                              'ADD COUPON'))
                      .toUpperCase(),
                  filled: false,
                  onTap: enabled
                      ? () => openKioskCouponScreen(
                            context,
                            orderAmount: kioskOrderAmountBeforeCoupon(cartList),
                          )
                      : null,
                ),
                KioskBarAction(
                  label: (getTranslated('check_out', context) ?? 'CHECK OUT')
                      .toUpperCase(),
                  filled: true,
                  onTap: enabled ? () => openKioskCheckout(context) : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// TOTAL + amount row — Figma 2305:15652.
  ///
  /// No ITEMS TOTAL / TAX breakdown on this screen: the cart design shows the
  /// grand TOTAL only. Those figures are still computed and shown on the
  /// confirm screen and the printed receipt.
  Widget _totalRow(BuildContext context) {
    final double s = _s;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          (getTranslated('total', context) ?? 'TOTAL').toUpperCase(),
          maxLines: 1,
          style: loewExtraBold.copyWith(
            fontSize: 216 * s,
            height: 1,
            color: Colors.black,
          ),
        ),
        SizedBox(width: 24 * s),
        // Expanded + FittedBox(scaleDown): shrink a long amount to the
        // row instead of letting it wrap and blow the footer's height.
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              kioskCommaPrice(total),
              maxLines: 1,
              style: loewRegular.copyWith(
                fontSize: 256 * s,
                height: 1,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
