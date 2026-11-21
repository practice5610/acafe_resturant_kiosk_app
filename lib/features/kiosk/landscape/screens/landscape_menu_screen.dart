import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/common/responsive/kiosk_responsive.dart';
import 'package:acafe_customer/common/widgets/custom_asset_image_widget.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/category/providers/category_provider.dart';
import 'package:acafe_customer/features/coupon/providers/coupon_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_allergen.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_cart_totals.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_coupon_helper.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_deal.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_menu_filter.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_translate.dart';
import 'package:acafe_customer/features/kiosk/landscape/landscape_menu_logic.dart';
import 'package:acafe_customer/features/kiosk/landscape/landscape_metrics.dart';
import 'package:acafe_customer/features/kiosk/landscape/widgets/landscape_cancel_dialog.dart';
import 'package:acafe_customer/features/kiosk/landscape/widgets/landscape_category_rail.dart';
import 'package:acafe_customer/features/kiosk/landscape/widgets/landscape_language_sheet.dart';
import 'package:acafe_customer/features/kiosk/landscape/widgets/landscape_order_panel.dart';
import 'package:acafe_customer/features/kiosk/landscape/widgets/landscape_product_card.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_deal_provider.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_deal_banner.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_staff_exit_trigger.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_tap.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_upsell_sheet.dart' show openKioskCheckout;
import 'package:acafe_customer/features/language/providers/localization_provider.dart';
import 'package:acafe_customer/features/search/providers/search_provider.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';

/// Merchandising filter pills (same labels/spelling as the portrait menu).
const List<String> _kFilterPillLabels = [
  'POPULAR',
  'SIGNATURE',
  'SEASONAL',
  'SPECIALS',
  'PURE',
  'CEROMONIAL',
];

const Color _kPageBg = Color(0xFFF7F1DE);

/// B2 landscape menu (Option B): menu on the left, a persistent order panel on
/// the right, no cart screen. Reuses the shared category/product/cart state and
/// the existing product, checkout, search, filter and language flows; only the
/// composition and the B-03 "item added" feedback are new.
class LandscapeMenuScreen extends StatefulWidget {
  const LandscapeMenuScreen({super.key});

  @override
  State<LandscapeMenuScreen> createState() => _LandscapeMenuScreenState();
}

class _LandscapeMenuScreenState extends State<LandscapeMenuScreen> {
  final Set<String> _selectedTagPills = <String>{};

  CartProvider? _cart;
  List<CartModel?> _prevCart = const [];
  int? _highlightIndex;
  String? _toast;
  Timer? _feedbackTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
      _cart = Provider.of<CartProvider>(context, listen: false);
      _prevCart = List<CartModel?>.of(_cart!.cartList);
      _cart!.addListener(_onCartChanged);
    });
  }

  @override
  void dispose() {
    _cart?.removeListener(_onCartChanged);
    _feedbackTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final category = Provider.of<CategoryProvider>(context, listen: false);
    final locale = Provider.of<LocalizationProvider>(context, listen: false)
        .locale
        .languageCode;
    if (!category.isKioskMenuReadyFor(locale)) {
      await category.ensureKioskMenuReady(localeCode: locale);
    }
    if (!mounted) return;
    Provider.of<KioskDealProvider>(context, listen: false).fetchDeals();
  }

  /// B-03: a product added from the menu appends a line; the toast and the
  /// highlighted row appear together and disappear together, 3 s later. A
  /// panel +/- never grows the list, so it never triggers this (see
  /// [landscapeJustAddedIndex]).
  void _onCartChanged() {
    if (_cart == null || !mounted) return;
    final next = _cart!.cartList;
    final int? added = landscapeJustAddedIndex(_prevCart, next);
    _prevCart = List<CartModel?>.of(next);
    if (added == null) return;
    final CartModel? line = added < next.length ? next[added] : null;
    final String name = line?.isDeal == true
        ? (line?.dealTitle ?? line?.product?.name ?? '')
        : (line?.product?.name ?? '');

    _feedbackTimer?.cancel();
    setState(() {
      _highlightIndex = added;
      _toast = kioskTranslate(
              context, 'landscape_item_added_toast', '{product} added to your order')
          .replaceAll('{product}', name);
    });
    _feedbackTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _highlightIndex = null;
          _toast = null;
        });
      }
    });
  }

  Future<void> _onSelectCategory(int id) async {
    final category = Provider.of<CategoryProvider>(context, listen: false);
    category.setSelectedCategoryHighlight('$id');
    await category.selectKioskCategory('$id');
  }

  Future<void> _onCancelOrder(double s) async {
    final cart = Provider.of<CartProvider>(context, listen: false);
    final coupon = Provider.of<CouponProvider>(context, listen: false);
    final int count = kioskCartItemCount(cart.cartList);
    final bool confirmed =
        await showLandscapeCancelOrderDialog(context, s: s, itemCount: count);
    if (!confirmed || !mounted) return;
    cart.clearCartList();
    coupon.removeCouponData(true);
    // Back to the existing start screen (SCOPE: B1 stays portrait for now).
    // Hitting a start path also releases the Phase-1 orientation latch.
    context.go(RouterHelper.kioskWelcomeScreen);
  }

  /// Same entry point the portrait cart uses (`kiosk_coupon_helper.dart`):
  /// ensures a guest account exists, then pushes the existing (portrait)
  /// coupon screen as a route. It renders as a portrait design inside the
  /// landscape window — same category as checkout/customize, no landscape
  /// Figma exists for it, and this task does not redesign it.
  Future<void> _onCoupon(BuildContext context) async {
    final cart = Provider.of<CartProvider>(context, listen: false);
    final coupon = Provider.of<CouponProvider>(context, listen: false);
    final double total = kioskPayableTotal(cart.cartList, coupon.discount ?? 0);
    await openKioskCouponScreen(context, orderAmount: total);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kPageBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final double s = LandscapeMetrics.scaleFor(c.maxWidth, c.maxHeight);
            // Target 350*s, floored at 220 so the panel stays usable, capped
            // at 40% of the available width so it can never crowd out the
            // menu. The cap must win the clamp when the window is narrow
            // (upper < 220) — `num.clamp` throws if lower > upper, which is
            // exactly what crashed this screen while it was briefly shown at
            // a narrow (near-portrait) width during a resize.
            final double panelUpper = math.max(c.maxWidth * 0.4, 0.0);
            final double panelLower = math.min(220.0, panelUpper);
            final double panelWidth = (390 * s).clamp(panelLower, panelUpper);
            return Stack(
              children: [
                Row(
                  children: [
                    Expanded(child: _menuArea(s)),
                    SizedBox(
                      width: panelWidth,
                      child: LandscapeOrderPanel(
                        s: s,
                        highlightIndex: _highlightIndex,
                        onCheckout: () => openKioskCheckout(context),
                        onCancelOrder: () => _onCancelOrder(s),
                        onCoupon: () => _onCoupon(context),
                        onCombo: () {}, // TODO: combo "+" (see docs/landscape/01-audit.md — no reusable "add this bundle outright" logic exists in portrait; stopped for sign-off)
                      ),
                    ),
                  ],
                ),
                if (_toast != null)
                  _ToastBar(s: s, message: _toast!, panelWidth: panelWidth),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _menuArea(double s) {
    final double railWidth = 140 * s;
    final double gap = 20 * s;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(s: s),
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20 * s, 16 * s, 24 * s, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LandscapeCategoryRail(
                    s: s, width: railWidth, onSelect: _onSelectCategory),
                SizedBox(width: gap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FilterPills(
                        s: s,
                        selected: _selectedTagPills,
                        onToggle: (label) => setState(() {
                          if (!_selectedTagPills.remove(label)) {
                            _selectedTagPills.add(label);
                          }
                        }),
                      ),
                      SizedBox(height: 16 * s),
                      Expanded(
                        child: Stack(
                          children: [
                            _ProductGrid(s: s, tagFilters: _selectedTagPills),
                            // Figma "Bottom fade": transparent -> page bg,
                            // 836x140 at the reference size. Ignores pointer
                            // events so scroll/taps reach the grid beneath it.
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              height: 140 * s,
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        _kPageBg.withValues(alpha: 0),
                                        _kPageBg,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
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
    );
  }
}

/// Header metrics are Figma B-01 values (canvas-relative, scaled by [s]):
/// logo left 40/top 35 (170.2 x 44.625), icon circles 49.6-49.8 wide with a
/// 15px gap, header line left 40/top 115/width 946 — the header spans
/// x40→x986 while the menu content below spans x180→x966.
class _Header extends StatelessWidget {
  final double s;
  const _Header({required this.s});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(40 * s, 28 * s, 30 * s, 0),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KioskStaffExitTrigger(
                child: Text(
                  'A/CAFÉ',
                  style: loewExtraBold.copyWith(
                      fontSize: 34 * s, height: 1, letterSpacing: 0.6 * s, color: Colors.black),
                ),
              ),
              const Spacer(),
              // Same assets the portrait header uses (kiosk_menu_screen.dart
              // _CircleIconButton / _LanguageFlagButton) — the SVGs already
              // bake in their own circle + glyph, so no separate border here.
              // Figma gives the search circle a slight top offset (33.1)
              // against filter/language (31.5) — reproduced exactly.
              Padding(
                padding: EdgeInsets.only(top: 1.6 * s),
                child: _HeaderIconButton(
                    s: s,
                    size: 49.79,
                    assetPath: Images.searchSvg,
                    onTap: () => RouterHelper.getSearchRoute()),
              ),
              SizedBox(width: 15.01 * s),
              _HeaderIconButton(
                  s: s,
                  size: 49.79,
                  assetPath: Images.filterSvg,
                  onTap: () => openKioskMenuFilterSheet(context)),
              SizedBox(width: 15.01 * s),
              _HeaderLanguageFlag(s: s, size: 49.6),
            ],
          ),
          // Measured against the rendered tree (not guessed): logo top 28,
          // header line top must land at 115 — gap tuned to hit that exactly
          // at the 1366x1024 reference (TextPainter-free: font ascent/descent
          // vary by platform, so this is corrected empirically against the
          // test, not derived from a formula).
          SizedBox(height: 35.61 * s),
          Container(height: 2 * s, color: Colors.black),
        ],
      ),
    );
  }
}

/// Search / filter header buttons — the exact same SVG assets as the portrait
/// header's `_CircleIconButton` (kiosk_menu_screen.dart). Those assets already
/// draw their own circle + glyph, so unlike the earlier Material-icon version
/// this needs no separate border.
class _HeaderIconButton extends StatelessWidget {
  final double s;
  final double size;
  final String assetPath;
  final VoidCallback onTap;
  const _HeaderIconButton({
    required this.s,
    required this.size,
    required this.assetPath,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double px = size * s;
    return KioskTap(
      onTap: onTap,
      child: SizedBox(
        width: px,
        height: px,
        child: CustomAssetImageWidget(
          assetPath,
          width: px,
          height: px,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

/// The selected language's flag, matching the portrait header's
/// `_LanguageFlagButton` — a plain flag image (not pre-bordered like the
/// search/filter SVGs), clipped into a circle with the same black ring.
class _HeaderLanguageFlag extends StatelessWidget {
  final double s;
  final double size;
  const _HeaderLanguageFlag({required this.s, required this.size});

  @override
  Widget build(BuildContext context) {
    final String code =
        Provider.of<LocalizationProvider>(context).locale.languageCode;
    final language = AppConstants.languages.firstWhere(
      (l) => l.languageCode == code,
      orElse: () => AppConstants.languages.first,
    );
    final double px = size * s;
    return SizedBox(
      width: px,
      height: px,
      child: Material(
        color: Colors.transparent,
        shape: CircleBorder(
          side: BorderSide(color: Colors.black, width: (1.6 * s).clamp(1.0, 3.0)),
        ),
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        child: KioskTap(
          onTap: () => showLandscapeLanguageSheet(context, s: s),
          child: Image.asset(
            language.imageUrl!,
            width: px,
            height: px,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}

class _FilterPills extends StatelessWidget {
  final double s;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  const _FilterPills(
      {required this.s, required this.selected, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8 * s,
      runSpacing: 8 * s,
      children: [
        for (final label in _kFilterPillLabels)
          _Pill(
            s: s,
            label: label,
            selected: selected.contains(label),
            onTap: () => onToggle(label),
          ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final double s;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Pill(
      {required this.s,
      required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return KioskTap(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 8 * s),
        decoration: BoxDecoration(
          color: selected ? Colors.black : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.black, width: (1.2 * s).clamp(1.0, 2.0)),
        ),
        child: Text(
          label,
          style: loewMedium.copyWith(
              fontSize: 14 * s,
              height: 1.0,
              color: selected ? Colors.white : Colors.black),
        ),
      ),
    );
  }
}

/// Reuses the exact portrait data derivation: the selected category's products
/// run through the shared tag and allergen filters, with the promo banner
/// inserted after the first two rows.
class _ProductGrid extends StatelessWidget {
  final double s;
  final Set<String> tagFilters;
  const _ProductGrid({required this.s, required this.tagFilters});

  @override
  Widget build(BuildContext context) {
    final bool showImages = context.watch<KioskAuthProvider>().showImages;
    return ListenableBuilder(
      listenable: KioskAllergenPreferences.instance,
      builder: (context, _) => Consumer2<CategoryProvider, SearchProvider>(
        builder: (context, category, search, _) {
          final bool filtersActive = kioskMenuFiltersActive(category, search);
          List<Product> products = filtersActive
              ? applyKioskMenuFilters(
                  categoryProvider: category, searchProvider: search)
              : (category.categoryProductModel?.products ?? const []);
          products =
              filterKioskProductsByTag(products: products, pillLabels: tagFilters);
          products = filterKioskProductsByAllergens(
              products: products,
              avoided: KioskAllergenPreferences.instance.avoided);

          if (category.categoryProductModel == null && !filtersActive) {
            return const Center(child: CircularProgressIndicator());
          }
          if (products.isEmpty) {
            return Center(
              child: Text(
                kioskTranslate(context, 'no_items', 'No items'),
                style: loewBold.copyWith(fontSize: 18 * s, color: Colors.black54),
              ),
            );
          }
          return _grid(context, products, showImages);
        },
      ),
    );
  }

  Widget _grid(BuildContext context, List<Product> products, bool showImages) {
    return LayoutBuilder(
      builder: (context, c) {
        // Figma B-01: columns sit 268px apart (x180/448/716) at a 250px card
        // width, i.e. an 18px gap — not the 22px this screen used before.
        // Row 1 (y190) to the promo banner (y578.95) and banner to row 2
        // (y795.14) both measure a 14px gap. Confirmed against the live node
        // via get_metadata, not estimated.
        final double colGap = 18 * s;
        final double bannerGap = 14 * s;
        // Figma B-01 is exactly 3 columns at every size — not the dynamic
        // width-driven column count portrait's grid uses. No per-device
        // "products per row" setting exists yet (checked: no such field on
        // the device/branch model), so this pins the shared factory to a
        // fixed 3 via its existing min/max-columns parameters rather than
        // changing the factory's default algorithm, which portrait relies on.
        const int kColumns = 3;
        final geo = KioskProductGridGeometry.resolve(
          areaWidth: c.maxWidth,
          gap: colGap,
          landscape: true,
          showImages: showImages,
          minColumns: kColumns,
          maxColumns: kColumns,
        );
        final int columns = geo.columns;
        // Figma's own card ratio (374.95 tall at a 250 width, ≈1.4998) left
        // only ~1.3 rows visible on a real screen before the next row was
        // scrolled almost entirely out of view — shortened so two full rows
        // fit. That ratio lives in a file shared with portrait
        // (common/responsive/kiosk_responsive.dart), so rather than change
        // the shared factory's assumption, the card height is computed
        // locally and used for the sliver's mainAxisExtent;
        // LandscapeProductCard already lays its image out with Expanded, so
        // it fills whatever height it is given.
        const double kCardAspect = 1.0;
        // Guards a tiny/negative tileWidth during an extreme resize (the
        // shared factory doesn't floor it) so the grid never hands a
        // negative mainAxisExtent to SliverGrid.
        final double tileWidth = math.max(geo.tileWidth, 1.0);
        final double tileHeight = tileWidth * kCardAspect;

        final int firstCount =
            products.length >= columns * 2 ? columns * 2 : products.length;
        final List<Product> rest = products.sublist(firstCount);

        final gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: colGap,
          mainAxisSpacing: bannerGap,
          mainAxisExtent: tileHeight,
        );

        return Consumer<KioskDealProvider>(
          builder: (context, dealsProvider, _) {
            List<KioskDeal> deals = const <KioskDeal>[];
            try {
              deals = dealsProvider.deals;
            } catch (_) {}
            final bool showPromo = deals.isNotEmpty && showImages;
            final int splitAt = showPromo ? firstCount : products.length;
            final List<Product> tail =
                showPromo ? rest : const <Product>[];

            return CustomScrollView(
              slivers: [
                SliverGrid(
                  gridDelegate: gridDelegate,
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => LandscapeProductCard(
                        tileWidth: tileWidth,
                        product: products[i],
                        showImages: showImages),
                    childCount: splitAt,
                  ),
                ),
                if (showPromo)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: bannerGap),
                      child: KioskDealPromoBanner(s: s, deals: deals),
                    ),
                  ),
                if (tail.isNotEmpty)
                  SliverGrid(
                    gridDelegate: gridDelegate,
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => LandscapeProductCard(
                          tileWidth: tileWidth,
                          product: tail[i],
                          showImages: showImages),
                      childCount: tail.length,
                    ),
                  ),
                SliverToBoxAdapter(child: SizedBox(height: 24 * s)),
              ],
            );
          },
        );
      },
    );
  }
}

/// B-03 toast: a dark pill with a green dot, centred near the bottom of the
/// menu, shown for 3 s above the grid.
/// Figma B-03 toast (`2305:4353`): bg #0D0D0D, pill radius 40, 26/16 padding,
/// 12 gap, a 26px circle asset + one line of text. Centered on the MENU
/// PANE only (x180..966 at the 1366 reference, center ≈573) — [panelWidth]
/// is subtracted from the right edge so it never centers across the order
/// panel too. `IgnorePointer` so it never blocks a tap on the grid beneath it.
class _ToastBar extends StatelessWidget {
  final double s;
  final String message;
  final double panelWidth;
  const _ToastBar({required this.s, required this.message, required this.panelWidth});

  @override
  Widget build(BuildContext context) {
    // Centered on the grid's own content region (x180..966 at the 1366
    // reference — the category rail and panel paddings are excluded), not
    // the whole left Expanded area, matching how `_menuArea` insets its row:
    // Padding(20) -> rail(140) -> gap(20) -> content -> Padding(24).
    return Positioned(
      left: (20 + 140 + 20) * s,
      right: panelWidth + 24 * s,
      bottom: 16 * s,
      child: IgnorePointer(
        child: Center(
          child: Container(
            key: const Key('landscape-toast'),
            padding: EdgeInsets.symmetric(horizontal: 26 * s, vertical: 16 * s),
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D0D),
              borderRadius: BorderRadius.circular(40 * s),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  'assets/svg/landscape_toast_circle.svg',
                  width: 26 * s,
                  height: 26 * s,
                ),
                SizedBox(width: 12 * s),
                Text(
                  message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: loewBold.copyWith(fontSize: 17 * s, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
