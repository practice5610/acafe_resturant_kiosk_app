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
import 'package:acafe_customer/features/kiosk/domain/kiosk_deal.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_menu_filter.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_translate.dart';
import 'package:acafe_customer/features/kiosk/landscape/landscape_menu_logic.dart';
import 'package:acafe_customer/features/kiosk/landscape/landscape_metrics.dart';
import 'package:acafe_customer/features/kiosk/landscape/widgets/landscape_cancel_dialog.dart';
import 'package:acafe_customer/features/kiosk/landscape/widgets/landscape_category_rail.dart';
import 'package:acafe_customer/features/kiosk/landscape/widgets/landscape_coupon_dialog.dart';
import 'package:acafe_customer/features/kiosk/landscape/widgets/landscape_language_sheet.dart';
import 'package:acafe_customer/features/kiosk/landscape/widgets/landscape_order_panel.dart';
import 'package:acafe_customer/features/kiosk/landscape/widgets/landscape_product_card.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_deal_provider.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_deal_banner.dart';
import 'package:acafe_customer/features/pos/widgets/pos_equal_height_row.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_tap.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_upsell_sheet.dart'
    show openKioskCheckout;
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

/// Menu content background (portrait redesign).
const Color _kContentBg = Color(0xFFF6F5F5);

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
      _toast = kioskTranslate(context, 'landscape_item_added_toast',
              '{product} added to your order')
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

  /// B-08/09/10 — the landscape "Add a coupon" pop-up (Figma TABLET option B,
  /// nodes 2305:7603/7939/8275), a small modal over the menu rather than the
  /// portrait's full-screen coupon flow.
  Future<void> _onCoupon(BuildContext context) async {
    final cart = Provider.of<CartProvider>(context, listen: false);
    final coupon = Provider.of<CouponProvider>(context, listen: false);
    final double total = kioskPayableTotal(cart.cartList, coupon.discount ?? 0);
    await showLandscapeCouponDialog(context, orderAmount: total);
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
            final double panelWidth = (430 * s).clamp(panelLower, panelUpper);
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
                        onCombo:
                            () {}, // TODO: combo "+" (see docs/landscape/01-audit.md — no reusable "add this bundle outright" logic exists in portrait; stopped for sign-off)
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

  /// Redesign unit: 1.0 at the 1190×680 reference (sidebar 130, circle 60…).
  static double _unit(double s) => s / LandscapeMetrics.scaleFor(1190, 680);

  Widget _menuArea(double s) {
    final double u = _unit(s);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Portrait-style cream sidebar: logo, categories, pinned logout.
        LandscapeCategoryRail(u: u, onSelect: _onSelectCategory),
        Expanded(
          child: ColoredBox(
            color: _kContentBg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(s: s),
                Padding(
                  padding: EdgeInsets.fromLTRB(16 * u, 12 * u, 16 * u, 0),
                  child: _FilterPills(
                    s: s,
                    selected: _selectedTagPills,
                    onToggle: (label) => setState(() {
                      if (!_selectedTagPills.remove(label)) {
                        _selectedTagPills.add(label);
                      }
                    }),
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      _ProductGrid(s: s, u: u, tagFilters: _selectedTagPills),
                      // Figma "Bottom fade": transparent -> content bg.
                      // Ignores pointer events so scroll/taps reach the grid.
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 60 * u,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  _kContentBg.withValues(alpha: 0),
                                  _kContentBg,
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
      padding: EdgeInsets.fromLTRB(24 * s, 24 * s, 30 * s, 0),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The A/CAFÉ logo (and its staff-exit triple tap) moved into
              // the sidebar.
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
          SizedBox(height: 18 * s),
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
          side:
              BorderSide(color: Colors.black, width: (1.6 * s).clamp(1.0, 3.0)),
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
          border:
              Border.all(color: Colors.black, width: (1.2 * s).clamp(1.0, 2.0)),
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
  final double u;
  final Set<String> tagFilters;
  const _ProductGrid(
      {required this.s, required this.u, required this.tagFilters});

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
          products = filterKioskProductsByTag(
              products: products, pillLabels: tagFilters);
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
                style:
                    loewBold.copyWith(fontSize: 18 * s, color: Colors.black54),
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
        // Grid: 16 padding, 16 gaps (redesign), scaled with the screen.
        final double pad = 16 * u;
        final double gap = 16 * u;
        // Columns: UNCHANGED logic — landscape is pinned to 3 per row through
        // the shared factory's min/max (no per-device setting exists for
        // landscape; see git history for the Figma B-01 reasoning).
        const int kColumns = 3;
        final geo = KioskProductGridGeometry.resolve(
          areaWidth: math.max(c.maxWidth - pad * 2, 1.0),
          gap: gap,
          landscape: true,
          showImages: showImages,
          minColumns: kColumns,
          maxColumns: kColumns,
        );
        final int columns = geo.columns;
        final double tileWidth = math.max(geo.tileWidth, 1.0);

        final int firstCount =
            products.length >= columns * 2 ? columns * 2 : products.length;
        final List<Product> rest = products.sublist(firstCount);

        // Rows of equal-height, content-sized cards (portrait grid): each row
        // is as tall as its tallest card; a short last row stays left aligned.
        Widget rows(List<Product> list) {
          final int rowCount = (list.length + columns - 1) ~/ columns;
          return SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, r) {
                final int start = r * columns;
                final int end = math.min(start + columns, list.length);
                return Padding(
                  padding: EdgeInsets.only(top: r == 0 ? 0 : gap),
                  child: PosEqualHeightRow(
                    columns: columns,
                    spacing: gap,
                    children: [
                      for (final p in list.sublist(start, end))
                        LandscapeProductCard(
                            tileWidth: tileWidth,
                            product: p,
                            showImages: showImages),
                    ],
                  ),
                );
              },
              childCount: rowCount,
            ),
          );
        }

        return Consumer<KioskDealProvider>(
          builder: (context, dealsProvider, _) {
            List<KioskDeal> deals = const <KioskDeal>[];
            try {
              deals = dealsProvider.deals;
            } catch (_) {}
            final bool showPromo = deals.isNotEmpty && showImages;
            final int splitAt = showPromo ? firstCount : products.length;
            final List<Product> tail = showPromo ? rest : const <Product>[];

            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(pad, pad, pad, 0),
                  sliver: rows(products.sublist(0, splitAt)),
                ),
                if (showPromo)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(pad, gap, pad, 0),
                      child: KioskDealPromoBanner(s: s, deals: deals),
                    ),
                  ),
                if (tail.isNotEmpty)
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(pad, gap, pad, 0),
                    sliver: rows(tail),
                  ),
                SliverToBoxAdapter(child: SizedBox(height: 60 * u)),
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
  const _ToastBar(
      {required this.s, required this.message, required this.panelWidth});

  @override
  Widget build(BuildContext context) {
    // Centered on the grid's own content region (x180..966 at the 1366
    // reference — the category rail and panel paddings are excluded), not
    // the whole left Expanded area, matching how `_menuArea` insets its row:
    // Padding(20) -> rail(140) -> gap(20) -> content -> Padding(24).
    return Positioned(
      left: LandscapeCategoryRail.widthFor(
          s / LandscapeMetrics.scaleFor(1190, 680)),
      right: panelWidth,
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
                  style:
                      loewBold.copyWith(fontSize: 17 * s, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
