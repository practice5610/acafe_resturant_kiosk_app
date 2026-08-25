import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/common/providers/product_provider.dart';
import 'package:acafe_customer/common/responsive/kiosk_responsive.dart';
import 'package:acafe_customer/common/responsive/responsive.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_navigation_helper.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_option_layout.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_session.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_checkout_widgets.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_tap.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_ui.dart';
import 'package:acafe_customer/common/widgets/custom_image_widget.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_product_image_helper.dart';
import 'package:acafe_customer/helper/custom_snackbar_helper.dart';
import 'package:acafe_customer/helper/price_converter_helper.dart';
import 'package:acafe_customer/helper/product_helper.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:acafe_customer/localization/language_constrants.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:provider/provider.dart';

// ===========================================================================
// KIOSK PRODUCT CUSTOMIZE — single full-screen page matching the Figma design
// (node 559:7646). Every size is taken from the 2572px-wide artboard and scaled
// by `s = KioskResponsive.scale(screenWidth)`, reproducing the design at any size.
// ===========================================================================
// Figma `02a - Menu Browse (Full Page)` (node 1385:13510), 2572x5400 artboard.
// Panel fill and border are the design's own tokens, not the generic cream.
const Color _kPanelBg = Color(0xFFFBF8EF); // (inspect) panel background
const Color _kPanelBorder = Color(0xFFB9B5A6); // (inspect) border / track
const Color _kDarkButton = Color(0xFF1E1E1E);
const Color _kCreamText = Color(0xFFF3F3DD);

// Add-on scroller — Figma `Rectangle 100` (thumb) over `Rectangle 101` (track):
// both 20px wide, 15px radius, thumb #000000 on a #B9B5A6 track. The add-on
// area is the screen's ONLY vertical scroller — everything else is pinned — so
// this is the one indicator on the page.
const double _kScrollbarWidth = 20;
const double _kScrollbarRadius = 15;
// Option-card metrics, scaled down ~18% from the raw artboard values: at full
// Figma size the cards read as oversized boxes on the real kiosk once the
// panels gained their borders.
const double _kDietaryCardWidth = 350; // was 426
const double _kAddOnCardWidth = 424; // was 520
const double _kOptionCardPad = 22; // was 28
const double _kOptionImage = 190; // was 240
const double _kOptionRadius = 30; // was 40
const double _kOptionInnerRadius = 20; // was 24
const double _kOptionGap = 16; // was 20
const double _kOptionNameSize = 28; // was 32/34
const double _kOptionPriceSize = 24; // was 28
const double _kOptionCardSpacing = 20; // was 24

/// The full-height hero only fits on a genuinely tall portrait kiosk. Below
/// this the header collapses to the compact side-by-side layout, which is what
/// keeps the add-on list from being squeezed to a sliver on a laptop window.
const double _kFullHeroMinViewport = 1150;

/// Width for one option card inside a panel [width] px wide — see
/// `kiosk_option_layout.dart` for the rule.
double _optionCardWidth(double width, double s) => kioskOptionCardWidth(
      width: width,
      cardWidth: _kAddOnCardWidth * s,
      gap: _kOptionCardSpacing * s,
    );

const Color _kScrollThumb = Color(0xFF000000);
const Color _kScrollTrack = _kPanelBorder;

/// Variation groups whose name mentions "cup"/"can" get the big two-card
/// treatment and are only shown when the product actually has them. This is the
/// name the backend's Cup/Can switch generates ("Can or cup?"); the pattern
/// stays loose so hand-authored groups from before the switch still match.
/// Word-bounded on purpose — an unbounded `can` also matched "Pecan".
final RegExp _kCupCanPattern =
    RegExp(r'\b(cups?|cans?)\b', caseSensitive: false);

/// Card outline + selected ink for the option cards — the design's own border
/// token, so an unselected card reads as part of the panel rather than a box
/// drawn on top of it.
const Color _kCardBorder = _kPanelBorder;
const Color _kCardBorderSelected = Color(0xFF1E1E1E);
const Color _kInkText = Color(0xFF2B2B2B);

/// Local artwork for the "Can or cup?" vessels. That group is generated from the
/// product's Cup/Can switch in the backend and carries no images of its own, so
/// the kiosk matches an option to a bundled asset by name. Anything unrecognised
/// falls back to the variation's own uploaded image.
String? _localVesselAsset(String label) {
  final String value = label.toLowerCase().trim();
  if (value.contains('cup')) return Images.kioskCupImage;
  if (value.contains('can')) return Images.kioskCanImage;
  return null;
}

/// Size groups (Small / Medium / Large) are often stored as separate
/// one-option variations. Render them as one addon-style horizontal card row.
final RegExp _kSizePattern =
    RegExp(r'(small|medium|large|\bsizes?\b)', caseSensitive: false);

bool _isSizeVariation(Variation variation) {
  final name = (variation.name ?? '').trim();
  if (_kSizePattern.hasMatch(name)) return true;
  final values = variation.variationValues ?? [];
  if (values.length == 1) {
    return _kSizePattern.hasMatch((values.first.level ?? '').trim());
  }
  return false;
}

String _addonImageUrl(BuildContext context, AddOns addon) {
  if (!addon.hasImage) return '';
  final splash = Provider.of<SplashProvider>(context, listen: false);
  return '${splash.baseUrls?.addonImageUrl}/${addon.image}';
}

String _addonGroupTitle(BuildContext context, AddOnGroup group) {
  final String name = (group.name != null && group.name!.isNotEmpty)
      ? group.name!
      : (getTranslated('add_add_ons', context) ?? 'Add add-ons');
  return group.isRequired ? '$name *' : name;
}

/// Entry point: tap a product in the kiosk menu -> open the customization screen.
///
/// Reuses the existing [ProductProvider] customization state and the existing
/// [CartModel] / [CartProvider.addToCart] pipeline, so a kiosk order is
/// identical to a web order. Products with no variations and no add-ons are
/// added straight to the cart (e.g. merchandise).
///
/// If this product is already in the cart (and the caller did not pass a line),
/// reopen that line so previous add-ons / variations stay selected and Add to
/// Cart updates it instead of inserting a duplicate.
void openKioskCustomize(BuildContext context, Product product,
    {CartModel? cart, int? cartIndex}) {
  final cartProvider = Provider.of<CartProvider>(context, listen: false);
  final productProvider = Provider.of<ProductProvider>(context, listen: false);

  final variations = product.variations ?? [];
  final addOns = product.addOns ?? [];
  final bool hasModifiers = variations.isNotEmpty ||
      addOns.isNotEmpty ||
      product.effectiveAddOnGroups.isNotEmpty;

  if (!hasModifiers) {
    productProvider.initData(product, null);
    productProvider.initProductVariationStatus(0);
    cartProvider.addToCart(
        buildKioskCartModel(context, product), productProvider.cartIndex);
    return;
  }

  bool replaceOtherProductLines = false;
  if (cart == null) {
    for (int i = cartProvider.cartList.length - 1; i >= 0; i--) {
      final line = cartProvider.cartList[i];
      if (line?.product?.id == product.id) {
        cart = line;
        cartIndex = i;
        replaceOtherProductLines = true;
        break;
      }
    }
  }

  productProvider.initData(product, cart);
  productProvider.initProductVariationStatus(product.variations?.length ?? 0);

  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => KioskProductCustomizeScreen(
        product: product,
        cartIndex: cartIndex,
        initialInstruction: cart?.instruction,
        replaceOtherProductLines: replaceOtherProductLines,
      ),
    ),
  );
}

/// Builds the cart line from the current [ProductProvider] selection state.
/// Mirrors the math in the web app's CartBottomSheetWidget so prices match.
CartModel buildKioskCartModel(BuildContext context, Product product,
    {String? instruction}) {
  final productProvider = Provider.of<ProductProvider>(context, listen: false);

  final branch = ProductHelper.getBranchProductVariationWithPrice(product);
  final List<Variation> variationList = branch.variatins ?? [];
  final double price = branch.price ?? 0;

  double variationPrice = 0;
  for (int index = 0; index < variationList.length; index++) {
    for (int i = 0; i < variationList[index].variationValues!.length; i++) {
      if (productProvider.selectedVariations[index][i] ?? false) {
        variationPrice += variationList[index].variationValues![i].optionPrice!;
      }
    }
  }

  final double? discount = product.discount;
  final String? discountType = product.discountType;
  final double priceWithDiscount =
      PriceConverterHelper.convertWithDiscount(price, discount, discountType)!;

  final List<AddOn> addOnIdList = [];
  for (int index = 0; index < (product.addOns?.length ?? 0); index++) {
    if (productProvider.addOnActiveList[index]) {
      addOnIdList.add(AddOn(
          id: product.addOns![index].id,
          quantity: productProvider.addOnQtyList[index]));
    }
  }

  final double priceWithVariation = price + variationPrice;
  final double discountAmount = priceWithVariation -
      PriceConverterHelper.convertWithDiscount(
          priceWithVariation, discount, discountType)!;

  return CartModel(
    priceWithVariation,
    priceWithDiscount,
    [],
    discountAmount,
    productProvider.quantity,
    (priceWithVariation - discountAmount) -
        PriceConverterHelper.convertWithDiscount(
            priceWithVariation - discountAmount, product.tax, product.taxType)!,
    addOnIdList,
    product,
    productProvider.selectedVariations,
    instruction: instruction,
  );
}

class KioskProductCustomizeScreen extends StatefulWidget {
  final Product product;
  final int? cartIndex;
  final String? initialInstruction;

  /// When true, saving replaces this product's cart line and drops any other
  /// leftover lines for the same product (menu tap reopened an existing item).
  final bool replaceOtherProductLines;
  const KioskProductCustomizeScreen({
    super.key,
    required this.product,
    this.cartIndex,
    this.initialInstruction,
    this.replaceOtherProductLines = false,
  });

  @override
  State<KioskProductCustomizeScreen> createState() =>
      _KioskProductCustomizeScreenState();
}

class _KioskProductCustomizeScreenState
    extends State<KioskProductCustomizeScreen> {
  /// Per-line note. There is no longer a field for it on this screen — the note
  /// moved to a single order-level note on the cart — but an existing line's
  /// text is carried through so editing a line cannot silently wipe it.
  String? _instruction;
  final ScrollController _optionsScrollController = ScrollController();

  Product get product => widget.product;
  int? get cartIndex => widget.cartIndex;

  @override
  void initState() {
    super.initState();
    final String initial = widget.initialInstruction?.trim() ?? '';
    _instruction = initial.isEmpty ? null : initial;
  }

  @override
  void dispose() {
    _optionsScrollController.dispose();
    super.dispose();
  }

  /// Same validation rules as the web app, run before adding to the cart.
  bool _validate(BuildContext context, ProductProvider productProvider) {
    final variations = product.variations ?? [];
    for (int index = 0; index < variations.length; index++) {
      final v = variations[index];
      if (!v.isMultiSelect! &&
          v.isRequired! &&
          !productProvider.selectedVariations[index].contains(true)) {
        showCustomSnackBarHelper(
          '${getTranslated('choose_a_variation_from', context)} ${v.name}',
          isError: true,
        );
        return false;
      }
      if (v.isMultiSelect! &&
          (v.isRequired! ||
              productProvider.selectedVariations[index].contains(true)) &&
          v.min! >
              productProvider.selectedVariationLength(
                  productProvider.selectedVariations, index)) {
        showCustomSnackBarHelper(
          '${getTranslated('you_need_to_select_minimum', context)} ${v.min}',
          isError: true,
        );
        return false;
      }
    }
    for (final group in product.effectiveAddOnGroups) {
      final List<int> indexes = [];
      for (final addon in group.addons) {
        final int? i = product.indexOfAddOn(addon.id);
        if (i != null) {
          indexes.add(i);
        }
      }
      int selected = 0;
      for (final int i in indexes) {
        if (i < productProvider.addOnActiveList.length &&
            productProvider.addOnActiveList[i]) {
          selected++;
        }
      }
      final bool required = group.isRequired || group.min > 0;
      final int min = group.isSingle ? (required ? 1 : 0) : group.min;
      if (required && selected < min) {
        showCustomSnackBarHelper(
          '${getTranslated('choose_a_variation_from', context)} ${group.name ?? ''}',
          isError: true,
        );
        return false;
      }
    }
    return true;
  }

  void _addToCart(BuildContext context, ProductProvider productProvider) {
    if (!_validate(context, productProvider)) return;
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final int? index = cartIndex ?? productProvider.cartIndex;
    cartProvider.addToCart(
        buildKioskCartModel(context, product, instruction: _instruction),
        index);
    if (widget.replaceOtherProductLines &&
        product.id != null &&
        index != null &&
        index >= 0) {
      cartProvider.removeOtherLinesForProduct(product.id!, index);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final variations = product.variations ?? [];
    // Split out the cup/can group(s) so they render with the big two-card style.
    final List<MapEntry<int, Variation>> indexedVariations =
        List.generate(variations.length, (i) => MapEntry(i, variations[i]));
    final cupCanVariations = indexedVariations
        .where((e) => _kCupCanPattern.hasMatch(e.value.name ?? ''))
        .toList();
    final sizeVariations = indexedVariations
        .where((e) =>
            !_kCupCanPattern.hasMatch(e.value.name ?? '') &&
            _isSizeVariation(e.value))
        .toList();
    final dietaryVariations = indexedVariations
        .where((e) =>
            !_kCupCanPattern.hasMatch(e.value.name ?? '') &&
            !_isSizeVariation(e.value))
        .toList();

    return Scaffold(
      backgroundColor: KioskUI.pageBg,
      body: SafeArea(
        child: Consumer<ProductProvider>(
          builder: (context, productProvider, _) {
            if (Responsive.isWide(context)) {
              return _WideCustomizeLayout(
                product: product,
                productProvider: productProvider,
                sizeVariations: sizeVariations,
                dietaryVariations: dietaryVariations,
                cupCanVariations: cupCanVariations,
                onAddToCart: () => _addToCart(context, productProvider),
              );
            }
            return LayoutBuilder(
              builder: (context, constraints) {
                final double s = KioskResponsive.scale(constraints.maxWidth);
                // A portrait kiosk can afford the full-height hero; a medium
                // tablet or a resized browser window cannot — there the header
                // collapses into a compact row so the options keep the screen.
                // Compact when the viewport is landscape-ish OR simply not
                // tall enough to carry the full hero and still leave the
                // add-ons room to breathe.
                final bool compactHeader =
                    constraints.maxHeight < constraints.maxWidth * 1.3 ||
                        constraints.maxHeight < _kFullHeroMinViewport;
                return KioskCenteredContent(
                  child: Column(
                    children: [
                      // Product image, name, description and the quantity
                      // stepper stay put — only the options below them scroll.
                      Padding(
                        padding: EdgeInsets.fromLTRB(86 * s, 30 * s, 86 * s, 0),
                        child: compactHeader
                            ? _CompactHeader(
                                s: s,
                                viewportHeight: constraints.maxHeight,
                                product: product,
                                productProvider: productProvider,
                              )
                            : _Header(
                                s: s,
                                product: product,
                                productProvider: productProvider),
                      ),
                      // VARIATIONS ARE PINNED. Each is a single line that
                      // scrolls sideways, and none of them sit in a vertical
                      // scroller — so a size or milk row can only ever move
                      // horizontally, never up and down with the page.
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 86 * s),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (sizeVariations.isNotEmpty)
                              _SizeOptionsPanel(
                                s: s,
                                entries: sizeVariations,
                                product: product,
                                productProvider: productProvider,
                              ),
                            for (final entry in dietaryVariations)
                              _VariationSection(
                                s: s,
                                variation: entry.value,
                                variationIndex: entry.key,
                                product: product,
                                productProvider: productProvider,
                              ),
                          ],
                        ),
                      ),
                      // ADD-ONS ARE THE ONLY VERTICAL SCROLLER. They take
                      // whatever height is left and scroll inside it, with the
                      // design's black-on-#B9B5A6 indicator.
                      if (product.effectiveAddOnGroups.isNotEmpty)
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 86 * s),
                            // The section owns the panel AND the scroller, so
                            // the indicator is drawn inside the panel box.
                            child: _AddOnsSection(
                              s: s,
                              product: product,
                              productProvider: productProvider,
                            ),
                          ),
                        )
                      else
                        const Spacer(),
                      // Cup / can and the action bar are both pinned to the
                      // bottom, per the design: the vessel is the last decision
                      // before adding, so it must not scroll out of reach.
                      for (final entry in cupCanVariations)
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 86 * s),
                          child: _CupCanSection(
                            s: s,
                            variation: entry.value,
                            variationIndex: entry.key,
                            product: product,
                            productProvider: productProvider,
                          ),
                        ),
                      _ActionBar(
                        s: s,
                        product: product,
                        productProvider: productProvider,
                        onAddToCart: () => _addToCart(context, productProvider),
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

/// Header: back button, large product image, name, description and a quantity
/// stepper.
class _Header extends StatelessWidget {
  final double s;
  final Product product;
  final ProductProvider productProvider;
  const _Header(
      {required this.s, required this.product, required this.productProvider});

  @override
  Widget build(BuildContext context) {
    final splash = Provider.of<SplashProvider>(context, listen: false);
    final String heroImage = KioskProductImageHelper.heroImageUrl(
      product: product,
      productImageBaseUrl: splash.baseUrls?.productImageUrl,
    );
    final String description =
        (product.description ?? '').replaceAll(RegExp(r'<[^>]*>'), '').trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Back button (top-left).
        Align(
          alignment: Alignment.centerLeft,
          child: KioskBackButton.scaled(
            s: s,
            size: 120,
            border: 2,
            icon: 50,
            fallback: RouterHelper.getKioskMenuRoute,
          ),
        ),
        // Figma hero: 453 x 731 on the 2572 artboard, centred — a portrait
        // box, so a landscape photo letterboxes inside it instead of stretching
        // to the full panel width the way it used to.
        Center(
          child: SizedBox(
            width: 453 * s,
            height: 731 * s,
            child: CustomImageWidget(
              key: ValueKey(heroImage),
              placeholder: Images.placeholderImage,
              image: heroImage,
              fit: BoxFit.contain,
            ),
          ),
        ),
        SizedBox(height: 24 * s),
        Text(
          product.name ?? '',
          textAlign: TextAlign.center,
          // (inspect) Loew / ExtraBold / 72px / line-height 100%.
          style: loewExtraBold.copyWith(
              fontSize: 72 * s, height: 1.0, color: Colors.black),
        ),
        if (description.isNotEmpty) ...[
          SizedBox(height: 12 * s),
          Text(
            description,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: scotchDisplayLight.copyWith(
                fontSize: 32 * s, height: 1.2, color: Colors.black87),
          ),
        ],
        SizedBox(height: 30 * s),
        _QuantityStepper(s: s, productProvider: productProvider),
        SizedBox(height: _kOptionGap * s),
      ],
    );
  }
}

/// Header for short / medium viewports (landscape tablets, resized windows).
///
/// The photo shrinks to a small square and the name, description and stepper
/// sit beside it, so the variations and add-ons below get most of the height
/// instead of a hero image that pushes them off-screen.
class _CompactHeader extends StatelessWidget {
  final double s;
  final double viewportHeight;
  final Product product;
  final ProductProvider productProvider;
  const _CompactHeader({
    required this.s,
    required this.viewportHeight,
    required this.product,
    required this.productProvider,
  });

  @override
  Widget build(BuildContext context) {
    final splash = Provider.of<SplashProvider>(context, listen: false);
    final String heroImage = KioskProductImageHelper.heroImageUrl(
      product: product,
      productImageBaseUrl: splash.baseUrls?.productImageUrl,
    );
    final String description =
        (product.description ?? '').replaceAll(RegExp(r'<[^>]*>'), '').trim();
    // Never let the photo eat more than a quarter of the viewport.
    final double imageSize = math.min(460 * s, viewportHeight * 0.25);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KioskBackButton.scaled(
          s: s,
          size: 110,
          border: 2,
          icon: 46,
          fallback: RouterHelper.getKioskMenuRoute,
        ),
        SizedBox(width: 28 * s),
        SizedBox(
          width: imageSize,
          height: imageSize,
          child: CustomImageWidget(
            key: ValueKey(heroImage),
            placeholder: Images.placeholderImage,
            image: heroImage,
            fit: BoxFit.contain,
          ),
        ),
        SizedBox(width: 36 * s),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                product.name ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: loewExtraBold.copyWith(
                    fontSize: 56 * s, color: Colors.black),
              ),
              if (description.isNotEmpty) ...[
                SizedBox(height: 10 * s),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: scotchDisplayLight.copyWith(
                      fontSize: 30 * s, height: 1.2, color: Colors.black87),
                ),
              ],
              SizedBox(height: 18 * s),
              _QuantityStepper(s: s, productProvider: productProvider),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  final double s;
  final ProductProvider productProvider;
  const _QuantityStepper({required this.s, required this.productProvider});

  @override
  Widget build(BuildContext context) {
    final int qty = productProvider.quantity ?? 1;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepperButton(
          s: s,
          label: '−',
          filled: false,
          onTap: () => qty > 1 ? productProvider.setQuantity(false) : null,
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 50 * s),
          child: Text('$qty',
              style: loewExtraBold.copyWith(
                  fontSize: 80 * s, color: Colors.black)),
        ),
        _StepperButton(
          s: s,
          label: '+',
          filled: true,
          onTap: () => productProvider.setQuantity(true),
        ),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  final double s;
  final String label;
  final bool filled;
  final VoidCallback onTap;
  const _StepperButton(
      {required this.s,
      required this.label,
      required this.filled,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? _kDarkButton : Colors.white,
      borderRadius: BorderRadius.circular(36 * s),
      clipBehavior: Clip.antiAlias,
      child: KioskTap(
        onTap: onTap,
        child: Container(
          width: 150 * s,
          height: 114 * s,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(36 * s),
            border: filled
                ? null
                : Border.all(
                    color: Colors.black, width: (4 * s).clamp(2.0, 6.0)),
          ),
          child: Text(
            label,
            style: loewExtraBold.copyWith(
                fontSize: 70 * s, color: filled ? _kCreamText : Colors.black),
          ),
        ),
      ),
    );
  }
}

/// Scrollable options area (variations / add-ons) with a kiosk-sized scrollbar
/// that is visible from the first frame — the guest should see that the list
/// scrolls without having to drag it first.
///
/// The thumb is only painted when the content is actually taller than the
/// viewport, so a product whose options all fit shows no indicator at all.
class _OptionsScrollArea extends StatefulWidget {
  final ScrollController controller;
  final EdgeInsets padding;
  final Widget child;

  const _OptionsScrollArea({
    required this.controller,
    required this.padding,
    required this.child,
  });

  @override
  State<_OptionsScrollArea> createState() => _OptionsScrollAreaState();
}

class _OptionsScrollAreaState extends State<_OptionsScrollArea> {
  // The scrollbar-reveal workaround that used to live here went with the
  // scrollbar itself — there is no outer indicator to coax into view any more.

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      // No scrollbar on the outer options list at all — the panels already
      // carry their own indicators where scrolling actually happens (the
      // add-ons), and a second tan bar down the whole page just added noise.
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // When the options are shorter than the area, centre them instead
          // of pinning them to the top — otherwise short products leave a
          // large empty band above the Instructions panel.
          final double minHeight = math.max(
            0,
            constraints.maxHeight - widget.padding.vertical,
          );
          return SingleChildScrollView(
            controller: widget.controller,
            padding: widget.padding,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [widget.child],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// One row of option cards that scrolls sideways.
///
/// The kiosk has no visible horizontal scrollbar in the design, so the row is
/// laid out with the cards at their natural width and simply overflows into a
/// drag. `physics` is always scrollable so a short list still feels the same.
class _HorizontalOptionRow extends StatelessWidget {
  final double s;

  /// Built with the card width derived from the row's own width, so the cards
  /// scale with the device instead of holding a fixed artboard size.
  final List<Widget> Function(double cardWidth) builder;
  const _HorizontalOptionRow({required this.s, required this.builder});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: LayoutBuilder(builder: (context, constraints) {
          final double cardWidth = _optionCardWidth(constraints.maxWidth, s);
          final List<Widget> children = builder(cardWidth);
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < children.length; i++) ...[
                  if (i > 0) SizedBox(width: _kOptionCardSpacing * s),
                  children[i],
                ],
              ],
            ),
          );
        }),
      ),
    );
  }
}

/// Add-on grid clipped to the design's viewport height with its own vertical
/// scroller — Figma draws a #000000 thumb on a #B9B5A6 track, 20px wide with a
/// 15px radius, rather than letting the add-ons run on down the page.
class _AddOnScrollBox extends StatefulWidget {
  final double s;
  final Widget child;
  const _AddOnScrollBox({required this.s, required this.child});

  @override
  State<_AddOnScrollBox> createState() => _AddOnScrollBoxState();
}

class _AddOnScrollBoxState extends State<_AddOnScrollBox> {
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _reveal();
  }

  @override
  void didUpdateWidget(covariant _AddOnScrollBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    _reveal();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// RawScrollbar only fades its thumb in once it has seen a scroll
  /// notification, so an untouched panel would render with no indicator at all.
  /// A zero-delta update after the first frame makes it visible immediately.
  void _reveal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      final ScrollPosition position = _controller.position;
      if (!position.hasContentDimensions) return;
      position.didUpdateScrollPositionBy(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final double s = widget.s;
    final double thickness =
        (_kScrollbarWidth * s).clamp(4.0, _kScrollbarWidth);

    // No height of its own: this lives in an Expanded and fills whatever the
    // pinned header, variations, cup/can and action bar leave behind.
    return SizedBox(
      width: double.infinity,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: RawScrollbar(
          controller: _controller,
          thumbVisibility: true,
          trackVisibility: true,
          interactive: true,
          thickness: thickness,
          radius: Radius.circular(_kScrollbarRadius * s),
          trackRadius: Radius.circular(_kScrollbarRadius * s),
          thumbColor: _kScrollThumb,
          trackColor: _kScrollTrack,
          trackBorderColor: Colors.transparent,
          child: SingleChildScrollView(
            controller: _controller,
            padding: EdgeInsets.only(right: thickness + 16 * s),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// A light rounded panel wrapping a titled section.
class _SectionPanel extends StatelessWidget {
  final double s;
  final String title;

  /// Let the child take the panel's remaining height instead of sizing to its
  /// content. Used by the add-ons panel so its scroller — and therefore the
  /// scroll indicator — lives INSIDE the panel box rather than beside it.
  final bool fill;
  final Widget child;
  const _SectionPanel({
    required this.s,
    required this.title,
    required this.child,
    this.fill = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(vertical: 18 * s),
      padding: EdgeInsets.all(38 * s),
      decoration: BoxDecoration(
        color: _kPanelBg,
        // Same corner as the option cards, so tuning _kOptionRadius moves the
        // whole screen's rounding together.
        borderRadius: BorderRadius.circular(_kOptionRadius * s),
        border: Border.all(
          color: _kPanelBorder,
          width: (4 * s).clamp(1.0, 4.0),
        ),
      ),
      child: Column(
        mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: loewBold.copyWith(fontSize: 54 * s, color: Colors.black)),
          SizedBox(height: 30 * s),
          if (fill)
            Expanded(child: child)
          else
            Align(
              alignment: Alignment.centerLeft,
              child: child,
            ),
        ],
      ),
    );
  }
}

/// Small / Medium / Large as one addon-style panel: title + horizontal cards.
class _SizeOptionsPanel extends StatelessWidget {
  final double s;
  final List<MapEntry<int, Variation>> entries;
  final Product product;
  final ProductProvider productProvider;
  const _SizeOptionsPanel({
    required this.s,
    required this.entries,
    required this.product,
    required this.productProvider,
  });

  @override
  Widget build(BuildContext context) {
    final splash = Provider.of<SplashProvider>(context, listen: false);
    return _SectionPanel(
      s: s,
      title: getTranslated('size', context) ?? 'Size',
      // Size is a variation, so it follows the same rule as the dietary row:
      // always one line that scrolls sideways, never wrapping onto a second.
      child: _HorizontalOptionRow(
        s: s,
        builder: (cardWidth) => [
          for (final entry in entries)
            for (int i = 0; i < (entry.value.variationValues?.length ?? 0); i++)
              _AddOnCard(
                width: cardWidth,
                s: s,
                name: (entry.value.variationValues![i].level ??
                        entry.value.name ??
                        '')
                    .trim(),
                priceDelta: entry.value.variationValues![i].optionPrice ?? 0,
                image: KioskProductImageHelper.optionCardImageUrl(
                  value: entry.value.variationValues![i],
                  productImageBaseUrl: splash.baseUrls?.productImageUrl,
                ),
                selected:
                    productProvider.selectedVariations[entry.key][i] ?? false,
                onTap: () {
                  productProvider.setCartVariationIndex(
                      entry.key, i, product, entry.value.isMultiSelect!);
                  productProvider.checkIsRequiredSelected(
                    index: entry.key,
                    isMultiSelect: entry.value.isMultiSelect!,
                    variations: productProvider.selectedVariations[entry.key],
                    min: entry.value.min,
                    max: entry.value.max,
                  );
                },
              ),
        ],
      ),
    );
  }
}

/// A single variation group rendered as selectable "dietary" cards with a radio.
class _VariationSection extends StatelessWidget {
  final double s;
  final Variation variation;
  final int variationIndex;
  final Product product;
  final ProductProvider productProvider;
  const _VariationSection({
    required this.s,
    required this.variation,
    required this.variationIndex,
    required this.product,
    required this.productProvider,
  });

  @override
  Widget build(BuildContext context) {
    final splash = Provider.of<SplashProvider>(context, listen: false);
    final values = variation.variationValues ?? [];
    final title = variation.name?.isNotEmpty == true
        ? variation.name!
        : (getTranslated('choose_an_option', context) ?? 'Choose an option');

    return _SectionPanel(
      s: s,
      title: title,
      // Figma keeps the dietary options on ONE row that scrolls sideways, so a
      // product with many milks never grows the panel vertically and pushes the
      // add-ons off screen — it just scrolls.
      child: _HorizontalOptionRow(
        s: s,
        builder: (cardWidth) => List.generate(values.length, (i) {
          final bool selected =
              productProvider.selectedVariations[variationIndex][i] ?? false;
          return _DietaryCard(
            s: s,
            width: cardWidth,
            name: values[i].level?.trim() ?? '',
            priceDelta: values[i].optionPrice ?? 0,
            image: KioskProductImageHelper.optionCardImageUrl(
              value: values[i],
              productImageBaseUrl: splash.baseUrls?.productImageUrl,
            ),
            selected: selected,
            onTap: () {
              productProvider.setCartVariationIndex(
                  variationIndex, i, product, variation.isMultiSelect!);
              productProvider.checkIsRequiredSelected(
                index: variationIndex,
                isMultiSelect: variation.isMultiSelect!,
                variations: productProvider.selectedVariations[variationIndex],
                min: variation.min,
                max: variation.max,
              );
            },
          );
        }),
      ),
    );
  }
}

class _DietaryCard extends StatelessWidget {
  final double s;

  /// Width computed from the space actually available. Falls back to the
  /// artboard value when a caller has no layout information.
  final double? width;
  final String name;
  final double priceDelta;
  final String image;
  final bool selected;
  final VoidCallback onTap;
  const _DietaryCard({
    required this.s,
    this.width,
    required this.name,
    required this.priceDelta,
    required this.image,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(_kOptionRadius * s),
      clipBehavior: Clip.antiAlias,
      child: KioskTap(
        onTap: onTap,
        child: Container(
          width: width ?? _kDietaryCardWidth * s,
          padding: EdgeInsets.all(_kOptionCardPad * s),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_kOptionRadius * s),
            border: Border.all(
              color: selected ? Colors.black : _kPanelBorder,
              width:
                  selected ? (6 * s).clamp(2.0, 8.0) : (2 * s).clamp(1.0, 3.0),
            ),
          ),
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: _RadioDot(s: s, selected: selected),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(_kOptionInnerRadius * s),
                child: SizedBox(
                  width: _kOptionImage * s,
                  height: _kOptionImage * s,
                  child: _OptionImageSlot(image: image, fit: BoxFit.cover),
                ),
              ),
              SizedBox(height: _kOptionGap * s),
              Text(
                name.toUpperCase(),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: loewBold.copyWith(
                    fontSize: _kOptionNameSize * s,
                    height: 1.1,
                    color: Colors.black),
              ),
              // Always reserve this row's height, even with no price delta
              // (e.g. the base "Small" option) -- cards sit in a Wrap, which
              // doesn't stretch siblings to a common height, so omitting this
              // line entirely made that card shorter than its neighbors.
              SizedBox(height: 6 * s),
              Text(
                priceDelta > 0
                    ? '+${PriceConverterHelper.convertPrice(priceDelta)}'
                    : '',
                style: swiss721Light.copyWith(
                    fontSize: _kOptionPriceSize * s, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RadioDot extends StatelessWidget {
  final double s;
  final bool selected;
  const _RadioDot({required this.s, required this.selected});

  @override
  Widget build(BuildContext context) {
    final double d = 40 * s;
    return Container(
      width: d,
      height: d,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? Colors.black : Colors.transparent,
        border: Border.all(color: Colors.black, width: (3 * s).clamp(1.5, 4.0)),
      ),
      child: selected
          ? Icon(Icons.check, size: 26 * s, color: Colors.white)
          : null,
    );
  }
}

/// Add-ons: grouped like Lightspeed. Single-choice groups act as radios.
class _AddOnsSection extends StatelessWidget {
  final double s;
  final Product product;
  final ProductProvider productProvider;
  const _AddOnsSection(
      {required this.s, required this.product, required this.productProvider});

  @override
  Widget build(BuildContext context) {
    final groups = product.effectiveAddOnGroups;

    // One panel for the whole add-on area, with the scroller INSIDE it — so the
    // indicator sits within the panel box next to the cards, the way the design
    // draws it, rather than running down the outside of the region.
    //
    // A single group titles the panel with its own name; several groups keep
    // the design's "Add add-ons" heading and label each block inside.
    final bool single = groups.length == 1;

    return _SectionPanel(
      s: s,
      fill: true,
      title: single
          ? _addonGroupTitle(context, groups.first)
          : (getTranslated('add_add_ons', context) ?? 'Add add-ons'),
      child: _AddOnScrollBox(
        s: s,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int i = 0; i < groups.length; i++) ...[
              if (!single) ...[
                if (i > 0) SizedBox(height: 32 * s),
                Padding(
                  padding: EdgeInsets.only(bottom: 20 * s),
                  child: Text(
                    _addonGroupTitle(context, groups[i]),
                    style: loewBold.copyWith(
                        fontSize: 40 * s, color: Colors.black87),
                  ),
                ),
              ],
              _GroupedAddOnCards(
                s: s,
                product: product,
                productProvider: productProvider,
                group: groups[i],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GroupedAddOnCards extends StatelessWidget {
  final double s;
  final Product product;
  final ProductProvider productProvider;
  final AddOnGroup group;
  const _GroupedAddOnCards({
    required this.s,
    required this.product,
    required this.productProvider,
    required this.group,
  });

  @override
  Widget build(BuildContext context) {
    final List<int> groupIndexes = [
      for (final addon in group.addons)
        if (product.indexOfAddOn(addon.id) != null)
          product.indexOfAddOn(addon.id)!,
    ];

    // Cards only — the heading and the panel chrome belong to _AddOnsSection
    // now, so every group shares one panel and one scroller.
    return LayoutBuilder(builder: (context, constraints) {
      // Cards fill the row they are given: fewer, still-legible cards on a
      // narrow window instead of the same count squeezed into slivers.
      final double cardWidth = _optionCardWidth(constraints.maxWidth, s);
      return Wrap(
        alignment: WrapAlignment.start,
        spacing: _kOptionCardSpacing * s,
        runSpacing: _kOptionCardSpacing * s,
        children: [
          for (final addon in group.addons)
            if (product.indexOfAddOn(addon.id) != null)
              _AddOnCard(
                s: s,
                width: cardWidth,
                name: addon.name ?? '',
                priceDelta: addon.price ?? 0,
                image: _addonImageUrl(context, addon),
                selected: product.indexOfAddOn(addon.id)! <
                        productProvider.addOnActiveList.length &&
                    productProvider
                        .addOnActiveList[product.indexOfAddOn(addon.id)!],
                onTap: () => productProvider.toggleAddOnInGroup(
                  index: product.indexOfAddOn(addon.id)!,
                  isSingle: group.isSingle,
                  groupIndexes: groupIndexes,
                  isRequired: group.isRequired,
                  maxSelect: group.max,
                ),
              ),
        ],
      );
    });
  }
}

class _AddOnCard extends StatelessWidget {
  final double s;

  /// Width computed from the space actually available. Falls back to the
  /// artboard value when a caller has no layout information.
  final double? width;
  final String name;
  final double priceDelta;
  final String image;
  final bool selected;
  final VoidCallback onTap;
  const _AddOnCard({
    required this.s,
    this.width,
    required this.name,
    required this.priceDelta,
    required this.image,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(_kOptionRadius * s),
      clipBehavior: Clip.antiAlias,
      child: KioskTap(
        onTap: onTap,
        child: Container(
          width: width ?? _kAddOnCardWidth * s,
          padding: EdgeInsets.all(_kOptionCardPad * s),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_kOptionRadius * s),
            border: Border.all(
              color: selected ? Colors.black : _kPanelBorder,
              width:
                  selected ? (6 * s).clamp(2.0, 8.0) : (2 * s).clamp(1.0, 3.0),
            ),
          ),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(_kOptionInnerRadius * s),
                child: SizedBox(
                  width: double.infinity,
                  height: _kOptionImage * s,
                  child: _OptionImageSlot(image: image, fit: BoxFit.cover),
                ),
              ),
              SizedBox(height: _kOptionGap * s),
              Text(
                name.toUpperCase(),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: loewBold.copyWith(
                    fontSize: _kOptionNameSize * s,
                    height: 1.1,
                    color: Colors.black),
              ),
              SizedBox(height: 6 * s),
              Text(
                '+${PriceConverterHelper.convertPrice(priceDelta)}',
                style: swiss721Light.copyWith(
                    fontSize: _kOptionPriceSize * s, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cup / can group: two big selectable cards. Only shown when the product has a
/// cup/can variation.
class _CupCanSection extends StatelessWidget {
  final double s;
  final Variation variation;
  final int variationIndex;
  final Product product;
  final ProductProvider productProvider;
  const _CupCanSection({
    required this.s,
    required this.variation,
    required this.variationIndex,
    required this.product,
    required this.productProvider,
  });

  @override
  Widget build(BuildContext context) {
    final splash = Provider.of<SplashProvider>(context, listen: false);
    final values = variation.variationValues ?? [];
    final title = variation.name?.isNotEmpty == true
        ? variation.name!
        : (getTranslated('can_or_cup', context) ?? 'Can or cup?');

    // Cup and can are normally both free, so the price line is dropped entirely
    // rather than left as an empty row eating vertical space. It comes back the
    // moment any option actually carries a surcharge.
    final bool anyPriced = values.any((value) => (value.optionPrice ?? 0) > 0);

    return _SectionPanel(
      s: s,
      title: title,
      // No CrossAxisAlignment.stretch here: _SectionPanel puts this child in an
      // Align inside a scrollable column, so the Row's incoming maxHeight is
      // unbounded and stretch would hand each card a tight infinite height —
      // which fails layout for the whole options list. The cards carry an
      // explicit height, so they are equal-height without it.
      child: Row(
        children: List.generate(values.length, (i) {
          final bool selected =
              productProvider.selectedVariations[variationIndex][i] ?? false;
          final String label = values[i].level?.trim() ?? '';
          return Expanded(
            child: Padding(
              padding:
                  EdgeInsets.only(right: i < values.length - 1 ? 28 * s : 0),
              child: _CupCanCard(
                s: s,
                name: label,
                priceDelta: values[i].optionPrice ?? 0,
                showPrice: anyPriced,
                assetImage: _localVesselAsset(label),
                image: KioskProductImageHelper.optionCardImageUrl(
                  value: values[i],
                  productImageBaseUrl: splash.baseUrls?.productImageUrl,
                ),
                selected: selected,
                onTap: () {
                  productProvider.setCartVariationIndex(
                      variationIndex, i, product, variation.isMultiSelect!);
                  productProvider.checkIsRequiredSelected(
                    index: variationIndex,
                    isMultiSelect: variation.isMultiSelect!,
                    variations:
                        productProvider.selectedVariations[variationIndex],
                    min: variation.min,
                    max: variation.max,
                  );
                },
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _CupCanCard extends StatelessWidget {
  final double s;
  final String name;
  final double priceDelta;

  /// Draw the price line at all. Off when no option in the group is priced, so
  /// two free vessels do not each carry an empty row.
  final bool showPrice;

  /// Bundled artwork for a recognised vessel. Takes precedence over [image],
  /// which stays as the fallback for a hand-authored group with its own upload.
  final String? assetImage;
  final String image;
  final bool selected;
  final VoidCallback onTap;
  const _CupCanCard({
    required this.s,
    required this.name,
    required this.priceDelta,
    required this.showPrice,
    required this.assetImage,
    required this.image,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double radius = 40 * s;
    // Hairline at rest, a deliberate 3px ink edge once chosen. The old 6*s
    // selected border grew to 8px on a big kiosk and read as a bug.
    final double borderWidth =
        selected ? (4 * s).clamp(2.0, 3.0) : (2 * s).clamp(1.0, 1.5);

    return KioskTap(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        // Capped against the viewport as well as the artboard: on a short
        // window the vessel cards would otherwise take the height the add-on
        // list needs.
        height: math.min(620 * s, MediaQuery.sizeOf(context).height * 0.22),
        padding: EdgeInsets.fromLTRB(34 * s, 34 * s, 34 * s, 30 * s),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: selected ? _kCardBorderSelected : _kCardBorder,
            width: borderWidth,
          ),
          // A single soft shadow that deepens on selection — enough to lift the
          // card off the cream panel without the "floating chip" look that two
          // stacked shadows give.
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: selected ? 0.10 : 0.04),
              blurRadius: selected ? 28 * s : 16 * s,
              offset: Offset(0, selected ? 10 * s : 6 * s),
            ),
          ],
        ),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  // Warm pedestal so a transparent PNG has something to sit on
                  // instead of hovering in the middle of a white rectangle.
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        widthFactor: 0.78,
                        heightFactor: 0.5,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: Alignment.bottomCenter,
                              radius: 0.9,
                              colors: [
                                _kPanelBg,
                                _kPanelBg.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10 * s),
                      child: _VesselImage(
                        assetImage: assetImage,
                        image: image,
                      ),
                    ),
                  ),
                  // Selection tick, top-right — the same affordance the dietary
                  // row uses, so one glance reads both sections the same way.
                  Positioned(
                    top: 0,
                    right: 0,
                    child: _CupCanTick(s: s, selected: selected),
                  ),
                ],
              ),
            ),
            SizedBox(height: 22 * s),
            Text(
              name.toUpperCase(),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: loewBold.copyWith(
                fontSize: 34 * s,
                letterSpacing: 3 * s,
                height: 1.0,
                color: _kInkText,
              ),
            ),
            if (showPrice) ...[
              SizedBox(height: 10 * s),
              Text(
                priceDelta > 0
                    ? '+${PriceConverterHelper.convertPrice(priceDelta)}'
                    : '',
                style: swiss721Light.copyWith(
                    fontSize: 26 * s, color: Colors.black54),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Vessel artwork: a bundled asset when the option is a recognised cup/can,
/// otherwise whatever image the variation itself was given.
class _VesselImage extends StatelessWidget {
  final String? assetImage;
  final String image;
  const _VesselImage({required this.assetImage, required this.image});

  @override
  Widget build(BuildContext context) {
    final String? asset = assetImage;
    if (asset != null) {
      return Image.asset(
        asset,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) =>
            _OptionImageSlot(image: image, fit: BoxFit.contain),
      );
    }
    return _OptionImageSlot(image: image, fit: BoxFit.contain);
  }
}

/// Filled tick when chosen, an empty ring when not — so an untouched required
/// group visibly reads as "nothing picked yet".
class _CupCanTick extends StatelessWidget {
  final double s;
  final bool selected;
  const _CupCanTick({required this.s, required this.selected});

  @override
  Widget build(BuildContext context) {
    final double size = (44 * s).clamp(20.0, 40.0);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? _kCardBorderSelected : Colors.transparent,
        border: Border.all(
          color: selected ? _kCardBorderSelected : _kCardBorder,
          width: (3 * s).clamp(1.5, 2.5),
        ),
      ),
      child: selected
          ? Icon(Icons.check_rounded, size: size * 0.62, color: Colors.white)
          : null,
    );
  }
}

/// Pinned full-width "ADD TO CART" button.
/// Pinned bottom pair from the Figma design: CANCEL ITEM (outlined) beside
/// ADD TO CART with the running line total.
///
/// Both are [KioskCheckoutButton] — the same shared control the checkout steps
/// and login use — so weight, radius, height and the wide-screen behaviour stay
/// consistent across the kiosk instead of this screen growing its own button.
class _ActionBar extends StatelessWidget {
  final double s;
  final Product product;

  /// Rebuilt from the live selection, so the price tracks quantity, variations
  /// and add-ons as they change.
  final ProductProvider productProvider;
  final VoidCallback onAddToCart;
  const _ActionBar({
    required this.s,
    required this.product,
    required this.productProvider,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    final double total = kioskLineTotal(buildKioskCartModel(context, product));
    final String addLabel =
        '${getTranslated('add_to_cart', context)?.toUpperCase() ?? 'ADD TO CART'}'
        '  ${PriceConverterHelper.convertPrice(total)}';

    return Padding(
      padding: EdgeInsets.fromLTRB(86 * s, 16 * s, 86 * s, 24 * s),
      // No CrossAxisAlignment.stretch: this Row sits directly in the screen's
      // Column, whose children get an UNBOUNDED height, so stretch would hand
      // each button a tight infinite height and fail layout for the whole body.
      // KioskCheckoutButton sizes itself, so the pair is equal-height anyway.
      child: Row(
        children: [
          Expanded(
            child: KioskCheckoutButton(
              s: s,
              filled: false,
              fontSize: 54,
              label: getTranslated('cancel_item', context)?.toUpperCase() ??
                  'CANCEL ITEM',
              // Same route as the back button: drop the customize sheet and
              // return to the menu.
              onTap: () => KioskNavigationHelper.popOrNavigate(
                context,
                fallback: RouterHelper.getKioskMenuRoute,
              ),
            ),
          ),
          SizedBox(width: 28 * s),
          Expanded(
            child: KioskCheckoutButton(
              s: s,
              filled: true,
              fontSize: 54,
              label: addLabel,
              onTap: onAddToCart,
            ),
          ),
        ],
      ),
    );
  }
}

/// Two-column product detail for wide screens (image left 480px, options right).
class _WideCustomizeLayout extends StatefulWidget {
  final Product product;
  final ProductProvider productProvider;
  final List<MapEntry<int, Variation>> sizeVariations;
  final List<MapEntry<int, Variation>> dietaryVariations;
  final List<MapEntry<int, Variation>> cupCanVariations;
  final VoidCallback onAddToCart;

  const _WideCustomizeLayout({
    required this.product,
    required this.productProvider,
    required this.sizeVariations,
    required this.dietaryVariations,
    required this.cupCanVariations,
    required this.onAddToCart,
  });

  @override
  State<_WideCustomizeLayout> createState() => _WideCustomizeLayoutState();
}

class _WideCustomizeLayoutState extends State<_WideCustomizeLayout> {
  final ScrollController _optionsScrollController = ScrollController();

  Product get product => widget.product;
  ProductProvider get productProvider => widget.productProvider;
  List<MapEntry<int, Variation>> get sizeVariations => widget.sizeVariations;
  List<MapEntry<int, Variation>> get dietaryVariations =>
      widget.dietaryVariations;
  List<MapEntry<int, Variation>> get cupCanVariations =>
      widget.cupCanVariations;
  VoidCallback get onAddToCart => widget.onAddToCart;

  @override
  void dispose() {
    _optionsScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final splash = Provider.of<SplashProvider>(context, listen: false);
    final String image = KioskProductImageHelper.heroImageUrl(
      product: product,
      productImageBaseUrl: splash.baseUrls?.productImageUrl,
    );
    final String description =
        (product.description ?? '').replaceAll(RegExp(r'<[^>]*>'), '').trim();

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 480,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: KioskBackButton(
                    fallback: RouterHelper.getKioskMenuRoute,
                  ),
                ),
                const SizedBox(height: 16),
                AspectRatio(
                  aspectRatio: 1,
                  child: CustomImageWidget(
                    key: ValueKey(image),
                    placeholder: Images.placeholderImage,
                    image: image,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 32),
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Name, description and the quantity stepper stay put — only
                  // the variations / add-ons below them scroll.
                  Padding(
                    padding: const EdgeInsets.only(right: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          product.name ?? '',
                          style: loewExtraBold.copyWith(
                            fontSize: KioskUI.heading,
                            color: Colors.black,
                          ),
                        ),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            description,
                            style: scotchDisplayLight.copyWith(
                              fontSize: KioskUI.body,
                              height: 1.3,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        Center(
                          child: KioskQtyStepper(
                            quantity: productProvider.quantity ?? 1,
                            onDecrement: () {
                              if ((productProvider.quantity ?? 1) > 1) {
                                productProvider.setQuantity(false);
                              }
                            },
                            onIncrement: () =>
                                productProvider.setQuantity(true),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                  // Same rule as the narrow layout: variations are pinned and
                  // only ever move sideways; the add-ons are the one vertical
                  // scroller.
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (sizeVariations.isNotEmpty)
                        _WideSizeOptionsSection(
                          entries: sizeVariations,
                          product: product,
                          productProvider: productProvider,
                        ),
                      for (final entry in dietaryVariations)
                        _WideVariationSection(
                          variation: entry.value,
                          variationIndex: entry.key,
                          product: product,
                          productProvider: productProvider,
                        ),
                    ],
                  ),
                  Expanded(
                    child: _OptionsScrollArea(
                      controller: _optionsScrollController,
                      padding: const EdgeInsets.only(right: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (product.effectiveAddOnGroups.isNotEmpty)
                            _WideAddOnsSection(
                              product: product,
                              productProvider: productProvider,
                            ),
                          for (final entry in cupCanVariations)
                            _WideVariationSection(
                              variation: entry.value,
                              variationIndex: entry.key,
                              product: product,
                              productProvider: productProvider,
                              useVesselArt: true,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Cancel / add to cart stay pinned; only the variations and
                  // add-ons above them scroll. Same pair as the narrow layout.
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Row(
                      children: [
                        Expanded(
                          child: KioskButton(
                            label: getTranslated('cancel_item', context)
                                    ?.toUpperCase() ??
                                'CANCEL ITEM',
                            filled: false,
                            height: KioskUI.primaryButtonHeight,
                            onTap: () => KioskNavigationHelper.popOrNavigate(
                              context,
                              fallback: RouterHelper.getKioskMenuRoute,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: KioskButton(
                            label:
                                '${getTranslated('add_to_cart', context)?.toUpperCase() ?? 'ADD TO CART'}'
                                '  ${PriceConverterHelper.convertPrice(kioskLineTotal(buildKioskCartModel(context, product)))}',
                            height: KioskUI.primaryButtonHeight,
                            onTap: onAddToCart,
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
      ),
    );
  }
}

class _WideSizeOptionsSection extends StatelessWidget {
  final List<MapEntry<int, Variation>> entries;
  final Product product;
  final ProductProvider productProvider;

  const _WideSizeOptionsSection({
    required this.entries,
    required this.product,
    required this.productProvider,
  });

  @override
  Widget build(BuildContext context) {
    final splash = Provider.of<SplashProvider>(context, listen: false);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(getTranslated('size', context) ?? 'Size',
              style: loewBold.copyWith(
                  fontSize: KioskUI.section, color: Colors.black)),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.start,
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final entry in entries)
                for (int i = 0;
                    i < (entry.value.variationValues?.length ?? 0);
                    i++)
                  _WideOptionCard(
                    name: (entry.value.variationValues![i].level ??
                            entry.value.name ??
                            '')
                        .trim(),
                    priceDelta:
                        entry.value.variationValues![i].optionPrice ?? 0,
                    image: KioskProductImageHelper.optionCardImageUrl(
                      value: entry.value.variationValues![i],
                      productImageBaseUrl: splash.baseUrls?.productImageUrl,
                    ),
                    selected: productProvider.selectedVariations[entry.key]
                            [i] ??
                        false,
                    onTap: () {
                      productProvider.setCartVariationIndex(
                          entry.key, i, product, entry.value.isMultiSelect!);
                      productProvider.checkIsRequiredSelected(
                        index: entry.key,
                        isMultiSelect: entry.value.isMultiSelect!,
                        variations:
                            productProvider.selectedVariations[entry.key],
                        min: entry.value.min,
                        max: entry.value.max,
                      );
                    },
                  ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WideVariationSection extends StatelessWidget {
  final Variation variation;
  final int variationIndex;
  final Product product;
  final ProductProvider productProvider;

  /// Only the cup/can group opts into bundled artwork. Matching every group by
  /// name would misfire on ordinary options that merely contain "can" or "cup"
  /// (a "Pecan" syrup, say).
  final bool useVesselArt;

  const _WideVariationSection({
    required this.variation,
    required this.variationIndex,
    required this.product,
    required this.productProvider,
    this.useVesselArt = false,
  });

  @override
  Widget build(BuildContext context) {
    final splash = Provider.of<SplashProvider>(context, listen: false);
    final values = variation.variationValues ?? [];
    final title = variation.name?.isNotEmpty == true
        ? variation.name!
        : (getTranslated('choose_an_option', context) ?? 'Choose an option');

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: loewBold.copyWith(
                  fontSize: KioskUI.section, color: Colors.black)),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.start,
            spacing: 12,
            runSpacing: 12,
            children: List.generate(values.length, (i) {
              final bool selected =
                  productProvider.selectedVariations[variationIndex][i] ??
                      false;
              final String label = values[i].level?.trim() ?? '';
              return _WideOptionCard(
                name: label,
                priceDelta: values[i].optionPrice ?? 0,
                assetImage: useVesselArt ? _localVesselAsset(label) : null,
                image: KioskProductImageHelper.optionCardImageUrl(
                  value: values[i],
                  productImageBaseUrl: splash.baseUrls?.productImageUrl,
                ),
                selected: selected,
                onTap: () {
                  productProvider.setCartVariationIndex(
                      variationIndex, i, product, variation.isMultiSelect!);
                  productProvider.checkIsRequiredSelected(
                    index: variationIndex,
                    isMultiSelect: variation.isMultiSelect!,
                    variations:
                        productProvider.selectedVariations[variationIndex],
                    min: variation.min,
                    max: variation.max,
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _WideAddOnsSection extends StatelessWidget {
  final Product product;
  final ProductProvider productProvider;

  const _WideAddOnsSection(
      {required this.product, required this.productProvider});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final group in product.effectiveAddOnGroups)
          _WideGroupedAddOns(
            product: product,
            productProvider: productProvider,
            group: group,
          ),
      ],
    );
  }
}

class _WideGroupedAddOns extends StatelessWidget {
  final Product product;
  final ProductProvider productProvider;
  final AddOnGroup group;

  const _WideGroupedAddOns({
    required this.product,
    required this.productProvider,
    required this.group,
  });

  @override
  Widget build(BuildContext context) {
    final List<int> groupIndexes = [
      for (final addon in group.addons)
        if (product.indexOfAddOn(addon.id) != null)
          product.indexOfAddOn(addon.id)!,
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_addonGroupTitle(context, group),
              style: loewBold.copyWith(
                  fontSize: KioskUI.section, color: Colors.black)),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.start,
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final addon in group.addons)
                if (product.indexOfAddOn(addon.id) != null)
                  _WideOptionCard(
                    name: addon.name ?? '',
                    priceDelta: addon.price ?? 0,
                    image: _addonImageUrl(context, addon),
                    selected: product.indexOfAddOn(addon.id)! <
                            productProvider.addOnActiveList.length &&
                        productProvider
                            .addOnActiveList[product.indexOfAddOn(addon.id)!],
                    onTap: () => productProvider.toggleAddOnInGroup(
                      index: product.indexOfAddOn(addon.id)!,
                      isSingle: group.isSingle,
                      groupIndexes: groupIndexes,
                      isRequired: group.isRequired,
                      maxSelect: group.max,
                    ),
                  ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WideOptionCard extends StatelessWidget {
  final String name;
  final double priceDelta;
  final String image;

  /// Bundled vessel artwork, set only for the cup/can group. Drawn with
  /// `contain` rather than `cover` so a transparent PNG is not cropped.
  final String? assetImage;
  final bool selected;
  final VoidCallback onTap;

  const _WideOptionCard({
    required this.name,
    required this.priceDelta,
    required this.image,
    this.assetImage,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: KioskTap(
        onTap: onTap,
        child: Container(
          width: 150,
          height: 150,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? Colors.black : _kPanelBorder,
              width: selected ? 2 : 1,
            ),
          ),
          child: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: assetImage != null
                          ? _VesselImage(assetImage: assetImage, image: image)
                          : _OptionImageSlot(image: image, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: loewBold.copyWith(
                      fontSize: KioskUI.caption,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
              Positioned(
                top: 0,
                right: 0,
                child: _WideRadioDot(selected: selected),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reserved image slot for variation / add-on cards. When the option has no
/// image of its own, the slot stays empty (no product photo, no placeholder)
/// so card size is unchanged.
class _OptionImageSlot extends StatelessWidget {
  final String image;
  final BoxFit fit;
  const _OptionImageSlot({required this.image, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    if (image.isEmpty || CustomImageWidget.isDefaultImage(image)) {
      return const SizedBox.expand();
    }
    return CustomImageWidget(
      placeholder: Images.placeholderImage,
      image: image,
      fit: fit,
    );
  }
}

class _WideRadioDot extends StatelessWidget {
  final bool selected;
  const _WideRadioDot({required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? Colors.black : Colors.transparent,
        border: Border.all(color: Colors.black, width: 1.5),
      ),
      child: selected
          ? const Icon(Icons.check, size: 13, color: Colors.white)
          : null,
    );
  }
}
