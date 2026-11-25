import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/widgets/custom_image_widget.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_tap.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_ui.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_remove_item_dialog.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_allergen.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_product_image_helper.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_session.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_translate.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_deal_detail_screen.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/helper/price_converter_helper.dart';
import 'package:acafe_customer/theme/text_legibility.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:provider/provider.dart';

const Color kOrderCardBg = Color(0xFFFBF8EF);
const Color kOrderCardBorder = Color(0xFFB9B5A6);
const Color kOrderPriceColor = Color(0xFF231F20);
const Color kOrderPlusText = Color(0xFFF3F3DD);

/// The list price a discount struck out (Figma POS node 1385:15938, the
/// "price-row" group).
const Color kOrderWasPriceColor = Color(0xFF888480);

/// Figma's cart thumbnail is a 473×660 portrait crop. That crop is what makes
/// a line card a third of a 16:9 viewport tall, so wide layouts pass 1.0 and
/// get a square instead — the same trade the product grid already makes.
/// Card size relative to the Figma artboard (user asked for smaller cards).
const double kOrderCardScale = 0.74;

const double kOrderLineImageAspect = 467 / 700;

/// One cart line: product image, name, price, modifier lines and a qty stepper.
/// Tapping the card opens the edit sheet; the stepper updates the cart live.
///
/// When [compact] is true (wide layouts), uses fixed ~120px card height with an
/// 88px square thumbnail and [KioskQtyStepper]. Otherwise uses scaled Figma px.
class KioskOrderLineCard extends StatelessWidget {
  final double? s;
  final CartModel cart;
  final int index;
  final bool compact;

  /// Width ÷ height of the thumbnail. Defaults to the Figma portrait crop;
  /// see [kOrderLineImageAspect].
  final double imageAspect;

  const KioskOrderLineCard({
    super.key,
    this.s,
    required this.cart,
    required this.index,
    this.compact = false,
    this.imageAspect = kOrderLineImageAspect,
  }) : assert(compact || s != null, 'scaled layout requires s');

  @override
  Widget build(BuildContext context) {
    if (compact) return _CompactLineCard(cart: cart, index: index);
    return _ScaledLineCard(
        s: s!, cart: cart, index: index, imageAspect: imageAspect);
  }
}

class _CompactLineCard extends StatelessWidget {
  final CartModel cart;
  final int index;
  const _CompactLineCard({required this.cart, required this.index});

  @override
  Widget build(BuildContext context) {
    final splash = Provider.of<SplashProvider>(context, listen: false);
    final bool showImages = context.watch<KioskAuthProvider>().showImages;
    final modifiers = _modifierLines(cart);

    return Material(
      color: kOrderCardBg,
      borderRadius: BorderRadius.circular(KioskUI.radius),
      clipBehavior: Clip.antiAlias,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(KioskUI.radius),
          border: Border.all(color: kOrderCardBorder),
        ),
        padding: const EdgeInsets.all(16),
        // Stepper is a sibling of the edit tap — not nested inside it — so a
        // card-body tap never competes with "+" in the gesture arena.
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: KioskTap(
                onTap: () =>
                    openKioskCartLine(context, cart, cartIndex: index),
                child: Row(
                  children: [
                    if (showImages) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 88,
                          height: 88,
                          child: CustomImageWidget(
                            emptyWhenMissing: true,
                            placeholder: Images.placeholderImage,
                            image: KioskProductImageHelper.cartLineImageUrl(
                              cart: cart,
                              productImageBaseUrl:
                                  splash.baseUrls?.productImageUrl,
                              dealImageBaseUrl: splash.baseUrls?.dealImageUrl,
                            ),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            cart.isDeal
                                ? (cart.dealTitle ?? cart.product?.name ?? '')
                                : (cart.product?.name ?? ''),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: loewExtraBold.copyWith(
                              fontSize: KioskUI.body,
                              height: 1.1,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          KioskLinePriceRow(
                            cart: cart,
                            fontSize: KioskUI.body,
                            gap: 8,
                          ),
                          if (modifiers.isNotEmpty)
                            Text(
                              modifiers.first,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: loewRegular.copyWith(
                                fontSize: KioskUI.caption,
                                color: TextTones.secondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            KioskQtyStepper(
              quantity: cart.quantity ?? 1,
              buttonSize: 44,
              onDecrement: () {
                final cartProvider =
                    Provider.of<CartProvider>(context, listen: false);
                if ((cart.quantity ?? 1) > 1) {
                  cartProvider.onUpdateCartQuantity(
                      index: index, product: cart.product!, isRemove: true);
                } else {
                  _confirmRemove(context, cart, index);
                }
              },
              onIncrement: () =>
                  Provider.of<CartProvider>(context, listen: false)
                      .onUpdateCartQuantity(
                          index: index,
                          product: cart.product!,
                          isRemove: false),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScaledLineCard extends StatelessWidget {
  final double s;
  final CartModel cart;
  final int index;
  final double imageAspect;
  const _ScaledLineCard(
      {required this.s,
      required this.cart,
      required this.index,
      required this.imageAspect});

  @override
  Widget build(BuildContext context) {
    final splash = Provider.of<SplashProvider>(context, listen: false);
    final bool showImages = context.watch<KioskAuthProvider>().showImages;
    final modifiers = _modifierLines(cart);
    final Set<KioskAllergen> allergens =
        cart.product == null ? const {} : kioskProductAllergens(cart.product!);

    void onEdit() => openKioskCartLine(context, cart, cartIndex: index);

    // Whole card drawn at 80% of the Figma artboard — full size read as
    // oversized on the kiosk.
    final double s = this.s * kOrderCardScale;

    // Figma 2305:16932 — 729-tall card, 1px #B9B5A6 rule, radius 30. The
    // product photo nearly fills the card's height (467×700, inset 75/14);
    // the text column is TOP-aligned on the name (87 down), EDIT sits on the
    // name's line at the right, and the stepper is centred vertically.
    final double minHeight = showImages ? 729 * s : 0;
    // Room the right-hand controls need, so long names ellipsize before
    // running under the stepper: 70 inset + 150 box + 180 qty + 150 box.
    final double controlsReserve = 70 * s + 480 * s + 40 * s;

    return Material(
      color: kOrderCardBg,
      borderRadius: BorderRadius.circular(30 * s),
      clipBehavior: Clip.antiAlias,
      child: Container(
        constraints: BoxConstraints(minHeight: minHeight),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30 * s),
          border: Border.all(color: kOrderCardBorder, width: 1),
        ),
        // Stepper/EDIT are positioned siblings of the edit tap — not nested
        // inside it — so a card-body tap never competes with "+"/EDIT in the
        // gesture arena.
        child: Stack(
          children: [
            KioskTap(
              onTap: onEdit,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showImages) ...[
                    Padding(
                      padding: EdgeInsets.only(left: 75 * s, top: 14 * s),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(33 * s),
                        child: SizedBox(
                          width: 467 * s,
                          height: (467 * s) / imageAspect,
                          child: CustomImageWidget(
                            emptyWhenMissing: true,
                            placeholder: Images.placeholderImage,
                            image: KioskProductImageHelper.cartLineImageUrl(
                              cart: cart,
                              productImageBaseUrl:
                                  splash.baseUrls?.productImageUrl,
                              dealImageBaseUrl: splash.baseUrls?.dealImageUrl,
                            ),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 50 * s),
                  ],
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: showImages ? 0 : 75 * s,
                        top: 87 * s,
                        bottom: 60 * s,
                        right: controlsReserve,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  cart.isDeal
                                      ? (cart.dealTitle ??
                                          cart.product?.name ??
                                          '')
                                      : (cart.product?.name ?? ''),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: loewExtraBold.copyWith(
                                      fontSize: 72 * s,
                                      height: 1,
                                      color: kOrderPriceColor),
                                ),
                              ),
                              if (allergens.isNotEmpty) ...[
                                SizedBox(width: 28 * s),
                                _CartAllergenBadges(s: s, allergens: allergens),
                              ],
                            ],
                          ),
                          SizedBox(height: 45 * s),
                          KioskLinePriceRow(
                            cart: cart,
                            fontSize: 96 * s,
                            gap: 24 * s,
                          ),
                          SizedBox(height: 49 * s),
                          for (final line in modifiers)
                            Padding(
                              padding: EdgeInsets.only(bottom: 22 * s),
                              child: Text(line,
                                  style: loewRegular.copyWith(
                                      fontSize: 64 * s,
                                      height: 1,
                                      color: Colors.black)),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 87 * s - 9 * s,
              right: 58 * s,
              child: _CartEditButton(s: s, onTap: onEdit),
            ),
            Positioned(
              top: 0,
              bottom: 0,
              right: 70 * s,
              child: Center(
                child: _QtyStepper(
                  s: s,
                  quantity: cart.quantity ?? 1,
                  onDecrement: () {
                    final cartProvider =
                        Provider.of<CartProvider>(context, listen: false);
                    if ((cart.quantity ?? 1) > 1) {
                      cartProvider.onUpdateCartQuantity(
                          index: index,
                          product: cart.product!,
                          isRemove: true);
                    } else {
                      _confirmRemove(context, cart, index);
                    }
                  },
                  onIncrement: () =>
                      Provider.of<CartProvider>(context, listen: false)
                          .onUpdateCartQuantity(
                              index: index,
                              product: cart.product!,
                              isRemove: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "EDIT" affordance (pencil + label) in the top-right of a cart line card —
/// Figma 2305:15712. Calls the same [openKioskCartLine] the card body's own
/// tap already uses; this is just an explicit, discoverable target for it.
class _CartEditButton extends StatelessWidget {
  final double s;
  final VoidCallback onTap;
  const _CartEditButton({required this.s, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return KioskTap(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.edit_outlined, size: 48 * s, color: Colors.black),
          SizedBox(width: 12 * s),
          Text(
            kioskTranslate(context, 'edit', 'EDIT').toUpperCase(),
            style: loewBold.copyWith(
                fontSize: 52 * s, height: 1, color: Colors.black),
          ),
        ],
      ),
    );
  }
}

/// Allergen glyphs on a cart line — rounded-square swatches (Figma
/// 2305:15696 "allergen-icon/wheat", 2305:15720 "allergen-icon/dairy"),
/// distinct from the circular discs [KioskAllergenNotice] draws on the
/// customize screen. Driven by the same [KioskAllergen] set as every other
/// allergen surface — no separate mapping to keep in sync.
class _CartAllergenBadges extends StatelessWidget {
  final double s;
  final Set<KioskAllergen> allergens;
  const _CartAllergenBadges({required this.s, required this.allergens});

  List<KioskAllergen> get _ordered =>
      KioskAllergen.values.where(allergens.contains).toList();

  @override
  Widget build(BuildContext context) {
    final double size = 56 * s;
    final double glyph = 32 * s;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final allergen in _ordered)
          Padding(
            padding: EdgeInsets.only(left: 8 * s),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: allergen.swatch,
                borderRadius: BorderRadius.circular(28 * s),
              ),
              alignment: Alignment.center,
              child: SvgPicture.asset(allergen.icon, width: glyph, height: glyph),
            ),
          ),
      ],
    );
  }
}

/// A cart line's price: what it used to cost, struck through, beside what the
/// customer actually pays — Figma POS node 1385:15938 ("price-row").
///
/// Renders a single price when the line is not discounted, and the word FREE in
/// place of "€0.00" when a discount clears the line completely, which is how the
/// design shows a coupon's free product.
///
/// The struck price is the product's own list price ([kioskLineOriginalTotal]);
/// a cart-level coupon is not spread across the lines, because nothing in the
/// order links a coupon to a particular product — it gets its own labelled row
/// in the summary instead.
class KioskLinePriceRow extends StatelessWidget {
  final CartModel cart;
  final double fontSize;

  /// Space between the struck price and the payable one (24 design px).
  final double gap;

  const KioskLinePriceRow({
    super.key,
    required this.cart,
    required this.fontSize,
    required this.gap,
  });

  @override
  Widget build(BuildContext context) {
    final double payable = kioskLineTotal(cart);
    final double original = kioskLineOriginalTotal(cart);
    // Currency rounding: a difference smaller than half a cent is not a
    // discount, it is float noise, and striking a price to show the same
    // number twice would just look broken.
    final bool discounted = original - payable > 0.005;

    final TextStyle base = swiss721Light.copyWith(
      fontSize: fontSize,
      height: 1,
      color: kOrderPriceColor,
    );

    final Widget payableText = payable <= 0.005
        ? Text(
            kioskTranslate(context, 'coupon_free_reward', 'Free').toUpperCase(),
            style: base.copyWith(color: Colors.black),
          )
        : Text(PriceConverterHelper.convertPrice(payable), style: base);

    if (!discounted) return payableText;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            PriceConverterHelper.convertPrice(original),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: base.copyWith(
              color: kOrderWasPriceColor,
              decoration: TextDecoration.lineThrough,
              decorationColor: kOrderWasPriceColor,
              decorationThickness: 2,
            ),
          ),
        ),
        SizedBox(width: gap),
        Flexible(child: payableText),
      ],
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
  if (instruction != null && instruction.isNotEmpty) {
    lines.add(instruction);
  }
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
    // qty == 1: the only way down is removing the line, so the left control
    // shows a trash can instead of a minus that would do the same thing.
    final bool atMinimum = quantity <= 1;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepBox(
          s: s,
          label: atMinimum ? null : '−',
          // Figma 2305:16967: a bare filled bin, no box, at qty 1.
          icon: atMinimum ? Icons.delete : null,
          bare: atMinimum,
          filled: false,
          onTap: onDecrement,
        ),
        // Figma 2305:16936: the count sits centred in a 180-wide slot.
        SizedBox(
          width: 180 * s,
          child: Text('$quantity',
              textAlign: TextAlign.center,
              style: loewExtraBold.copyWith(
                  fontSize: 96 * s, height: 1, color: Colors.black)),
        ),
        _StepBox(s: s, label: '+', filled: true, onTap: onIncrement),
      ],
    );
  }
}

class _StepBox extends StatelessWidget {
  final double s;
  final String? label;
  final IconData? icon;
  final bool filled;
  final bool bare;
  final VoidCallback onTap;
  const _StepBox(
      {required this.s,
      this.label,
      this.icon,
      this.bare = false,
      required this.filled,
      required this.onTap})
      : assert(label != null || icon != null, 'need a label or an icon');

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? Colors.black : Colors.transparent,
      borderRadius: BorderRadius.circular(15 * s),
      clipBehavior: Clip.antiAlias,
      child: KioskTap(
        onTap: onTap,
        child: Container(
          width: 150 * s,
          height: 111 * s,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15 * s),
            border: bare
                ? null
                : Border.all(
                    color: Colors.black, width: (2.25 * s).clamp(1.5, 4.0)),
          ),
          child: icon != null
              ? Icon(icon,
                  size: (bare ? 80 : 60) * s,
                  color: filled ? kOrderPlusText : Colors.black)
              : Text(
                  label!,
                  style: loewExtraBold.copyWith(
                      fontSize: 96 * s,
                      height: 1,
                      color: filled ? kOrderPlusText : Colors.black),
                ),
        ),
      ),
    );
  }
}

/// Asks before deleting the line; removes it only on REMOVE.
Future<void> _confirmRemove(
    BuildContext context, CartModel cart, int index) async {
  final cartProvider = Provider.of<CartProvider>(context, listen: false);
  final splash = Provider.of<SplashProvider>(context, listen: false);
  final bool showImages = context.read<KioskAuthProvider>().showImages;
  final String name = cart.isDeal
      ? (cart.dealTitle ?? cart.product?.name ?? '')
      : (cart.product?.name ?? '');
  final bool confirmed = await showKioskRemoveItemDialog(
    context,
    productName: name,
    imageUrl: showImages
        ? KioskProductImageHelper.cartLineImageUrl(
            cart: cart,
            productImageBaseUrl: splash.baseUrls?.productImageUrl,
            dealImageBaseUrl: splash.baseUrls?.dealImageUrl,
          )
        : null,
  );
  if (!confirmed) return;
  // Guard: the line may have shifted while the dialog was open.
  if (index < cartProvider.cartList.length &&
      identical(cartProvider.cartList[index], cart)) {
    cartProvider.removeFromCart(index);
  }
}
