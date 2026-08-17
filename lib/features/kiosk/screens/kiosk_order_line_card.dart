import 'package:flutter/material.dart';
import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/widgets/custom_image_widget.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_tap.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_ui.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_product_image_helper.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_session.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_product_customize_sheet.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/helper/price_converter_helper.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:provider/provider.dart';

const Color kOrderCardBg = Color(0xFFFBF8EF);
const Color kOrderCardBorder = Color(0xFFB9B5A6);
const Color kOrderPriceColor = Color(0xFF231F20);
const Color kOrderPlusText = Color(0xFFF3F3DD);

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

  const KioskOrderLineCard({
    super.key,
    this.s,
    required this.cart,
    required this.index,
    this.compact = false,
  }) : assert(compact || s != null, 'scaled layout requires s');

  @override
  Widget build(BuildContext context) {
    if (compact) return _CompactLineCard(cart: cart, index: index);
    return _ScaledLineCard(s: s!, cart: cart, index: index);
  }
}

class _CompactLineCard extends StatelessWidget {
  final CartModel cart;
  final int index;
  const _CompactLineCard({required this.cart, required this.index});

  @override
  Widget build(BuildContext context) {
    final splash = Provider.of<SplashProvider>(context, listen: false);
    final modifiers = _modifierLines(cart);

    return Material(
      color: kOrderCardBg,
      borderRadius: BorderRadius.circular(KioskUI.radius),
      clipBehavior: Clip.antiAlias,
      child: KioskTap(
        onTap: () => openKioskCustomize(context, cart.product!,
            cart: cart, cartIndex: index),
        child: Container(
          height: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(KioskUI.radius),
            border: Border.all(color: kOrderCardBorder),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 88,
                  height: 88,
                  child: CustomImageWidget(
                    placeholder: Images.placeholderImage,
                    image: KioskProductImageHelper.cartLineImageUrl(
                      cart: cart,
                      productImageBaseUrl: splash.baseUrls?.productImageUrl,
                    ),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      cart.product?.name ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: loewExtraBold.copyWith(
                        fontSize: KioskUI.body,
                        height: 1.1,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      PriceConverterHelper.convertPrice(kioskLineTotal(cart)),
                      style: swiss721Light.copyWith(
                        fontSize: KioskUI.body,
                        color: kOrderPriceColor,
                      ),
                    ),
                    if (modifiers.isNotEmpty)
                      Text(
                        modifiers.first,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: loewRegular.copyWith(
                          fontSize: KioskUI.caption,
                          color: Colors.black54,
                        ),
                      ),
                  ],
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
                    cartProvider.removeFromCart(index);
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
      ),
    );
  }
}

class _ScaledLineCard extends StatelessWidget {
  final double s;
  final CartModel cart;
  final int index;
  const _ScaledLineCard(
      {required this.s, required this.cart, required this.index});

  @override
  Widget build(BuildContext context) {
    final splash = Provider.of<SplashProvider>(context, listen: false);
    final modifiers = _modifierLines(cart);

    return Material(
      color: kOrderCardBg,
      borderRadius: BorderRadius.circular(30 * s),
      clipBehavior: Clip.antiAlias,
      child: KioskTap(
        onTap: () => openKioskCustomize(context, cart.product!,
            cart: cart, cartIndex: index),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30 * s),
            border: Border.all(
                color: kOrderCardBorder, width: (1.5 * s).clamp(1.0, 3.0)),
          ),
          padding: EdgeInsets.all(30 * s),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(33 * s),
                child: SizedBox(
                  width: 473 * s,
                  height: 660 * s,
                  child: CustomImageWidget(
                    placeholder: Images.placeholderImage,
                    image: KioskProductImageHelper.cartLineImageUrl(
                      cart: cart,
                      productImageBaseUrl: splash.baseUrls?.productImageUrl,
                    ),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              SizedBox(width: 50 * s),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      cart.product?.name ?? '',
                      style: loewExtraBold.copyWith(
                          fontSize: 72 * s, height: 1.05, color: Colors.black),
                    ),
                    SizedBox(height: 16 * s),
                    Text(
                      PriceConverterHelper.convertPrice(kioskLineTotal(cart)),
                      style: swiss721Light.copyWith(
                          fontSize: 90 * s, height: 1, color: kOrderPriceColor),
                    ),
                    SizedBox(height: 24 * s),
                    for (final line in modifiers)
                      Padding(
                        padding: EdgeInsets.only(bottom: 14 * s),
                        child: Text(line,
                            style: loewRegular.copyWith(
                                fontSize: 64 * s,
                                height: 1.1,
                                color: Colors.black)),
                      ),
                  ],
                ),
              ),
              SizedBox(width: 30 * s),
              _QtyStepper(
                s: s,
                quantity: cart.quantity ?? 1,
                onDecrement: () {
                  final cartProvider =
                      Provider.of<CartProvider>(context, listen: false);
                  if ((cart.quantity ?? 1) > 1) {
                    cartProvider.onUpdateCartQuantity(
                        index: index, product: cart.product!, isRemove: true);
                  } else {
                    cartProvider.removeFromCart(index);
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
      ),
    );
  }
}

List<String> _modifierLines(CartModel cart) {
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepBox(s: s, label: '−', filled: false, onTap: onDecrement),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 30 * s),
          child: Text('$quantity',
              style: loewExtraBold.copyWith(
                  fontSize: 90 * s, color: Colors.black)),
        ),
        _StepBox(s: s, label: '+', filled: true, onTap: onIncrement),
      ],
    );
  }
}

class _StepBox extends StatelessWidget {
  final double s;
  final String label;
  final bool filled;
  final VoidCallback onTap;
  const _StepBox(
      {required this.s,
      required this.label,
      required this.filled,
      required this.onTap});

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
          height: 114 * s,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15 * s),
            border: Border.all(
                color: Colors.black, width: (2.25 * s).clamp(1.5, 4.0)),
          ),
          child: Text(
            label,
            style: loewExtraBold.copyWith(
                fontSize: 90 * s,
                height: 1,
                color: filled ? kOrderPlusText : Colors.black),
          ),
        ),
      ),
    );
  }
}
