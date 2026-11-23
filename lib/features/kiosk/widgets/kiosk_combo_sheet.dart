import 'package:flutter/material.dart';
import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/common/responsive/kiosk_layout.dart';
import 'package:acafe_customer/common/widgets/custom_image_widget.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_cart_totals.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_combo_match.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_order_composition.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_product_image_helper.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_translate.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_scrim.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_tap.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_ui.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/helper/price_converter_helper.dart';
import 'package:acafe_customer/theme/text_legibility.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:provider/provider.dart';

// ===========================================================================
// KIOSK — "MAKE IT A COMBO MEAL?" (Figma 05a, node 2305:6821)
// ===========================================================================
// Modal card, not a route. Same showGeneralDialog + KioskScrim shell as the
// drink/food upsell. Offers a one-tap upgrade when the cart already covers
// an active deal: YES swaps those (already-customized) lines into a combo
// at bundle price; NO leaves the cart alone.
// ===========================================================================

// Figma 05a (node 2305:6821), "TABLET Final Designs (option B)".
const Color _kModalBg = Color(0xFFFBF8EF);
const Color _kModalBorder = Color(0xFFB9B5A6);
const Color _kSelectedBg = Color(0xFFFAF9F7);
const Color _kSelectedBorder = Color(0xFF0D0D0D);
const Color _kUnselectedBg = Color(0xFFFBF8EF);
const Color _kUnselectedBorder = Color(0xFFE2D9C8);

/// Resolved photo URLs for the "Yes, combo me!" composite — drink layered
/// with the side dish. Either may be empty (missing image / unclassifiable
/// product); the card simply omits what it does not have.
class _ComboImages {
  final String drink;
  final String food;
  const _ComboImages({required this.drink, required this.food});
}

/// Opens the combo upgrade and resolves to true when the customer accepted,
/// false when they declined or dismissed.
Future<bool> openKioskComboSheet(
  BuildContext context, {
  required KioskComboMatch match,
}) async {
  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Make it a combo meal',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (context, animation, secondaryAnimation) =>
        _KioskComboSheet(match: match),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved =
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
  return result ?? false;
}

enum _ComboChoice { yes, no }

class _KioskComboSheet extends StatefulWidget {
  final KioskComboMatch match;
  const _KioskComboSheet({required this.match});

  @override
  State<_KioskComboSheet> createState() => _KioskComboSheetState();
}

class _KioskComboSheetState extends State<_KioskComboSheet> {
  _ComboChoice? _choice;

  void _confirm() {
    if (_choice == null) return;
    if (_choice == _ComboChoice.yes) {
      Provider.of<CartProvider>(context, listen: false).applyComboUpgrade(
        consume: widget.match.consumeByIndex,
        dealLine: widget.match.dealLine,
      );
      Navigator.of(context).pop(true);
      return;
    }
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          KioskScrim(
            animation:
                ModalRoute.of(context)?.animation ?? kAlwaysCompleteAnimation,
            onDismiss: () => Navigator.of(context).pop(false),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double s = KioskLayout.scaleOf(context, constraints);
                final m = _ComboMetrics.forSize(
                  constraints.maxWidth,
                  constraints.maxHeight,
                );
                final _ComboImages images = _comboImages(context);
                return Center(
                  child: SingleChildScrollView(
                    // The scroll view spans the whole screen; by default it
                    // would swallow taps beside the card, so the scrim under
                    // it could never close the modal.
                    hitTestBehavior: HitTestBehavior.deferToChild,
                    padding: EdgeInsets.symmetric(vertical: 24 * s),
                    child: GestureDetector(
                      onTap: () {},
                      child: Container(
                        width: m.sheetWidth,
                        constraints: BoxConstraints(
                          maxHeight: constraints.maxHeight * 0.86,
                        ),
                        padding: EdgeInsets.all(m.pad),
                        decoration: BoxDecoration(
                          color: _kModalBg,
                          borderRadius: BorderRadius.circular(m.modalRadius),
                          border: Border.all(
                              color: _kModalBorder, width: m.modalBorderWidth),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: (60 * s).clamp(24.0, 60.0),
                              offset: Offset(0, (18 * s).clamp(8.0, 18.0)),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _Header(
                                s: s,
                                backSize: m.backSize,
                                titleSize: m.titleSize),
                            SizedBox(height: m.optionTopGap),
                            Row(
                              children: [
                                Expanded(
                                  child: _OptionCard(
                                    key: const ValueKey('kiosk-combo-yes'),
                                    metrics: m,
                                    selected: _choice == _ComboChoice.yes,
                                    imageUrl: images.drink,
                                    foodImageUrl: images.food,
                                    label: kioskTranslate(
                                      context,
                                      'yes_combo_me',
                                      'Yes, combo me!',
                                    ).toUpperCase(),
                                    caption: _yesCaption(context),
                                    onTap: () => setState(
                                        () => _choice = _ComboChoice.yes),
                                  ),
                                ),
                                SizedBox(width: m.gap),
                                Expanded(
                                  child: _OptionCard(
                                    key: const ValueKey('kiosk-combo-no'),
                                    metrics: m,
                                    selected: _choice == _ComboChoice.no,
                                    imageUrl: _noImage(context),
                                    label: kioskTranslate(
                                      context,
                                      'no_just_my_order',
                                      'No, just my order',
                                    ).toUpperCase(),
                                    onTap: () => setState(
                                        () => _choice = _ComboChoice.no),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: m.nextTopGap),
                            _NextBar(
                              metrics: m,
                              enabled: _choice != null,
                              onTap: _confirm,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Drink + food images for the "Yes, combo me!" composite.
  ///
  /// Pulled from the already-built [KioskComboMatch.dealLine] components —
  /// the same lines the (untouched) matching logic assembled — and sorted
  /// into drink/food by [KioskCourse.of], the same classifier the upsell
  /// sheet uses. Purely presentational: it never changes what gets added to
  /// the cart, only which two photos sit in the composite.
  _ComboImages _comboImages(BuildContext context) {
    final splash = Provider.of<SplashProvider>(context, listen: false);
    String drink = '';
    String food = '';
    for (final CartModel component
        in widget.match.dealLine.components ?? const <CartModel>[]) {
      final Product? product = component.product;
      if (product == null) continue;
      final String url = KioskProductImageHelper.heroImageUrl(
        product: product,
        productImageBaseUrl: splash.baseUrls?.productImageUrl,
      );
      if (KioskCourse.of(product) == KioskCourse.drink) {
        if (drink.isEmpty) drink = url;
      } else {
        if (food.isEmpty) food = url;
      }
    }
    // Defensive fallback: if neither slot could be classified (e.g. test
    // fixtures with no variations), fall back to the deal's own bundle image
    // for the drink slot rather than showing nothing at all.
    if (drink.isEmpty && food.isEmpty) {
      drink = KioskProductImageHelper.resolveUrl(
        productImageBaseUrl:
            splash.baseUrls?.dealImageUrl ?? splash.baseUrls?.productImageUrl,
        filename: widget.match.deal.image,
      );
    }
    return _ComboImages(drink: drink, food: food);
  }

  String _noImage(BuildContext context) {
    final splash = Provider.of<SplashProvider>(context, listen: false);
    final List<CartModel?> cart =
        Provider.of<CartProvider>(context, listen: false).cartList;
    if (widget.match.consume.isEmpty) return '';
    Product? drinkProduct;
    Product? firstProduct;
    for (final KioskComboConsume consumed in widget.match.consume) {
      final int index = consumed.cartIndex;
      if (index < 0 || index >= cart.length) continue;
      final Product? product = cart[index]?.product;
      if (product == null) continue;
      firstProduct ??= product;
      if (drinkProduct == null &&
          KioskCourse.of(product) == KioskCourse.drink) {
        drinkProduct = product;
      }
    }
    final Product? chosen = drinkProduct ?? firstProduct;
    if (chosen == null) return '';
    return KioskProductImageHelper.heroImageUrl(
      product: chosen,
      productImageBaseUrl: splash.baseUrls?.productImageUrl,
    );
  }

  String _yesCaption(BuildContext context) {
    final String price = PriceConverterHelper.convertPrice(
        kioskLineTotal(widget.match.dealLine));
    final String saved = PriceConverterHelper.convertPrice(widget.match.saving);
    final String saveLabel = kioskTranslate(context, 'you_save', 'You save');
    return '$price · $saveLabel $saved';
  }
}

class _Header extends StatelessWidget {
  final double s;
  final double backSize;
  final double titleSize;
  const _Header({
    required this.s,
    required this.backSize,
    required this.titleSize,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KioskCircleBack(
          size: backSize,
          onTap: () => Navigator.of(context).pop(false),
        ),
        Expanded(
          child: Padding(
            padding:
                EdgeInsets.symmetric(horizontal: (12 * s).clamp(6.0, 12.0)),
            child: Text(
              kioskTranslate(
                context,
                'make_it_a_combo_meal',
                'Make it a Combo Meal?',
              ).toUpperCase(),
              textAlign: TextAlign.center,
              style: loewExtraBold.copyWith(
                fontSize: titleSize,
                height: 1.15,
                color: Colors.black,
              ),
            ),
          ),
        ),
        SizedBox(width: backSize),
      ],
    );
  }
}

class _OptionCard extends StatelessWidget {
  final _ComboMetrics metrics;
  final bool selected;

  /// The drink photo. For "No, just my order" this is the only image; for
  /// "Yes, combo me!" it is layered under/behind [foodImageUrl].
  final String imageUrl;

  /// The side-dish photo, layered over [imageUrl]. Null/empty on the "No"
  /// card, which shows the lone drink only.
  final String? foodImageUrl;

  final String label;
  final String? caption;
  final VoidCallback onTap;

  const _OptionCard({
    super.key,
    required this.metrics,
    required this.selected,
    required this.imageUrl,
    this.foodImageUrl,
    required this.label,
    this.caption,
    required this.onTap,
  });

  bool get _isComposite => foodImageUrl != null && foodImageUrl!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final double radius = metrics.cardRadius;

    Widget photo(String url, double w, double h) => ClipRRect(
          borderRadius: BorderRadius.circular(radius * 0.4),
          child: CustomImageWidget(
            placeholder: Images.placeholderImage,
            image: url,
            fit: BoxFit.contain,
            width: w,
            height: h,
            useShimmer: true,
            cacheWidth: CustomImageWidget.kKioskProductCacheWidth,
          ),
        );

    final Widget imageArea = !CustomImageWidget.showProductImages
        ? const SizedBox.shrink()
        : SizedBox(
            width: double.infinity,
            height: metrics.imageAreaHeight,
            child: _isComposite
                ? Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: metrics.drinkX,
                        top: metrics.drinkY,
                        width: metrics.drinkW,
                        height: metrics.drinkH,
                        child: photo(imageUrl, metrics.drinkW, metrics.drinkH),
                      ),
                      Positioned(
                        left: metrics.foodX,
                        top: metrics.foodY,
                        width: metrics.foodW,
                        height: metrics.foodH,
                        child:
                            photo(foodImageUrl!, metrics.foodW, metrics.foodH),
                      ),
                    ],
                  )
                : Center(
                    child:
                        photo(imageUrl, metrics.loneDrinkW, metrics.loneDrinkH),
                  ),
          );

    return Material(
      color: selected ? _kSelectedBg : _kUnselectedBg,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: KioskTap(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: metrics.cardHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: selected ? _kSelectedBorder : _kUnselectedBorder,
              width: selected
                  ? metrics.selectedBorderWidth
                  : metrics.unselectedBorderWidth,
            ),
          ),
          child: Stack(
            children: [
              Column(
                mainAxisAlignment: CustomImageWidget.showProductImages
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: [
                  if (CustomImageWidget.showProductImages) imageArea,
                  Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: metrics.cardInset),
                    child: Column(
                      children: [
                        SizedBox(height: metrics.cardInset * 0.4),
                        Text(
                          label,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: loewBold.copyWith(
                            fontSize: metrics.labelSize,
                            height: 1.1,
                            color: Colors.black,
                          ),
                        ),
                        if (caption != null) ...[
                          SizedBox(height: metrics.cardInset * 0.35),
                          Text(
                            caption!,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: loewMedium.copyWith(
                              fontSize:
                                  (metrics.labelSize * 0.72).clamp(10.0, 22.0),
                              height: 1.0,
                              color: TextTones.secondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (selected)
                Positioned(
                  top: metrics.cardInset * 0.5,
                  right: metrics.cardInset * 0.5,
                  child: Container(
                    width: metrics.dotSize,
                    height: metrics.dotSize,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NextBar extends StatelessWidget {
  final _ComboMetrics metrics;
  final bool enabled;
  final VoidCallback onTap;

  const _NextBar({
    required this.metrics,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: Colors.black,
        borderRadius: BorderRadius.circular(metrics.nextRadius),
        clipBehavior: Clip.antiAlias,
        child: KioskTap(
          key: const ValueKey('kiosk-combo-next'),
          onTap: enabled ? onTap : null,
          child: SizedBox(
            width: double.infinity,
            height: metrics.nextHeight,
            child: Center(
              child: Text(
                kioskTranslate(context, 'next', 'Next').toUpperCase(),
                style: loewExtraBold.copyWith(
                  fontSize: metrics.nextLabelSize,
                  height: 1.0,
                  color: KioskUI.cream,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Geometry measured directly off Figma 05a (node 2305:6821), "TABLET Final
/// Designs (option B)". Every field below is `literalFigmaPx * f`, where
/// `f = sheetWidth / _designW` and `_designW` (749.44) is the frame width the
/// node's own numbers imply: two 346.385px cards, an 11.19px gap between
/// them, and a 22.74px inset on each side (the same inset the NEXT bar sits
/// inside). One scale, no per-element clamps beyond sane floors/ceilings so
/// the sheet never becomes illegible or oversized at extreme viewports.
class _ComboMetrics {
  final double sheetWidth;
  final double pad;
  final double backSize;
  final double titleSize;
  final double cardWidth;
  final double cardHeight;
  final double cardRadius;
  final double gap;
  final double labelSize;
  final double optionTopGap;
  final double nextTopGap;
  final double nextHeight;
  final double nextLabelSize;
  final double nextRadius;
  final double cardInset;
  final double modalRadius;
  final double modalBorderWidth;
  final double selectedBorderWidth;
  final double unselectedBorderWidth;
  final double dotSize;

  // Composite "Yes, combo me!" image geometry — drink layered with the food
  // image down-and-right of it, both measured from the card's top-left.
  final double drinkW;
  final double drinkH;
  final double drinkX;
  final double drinkY;
  final double foodW;
  final double foodH;
  final double foodX;
  final double foodY;

  // "No, just my order" — the lone drink, centered.
  final double loneDrinkW;
  final double loneDrinkH;

  /// Height reserved for the image area, sized to the lower of the two
  /// composite images so both cards' labels land on the same baseline.
  final double imageAreaHeight;

  const _ComboMetrics({
    required this.sheetWidth,
    required this.pad,
    required this.backSize,
    required this.titleSize,
    required this.cardWidth,
    required this.cardHeight,
    required this.cardRadius,
    required this.gap,
    required this.labelSize,
    required this.optionTopGap,
    required this.nextTopGap,
    required this.nextHeight,
    required this.nextLabelSize,
    required this.nextRadius,
    required this.cardInset,
    required this.modalRadius,
    required this.modalBorderWidth,
    required this.selectedBorderWidth,
    required this.unselectedBorderWidth,
    required this.dotSize,
    required this.drinkW,
    required this.drinkH,
    required this.drinkX,
    required this.drinkY,
    required this.foodW,
    required this.foodH,
    required this.foodX,
    required this.foodY,
    required this.loneDrinkW,
    required this.loneDrinkH,
    required this.imageAreaHeight,
  });

  // Frame width implied by the node's own measurements (see class doc).
  static const double _designW = 749.44;
  static const double _sheetRatio = 0.81;

  factory _ComboMetrics.forSize(double viewportWidth, double viewportHeight) {
    final bool landscape = viewportWidth > viewportHeight;
    final double usable = viewportWidth.clamp(240.0, double.infinity);
    final double sheetWidth = (usable * (landscape ? 0.72 : _sheetRatio))
        .clamp(300.0, landscape ? 1680.0 : 1600.0);
    final double f = sheetWidth / _designW;

    final double cardWidth = 346.385 * f;
    final double cardHeight = 285.13 * f;
    final double drinkBottom = (30.42 + 195.621) * f;
    final double foodBottom = (52.98 + 150.505) * f;

    return _ComboMetrics(
      sheetWidth: sheetWidth,
      pad: 22.74 * f,
      backSize: (50.89 * f).clamp(28.0, 86.0),
      titleSize: (26 * f).clamp(13.0, 40.0),
      cardWidth: cardWidth,
      cardHeight: cardHeight,
      cardRadius: (10.106 * f).clamp(8.0, 28.0),
      gap: 11.19 * f,
      labelSize: (17 * f).clamp(10.0, 26.0),
      optionTopGap: (sheetWidth * 0.04).clamp(12.0, 36.0),
      nextTopGap: (sheetWidth * 0.05).clamp(16.0, 48.0),
      nextHeight: (90.95 * f).clamp(44.0, 110.0),
      nextLabelSize: (20 * f).clamp(13.0, 30.0),
      nextRadius: (10.828 * f).clamp(8.0, 30.0),
      cardInset: (cardWidth * 0.05).clamp(8.0, 18.0),
      modalRadius: (10.828 * f).clamp(10.0, 30.0),
      modalBorderWidth: (0.361 * f).clamp(0.5, 1.5),
      selectedBorderWidth: (1.444 * f).clamp(1.0, 3.0),
      unselectedBorderWidth: (0.541 * f).clamp(0.5, 2.0),
      dotSize: (12.99 * f).clamp(8.0, 26.0),
      drinkW: 130.654 * f,
      drinkH: 195.621 * f,
      drinkX: 55.88 * f,
      drinkY: 30.42 * f,
      foodW: 191.651 * f,
      foodH: 150.505 * f,
      foodX: 98.86 * f,
      foodY: 52.98 * f,
      loneDrinkW: 130.654 * f,
      loneDrinkH: 195.958 * f,
      imageAreaHeight: drinkBottom > foodBottom ? drinkBottom : foodBottom,
    );
  }
}
