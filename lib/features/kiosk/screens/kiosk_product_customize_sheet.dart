import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/common/providers/product_provider.dart';
import 'package:acafe_customer/common/responsive/kiosk_responsive.dart';
import 'package:acafe_customer/features/coupon/providers/coupon_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_allergen.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_order_composition.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_navigation_helper.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_customize_spec.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_option_layout.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_session.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_allergen_filter_screen.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_checkout_widgets.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_allergen_notice.dart';
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
import 'package:acafe_customer/features/kiosk/domain/kiosk_customize_analytics.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_translate.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_added_to_cart_screen.dart';
import 'package:acafe_customer/features/auth/providers/auth_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_ordering_experience.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/category/providers/category_provider.dart';
import 'package:provider/provider.dart';

// Version B (the three-step flow) is a `part` of this library rather than a
// separate one, so it reuses every private section widget below — the header,
// the variation panels, the add-on grid, the cup/can cards — instead of
// re-implementing them. Only the navigation shell differs between versions.
part 'kiosk_product_customize_step_flow.dart';

// ===========================================================================
// KIOSK PRODUCT CUSTOMIZE — one full-screen page reproducing the Figma design
// `02a – Menu Browse (Full Page)` (node 1385:13510), a 2572x5400 artboard.
//
// Every measurement lives in [KioskCustomizeSpec] as an artboard pixel and is
// multiplied by a SINGLE scale `s`. There are no per-element floors: a minimum
// font size on one label and not the next is what pulled the old screen out of
// proportion, leaving 16px headings inside panels that had kept shrinking. The
// bounds now sit on `s` itself (see [kioskCustomizeScale]) — it is capped by
// the viewport's WIDTH *and* its HEIGHT, which is the actual fix for a screen
// that looked oversized: scaling by width alone on a viewport proportionally
// shorter than the artboard asks for more height than exists.
// ===========================================================================

/// Section panel fill (`Rectangle 62`). The page cream behind it is the shared
/// [KioskUI.pageBg] (`Rectangle 86`, #F7F1DE).
const Color _kPanelBg = Color(0xFFFBF8EF);

/// Panel outline, option-card idle outline and the scroll track all share this
/// one token in the design.
const Color _kPanelBorder = Color(0xFFB9B5A6);
const Color _kCardIdleBorder = _kPanelBorder;

/// Cup/can cards carry a lighter idle outline than the option cards.
const Color _kVesselIdleBorder = Color(0xFFE2D9C8);

/// Selected outline + the design's near-black ink.
const Color _kCardBorderSelected = Color(0xFF000000);
const Color _kInkText = Color(0xFF0D0D0D);

/// Cream used for glyphs on the filled (black) controls.
const Color _kCreamText = Color(0xFFF3F3DD);

/// Filled chrome ink — Version B's progress bar.
const Color _kDarkButton = Color(0xFF1E1E1E);

/// Variation groups whose name mentions "cup"/"can" get the big two-card
/// treatment and are only shown when the product actually has them. The
/// pattern lives on [kioskCupCanPattern] so the upsell classifier and this
/// screen never disagree about what a drink is.

// Add-on scroller — Figma `Rectangle 100` (thumb) over `Rectangle 101` (track):
// both 20px wide, 15px radius, thumb #000000 on a #B9B5A6 track. The add-on
// area is the screen's ONLY vertical scroller in the pinned layout, so this is
// the one indicator on the page.
const double _kScrollbarWidth = KioskCustomizeSpec.scrollbarWidth;
const double _kScrollbarRadius = KioskCustomizeSpec.scrollbarRadius;
const Color _kScrollThumb = Color(0xFF000000);
const Color _kScrollTrack = _kPanelBorder;

/// Borders scale like everything else but never vanish — a hairline below one
/// logical pixel simply does not paint. This floor is the one bound the screen
/// applies to an individual element, and [KioskCustomizeSpec.borderFloor] is
/// why; everything else is bounded through the scale.
double _border(double artboardWidth, double s) =>
    math.max(KioskCustomizeSpec.borderFloor, artboardWidth * s);

double _addOnGap(double s) => KioskCustomizeSpec.addOnCardGap * s;

/// Shared gutter for variation and add-on choice cards, so both rows
/// compute the same tile width.
///
/// Floored in logical pixels: the artboard's 24px gutter scaled by a phone's
/// `s` is under 4px, which is not a gutter — it is a hairline between two cards
/// that then read as one strip. See [KioskCustomizeSpec.choiceCardGapFloor];
/// above ~1080px wide the scaled value wins and nothing changes.
double _choiceGap(double s) => math.max(
      KioskCustomizeSpec.choiceCardGapFloor,
      KioskCustomizeSpec.choiceCardGap * s,
    );

/// Width for one card inside a row/grid [width] px wide, given the artboard
/// card it is reproducing — see `kiosk_option_layout.dart` for the rule. Cards
/// divide the row exactly, so the last one ends flush with the panel edge.
double _cardWidthFor({
  required double width,
  required double artboardCard,
  required double s,
  required double gap,
}) =>
    kioskOptionCardWidth(
      width: width,
      cardWidth: artboardCard * s,
      gap: gap,
    );

/// Variation / add-on tile width. Large kiosks keep the stretched slot;
/// compact windows cap the box so three sizes cannot eat the whole row.
double _choiceTileWidth({
  required double viewportWidth,
  required double panelWidth,
  required double s,
  required double gap,
}) {
  final double filled = _cardWidthFor(
    width: panelWidth,
    artboardCard: KioskCustomizeSpec.choiceCardWidth,
    s: s,
    gap: gap,
  );
  if (viewportWidth >= KioskResponsive.compactMax) return filled;
  return math.min(filled, KioskCustomizeSpec.choiceCardMaxEdgeCompact);
}

/// Tile width for a WRAPPING grid of choice cards — the add-ons.
///
/// A grid must divide its row exactly, or the remainder piles up against the
/// panel's right edge with nothing in it. That is what the compact cap did on a
/// phone: three 96px cards and 58px of dead panel beside them, with 4px gutters
/// between the cards themselves, so the row read as a strip shoved to the left.
///
/// The cap still decides how many cards go across; the columns it implies then
/// share the row. A SCROLLING row ([_HorizontalOptionRow]) deliberately does
/// NOT do this — there the remainder is the next card peeking in, which is the
/// only thing telling the customer the row continues.
double _choiceGridTileWidth({
  required double viewportWidth,
  required double panelWidth,
  required double s,
  required double gap,
}) {
  final double capped = _choiceTileWidth(
    viewportWidth: viewportWidth,
    panelWidth: panelWidth,
    s: s,
    gap: gap,
  );
  // Kiosk-sized viewports never hit the cap: their cards already divide the row.
  if (viewportWidth >= KioskResponsive.compactMax) return capped;
  final int columns =
      math.max(1, ((panelWidth + gap) / (capped + gap)).floor());
  // Never below [capped] by construction — the columns are the number that FIT
  // at that width, so what they share out is the leftover.
  return math.max(1, (panelWidth - gap * (columns - 1)) / columns);
}

/// True when an option carries artwork of its own — the same test
/// [_OptionImageSlot] paints by.
bool _hasOptionArt(String image) =>
    image.isNotEmpty && !CustomImageWidget.isDefaultImage(image);

/// Image for a variation / add-on choice card. Only the option's own artwork —
/// never the product photo. Empty keeps a blank slot via [_OptionImageSlot].
String _choiceImageUrl(String image) => _hasOptionArt(image) ? image : '';

/// Same type token as a kiosk menu product name (`45px` on a `564px` tile).
/// Sized from THIS choice card so SMALL / ADDON1 decrease with the tile,
/// and never larger than Espresso on the same window.
double _choiceLabelSize(BuildContext context, double cardWidth) {
  final double menu = _menuProductNameSize(context);
  final double fromCard = 45 * (cardWidth / 564.0);
  return math.min(menu, math.max(11, fromCard));
}

/// Pixel size of a product name on the kiosk menu grid (`45 * tile/564`).
double _menuProductNameSize(BuildContext context) {
  final Size size = MediaQuery.sizeOf(context);
  final double s = KioskResponsive.scale(size.width, size.height);
  final rail = kioskCategoryRailLayout(scale: s, innerWidth: size.width);
  final double areaWidth = math.max(1, size.width - rail.width - rail.gap);
  final geo = KioskProductGridGeometry.resolve(
    areaWidth: areaWidth,
    gap: 41 * s,
    landscape: size.width > size.height,
  );
  return 45 * (geo.tileWidth / 564.0) * KioskResponsive.menuTypeScale;
}

/// Two lines of label is what a real product name needs — Figma's own
/// "SUGAR FREE CARAMEL SYRUP" already wraps — and a little more than the exact
/// line box, so a font that rounds up a fraction of a pixel cannot overflow a
/// card whose height was computed from it.
const int _kCardLabelLines = 2;

/// Height of one variation / add-on choice card of [width].
///
/// Both rows use this one box so Small/Medium/Large and Addon1/Addon2 are
/// the same width and height. The image slot flexes around the name and
/// price rather than growing the card.
double _choiceCardHeight(double width) {
  final double k = width / KioskCustomizeSpec.choiceCardWidth;
  return KioskCustomizeSpec.choiceCardHeight * k;
}

/// Height of one variation (dietary / size) card of [width].
double _optionCardHeight(
  double width, {
  required bool showImage,
  required bool showPrice,
}) {
  // Flags are kept so call sites stay explicit; the compact box always
  // includes image + price, so they do not change the height.
  assert(showImage && showPrice);
  return _choiceCardHeight(width);
}

/// Height of one add-on card of [width]. Same box as [_optionCardHeight].
double _addOnCardHeight(
  double width, {
  required bool showImage,
  required bool showPrice,
  required bool reserveQuantity,
}) {
  // Image slot absorbs the stepper, so reserved quantity never grows the box.
  assert(showImage && showPrice && !reserveQuantity);
  return _choiceCardHeight(width);
}

/// Figma add-on price: "€ +1.50" when the currency sits on the left, otherwise
/// "+ 1.50 €". [PriceConverterHelper.convertPrice] already includes the symbol.
String _addonPriceLabel(double price) {
  if (price <= 0) return '';
  final String converted = PriceConverterHelper.convertPrice(price);
  final Match? leading = RegExp(r'^([^\d\s]+)\s*(.*)').firstMatch(converted);
  if (leading != null) {
    final String symbol = leading.group(1)!.trim();
    final String amount = leading.group(2)!.trim();
    if (symbol.isNotEmpty && amount.isNotEmpty) {
      return '$symbol +$amount';
    }
  }
  return '+ $converted';
}

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

/// The three logical groups a product's variations fall into, in the order the
/// customer meets them. Version A stacks all three on one screen; Version B
/// puts each behind its own step — so the split has to be identical for both,
/// and lives here rather than inside either screen.
class _CustomizeSections {
  /// Small / Medium / Large, rendered as one horizontal card row.
  final List<MapEntry<int, Variation>> size;

  /// Milk / dietary choices — one panel each.
  final List<MapEntry<int, Variation>> dietary;

  /// Cup or can, rendered as the big two-card selector.
  final List<MapEntry<int, Variation>> cupCan;

  const _CustomizeSections({
    required this.size,
    required this.dietary,
    required this.cupCan,
  });

  factory _CustomizeSections.of(Product product) {
    final variations = ProductHelper.effectiveVariations(product) ?? [];
    final indexed =
        List.generate(variations.length, (i) => MapEntry(i, variations[i]));
    bool isCupCan(MapEntry<int, Variation> e) =>
        kioskCupCanPattern.hasMatch(e.value.name ?? '');

    return _CustomizeSections(
      cupCan: indexed.where(isCupCan).toList(),
      size: indexed
          .where((e) => !isCupCan(e) && _isSizeVariation(e.value))
          .toList(),
      dietary: indexed
          .where((e) => !isCupCan(e) && !_isSizeVariation(e.value))
          .toList(),
    );
  }

  /// Everything Version B's first step ("Milks") covers.
  bool get hasMilkStep => size.isNotEmpty || dietary.isNotEmpty;
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
    {CartModel? cart, int? cartIndex, ValueChanged<CartModel>? onConfigured}) {
  // THE ALLERGEN GATE. The first time a customer reaches for a product in an
  // order, ask what they need to avoid before showing them anything they might
  // not be able to eat (Figma POS 1385:15054). Once per order, not once per
  // product — see [KioskAllergenPreferences].
  //
  // Guarded on `cart == null` so this only fires on a NEW product selection.
  // Re-opening an existing cart line is an edit, and someone with a line in the
  // cart has necessarily already been asked.
  if (cart == null &&
      onConfigured == null &&
      !KioskAllergenPreferences.instance.asked) {
    _askAllergensThenOpenKioskCustomize(context, product);
    return;
  }
  _openKioskCustomizeNow(context, product,
      cart: cart, cartIndex: cartIndex, onConfigured: onConfigured);
}

/// Shows the allergen popup, then opens the product the customer tapped —
/// unless what they just declared rules it out.
Future<void> _askAllergensThenOpenKioskCustomize(
    BuildContext context, Product product) async {
  await showKioskAllergenFilter(context);
  if (!context.mounted) return;

  // They tapped a product, then told us they avoid something it contains. The
  // menu behind this popup has already dropped it, so opening it anyway would
  // contradict the answer they just gave.
  if (kioskProductHasAllergen(
      product, KioskAllergenPreferences.instance.avoided)) {
    return;
  }
  _openKioskCustomizeNow(context, product);
}

void _openKioskCustomizeNow(BuildContext context, Product product,
    {CartModel? cart, int? cartIndex, ValueChanged<CartModel>? onConfigured}) {
  final cartProvider = Provider.of<CartProvider>(context, listen: false);
  final productProvider = Provider.of<ProductProvider>(context, listen: false);

  final variations = ProductHelper.effectiveVariations(product) ?? [];
  final addOns = product.addOns ?? [];
  final bool hasModifiers = variations.isNotEmpty ||
      addOns.isNotEmpty ||
      product.effectiveAddOnGroups.isNotEmpty;

  if (!hasModifiers) {
    // Plain products (merch, bottles, …) have nothing to customize. Re-opening
    // an existing cart line used to call [addToCart] with a fresh qty-1 model
    // and no cart index, which merged into the matching line and bumped
    // quantity — the same symptom as tapping "+". Editing is a no-op.
    if (cart != null || cartIndex != null) {
      if (onConfigured != null) {
        productProvider.initData(product, cart);
        productProvider.initProductVariationStatus(0);
        onConfigured(buildKioskCartModel(context, product));
      }
      return;
    }
    productProvider.initData(product, null);
    productProvider.initProductVariationStatus(0);
    final CartModel built = buildKioskCartModel(context, product);
    if (onConfigured != null) {
      onConfigured(built);
      return;
    }
    cartProvider.addToCart(built, productProvider.cartIndex);
    return;
  }

  bool replaceOtherProductLines = false;
  if (onConfigured == null && cart == null) {
    for (int i = cartProvider.cartList.length - 1; i >= 0; i--) {
      final line = cartProvider.cartList[i];
      if (line?.product?.id == product.id && line?.isDeal != true) {
        cart = line;
        cartIndex = i;
        replaceOtherProductLines = true;
        break;
      }
    }
  }

  productProvider.initData(product, cart);
  productProvider.initProductVariationStatus(
      ProductHelper.effectiveVariations(product)?.length ?? 0);

  // THE A/B SWITCH. Which customization flow this kiosk renders is a back-office
  // setting on the device (Device Update -> Ordering Experience), delivered as
  // `device.ordering_experience` (login/me + live websocket) and cached in
  // SharedPreferences. Everything above this line — the cart lookup, the
  // ProductProvider seeding, the no-modifiers shortcut — is shared, so the two
  // versions can only ever differ in presentation. A live admin change remounts
  // the correct flow via [KioskCustomizeExperienceHost] without a full reload.
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => KioskCustomizeExperienceHost(
        product: product,
        cartIndex: cartIndex,
        initialInstruction: cart?.instruction,
        replaceOtherProductLines: replaceOtherProductLines,
        onConfigured: onConfigured,
      ),
    ),
  );
}

/// Watches [KioskAuthProvider.orderingExperience] so an admin A↔B switch over
/// the websocket remounts Version A or Version B immediately, even mid-customize.
///
/// Remounting resets step progress (Version B) but keeps [ProductProvider]
/// selections. The abandon analytics fire is suppressed for that remount so a
/// live switch is not counted as the customer walking away.
class KioskCustomizeExperienceHost extends StatefulWidget {
  final Product product;
  final int? cartIndex;
  final String? initialInstruction;
  final bool replaceOtherProductLines;
  final ValueChanged<CartModel>? onConfigured;

  const KioskCustomizeExperienceHost({
    super.key,
    required this.product,
    this.cartIndex,
    this.initialInstruction,
    this.replaceOtherProductLines = false,
    this.onConfigured,
  });

  /// Set when this host is about to swap A↔B so the outgoing screen's dispose
  /// does not emit `customization_abandoned`.
  static bool suppressAbandonOnce = false;

  @override
  State<KioskCustomizeExperienceHost> createState() =>
      _KioskCustomizeExperienceHostState();
}

class _KioskCustomizeExperienceHostState
    extends State<KioskCustomizeExperienceHost> {
  KioskOrderingExperience? _shown;
  late Product _product;
  late String _modifierSignature;
  bool _reinitScheduled = false;

  @override
  void initState() {
    super.initState();
    _product = widget.product;
    _modifierSignature = ProductHelper.catalogModifierSignature(_product);
  }

  @override
  void didUpdateWidget(covariant KioskCustomizeExperienceHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product.id != widget.product.id) {
      _product = widget.product;
      _modifierSignature = ProductHelper.catalogModifierSignature(_product);
    }
  }

  void _scheduleCatalogReinit(Product latest, String signature) {
    if (_reinitScheduled) return;
    _reinitScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reinitScheduled = false;
      if (!mounted) return;
      setState(() {
        _product = latest;
        _modifierSignature = signature;
      });
      // Admin changed addons/variations while this sheet was open — reset
      // selections so option indexes cannot point at removed rows.
      final productProvider =
          Provider.of<ProductProvider>(context, listen: false);
      productProvider.initData(latest, null);
      productProvider.initProductVariationStatus(
          ProductHelper.effectiveVariations(latest)?.length ?? 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<KioskAuthProvider, CategoryProvider>(
      builder: (context, auth, categories, _) {
        final Product latest =
            categories.findCachedProduct(_product.id) ?? _product;
        final String signature = ProductHelper.catalogModifierSignature(latest);
        if (signature != _modifierSignature) {
          _scheduleCatalogReinit(latest, signature);
        }

        final experience = auth.orderingExperience;
        if (_shown != null && _shown != experience) {
          KioskCustomizeExperienceHost.suppressAbandonOnce = true;
        }
        _shown = experience;
        return KeyedSubtree(
          key: ValueKey<String>('${experience.apiValue}_$_modifierSignature'),
          child: experience.isVersionB
              ? KioskProductCustomizeStepScreen(
                  product: _product,
                  cartIndex: widget.cartIndex,
                  initialInstruction: widget.initialInstruction,
                  replaceOtherProductLines: widget.replaceOtherProductLines,
                  onConfigured: widget.onConfigured,
                )
              : KioskProductCustomizeScreen(
                  product: _product,
                  cartIndex: widget.cartIndex,
                  initialInstruction: widget.initialInstruction,
                  replaceOtherProductLines: widget.replaceOtherProductLines,
                  onConfigured: widget.onConfigured,
                ),
        );
      },
    );
  }
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

  final List<AddOn> addOnIdList = [];
  for (int index = 0; index < (product.addOns?.length ?? 0); index++) {
    if (productProvider.addOnActiveList[index]) {
      addOnIdList.add(AddOn(
          id: product.addOns![index].id,
          quantity: productProvider.addOnQtyList[index]));
    }
  }

  // The discount is taken off the price of the configuration the customer
  // actually chose, so it has to be applied to the variation-inclusive price.
  // Discounting the bare base price instead left `discountedPrice` blind to
  // every variation picked (a +10.00 Large simply vanished from it), which is
  // what made the Add to Cart button, the cart line and the menu cart bar
  // disagree with the order summary — and, on an undiscounted product, made
  // `price` > `discountedPrice`, which the cart line card then drew as a
  // discount that does not exist.
  final double priceWithVariation = price + variationPrice;
  final double priceWithDiscount = PriceConverterHelper.convertWithDiscount(
      priceWithVariation, discount, discountType)!;
  final double discountAmount = priceWithVariation - priceWithDiscount;

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

/// Validation and the cart write, shared by both ordering experiences.
///
/// Version A runs [_validate] once when the customer taps Add to Cart;
/// Version B additionally runs [_validateStep] to decide whether Next is
/// enabled — but both end at the same [_addToCart], so the two versions can
/// never disagree about what a valid line is or how it reaches the cart.
mixin _KioskCustomizeActions<T extends StatefulWidget> on State<T> {
  Product get product;
  int? get cartIndex;
  String? get instruction;
  bool get replaceOtherProductLines;
  ValueChanged<CartModel>? get onConfigured => null;

  /// The ordering experience an ADMIN chose for this device. Both versions read
  /// it from the same place, so an event's `variant` always describes what was
  /// genuinely on screen.
  KioskOrderingExperience experienceOf(BuildContext context) =>
      Provider.of<KioskAuthProvider>(context, listen: false).orderingExperience;

  /// True once the line has reached the cart, so leaving the screen afterwards
  /// is a completion rather than an abandonment.
  bool _completed = false;

  /// Last experience seen during build. [dispose] runs after the element is
  /// detached, where Provider.of would throw, so the abandonment event reads
  /// this instead of the provider.
  KioskOrderingExperience _lastExperience = KioskOrderingExperience.fallback;

  /// Decode the success animation ahead of time. Called when a customization
  /// screen opens: the customer is seconds away from possibly adding to cart,
  /// and a cold 744KB gif would otherwise pop in a frame late.
  void precacheSuccessAnimation(BuildContext context) {
    precacheImage(const AssetImage(Images.confirmedDeliveryAnimation), context)
        .catchError((_) {
      // A failed precache just means it decodes on first paint instead.
    });
  }

  /// Emit one customization event with this screen's identifying fields.
  void track(BuildContext context, String event,
      {String? step, int? addOnId, String? value}) {
    final auth = Provider.of<KioskAuthProvider>(context, listen: false);
    String? guestId;
    try {
      guestId = Provider.of<AuthProvider>(context, listen: false).getGuestId();
    } catch (_) {
      // Guest id is a nice-to-have for the conversion join, never a requirement.
      guestId = null;
    }

    KioskCustomizeAnalytics.instance.track(
      event,
      experience: auth.orderingExperience,
      productId: product.id,
      branchId: auth.branchId,
      deviceId: auth.deviceId,
      guestId: guestId,
      step: step,
      addOnId: addOnId,
      value: value,
    );
  }

  /// Variation rules (same as the web app) for a subset of variation indexes.
  ///
  /// Version A passes every index at once; Version B passes only the indexes
  /// belonging to the step being left, so Next can gate on that step alone
  /// without complaining about a question the customer has not reached yet.
  ///
  /// [silent] suppresses the snackbar — used to compute whether Next should be
  /// enabled, where nagging on every rebuild would be wrong.
  bool _validateVariations(
    BuildContext context,
    ProductProvider productProvider,
    Iterable<int> indexes, {
    bool silent = false,
  }) {
    final variations = ProductHelper.effectiveVariations(product) ?? [];
    for (final int index in indexes) {
      if (index < 0 || index >= variations.length) continue;
      final v = variations[index];
      if (!v.isMultiSelect! &&
          v.isRequired! &&
          !productProvider.selectedVariations[index].contains(true)) {
        if (!silent) {
          showCustomSnackBarHelper(
            '${getTranslated('choose_a_variation_from', context)} ${v.name}',
            isError: true,
          );
        }
        return false;
      }
      if (v.isMultiSelect! &&
          (v.isRequired! ||
              productProvider.selectedVariations[index].contains(true)) &&
          v.min! >
              productProvider.selectedVariationLength(
                  productProvider.selectedVariations, index)) {
        if (!silent) {
          showCustomSnackBarHelper(
            '${getTranslated('you_need_to_select_minimum', context)} ${v.min}',
            isError: true,
          );
        }
        return false;
      }
    }
    return true;
  }

  /// Add-on group minimums. Unchanged from the original single-screen rules.
  bool _validateAddOnGroups(
    BuildContext context,
    ProductProvider productProvider, {
    bool silent = false,
  }) {
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
        if (!silent) {
          showCustomSnackBarHelper(
            '${getTranslated('choose_a_variation_from', context)} ${group.name ?? ''}',
            isError: true,
          );
        }
        return false;
      }
    }
    return true;
  }

  /// Full check, run before the cart write in BOTH versions.
  bool _validate(BuildContext context, ProductProvider productProvider) {
    final variations = ProductHelper.effectiveVariations(product) ?? [];
    return _validateVariations(
          context,
          productProvider,
          List.generate(variations.length, (i) => i),
        ) &&
        _validateAddOnGroups(context, productProvider);
  }

  void _addToCart(BuildContext context, ProductProvider productProvider) {
    if (!_validate(context, productProvider)) return;
    track(context, KioskCustomizeEvent.addToCartClicked);
    _completed = true;
    final CartModel built =
        buildKioskCartModel(context, product, instruction: instruction);
    final ValueChanged<CartModel>? configured = onConfigured;
    if (configured != null) {
      configured(built);
      Navigator.of(context).pop();
      return;
    }
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final int? index = cartIndex ?? productProvider.cartIndex;
    cartProvider.addToCart(built, index);
    if (replaceOtherProductLines &&
        product.id != null &&
        index != null &&
        index >= 0) {
      cartProvider.removeOtherLinesForProduct(product.id!, index);
    }

    // Confirmation beat, then back to the menu. pushReplacement swaps THIS
    // screen for the confirmation, so the stack stays [menu] -> [confirmation]
    // and dismissing lands on the menu exactly as the old straight pop did.
    // Read after the write, so the total shown includes the line just added.
    final splash = Provider.of<SplashProvider>(context, listen: false);
    Navigator.of(context).pushReplacement(
      KioskAddedToCartScreen.route(
        heroImage: KioskProductImageHelper.heroImageUrl(
          product: product,
          productImageBaseUrl: splash.baseUrls?.productImageUrl,
        ),
        // Same payable the cart bar and cart screen show, coupon included —
        // "your total has been updated" has to name the total they will see.
        totalLabel: PriceConverterHelper.convertPrice(kioskPayableTotal(
            cartProvider.cartList,
            Provider.of<CouponProvider>(context, listen: false).discount ?? 0)),
      ),
    );
  }
}

class KioskProductCustomizeScreen extends StatefulWidget {
  final Product product;
  final int? cartIndex;
  final String? initialInstruction;

  /// When true, saving replaces this product's cart line and drops any other
  /// leftover lines for the same product (menu tap reopened an existing item).
  final bool replaceOtherProductLines;
  final ValueChanged<CartModel>? onConfigured;
  const KioskProductCustomizeScreen({
    super.key,
    required this.product,
    this.cartIndex,
    this.initialInstruction,
    this.replaceOtherProductLines = false,
    this.onConfigured,
  });

  @override
  State<KioskProductCustomizeScreen> createState() =>
      _KioskProductCustomizeScreenState();
}

class _KioskProductCustomizeScreenState
    extends State<KioskProductCustomizeScreen>
    with _KioskCustomizeActions<KioskProductCustomizeScreen> {
  /// Per-line note. There is no longer a field for it on this screen — the note
  /// moved to a single order-level note on the cart — but an existing line's
  /// text is carried through so editing a line cannot silently wipe it.
  String? _instruction;

  @override
  Product get product => widget.product;
  @override
  int? get cartIndex => widget.cartIndex;
  @override
  String? get instruction => _instruction;
  @override
  bool get replaceOtherProductLines => widget.replaceOtherProductLines;
  @override
  ValueChanged<CartModel>? get onConfigured => widget.onConfigured;

  @override
  void initState() {
    super.initState();
    final String initial = widget.initialInstruction?.trim() ?? '';
    _instruction = initial.isEmpty ? null : initial;
    // After the first frame: `track` reads providers, which is not allowed
    // while the widget is still being mounted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      track(context, KioskCustomizeEvent.customizationStarted);
      precacheSuccessAnimation(context);
    });
  }

  @override
  void dispose() {
    // Left the screen without the line reaching the cart — unless an admin
    // live-switched Ordering Experience and this host remounted the other flow.
    final bool suppress = KioskCustomizeExperienceHost.suppressAbandonOnce;
    if (suppress) {
      KioskCustomizeExperienceHost.suppressAbandonOnce = false;
    }
    if (!_completed && !suppress) {
      KioskCustomizeAnalytics.instance.track(
        KioskCustomizeEvent.customizationAbandoned,
        experience: _lastExperience,
        productId: product.id,
      );
    }
    // Nothing else will run before the tab/route is gone, so push what is queued.
    unawaited(KioskCustomizeAnalytics.instance.flush());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Captured for [dispose], which runs after the element is unmounted and can
    // no longer reach a provider.
    _lastExperience = experienceOf(context);
    // Cup/can splits out so it renders with the big two-card style; the same
    // split drives Version B's steps (see [_CustomizeSections]).
    final sections = _CustomizeSections.of(product);
    final cupCanVariations = sections.cupCan;
    final sizeVariations = sections.size;
    final dietaryVariations = sections.dietary;
    final bool hasAddOns = product.effectiveAddOnGroups.isNotEmpty;

    return Scaffold(
      backgroundColor: KioskUI.pageBg,
      body: SafeArea(
        child: Consumer<ProductProvider>(
          builder: (context, productProvider, _) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final Size viewport =
                    Size(constraints.maxWidth, constraints.maxHeight);
                // How tall THIS product's page is on the artboard. The design is
                // 5400px because it draws three rows of add-ons; a product with
                // no add-ons and no cup/can question needs far less, and must
                // not be shrunk as though it needed the lot.
                //
                // ONE STACK IN EVERY ORIENTATION. Version A used to split a
                // landscape viewport into two columns — the header beside the
                // panels — and budget height for the taller column only. It now
                // renders the same single vertical column a phone gets, so the
                // artboard is always the STACKED height: header, then every
                // panel, then the action bar. Passing the landscape height here
                // would under-budget the page and scale it up until the stack
                // ran off the bottom. (Version B still splits, and still asks
                // for the landscape height — see the step flow.)
                final double artboard = kioskCustomizeArtboardHeight(
                  hasDescription: kioskProductDescription(product).isNotEmpty,
                  variationPanels: (sizeVariations.isEmpty ? 0 : 1) +
                      dietaryVariations.length,
                  hasAddOns: hasAddOns,
                  hasVessel: cupCanVariations.isNotEmpty,
                );
                // ONE scale for the whole screen, bounded by the viewport's
                // width AND its height — see [kioskCustomizeScale].
                final double s = kioskCustomizeScale(
                    viewport: viewport, artboardHeight: artboard);
                // A viewport too short for the stack buys height back from the
                // hero photo rather than from the type: at the floored scale a
                // landscape window would otherwise open on a half-screen
                // product shot with the first question already below the fold.
                // 1.0 — the design's own hero — everywhere the page fits.
                final double heroFactor = kioskCustomizeHeroFactor(
                  viewport: viewport,
                  artboardHeight: artboard,
                  scale: s,
                  hasDescription: kioskProductDescription(product).isNotEmpty,
                );
                final double pageHeight = kioskCustomizeArtboardWithHero(
                    artboardHeight: artboard, heroFactor: heroFactor);
                // Fits -> the pinned Figma layout, where the add-on grid is the
                // only thing that scrolls. Does not fit (a short landscape
                // window) -> the options scroll as one block, with the action
                // bar still pinned so it can never cover them.
                final bool pinned = kioskCustomizeFits(
                    viewport: viewport, artboardHeight: pageHeight, scale: s);
                final double gutter = KioskCustomizeSpec.gutter * s;
                final double panelGap = KioskCustomizeSpec.panelGap * s;

                // The header sits at the top of the page in every orientation,
                // so it carries the design's back button in its own top-left
                // corner. (Version B's landscape split centres the header in a
                // column, which would ride the button down to the middle of the
                // page — that flow draws the button itself instead.)
                final Widget header = _Header(
                  s: s,
                  heroFactor: heroFactor,
                  product: product,
                  productProvider: productProvider,
                );

                // Allergen disclosure sits ABOVE the first panel — i.e. above
                // Size — so it is read before any choice is made rather than
                // after. It is not a panel: it is a left-aligned strip, and it
                // is absent entirely for a product that declares nothing.
                //
                // Prepended to this list rather than inserted into each of the
                // two layout branches below, so the pinned page and the
                // scrolling page place it identically.
                final Widget? allergenNotice =
                    KioskAllergenNotice.maybe(s: s, product: product);

                // Size first, then each dietary group, each in its own panel.
                final List<Widget> variationPanels = [
                  if (allergenNotice != null) allergenNotice,
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
                ];
                final Widget? addOns = hasAddOns
                    ? _AddOnsSection(
                        s: s,
                        product: product,
                        productProvider: productProvider,
                        // Pinned layout: the panel keeps its own scroller.
                        // Scrolling layout: it sizes to its content and rides
                        // the page scroller instead, so there are never two
                        // scrollers nested.
                        scrollable: pinned,
                        // NO INDICATORS ON THIS SCREEN. Everything here still
                        // scrolls; nothing here draws a bar to say so.
                        showIndicator: false,
                      )
                    : null;
                final List<Widget> vesselPanels = [
                  for (final entry in cupCanVariations)
                    _CupCanSection(
                      s: s,
                      variation: entry.value,
                      variationIndex: entry.key,
                      product: product,
                      productProvider: productProvider,
                    ),
                ];
                final Widget actionBar = _ActionBar(
                  s: s,
                  product: product,
                  productProvider: productProvider,
                  onAddToCart: () => _addToCart(context, productProvider),
                );

                return KioskCenteredContent(
                  // Fill the shell the same way the menu does. The old
                  // `2572 * s` cap shrank the column when height pulled scale
                  // down, leaving beige gutters on both sides. Type and chrome
                  // still scale with `s`; cards divide whatever width remains
                  // after the theme gutter (86 artboard px, matching the
                  // menu's 85). KioskShell already caps at the artboard.
                  maxWidth: constraints.maxWidth,
                  child: Column(
                    children: [
                      if (pinned) ...[
                        // Product image, name, description and the quantity
                        // stepper stay put — only the add-ons below them scroll.
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: gutter),
                          child: header,
                        ),
                        SizedBox(height: KioskCustomizeSpec.headerToPanels * s),
                        // VARIATIONS ARE PINNED. Each is a single line that
                        // scrolls sideways, and none of them sit in a vertical
                        // scroller — so a size or milk row can only ever move
                        // horizontally, never up and down with the page.
                        for (int i = 0; i < variationPanels.length; i++) ...[
                          if (i > 0) SizedBox(height: panelGap),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: gutter),
                            child: variationPanels[i],
                          ),
                        ],
                        // ADD-ONS ARE THE ONLY VERTICAL SCROLLER. They take
                        // whatever height is left and scroll inside it, with the
                        // design's black-on-#B9B5A6 indicator.
                        if (addOns != null) ...[
                          if (variationPanels.isNotEmpty)
                            SizedBox(height: panelGap),
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: gutter),
                              child: addOns,
                            ),
                          ),
                        ] else
                          const Spacer(),
                        // Cup / can and the action bar are both pinned to the
                        // bottom, per the design: the vessel is the last
                        // decision before adding, so it must not scroll away.
                        for (final panel in vesselPanels) ...[
                          SizedBox(height: panelGap),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: gutter),
                            child: panel,
                          ),
                        ],
                      ] else
                        Expanded(
                          // Bare: the page drags, and says nothing about it.
                          // Flutter's own behaviour would hang a scrollbar down
                          // the right edge of a desktop or web build — the
                          // kiosk's browser included — and this screen draws no
                          // indicators at all.
                          child: ScrollConfiguration(
                            behavior: ScrollConfiguration.of(context)
                                .copyWith(scrollbars: false),
                            child: SingleChildScrollView(
                              padding: EdgeInsets.symmetric(horizontal: gutter),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  header,
                                  SizedBox(
                                      height:
                                          KioskCustomizeSpec.headerToPanels *
                                              s),
                                  for (int i = 0;
                                      i < variationPanels.length;
                                      i++) ...[
                                    if (i > 0) SizedBox(height: panelGap),
                                    variationPanels[i],
                                  ],
                                  if (addOns != null) ...[
                                    if (variationPanels.isNotEmpty)
                                      SizedBox(height: panelGap),
                                    addOns,
                                  ],
                                  for (final panel in vesselPanels) ...[
                                    SizedBox(height: panelGap),
                                    panel,
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      actionBar,
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

/// The product's blurb with the CMS markup stripped. Lives here rather than in
/// the header so the scale rule can ask the same question before laying out.
String kioskProductDescription(Product product) =>
    (product.description ?? '').replaceAll(RegExp(r'<[^>]*>'), '').trim();

/// Product header: back button pinned top-left, then the hero photo, name,
/// description and quantity stepper, all centred — Figma `Group 93`/`94`/`95`.
///
/// ONE header for every viewport. The screen used to carry a second "compact"
/// variant because scaling by width alone left no room for the real one on a
/// short window; the scale is height-aware now, so the design's own header fits
/// everywhere and the duplicate — with its own smaller photo, its own type
/// sizes and its own spacing — is gone.
class _Header extends StatelessWidget {
  final double s;
  final Product product;
  final ProductProvider productProvider;

  /// How much of the hero block this viewport can afford — 1.0 on every screen
  /// the page fits, less only where the photo has to give height back to the
  /// questions below it. See [kioskCustomizeHeroFactor]. Type is never touched:
  /// the name, the blurb and the stepper stay at `s` whatever happens.
  final double heroFactor;

  /// Version B draws its own back button beside the progress bar, so it asks
  /// the header to skip the one in the corner rather than showing two.
  final bool showBackButton;
  const _Header({
    required this.s,
    required this.product,
    required this.productProvider,
    this.heroFactor = 1.0,
    this.showBackButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final splash = Provider.of<SplashProvider>(context, listen: false);
    final String heroImage = KioskProductImageHelper.heroImageUrl(
      product: product,
      productImageBaseUrl: splash.baseUrls?.productImageUrl,
    );
    final String description = kioskProductDescription(product);

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: KioskCustomizeSpec.heroTop * s * heroFactor),
            // Figma hero: a 453x731 portrait box, centred — so a landscape
            // photo letterboxes inside it instead of stretching to the panel.
            // Both edges take [heroFactor], so a shrunken hero is the same box
            // at a smaller size rather than a squashed one.
            Center(
              child: SizedBox(
                width: KioskCustomizeSpec.heroWidth * s * heroFactor,
                height: KioskCustomizeSpec.heroHeight * s * heroFactor,
                child: CustomImageWidget(
                  key: ValueKey(heroImage),
                  placeholder: Images.placeholderImage,
                  image: heroImage,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            SizedBox(height: KioskCustomizeSpec.heroToTitle * s * heroFactor),
            Text(
              product.name ?? '',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              // (inspect) Loew / ExtraBold / 72px / line-height 100%.
              style: loewExtraBold.copyWith(
                fontSize: KioskCustomizeSpec.titleSize * s,
                height: 1.0,
                color: Colors.black,
              ),
            ),
            if (description.isNotEmpty) ...[
              SizedBox(height: KioskCustomizeSpec.titleToDescription * s),
              Text(
                description,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                // (inspect) Swiss 721 Light / 48px.
                style: swiss721Light.copyWith(
                  fontSize: KioskCustomizeSpec.descriptionSize * s,
                  height: KioskCustomizeSpec.descriptionLineHeight,
                  color: Colors.black,
                ),
              ),
            ],
            SizedBox(height: KioskCustomizeSpec.descriptionToStepper * s),
            _QuantityStepper(s: s, productProvider: productProvider),
          ],
        ),
        // The photo starts above the button's baseline in the design, which is
        // why this is a Stack: the back button sits over the header rather than
        // pushing the centred block down or off-centre.
        if (showBackButton)
          Positioned(
            left: 0,
            top: KioskCustomizeSpec.backButtonTop * s,
            child: KioskBackButton(
              size: KioskCustomizeSpec.backButton * s,
              borderWidth: _border(KioskCustomizeSpec.backButtonBorder, s),
              iconSize: KioskCustomizeSpec.backButtonIcon * s,
              fallback: RouterHelper.getKioskMenuRoute,
            ),
          ),
      ],
    );
  }
}

/// Figma `Group 95`: two 150x114 buttons hugging a 256.5-wide digit box.
class _QuantityStepper extends StatelessWidget {
  final double s;
  final ProductProvider productProvider;
  const _QuantityStepper({required this.s, required this.productProvider});

  @override
  Widget build(BuildContext context) {
    final int qty = productProvider.quantity ?? 1;
    final double width = KioskCustomizeSpec.stepperButtonWidth * s;
    final double height = KioskCustomizeSpec.stepperButtonHeight * s;
    final double glyph = KioskCustomizeSpec.stepperGlyphSize * s;
    final double radius = KioskCustomizeSpec.stepperRadius * s;
    final double border = _border(KioskCustomizeSpec.stepperBorder, s);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepperButton(
          width: width,
          height: height,
          radius: radius,
          borderWidth: border,
          glyphSize: glyph,
          label: '-',
          filled: false,
          onTap: () => qty > 1 ? productProvider.setQuantity(false) : null,
        ),
        SizedBox(
          width: KioskCustomizeSpec.stepperDigitWidth * s,
          child: Text(
            '$qty',
            textAlign: TextAlign.center,
            style: loewExtraBold.copyWith(
                fontSize: glyph, height: 1.0, color: Colors.black),
          ),
        ),
        _StepperButton(
          width: width,
          height: height,
          radius: radius,
          borderWidth: border,
          glyphSize: glyph,
          label: '+',
          filled: true,
          onTap: () => productProvider.setQuantity(true),
        ),
      ],
    );
  }
}

/// One −/+ box. Figma draws the minus as an outline on the page cream and the
/// plus as the same box filled black with a cream glyph, at both sizes it is
/// used (the header stepper and the one inside a selected add-on card).
class _StepperButton extends StatelessWidget {
  final double width;
  final double height;
  final double radius;
  final double borderWidth;
  final double glyphSize;
  final String label;
  final bool filled;

  /// Add-on cards sit on the panel cream, so their idle box is filled and
  /// outlined in the panel border rather than left transparent.
  final Color? background;
  final Color? borderColor;
  final VoidCallback? onTap;
  const _StepperButton({
    required this.width,
    required this.height,
    required this.radius,
    required this.borderWidth,
    required this.glyphSize,
    required this.label,
    required this.filled,
    required this.onTap,
    this.background,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? Colors.black : (background ?? Colors.transparent),
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: KioskTap(
        onTap: onTap,
        child: Container(
          width: width,
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: filled ? Colors.black : (borderColor ?? Colors.black),
              width: borderWidth,
            ),
          ),
          child: Text(
            label,
            style: loewExtraBold.copyWith(
              fontSize: glyphSize,
              height: 1.0,
              color: filled ? _kCreamText : Colors.black,
            ),
          ),
        ),
      ),
    );
  }
}

/// Figma `qty-counter`: three 72px boxes 12 apart, inside a selected add-on.
class _CardQtyStepper extends StatelessWidget {
  final int quantity;

  /// Card-relative scale — the card's width over the artboard card's, so the
  /// stepper is always the same fraction of the card it sits in.
  final double k;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;
  const _CardQtyStepper({
    required this.quantity,
    required this.k,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    final double button = KioskCustomizeSpec.addOnQtyButton * k;
    final double gap = KioskCustomizeSpec.addOnQtyGap * k;
    final double glyph = KioskCustomizeSpec.addOnQtyGlyph * k;
    final double radius = KioskCustomizeSpec.addOnQtyRadius * k;
    final double border = _border(KioskCustomizeSpec.addOnCardBorder, k);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepperButton(
          width: button,
          height: button,
          radius: radius,
          borderWidth: border,
          glyphSize: glyph,
          label: '-',
          filled: false,
          background: _kPanelBg,
          borderColor: _kPanelBorder,
          onTap: onDecrement,
        ),
        SizedBox(width: gap),
        SizedBox(
          width: button,
          height: button,
          child: Center(
            child: Text(
              '$quantity',
              style: loewExtraBold.copyWith(
                  fontSize: glyph, height: 1.0, color: Colors.black),
            ),
          ),
        ),
        SizedBox(width: gap),
        _StepperButton(
          width: button,
          height: button,
          radius: radius,
          borderWidth: border,
          glyphSize: glyph,
          label: '+',
          filled: true,
          onTap: onIncrement,
        ),
      ],
    );
  }
}

/// One row of option cards that scrolls sideways.
///
/// The kiosk has no visible horizontal scrollbar in the design, so the row is
/// laid out with the cards at the width the panel divides into and simply
/// overflows into a drag. The row is given ONE height and every card is built
/// at it, which is what keeps a row of cards level instead of ragged — a Row
/// lets each child size itself, and that is how the old grid ended up with a
/// short card beside a tall empty one.
/// A column of sections that CENTRES itself while there is room and scrolls
/// the moment there is not.
///
/// The customize page is scaled by width whenever the window is wider than it
/// is tall relative to the 2572x5400 artboard — a 1512px browser window puts
/// the page at ~0.59 — and that leaves vertical slack no element claims. Every
/// column here used to be top-aligned, so the slack collected in one block at
/// the bottom: a Size panel hanging off the progress bar with a third of the
/// screen empty under it, and, in the three-step flow's portrait layout, most
/// of a 1920px kiosk.
///
/// Centring spends the slack evenly above and below instead, which reads as
/// deliberate whitespace rather than a layout that ran out of content. Nothing
/// is clipped when the slack runs out: past that point [Column] is taller than
/// [minHeight], the alignment stops having anything to distribute, and the
/// scroll view takes over exactly as it did before.
///
/// Do NOT put a section that wants to FILL its column in here — the add-ons
/// panel ([_AddOnsSection] with `scrollable: true`) sizes itself to the height
/// it is given, and a scroll view gives it an unbounded one. That panel is
/// already its own absorber for the slack, which is why the add-ons step needs
/// none of this.
class _FittedColumn extends StatefulWidget {
  /// Page scale, for the scroll indicator's thickness only.
  final double s;
  final EdgeInsets padding;
  final List<Widget> children;
  const _FittedColumn({
    required this.s,
    this.padding = EdgeInsets.zero,
    required this.children,
  });

  @override
  State<_FittedColumn> createState() => _FittedColumnState();
}

class _FittedColumnState extends State<_FittedColumn> {
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _reveal();
  }

  @override
  void didUpdateWidget(covariant _FittedColumn oldWidget) {
    super.didUpdateWidget(oldWidget);
    _reveal();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// See [_AddOnScrollBoxState._reveal] — a scrollbar that has never seen a
  /// scroll notification renders nothing, so a column that IS overflowing
  /// would give no sign of it until the customer happened to drag.
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
    final double thickness = _kScrollbarWidth * widget.s;
    return LayoutBuilder(
      builder: (context, constraints) {
        // An unbounded parent (never the case for the two-column row or a
        // step body, both of which sit in an Expanded) simply gets the plain
        // content height.
        final double room = constraints.maxHeight.isFinite
            ? math.max(0.0, constraints.maxHeight - widget.padding.vertical)
            : 0.0;
        return ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          // The indicator paints nothing while the content fits — which is the
          // centred case, every time — so this costs the balanced layout
          // nothing and only appears on the viewport that genuinely has to
          // scroll, where a panel otherwise just ran off under the action bar
          // with no sign there was more of it. The thumb rides the page gutter
          // rather than the panel because [padding] is applied INSIDE the
          // scroll view.
          child: RawScrollbar(
            controller: _controller,
            thumbVisibility: true,
            interactive: true,
            thickness: thickness,
            radius: Radius.circular(_kScrollbarRadius * widget.s),
            thumbColor: _kScrollThumb,
            child: SingleChildScrollView(
              controller: _controller,
              padding: widget.padding,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: room),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: widget.children,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HorizontalOptionRow extends StatelessWidget {
  final double s;
  final double gap;
  final double Function(double cardWidth) heightOf;
  final List<Widget> Function(double cardWidth, double cardHeight) builder;
  const _HorizontalOptionRow({
    required this.s,
    required this.gap,
    required this.heightOf,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final double cardWidth = _choiceTileWidth(
        viewportWidth: MediaQuery.sizeOf(context).width,
        panelWidth: constraints.maxWidth,
        s: s,
        gap: gap,
      );
      final double cardHeight = heightOf(cardWidth);
      final List<Widget> children = builder(cardWidth, cardHeight);
      return SizedBox(
        width: double.infinity,
        height: cardHeight,
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            // Card width follows the ARTBOARD's density — seven across a kiosk
            // panel — so a question with three answers fills three sevenths of
            // the row and the rest is panel. Left-aligned that reads as a row
            // that failed to load; centred it reads as three cards. The row
            // still starts flush left the moment the cards fill it, which is
            // the case the design draws and the case that scrolls.
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int i = 0; i < children.length; i++) ...[
                    if (i > 0) SizedBox(width: gap),
                    children[i],
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}

/// Add-on grid with the design's own scroller — Figma draws a #000000 thumb on
/// a #B9B5A6 track, 20px wide with a 15px radius, rather than letting the
/// add-ons run on down the page.
///
/// [showIndicator] draws that thumb. The single screen turns it off: it is the
/// one page where the add-ons sit under a header and above cup/can, and a
/// second bar of chrome inside the panel — on a page the customer is already
/// dragging — reads as clutter rather than as a hint. The panel still scrolls;
/// only the indicator is gone, and with it the strip of width it reserved.
class _AddOnScrollBox extends StatefulWidget {
  final double s;
  final Widget child;
  final bool showIndicator;
  const _AddOnScrollBox({
    required this.s,
    required this.child,
    this.showIndicator = true,
  });

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
    if (!widget.showIndicator) return;
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
    final double thickness = _kScrollbarWidth * s;

    final Widget scroller = SingleChildScrollView(
      controller: _controller,
      // The reserved strip belongs to the thumb. Without one the cards take
      // the full panel width, so hiding the indicator never leaves a margin
      // with nothing in it.
      padding: widget.showIndicator
          ? EdgeInsets.only(right: thickness + _addOnGap(s) * 2)
          : EdgeInsets.zero,
      child: widget.child,
    );

    // No height of its own: this lives in an Expanded and fills whatever the
    // pinned header, variations, cup/can and action bar leave behind.
    return SizedBox(
      width: double.infinity,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: widget.showIndicator
            ? RawScrollbar(
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
                child: scroller,
              )
            : scroller,
      ),
    );
  }
}

/// Figma `Rectangle 62`: a cream panel with a hairline border and a 30px
/// radius, titled in Loew ExtraBold 72.
class _SectionPanel extends StatelessWidget {
  final double s;
  final String title;

  /// Let the child take the panel's remaining height instead of sizing to its
  /// content. Used by the add-ons panel so its scroller — and therefore the
  /// scroll indicator — lives INSIDE the panel box rather than beside it.
  final bool fill;

  /// Tighter title/padding chrome. Used by cup/can so the last section
  /// shrinks as a whole, not only its inner cards.
  final bool compact;
  final Widget child;
  const _SectionPanel({
    required this.s,
    required this.title,
    required this.child,
    this.fill = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final double padScale = compact ? 0.55 : 1.0;
    final double bottomScale = compact ? 0.35 : 1.0;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        KioskCustomizeSpec.panelPadH * s,
        KioskCustomizeSpec.panelPadTop * padScale * s,
        KioskCustomizeSpec.panelPadH * s,
        KioskCustomizeSpec.panelPadBottom * bottomScale * s,
      ),
      decoration: BoxDecoration(
        color: _kPanelBg,
        borderRadius: BorderRadius.circular(KioskCustomizeSpec.panelRadius * s),
        border: Border.all(color: _kPanelBorder, width: _border(1, s)),
      ),
      child: Column(
        mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: loewExtraBold.copyWith(
              fontSize: KioskCustomizeSpec.panelTitleSize * s,
              height: 1.0,
              color: Colors.black,
            ),
          ),
          SizedBox(height: KioskCustomizeSpec.panelTitleGap * padScale * s),
          if (fill) Expanded(child: child) else child,
        ],
      ),
    );
  }
}

/// Small / Medium / Large as one panel: title + one horizontal card row.
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
    // Flatten the groups first. Every size card uses the same compact
    // image → name → price box as add-ons; missing option art leaves a blank
    // slot (never the product photo).
    final options = [
      for (final entry in entries)
        for (int i = 0; i < (entry.value.variationValues?.length ?? 0); i++)
          (
            index: entry.key,
            valueIndex: i,
            variation: entry.value,
            value: entry.value.variationValues![i],
            image: _choiceImageUrl(
              KioskProductImageHelper.optionCardImageUrl(
                value: entry.value.variationValues![i],
                productImageBaseUrl: splash.baseUrls?.productImageUrl,
              ),
            ),
          ),
    ];
    const bool showImage = true;
    const bool showPrice = true;

    return _SectionPanel(
      s: s,
      title: getTranslated('size', context) ?? 'Size',
      // Size is a variation, so it follows the same rule as the dietary row:
      // always one line that scrolls sideways, never wrapping onto a second.
      child: _HorizontalOptionRow(
        s: s,
        gap: _choiceGap(s),
        heightOf: (width) =>
            _optionCardHeight(width, showImage: true, showPrice: true),
        builder: (cardWidth, cardHeight) => [
          for (final option in options)
            _DietaryCard(
              width: cardWidth,
              height: cardHeight,
              name: (option.value.level ?? option.variation.name ?? '').trim(),
              priceDelta: option.value.optionPrice ?? 0,
              image: option.image,
              showImage: showImage,
              showPrice: showPrice,
              selected: productProvider.selectedVariations[option.index]
                      [option.valueIndex] ??
                  false,
              onTap: () {
                productProvider.setCartVariationIndex(
                  option.index,
                  option.valueIndex,
                  product,
                  option.variation.isMultiSelect!,
                );
                productProvider.checkIsRequiredSelected(
                  index: option.index,
                  isMultiSelect: option.variation.isMultiSelect!,
                  variations: productProvider.selectedVariations[option.index],
                  min: option.variation.min,
                  max: option.variation.max,
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

    final List<String> images = [
      for (final value in values)
        _choiceImageUrl(
          KioskProductImageHelper.optionCardImageUrl(
            value: value,
            productImageBaseUrl: splash.baseUrls?.productImageUrl,
          ),
        ),
    ];
    const bool showImage = true;
    const bool showPrice = true;

    return _SectionPanel(
      s: s,
      title: title,
      // Figma keeps the dietary options on ONE row that scrolls sideways, so a
      // product with many milks never grows the panel vertically and pushes the
      // add-ons off screen — it just scrolls.
      child: _HorizontalOptionRow(
        s: s,
        gap: _choiceGap(s),
        heightOf: (width) =>
            _optionCardHeight(width, showImage: true, showPrice: true),
        builder: (cardWidth, cardHeight) => List.generate(values.length, (i) {
          final bool selected =
              productProvider.selectedVariations[variationIndex][i] ?? false;
          return _DietaryCard(
            width: cardWidth,
            height: cardHeight,
            name: values[i].level?.trim() ?? '',
            priceDelta: values[i].optionPrice ?? 0,
            image: images[i],
            showImage: showImage,
            showPrice: showPrice,
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

/// Figma `Group 98`: a 407.8x449.4 cream card — artwork, an uppercase Loew
/// Medium label and a radio in the top-right corner.
///
/// Everything inside is a fraction of the card's OWN width (`k`), which is what
/// makes the card the same shape on a phone-width window and a 4K kiosk. The
/// height comes from the row, so every card in a row matches.
class _DietaryCard extends StatelessWidget {
  final double width;
  final double height;
  final String name;
  final double priceDelta;
  final String image;

  /// Whether this ROW reserves an image slot / a price line. Decided per group,
  /// not per card, so every card in a row is the same shape — a group where no
  /// option has artwork drops the slot entirely and gets a compact text card.
  final bool showImage;
  final bool showPrice;
  final bool selected;
  final VoidCallback onTap;
  const _DietaryCard({
    required this.width,
    required this.height,
    required this.name,
    required this.priceDelta,
    required this.image,
    required this.showImage,
    required this.showPrice,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double k = width / KioskCustomizeSpec.choiceCardWidth;
    final double radius = KioskCustomizeSpec.optionCardRadius * k;
    final double padTop = showImage
        ? KioskCustomizeSpec.optionPadTop
        // Nothing to tuck the radio over, so the label starts below it.
        : KioskCustomizeSpec.optionRadioInset * 2 +
            KioskCustomizeSpec.optionRadio;
    final double nameSize = _choiceLabelSize(context, width);
    final Widget label = Text(
      name.toUpperCase(),
      textAlign: TextAlign.center,
      maxLines: _kCardLabelLines,
      overflow: TextOverflow.ellipsis,
      style: loewMedium.copyWith(
        fontSize: nameSize,
        height: 1.15,
        color: Colors.black,
      ),
    );
    final Widget price = Text(
      priceDelta > 0 ? _addonPriceLabel(priceDelta) : '',
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: swiss721Light.copyWith(
        fontSize: nameSize * (42 / 45),
        height: 1.0,
        color: Colors.black,
      ),
    );

    return Material(
      color: _kPanelBg,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: KioskTap(
        onTap: onTap,
        // The size is fixed by the row and must change in ONE frame; only the
        // outline animates. An AnimatedContainer that also tweens width and
        // height spends 160ms at a size its contents were never measured for,
        // which on a viewport change reads as a flash of overflowing card.
        child: SizedBox(
          width: width,
          height: height,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            decoration: BoxDecoration(
              color: _kPanelBg,
              borderRadius: BorderRadius.circular(radius),
            ),
            // The outline is painted OVER the card, not inset into it: a
            // decoration border shrinks the box it wraps, so the card would
            // lose height to it — more when selected than not — and the
            // contents measured against the card's own height would overflow.
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: selected ? _kCardBorderSelected : _kCardIdleBorder,
                width: _border(
                  selected
                      ? KioskCustomizeSpec.optionCardBorderSelected
                      : KioskCustomizeSpec.optionCardBorder,
                  k,
                ),
              ),
            ),
            child: Stack(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    KioskCustomizeSpec.optionPadH * k,
                    padTop * k,
                    KioskCustomizeSpec.optionPadH * k,
                    KioskCustomizeSpec.optionPadBottom * k,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (showImage) ...[
                        Expanded(
                          child: _OptionImageSlot(
                              image: image, fit: BoxFit.contain),
                        ),
                        SizedBox(height: KioskCustomizeSpec.optionImageGap * k),
                        label,
                        if (showPrice) ...[
                          SizedBox(
                              height:
                                  KioskCustomizeSpec.optionImageGap * 0.5 * k),
                          price,
                        ],
                      ] else
                        // Nothing to flex against, so the text block takes the
                        // card and centres itself in it. A fixed column here is
                        // what overflowed when a font rounded a fraction up.
                        Expanded(
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                label,
                                if (showPrice) ...[
                                  SizedBox(
                                      height:
                                          KioskCustomizeSpec.optionImageGap *
                                              0.5 *
                                              k),
                                  price,
                                ],
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Positioned(
                  top: KioskCustomizeSpec.optionRadioInset * k,
                  right: KioskCustomizeSpec.optionRadioInset * k,
                  child: _RadioDot(
                      size: KioskCustomizeSpec.optionRadio * k,
                      selected: selected),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Figma `Ellipse 22`: a hollow ring that fills in when the option is chosen.
class _RadioDot extends StatelessWidget {
  /// Sized by the card it sits on, so it shrinks with the card instead of
  /// holding an artboard size the shrunken card can no longer carry.
  final double size;
  final bool selected;
  const _RadioDot({required this.size, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.transparent,
        border: Border.all(color: Colors.black, width: _border(size * 0.08, 1)),
      ),
      alignment: Alignment.center,
      child: selected
          ? Container(
              width: size * 0.52,
              height: size * 0.52,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black,
              ),
            )
          : null,
    );
  }
}

/// Add-ons: grouped like Lightspeed. Single-choice groups act as radios.
class _AddOnsSection extends StatelessWidget {
  final double s;
  final Product product;
  final ProductProvider productProvider;

  /// True in the pinned layout, where this panel owns the screen's only
  /// vertical scroller. False when the whole page already scrolls, so the grid
  /// sizes to its content instead of nesting a second scroller inside one.
  final bool scrollable;

  /// Height the panel may occupy, when the caller knows it — the three-step
  /// flow, where this panel has a whole column to itself.
  ///
  /// Given it, the panel keeps only as many WHOLE rows of cards as that height
  /// allows and scrolls the rest inside itself, so a large display shows a
  /// compact two-row grid with the design's own indicator beside it rather than
  /// a panel stretched the full height of the screen with a row sliced through
  /// the middle at the fold. Whatever height it does not use goes back to the
  /// step, which centres the panel in it — that is where the air above and
  /// below the panel comes from.
  ///
  /// Null (Version A) leaves the panel exactly as it was: [scrollable] alone
  /// decides between filling its slot and sizing to its content.
  final double? maxHeight;

  /// Draw the design's scroll thumb beside the cards. The three-step flow does
  /// — the add-ons are a step of their own there, and the indicator is what
  /// says the grid continues past the last visible row. The single screen does
  /// not: see [_AddOnScrollBox].
  final bool showIndicator;
  const _AddOnsSection({
    required this.s,
    required this.product,
    required this.productProvider,
    this.scrollable = true,
    this.maxHeight,
    this.showIndicator = true,
  });

  /// Height of the panel's chrome — padding, title, and the gap under it.
  /// Mirrors [_SectionPanel.build] for the non-compact case this panel uses.
  double get _chrome =>
      KioskCustomizeSpec.panelPadTop * s +
      KioskCustomizeSpec.panelTitleSize * 1.295 * s +
      KioskCustomizeSpec.panelTitleGap * s +
      KioskCustomizeSpec.panelPadBottom * s;

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

    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < groups.length; i++) ...[
          if (!single) ...[
            if (i > 0)
              SizedBox(height: KioskCustomizeSpec.panelTitleGap * 0.5 * s),
            Padding(
              padding:
                  EdgeInsets.only(bottom: KioskCustomizeSpec.addOnCardGap * s),
              child: Text(
                _addonGroupTitle(context, groups[i]),
                style: loewBold.copyWith(
                  fontSize: KioskCustomizeSpec.optionLabelSize * s,
                  height: 1.2,
                  color: Colors.black,
                ),
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
    );

    final Widget panelChild = scrollable || maxHeight != null
        ? _AddOnScrollBox(s: s, showIndicator: showIndicator, child: content)
        : content;

    return _SectionPanel(
      s: s,
      // A capped panel hugs the box below; only the uncapped pinned layout
      // still stretches to fill its slot.
      fill: scrollable && maxHeight == null,
      title: single
          ? _addonGroupTitle(context, groups.first)
          : (getTranslated('add_add_ons', context) ?? 'Add add-ons'),
      child: maxHeight == null
          ? panelChild
          : LayoutBuilder(
              builder: (context, constraints) => SizedBox(
                height: _boxHeight(
                  context,
                  gridWidth: constraints.maxWidth,
                  groups: groups,
                  single: single,
                ),
                child: panelChild,
              ),
            ),
    );
  }

  /// Visible height of the card area: the tallest whole number of card rows
  /// that fits [maxHeight], never more than the grid actually needs.
  ///
  /// Snapping to whole rows is the point. A box sized to whatever height was
  /// left over cuts the last row in half at the fold, which is the one thing a
  /// grid of tappable cards must not do — a half card reads as a broken image,
  /// not as "scroll for more". The indicator does that job instead.
  double _boxHeight(
    BuildContext context, {
    required double gridWidth,
    required List<AddOnGroup> groups,
    required bool single,
  }) {
    final double gap = _choiceGap(s);
    // [_AddOnScrollBox] reserves this much on the right for its indicator, so
    // the cards divide what is left — the same width they will actually get.
    // No indicator, no strip.
    final double cardsWidth = math.max(
        1.0,
        gridWidth -
            (showIndicator ? _kScrollbarWidth * s + _addOnGap(s) * 2 : 0));
    // The same tile [_GroupedAddOnCards] will build, or the row pitch measured
    // here would not be the pitch on screen.
    final double cardWidth = _choiceGridTileWidth(
      viewportWidth: MediaQuery.sizeOf(context).width,
      panelWidth: cardsWidth,
      s: s,
      gap: gap,
    );
    final double cardHeight = _choiceCardHeight(cardWidth);
    // How many of THAT tile the Wrap will actually put on a line. Asking
    // [kioskOptionColumns] for the design's density instead would answer for a
    // card the grid is not building — on a phone, where the cap has already
    // decided the density, it says six where three go across.
    final int columns =
        math.max(1, ((cardsWidth + gap) / (cardWidth + gap)).floor());

    // What the grid needs in full, headings included.
    final double headingHeight =
        KioskCustomizeSpec.optionLabelSize * s * 1.2 + _addOnGap(s);
    double content = 0;
    int cardRows = 0;
    for (int i = 0; i < groups.length; i++) {
      if (!single) {
        if (i > 0) content += KioskCustomizeSpec.panelTitleGap * 0.5 * s;
        content += headingHeight;
      }
      final int shown = [
        for (final addon in groups[i].addons)
          if (product.indexOfAddOn(addon.id) != null) addon,
      ].length;
      final int rows = (shown / columns).ceil();
      cardRows += rows;
      content += rows * cardHeight + math.max(0, rows - 1) * gap;
    }

    final double room = math.max(0.0, (maxHeight ?? 0) - _chrome);
    if (content <= room) return content;

    // Several groups interleave headings with rows, so there is no single row
    // pitch to snap to; those take the room as given.
    if (!single) return room;

    final int fit = math.max(1, ((room + gap) / (cardHeight + gap)).floor());
    final int rows = math.min(fit, math.max(1, cardRows));
    return rows * cardHeight + math.max(0, rows - 1) * gap;
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

  /// Report an add-on toggle. Rendered identically by both versions, so this is
  /// the one place either flow records a `addon_selected`/`addon_deselected`.
  void _trackAddOn(BuildContext context, bool nowSelected, AddOns addon) {
    final auth = Provider.of<KioskAuthProvider>(context, listen: false);
    KioskCustomizeAnalytics.instance.track(
      nowSelected
          ? KioskCustomizeEvent.addOnSelected
          : KioskCustomizeEvent.addOnDeselected,
      experience: auth.orderingExperience,
      productId: product.id,
      branchId: auth.branchId,
      deviceId: auth.deviceId,
      addOnId: addon.id,
      value: addon.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<int> groupIndexes = [
      for (final addon in group.addons)
        if (product.indexOfAddOn(addon.id) != null)
          product.indexOfAddOn(addon.id)!,
    ];

    // Cards only — the heading and the panel chrome belong to _AddOnsSection,
    // so every group shares one panel and one scroller.
    return LayoutBuilder(builder: (context, constraints) {
      final double gap = _choiceGap(s);
      // Same compact tile as the size / dietary row, so Addon1 and Small
      // are the same shape. This is a WRAPPING grid, so on a phone the cards
      // divide the row they are given rather than stopping at the cap and
      // leaving the rest of the panel empty — see [_choiceGridTileWidth].
      final double cardWidth = _choiceGridTileWidth(
        viewportWidth: MediaQuery.sizeOf(context).width,
        panelWidth: constraints.maxWidth,
        s: s,
        gap: gap,
      );
      const bool showImage = true;
      const bool showPrice = true;
      // Image is always reserved, so a selected multi add-on absorbs the
      // stepper by shrinking its photo rather than growing the card.
      const bool reserveQuantity = false;
      final double cardHeight = _addOnCardHeight(
        cardWidth,
        showImage: showImage,
        showPrice: showPrice,
        reserveQuantity: reserveQuantity,
      );

      return Wrap(
        alignment: WrapAlignment.start,
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final addon in group.addons)
            if (product.indexOfAddOn(addon.id) != null)
              Builder(builder: (context) {
                final int index = product.indexOfAddOn(addon.id)!;
                final bool selected =
                    index < productProvider.addOnActiveList.length &&
                        productProvider.addOnActiveList[index];
                final int quantity = index < productProvider.addOnQtyList.length
                    ? (productProvider.addOnQtyList[index] ?? 1)
                    : 1;
                return _AddOnCard(
                  width: cardWidth,
                  height: cardHeight,
                  name: addon.name ?? '',
                  priceDelta: addon.price ?? 0,
                  image: _choiceImageUrl(_addonImageUrl(context, addon)),
                  showImage: showImage,
                  showPrice: showPrice,
                  selected: selected,
                  quantity: quantity,
                  showQuantity: selected && !group.isSingle,
                  reserveQuantity: reserveQuantity,
                  onIncrement: () =>
                      productProvider.setAddOnQuantity(true, index),
                  onDecrement: () {
                    if (quantity > 1) {
                      productProvider.setAddOnQuantity(false, index);
                    } else {
                      _trackAddOn(context, false, addon);
                      productProvider.toggleAddOnInGroup(
                        index: index,
                        isSingle: group.isSingle,
                        groupIndexes: groupIndexes,
                        isRequired: group.isRequired,
                        maxSelect: group.max,
                      );
                    }
                  },
                  onTap: () {
                    if (selected && !group.isSingle) return;
                    _trackAddOn(context, !selected, addon);
                    productProvider.toggleAddOnInGroup(
                      index: index,
                      isSingle: group.isSingle,
                      groupIndexes: groupIndexes,
                      isRequired: group.isRequired,
                      maxSelect: group.max,
                    );
                  },
                );
              }),
        ],
      );
    });
  }
}

/// Figma `card-shot-espresso` and friends: a 539x535 cream card holding the
/// artwork, an uppercase Loew Medium name and the surcharge.
class _AddOnCard extends StatelessWidget {
  final double width;

  /// Fixed by the grid, so every card in it is the same height and the artwork
  /// inside flexes — the design keeps 535px whether the name runs to one line
  /// or two, and whether or not a quantity stepper has appeared.
  final double height;
  final String name;
  final double priceDelta;
  final String image;

  /// Whether this GROUP reserves an image slot / a price line — see
  /// [_DietaryCard.showImage].
  final bool showImage;
  final bool showPrice;
  final bool selected;
  final int quantity;

  /// Multi-select add-ons show − / qty / + once chosen. Single-choice groups
  /// stay binary (Figma: whipped cream) and never grow a stepper.
  final bool showQuantity;

  /// Keep the stepper's row even when this card has not been chosen, so a
  /// text-only grid does not jump when one card is tapped.
  final bool reserveQuantity;
  final VoidCallback onTap;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;
  const _AddOnCard({
    required this.width,
    required this.height,
    required this.name,
    required this.priceDelta,
    required this.image,
    required this.showImage,
    required this.showPrice,
    required this.selected,
    this.quantity = 1,
    this.showQuantity = false,
    this.reserveQuantity = false,
    required this.onTap,
    this.onIncrement,
    this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    final double k = width / KioskCustomizeSpec.choiceCardWidth;
    final double radius = KioskCustomizeSpec.addOnCardRadius * k;
    final double innerGap = KioskCustomizeSpec.addOnInnerGap * k;
    final String priceLabel = _addonPriceLabel(priceDelta);
    // Figma: a chosen card with no stepper moves its price to the top-right
    // (`card-whipped-cream/Selected`); one WITH a stepper keeps the price
    // inline above it (`card-vanilla-syrup/Selected`).
    final bool priceOnTop = selected && !showQuantity && priceLabel.isNotEmpty;

    final double nameSize = _choiceLabelSize(context, width);
    final TextStyle priceStyle = swiss721Light.copyWith(
      fontSize: nameSize * (42 / 45),
      height: 1.2,
      color: Colors.black,
    );
    final Widget label = Text(
      name.toUpperCase(),
      textAlign: TextAlign.center,
      maxLines: _kCardLabelLines,
      overflow: TextOverflow.ellipsis,
      style: loewMedium.copyWith(
        fontSize: nameSize,
        height: 1.2,
        color: Colors.black,
      ),
    );
    final Widget? price = (!priceOnTop && showPrice)
        ? Text(priceLabel, textAlign: TextAlign.center, style: priceStyle)
        : null;

    final List<Widget> body = [
      if (priceOnTop) ...[
        Text(priceLabel, textAlign: TextAlign.right, style: priceStyle),
        SizedBox(height: innerGap),
      ],
      if (showImage) ...[
        Expanded(
          child: ClipRRect(
            borderRadius:
                BorderRadius.circular(KioskCustomizeSpec.addOnImageRadius * k),
            child: _OptionImageSlot(image: image, fit: BoxFit.contain),
          ),
        ),
        SizedBox(height: innerGap),
        label,
        if (price != null) ...[SizedBox(height: innerGap), price],
      ] else
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                label,
                if (price != null) ...[SizedBox(height: innerGap), price],
              ],
            ),
          ),
        ),
      if (showQuantity || reserveQuantity) ...[
        SizedBox(height: innerGap),
        SizedBox(
          height: KioskCustomizeSpec.addOnQtyButton * k,
          child: showQuantity
              ? _CardQtyStepper(
                  quantity: quantity,
                  k: k,
                  onIncrement: onIncrement,
                  onDecrement: onDecrement,
                )
              : null,
        ),
      ],
    ];

    return Material(
      color: _kPanelBg,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: KioskTap(
        onTap: onTap,
        // See [_DietaryCard]: the grid owns the size, the card animates only
        // its outline.
        child: SizedBox(
          width: width,
          height: height,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            // Padding is NOT animated: it is measured against this card's
            // height, and a tween would spend 160ms at a value the contents
            // were never sized for — which is an overflow on every resize.
            decoration: BoxDecoration(
              color: _kPanelBg,
              borderRadius: BorderRadius.circular(radius),
            ),
            // See [_DietaryCard]: painted over the card so it costs no height.
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: selected ? _kCardBorderSelected : _kCardIdleBorder,
                width: _border(
                  selected
                      ? KioskCustomizeSpec.addOnCardBorderSelected
                      : KioskCustomizeSpec.addOnCardBorder,
                  k,
                ),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                KioskCustomizeSpec.addOnPadH * k,
                KioskCustomizeSpec.addOnPadTop * k,
                KioskCustomizeSpec.addOnPadH * k,
                KioskCustomizeSpec.addOnPadBottom * k,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: body,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Cup / can group: two big selectable cards. Only shown when the product has a
/// cup/can variation — Figma `Group 109`.
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
      compact: true,
      title: title,
      child: LayoutBuilder(builder: (context, constraints) {
        final int count = math.max(1, values.length);
        final double gap = KioskCustomizeSpec.vesselCardGap * s;
        // Equal widths, exactly filling the panel — the design's two 1099px
        // cards, whatever the panel is actually wide.
        final double cardWidth =
            math.max(1, (constraints.maxWidth - gap * (count - 1)) / count);
        final double cardHeight = cardWidth *
            (KioskCustomizeSpec.vesselCardHeight /
                KioskCustomizeSpec.vesselCardWidth) *
            KioskCustomizeSpec.vesselHeightFactor;

        return SizedBox(
          height: cardHeight,
          child: Row(
            children: [
              for (int i = 0; i < values.length; i++) ...[
                if (i > 0) SizedBox(width: gap),
                _CupCanCard(
                  s: s,
                  width: cardWidth,
                  height: cardHeight,
                  name: values[i].level?.trim() ?? '',
                  priceDelta: values[i].optionPrice ?? 0,
                  showPrice: anyPriced,
                  assetImage: _localVesselAsset(values[i].level?.trim() ?? ''),
                  image: KioskProductImageHelper.optionCardImageUrl(
                    value: values[i],
                    productImageBaseUrl: splash.baseUrls?.productImageUrl,
                  ),
                  selected: productProvider.selectedVariations[variationIndex]
                          [i] ??
                      false,
                  onTap: () {
                    final auth =
                        Provider.of<KioskAuthProvider>(context, listen: false);
                    KioskCustomizeAnalytics.instance.track(
                      KioskCustomizeEvent.cupOrCanSelected,
                      experience: auth.orderingExperience,
                      productId: product.id,
                      branchId: auth.branchId,
                      deviceId: auth.deviceId,
                      value: values[i].level?.trim() ?? '',
                    );
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
              ],
            ],
          ),
        );
      }),
    );
  }
}

/// Figma `cup` / `can`: a 1099x790 cream card, vessel centred over a small
/// letter-spaced label, with a heavy outline once chosen.
class _CupCanCard extends StatelessWidget {
  final double width;

  /// Fixed by the section from the design's 1099x790 ratio, so both cards match
  /// and neither steals the add-on list's height.
  final double height;
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

  /// The page scale, so the vessel word can match the section headings, which
  /// are authored in artboard px like everything else.
  final double s;

  const _CupCanCard({
    required this.width,
    required this.height,
    required this.name,
    required this.priceDelta,
    required this.showPrice,
    required this.assetImage,
    required this.image,
    required this.selected,
    required this.onTap,
    required this.s,
  });

  /// Section-heading size, capped so a narrow card ellipsizes the word rather
  /// than letting it run past the vessel image above it.
  double get _vesselLabelSize => math.min(
        KioskCustomizeSpec.panelTitleSize * s,
        width * KioskCustomizeSpec.vesselLabelMaxWidthShare,
      );

  @override
  Widget build(BuildContext context) {
    // Scale interiors from the shorter card so the vessel image shrinks
    // with the section instead of overflowing a reduced height.
    final double kW = width / KioskCustomizeSpec.vesselCardWidth;
    final double kH = height / KioskCustomizeSpec.vesselCardHeight;
    final double k = math.min(kW, kH);

    return KioskTap(
      onTap: onTap,
      // See [_DietaryCard]: the section owns the size, only the outline moves.
      child: SizedBox(
        width: width,
        height: height,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: _kPanelBg,
            borderRadius:
                BorderRadius.circular(KioskCustomizeSpec.vesselCardRadius * k),
          ),
          // See [_DietaryCard]: painted over the card so it costs no height.
          foregroundDecoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(KioskCustomizeSpec.vesselCardRadius * k),
            border: Border.all(
              color: selected ? _kInkText : _kVesselIdleBorder,
              width: _border(
                selected
                    ? KioskCustomizeSpec.vesselCardBorderSelected
                    : KioskCustomizeSpec.vesselCardBorder,
                k,
              ),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: KioskCustomizeSpec.vesselImageWidth * k,
                height: KioskCustomizeSpec.vesselImageHeight * k,
                child: _VesselImage(assetImage: assetImage, image: image),
              ),
              SizedBox(height: KioskCustomizeSpec.vesselImageGap * kW),
              Text(
                name.toUpperCase(),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                // ONE family of labels. "Size", "Add add-ons" and "CUP" sit in
                // the same column and read as the same kind of thing, so they
                // share the section-heading size and weight exactly.
                //
                // This used to be sized from the card WIDTH and set in Bold,
                // independent of `s`. Whenever height pulled the scale down —
                // which is the normal case on the 1080x1920 kiosk — the
                // headings shrank but this did not, so the vessel word ended up
                // LARGER than the headings above it.
                style: loewExtraBold.copyWith(
                  fontSize: _vesselLabelSize,
                  letterSpacing: _vesselLabelSize *
                      KioskCustomizeSpec.vesselLabelTrackingRatio,
                  height: 1.0,
                  color: _kInkText,
                ),
              ),
              if (showPrice) ...[
                SizedBox(height: KioskCustomizeSpec.vesselImageGap * 0.5 * kW),
                Text(
                  priceDelta > 0 ? _addonPriceLabel(priceDelta) : '',
                  style: swiss721Light.copyWith(
                    fontSize: math.max(
                      KioskCustomizeSpec.vesselLabelMinSize * 0.75,
                      KioskCustomizeSpec.addOnPriceSize * kW,
                    ),
                    height: 1.0,
                    color: Colors.black,
                  ),
                ),
              ],
            ],
          ),
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

/// Pinned bottom pair from the Figma design (`Group 167`): CANCEL ITEM
/// (outlined) beside ADD TO CART with the running line total.
///
/// Both are [KioskCheckoutButton] — the same shared control the checkout steps
/// and login use — so weight, radius and height stay consistent across the
/// kiosk instead of this screen growing its own button.
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
      padding: EdgeInsets.fromLTRB(
        KioskCustomizeSpec.gutter * s,
        KioskCustomizeSpec.actionBarTopGap * s,
        KioskCustomizeSpec.gutter * s,
        KioskCustomizeSpec.actionBarBottomGap * s,
      ),
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
              // The design's bar is part of the artboard, so it scales with the
              // page rather than snapping to the shared wide-screen button.
              forceScaled: true,
              fontSize: KioskCustomizeSpec.actionLabelSize,
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
          SizedBox(width: KioskCustomizeSpec.actionGap * s),
          Expanded(
            child: KioskCheckoutButton(
              s: s,
              filled: true,
              forceScaled: true,
              fontSize: KioskCustomizeSpec.actionLabelSize,
              label: addLabel,
              onTap: onAddToCart,
            ),
          ),
        ],
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
