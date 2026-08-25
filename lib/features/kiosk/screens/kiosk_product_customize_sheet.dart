import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/common/providers/product_provider.dart';
import 'package:acafe_customer/common/responsive/kiosk_responsive.dart';
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
import 'package:acafe_customer/features/kiosk/domain/kiosk_customize_analytics.dart';
import 'package:acafe_customer/features/auth/providers/auth_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_ordering_experience.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:provider/provider.dart';

// Version B (the three-step flow) is a `part` of this library rather than a
// separate one, so it reuses every private section widget below — the header,
// the variation panels, the add-on grid, the cup/can cards — instead of
// re-implementing them. Only the navigation shell differs between versions.
part 'kiosk_product_customize_step_flow.dart';

// ===========================================================================
// KIOSK PRODUCT CUSTOMIZE — single full-screen page matching the Figma design
// (node 559:7646). Every size is taken from the 2572px-wide artboard and scaled
// by `s = KioskResponsive.scale(screenWidth)`, reproducing the design at any size.
// ===========================================================================
// Figma `02a - Menu Browse (Full Page)` (node 1385:13510), 2572x5400 artboard.
// Section panels are white cards with a soft shadow; the page cream sits behind.
const Color _kPanelBg = Color(0xFFFFFFFF); // section card fill
const Color _kPanelBorder = Color(0xFFB9B5A6); // scroll track
const Color _kCardIdleBorder = Color(0xFFD9D4C4); // unselected option cards
const Color _kStepperMinus = Color(0xFFE8E6DF); // header / in-card minus
const Color _kDarkButton = Color(0xFF1E1E1E);
const Color _kCreamText = Color(0xFFF3F3DD);

// Add-on scroller — Figma `Rectangle 100` (thumb) over `Rectangle 101` (track):
// both 20px wide, 15px radius, thumb #000000 on a #B9B5A6 track. The add-on
// area is the screen's ONLY vertical scroller — everything else is pinned — so
// this is the one indicator on the page.
const double _kScrollbarWidth = 20;
const double _kScrollbarRadius = 15;
// Option-card metrics. These are now CEILINGS, not fixed sizes: a card sizes
// its own interior from the width it is actually given (see
// [_OptionCardMetrics]) and only grows up to these artboard values. The screen
// scale `s` bottoms out at KioskResponsive.minScale so type stays legible on a
// small device — but that floor also froze the boxes, so below ~1070px the
// panel kept shrinking while the image slot, padding and radii did not. That is
// what left oversized cards wrapped around 7px labels on a laptop window.
const double _kDietaryCardWidth = 300; // was 350
const double _kAddOnCardWidth = 360; // was 424
const double _kOptionCardPad = 16;
const double _kOptionImage = 220;
const double _kOptionRadius = 16;
const double _kOptionInnerRadius = 12;
const double _kOptionGap = 12;
const double _kOptionNameSize = 26;
const double _kOptionPriceSize = 18;
const double _kOptionCardSpacing = 16;

/// The full-height hero only fits on a genuinely tall portrait kiosk. Below
/// this the header collapses to the compact side-by-side layout, which is what
/// keeps the add-on list from being squeezed to a sliver on a laptop window.
const double _kFullHeroMinViewport = 1150;

/// Gutter between option cards. Floored so a small screen keeps the cards
/// visibly separate instead of running them into one grey block. Used by BOTH
/// the width rule and the rows that lay the cards out, so the row keeps
/// dividing exactly.
double _optionGap(double s) =>
    (_kOptionCardSpacing * s).clamp(6.0, _kOptionCardSpacing);

/// Width for one option card inside a panel [width] px wide — see
/// `kiosk_option_layout.dart` for the rule.
double _optionCardWidth(double width, double s) => kioskOptionCardWidth(
      width: width,
      cardWidth: _kAddOnCardWidth * s,
      gap: _optionGap(s),
    );

/// True when an option carries artwork of its own — the same test
/// [_OptionImageSlot] paints by. A row where NOTHING has an image drops the
/// image slot altogether rather than reserving a band of empty white, which is
/// what made size cards and image-less add-ons read as big blank boxes.
bool _hasOptionArt(String image) =>
    image.isNotEmpty && !CustomImageWidget.isDefaultImage(image);

/// Everything inside an option card, derived from the card's own width.
///
/// The card width already comes from the space available (`_optionCardWidth`),
/// so driving the interior off it is what makes the card the same *shape* on a
/// phone-width window and a 4K kiosk. Each value has a floor (legibility, touch
/// target) and a ceiling (the artboard constant above).
class _OptionCardMetrics {
  /// Card padding.
  final double pad;

  /// Height of the image slot — 0 when the row has no artwork at all.
  final double image;

  /// Image → name gap.
  final double gap;

  /// Name → price gap.
  final double priceGap;
  final double radius;
  final double innerRadius;
  final double nameSize;
  final double priceSize;

  /// Selection dot, drawn over the image (or reserved above the name when the
  /// card has no image).
  final double dot;
  final double idleBorder;
  final double selectedBorder;

  const _OptionCardMetrics._({
    required this.pad,
    required this.image,
    required this.gap,
    required this.priceGap,
    required this.radius,
    required this.innerRadius,
    required this.nameSize,
    required this.priceSize,
    required this.dot,
    required this.idleBorder,
    required this.selectedBorder,
  });

  factory _OptionCardMetrics.of(double width, {required bool showImage}) {
    final double w = math.max(1, width);
    final double pad = (w * 0.07).clamp(6.0, _kOptionCardPad);
    final double inner = math.max(1, w - pad * 2);
    return _OptionCardMetrics._(
      pad: pad,
      // Figma option cards are nearly square: the image is the hero, the
      // label sits underneath, and a selected add-on tucks a qty stepper
      // into the same box rather than a short landscape strip.
      image: showImage ? (inner * 0.72).clamp(36.0, _kOptionImage) : 0,
      gap: (w * 0.045).clamp(4.0, _kOptionGap),
      priceGap: (w * 0.025).clamp(2.0, 6.0),
      radius: (w * 0.085).clamp(8.0, _kOptionRadius),
      innerRadius: (w * 0.055).clamp(5.0, _kOptionInnerRadius),
      nameSize: (w * 0.095).clamp(11.0, _kOptionNameSize),
      priceSize: (w * 0.07).clamp(9.0, _kOptionPriceSize),
      dot: (w * 0.12).clamp(16.0, 28.0),
      idleBorder: 1.0,
      selectedBorder: (w * 0.014).clamp(2.0, 3.0),
    );
  }
}

const Color _kScrollThumb = Color(0xFF000000);
const Color _kScrollTrack = _kPanelBorder;

/// Variation groups whose name mentions "cup"/"can" get the big two-card
/// treatment and are only shown when the product actually has them. This is the
/// name the backend's Cup/Can switch generates ("Can or cup?"); the pattern
/// stays loose so hand-authored groups from before the switch still match.
/// Word-bounded on purpose — an unbounded `can` also matched "Pecan".
final RegExp _kCupCanPattern =
    RegExp(r'\b(cups?|cans?)\b', caseSensitive: false);

/// Card outline + selected ink for the option cards.
const Color _kCardBorderSelected = Color(0xFF1E1E1E);
const Color _kInkText = Color(0xFF2B2B2B);

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
    final variations = product.variations ?? [];
    final indexed =
        List.generate(variations.length, (i) => MapEntry(i, variations[i]));
    bool isCupCan(MapEntry<int, Variation> e) =>
        _kCupCanPattern.hasMatch(e.value.name ?? '');

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

  // THE A/B SWITCH. Which customization flow this kiosk renders is a back-office
  // setting on the device (Device Update -> Ordering Experience), delivered as
  // `device.ordering_experience` and cached in SharedPreferences. Everything
  // above this line — the cart lookup, the ProductProvider seeding, the
  // no-modifiers shortcut — is shared, so the two versions can only ever differ
  // in presentation. A device that has never been told which flow to run falls
  // back to Version A (see [KioskOrderingExperience.fallback]).
  final KioskOrderingExperience experience =
      Provider.of<KioskAuthProvider>(context, listen: false).orderingExperience;

  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => experience.isVersionB
          ? KioskProductCustomizeStepScreen(
              product: product,
              cartIndex: cartIndex,
              initialInstruction: cart?.instruction,
              replaceOtherProductLines: replaceOtherProductLines,
            )
          : KioskProductCustomizeScreen(
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
    final variations = product.variations ?? [];
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
    final variations = product.variations ?? [];
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
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final int? index = cartIndex ?? productProvider.cartIndex;
    cartProvider.addToCart(
        buildKioskCartModel(context, product, instruction: instruction), index);
    if (replaceOtherProductLines &&
        product.id != null &&
        index != null &&
        index >= 0) {
      cartProvider.removeOtherLinesForProduct(product.id!, index);
    }
    Navigator.of(context).pop();
  }
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
  void initState() {
    super.initState();
    final String initial = widget.initialInstruction?.trim() ?? '';
    _instruction = initial.isEmpty ? null : initial;
    // After the first frame: `track` reads providers, which is not allowed
    // while the widget is still being mounted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) track(context, KioskCustomizeEvent.customizationStarted);
    });
  }

  @override
  void dispose() {
    // Left the screen without the line reaching the cart.
    if (!_completed) {
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

    return Scaffold(
      backgroundColor: KioskUI.pageBg,
      body: SafeArea(
        child: Consumer<ProductProvider>(
          builder: (context, productProvider, _) {
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

  /// Version B draws its own back button beside the progress bar, so it asks
  /// the header to skip the one in the corner rather than showing two.
  final bool showBackButton;
  const _Header(
      {required this.s,
      required this.product,
      required this.productProvider,
      this.showBackButton = true});

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
        if (showBackButton)
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
/// Same shape as the full hero — photo on top, then the name, description and
/// stepper, all centred on the screen — only smaller: the photo is capped
/// against the viewport so the identity block never takes the height the
/// options need. The back button stays pinned in the corner rather than pushing
/// the block off-centre.
class _CompactHeader extends StatelessWidget {
  final double s;
  final double viewportHeight;
  final Product product;
  final ProductProvider productProvider;

  /// See [_Header.showBackButton].
  final bool showBackButton;
  const _CompactHeader({
    required this.s,
    required this.viewportHeight,
    required this.product,
    required this.productProvider,
    this.showBackButton = true,
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
    // A badge, not a hero: never more than a seventh of the viewport, so the
    // centred block stays short enough to leave the options their room.
    final double imageSize = math.min(340 * s, viewportHeight * 0.15);
    // Keeps the centred text clear of the back button in the corner.
    final double gutter = (170 * s).clamp(52.0, 170.0);

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        SizedBox(
          width: double.infinity,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: gutter),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
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
                SizedBox(height: (18 * s).clamp(8.0, 24.0)),
                Text(
                  product.name ?? '',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: loewExtraBold.copyWith(
                      fontSize: (56 * s).clamp(18.0, 56.0),
                      height: 1.05,
                      color: Colors.black),
                ),
                if (description.isNotEmpty) ...[
                  SizedBox(height: (10 * s).clamp(4.0, 12.0)),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: scotchDisplayLight.copyWith(
                        fontSize: (30 * s).clamp(12.0, 30.0),
                        height: 1.2,
                        color: Colors.black87),
                  ),
                ],
                SizedBox(height: (20 * s).clamp(10.0, 24.0)),
                _QuantityStepper(s: s, productProvider: productProvider),
              ],
            ),
          ),
        ),
        if (showBackButton)
          Positioned(
            left: 0,
            top: 0,
            child: KioskBackButton.scaled(
              s: s,
              size: 110,
              border: 2,
              icon: 46,
              fallback: RouterHelper.getKioskMenuRoute,
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
    final double button = (96 * s).clamp(40.0, 96.0);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepperButton(
          width: button,
          height: button,
          label: '−',
          filled: false,
          onTap: () => qty > 1 ? productProvider.setQuantity(false) : null,
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: (36 * s).clamp(14.0, 36.0)),
          child: Text('$qty',
              style: loewExtraBold.copyWith(
                  fontSize: (64 * s).clamp(22.0, 64.0), color: Colors.black)),
        ),
        _StepperButton(
          width: button,
          height: button,
          label: '+',
          filled: true,
          onTap: () => productProvider.setQuantity(true),
        ),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  final double width;
  final double height;
  final String label;
  final bool filled;
  final VoidCallback? onTap;
  const _StepperButton({
    required this.width,
    required this.height,
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Figma: square-ish buttons, grey minus / black plus, tight radius — not
    // the outlined white pill the rest of the kiosk uses for qty.
    final double radius = (height * 0.22).clamp(6.0, 12.0);
    final double fontSize = (height * 0.48).clamp(14.0, 36.0);

    return Material(
      color: filled ? _kDarkButton : _kStepperMinus,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: KioskTap(
        onTap: onTap,
        child: Container(
          width: width,
          height: height,
          alignment: Alignment.center,
          child: Text(
            label,
            style: loewExtraBold.copyWith(
                fontSize: fontSize,
                height: 1.0,
                color: filled ? _kCreamText : Colors.black),
          ),
        ),
      ),
    );
  }
}

/// Compact − / qty / + used inside a selected add-on card.
class _CardQtyStepper extends StatelessWidget {
  final int quantity;
  final double size;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;
  const _CardQtyStepper({
    required this.quantity,
    required this.size,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    final double button = size.clamp(22.0, 36.0);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _StepperButton(
          width: button,
          height: button,
          label: '−',
          filled: false,
          onTap: onDecrement,
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: button * 0.35),
          child: Text(
            '$quantity',
            style: loewExtraBold.copyWith(
              fontSize: button * 0.72,
              height: 1.0,
              color: Colors.black,
            ),
          ),
        ),
        _StepperButton(
          width: button,
          height: button,
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
                  if (i > 0) SizedBox(width: _optionGap(s)),
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
    // Panel chrome is floored too: at the smallest scale 38*s is a 9px inset
    // around cards that have their own padding, which reads as no panel at all.
    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(vertical: (14 * s).clamp(6.0, 14.0)),
      padding: EdgeInsets.all((32 * s).clamp(12.0, 32.0)),
      decoration: BoxDecoration(
        color: _kPanelBg,
        borderRadius: BorderRadius.circular(
            (_kOptionRadius * s).clamp(10.0, _kOptionRadius)),
        border: Border.all(
          color: _kCardIdleBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: (20 * s).clamp(8.0, 20.0),
            offset: Offset(0, (4 * s).clamp(2.0, 4.0)),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: loewBold.copyWith(
                  fontSize: (54 * s).clamp(16.0, 54.0), color: Colors.black)),
          SizedBox(height: (30 * s).clamp(10.0, 30.0)),
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
        builder: (cardWidth) {
          // Flatten the groups first so the row can be asked ONE question:
          // does anything here have artwork? Size options rarely do, and a row
          // of reserved-but-empty image slots is what made Small / Medium /
          // Large read as tall blank boxes.
          final options = [
            for (final entry in entries)
              for (int i = 0;
                  i < (entry.value.variationValues?.length ?? 0);
                  i++)
                (
                  index: entry.key,
                  valueIndex: i,
                  variation: entry.value,
                  value: entry.value.variationValues![i],
                  image: KioskProductImageHelper.optionCardImageUrl(
                    value: entry.value.variationValues![i],
                    productImageBaseUrl: splash.baseUrls?.productImageUrl,
                  ),
                ),
          ];
          final bool showImage =
              options.any((option) => _hasOptionArt(option.image));
          return [
            for (final option in options)
              _DietaryCard(
                width: cardWidth,
                s: s,
                name:
                    (option.value.level ?? option.variation.name ?? '').trim(),
                priceDelta: option.value.optionPrice ?? 0,
                image: option.image,
                showImage: showImage,
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
                    variations:
                        productProvider.selectedVariations[option.index],
                    min: option.variation.min,
                    max: option.variation.max,
                  );
                },
              ),
          ];
        },
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
        builder: (cardWidth) {
          final List<String> images = [
            for (final value in values)
              KioskProductImageHelper.optionCardImageUrl(
                value: value,
                productImageBaseUrl: splash.baseUrls?.productImageUrl,
              ),
          ];
          // One decision for the whole row: illustrated groups keep the slot,
          // text-only groups (most milks) collapse to short cards.
          final bool showImage = images.any(_hasOptionArt);
          return List.generate(values.length, (i) {
            final bool selected =
                productProvider.selectedVariations[variationIndex][i] ?? false;
            return _DietaryCard(
              s: s,
              width: cardWidth,
              name: values[i].level?.trim() ?? '',
              priceDelta: values[i].optionPrice ?? 0,
              image: images[i],
              showImage: showImage,
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
          });
        },
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

  /// Whether this ROW reserves an image slot. Decided per group, not per card,
  /// so every card in a row is the same height — a group where no option has
  /// artwork drops the slot entirely and collapses to a compact text card.
  final bool showImage;
  final bool selected;
  final VoidCallback onTap;
  const _DietaryCard({
    required this.s,
    this.width,
    required this.name,
    required this.priceDelta,
    required this.image,
    required this.showImage,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double cardWidth = width ?? _kDietaryCardWidth * s;
    final _OptionCardMetrics m =
        _OptionCardMetrics.of(cardWidth, showImage: showImage);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(m.radius),
      clipBehavior: Clip.antiAlias,
      child: KioskTap(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: cardWidth,
          padding: EdgeInsets.all(m.pad),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(m.radius),
            border: Border.all(
              color: selected ? _kCardBorderSelected : _kCardIdleBorder,
              width: selected ? m.selectedBorder : m.idleBorder,
            ),
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (m.image > 0) ...[
                    SizedBox(
                      height: m.image,
                      child:
                          _OptionImageSlot(image: image, fit: BoxFit.contain),
                    ),
                    SizedBox(height: m.gap),
                  ] else
                    SizedBox(height: m.dot + m.priceGap),
                  Text(
                    name.toUpperCase(),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: loewBold.copyWith(
                        fontSize: m.nameSize, height: 1.1, color: Colors.black),
                  ),
                  if (priceDelta > 0) ...[
                    SizedBox(height: m.priceGap),
                    Text(
                      _addonPriceLabel(priceDelta),
                      textAlign: TextAlign.center,
                      style: swiss721Light.copyWith(
                          fontSize: m.priceSize, color: Colors.black54),
                    ),
                  ],
                ],
              ),
              Positioned(
                top: 0,
                right: 0,
                child: _RadioDot(size: m.dot, selected: selected),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
        border: Border.all(
            color: Colors.black, width: (size * 0.08).clamp(1.5, 2.5)),
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
                if (i > 0) SizedBox(height: (32 * s).clamp(12.0, 32.0)),
                Padding(
                  padding: EdgeInsets.only(bottom: (20 * s).clamp(8.0, 20.0)),
                  child: Text(
                    _addonGroupTitle(context, groups[i]),
                    style: loewBold.copyWith(
                        fontSize: (40 * s).clamp(13.0, 40.0),
                        color: Colors.black87),
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

    // Cards only — the heading and the panel chrome belong to _AddOnsSection
    // now, so every group shares one panel and one scroller.
    return LayoutBuilder(builder: (context, constraints) {
      // Cards fill the row they are given: fewer, still-legible cards on a
      // narrow window instead of the same count squeezed into slivers.
      final double cardWidth = _optionCardWidth(constraints.maxWidth, s);
      // Group-wide, so the grid stays a grid: one add-on with a photo keeps the
      // slot for its neighbours, a group with none loses it entirely.
      final bool showImage = group.addons.any((addon) => addon.hasImage);
      return Wrap(
        alignment: WrapAlignment.start,
        spacing: _optionGap(s),
        runSpacing: _optionGap(s),
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
                  s: s,
                  width: cardWidth,
                  name: addon.name ?? '',
                  priceDelta: addon.price ?? 0,
                  image: _addonImageUrl(context, addon),
                  showImage: showImage,
                  selected: selected,
                  quantity: quantity,
                  showQuantity: selected && !group.isSingle,
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

class _AddOnCard extends StatelessWidget {
  final double s;

  /// Width computed from the space actually available. Falls back to the
  /// artboard value when a caller has no layout information.
  final double? width;
  final String name;
  final double priceDelta;
  final String image;

  /// Whether this ROW reserves an image slot — see [_DietaryCard.showImage].
  final bool showImage;
  final bool selected;
  final int quantity;

  /// Multi-select add-ons show − / qty / + once chosen. Single-choice groups
  /// stay binary (Figma: whipped cream) and never grow a stepper.
  final bool showQuantity;
  final VoidCallback onTap;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;
  const _AddOnCard({
    required this.s,
    this.width,
    required this.name,
    required this.priceDelta,
    required this.image,
    required this.showImage,
    required this.selected,
    this.quantity = 1,
    this.showQuantity = false,
    required this.onTap,
    this.onIncrement,
    this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    final double cardWidth = width ?? _kAddOnCardWidth * s;
    final _OptionCardMetrics m =
        _OptionCardMetrics.of(cardWidth, showImage: showImage);
    final String priceLabel = _addonPriceLabel(priceDelta);
    final bool priceOnTop = selected && priceLabel.isNotEmpty;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(m.radius),
      clipBehavior: Clip.antiAlias,
      child: KioskTap(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: cardWidth,
          padding: EdgeInsets.fromLTRB(
            m.pad,
            priceOnTop ? m.pad + m.priceSize * 0.15 : m.pad,
            m.pad,
            m.pad,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(m.radius),
            border: Border.all(
              color: selected ? _kCardBorderSelected : _kCardIdleBorder,
              width: selected ? m.selectedBorder : m.idleBorder,
            ),
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (m.image > 0) ...[
                    SizedBox(
                      height: m.image,
                      child:
                          _OptionImageSlot(image: image, fit: BoxFit.contain),
                    ),
                    SizedBox(height: m.gap),
                  ],
                  Text(
                    name.toUpperCase(),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: loewBold.copyWith(
                        fontSize: m.nameSize, height: 1.1, color: Colors.black),
                  ),
                  if (!priceOnTop && priceLabel.isNotEmpty) ...[
                    SizedBox(height: m.priceGap),
                    Text(
                      priceLabel,
                      textAlign: TextAlign.center,
                      style: swiss721Light.copyWith(
                          fontSize: m.priceSize, color: Colors.black54),
                    ),
                  ],
                  if (showQuantity) ...[
                    SizedBox(height: m.gap),
                    _CardQtyStepper(
                      quantity: quantity,
                      size: m.dot,
                      onIncrement: onIncrement,
                      onDecrement: onDecrement,
                    ),
                  ],
                ],
              ),
              if (priceOnTop)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Text(
                    priceLabel,
                    style: swiss721Light.copyWith(
                      fontSize: m.priceSize,
                      height: 1.0,
                      color: Colors.black54,
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

    // The vessel row is the last small decision before adding, not a hero. It
    // used to take 620*s (or 22% of the viewport) and stretch edge to edge,
    // which drew two half-empty white slabs around a small cup. Now the card is
    // short AND capped in width, so the artwork sits in a card its own size.
    final double viewportHeight = MediaQuery.sizeOf(context).height;
    final double cardHeight =
        math.min(520 * s, viewportHeight * 0.22).clamp(120.0, 520.0);
    final double gap = (20 * s).clamp(8.0, 20.0);

    return _SectionPanel(
      s: s,
      title: title,
      child: Row(
        children: List.generate(values.length, (i) {
          final List<bool?> selections =
              productProvider.selectedVariations[variationIndex];
          final bool selected = selections[i] ?? false;
          final String label = values[i].level?.trim() ?? '';
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < values.length - 1 ? gap : 0),
              child: _CupCanCard(
                s: s,
                height: cardHeight,
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
                  final auth = Provider.of<KioskAuthProvider>(context,
                      listen: false);
                  KioskCustomizeAnalytics.instance.track(
                    KioskCustomizeEvent.cupOrCanSelected,
                    experience: auth.orderingExperience,
                    productId: product.id,
                    branchId: auth.branchId,
                    deviceId: auth.deviceId,
                    value: label,
                  );
                  productProvider.setCartVariationIndex(
                      variationIndex, i, product, variation.isMultiSelect!);
                  productProvider.checkIsRequiredSelected(
                    index: variationIndex,
                    isMultiSelect: variation.isMultiSelect!,
                    variations: selections,
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

  /// Fixed by the section, from the artboard AND the viewport, so both cards
  /// match and neither steals the add-on list's height.
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
  const _CupCanCard({
    required this.s,
    required this.height,
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
    // Everything here is a fraction of the card's own height, so the vessel,
    // its label and the chrome around them shrink together instead of the
    // artwork holding an artboard size inside a card that no longer fits it.
    final double radius = (height * 0.06).clamp(10.0, 16.0);
    final double pad = (height * 0.08).clamp(8.0, 28.0);
    final double labelSize = (height * 0.12).clamp(12.0, 28.0);
    final double labelGap = (height * 0.045).clamp(4.0, 16.0);
    final double borderWidth = selected ? 2.5 : 1.0;

    return KioskTap(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        height: height,
        padding: EdgeInsets.fromLTRB(pad, pad, pad, pad * 0.85),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: selected ? _kCardBorderSelected : _kCardIdleBorder,
            width: borderWidth,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: height * 0.04,
                  vertical: height * 0.02,
                ),
                child: _VesselImage(
                  assetImage: assetImage,
                  image: image,
                ),
              ),
            ),
            SizedBox(height: labelGap),
            Text(
              name.toUpperCase(),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: loewBold.copyWith(
                fontSize: labelSize,
                letterSpacing: (2 * s).clamp(0.4, 2.0),
                height: 1.0,
                color: _kInkText,
              ),
            ),
            if (showPrice) ...[
              SizedBox(height: labelGap * 0.5),
              Text(
                priceDelta > 0 ? _addonPriceLabel(priceDelta) : '',
                style: swiss721Light.copyWith(
                    fontSize: labelSize * 0.76, color: Colors.black54),
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
