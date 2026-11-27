import 'package:acafe_customer/features/kiosk/domain/kiosk_chrome_spec.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_navigation_helper.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/widgets/custom_image_widget.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/coupon/providers/coupon_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_coupon_helper.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_coupon_reward.dart' show kioskCouponRowLabel;
import 'package:acafe_customer/features/kiosk/domain/kiosk_place_order.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_product_image_helper.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_session.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_tip.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_translate.dart';
import 'package:acafe_customer/features/kiosk/landscape/landscape_metrics.dart';
import 'package:acafe_customer/features/kiosk/landscape/screens/landscape_order_success_screen.dart';
import 'package:acafe_customer/features/kiosk/landscape/widgets/landscape_tip_dialog.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_deal_detail_screen.dart'
    show openKioskCartLine;
import 'package:acafe_customer/features/kiosk/screens/kiosk_order_line_card.dart'
    show KioskLinePriceRow;
import 'package:acafe_customer/features/kiosk/widgets/kiosk_order_note_sheet.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_tap.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_ui.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_upsell_sheet.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/helper/custom_snackbar_helper.dart';
import 'package:acafe_customer/helper/price_converter_helper.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';

// ===========================================================================
// LANDSCAPE KIOSK — "Order summary" (Option B), Figma nodes:
//   2305:9386  — B-12e "Order summary" (no note)
//   2305:10122 — B-12g "Order summary with note" (order-note row shown)
// Checkout step 3 — PAYMENT. Reuses the SAME business logic as portrait's
// `KioskConfirmScreen._onPay` (open the tip pop-up unless already locked in,
// run the upsell, place the order, then push the thank-you screen) — only the
// visuals and which tip/thank-you widget get pushed differ.
// ===========================================================================

const Color _kPageBg = Color(0xFFF7F1DE);
const Color _kCardBg = Color(0xFFFBF8EF);
const Color _kCardBorder = Color(0xFFDED8C6);
const Color _kInk = Color(0xFF0D0D0D);
const Color _kMuted = Color(0xFF6B665C);
const Color _kMutedLight = Color(0xFF73736E);
const Color _kNoteHint = Color(0xFF888480);
const Color _kCouponGreen = Color(0xFF2E7D33);

class LandscapeOrderSummaryScreen extends StatefulWidget {
  const LandscapeOrderSummaryScreen({super.key});

  @override
  State<LandscapeOrderSummaryScreen> createState() =>
      _LandscapeOrderSummaryScreenState();
}

class _LandscapeOrderSummaryScreenState
    extends State<LandscapeOrderSummaryScreen> {
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
        final int? choice = await showLandscapeTipDialog(
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
        couponProvider.removeCouponData(true);
      }
      if (!mounted) {
        if (result.success) {
          endKioskCustomerSession(null, cart: cartProvider, coupon: couponProvider);
        }
        return;
      }

      if (!result.success) {
        setState(() => _placing = false);
        showCustomSnackBarHelper(
          result.message ??
              kioskTranslate(context, 'order_failed', 'Order could not be placed'),
          isError: true,
        );
        return;
      }

      final String name = KioskSession.instance.customerName;
      final String rawId = result.orderId ?? '';
      final String orderNumber =
          rawId.isEmpty || rawId == '-1' ? '' : rawId.replaceFirst('#', '');

      await Navigator.of(context).push(LandscapeOrderSuccessScreen.route(
        orderNumber: orderNumber,
        customerName: name,
        receiptUrl: 'https://acafepos.com/order-details?id=$rawId',
        thankYouHeadline:
            kioskTranslate(context, 'thank_you_headline', 'Thank you!'),
        thankYouSubtitle: kioskTranslate(context, 'order_paid_making_it',
            "Your order is paid. We're making it now."),
        nameCardLabel: kioskTranslate(context, 'we_call_your_name',
                'We call your name at the counter')
            .toUpperCase(),
        receiptHeadline:
            kioskTranslate(context, 'scan_for_your_receipt', 'Scan for your receipt'),
        receiptSubtitle: kioskTranslate(context, 'open_on_phone_follow_order',
            'Open it on your phone and follow your order live.'),
        placeNewOrderLabel:
            kioskTranslate(context, 'place_new_order', 'Place new order').toUpperCase(),
      ));

      endKioskCustomerSession(
        mounted ? context : null,
        cart: cartProvider,
        coupon: couponProvider,
      );
      if (!mounted) return;
      RouterHelper.goKioskMenu();
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
      backgroundColor: _kPageBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final double s = LandscapeMetrics.scaleFor(c.maxWidth, c.maxHeight);
            return Consumer2<CartProvider, CouponProvider>(
              builder: (context, cartProvider, couponProvider, _) {
                return Stack(
                  children: [
                    Column(
                      children: [
                        _Header(s: s),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(48 * s, 24 * s, 48 * s, 24 * s),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _OrderItemsColumn(
                                      s: s, cartList: cartProvider.cartList),
                                ),
                                SizedBox(width: 32 * s),
                                SizedBox(
                                  width: 418 * s,
                                  child: _SummaryCard(
                                    s: s,
                                    cartList: cartProvider.cartList,
                                    couponDiscount: couponProvider.discount ?? 0,
                                    couponTitle: couponProvider.coupon?.title,
                                    couponCode: couponProvider.coupon?.code,
                                    note: cartProvider.orderNote,
                                    payEnabled: !_busy &&
                                        cartProvider.cartList.any((c) => c != null),
                                    onPay: _onPay,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_placing) const Positioned.fill(child: _PlacingOverlay()),
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
          child: CircularProgressIndicator(strokeWidth: 4, color: Colors.white),
        ),
      ),
    );
  }
}

/// Back button + NAME/EMAIL/PAYMENT stepper — Figma B-12e header
/// (`Group 97` back chevron, `Group 159` stepper, centred x423..943).
/// Self-contained: no landscape name/email screen exists yet to extract a
/// shared step-bar widget from.
class _Header extends StatelessWidget {
  final double s;
  const _Header({required this.s});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(30 * s, 30 * s, 30 * s, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KioskBackButton(
            // Landscape variant: never larger than it is today.
            s: KioskChrome.scaleOfVersionA(
                context, 56.4 * s / KioskChromeSpec.backDiameter),
            onTap: () => KioskNavigationHelper.backTo(
                context, RouterHelper.kioskCheckoutEmailScreen),
          ),
          Expanded(
            child: Center(
              child: SizedBox(
                width: 520 * s,
                child: _StepBar(s: s),
              ),
            ),
          ),
          SizedBox(width: 56.4 * s),
        ],
      ),
    );
  }
}

enum _StepState { completed, active }

class _StepBar extends StatelessWidget {
  final double s;
  const _StepBar({required this.s});

  static const List<String> _labels = ['NAME', 'EMAIL', 'PAYMENT'];

  @override
  Widget build(BuildContext context) {
    final List<_StepState> states = [
      _StepState.completed,
      _StepState.completed,
      _StepState.active,
    ];
    final List<Widget> row = [];
    for (int i = 0; i < _labels.length; i++) {
      row.add(_StepNode(s: s, label: _labels[i], state: states[i]));
      if (i < _labels.length - 1) row.add(Expanded(child: _Connector(s: s)));
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: row);
  }
}

class _StepNode extends StatelessWidget {
  final double s;
  final String label;
  final _StepState state;
  const _StepNode({required this.s, required this.label, required this.state});

  @override
  Widget build(BuildContext context) {
    final double d = 54.65 * s;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: d,
          height: d,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: state == _StepState.completed ? Colors.black : Colors.transparent,
            border: Border.all(color: Colors.black, width: (2 * s).clamp(1.0, 3.0)),
          ),
          child: state == _StepState.completed
              ? Icon(Icons.check, size: d * 0.55, color: Colors.white)
              : Container(
                  width: 26.17 * s,
                  height: 26.17 * s,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black),
                ),
        ),
        SizedBox(height: 8 * s),
        Text(label,
            style: loewMedium.copyWith(fontSize: 12 * s, height: 1.0, color: Colors.black)),
      ],
    );
  }
}

class _Connector extends StatelessWidget {
  final double s;
  const _Connector({required this.s});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 27.3 * s, left: 8 * s, right: 8 * s),
      child: Container(height: (1 * s).clamp(1.0, 2.0), color: Colors.black),
    );
  }
}

/// The "Order summary" title + item cards scroll; "ADD MORE ITEMS" stays
/// pinned at the bottom of this column, outside the scroll view.
class _OrderItemsColumn extends StatelessWidget {
  final double s;
  final List<CartModel?> cartList;
  const _OrderItemsColumn({required this.s, required this.cartList});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.only(top: 20 * s),
            children: [
              Text(
                kioskTranslate(context, 'order_summary', 'Order summary'),
                style: loewBold.copyWith(fontSize: 34 * s, height: 1.0, color: Colors.black),
              ),
              SizedBox(height: 24 * s),
              for (int i = 0; i < cartList.length; i++)
                if (cartList[i] != null)
                  Padding(
                    padding: EdgeInsets.only(bottom: 16 * s),
                    child: _SummaryLineCard(s: s, cart: cartList[i]!, index: i),
                  ),
            ],
          ),
        ),
        SizedBox(height: 16 * s),
        _AddMoreItemsButton(s: s),
        SizedBox(height: 20 * s),
      ],
    );
  }
}

class _AddMoreItemsButton extends StatelessWidget {
  final double s;
  const _AddMoreItemsButton({required this.s});

  @override
  Widget build(BuildContext context) {
    return KioskTap(
      onTap: () => Navigator.of(context).maybePop(),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 22 * s),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: _kInk, width: (1.5 * s).clamp(1.0, 2.5)),
          borderRadius: BorderRadius.circular(16 * s),
        ),
        child: Text(
          '+  ${kioskTranslate(context, 'add_more_items', 'ADD MORE ITEMS')}',
          style: loewBold.copyWith(fontSize: 17 * s, height: 1.0, color: _kInk),
        ),
      ),
    );
  }
}

/// One order line card — Figma `item-card/*` (2305:9408 / 2305:9431): photo,
/// name + modifier lines + EDIT, price + unit price + qty stepper.
class _SummaryLineCard extends StatelessWidget {
  final double s;
  final CartModel cart;
  final int index;
  const _SummaryLineCard({required this.s, required this.cart, required this.index});

  @override
  Widget build(BuildContext context) {
    final splash = Provider.of<SplashProvider>(context, listen: false);
    final String name =
        cart.isDeal ? (cart.dealTitle ?? cart.product?.name ?? '') : (cart.product?.name ?? '');
    final List<String> modifiers = _modifierLines(cart);
    final String image = KioskProductImageHelper.cartLineImageUrl(
      cart: cart,
      productImageBaseUrl: splash.baseUrls?.productImageUrl,
      dealImageBaseUrl: splash.baseUrls?.dealImageUrl,
    );
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    void onEdit() => openKioskCartLine(context, cart, cartIndex: index);
    void onDecrement() {
      if ((cart.quantity ?? 1) > 1) {
        cartProvider.onUpdateCartQuantity(index: index, product: cart.product!, isRemove: true);
      } else {
        cartProvider.removeFromCart(index);
      }
    }

    void onIncrement() => cartProvider.onUpdateCartQuantity(
        index: index, product: cart.product!, isRemove: false);

    return Container(
      padding: EdgeInsets.fromLTRB(20 * s, 20 * s, 28 * s, 20 * s),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16 * s),
        border: Border.all(color: _kCardBorder, width: s),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12 * s),
            child: Container(
              width: 130 * s,
              height: 160 * s,
              color: _kPageBg,
              child: CustomImageWidget(
                emptyWhenMissing: true,
                placeholder: Images.placeholderImage,
                image: image,
                fit: BoxFit.cover,
              ),
            ),
          ),
          SizedBox(width: 24 * s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: loewBold.copyWith(fontSize: 20 * s, height: 1.0, color: _kInk),
                ),
                if (modifiers.isNotEmpty) ...[
                  SizedBox(height: 10 * s),
                  for (final line in modifiers)
                    Text(line,
                        style: loewRegular.copyWith(
                            fontSize: 17 * s, height: 1.45, color: _kMuted)),
                ],
                SizedBox(height: 10 * s),
                KioskTap(
                  onTap: onEdit,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 4 * s),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(5 * s),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_outlined, size: 15 * s, color: Colors.white),
                        SizedBox(width: 6 * s),
                        Text(
                          kioskTranslate(context, 'edit', 'EDIT').toUpperCase(),
                          style: loewBold.copyWith(fontSize: 16 * s, height: 1.0, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 24 * s),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              KioskLinePriceRow(cart: cart, fontSize: 20 * s, gap: 10 * s),
              SizedBox(height: 4 * s),
              Text(
                '${PriceConverterHelper.convertPrice((cart.discountedPrice ?? 0))} each',
                style: swiss721Light.copyWith(fontSize: 15 * s, height: 1.0, color: _kMuted),
              ),
              SizedBox(height: 14 * s),
              _QtyStepper(
                s: s,
                quantity: cart.quantity ?? 1,
                onDecrement: onDecrement,
                onIncrement: onIncrement,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

List<String> _modifierLines(CartModel cart) {
  if (cart.isDeal) {
    return (cart.components ?? [])
        .map((c) => c.product?.name ?? '')
        .where((n) => n.isNotEmpty)
        .toList();
  }
  final List<String> lines = [];
  final variations = cart.product?.variations ?? [];
  final selected = cart.variations ?? [];
  for (int g = 0; g < variations.length && g < selected.length; g++) {
    final values = variations[g].variationValues ?? [];
    for (int i = 0; i < values.length && i < selected[g].length; i++) {
      if (selected[g][i] ?? false) {
        lines.add('+ ${values[i].level?.trim()}');
      }
    }
  }
  for (final addOn in cart.addOnIds ?? []) {
    final match = (cart.product?.addOns ?? []).where((a) => a.id == addOn.id);
    if (match.isNotEmpty) {
      final qty = addOn.quantity ?? 1;
      lines.add('+ ${qty > 1 ? '$qty x ' : ''}${match.first.name}');
    }
  }
  final instruction = cart.instruction?.trim();
  if (instruction != null && instruction.isNotEmpty) lines.add(instruction);
  return lines;
}

class _QtyStepper extends StatelessWidget {
  final double s;
  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  const _QtyStepper({
    required this.s,
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    final bool atMinimum = quantity <= 1;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepBox(
          s: s,
          filled: false,
          onTap: onDecrement,
          child: atMinimum
              ? Icon(Icons.delete_outline, size: 18 * s, color: Colors.black)
              : Text('−', style: loewMedium.copyWith(fontSize: 24 * s, height: 1.0, color: Colors.black)),
        ),
        SizedBox(
          width: 56.7 * s,
          child: Text(
            '$quantity',
            textAlign: TextAlign.center,
            style: loewMedium.copyWith(fontSize: 24 * s, height: 1.0, color: Colors.black),
          ),
        ),
        _StepBox(
          s: s,
          filled: true,
          onTap: onIncrement,
          child: Text('+',
              style: loewMedium.copyWith(fontSize: 24 * s, height: 1.0, color: const Color(0xFFF3F3DD))),
        ),
      ],
    );
  }
}

class _StepBox extends StatelessWidget {
  final double s;
  final bool filled;
  final VoidCallback onTap;
  final Widget child;
  const _StepBox({required this.s, required this.filled, required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? Colors.black : Colors.transparent,
      borderRadius: BorderRadius.circular(4.727 * s),
      clipBehavior: Clip.antiAlias,
      child: KioskTap(
        onTap: onTap,
        child: Container(
          width: 47.27 * s,
          height: 35.06 * s,
          alignment: Alignment.center,
          decoration: filled
              ? null
              : BoxDecoration(
                  borderRadius: BorderRadius.circular(4.727 * s),
                  border: Border.all(color: Colors.black, width: (0.7 * s).clamp(0.5, 2.0)),
                ),
          child: child,
        ),
      ),
    );
  }
}

/// Figma "Summary card" — item count, order-note row, totals breakdown, PAY
/// NOW. 2305:9458 (no note) / 2305:10194 (with note, 2305:10122).
class _SummaryCard extends StatelessWidget {
  final double s;
  final List<CartModel?> cartList;
  final double couponDiscount;
  final String? couponTitle;
  final String? couponCode;
  final String note;
  final bool payEnabled;
  final VoidCallback onPay;

  const _SummaryCard({
    required this.s,
    required this.cartList,
    required this.couponDiscount,
    required this.couponTitle,
    required this.couponCode,
    required this.note,
    required this.payEnabled,
    required this.onPay,
  });

  @override
  Widget build(BuildContext context) {
    final int count = kioskCartItemCount(cartList);
    final double items = kioskItemsTotal(cartList);
    final double tax = kioskTaxTotal(cartList);
    final double total = kioskPayableTotal(cartList, couponDiscount);
    final String couponLabel = kioskCouponRowLabel(
      discountLabel: kioskTranslate(context, 'discount', 'Discount'),
      title: couponTitle,
      code: couponCode,
    );

    return Container(
      padding: EdgeInsets.all(28 * s),
      decoration: BoxDecoration(
        color: _kCardBg,
        border: Border.all(color: _kCardBorder, width: s),
        borderRadius: BorderRadius.circular(20 * s),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 24 * s, offset: Offset(0, 8 * s)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            count == 1 ? '1 item' : '$count items',
            style: swiss721Light.copyWith(fontSize: 15 * s, height: 1.0, color: _kMutedLight),
          ),
          SizedBox(height: 18 * s),
          _NoteRow(s: s, note: note),
          SizedBox(height: 18 * s),
          Container(height: s, color: _kCardBorder),
          SizedBox(height: 18 * s),
          _Row(s: s, label: kioskTranslate(context, 'items', 'ITEMS'),
              value: PriceConverterHelper.convertPrice(items)),
          if (couponDiscount > 0) ...[
            SizedBox(height: 14 * s),
            _Row(
              s: s,
              label: couponLabel,
              value: '- ${PriceConverterHelper.convertPrice(couponDiscount)}',
              color: _kCouponGreen,
            ),
          ],
          SizedBox(height: 14 * s),
          _Row(
            s: s,
            label: kioskTranslate(context, 'incl_vat', 'Incl. VAT'),
            value: PriceConverterHelper.convertPrice(tax),
            small: true,
          ),
          SizedBox(height: 18 * s),
          Container(height: s, color: _kCardBorder),
          SizedBox(height: 18 * s),
          _Row(
            s: s,
            label: kioskTranslate(context, 'total', 'Total'),
            value: PriceConverterHelper.convertPrice(total),
            bold: true,
          ),
          SizedBox(height: 18 * s),
          Opacity(
            opacity: payEnabled ? 1.0 : 0.5,
            child: Material(
              color: Colors.black,
              borderRadius: BorderRadius.circular(10 * s),
              clipBehavior: Clip.antiAlias,
              child: KioskTap(
                onTap: payEnabled ? onPay : null,
                child: Container(
                  height: 64 * s,
                  alignment: Alignment.center,
                  child: Text(
                    kioskTranslate(context, 'pay_now', 'PAY NOW').toUpperCase(),
                    style: loewBold.copyWith(fontSize: 17 * s, height: 1.0, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Add an order note" / "Order note" (with its value + EDIT) — opens the
/// SAME editor portrait uses (`openKioskOrderNote`), which writes the note
/// straight to `CartProvider`.
class _NoteRow extends StatelessWidget {
  final double s;
  final String note;
  const _NoteRow({required this.s, required this.note});

  @override
  Widget build(BuildContext context) {
    final bool hasNote = note.trim().isNotEmpty;
    return KioskTap(
      onTap: () => openKioskOrderNote(context),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  hasNote
                      ? kioskTranslate(context, 'order_note', 'Order note')
                      : kioskTranslate(context, 'add_an_order_note', 'Add an order note'),
                  style: loewBold.copyWith(fontSize: 17 * s, height: 1.0, color: const Color(0xFF231F20)),
                ),
                SizedBox(height: 6 * s),
                Text(
                  hasNote ? note.trim() : kioskTranslate(context, 'anything_we_should_know_short', 'Anything we should know?'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: loewRegular.copyWith(fontSize: 16.8 * s, height: 1.0, color: _kNoteHint),
                ),
              ],
            ),
          ),
          if (hasNote)
            Text(
              kioskTranslate(context, 'edit', 'EDIT').toUpperCase(),
              style: loewBold.copyWith(fontSize: 15 * s, height: 1.0, color: _kInk),
            )
          else
            Container(
              width: 30 * s,
              height: 30 * s,
              alignment: Alignment.center,
              child: Icon(Icons.add, size: 20 * s, color: _kInk.withValues(alpha: 0.6)),
            ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final double s;
  final String label;
  final String value;
  final bool bold;
  final bool small;
  final Color? color;
  const _Row({
    required this.s,
    required this.label,
    required this.value,
    this.bold = false,
    this.small = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final double fontSize = bold ? 22 * s : (small ? 14 * s : 16 * s);
    final Color fg = color ?? (small ? _kMutedLight : _kInk);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: (bold ? loewBold : loewRegular).copyWith(fontSize: fontSize, height: 1.0, color: fg),
          ),
        ),
        SizedBox(width: 8 * s),
        Text(value,
            style: (bold ? loewBold : swiss721Light).copyWith(fontSize: fontSize, height: 1.0, color: fg)),
      ],
    );
  }
}
