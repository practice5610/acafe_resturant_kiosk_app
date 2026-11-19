import 'package:flutter/material.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_staff_exit_trigger.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_language_sheet.dart';
import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/common/responsive/kiosk_layout.dart';
import 'package:acafe_customer/common/responsive/kiosk_responsive.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_logout_button.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_ui.dart';
import 'package:acafe_customer/common/widgets/custom_asset_image_widget.dart';
import 'package:acafe_customer/common/widgets/custom_image_widget.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/category/providers/category_provider.dart';
import 'package:acafe_customer/features/coupon/providers/coupon_provider.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_deal_banner.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_tap.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_menu_image_helper.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_product_image_helper.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_allergen.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_deal.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_menu_filter.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_translate.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_session.dart';
// Used only by the commented-out manager-access lock below (ownership
// moved to POS Settings). Restore together with that block.
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_deal_provider.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_allergen_filter_screen.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_product_customize_sheet.dart';
// Used only by the commented-out manager-access lock below (ownership
// moved to POS Settings). Restore together with that block.
// import 'package:acafe_customer/features/kiosk/widgets/kiosk_pin_entry_sheet.dart';
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
      showImages: context.read<KioskAuthProvider>().showImages,
      includeOptions: true,
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
          context, categoryProvider, splash,
          showImages: context.read<KioskAuthProvider>().showImages,
          includeOptions: true);
      Provider.of<KioskDealProvider>(context, listen: false).fetchDeals();
      return;
    }

    // Edge case: deep-linked to /menu-kiosk without visiting welcome first.
    await categoryProvider.ensureKioskMenuReady(localeCode: locale);
    if (!mounted) return;
    Provider.of<KioskDealProvider>(context, listen: false).fetchDeals();
    KioskMenuImageHelper.precacheAroundSelected(
        context, categoryProvider, splash,
        showImages: context.read<KioskAuthProvider>().showImages,
        includeOptions: true);
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
        context, categoryProvider, splash,
        showImages: context.read<KioskAuthProvider>().showImages,
        includeOptions: true);
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
                                    fontSize: 43.2 * s,
                                    borderWidth: 3.6 * s,
                                    hPadding: 42 * s,
                                    hGap: 19.8 * s,
                                    vGap: 28 * s,
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
          // Left-aligned brand title (the A/CAFÉ brand, per the design). On a
          // POS till serving as a kiosk, three quick taps are the staff way back
          // to POS; inert everywhere else.
          KioskStaffExitTrigger(
            child: Text(
              'A/CAFÉ',
              style: loewExtraBold.copyWith(
                fontSize: 120 * s,
                height: 1,
                letterSpacing: 2 * s,
                color: Colors.black,
              ),
            ),
          ),
          const Spacer(),
          // Right-aligned action icons.
          // OWNERSHIP MOVED TO POS SETTINGS (2026-09-04).
          //
          // This lock opened Kiosk manager access, whose Mark-Out-of-Stock
          // screen was the primary place `product_by_branches.is_available`
          // got toggled. That flag is now owned by POS Settings -> Products
          // (and the equivalent Add-ons screen), so the Kiosk lock UI is
          // disabled pending removal. Commented out rather than deleted so the
          // entry point is easy to restore if the decision is revisited.
          //
          // NOTE: this lock gated the WHOLE Kiosk manager area, not just the
          // stock screen — sales overview, Z-report close, and transactions
          // are also unreachable from the Kiosk main screen while it is off.
          // Everything behind it still exists and still works; only this
          // entry point is hidden. See KioskManagerProvider and
          // kiosk_manager_*_screen.dart.
          //
          // if (context.watch<KioskAuthProvider>().isPosDevice) ...[
          //   _CircleIconButton(
          //       s: s,
          //       assetPath: Images.managerAccessSvg,
          //       onTap: () => openKioskManagerAccess(context)),
          //   SizedBox(width: 38 * s),
          // ],
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
          SizedBox(width: 38 * s),
          // Staff sign-out — the same avatar + "Logout" dropdown +
          // confirmation the POS nav bar carries, and the same control the
          // kiosk welcome screen shows. Sized to the other top-bar circles.
          KioskLogoutButton(size: _topBarActionDiameter(s)),
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

  const _FilterPillsRow({
    required this.pillHeight,
    required this.fontSize,
    required this.borderWidth,
    required this.hPadding,
    required this.hGap,
    required this.vGap,
    required this.selected,
    required this.onSelect,
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

    // Wrap, in every composition. It puts as many pills on a line as the
    // measured width holds and reflows the rest, so a wide display shows the
    // whole set on one line and a narrow one gets the Figma's second line with
    // CEROMONIAL on it. Nothing is ever cut.
    //
    // Landscape used to scroll this row sideways instead, to stop a second
    // line taking height from the product grid. That traded a few pixels of
    // grid for a worse failure: the row clipped its last pill mid-word, with
    // no scrollbar and no fade to say there was more — "CEROMO" against the
    // panel edge reads as a broken layout, not as something to swipe. The
    // second line costs `pillHeight + vGap`, which is 74px on a 1366x768
    // laptop and less on anything larger, and on a display big enough to show
    // every pill at once it costs nothing at all because the row never wraps.
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
                ),
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
                fontSize: 32 * s, color: Theme.of(context).hintColor),
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
                    fontSize: 32 * s,
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
    final bool showImages = context.watch<KioskAuthProvider>().showImages;
    return LayoutBuilder(
      builder: (context, constraints) {
        final double colGap = 41 * s;
        final double rowGap = (landscape ? 28 : 55) * s;
        final geo = KioskProductGridGeometry.resolve(
          areaWidth: constraints.maxWidth,
          gap: colGap,
          landscape: landscape,
          showImages: showImages,
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
              // Isolate deal UI: a banner failure must never blank the product grid.
              List<KioskDeal> deals = const <KioskDeal>[];
              try {
                deals = dealsProvider.deals;
              } catch (_) {
                deals = const <KioskDeal>[];
              }
              // Picture-less device: the promo rail is pure deal artwork with
              // no text-only form, so it is dropped entirely rather than shown
              // as a blank/gradient box.
              final bool showPromo = deals.isNotEmpty && showImages;
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
                        showImages: showImages,
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
                        child: KioskDealPromoBanner(s: s, deals: deals),
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
                            badge: _badgeForProduct(rest[index]),
                            showImages: showImages),
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

  /// Badge from merchandising tags only (Popular, Specials, …).
  /// Allergen tags never appear here — see [kioskMenuCardBadgeTag].
  _Badge? _badgeForProduct(Product product) {
    final ProductTag? chosen = kioskMenuCardBadgeTag(product);
    if (chosen == null) return null;
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
    final bool showImages = context.watch<KioskAuthProvider>().showImages;
    return LayoutBuilder(
      builder: (context, constraints) {
        final double colGap = 41 * s;
        final double rowGap = (landscape ? 28 : 55) * s;
        final geo = KioskProductGridGeometry.resolve(
          areaWidth: constraints.maxWidth,
          gap: colGap,
          landscape: landscape,
          showImages: showImages,
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
                _SkeletonCard(tileWidth: tileWidth, showImages: showImages),
          ),
        );
      },
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  final double tileWidth;
  final bool showImages;
  const _SkeletonCard({required this.tileWidth, this.showImages = true});

  @override
  Widget build(BuildContext context) {
    final double ts = tileWidth / _CardDesign.cardWidth;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(_CardDesign.cardRadius * ts),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(24 * ts),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment:
              showImages ? MainAxisAlignment.start : MainAxisAlignment.center,
          mainAxisSize: showImages ? MainAxisSize.max : MainAxisSize.min,
          children: [
            if (showImages) ...[
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(40 * ts),
                  child: CustomImageWidget.shimmerBox(),
                ),
              ),
              SizedBox(height: 24 * ts),
            ],
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

// ─────────────────────────────────────────────────────────────────────────────
// Product card — Figma node 2305:12471 redesign
//
// Stack-based layout with ABSOLUTE positioning inside a fixed-size SizedBox.
// Every vertical offset is measured from the top of the card in design px and
// scaled by `ts = tileWidth / 548`. Content length never shifts any baseline.
// ─────────────────────────────────────────────────────────────────────────────

/// Design-unit constants for the product card (Figma 2305:12471).
/// Centralised here so they map 1:1 to the design spec.
class _CardDesign {
  _CardDesign._();

  // Card frame
  static const double cardWidth = 548;
  static const double cardHeight = 823;
  static const double cardRadius = 33;
  static const double cardBorderWidth = 5.5;

  // Photo feather mask
  static const double photoTop = -11;
  static const double photoWidthFraction = 0.82; // 82% of card width
  static const double photoHeight = 630;
  // The feather mask is a radial gradient: opaque centre → transparent edge.
  // Stops from the Figma SVG (paint0_radial_0_91): 0→0.45 opaque, 0.92→ transparent.
  static const double featherOpaqueStop = 0.45;
  static const double featherFadeStop = 0.92;

  // Allergen icons row
  static const double allergenTop = 574;
  static const double allergenIconSize = 32;
  static const double allergenIconGap = 6;
  static const double allergenRowHeight = 32;

  // Name text box
  static const double nameTop = 628;
  static const double nameHeight = 67; // fixed 2-line box
  static const double nameFontSize = 31.68;
  static const double nameLineHeight = 1.05;

  // Description
  static const double descGap = 7; // below name box
  static const double descHeight = 27;
  static const double descFontSize = 22;
  static const double descLineHeight = 1.2;

  // Price
  static const double priceGap = 9; // below description
  static const double priceHeight = 42;
  static const double priceFontSize = 39.6;
  static const double priceLineHeight = 1.05;

  // Text side inset (from card edge to text block)
  static const double textInset = 24;

  // Badge (POPULAR / OUT OF STOCK)
  static const double badgeTop = 38.5;
  static const double badgeLeft = 27.5;
  static const double badgeHeight = 68;
  static const double badgeRadius = 1098.9; // full pill
  static const double badgeFontSize = 35.2;

  // Info icon
  static const double infoTop = 24;
  static const double infoRight = 23;
  static const double infoSize = 40;
  static const double infoFontSize = 22;

  // Out-of-stock
  static const double outOfStockOpacity = 0.45;
  static const Color outOfStockBadgeColor = Color(0xFF808080);
  static const Color outOfStockTextColor = Color(0xFF808080);
}

class _KioskProductCard extends StatelessWidget {
  final double s;
  final double tileWidth;
  final Product product;
  final _Badge? badge;
  final bool showImages;
  const _KioskProductCard({
    required this.s,
    required this.tileWidth,
    required this.product,
    this.badge,
    this.showImages = true,
  });

  /// Out of stock when the branch-level record explicitly says so.
  /// A null [BranchProduct] means the product has no branch override — treat
  /// it as available (the backend would not include it otherwise).
  bool get _isOutOfStock =>
      product.branchProduct != null && product.branchProduct!.isAvailable != true;

  @override
  Widget build(BuildContext context) {
    // Picture-less device: use the compact text-only card.
    if (!showImages) return _buildTextOnlyCard(context);

    final double ts = tileWidth / _CardDesign.cardWidth;
    final double cardRadius = _CardDesign.cardRadius * ts;
    final double cardBorderWidth = _CardDesign.cardBorderWidth * ts;
    final double tileHeight = tileWidth * (_CardDesign.cardHeight / _CardDesign.cardWidth);

    final cardContent = SizedBox(
      width: tileWidth,
      height: tileHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Feathered photo ──
          _buildPhoto(context, ts),

          // ── Allergen icons ──
          _buildAllergenRow(ts),

          // ── Name (fixed 2-line box) ──
          _buildName(ts),

          // ── Description ──
          _buildDescription(ts),

          // ── Price ──
          _buildPrice(ts),

          // ── Badge (POPULAR / OUT OF STOCK) ──
          if (badge != null && !_isOutOfStock) _buildBadge(ts),
          if (_isOutOfStock) _buildOutOfStockBadge(ts),
        ],
      ),
    );

    final card = Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cardRadius),
        side: BorderSide(color: BrandColors.cardBorder, width: cardBorderWidth),
      ),
      clipBehavior: Clip.antiAlias,
      child: cardContent,
    );

    // Out-of-stock: fade the card and block taps (but keep the info icon live).
    // The info icon is positioned OUTSIDE the card's tap area via a separate
    // Stack layer, so AbsorbPointer on the card does not kill it.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Card body — tappable unless out of stock.
        Opacity(
          opacity: _isOutOfStock ? _CardDesign.outOfStockOpacity : 1.0,
          child: _isOutOfStock
              ? AbsorbPointer(child: card)
              : KioskTap(
                  onTap: () => openKioskCustomize(context, product),
                  child: card,
                ),
        ),
        // ── Info (i) icon — always tappable ──
        _buildInfoIcon(context, ts),
      ],
    );
  }

  /// Compact text-only card (picture-less device / show-images off).
  Widget _buildTextOnlyCard(BuildContext context) {
    final double ts = tileWidth / _CardDesign.cardWidth;
    final double cardRadius = _CardDesign.cardRadius * ts;
    final double cardBorderWidth = _CardDesign.cardBorderWidth * ts;

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cardRadius),
        side: BorderSide(color: BrandColors.cardBorder, width: cardBorderWidth),
      ),
      clipBehavior: Clip.antiAlias,
      child: KioskTap(
        onTap: _isOutOfStock ? null : () => openKioskCustomize(context, product),
        child: Opacity(
          opacity: _isOutOfStock ? _CardDesign.outOfStockOpacity : 1.0,
          child: Padding(
            padding: EdgeInsets.fromLTRB(24 * ts, 16 * ts, 24 * ts, 24 * ts),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (badge != null) ...[
                  Center(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 20 * ts, vertical: 6 * ts),
                      decoration: BoxDecoration(
                        color: _isOutOfStock
                            ? _CardDesign.outOfStockBadgeColor
                            : badge!.color,
                        borderRadius: BorderRadius.circular(10 * ts),
                      ),
                      child: Text(
                        _isOutOfStock ? 'OUT OF STOCK' : badge!.label,
                        style: loewMedium.copyWith(
                            color: Colors.white, fontSize: 28 * ts),
                      ),
                    ),
                  ),
                  SizedBox(height: 12 * ts),
                ],
                Text(
                  product.name ?? '',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: loewExtraBold.copyWith(
                    fontSize: _CardDesign.nameFontSize * ts,
                    height: _CardDesign.nameLineHeight,
                    letterSpacing: 0,
                    color: _isOutOfStock
                        ? _CardDesign.outOfStockTextColor
                        : Colors.black,
                  ),
                ),
                SizedBox(height: 8 * ts),
                Text(
                  PriceConverterHelper.convertPrice(
                    product.price,
                    discount: product.discount,
                    discountType: product.discountType,
                  ),
                  textAlign: TextAlign.center,
                  style: swiss721Light.copyWith(
                    fontSize: _CardDesign.priceFontSize * ts,
                    height: _CardDesign.priceLineHeight,
                    color: _isOutOfStock
                        ? _CardDesign.outOfStockTextColor
                        : Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Feathered product photo with radial gradient mask.
  Widget _buildPhoto(BuildContext context, double ts) {
    final splash = Provider.of<SplashProvider>(context, listen: false);
    final String image = '${splash.baseUrls?.productImageUrl}/${product.image}';
    final double photoWidth = tileWidth * _CardDesign.photoWidthFraction;
    final double photoHeight = _CardDesign.photoHeight * ts;
    final double photoLeft = (tileWidth - photoWidth) / 2;

    return Positioned(
      top: _CardDesign.photoTop * ts,
      left: photoLeft,
      width: photoWidth,
      height: photoHeight,
      child: ShaderMask(
        shaderCallback: (Rect bounds) => const RadialGradient(
          center: Alignment.center,
          radius: 1.0,
          colors: [
            Colors.black,
            Colors.black,
            Colors.transparent,
          ],
          stops: [
            0.0,
            _CardDesign.featherOpaqueStop,
            _CardDesign.featherFadeStop,
          ],
        ).createShader(bounds),
        blendMode: BlendMode.dstIn,
        child: CustomImageWidget(
          placeholder: Images.placeholderImage,
          image: image,
          fit: BoxFit.cover,
          useShimmer: true,
          cacheWidth: CustomImageWidget.kKioskProductCacheWidth,
        ),
      ),
    );
  }

  /// Allergen icons row — always reserves its height even with no allergens.
  Widget _buildAllergenRow(double ts) {
    final Set<KioskAllergen> allergens = kioskProductAllergens(product);
    final double iconSize = _CardDesign.allergenIconSize * ts;
    final double iconGap = _CardDesign.allergenIconGap * ts;

    return Positioned(
      top: _CardDesign.allergenTop * ts,
      left: 0,
      right: 0,
      height: _CardDesign.allergenRowHeight * ts,
      child: allergens.isEmpty
          ? SizedBox(height: _CardDesign.allergenRowHeight * ts)
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < allergens.length; i++) ...[
                  if (i > 0) SizedBox(width: iconGap),
                  Container(
                    width: iconSize,
                    height: iconSize,
                    decoration: BoxDecoration(
                      color: allergens.elementAt(i).swatch,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: CustomAssetImageWidget(
                        allergens.elementAt(i).icon,
                        width: iconSize * 0.57,
                        height: iconSize * 0.57,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  /// Product name — fixed 2-line box, vertically centered when 1 line.
  Widget _buildName(double ts) {
    final double nameHeight = _CardDesign.nameHeight * ts;
    final double textInset = _CardDesign.textInset * ts;

    return Positioned(
      top: _CardDesign.nameTop * ts,
      left: textInset,
      right: textInset,
      height: nameHeight,
      child: Center(
        child: Text(
          product.name ?? '',
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: loewExtraBold.copyWith(
            fontSize: _CardDesign.nameFontSize * ts,
            height: _CardDesign.nameLineHeight,
            letterSpacing: 0,
            color: _isOutOfStock
                ? _CardDesign.outOfStockTextColor
                : Colors.black,
          ),
        ),
      ),
    );
  }

  /// Product description — 1 line with ellipsis.
  Widget _buildDescription(double ts) {
    final double descTop =
        (_CardDesign.nameTop + _CardDesign.nameHeight + _CardDesign.descGap) * ts;
    final double textInset = _CardDesign.textInset * ts;

    return Positioned(
      top: descTop,
      left: textInset,
      right: textInset,
      height: _CardDesign.descHeight * ts,
      child: Center(
        child: Text(
          product.description ?? '',
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: swiss721Light.copyWith(
            fontSize: _CardDesign.descFontSize * ts,
            height: _CardDesign.descLineHeight,
            color: const Color(0xFF4D4D4D),
          ),
        ),
      ),
    );
  }

  /// Price — single line.
  Widget _buildPrice(double ts) {
    final double priceTop =
        (_CardDesign.nameTop +
            _CardDesign.nameHeight +
            _CardDesign.descGap +
            _CardDesign.descHeight +
            _CardDesign.priceGap) *
        ts;
    final double textInset = _CardDesign.textInset * ts;

    return Positioned(
      top: priceTop,
      left: textInset,
      right: textInset,
      height: _CardDesign.priceHeight * ts,
      child: Center(
        child: Text(
          PriceConverterHelper.convertPrice(
            product.price,
            discount: product.discount,
            discountType: product.discountType,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: swiss721Light.copyWith(
            fontSize: _CardDesign.priceFontSize * ts,
            height: _CardDesign.priceLineHeight,
            color: _isOutOfStock
                ? _CardDesign.outOfStockTextColor
                : Colors.black,
          ),
        ),
      ),
    );
  }

  /// POPULAR badge — green pill, top-left.
  Widget _buildBadge(double ts) {
    return Positioned(
      top: _CardDesign.badgeTop * ts,
      left: _CardDesign.badgeLeft * ts,
      child: Container(
        height: _CardDesign.badgeHeight * ts,
        padding: EdgeInsets.symmetric(horizontal: 28 * ts),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: badge!.color,
          borderRadius: BorderRadius.circular(_CardDesign.badgeRadius * ts),
        ),
        child: Text(
          badge!.label.toUpperCase(),
          style: loewMedium.copyWith(
            fontSize: _CardDesign.badgeFontSize * ts,
            height: 1,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  /// OUT OF STOCK badge — grey pill, top-left.
  Widget _buildOutOfStockBadge(double ts) {
    return Positioned(
      top: _CardDesign.badgeTop * ts,
      left: _CardDesign.badgeLeft * ts,
      child: Container(
        height: _CardDesign.badgeHeight * ts,
        padding: EdgeInsets.symmetric(horizontal: 28 * ts),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _CardDesign.outOfStockBadgeColor,
          borderRadius: BorderRadius.circular(_CardDesign.badgeRadius * ts),
        ),
        child: Text(
          'OUT OF STOCK',
          style: loewMedium.copyWith(
            fontSize: _CardDesign.badgeFontSize * ts,
            height: 1,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  /// Info (i) icon — 40×40 circle, top-right, independently tappable.
  Widget _buildInfoIcon(BuildContext context, double ts) {
    final double infoSize = _CardDesign.infoSize * ts;
    final double infoRight = _CardDesign.infoRight * ts;
    final double infoTop = _CardDesign.infoTop * ts;

    return Positioned(
      top: infoTop,
      right: infoRight,
      child: KioskTap(
        onTap: () => _showProductInfoDialog(context),
        child: Container(
          width: infoSize,
          height: infoSize,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(infoSize / 2),
          ),
          alignment: Alignment.center,
          child: Text(
            'i',
            style: loewBold.copyWith(
              fontSize: _CardDesign.infoFontSize * ts,
              height: 1,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  /// Ingredients & allergens info popup.
  void _showProductInfoDialog(BuildContext context) {
    final Set<KioskAllergen> allergens = kioskProductAllergens(product);
    final double s = KioskLayout.scaleOf(context);
    showDialog(
      context: context,
      builder: (context) => _ProductInfoDialog(
        product: product,
        allergens: allergens,
        s: s,
      ),
    );
  }
}

/// Ingredients & allergens popup dialog.
class _ProductInfoDialog extends StatelessWidget {
  final Product product;
  final Set<KioskAllergen> allergens;
  final double s;
  const _ProductInfoDialog({
    required this.product,
    required this.allergens,
    required this.s,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: KioskUI.pageBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30 * s),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 600 * s),
        child: Padding(
          padding: EdgeInsets.all(40 * s),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      product.name ?? '',
                      style: loewExtraBold.copyWith(
                        fontSize: 36 * s,
                        height: 1.1,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  KioskTap(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.close, size: 36 * s, color: Colors.black),
                  ),
                ],
              ),
              if (product.description != null &&
                  product.description!.isNotEmpty) ...[
                SizedBox(height: 16 * s),
                Text(
                  product.description!,
                  style: swiss721Light.copyWith(
                    fontSize: 24 * s,
                    height: 1.3,
                    color: const Color(0xFF4D4D4D),
                  ),
                ),
              ],
              if (allergens.isNotEmpty) ...[
                SizedBox(height: 28 * s),
                Text(
                  'Allergens',
                  style: loewBold.copyWith(
                    fontSize: 28 * s,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 16 * s),
                Wrap(
                  spacing: 12 * s,
                  runSpacing: 12 * s,
                  children: allergens.map((allergen) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 36 * s,
                          height: 36 * s,
                          decoration: BoxDecoration(
                            color: allergen.swatch,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: CustomAssetImageWidget(
                              allergen.icon,
                              width: 20 * s,
                              height: 20 * s,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(width: 8 * s),
                        Text(
                          allergen.label,
                          style: swiss721Light.copyWith(
                            fontSize: 24 * s,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ],
            ],
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
    // The coupon is read here too: this bar quotes the customer the same
    // number the cart screen and the payment screen will, and summing the
    // lines on their own would quietly drop tax and any applied coupon.
    return Consumer2<CartProvider, CouponProvider>(
      builder: (context, cartProvider, couponProvider, _) {
        final cartList = cartProvider.cartList;
        final double total =
            kioskPayableTotal(cartList, couponProvider.discount ?? 0);
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
                loewExtraBold.copyWith(fontSize: 64 * s, color: Colors.black),
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
                style: loewBold.copyWith(fontSize: 50 * s, color: Colors.black),
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
                      fontSize: 30 * s, color: _kCreamText),
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
        onTap: () => openKioskCheckout(context),
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
                      loewBold.copyWith(fontSize: 50 * s, color: _kCreamText),
                ),
                SizedBox(width: 28 * s),
                Text(
                  PriceConverterHelper.convertPrice(total),
                  style: loewExtraBold.copyWith(
                      fontSize: 46 * s, color: _kCreamText),
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
    final bool showImages = context.watch<KioskAuthProvider>().showImages;
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
    // Per-unit price (product + add-ons), not lineTotal/qty — that old split
    // shrank when qty rose because add-ons were not scaled with quantity.
    final double unitPrice = cart == null ? 0 : kioskLineUnitPrice(cart!);
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
                  // Latest product image (square). Dropped on a picture-less
                  // device so the name + price take the full card width.
                  if (showImages) ...[
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
                  ],
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
                              fontSize: 38 * s,
                              height: 1.1,
                              color: Colors.black),
                        ),
                        SizedBox(height: 8 * s),
                        Text(
                          PriceConverterHelper.convertPrice(unitPrice),
                          style: swiss721Light.copyWith(
                              fontSize: 32 * s, color: Colors.black),
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
