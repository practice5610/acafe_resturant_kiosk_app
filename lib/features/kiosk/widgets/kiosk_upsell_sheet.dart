import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/material.dart';
import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/common/responsive/kiosk_responsive.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/category/providers/category_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_order_composition.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_translate.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_scrim.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_tap.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_ui.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:acafe_customer/common/widgets/custom_image_widget.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_product_customize_sheet.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/helper/price_converter_helper.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:provider/provider.dart';

// ===========================================================================
// KIOSK — "WOULD YOU LIKE TO ADD A DRINK?" upsell
// ===========================================================================
// Shown when the customer heads for the cart or checkout with a one-sided
// order. Which question gets asked is decided by [KioskOrderComposition], not
// here — this file only draws the answer.
// ===========================================================================

/// Card fill, a shade off the page cream so it lifts off the blurred menu.
const Color _kCardBg = Color(0xFFFBF7EC);
const Color _kCardBorder = Color(0xFFE6E0CE);

/// How many suggestions the grid offers. Six fills two rows of three without
/// the sheet ever needing to scroll on a kiosk.
const int _kMaxSuggestions = 6;

/// Opens the upsell for [composition] and resolves to true when the customer
/// added something, false when they declined or it was dismissed.
///
/// Returns false immediately when there is nothing worth asking — the caller
/// can therefore always `await` this and carry on.
Future<bool> openKioskUpsellSheet(
  BuildContext context, {
  required KioskCourse course,
}) async {
  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Add to your order',
    barrierColor: Colors.transparent, // the sheet paints its own frosted scrim
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (context, animation, secondaryAnimation) =>
        _KioskUpsellSheet(course: course),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      // The card rises and settles; the scrim behind it ramps its own blur.
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

class _KioskUpsellSheet extends StatelessWidget {
  final KioskCourse course;
  const _KioskUpsellSheet({required this.course});

  String _title(BuildContext context) => course == KioskCourse.drink
      ? kioskTranslate(
          context, 'would_you_like_to_add_a_drink', 'Would you like to add a drink?')
      : kioskTranslate(context, 'would_you_like_something_to_eat',
          'Would you like something to eat?');

  /// Suggestions for the missing course, cheapest-looking first isn't the goal —
  /// the most popular items are, because that is what a barista would offer.
  List<Product> _suggestions(BuildContext context) {
    final category = Provider.of<CategoryProvider>(context, listen: false);
    final cart = Provider.of<CartProvider>(context, listen: false);

    // Never suggest something already in the cart.
    final Set<int> inCart = {
      for (final CartModel? line in cart.cartList)
        if (line?.product?.id != null) line!.product!.id!,
    };

    final matches = category.allPrefetchedProducts
        .where((p) => KioskCourse.of(p) == course)
        .where((p) => p.id == null || !inCart.contains(p.id))
        .toList()
      ..sort((a, b) =>
          (b.popularityCount ?? 0).compareTo(a.popularityCount ?? 0));

    return matches.take(_kMaxSuggestions).toList();
  }

  @override
  Widget build(BuildContext context) {
    // Material (transparent) supplies the DefaultTextStyle every Text below
    // relies on; without it, text inside showGeneralDialog falls back to the
    // framework debug style.
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          KioskScrim(
            animation: ModalRoute.of(context)?.animation ?? kAlwaysCompleteAnimation,
            onDismiss: () => Navigator.of(context).pop(false),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double s = KioskResponsive.scale(constraints.maxWidth);
                final m = KioskUpsellGridMetrics.forWidth(constraints.maxWidth);
                final all = _suggestions(context);
                final suggestions =
                    all.take(m.visibleCount(all.length)).toList();

                return Center(
                  child: SingleChildScrollView(
                    // The sheet, not the page: on a short window the card
                    // scrolls inside the scrim instead of overflowing.
                    padding: EdgeInsets.symmetric(vertical: 24 * s),
                    child: GestureDetector(
                      // Absorb taps so tapping the card never dismisses.
                      onTap: () {},
                      child: Container(
                        width: m.sheetWidth,
                        // A dialog must never be taller than the screen it sits
                        // on; past this the card scrolls internally instead of
                        // growing. Without a ceiling the sheet grew with the
                        // number of suggestions until it WAS the page.
                        constraints: BoxConstraints(
                          maxHeight: constraints.maxHeight * 0.86,
                        ),
                        padding: EdgeInsets.all(m.pad),
                        decoration: BoxDecoration(
                          color: _kCardBg,
                          borderRadius:
                              BorderRadius.circular((36 * s).clamp(18.0, 36.0)),
                          border: Border.all(color: _kCardBorder, width: 1),
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
                            _Header(s: s, title: _title(context)),
                            SizedBox(height: (34 * s).clamp(14.0, 34.0)),
                            if (suggestions.isEmpty)
                              _Empty(s: s)
                            else
                              Wrap(
                                spacing: m.gutter,
                                runSpacing: m.gutter,
                                alignment: WrapAlignment.center,
                                children: [
                                  for (final product in suggestions)
                                    SizedBox(
                                      width: m.tile,
                                      child: _UpsellCard(
                                          tile: m.tile, product: product),
                                    ),
                                ],
                              ),
                            SizedBox(height: (36 * s).clamp(16.0, 36.0)),
                            _DeclineButton(s: s),
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
}

/// Back button on the left, title optically centred in the remaining space.
class _Header extends StatelessWidget {
  final double s;
  final String title;
  const _Header({required this.s, required this.title});

  @override
  Widget build(BuildContext context) {
    final double button = (86 * s).clamp(36.0, 86.0);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CircleBack(size: button, onTap: () => Navigator.of(context).pop(false)),
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: (12 * s).clamp(6.0, 12.0)),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: loewExtraBold.copyWith(
                fontSize: (52 * s).clamp(17.0, 52.0),
                height: 1.15,
                color: Colors.black,
              ),
            ),
          ),
        ),
        // Balances the back button so the title stays truly centred.
        SizedBox(width: button),
      ],
    );
  }
}

class _CircleBack extends StatelessWidget {
  final double size;
  final VoidCallback onTap;
  const _CircleBack({required this.size, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: KioskTap(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
                color: Colors.black, width: (size * 0.035).clamp(1.2, 3.0)),
          ),
          child: Icon(Icons.arrow_back_ios_new_rounded,
              size: size * 0.42, color: Colors.black),
        ),
      ),
    );
  }
}

/// "NO, THANK YOU!" — a text action, not a button: declining should never
/// compete visually with the suggestions.
class _DeclineButton extends StatelessWidget {
  final double s;
  const _DeclineButton({required this.s});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: KioskTap(
        onTap: () => Navigator.of(context).pop(false),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: (24 * s).clamp(12.0, 24.0),
            vertical: (14 * s).clamp(8.0, 14.0),
          ),
          child: Text(
            kioskTranslate(context, 'no_thank_you', 'No, thank you!')
                .toUpperCase(),
            style: loewBold.copyWith(
              fontSize: (30 * s).clamp(12.0, 30.0),
              height: 1.0,
              letterSpacing: 0.4,
              color: Colors.black,
            ),
          ),
        ),
      ),
    );
  }
}

/// Nothing left to offer (every item of that course is already in the cart).
class _Empty extends StatelessWidget {
  final double s;
  const _Empty({required this.s});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: (30 * s).clamp(14.0, 30.0)),
      child: Text(
        kioskTranslate(context, 'nothing_else_to_add', 'Nothing else to add'),
        textAlign: TextAlign.center,
        style: loewMedium.copyWith(
          fontSize: (32 * s).clamp(13.0, 32.0),
          color: Colors.black54,
        ),
      ),
    );
  }
}

// ===========================================================================
// ENTRY POINTS
// ===========================================================================
// Every "view cart" and "check out" button in the kiosk goes through these two
// functions rather than calling RouterHelper directly, so the upsell rule is
// asked once, in one place, and the two buttons can never drift apart.
// ===========================================================================

/// Runs the upsell check, then navigates to the cart.
Future<void> openKioskCart(BuildContext context) async {
  await _offerThenGo(context, RouterHelper.getKioskCartRoute);
}

/// Runs the upsell check, then navigates to checkout.
Future<void> openKioskCheckout(BuildContext context) async {
  await _offerThenGo(context, RouterHelper.getKioskCheckoutRoute);
}

/// Last-chance upsell after the customer has chosen a tip (or declined one)
/// and before the order is placed. Skipped when the cart already has both
/// courses. Failures never block payment.
Future<void> offerKioskPayUpsell(BuildContext context) async {
  try {
    final composition = KioskOrderComposition.of(
      Provider.of<CartProvider>(context, listen: false).cartList,
    );
    final KioskCourse? course = composition.courseToOffer;
    if (course == null) return;
    _KioskUpsellMemory.remember(course);
    await openKioskUpsellSheet(context, course: course);
  } catch (_) {
    // The customer is paying; a missing catalog must not stop the order.
  }
}

/// Ask once per visit to the cart, then continue regardless of the answer.
///
/// The customer is on their way somewhere; the upsell must never block that.
/// If anything about the offer fails, navigation still happens.
Future<void> _offerThenGo(BuildContext context, VoidCallback go) async {
  final composition = KioskOrderComposition.of(
    Provider.of<CartProvider>(context, listen: false).cartList,
  );

  final KioskCourse? course = composition.courseToOffer;
  if (course != null && !_KioskUpsellMemory.alreadyAsked(course)) {
    _KioskUpsellMemory.remember(course);
    // Declining, adding, or dismissing all end the same way: carry on.
    await openKioskUpsellSheet(context, course: course);
    if (!context.mounted) return;
  }

  go();
}

/// Remembers which upsells this customer has already seen.
///
/// Without this, a customer who declines the drink offer gets asked again every
/// single time they tap the cart — which reads as nagging, not service. Cleared
/// when the order is placed / the kiosk resets, so the next customer is asked
/// fresh.
class _KioskUpsellMemory {
  static final Set<KioskCourse> _asked = {};

  static bool alreadyAsked(KioskCourse course) => _asked.contains(course);
  static void remember(KioskCourse course) => _asked.add(course);
}

/// Clear the "already asked" memory. Call when a session ends so the next
/// customer starts clean.
void resetKioskUpsellMemory() => _KioskUpsellMemory._asked.clear();

// ===========================================================================
// GRID METRICS
// ===========================================================================

/// Sheet width, column count and tile width for the suggestion grid.
///
/// Pulled out of the widget as a pure value type because the arithmetic here
/// is exactly where the layout broke before: the old code divided the
/// available width by the column count and handed the result straight to
/// `Wrap`, so `columns * tile + gutters` came out EQUAL to the space
/// available. Any floating-point error then made the row one hair too wide and
/// Wrap pushed the last card onto its own line — which is why six cards
/// rendered as a single tall column. [tile] is floored for that reason, and
/// [fits] is asserted in tests at a spread of real viewport widths.
@visibleForTesting
class KioskUpsellGridMetrics {
  final double sheetWidth;
  final double pad;
  final double gutter;
  final double tile;
  final int columns;

  const KioskUpsellGridMetrics({
    required this.sheetWidth,
    required this.pad,
    required this.gutter,
    required this.tile,
    required this.columns,
  });

  /// Smallest tile that still reads as a product card rather than a thumbnail.
  /// Below this the grid drops a column instead of shrinking further.
  static const double _minTile = 112;

  /// Measured off the Figma sheet (412px wide: 24px padding, 17px gutters,
  /// 110px cards). Expressing them as RATIOS of the sheet — rather than as
  /// artboard px run through [KioskResponsive.scale] — is the fix for cards
  /// that came out too big: the scaled values bottomed out on their clamps
  /// (padding at 3.2% of the sheet instead of 5.8%, gutters at 2.0% instead of
  /// 4.1%) and the tiles absorbed every pixel the chrome gave up, landing at
  /// 29.8% of the sheet against the design's 26.7%.
  static const double _padRatio = 0.058;
  static const double _gutterRatio = 0.041;

  /// Desktop browsers reserve ~15px for a vertical scrollbar, and this sheet
  /// scrolls whenever the suggestions are taller than the window. LayoutBuilder
  /// measures BEFORE that scrollbar exists, so a grid sized to the full width
  /// loses the race and drops a column the moment the bar appears — which is
  /// exactly how a 3-across grid rendered 2-across in a 586px window.
  static const double _scrollbarReserve = 16;

  /// Share of the viewport the sheet occupies.
  ///
  /// Measured off the Figma mock: the card leaves ~9% of the screen clear on
  /// each side, so it reads as a dialog sitting ON the menu rather than as a
  /// new page. At 0.86 it filled almost the whole window and stopped looking
  /// like a modal at all.
  static const double _sheetRatio = 0.78;

  factory KioskUpsellGridMetrics.forWidth(double viewportWidth) {
    final double usable =
        (viewportWidth - _scrollbarReserve).clamp(240.0, double.infinity);
    final double sheetWidth = (usable * _sheetRatio).clamp(300.0, 1400.0);
    final double pad = (sheetWidth * _padRatio).clamp(14.0, 87.0);
    final double gutter = (sheetWidth * _gutterRatio).clamp(10.0, 62.0);

    // Three across is the design. Drop to two, then one, only when three
    // genuinely cannot hold a legible card — never because of rounding.
    int columns = 3;
    double tile = _tileFor(sheetWidth, pad, gutter, columns);
    while (columns > 1 && tile < _minTile) {
      columns--;
      tile = _tileFor(sheetWidth, pad, gutter, columns);
    }

    return KioskUpsellGridMetrics(
      sheetWidth: sheetWidth,
      pad: pad,
      gutter: gutter,
      tile: tile,
      columns: columns,
    );
  }

  /// One pixel of the row is deliberately left unused, then the result is
  /// floored. Flooring alone already keeps the row from exceeding the space
  /// available, but it still permits the row to land EXACTLY on it — the same
  /// knife-edge the original bug sat on. The reserved pixel makes
  /// `rowWidth < available` strict, so no future change to the padding or
  /// gutter (a fractional value, a different clamp) can put it back.
  static const double _slack = 1;

  static double _tileFor(
          double sheetWidth, double pad, double gutter, int columns) =>
      ((sheetWidth - pad * 2 - gutter * (columns - 1) - _slack) / columns)
          .floorToDouble();

  /// Total width one full row occupies.
  double get rowWidth => tile * columns + gutter * (columns - 1);

  /// How many suggestions to actually show, given [available] candidates.
  ///
  /// The design is two full rows. A count that does not divide by [columns]
  /// leaves a single card marooned on the last row beside a block of dead
  /// space — which is both ugly and the reason the sheet grew a whole extra
  /// row taller than it needed to be. So the count is rounded DOWN to a full
  /// row: 6 candidates fill two rows, 4 or 5 show one tidy row of 3, and a
  /// branch with fewer than one row's worth shows what it has.
  int visibleCount(int available) {
    if (available >= columns * 2) return columns * 2;
    if (available >= columns) return columns;
    return available;
  }

  /// Width available to the row inside the sheet's padding.
  double get available => sheetWidth - pad * 2;

  /// The invariant the old code violated.
  bool get fits => rowWidth < available;
}

// ===========================================================================
// SUGGESTION CARD
// ===========================================================================

/// Compact product card for the upsell grid.
///
/// Not [KioskProductCard]: that one is the MENU card, built for a ~300px grid
/// slot with fixed 12px padding, a fixed 20px radius and fixed caption type. In
/// a modal it has to render at half that width, where the fixed metrics stop
/// being proportional — a 12px inset around a 130px card reads as a fat border,
/// and the caption size stays put while everything around it shrinks. This card
/// carries the same visual language (white surface, square photo, badge in the
/// corner, name over price) with every dimension derived from the tile it is
/// actually given.
class _UpsellCard extends StatelessWidget {
  final double tile;
  final Product product;

  const _UpsellCard({required this.tile, required this.product});

  @override
  Widget build(BuildContext context) {
    final splash = Provider.of<SplashProvider>(context, listen: false);
    final String image = '${splash.baseUrls?.productImageUrl}/${product.image}';

    // Everything below scales off the tile, so the card holds its proportions
    // whether it is 128px on a laptop window or 420px on a 4K kiosk.
    final double radius = (tile * 0.09).clamp(10.0, 22.0);
    final double inset = (tile * 0.07).clamp(8.0, 20.0);
    final double nameSize = (tile * 0.10).clamp(11.0, 22.0);
    final double priceSize = (tile * 0.095).clamp(10.0, 20.0);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: KioskTap(
        // Same destination as tapping the product on the menu: customize, then
        // the shared add-to-cart path.
        onTap: () => openKioskCustomize(context, product),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: CustomImageWidget(
                placeholder: Images.placeholderImage,
                image: image,
                fit: BoxFit.cover,
                useShimmer: true,
                cacheWidth: CustomImageWidget.kKioskProductCacheWidth,
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(inset, inset * 0.8, inset, inset),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    product.name ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: loewBold.copyWith(
                      fontSize: nameSize,
                      height: 1.15,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: inset * 0.35),
                  Text(
                    PriceConverterHelper.convertPrice(product.price),
                    maxLines: 1,
                    style: loewMedium.copyWith(
                      fontSize: priceSize,
                      height: 1.0,
                      color: Colors.black54,
                    ),
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
