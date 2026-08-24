import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/common/providers/product_provider.dart';
import 'package:acafe_customer/common/responsive/kiosk_responsive.dart';
import 'package:acafe_customer/common/responsive/responsive.dart';
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
import 'package:acafe_customer/theme/brand_colors.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:provider/provider.dart';

// ===========================================================================
// KIOSK PRODUCT CUSTOMIZE — single full-screen page matching the Figma design
// (node 559:7646). Every size is taken from the 2572px-wide artboard and scaled
// by `s = KioskResponsive.scale(screenWidth)`, reproducing the design at any size.
// ===========================================================================
const Color _kPanelBg = Color(0xFFFCFAF4);
const Color _kDarkButton = Color(0xFF1E1E1E);
const Color _kCreamText = Color(0xFFF3F3DD);

/// Variation groups whose name mentions "cup"/"can" get the big two-card
/// treatment and are only shown when the product actually has them.
final RegExp _kCupCanPattern = RegExp(r'cup|can', caseSensitive: false);

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
  late final TextEditingController _instructionController;
  final ScrollController _optionsScrollController = ScrollController();

  Product get product => widget.product;
  int? get cartIndex => widget.cartIndex;

  @override
  void initState() {
    super.initState();
    _instructionController =
        TextEditingController(text: widget.initialInstruction ?? '');
  }

  @override
  void dispose() {
    _instructionController.dispose();
    _optionsScrollController.dispose();
    super.dispose();
  }

  String? get _instruction {
    final text = _instructionController.text.trim();
    return text.isEmpty ? null : text;
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
                instructionController: _instructionController,
                onAddToCart: () => _addToCart(context, productProvider),
              );
            }
            return LayoutBuilder(
              builder: (context, constraints) {
                final double s = KioskResponsive.scale(constraints.maxWidth);
                // A portrait kiosk can afford the full-height hero; a medium
                // tablet or a resized browser window cannot — there the header
                // collapses into a compact row so the options keep the screen.
                final bool compactHeader =
                    constraints.maxHeight < constraints.maxWidth * 1.3;
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
                      Expanded(
                        child: _OptionsScrollArea(
                          controller: _optionsScrollController,
                          padding:
                              EdgeInsets.fromLTRB(86 * s, 0, 86 * s, 30 * s),
                          thickness: 30 * s,
                          minThumbLength: 160 * s,
                          scrollbarPadding:
                              EdgeInsets.fromLTRB(0, 0, 24 * s, 30 * s),
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
                              if (product.effectiveAddOnGroups.isNotEmpty)
                                _AddOnsSection(
                                    s: s,
                                    product: product,
                                    productProvider: productProvider),
                              for (final entry in cupCanVariations)
                                _CupCanSection(
                                  s: s,
                                  variation: entry.value,
                                  variationIndex: entry.key,
                                  product: product,
                                  productProvider: productProvider,
                                ),
                            ],
                          ),
                        ),
                      ),
                      // Instructions + Add to cart stay pinned; only the
                      // variations / add-ons above them scroll.
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 86 * s),
                        child: _InstructionsSection(
                          s: s,
                          controller: _instructionController,
                        ),
                      ),
                      _AddToCartBar(
                          s: s,
                          onTap: () => _addToCart(context, productProvider)),
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
        SizedBox(
          height: 720 * s,
          child: CustomImageWidget(
            key: ValueKey(heroImage),
            placeholder: Images.placeholderImage,
            image: heroImage,
            fit: BoxFit.contain,
          ),
        ),
        SizedBox(height: 24 * s),
        Text(
          product.name ?? '',
          textAlign: TextAlign.center,
          style: loewExtraBold.copyWith(fontSize: 64 * s, color: Colors.black),
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
        SizedBox(height: 20 * s),
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
  final double thickness;
  final double minThumbLength;
  final EdgeInsets scrollbarPadding;
  final Widget child;

  const _OptionsScrollArea({
    required this.controller,
    required this.padding,
    required this.thickness,
    required this.minThumbLength,
    required this.scrollbarPadding,
    required this.child,
  });

  @override
  State<_OptionsScrollArea> createState() => _OptionsScrollAreaState();
}

class _OptionsScrollAreaState extends State<_OptionsScrollArea> {
  @override
  void initState() {
    super.initState();
    _revealScrollbar();
  }

  @override
  void didUpdateWidget(covariant _OptionsScrollArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Selecting an option can grow / shrink the list, so re-check.
    _revealScrollbar();
  }

  /// [RawScrollbar] fades its thumb in only once it sees a scroll notification,
  /// which means an untouched screen can render with no indicator at all even
  /// though `thumbVisibility` is on. Emitting a zero-delta scroll update after
  /// the frame settles makes the thumb appear straight away.
  void _revealScrollbar() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ScrollController controller = widget.controller;
      if (!controller.hasClients) return;
      final ScrollPosition position = controller.position;
      if (!position.hasContentDimensions) return;
      position.didUpdateScrollPositionBy(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      // Drop the thin scrollbar the desktop/web scroll behavior adds, so only
      // the kiosk-sized one below is drawn.
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: RawScrollbar(
        controller: widget.controller,
        thumbVisibility: true,
        trackVisibility: true,
        interactive: true,
        thickness: widget.thickness,
        radius: Radius.circular(widget.thickness),
        minThumbLength: widget.minThumbLength,
        padding: widget.scrollbarPadding,
        // Warm brand tones instead of a black bar: tan thumb on the cream
        // card-border colour, so the indicator sits inside the kiosk palette.
        thumbColor: BrandColors.secondary,
        trackColor: BrandColors.cardBorder.withValues(alpha: 0.55),
        trackBorderColor: Colors.transparent,
        trackRadius: Radius.circular(widget.thickness),
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
      ),
    );
  }
}

/// A light rounded panel wrapping a titled section.
class _SectionPanel extends StatelessWidget {
  final double s;
  final String title;
  final Widget child;
  const _SectionPanel(
      {required this.s, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(vertical: 18 * s),
      padding: EdgeInsets.all(45 * s),
      decoration: BoxDecoration(
        color: _kPanelBg,
        borderRadius: BorderRadius.circular(70 * s),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: loewBold.copyWith(fontSize: 54 * s, color: Colors.black)),
          SizedBox(height: 30 * s),
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
      child: Wrap(
        alignment: WrapAlignment.start,
        spacing: 24 * s,
        runSpacing: 24 * s,
        children: [
          for (final entry in entries)
            for (int i = 0; i < (entry.value.variationValues?.length ?? 0); i++)
              _AddOnCard(
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
      child: Wrap(
        alignment: WrapAlignment.start,
        spacing: 24 * s,
        runSpacing: 24 * s,
        children: List.generate(values.length, (i) {
          final bool selected =
              productProvider.selectedVariations[variationIndex][i] ?? false;
          return _DietaryCard(
            s: s,
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
  final String name;
  final double priceDelta;
  final String image;
  final bool selected;
  final VoidCallback onTap;
  const _DietaryCard({
    required this.s,
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
      borderRadius: BorderRadius.circular(40 * s),
      clipBehavior: Clip.antiAlias,
      child: KioskTap(
        onTap: onTap,
        child: Container(
          width: 400 * s,
          padding: EdgeInsets.all(28 * s),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(40 * s),
            border: Border.all(
              color: selected ? Colors.black : Colors.black12,
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
                borderRadius: BorderRadius.circular(24 * s),
                child: SizedBox(
                  width: 240 * s,
                  height: 240 * s,
                  child: _OptionImageSlot(image: image, fit: BoxFit.cover),
                ),
              ),
              SizedBox(height: 20 * s),
              Text(
                name.toUpperCase(),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: loewBold.copyWith(
                    fontSize: 34 * s, height: 1.1, color: Colors.black),
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
                    fontSize: 28 * s, color: Colors.black54),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final group in product.effectiveAddOnGroups)
          _GroupedAddOnCards(
            s: s,
            product: product,
            productProvider: productProvider,
            group: group,
          ),
      ],
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

    return _SectionPanel(
      s: s,
      title: _addonGroupTitle(context, group),
      child: Wrap(
        alignment: WrapAlignment.start,
        spacing: 24 * s,
        runSpacing: 24 * s,
        children: [
          for (final addon in group.addons)
            if (product.indexOfAddOn(addon.id) != null)
              _AddOnCard(
                s: s,
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
    );
  }
}

class _AddOnCard extends StatelessWidget {
  final double s;
  final String name;
  final double priceDelta;
  final String image;
  final bool selected;
  final VoidCallback onTap;
  const _AddOnCard({
    required this.s,
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
      borderRadius: BorderRadius.circular(40 * s),
      clipBehavior: Clip.antiAlias,
      child: KioskTap(
        onTap: onTap,
        child: Container(
          width: 520 * s,
          padding: EdgeInsets.all(28 * s),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(40 * s),
            border: Border.all(
              color: selected ? Colors.black : Colors.black12,
              width:
                  selected ? (6 * s).clamp(2.0, 8.0) : (2 * s).clamp(1.0, 3.0),
            ),
          ),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(24 * s),
                child: SizedBox(
                  width: double.infinity,
                  height: 240 * s,
                  child: _OptionImageSlot(image: image, fit: BoxFit.cover),
                ),
              ),
              SizedBox(height: 20 * s),
              Text(
                name.toUpperCase(),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: loewBold.copyWith(
                    fontSize: 32 * s, height: 1.1, color: Colors.black),
              ),
              SizedBox(height: 6 * s),
              Text(
                '+${PriceConverterHelper.convertPrice(priceDelta)}',
                style: swiss721Light.copyWith(
                    fontSize: 28 * s, color: Colors.black54),
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

    return _SectionPanel(
      s: s,
      title: title,
      child: Row(
        children: List.generate(values.length, (i) {
          final bool selected =
              productProvider.selectedVariations[variationIndex][i] ?? false;
          return Expanded(
            child: Padding(
              padding:
                  EdgeInsets.only(right: i < values.length - 1 ? 30 * s : 0),
              child: _CupCanCard(
                s: s,
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
  final String image;
  final bool selected;
  final VoidCallback onTap;
  const _CupCanCard({
    required this.s,
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
      borderRadius: BorderRadius.circular(40 * s),
      clipBehavior: Clip.antiAlias,
      child: KioskTap(
        onTap: onTap,
        child: Container(
          height: 640 * s,
          padding: EdgeInsets.all(40 * s),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(40 * s),
            border: Border.all(
              color: selected ? Colors.black : Colors.black12,
              width:
                  selected ? (6 * s).clamp(2.0, 8.0) : (2 * s).clamp(1.0, 3.0),
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: _OptionImageSlot(image: image, fit: BoxFit.contain),
              ),
              SizedBox(height: 16 * s),
              Text(
                name.toUpperCase(),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: loewBold.copyWith(
                    fontSize: 36 * s, letterSpacing: 1, color: Colors.black),
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
                    fontSize: 28 * s, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Optional free-text instructions, shown after all option sections.
class _InstructionsSection extends StatelessWidget {
  final double s;
  final TextEditingController controller;
  const _InstructionsSection({required this.s, required this.controller});

  @override
  Widget build(BuildContext context) {
    return _SectionPanel(
      s: s,
      title: 'Instructions',
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 28 * s, vertical: 12 * s),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(40 * s),
        ),
        child: TextField(
          controller: controller,
          maxLength: 255,
          textInputAction: TextInputAction.done,
          textCapitalization: TextCapitalization.sentences,
          style: loewRegular.copyWith(fontSize: 36 * s, color: Colors.black),
          decoration: InputDecoration(
            isCollapsed: true,
            counterText: '',
            border: InputBorder.none,
            hintText: 'Special instructions (optional)',
            hintStyle:
                loewRegular.copyWith(fontSize: 36 * s, color: Colors.black38),
          ),
        ),
      ),
    );
  }
}

/// Pinned full-width "ADD TO CART" button.
class _AddToCartBar extends StatelessWidget {
  final double s;
  final VoidCallback onTap;
  const _AddToCartBar({required this.s, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(86 * s, 16 * s, 86 * s, 24 * s),
      child: Material(
        color: _kDarkButton,
        borderRadius: BorderRadius.circular(80 * s),
        clipBehavior: Clip.antiAlias,
        child: KioskTap(
          onTap: onTap,
          child: Container(
            height: 180 * s,
            alignment: Alignment.center,
            child: Text(
              getTranslated('add_to_cart', context)?.toUpperCase() ??
                  'ADD TO CART',
              style: loewExtraBold.copyWith(
                  fontSize: 54 * s, letterSpacing: 2, color: _kCreamText),
            ),
          ),
        ),
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
  final TextEditingController instructionController;
  final VoidCallback onAddToCart;

  const _WideCustomizeLayout({
    required this.product,
    required this.productProvider,
    required this.sizeVariations,
    required this.dietaryVariations,
    required this.cupCanVariations,
    required this.instructionController,
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
  TextEditingController get instructionController =>
      widget.instructionController;
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
                  Expanded(
                    child: _OptionsScrollArea(
                      controller: _optionsScrollController,
                      padding: const EdgeInsets.only(right: 20),
                      thickness: 10,
                      minThumbLength: 56,
                      scrollbarPadding: EdgeInsets.zero,
                      child: Column(
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
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Instructions + Add to cart stay pinned; only the
                  // variations / add-ons above them scroll.
                  _WideInstructionsSection(
                    controller: instructionController,
                  ),
                  KioskButton(
                    label:
                        getTranslated('add_to_cart', context)?.toUpperCase() ??
                            'ADD TO CART',
                    height: KioskUI.primaryButtonHeight,
                    maxWidth: 720,
                    onTap: onAddToCart,
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

class _WideInstructionsSection extends StatelessWidget {
  final TextEditingController controller;
  const _WideInstructionsSection({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Instructions',
            style: loewBold.copyWith(
                fontSize: KioskUI.section, color: Colors.black),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(KioskUI.radius),
            ),
            child: TextField(
              controller: controller,
              maxLength: 255,
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.sentences,
              style: loewRegular.copyWith(
                  fontSize: KioskUI.body, color: Colors.black),
              decoration: InputDecoration(
                isCollapsed: true,
                counterText: '',
                border: InputBorder.none,
                hintText: 'SPECIAL INSTRUCTIONS (Optional)',
                hintStyle: loewRegular.copyWith(
                    fontSize: KioskUI.body, color: Colors.black38),
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

  const _WideVariationSection({
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
              return _WideOptionCard(
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
  final bool selected;
  final VoidCallback onTap;

  const _WideOptionCard({
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
              color: selected ? Colors.black : Colors.black12,
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
                      child: _OptionImageSlot(image: image, fit: BoxFit.cover),
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
