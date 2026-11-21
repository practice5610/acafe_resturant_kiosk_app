import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/widgets/custom_image_widget.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_product_image_helper.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_translate.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_deal_detail_screen.dart'
    show openKioskCartLine;
import 'package:acafe_customer/features/kiosk/screens/kiosk_order_line_card.dart'
    show KioskLinePriceRow;
import 'package:acafe_customer/features/kiosk/widgets/kiosk_tap.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';

const Color _kCardBg = Color(0xFFF7F1DE);
const Color _kModifierText = Color(0xFF73736E);
const Color _kInk = Color(0xFF0D0D0D);
const Color _kPlusText = Color(0xFFF3F3DD);

/// Trash icon asset for the qty==1 stepper state — Figma node 2305:4096 /
/// 2305:4332 (both just placements of the same vector), downloaded locally.
/// Not reused from `kiosk_order_line_card.dart`'s non-compact stepper (which
/// uses `Icons.delete_outline`): this screen matches the Figma asset exactly.
const String _kTrashSvg = 'assets/svg/landscape_cart_trash.svg';

/// Landscape (Option B) cart line card — Figma B-02/B-03
/// (`2305:4065`/`2305:4082`/`2305:4301`/`2305:4318`). A standalone widget
/// rather than a new mode of the shared `KioskOrderLineCard`: that widget's
/// `compact` path is also used by POS (`pos_payment_selection_screen.dart`,
/// `pos_top_nav_bar.dart`) and portrait's customize sheet, so matching this
/// Figma card's exact look here (bg, radius, image crop, EDIT row, the
/// trash-at-qty-1 stepper) would have changed how those render too.
///
/// Price math, "+ modifier" lines and the add/remove cart calls are the
/// SAME logic `kiosk_order_line_card.dart` already uses — reused directly
/// (`KioskLinePriceRow`, `CartProvider.onUpdateCartQuantity`/`removeFromCart`)
/// or mirrored where the source is private to that file (`_lineModifiers`
/// below mirrors `_modifierLines` 1:1; nothing about the rule changed).
///
/// No "- removed ingredient" line: `AddOns.isDefault`'s own doc comment says
/// a default "comes with the product... the customer cannot turn it off", so
/// there is no cart state that means "a default was removed" to render.
class LandscapeOrderLineCard extends StatelessWidget {
  final CartModel cart;
  final int index;
  final double s;
  final bool highlighted;

  const LandscapeOrderLineCard({
    super.key,
    required this.cart,
    required this.index,
    required this.s,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final splash = Provider.of<SplashProvider>(context, listen: false);
    final List<String> modifiers = _lineModifiers(cart);
    final String name =
        cart.isDeal ? (cart.dealTitle ?? cart.product?.name ?? '') : (cart.product?.name ?? '');
    final String image = KioskProductImageHelper.cartLineImageUrl(
      cart: cart,
      productImageBaseUrl: splash.baseUrls?.productImageUrl,
      dealImageBaseUrl: splash.baseUrls?.dealImageUrl,
    );

    void onEdit() => openKioskCartLine(context, cart, cartIndex: index);

    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    void onDecrement() {
      if ((cart.quantity ?? 1) > 1) {
        cartProvider.onUpdateCartQuantity(
            index: index, product: cart.product!, isRemove: true);
      } else {
        cartProvider.removeFromCart(index);
      }
    }

    void onIncrement() => cartProvider.onUpdateCartQuantity(
        index: index, product: cart.product!, isRemove: false);

    // Highlight border sits INSIDE the 294 content width — the card itself
    // does not get wider, so its own padding/gap shrink by the border width
    // rather than the border being drawn as an extra layer around a
    // fixed-size card.
    final double borderWidth = highlighted ? 3 * s : 0;

    return Container(
      padding: EdgeInsets.all(borderWidth),
      decoration: highlighted
          ? BoxDecoration(
              color: const Color(0xFFEDF5E8),
              borderRadius: BorderRadius.circular(12 * s),
              border: Border.all(color: const Color(0xFF2E7D33), width: borderWidth),
            )
          : null,
      child: Container(
        decoration: BoxDecoration(
          color: highlighted ? Colors.transparent : _kCardBg,
          borderRadius: BorderRadius.circular(12 * s),
        ),
        padding: EdgeInsets.all(12 * s),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(5.386 * s),
              child: CustomImageWidget(
                placeholder: Images.placeholderImage,
                image: image,
                width: 78.676 * s,
                height: 118 * s,
                fit: BoxFit.cover,
              ),
            ),
            SizedBox(width: 12 * s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: loewBold.copyWith(fontSize: 16 * s, height: 1.2, color: _kInk),
                  ),
                  SizedBox(height: 4 * s),
                  KioskLinePriceRow(cart: cart, fontSize: 16 * s, gap: 8 * s),
                  for (final line in modifiers) ...[
                    SizedBox(height: 4 * s),
                    Text(
                      line,
                      style: loewRegular.copyWith(fontSize: 13 * s, color: _kModifierText),
                    ),
                  ],
                  SizedBox(height: 10 * s),
                  Row(
                    children: [
                      KioskTap(
                        onTap: onEdit,
                        child: Text(
                          // Reuses the SAME key portrait's cart line already
                          // uses (kiosk_order_line_card.dart's _CartEditButton),
                          // which already has real translations in all 8 files.
                          kioskTranslate(context, 'edit', 'EDIT').toUpperCase(),
                          style: loewBold.copyWith(
                              fontSize: 13 * s,
                              color: _kInk,
                              decoration: TextDecoration.underline),
                        ),
                      ),
                      const Spacer(),
                      _LandscapeQtyStepper(
                        s: s,
                        quantity: cart.quantity ?? 1,
                        onDecrement: onDecrement,
                        onIncrement: onIncrement,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mirrors `kiosk_order_line_card.dart`'s private `_modifierLines` exactly —
/// same "+ value" rule for variations, add-ons (with an "N x " prefix above
/// qty 1) and the free-text instruction line. Duplicated rather than
/// imported because the source is a private top-level function in a file
/// this task must not edit.
List<String> _lineModifiers(CartModel cart) {
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

/// Figma B-02 stepper: qty>=2 is outlined "-"/filled "+" (~119.8 wide); qty==1
/// replaces "-" with the trash vector (~104 wide). Deliberately not
/// `KioskQtyStepper` (shared with POS/portrait) — this is sized and iconed
/// to this Figma spec only.
class _LandscapeQtyStepper extends StatelessWidget {
  final double s;
  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  const _LandscapeQtyStepper({
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
          width: atMinimum ? null : 37.489,
          filled: false,
          onTap: onDecrement,
          child: atMinimum
              ? SvgPicture.asset(_kTrashSvg, width: 12.195 * s, height: 18.78 * s)
              : Text('−',
                  style: loewMedium.copyWith(fontSize: 18 * s, height: 1.0, color: Colors.black)),
        ),
        SizedBox(
          width: 44.986 * s,
          child: Text(
            '$quantity',
            textAlign: TextAlign.center,
            style: loewMedium.copyWith(fontSize: 18 * s, height: 1.0, color: Colors.black),
          ),
        ),
        _StepBox(
          s: s,
          width: atMinimum ? 36.585 : 37.489,
          filled: true,
          onTap: onIncrement,
          child: Text('+',
              style: loewMedium.copyWith(fontSize: 18 * s, height: 1.0, color: _kPlusText)),
        ),
      ],
    );
  }
}

class _StepBox extends StatelessWidget {
  final double s;
  final double? width;
  final bool filled;
  final VoidCallback onTap;
  final Widget child;
  const _StepBox({
    required this.s,
    required this.width,
    required this.filled,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? Colors.black : Colors.transparent,
      borderRadius: BorderRadius.circular(3.749 * s),
      clipBehavior: Clip.antiAlias,
      child: KioskTap(
        onTap: onTap,
        child: Container(
          width: (width ?? 37.489) * s,
          height: 27.805 * s,
          alignment: Alignment.center,
          decoration: filled
              ? null
              : BoxDecoration(
                  borderRadius: BorderRadius.circular(3.749 * s),
                  border: Border.all(color: Colors.black, width: (0.562 * s).clamp(0.5, 2.0)),
                ),
          child: child,
        ),
      ),
    );
  }
}
