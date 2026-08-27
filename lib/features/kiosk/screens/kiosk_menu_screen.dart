import 'package:flutter/material.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_language_sheet.dart';
import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/common/responsive/kiosk_layout.dart';
import 'package:acafe_customer/common/responsive/kiosk_responsive.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_ui.dart';
import 'package:acafe_customer/common/widgets/custom_asset_image_widget.dart';
import 'package:acafe_customer/common/widgets/custom_image_widget.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/category/providers/category_provider.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_tap.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_menu_image_helper.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_product_image_helper.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_allergen.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_deal.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_menu_filter.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_translate.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_session.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_deal_provider.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_allergen_filter_screen.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_deal_detail_screen.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_product_customize_sheet.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_pin_entry_sheet.dart';
import 'package:acafe_customer/features/language/providers/localization_provider.dart';
import 'package:acafe_customer/features/search/providers/search_provider.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/helper/price_converter_helper.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_upsell_sheet.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:acafe_customer/localization/language_constrants.dart';
import 'package:acafe_customer/theme/brand_colors.dart';
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:provider/provider.dart';

// ===========================================================================
// KIOSK MENU — faithful, fully-responsive port of the Figma "Kiosk 55 inch"
// design (node 582:9515).
//
// RESPONSIVENESS MODEL: every size below is taken straight from the Figma
// artboard (KioskResponsive.designWidth px wide) and scaled by
// `s = KioskResponsive.scale(width, height)`. Portrait is width-only so the
// 1080×1920 kiosk is a proportional photocopy. Landscape also fits height
// (2160 artboard) so a laptop window does not inflate the header and cart bar.
// ===========================================================================

// Static promo/badge colours from the design (page background is KioskUI.pageBg).
const Color _kPopularGreen = Color(0xFF357937);
const Color _kSpecialRed = Color(0xFF59030E);

// Top-bar search / filter / language controls (Figma 124×124, SVG stroke 6 @ 137).
const double _kTopBarActionSize = 124;
const double _kTopBarSvgArtSize = 137;
const double _kTopBarSvgStroke = 6;

/// Vertical gap between the header row (logo + icons) and the menu row.
const double _kHeaderContentGap = 72;

/// Type is smaller than the Figma artboard so the menu matches the already
/// reduced customize / add-on screens. Gaps, cards, and bars stay as designed.
const double _kMenuType = KioskResponsive.menuTypeScale;

double _topBarActionDiameter(double s) => _kTopBarActionSize * s;

double _topBarActionBorderWidth(double s) =>
    _kTopBarSvgStroke * s * (_kTopBarActionSize / _kTopBarSvgArtSize);

// Filter pills from the design: POPULAR / SIGNATURE / SEASONAL / SPECIALS /
// PURE on the first row, CEROMONIAL alone on the second (spelling as in the
// Figma source). The labels stay hardcoded; tapping a pill filters the current
// category to products that have that tag on the product create screen.
const List<String> _kFilterPillLabels = [
  'POPULAR',
  'SIGNATURE',
  'SEASONAL',
  'SPECIALS',
  'PURE',
];
const String _kFilterPillSecondRowLabel = 'CEROMONIAL';

/// Removes the overscroll glow/stretch so dragging the grid past its top edge
/// doesn't paint a grey "shadow" over the page (matches a clean kiosk look).
/// Also drops the scrollbar the root MaterialScrollBehavior auto-adds on
/// desktop/web (kiosk is touch-driven; no drag handle should show on the
/// product grid).
class _NoGlowScrollBehavior extends ScrollBehavior {
  const _NoGlowScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
          BuildContext context, Widget child, ScrollableDetails details) =>
      child;

  @override
  Widget buildScrollbar(
          BuildContext context, Widget child, ScrollableDetails details) =>
      child;
}

/// Kiosk main menu: centered brand bar on top, a vertical category rail (white
/// image cards) on the left and a responsive 3-column product grid on the
/// right, with a fixed full-width cart bar pinned to the bottom.
class KioskMenuScreen extends StatefulWidget {
  const KioskMenuScreen({super.key});

  @override
  State<KioskMenuScreen> createState() => _KioskMenuScreenState();
}

class _KioskMenuScreenState extends State<KioskMenuScreen> {
  LocalizationProvider? _localization;
  String? _lastLocale;
  /// Pills the customer has toggled on. Multi-select: the grid shows products
  /// carrying ANY of them (see [filterKioskProductsByTag]).
  final Set<String> _selectedTagPills = <String>{};

  @override
  void initState() {
    super.initState();
    _localization = Provider.of<LocalizationProvider>(context, listen: false);
    _lastLocale = _localization!.locale.languageCode;
    // Refetch menu data when the language changes while this screen is open, so
    // the product grid updates instantly (not only after navigating away/back).
    _localization!.addListener(_onLocaleChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _localization?.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onLocaleChanged() {
    final code = _localization?.locale.languageCode;
    if (code != null && code != _lastLocale) {
      _lastLocale = code;
      _reloadForLocale();
    }
  }

  /// Re-pull the category list and the currently-selected category's products
  /// in the new locale (the X-localization header is already updated by then).
  Future<void> _reloadForLocale() async {
    if (!mounted) return;
    final categoryProvider =
        Provider.of<CategoryProvider>(context, listen: false);
    final locale = Provider.of<LocalizationProvider>(context, listen: false)
        .locale
        .languageCode;
    await categoryProvider.prefetchKioskMenu(localeCode: locale, force: true);
    if (!mounted) return;
    Provider.of<KioskDealProvider>(context, listen: false).fetchDeals();
    KioskMenuImageHelper.precacheAroundSelected(
      context,
      categoryProvider,
      Provider.of<SplashProvider>(context, listen: false),
    );
  }

  Future<void> _loadData() async {
    final categoryProvider =
        Provider.of<CategoryProvider>(context, listen: false);
    final locale = Provider.of<LocalizationProvider>(context, listen: false)
        .locale
        .languageCode;
    final splash = Provider.of<SplashProvider>(context, listen: false);

    // Prefetched on the welcome screen — render from cache, no extra network hit.
    if (categoryProvider.isKioskMenuReadyFor(locale)) {
      KioskMenuImageHelper.precacheAroundSelected(
          context, categoryProvider, splash);
      Provider.of<KioskDealProvider>(context, listen: false).fetchDeals();
      return;
    }

    // Edge case: deep-linked to /menu-kiosk without visiting welcome first.
    await categoryProvider.ensureKioskMenuReady(localeCode: locale);
    if (!mounted) return;
    Provider.of<KioskDealProvider>(context, listen: false).fetchDeals();
    KioskMenuImageHelper.precacheAroundSelected(
        context, categoryProvider, splash);
  }

  Future<void> _onSelectCategory(int id) async {
    final categoryProvider =
        Provider.of<CategoryProvider>(context, listen: false);
    final splash = Provider.of<SplashProvider>(context, listen: false);

    // 1) Highlight the tapped category immediately (responsive), while the
    //    current grid stays on screen.
    categoryProvider.setSelectedCategoryHighlight('$id');

    // 2) Warm the target category's images BEFORE swapping the grid, so the new
    //    products appear already-decoded — no shimmer/fade. Bounded by a timeout
    //    so a cold first load still swaps promptly (falling back to a skeleton).
    final targetProducts = categoryProvider.kioskProductsForCategoryIds([id]);
    await KioskMenuImageHelper.precacheProducts(
      context,
      splash,
      targetProducts,
      awaitAll: true,
    ).timeout(const Duration(milliseconds: 1200), onTimeout: () {});
    if (!mounted) return;

    // 3) Swap the grid to the now-warm category (instant from the memory cache).
    await categoryProvider.selectKioskCategory('$id');
    if (!mounted) return;

    // 4) Warm neighbours for the next tap.
    KioskMenuImageHelper.precacheAroundSelected(
        context, categoryProvider, splash);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KioskUI.pageBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double s = KioskLayout.scaleOf(context, constraints);
            final bool landscape =
                KioskLayout.isLandscape(context, constraints);
            // Landscape has far less vertical room — tighten chrome so the
            // product grid keeps the majority of the window. Portrait 1080
            // stays on the Figma gaps (chrome = 1).
            final double chrome = landscape ? 0.48 : 1.0;
            final double sideMargin = 85 * s; // Figma left/right page margin.
            return Column(
              children: [
                _KioskTopBar(
                    s: s, sideMargin: sideMargin, landscape: landscape),
                SizedBox(height: 28 * s * chrome),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: sideMargin),
                  child: Container(height: 3 * s, color: Colors.black),
                ),
                SizedBox(height: _kHeaderContentGap * s * chrome),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: sideMargin),
                    child: LayoutBuilder(
                      builder: (context, row) {
                        final rail = kioskCategoryRailLayout(
                          scale: s,
                          innerWidth: row.maxWidth,
                        );
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _CategoryRail(
                              s: s,
                              width: rail.width,
                              onSelect: _onSelectCategory,
                            ),
                            SizedBox(width: rail.gap),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _FilterPillsRow(
                                    pillHeight: 90 * s,
                                    fontSize: 43.2 * s * _kMenuType,
                                    borderWidth: 3.6 * s,
                                    hPadding: 42 * s,
                                    hGap: 19.8 * s,
                                    vGap: 28 * s,
                                    scrollInsteadOfWrap: landscape,
                                    selected: _selectedTagPills,
                                    onSelect: (label) => setState(() {
                                      if (!_selectedTagPills.remove(label)) {
                                        _selectedTagPills.add(label);
                                      }
                                    }),
                                  ),
                                  SizedBox(height: 61 * s * chrome),
                                  Expanded(
                                      child: _ProductArea(
                                          s: s,
                                          landscape: landscape,
                                          tagFilters: _selectedTagPills)),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                _CartBar(
                    s: s, sideMargin: sideMargin, landscape: landscape),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Top bar: centered "A/CAFÉ" brand title with circular search / filter /
/// language-flag actions on the right.
class _KioskTopBar extends StatelessWidget {
  final double s;
  final double sideMargin;
  final bool landscape;
  const _KioskTopBar({
    required this.s,
    required this.sideMargin,
    this.landscape = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          sideMargin, (landscape ? 16 : 40) * s, sideMargin, 0),
      child: Row(
        children: [
          // Left-aligned brand title (the A/CAFÉ brand, per the design).
          Text(
            'A/CAFÉ',
            style: loewExtraBold.copyWith(
              fontSize: 120 * s * _kMenuType,
              height: 1,
              letterSpacing: 2 * s,
              color: Colors.black,
            ),
          ),
          const Spacer(),
          // Right-aligned action icons.
          if (context.watch<KioskAuthProvider>().isPosDevice) ...[
            _CircleIconButton(
                s: s,
                assetPath: Images.managerAccessSvg,
                onTap: () => openKioskManagerAccess(context)),
            SizedBox(width: 38 * s),
          ],
          _CircleIconButton(
              s: s,
              assetPath: Images.searchSvg,
              onTap: () => RouterHelper.getSearchRoute()),
          SizedBox(width: 38 * s),
          _CircleIconButton(
              s: s,
              assetPath: Images.filterSvg,
              onTap: () => openKioskMenuFilterSheet(context)),
          SizedBox(width: 38 * s),
          _LanguageFlagButton(s: s),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final double s;
  final String assetPath;
  final VoidCallback onTap;
  const _CircleIconButton(
      {required this.s, required this.assetPath, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final double d = _topBarActionDiameter(s);
    return SizedBox(
      width: d,
      height: d,
      child: KioskTap(
        onTap: onTap,
        child: CustomAssetImageWidget(
          assetPath,
          width: d,
          height: d,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _LanguageFlagButton extends StatelessWidget {
  final double s;
  const _LanguageFlagButton({required this.s});

  @override
  Widget build(BuildContext context) {
    final String code =
        Provider.of<LocalizationProvider>(context).locale.languageCode;
    final language = AppConstants.languages.firstWhere(
      (l) => l.languageCode == code,
      orElse: () => AppConstants.languages.first,
    );
    final double d = _topBarActionDiameter(s);
    final double stroke = _topBarActionBorderWidth(s);

    return SizedBox(
      width: d,
      height: d,
      child: Material(
        color: Colors.transparent,
        shape: CircleBorder(
          side: BorderSide(color: Colors.black, width: stroke),
        ),
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        child: KioskTap(
          onTap: () => openKioskLanguageSheet(context),
          child: Image.asset(
            language.imageUrl!,
            width: d,
            height: d,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}

/// Filter pills row: POPULAR/SIGNATURE/SEASONAL/SPECIALS/PURE, wrapping to a
/// second row for CEROMONIAL, matching the Figma layout. Pills toggle
/// independently — any number can be on at once, and the grid then shows the
/// products matching any of them. Tapping a lit pill turns it back off.
class _FilterPillsRow extends StatelessWidget {
  final double pillHeight;
  final double fontSize;
  final double borderWidth;
  final double hPadding;
  final double hGap;
  final double vGap;
  final Set<String> selected;
  final ValueChanged<String> onSelect;

  /// Landscape laptops: keep one row and scroll sideways so the second pill
  /// line does not steal product-grid height.
  final bool scrollInsteadOfWrap;
  const _FilterPillsRow({
    required this.pillHeight,
    required this.fontSize,
    required this.borderWidth,
    required this.hPadding,
    required this.hGap,
    required this.vGap,
    required this.selected,
    required this.onSelect,
    this.scrollInsteadOfWrap = false,
  });

  @override
  Widget build(BuildContext context) {
    final pills = <Widget>[
      for (final label in [..._kFilterPillLabels, _kFilterPillSecondRowLabel])
        _FilterPill(
          label: label,
          selected: selected.contains(label),
          height: pillHeight,
          fontSize: fontSize,
          borderWidth: borderWidth,
          hPadding: hPadding,
          onTap: () => onSelect(label),
        ),
    ];

    if (scrollInsteadOfWrap) {
      return SizedBox(
        height: pillHeight,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: pills.length,
          separatorBuilder: (_, __) => SizedBox(width: hGap),
          itemBuilder: (_, i) => pills[i],
        ),
      );
    }

    // Wrap (not a fixed Row) so pills reflow onto additional lines instead of
    // overflowing when the available width is narrower than the design's
    // 2414px artboard — CEROMONIAL lands on its own line at that width,
    // matching the Figma layout, but nothing clips on smaller screens.
    return Wrap(
      spacing: hGap,
      runSpacing: vGap,
      children: pills,
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final double height;
  final double fontSize;
  final double borderWidth;
  final double hPadding;
  final VoidCallback onTap;
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.height,
    required this.fontSize,
    required this.borderWidth,
    required this.hPadding,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double radius = height / 2;
    // IntrinsicWidth pins this to its content's natural width — without it,
    // Container's `alignment` makes it expand to fill whatever width Wrap
    // offers on its line, turning every pill into a full-width bar.
    return IntrinsicWidth(
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: KioskTap(
          onTap: onTap,
          child: Container(
            height: height,
            padding: EdgeInsets.symmetric(horizontal: hPadding),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? Colors.black : Colors.transparent,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: Colors.black, width: borderWidth),
            ),
            child: Text(
              label,
              style: loewMedium.copyWith(
                fontSize: fontSize,
                height: 1,
                color: selected ? Colors.white : Colors.black,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Left rail of category names: plain text on the page background with a
/// divider below each item (no card, no image); selected fills black with
/// white text. Width comes from [kioskCategoryRailLayout] so it shrinks on
/// small screens instead of staying a 524px Figma column.
class _CategoryRail extends StatelessWidget {
  final double s;
  final double width;
  final void Function(int id) onSelect;
  const _CategoryRail({
    required this.s,
    required this.width,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<CategoryProvider>(
      builder: (context, category, _) {
        final categories = category.categoryList;
        if (categories == null) {
          return SizedBox(
              width: width,
              child: const Center(child: CircularProgressIndicator()));
        }
        return SizedBox(
          width: width,
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: categories.length,
            separatorBuilder: (_, __) => SizedBox(height: 56 * s),
            itemBuilder: (context, index) {
              final c = categories[index];
              final bool selected = '${c.id}' == category.selectedSubCategoryId;
              return _RailCard(
                s: s,
                railWidth: width,
                name: c.name ?? '',
                selected: selected,
                onTap: () => onSelect(c.id!),
              );
            },
          ),
        );
      },
    );
  }
}

class _RailCard extends StatelessWidget {
  final double s;
  final double railWidth;
  final String name;
  final bool selected;
  final VoidCallback onTap;
  const _RailCard({
    required this.s,
    required this.railWidth,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? KioskUI.categorySelectedBg : Colors.transparent,
      child: KioskTap(
        onTap: onTap,
        child: Container(
          height: 130 * s,
          padding: EdgeInsets.symmetric(horizontal: 6 * s),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            border:
                Border(bottom: BorderSide(color: Colors.black, width: 2 * s)),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              name.toUpperCase(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: loewBold.copyWith(
                fontSize: kioskCategoryRailFontSize(
                      railWidth: railWidth,
                      scale: s,
                    ) *
                    _kMenuType,
                height: 1.1,
                color: selected ? Colors.white : Colors.black,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Right product area: responsive product grid with a static "SPECIAL EDITION"
/// promo banner inserted after the first rows.
class _ProductArea extends StatelessWidget {
  final double s;
  final bool landscape;
  final Set<String> tagFilters;
  const _ProductArea({
    required this.s,
    this.landscape = false,
    this.tagFilters = const <String>{},
  });

  @override
  Widget build(BuildContext context) {
    // The allergen answer is session state rather than a provider, so the grid
    // subscribes to it directly — the customer is looking straight at this grid
    // when the popup closes over it, and the excluded products have to be gone
    // by the time they see it again.
    return ListenableBuilder(
      listenable: KioskAllergenPreferences.instance,
      builder: (context, _) => Consumer2<CategoryProvider, SearchProvider>(
        builder: (context, category, search, _) {
          final bool filtersActive = kioskMenuFiltersActive(category, search);
          List<Product> products = filtersActive
              ? applyKioskMenuFilters(
                  categoryProvider: category,
                  searchProvider: search,
                )
              : (category.categoryProductModel?.products ?? const []);
          products = filterKioskProductsByTag(
            products: products,
            pillLabels: tagFilters,
          );
          // Applied on BOTH branches above, unlike the search-sheet filters:
          // an allergen is a constraint, not a preference, so it must hold even
          // when the customer never opened the filter sheet.
          products = filterKioskProductsByAllergens(
            products: products,
            avoided: KioskAllergenPreferences.instance.avoided,
          );

          return category.categoryProductModel == null && !filtersActive
              ? _ProductGridSkeleton(s: s, landscape: landscape)
              : products.isEmpty
                  ? _EmptyProductArea(s: s)
                  : _ProductGrid(
                      s: s, products: products, landscape: landscape);
        },
      ),
    );
  }
}

/// What the customer sees when the category has nothing to show.
///
/// Split out because the allergen case needs a way BACK. Once the popup has
/// been answered it never reopens on its own, so a customer who ticked
/// something by mistake would otherwise be left staring at an empty menu for
/// the rest of the order with no way to undo it — and the one thing they
/// cannot do is notice which products are missing.
class _EmptyProductArea extends StatelessWidget {
  final double s;
  const _EmptyProductArea({required this.s});

  @override
  Widget build(BuildContext context) {
    final bool byAllergen = KioskAllergenPreferences.instance.hasSelection;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            byAllergen
                // "No items" reads as a broken menu. Name the cause.
                ? kioskTranslate(context, 'allergen_no_matching_items',
                    'No items match your allergen filters')
                : (getTranslated('no_items', context) ?? 'No items'),
            textAlign: TextAlign.center,
            style: rubikRegular.copyWith(
                fontSize: 32 * s * _kMenuType, color: Theme.of(context).hintColor),
          ),
          if (byAllergen) ...[
            SizedBox(height: 32 * s),
            KioskTap(
              onTap: () => showKioskAllergenFilter(context),
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: 32 * s, vertical: 16 * s),
                child: Text(
                  kioskTranslate(context, 'allergen_change_filters',
                      'Change allergen filters'),
                  textAlign: TextAlign.center,
                  style: rubikRegular.copyWith(
                    fontSize: 32 * s * _kMenuType,
                    color: Colors.black,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProductGrid extends StatelessWidget {
  final double s;
  final List<Product> products;
  final bool landscape;
  const _ProductGrid({
    required this.s,
    required this.products,
    this.landscape = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double colGap = 41 * s;
        final double rowGap = (landscape ? 28 : 55) * s;
        final geo = KioskProductGridGeometry.resolve(
          areaWidth: constraints.maxWidth,
          gap: colGap,
          landscape: landscape,
        );
        final int columns = geo.columns;
        final double tileWidth = geo.tileWidth;
        final double tileHeight = geo.tileHeight;

        // Split so the full-width promo banner sits after the first two rows.
        final int firstCount =
            products.length >= columns * 2 ? columns * 2 : products.length;
        final List<Product> remaining = products.sublist(firstCount);

        final gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: colGap,
          mainAxisSpacing: rowGap,
          mainAxisExtent: tileHeight,
        );

        return ScrollConfiguration(
          behavior: const _NoGlowScrollBehavior(),
          child: Consumer<KioskDealProvider>(
            builder: (context, dealsProvider, _) {
              final deals = dealsProvider.deals;
              final bool showPromo = deals.isNotEmpty;
              final int splitAt = showPromo ? firstCount : products.length;
              final List<Product> rest =
                  showPromo ? remaining : const <Product>[];

              return CustomScrollView(
                slivers: [
                  SliverGrid(
                    gridDelegate: gridDelegate,
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _KioskProductCard(
                        s: s,
                        tileWidth: tileWidth,
                        product: products[index],
                        badge: _badgeForProduct(products[index]),
                      ),
                      childCount: splitAt,
                    ),
                  ),
                  if (showPromo)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(
                          top: rowGap,
                          bottom: rest.isNotEmpty ? rowGap : 0,
                        ),
                        child: _DealPromoBanner(s: s, deals: deals),
                      ),
                    ),
                  if (rest.isNotEmpty)
                    SliverGrid(
                      gridDelegate: gridDelegate,
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _KioskProductCard(
                            s: s,
                            tileWidth: tileWidth,
                            product: rest[index],
                            badge: _badgeForProduct(rest[index])),
                        childCount: rest.length,
                      ),
                    ),
                  SliverToBoxAdapter(child: SizedBox(height: 30 * s)),
                ],
              );
            },
          ),
        );
      },
    );
  }

  /// Badge from the product's own tags (Popular, Specials, …), not grid index.
  _Badge? _badgeForProduct(Product product) {
    final List<ProductTag> tags = product.tags ?? const <ProductTag>[];
    if (tags.isEmpty) return null;
    ProductTag chosen = tags.first;
    for (final ProductTag tag in tags) {
      if (tag.isKioskFilter == true) {
        chosen = tag;
        break;
      }
    }
    final String raw = chosen.tag?.trim() ?? '';
    if (raw.isEmpty) return null;
    return _Badge(_badgeLabel(raw), _badgeColor(chosen));
  }

  String _badgeLabel(String tag) {
    if (normalizeKioskTag(tag) == 'specials') return 'Special';
    if (tag.length <= 1) return tag.toUpperCase();
    return '${tag[0].toUpperCase()}${tag.substring(1).toLowerCase()}';
  }

  Color _badgeColor(ProductTag tag) {
    final Color? fromHex = _colorFromHex(tag.color);
    if (fromHex != null) return fromHex;
    switch (normalizeKioskTag(tag.tag ?? '')) {
      case 'popular':
        return _kPopularGreen;
      case 'specials':
        return _kSpecialRed;
      default:
        return _kSpecialRed;
    }
  }

  Color? _colorFromHex(String? hex) {
    if (hex == null) return null;
    final String value = hex.replaceFirst('#', '').trim();
    if (value.length != 6) return null;
    final int? parsed = int.tryParse(value, radix: 16);
    if (parsed == null) return null;
    return Color(0xFF000000 | parsed);
  }
}

class _Badge {
  final String label;
  final Color color;
  const _Badge(this.label, this.color);
}

/// Loading skeleton for the product grid: shimmering white cards laid out with
/// the exact same responsive geometry as [_ProductGrid], so the switch from
/// skeleton → real products is a seamless in-place swap (no size jump).
class _ProductGridSkeleton extends StatelessWidget {
  final double s;
  final bool landscape;
  const _ProductGridSkeleton({required this.s, this.landscape = false});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double colGap = 41 * s;
        final double rowGap = (landscape ? 28 : 55) * s;
        final geo = KioskProductGridGeometry.resolve(
          areaWidth: constraints.maxWidth,
          gap: colGap,
          landscape: landscape,
        );
        final int columns = geo.columns;
        final double tileWidth = geo.tileWidth;
        final double tileHeight = geo.tileHeight;

        return IgnorePointer(
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: columns * 2,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: colGap,
              mainAxisSpacing: rowGap,
              mainAxisExtent: tileHeight,
            ),
            itemBuilder: (context, index) =>
                _SkeletonCard(tileWidth: tileWidth),
          ),
        );
      },
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  final double tileWidth;
  const _SkeletonCard({required this.tileWidth});

  @override
  Widget build(BuildContext context) {
    final double ts = tileWidth / 564.0;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(60 * ts),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(24 * ts),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(40 * ts),
                child: CustomImageWidget.shimmerBox(),
              ),
            ),
            SizedBox(height: 24 * ts),
            CustomImageWidget.shimmerBox(
                width: double.infinity, height: 34 * ts),
            SizedBox(height: 14 * ts),
            Center(
              child: CustomImageWidget.shimmerBox(
                  width: 140 * ts, height: 34 * ts),
            ),
          ],
        ),
      ),
    );
  }
}

class _KioskProductCard extends StatelessWidget {
  final double s;
  final double tileWidth;
  final Product product;
  final _Badge? badge;
  const _KioskProductCard({
    required this.s,
    required this.tileWidth,
    required this.product,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final splash = Provider.of<SplashProvider>(context, listen: false);
    final String image = '${splash.baseUrls?.productImageUrl}/${product.image}';
    // Metrics scale with the actual tile width (design tile ≈ 564px) so the card
    // keeps the same proportions no matter how many columns fit on screen.
    final double ts = tileWidth / 564.0;
    final double cardRadius = 33 * ts;
    final double cardBorderWidth = 5.5 * ts;

    // White rounded card containing the image AND the name + price (matches the
    // Figma layout where text sits inside the card, not on the page below it).
    // Border radius/width + colour come straight from Figma (33px / 5.5px / #DED9C7),
    // scaled by `ts` so the card stays proportional at any kiosk screen size.
    // The image sits flush against the card edges (no inset padding) so it fills
    // the card edge-to-edge; Material's own rounded clip takes care of rounding
    // the image's top corners to match the card.
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cardRadius),
        side: BorderSide(color: BrandColors.cardBorder, width: cardBorderWidth),
      ),
      clipBehavior: Clip.antiAlias,
      child: KioskTap(
        onTap: () => openKioskCustomize(context, product),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomImageWidget(
                      placeholder: Images.placeholderImage,
                      image: image,
                      fit: BoxFit.cover,
                      useShimmer: true,
                      cacheWidth: CustomImageWidget.kKioskProductCacheWidth,
                    ),
                  ),
                  if (badge != null)
                    Positioned(
                      top: 30 * ts,
                      left: 0,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 28 * ts, vertical: 10 * ts),
                        decoration: BoxDecoration(
                          color: badge!.color,
                          borderRadius: BorderRadius.only(
                            topRight: Radius.circular(10 * ts),
                            bottomRight: Radius.circular(10 * ts),
                          ),
                        ),
                        child: Text(
                          badge!.label,
                          style: swiss721Light.copyWith(
                              color: Colors.white, fontSize: 34 * ts * _kMenuType),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(24 * ts, 16 * ts, 24 * ts, 24 * ts),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    product.name ?? '',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    // Figma: Loew ExtraBold (w800) 31.68px, 100% line height, 0 tracking.
                    style: loewExtraBold.copyWith(
                        fontSize: 45 * ts * _kMenuType,
                        height: 1.0,
                        letterSpacing: 0,
                        color: Colors.black),
                  ),
                  SizedBox(height: 8 * ts),
                  Text(
                    PriceConverterHelper.convertPrice(
                      product.price,
                      discount: product.discount,
                      discountType: product.discountType,
                    ),
                    textAlign: TextAlign.center,
                    // Figma: Swiss 721 Light (w300) 39.6px, 100% line height, 0 tracking.
                    style: swiss721Light.copyWith(
                        fontSize: 42 * ts * _kMenuType,
                        height: 1.5,
                        letterSpacing: 1,
                        color: Colors.black),
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

/// Data-driven promotional deal banner inserted mid-grid after the first two
/// product rows. Hidden when there are no active deals for this branch.
class _DealPromoBanner extends StatelessWidget {
  final double s;
  final List<KioskDeal> deals;
  const _DealPromoBanner({required this.s, required this.deals});

  @override
  Widget build(BuildContext context) {
    if (deals.isEmpty) return const SizedBox.shrink();
    if (deals.length == 1) {
      return _DealBannerTile(s: s, deal: deals.first);
    }
    return SizedBox(
      height: 760 * s,
      child: PageView.builder(
        itemCount: deals.length,
        itemBuilder: (context, index) => Padding(
          padding: EdgeInsets.only(right: index == deals.length - 1 ? 0 : 16 * s),
          child: _DealBannerTile(s: s, deal: deals[index]),
        ),
      ),
    );
  }
}

class _DealBannerTile extends StatelessWidget {
  final double s;
  final KioskDeal deal;
  const _DealBannerTile({required this.s, required this.deal});

  @override
  Widget build(BuildContext context) {
    final splash = Provider.of<SplashProvider>(context, listen: false);
    final String imageUrl = KioskProductImageHelper.resolveUrl(
      productImageBaseUrl:
          splash.baseUrls?.dealImageUrl ?? splash.baseUrls?.productImageUrl,
      filename: deal.image,
    );
    return KioskTap(
      onTap: () => openKioskDealDetail(context, deal),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(60 * s),
        child: SizedBox(
          height: 760 * s,
          width: double.infinity,
          child: imageUrl.isNotEmpty
              ? CustomImageWidget(
                  placeholder: Images.placeholderImage,
                  image: imageUrl,
                  fit: BoxFit.cover,
                )
              : const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Color(0xFF6B4A2F), Color(0xFFB98E5E)],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

// Dark button fill + cream text used by the filled cart bar (from the design).
const Color _kDarkButton = Color(0xFF1E1E1E);
const Color _kCreamText = Color(0xFFFFFFFF);

/// Fixed cart bar pinned to the bottom of the menu. Two states (per Figma):
///  • empty  → a single "CART / € 0.00" bar.
///  • filled → a COMBO MEAL upsell card on the left and VIEW CART (with the
///    item count) over CHECK OUT (with the total) on the right.
class _CartBar extends StatelessWidget {
  final double s;
  final double sideMargin;
  final bool landscape;
  const _CartBar({
    required this.s,
    required this.sideMargin,
    this.landscape = false,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cartProvider, _) {
        final cartList = cartProvider.cartList;
        final double total = kioskCartTotal(cartList);
        final int count = kioskCartItemCount(cartList);

        return Padding(
          padding: EdgeInsets.fromLTRB(
            sideMargin,
            (landscape ? 10 : 20) * s,
            sideMargin,
            (landscape ? 16 : 30) * s,
          ),
          child: count == 0
              ? _EmptyCartBar(s: s, total: total, landscape: landscape)
              : _FilledCartBar(
                  s: s,
                  total: total,
                  count: count,
                  cartList: cartList,
                  landscape: landscape,
                ),
        );
      },
    );
  }
}

class _EmptyCartBar extends StatelessWidget {
  final double s;
  final double total;
  final bool landscape;
  const _EmptyCartBar({
    required this.s,
    required this.total,
    this.landscape = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(80 * s),
      clipBehavior: Clip.antiAlias,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      child: KioskTap(
        onTap: () => openKioskCart(context),
        child: Container(
          height: (landscape ? 140 : 200) * s,
          padding: EdgeInsets.symmetric(horizontal: 100 * s),
          alignment: Alignment.centerLeft,
          child: Text(
            '${(getTranslated('cart', context) ?? 'CART').toUpperCase()} / ${PriceConverterHelper.convertPrice(total)}',
            style:
                loewExtraBold.copyWith(fontSize: 64 * s * _kMenuType, color: Colors.black),
          ),
        ),
      ),
    );
  }
}

class _FilledCartBar extends StatelessWidget {
  final double s;
  final double total;
  final int count;
  final List<CartModel?> cartList;
  final bool landscape;
  const _FilledCartBar({
    required this.s,
    required this.total,
    required this.count,
    required this.cartList,
    this.landscape = false,
  });

  @override
  Widget build(BuildContext context) {
    // The most recently added item is shown on the left.
    final CartModel? latest = cartList.isNotEmpty ? cartList.last : null;
    // Figma gives each stacked button a 252px height; total = 2*252 + the
    // 20px gap between them, so each Expanded below resolves back to 252*s.
    return SizedBox(
      height: (landscape ? 260 : 424) * s,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left: the latest item added to the cart.
          Expanded(
              flex: 47,
              child: _LatestItemCard(
                  s: s, cart: latest, index: cartList.length - 1)),
          SizedBox(width: 30 * s),
          // Right: VIEW CART over CHECK OUT.
          Expanded(
            flex: 44,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _ViewCartButton(s: s, count: count)),
                SizedBox(height: 20 * s),
                Expanded(child: _CheckoutButton(s: s, total: total)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewCartButton extends StatelessWidget {
  final double s;
  final int count;
  const _ViewCartButton({required this.s, required this.count});

  @override
  Widget build(BuildContext context) {
    // Figma: border-radius 30px, border 8px solid #000 (was a much
    // rounder 50px radius with a thin 2-6px border).
    final double radius = 30 * s;
    final double badge = 56 * s;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      child: KioskTap(
        onTap: () => openKioskCart(context),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.black, width: 8 * s),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                (getTranslated('view_cart', context) ?? 'VIEW CART')
                    .toUpperCase(),
                style: loewBold.copyWith(fontSize: 50 * s * _kMenuType, color: Colors.black),
              ),
              SizedBox(width: 24 * s),
              Container(
                width: badge,
                height: badge,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                    color: _kDarkButton, shape: BoxShape.circle),
                child: Text(
                  '$count',
                  style: loewExtraBold.copyWith(
                      fontSize: 30 * s * _kMenuType, color: _kCreamText),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckoutButton extends StatelessWidget {
  final double s;
  final double total;
  const _CheckoutButton({required this.s, required this.total});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _kDarkButton,
      // Matches _ViewCartButton's Figma radius (30px) so the paired buttons
      // read as one family instead of the old, much rounder 50px pill.
      borderRadius: BorderRadius.circular(30 * s),
      clipBehavior: Clip.antiAlias,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      child: KioskTap(
        onTap: () => RouterHelper.getKioskCheckoutRoute(),
        child: Container(
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: 30 * s),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  (getTranslated('check_out', context) ?? 'CHECK OUT')
                      .toUpperCase(),
                  style:
                      loewBold.copyWith(fontSize: 50 * s * _kMenuType, color: _kCreamText),
                ),
                SizedBox(width: 28 * s),
                Text(
                  PriceConverterHelper.convertPrice(total),
                  style: loewExtraBold.copyWith(
                      fontSize: 46 * s * _kMenuType, color: _kCreamText),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The most recently added cart item shown on the left of the filled cart bar:
/// its image, name and price, with a "+" to add another of the same item.
class _LatestItemCard extends StatelessWidget {
  final double s;
  final CartModel? cart;
  final int index;
  const _LatestItemCard(
      {required this.s, required this.cart, required this.index});

  @override
  Widget build(BuildContext context) {
    final splash = Provider.of<SplashProvider>(context, listen: false);
    final product = cart?.product;
    final bool isDeal = cart?.isDeal == true;
    final String image = isDeal
        ? KioskProductImageHelper.cartLineImageUrl(
            cart: cart!,
            productImageBaseUrl: splash.baseUrls?.productImageUrl,
            dealImageBaseUrl: splash.baseUrls?.dealImageUrl,
          )
        : '${splash.baseUrls?.productImageUrl}/${product?.image}';
    // `cart` is a public field, so the `== null` check above does not promote
    // it (dart.dev/go/non-promo-public-field). The bang is safe on this branch.
    final double unitPrice =
        cart == null ? 0 : kioskLineTotal(cart!) / (cart!.quantity ?? 1);
    final String title = isDeal
        ? (cart?.dealTitle ?? product?.name ?? '')
        : (product?.name ?? '');
    final double plus = 64 * s;
    // Figma: border-radius 40px, border 9px solid rgba(0,0,0,0.25),
    // background #FBF8EF. Height matches the View Cart / Check Out column
    // automatically — this card stretches to fill the shared parent Row's
    // fixed height (see _FilledCartBar).
    return Material(
      color: const Color(0xFFFBF8EF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(40 * s),
        side: BorderSide(
            color: Colors.black.withValues(alpha: 0.25), width: 9 * s),
      ),
      clipBehavior: Clip.antiAlias,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      child: KioskTap(
        onTap: () => openKioskCart(context),
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(40 * s, 24 * s, 40 * s, 24 * s),
              child: Row(
                children: [
                  // Latest product image (square).
                  AspectRatio(
                    aspectRatio: 1,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(40 * s),
                      child: CustomImageWidget(
                        placeholder: Images.placeholderImage,
                        image: image,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  SizedBox(width: 30 * s),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: loewExtraBold.copyWith(
                              fontSize: 38 * s * _kMenuType,
                              height: 1.1,
                              color: Colors.black),
                        ),
                        SizedBox(height: 8 * s),
                        Text(
                          PriceConverterHelper.convertPrice(unitPrice),
                          style: swiss721Light.copyWith(
                              fontSize: 32 * s * _kMenuType, color: Colors.black),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: plus + 16 * s), // room for the "+" button.
                ],
              ),
            ),
            // "+" — add another of this item.
            Positioned(
              right: 24 * s,
              bottom: 24 * s,
              child: Material(
                color: _kDarkButton,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: KioskTap(
                  onTap: product == null
                      ? null
                      : () => Provider.of<CartProvider>(context, listen: false)
                          .onUpdateCartQuantity(
                              index: index, product: product, isRemove: false),
                  child: SizedBox(
                    width: plus,
                    height: plus,
                    child: Icon(Icons.add, color: _kCreamText, size: 40 * s),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
