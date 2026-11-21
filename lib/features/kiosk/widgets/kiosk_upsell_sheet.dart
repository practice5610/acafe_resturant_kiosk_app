import 'package:flutter/material.dart';
import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/common/responsive/kiosk_layout.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/category/providers/category_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_combo_match.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_order_composition.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_translate.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_deal_provider.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_product_customize_sheet.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_combo_sheet.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_product_card.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_scrim.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_tap.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_ui.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:acafe_customer/theme/text_legibility.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:provider/provider.dart';

// ===========================================================================
// KIOSK — "WOULD YOU LIKE TO ADD A DRINK?" upsell  (Figma POS 2305:14909)
// ===========================================================================
// Shown when the customer heads for the cart or checkout with a one-sided
// order. Which question gets asked is decided by [KioskOrderComposition], not
// here — this file only draws the answer. The cards are the SAME
// [KioskProductCard] the menu grid uses, with description and (i) switched off.
// ===========================================================================

/// Figma 2305:14909, measured on its 2078px-wide sheet. Every size is the
/// design value × k, where k = sheetWidth / [sheetW] — one scale, no per-element
/// clamps, so the sheet holds its proportions on any kiosk.
class _Spec {
  _Spec._();

  static const double sheetW = 2078;
  static const Color bg = Color(0xFFFBF8EF);
  static const Color borderColor = Color(0xFFB9B5A6);
  static const double radius = 30;
  static const double border = 1;

  static const double padTop = 94; // sheet top (608) → title (702)
  static const double headerH = 157; // title box
  static const double backLeft = 65; // sheet left (247) → back (312)
  static const double backTop = 8; // title top (702) → back top (710)
  static const double backSize = 141;
  static const double titleW = 946;
  static const double titleSize = 72; // Loew ExtraBold, leading 1
  static const double titleToGrid = 142; // 859 → 1001
  static const double gridToButton = 74; // last row end (2704) → button (2778)
  static const double buttonW = 571;
  static const double buttonH = 126;
  static const double buttonText = 36; // Loew Bold
  static const double padBottom = 129; // button end (2904) → sheet end (3033)
}

/// How many suggestions the grid offers. Six fills two rows of three without
/// the sheet ever needing to scroll on a kiosk.
const int _kMaxSuggestions = 6;

/// Opens the upsell for [course] and resolves to the product the customer
/// tapped, or null when they declined / dismissed it. The caller opens
/// customize for the chosen product AFTER this sheet has closed, so the sheet
/// never has to pop itself from across a push (which is unreliable once the
/// dialog subtree has rebuilt behind the customize route).
Future<Product?> openKioskUpsellSheet(
  BuildContext context, {
  required KioskCourse course,
}) async {
  return showGeneralDialog<Product>(
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
}

class _KioskUpsellSheet extends StatelessWidget {
  final KioskCourse course;
  const _KioskUpsellSheet({required this.course});

  String _title(BuildContext context) => course == KioskCourse.drink
      ? kioskTranslate(context, 'would_you_like_something_to_drink',
          'Would you like to add a drink?')
      : kioskTranslate(context, 'would_you_like_something_to_eat',
          'Would you like to add something to eat?');

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

  /// Tap on a suggestion: close the sheet, handing the product back so the
  /// caller opens customize once the sheet is gone. Doing the customize push
  /// from inside the sheet (then popping it afterwards) is unreliable — the
  /// dialog rebuilds behind the customize route — so the sheet just reports the
  /// choice and closes cleanly here.
  void _pick(BuildContext context, Product product) =>
      Navigator.of(context).pop(product);

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
            onDismiss: () => Navigator.of(context).pop(),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double s = KioskLayout.scaleOf(context, constraints);
                final m = KioskUpsellGridMetrics.forWidth(
                  constraints.maxWidth,
                  viewportHeight: constraints.maxHeight,
                );
                final double k = m.sheetWidth / _Spec.sheetW;
                final bool showImages =
                    Provider.of<KioskAuthProvider>(context, listen: false)
                        .showImages;
                final all = _suggestions(context);
                final suggestions =
                    all.take(m.visibleCount(all.length)).toList();

                return Center(
                  child: SingleChildScrollView(
                    // On a short window the sheet scrolls inside the scrim
                    // instead of overflowing.
                    padding: EdgeInsets.symmetric(vertical: 24 * s),
                    child: GestureDetector(
                      // Absorb taps so tapping the card never dismisses.
                      onTap: () {},
                      child: Container(
                        width: m.sheetWidth,
                        padding: EdgeInsets.only(
                          top: _Spec.padTop * k,
                          bottom: _Spec.padBottom * k,
                        ),
                        decoration: BoxDecoration(
                          color: _Spec.bg,
                          borderRadius:
                              BorderRadius.circular(_Spec.radius * k),
                          border: Border.all(
                            color: _Spec.borderColor,
                            width: (_Spec.border * k).clamp(0.5, 2.0),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _Header(k: k, title: _title(context)),
                            SizedBox(height: _Spec.titleToGrid * k),
                            Padding(
                              padding:
                                  EdgeInsets.symmetric(horizontal: m.pad),
                              child: suggestions.isEmpty
                                  ? _Empty(s: s)
                                  : Wrap(
                                      spacing: m.gutter,
                                      runSpacing: m.gutter,
                                      alignment: WrapAlignment.center,
                                      children: [
                                        for (final product in suggestions)
                                          SizedBox(
                                            width: m.tile,
                                            child: KioskProductCard(
                                              s: s,
                                              tileWidth: m.tile,
                                              product: product,
                                              badge: kioskCardBadgeFor(product),
                                              showImages: showImages,
                                              showDescription: false,
                                              showInfoIcon: false,
                                              onTap: () =>
                                                  _pick(context, product),
                                            ),
                                          ),
                                      ],
                                    ),
                            ),
                            SizedBox(height: _Spec.gridToButton * k),
                            _DeclineButton(k: k),
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

/// Back circle top-left, title centred on the sheet (Figma 2305:14909).
class _Header extends StatelessWidget {
  final double k;
  final String title;
  const _Header({required this.k, required this.title});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _Spec.headerH * k,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: _Spec.titleW * k,
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: loewExtraBold.copyWith(
                  fontSize: _Spec.titleSize * k,
                  height: 1.0,
                  letterSpacing: 0,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          Positioned(
            left: _Spec.backLeft * k,
            top: _Spec.backTop * k,
            child: KioskCircleBack(
              size: _Spec.backSize * k,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}

/// "NO, THANK YOU!" — a text action, not a button: declining should never
/// compete visually with the suggestions. Figma: 571×126 hit box, Loew Bold 36.
class _DeclineButton extends StatelessWidget {
  final double k;
  const _DeclineButton({required this.k});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(15 * k),
      clipBehavior: Clip.antiAlias,
      child: KioskTap(
        onTap: () => Navigator.of(context).pop(),
        child: SizedBox(
          width: _Spec.buttonW * k,
          height: _Spec.buttonH * k,
          child: Center(
            child: Text(
              kioskTranslate(context, 'no_thank_you', 'No, thank you!')
                  .toUpperCase(),
              style: loewBold.copyWith(
                fontSize: _Spec.buttonText * k,
                height: 1.0,
                letterSpacing: 0,
                color: Colors.black,
              ),
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
          color: TextTones.secondary,
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
/// and before the order is placed. Combo-first, then the missing-course grid.
/// Failures never block payment.
Future<void> offerKioskPayUpsell(BuildContext context) async {
  try {
    await _presentUpsell(context);
  } catch (_) {
    // The customer is paying; a missing catalog must not stop the order.
  }
}

/// Ask once per visit to the cart, then continue regardless of the answer.
///
/// The customer is on their way somewhere; the upsell must never block that.
/// If anything about the offer fails, navigation still happens.
Future<void> _offerThenGo(BuildContext context, VoidCallback go) async {
  bool handled = false;
  try {
    handled = await _presentUpsell(context);
  } catch (_) {}
  if (!context.mounted) return;
  // When the customer picked a suggestion, the add flow (customize → "added to
  // cart" confirmation, which returns to the menu on its own) owns navigation —
  // calling [go] here would race that screen. Only continue to the cart /
  // checkout when nothing was added (declined, dismissed, or combo offer).
  if (!handled) go();
}

/// Combo match first (product ids), then the food/drink grid.
///
/// Combo-first still matters: a deal match on product ids is independent of
/// whether those products are food or drink. The course rule itself now uses
/// cup/can, not `products.area`.
/// Shows the right upsell (combo, then the missing-course grid) and returns
/// true when the customer picked a suggestion — in which case the add flow
/// (customize → confirmation → menu) has taken over navigation and the caller
/// must NOT navigate again. Returns false when nothing was added.
Future<bool> _presentUpsell(BuildContext context) async {
  final cart = Provider.of<CartProvider>(context, listen: false);
  final deals = Provider.of<KioskDealProvider>(context, listen: false).deals;
  final KioskComboMatch? match = findKioskComboUpgrade(cart.cartList, deals);
  if (match != null && !_KioskUpsellMemory.alreadyAskedCombo(match.deal.id)) {
    _KioskUpsellMemory.rememberCombo(match.deal.id);
    await openKioskComboSheet(context, match: match);
    return false;
  }

  final composition = KioskOrderComposition.of(cart.cartList);
  final KioskCourse? course = composition.courseToOffer;
  if (course != null && !_KioskUpsellMemory.alreadyAsked(course)) {
    _KioskUpsellMemory.remember(course);
    final Product? picked = await openKioskUpsellSheet(context, course: course);
    // Sheet is closed now; open customize for the tapped suggestion so adding
    // it uses the same cup/can → add-to-cart path as the menu. The confirmation
    // screen then returns to the menu on its own, so report that navigation is
    // handled. Declining (null) falls through so the caller continues the flow.
    if (picked != null && context.mounted) {
      await openKioskCustomize(context, picked);
      return true;
    }
  }
  return false;
}

/// Remembers which upsells this customer has already seen.
///
/// Without this, a customer who declines the drink offer gets asked again every
/// single time they tap the cart — which reads as nagging, not service. Cleared
/// when the order is placed / the kiosk resets, so the next customer is asked
/// fresh. Combo offers are keyed by deal id so a declined upgrade is not
/// repeated on every cart tap.
class _KioskUpsellMemory {
  static final Set<KioskCourse> _asked = {};
  static final Set<int> _askedCombos = {};

  static bool alreadyAsked(KioskCourse course) => _asked.contains(course);
  static void remember(KioskCourse course) => _asked.add(course);

  static bool alreadyAskedCombo(int dealId) => _askedCombos.contains(dealId);
  static void rememberCombo(int dealId) => _askedCombos.add(dealId);

  static void reset() {
    _asked.clear();
    _askedCombos.clear();
  }
}

/// Clear the "already asked" memory. Call when a session ends so the next
/// customer starts clean.
void resetKioskUpsellMemory() => _KioskUpsellMemory.reset();

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

  factory KioskUpsellGridMetrics.forWidth(
    double viewportWidth, {
    double? viewportHeight,
  }) {
    final bool landscape =
        viewportHeight != null && viewportWidth > viewportHeight;
    final double usable =
        (viewportWidth - _scrollbarReserve).clamp(240.0, double.infinity);
    final double sheetWidth = (usable * (landscape ? 0.72 : _sheetRatio))
        .clamp(300.0, landscape ? 1680.0 : 1400.0);
    final double pad = (sheetWidth * _padRatio).clamp(14.0, 87.0);
    final double gutter = (sheetWidth * _gutterRatio).clamp(10.0, 62.0);

    // Three across is the portrait design. Landscape uses four when the
    // sheet is wide enough for a legible card.
    int columns = landscape && sheetWidth >= 900 ? 4 : 3;
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

