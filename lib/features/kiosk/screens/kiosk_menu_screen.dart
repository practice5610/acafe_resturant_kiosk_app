import 'package:flutter/material.dart';
import 'package:acafe_customer/common/models/kiosk_theme.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_staff_exit_trigger.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_language_sheet.dart';
import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/common/responsive/kiosk_layout.dart';
import 'package:acafe_customer/common/responsive/kiosk_responsive.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_logout_button.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_menu_search.dart';
import 'package:acafe_customer/common/widgets/custom_image_widget.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/category/providers/category_provider.dart';
import 'package:acafe_customer/features/coupon/providers/coupon_provider.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_deal_banner.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_filter_chip_style.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_product_card.dart';
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
import 'package:acafe_customer/features/pos/domain/pos_category_layout.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_deal_provider.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_allergen_filter_screen.dart';
import 'package:acafe_customer/features/pos/widgets/pos_equal_height_row.dart';
// Used only by the commented-out manager-access lock below (ownership
// moved to POS Settings). Restore together with that block.
// import 'package:acafe_customer/features/kiosk/widgets/kiosk_pin_entry_sheet.dart';
import 'package:acafe_customer/features/language/providers/localization_provider.dart';
import 'package:acafe_customer/features/search/providers/search_provider.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/helper/price_converter_helper.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_upsell_sheet.dart';
import 'package:acafe_customer/localization/language_constrants.dart';
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

/// Portrait chip font size at the 864 reference (font family stays Poppins).
const double _kChipFont = 12;

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

  /// Inline top-bar search (replaces the old push to the search route).
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  bool _searchOpen = false;

  void _openSearch() => setState(() => _searchOpen = true);

  void _closeSearch() {
    _searchFocus.unfocus();
    _searchCtrl.clear();
    setState(() => _searchOpen = false);
  }

  void _onSearchFocusChange() {
    // Keyboard dismissed with nothing typed -> fold back to the circle.
    if (!_searchFocus.hasFocus &&
        _searchOpen &&
        _searchCtrl.text.trim().isEmpty) {
      setState(() => _searchOpen = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _localization = Provider.of<LocalizationProvider>(context, listen: false);
    _lastLocale = _localization!.locale.languageCode;
    // Refetch menu data when the language changes while this screen is open, so
    // the product grid updates instantly (not only after navigating away/back).
    _localization!.addListener(_onLocaleChanged);
    _searchFocus.addListener(_onSearchFocusChange);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _localization?.removeListener(_onLocaleChanged);
    _searchFocus.removeListener(_onSearchFocusChange);
    _searchFocus.dispose();
    _searchCtrl.dispose();
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
    // Picking a category is leaving search.
    if (_searchOpen || _searchCtrl.text.isNotEmpty) _closeSearch();
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
    // Per-kiosk theme (admin > Device > Theme). Null field = the built-in look.
    final KioskTheme theme = context
        .select<KioskAuthProvider, KioskTheme>((a) => a.portraitTheme);
    return Scaffold(
      backgroundColor: theme.screenBg ?? _MenuSpec.contentBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // `s` = legacy kiosk scale, still used by the deal banner, empty
            // state and search field internals. `u` = the redesign's unit:
            // 1 reference px at an 864-wide frame (see [_MenuSpec]).
            final double s = KioskLayout.scaleOf(context, constraints);
            final bool landscape =
                KioskLayout.isLandscape(context, constraints);
            final double u = _MenuSpec.unit(constraints);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _MenuSidebar(u: u, onSelect: _onSelectCategory),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Column(
                                children: [
                                  SizedBox(height: _MenuSpec.decoLineTop * u),
                                  _DecorativeLines(u: u),
                                  SizedBox(height: 11 * u),
                                  _CategoryTitle(u: u),
                                  SizedBox(height: 10 * u),
                                  Padding(
                                    padding: EdgeInsets.fromLTRB(
                                        _MenuSpec.gridPadLeft * u,
                                        0,
                                        _MenuSpec.gridPadRight * u,
                                        0),
                                    child: _FilterPillsRow(
                                      u: u,
                                      selected: _selectedTagPills,
                                      onSelect: (label) => setState(() {
                                        if (!_selectedTagPills.remove(label)) {
                                          _selectedTagPills.add(label);
                                        }
                                      }),
                                    ),
                                  ),
                                  SizedBox(height: 16 * u),
                                  Expanded(
                                    child: ValueListenableBuilder<
                                        TextEditingValue>(
                                      valueListenable: _searchCtrl,
                                      builder: (context, value, _) =>
                                          _ProductArea(
                                        s: s,
                                        u: u,
                                        landscape: landscape,
                                        tagFilters: _selectedTagPills,
                                        searchQuery: value.text.trim(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              top: _MenuSpec.headerTop * u,
                              right: _MenuSpec.headerRight * u,
                              child: _KioskTopBar(
                                u: u,
                                search: KioskMenuSearch(
                                  s: s,
                                  diameter: _MenuSpec.headerButton * u,
                                  expandedWidth: 340 * u,
                                  flat: true,
                                  open: _searchOpen,
                                  controller: _searchCtrl,
                                  focusNode: _searchFocus,
                                  onOpen: _openSearch,
                                  onClose: _closeSearch,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _CartBar(s: s, u: u),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Every size on this screen is authored against the 864-px-wide portrait
/// reference and multiplied by [unit], so the real kiosk is a proportional
/// copy. Height also bounds the unit so a short window never inflates it.
class _MenuSpec {
  _MenuSpec._();

  static const double refWidth = 864;
  static const double refHeight = 1270;

  static double unit(BoxConstraints c) {
    final double byW = c.maxWidth / refWidth;
    final double byH = c.maxHeight / refHeight;
    return byW < byH ? byW : byH;
  }

  // Colours (sampled from the reference).
  static const Color sidebarBg = Color(0xFFF9EBD7);
  static const Color sidebarSelectedBg = Color(0xFFFBF1E4);
  static const Color sidebarRule = Color(0xFFEADBC4);
  static const Color contentBg = Color(0xFFF6F5F5);
  static const Color cardDivider = Color(0xFFEFEFEF);
  static const Color priceInk = Color(0xFF333333);
  static const Color ink = Color(0xFF111111);
  static const Color decoLine = Color(0xFFE6D6D2);

  // Sidebar.
  static const double sidebarWidth = 208;
  static const double logoTop = 45;
  static const double logoWidth = 140;
  static const double categoryItemHeight = 123;
  static const double categoryImage = 80;

  // Header buttons.
  static const double headerButton = 50;
  static const double headerGap = 10;
  static const double headerTop = 15;
  static const double headerRight = 18;

  // Title.
  static const double decoLineTop = 61;
  static const double titleSize = 38;

  // Grid.
  static const double gridPadLeft = 19;
  static const double gridPadRight = 23;
  static const double gridGap = 16;
  static const double cardWidth = 300;
  static const double cardHeight = 340;

  static List<BoxShadow> softShadow(double u) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 10 * u,
          offset: Offset(0, 2 * u),
        ),
      ];
}

/// One thin short rule above the category title, left of centre.
class _DecorativeLines extends StatelessWidget {
  final double u;
  const _DecorativeLines({required this.u});

  @override
  Widget build(BuildContext context) {
    Widget line() =>
        Container(width: 80 * u, height: 1 * u, color: _MenuSpec.decoLine);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      // Left rule only; the right one sat under the search button. The
      // trailing spacer keeps the left rule exactly where it was.
      children: [line(), SizedBox(width: 240 * u + 80 * u)],
    );
  }
}

/// Selected category name, centred (text centre ~108 from the top).
class _CategoryTitle extends StatelessWidget {
  final double u;
  const _CategoryTitle({required this.u});

  @override
  Widget build(BuildContext context) {
    final category = context.watch<CategoryProvider>();
    String name = '';
    for (final c in category.categoryList ?? const []) {
      if ('${c.id}' == category.selectedSubCategoryId) {
        name = c.name ?? '';
        break;
      }
    }
    return SizedBox(
      height: 70 * u,
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24 * u),
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: poppinsMedium.copyWith(
              fontSize: _MenuSpec.titleSize * u,
              height: 1.2,
              letterSpacing: 0,
              color: _MenuSpec.ink,
            ),
          ),
        ),
      ),
    );
  }
}

/// Top-right header actions: search, language flag, filter — circular white
/// buttons with a soft shadow. Each keeps its existing action.
class _KioskTopBar extends StatelessWidget {
  final double u;
  final Widget search;
  const _KioskTopBar({required this.u, required this.search});

  @override
  Widget build(BuildContext context) {
    final double gap = _MenuSpec.headerGap * u;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
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
        //       u: u,
        //       assetPath: Images.managerAccessSvg,
        //       onTap: () => openKioskManagerAccess(context)),
        //   SizedBox(width: gap),
        // ],
        search,
        SizedBox(width: gap),
        _LanguageFlagButton(u: u),
        SizedBox(width: gap),
        _CircleIconButton(
          u: u,
          icon: Icons.filter_alt,
          onTap: () => openKioskMenuFilterSheet(context),
        ),
      ],
    );
  }
}

/// White 50-px circle with a soft shadow — the shared header button shell.
class _WhiteCircle extends StatelessWidget {
  final double u;
  final VoidCallback onTap;
  final Widget child;
  const _WhiteCircle(
      {required this.u, required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    final double d = _MenuSpec.headerButton * u;
    return Container(
      width: d,
      height: d,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 10 * u,
            offset: Offset(0, 2 * u),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: KioskTap(onTap: onTap, child: Center(child: child)),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final double u;
  final IconData icon;
  final VoidCallback onTap;
  const _CircleIconButton(
      {required this.u, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _WhiteCircle(
      u: u,
      onTap: onTap,
      child: Icon(icon, size: 24 * u, color: _MenuSpec.ink),
    );
  }
}

class _LanguageFlagButton extends StatelessWidget {
  final double u;
  const _LanguageFlagButton({required this.u});

  @override
  Widget build(BuildContext context) {
    final String code =
        Provider.of<LocalizationProvider>(context).locale.languageCode;
    final language = AppConstants.languages.firstWhere(
      (l) => l.languageCode == code,
      orElse: () => AppConstants.languages.first,
    );
    final double flag = 22 * u;
    return _WhiteCircle(
      u: u,
      onTap: () => openKioskLanguageSheet(context),
      child: ClipOval(
        child: Image.asset(
          language.imageUrl!,
          width: flag,
          height: flag,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}

/// Filter pills (POPULAR … CEROMONIAL) under the title: white pills with a
/// soft shadow. Same multi-select toggle as before; a lit pill fills ink.
class _FilterPillsRow extends StatelessWidget {
  final double u;
  final Set<String> selected;
  final ValueChanged<String> onSelect;

  const _FilterPillsRow({
    required this.u,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    // Wrap (not a sideways scroll): on the portrait frame every pill fits on
    // one line; a narrower window reflows instead of clipping a pill mid-word.
    final double gap = KioskFilterChipStyle.gap(_kChipFont * u);
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: gap,
      runSpacing: gap,
      children: [
        for (final label in [..._kFilterPillLabels, _kFilterPillSecondRowLabel])
          _FilterPill(
            u: u,
            label: label,
            selected: selected.contains(label),
            onTap: () => onSelect(label),
          ),
      ],
    );
  }
}

class _FilterPill extends StatelessWidget {
  final double u;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterPill({
    required this.u,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Shared landscape chip look (KioskFilterChipStyle): black outline, full
    // pill, transparent, no shadow; selected = black with white text.
    // Portrait keeps its own font (Poppins 12).
    final double font = _kChipFont * u;
    return KioskTap(
      onTap: onTap,
      child: Container(
        padding: KioskFilterChipStyle.padding(font),
        // Portrait refinement: a hairline outline in soft ink (the shared
        // 1.2 black read heavy at this size) and light tracking on the caps.
        decoration: KioskFilterChipStyle.decoration(
          selected: selected,
          fontSize: font,
          borderColor: Colors.black.withValues(alpha: 0.35),
          borderWidth: (0.8 * u).clamp(0.75, 1.0),
        ),
        child: Text(
          label,
          style: poppinsMedium.copyWith(
            fontSize: font,
            height: 1,
            letterSpacing: 0.6 * u,
            color: KioskFilterChipStyle.textColor(selected),
          ),
        ),
      ),
    );
  }
}

/// Left sidebar: logo, scrolling category list (circular image + label) and
/// the logout control pinned at the bottom. The list ends above the footer.
class _MenuSidebar extends StatelessWidget {
  final double u;
  final void Function(int id) onSelect;
  const _MenuSidebar({required this.u, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final KioskTheme theme = context
        .select<KioskAuthProvider, KioskTheme>((a) => a.portraitTheme);
    return Container(
      width: _MenuSpec.sidebarWidth * u,
      color: theme.sidebarBg ?? _MenuSpec.sidebarBg,
      child: Column(
        children: [
          SizedBox(height: _MenuSpec.logoTop * u),
          // On a POS till serving as a kiosk, three quick taps on the brand
          // are the staff way back to POS; inert everywhere else.
          KioskStaffExitTrigger(
            child: SizedBox(
              width: _MenuSpec.logoWidth * u,
              child: FittedBox(
                fit: BoxFit.contain,
                child: Text(
                  'A/CAFÉ',
                  style: loewExtraBold.copyWith(
                    fontSize: 40,
                    height: 1,
                    letterSpacing: 0.5,
                    color: _MenuSpec.ink,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 24 * u),
          Expanded(child: _CategoryRail(u: u, onSelect: onSelect)),
          _SidebarLogout(u: u),
        ],
      ),
    );
  }
}

/// The existing kiosk logout (same dropdown + confirmation, same kiosk-mode
/// hiding) dressed as the sidebar footer: rule, icon, "Logout".
class _SidebarLogout extends StatelessWidget {
  final double u;
  const _SidebarLogout({required this.u});

  @override
  Widget build(BuildContext context) {
    final Color ink = context.select<KioskAuthProvider, KioskTheme>(
                (a) => a.portraitTheme).sidebarText ??
        _MenuSpec.ink;
    return KioskLogoutButton(
      child: Container(
        width: _MenuSpec.sidebarWidth * u,
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: _MenuSpec.sidebarRule, width: 1 * u),
          ),
        ),
        padding: EdgeInsets.only(top: 16 * u, bottom: 24 * u),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.logout, size: 22 * u, color: ink),
            SizedBox(height: 4 * u),
            Text(
              'Logout',
              style: poppinsMedium.copyWith(
                fontSize: 12 * u,
                height: 1.2,
                color: ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Category list. Each row: 80-px circular category image with the label 8
/// below; the selected row gets a full-width lighter-cream band.
///
/// The image follows the per-device "Show Category Images" Kiosk Setting and
/// the picture-less device mode, exactly as the old rail did: when either is
/// off, the row shows the label alone (no image fetched).
class _CategoryRail extends StatelessWidget {
  final double u;
  final void Function(int id) onSelect;
  const _CategoryRail({required this.u, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    // watch (not read) so a live device.settings push re-skins the rail.
    final KioskAuthProvider auth = context.watch<KioskAuthProvider>();
    final bool images =
        auth.categoryLayout == PosCategoryLayout.tiles && auth.showImages;
    final String? imageBaseUrl =
        context.read<SplashProvider>().baseUrls?.categoryImageUrl;

    return Consumer<CategoryProvider>(
      builder: (context, category, _) {
        final categories = category.categoryList;
        if (categories == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return ScrollConfiguration(
          behavior: const _NoGlowScrollBehavior(),
          child: ListView.builder(
            padding: EdgeInsets.only(bottom: 8 * u),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final c = categories[index];
              final String image = c.image ?? '';
              return _RailItem(
                u: u,
                name: c.name ?? '',
                imageUrl: images && imageBaseUrl != null && image.isNotEmpty
                    ? '$imageBaseUrl/$image'
                    : null,
                showImage: images,
                selected: '${c.id}' == category.selectedSubCategoryId,
                onTap: () => onSelect(c.id!),
              );
            },
          ),
        );
      },
    );
  }
}

class _RailItem extends StatelessWidget {
  final double u;
  final String name;
  final String? imageUrl;
  final bool showImage;
  final bool selected;
  final VoidCallback onTap;
  const _RailItem({
    required this.u,
    required this.name,
    required this.imageUrl,
    required this.showImage,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double d = _MenuSpec.categoryImage * u;
    final KioskTheme theme = context
        .select<KioskAuthProvider, KioskTheme>((a) => a.portraitTheme);
    final label = Text(
      name,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: poppinsMedium.copyWith(
        fontSize: 12 * u,
        height: 1.25,
        color: theme.sidebarText ?? _MenuSpec.ink,
        fontWeight: theme.sidebarBold == true ? FontWeight.w700 : null,
      ),
    );
    return Material(
      // With a themed sidebar the fixed cream band would clash with the chosen
      // colours, so the highlight becomes a shade of the sidebar colour (nudged
      // toward the label colour). No theme = the built-in cream, unchanged.
      color: !selected
          ? Colors.transparent
          : theme.sidebarBg == null
              ? _MenuSpec.sidebarSelectedBg
              : Color.lerp(
                  theme.sidebarBg, theme.sidebarText ?? _MenuSpec.ink, 0.14),
      child: KioskTap(
        onTap: onTap,
        child: SizedBox(
          height: showImage ? _MenuSpec.categoryItemHeight * u : 56 * u,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 10 * u),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (showImage) ...[
                  ClipOval(
                    child: SizedBox(
                      width: d,
                      height: d,
                      child: imageUrl == null
                          ? const ColoredBox(color: Colors.white)
                          : CustomImageWidget(
                              image: imageUrl!,
                              placeholder: Images.placeholderImage,
                              emptyWhenMissing: true,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  SizedBox(height: 8 * u),
                ],
                label,
              ],
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
  final double u;
  final bool landscape;
  final Set<String> tagFilters;
  final String searchQuery;
  const _ProductArea({
    required this.s,
    required this.u,
    this.landscape = false,
    this.tagFilters = const <String>{},
    this.searchQuery = '',
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
          final bool searching = searchQuery.isNotEmpty;
          final bool filtersActive =
              searching || kioskMenuFiltersActive(category, search);
          List<Product> products = searching
              // Search spans the whole menu, then the sheet's sort/price apply.
              ? filterKioskProducts(
                  products: searchKioskProducts(
                      category.allPrefetchedProducts, searchQuery),
                  searchProvider: search,
                )
              : filtersActive
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
              ? _ProductGridSkeleton(u: u)
              : products.isEmpty
                  ? _EmptyProductArea(s: s, searchQuery: searchQuery)
                  : _ProductGrid(
                      s: s,
                      u: u,
                      products: products,
                      // Per-category override only when a single category is on
                      // screen. With search/tag filters active the grid spans
                      // categories, so there is no one category to key on --
                      // keep the responsive count.
                      columnsOverride: filtersActive
                          ? null
                          : context
                              .read<KioskAuthProvider>()
                              .columnsForCategory(category.selectedCategoryId),
                    );
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
  final String searchQuery;
  const _EmptyProductArea({required this.s, this.searchQuery = ''});

  @override
  Widget build(BuildContext context) {
    final bool byAllergen = KioskAllergenPreferences.instance.hasSelection;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            searchQuery.isNotEmpty && !byAllergen
                ? '${kioskTranslate(context, 'no_search_results', 'No products found for')} "$searchQuery"'
                : byAllergen
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
                padding:
                    EdgeInsets.symmetric(horizontal: 32 * s, vertical: 16 * s),
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

/// Menu grid geometry: the device's per-category column count (see
/// [_MenuGridGeometry.resolve]); the 300×340 reference card is scaled to the
/// column width, so 2 and 3 per row are the same design at different sizes.
class _MenuGridGeometry {
  final int columns;
  final double gap;
  final double tileWidth;
  final double tileHeight;
  final EdgeInsets padding;

  const _MenuGridGeometry._(
      this.columns, this.gap, this.tileWidth, this.tileHeight, this.padding);

  factory _MenuGridGeometry.resolve({
    required double areaWidth,
    required double u,
    required bool showImages,
    int? columnsOverride,
  }) {
    final double gap = _MenuSpec.gridGap * u;
    final EdgeInsets padding = EdgeInsets.fromLTRB(
        _MenuSpec.gridPadLeft * u, 4 * u, _MenuSpec.gridPadRight * u, 24 * u);
    final double inner = areaWidth - padding.horizontal;
    // Column count = the pre-redesign logic, unchanged: the admin's
    // per-device, per-category "Products Per Row" override when one is stored,
    // else the responsive count (min 3). The admin form treats 3 as "automatic"
    // and the backend never stores it (Device::sanitizeCategoryColumns drops
    // it), so a category set to 3 arrives here as NO override -- the fallback
    // must stay the responsive count, never a hardcoded 2.
    final int columns = KioskProductGridGeometry.resolve(
      areaWidth: inner,
      gap: gap,
      showImages: showImages,
      columnsOverride: columnsOverride,
    ).columns;
    final double tileWidth = (inner - gap * (columns - 1)) / columns;
    final double tileHeight = showImages
        ? tileWidth * (_MenuSpec.cardHeight / _MenuSpec.cardWidth)
        : tileWidth * 0.34;
    return _MenuGridGeometry._(columns, gap, tileWidth, tileHeight, padding);
  }

  SliverGridDelegate get delegate => SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: gap,
        mainAxisSpacing: gap,
        mainAxisExtent: tileHeight,
      );
}

class _ProductGrid extends StatelessWidget {
  final double s;
  final double u;
  final List<Product> products;

  /// Per-device, per-category products-per-row override for the category being
  /// shown. Null = no override, so the grid keeps its responsive column count.
  final int? columnsOverride;
  const _ProductGrid({
    required this.s,
    required this.u,
    required this.products,
    this.columnsOverride,
  });

  @override
  Widget build(BuildContext context) {
    final bool showImages = context.watch<KioskAuthProvider>().showImages;
    return LayoutBuilder(
      builder: (context, constraints) {
        final geo = _MenuGridGeometry.resolve(
          areaWidth: constraints.maxWidth,
          u: u,
          showImages: showImages,
          columnsOverride: columnsOverride,
        );
        final int columns = geo.columns;

        // Split so the full-width promo banner sits after the first two rows.
        final int firstCount =
            products.length >= columns * 2 ? columns * 2 : products.length;
        final List<Product> remaining = products.sublist(firstCount);

        Widget card(Product p) => KioskProductCard(
              s: s,
              tileWidth: geo.tileWidth,
              product: p,
              badge: kioskCardBadgeFor(p),
              showImages: showImages,
              menuStyle: true,
            );

        // Rows, not a fixed-extent grid: each row is as tall as its tallest
        // card (content-sized cards), rows may differ, and a short last row
        // keeps its column width, left aligned.
        Widget cardRows(List<Product> list) {
          final int rowCount = (list.length + columns - 1) ~/ columns;
          return SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, r) {
                final int start = r * columns;
                final int end = (start + columns).clamp(0, list.length);
                return Padding(
                  padding: EdgeInsets.only(top: r == 0 ? 0 : geo.gap),
                  child: PosEqualHeightRow(
                    columns: columns,
                    spacing: geo.gap,
                    children: [
                      for (final p in list.sublist(start, end)) card(p),
                    ],
                  ),
                );
              },
              childCount: rowCount,
            ),
          );
        }

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
              final EdgeInsets pad = geo.padding;

              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding:
                        EdgeInsets.fromLTRB(pad.left, pad.top, pad.right, 0),
                    sliver: cardRows(products.sublist(0, splitAt)),
                  ),
                  if (showPromo)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          pad.left,
                          geo.gap,
                          pad.right,
                          rest.isNotEmpty ? geo.gap : 0,
                        ),
                        child: KioskDealPromoBanner(s: s, deals: deals),
                      ),
                    ),
                  if (rest.isNotEmpty)
                    SliverPadding(
                      padding:
                          EdgeInsets.only(left: pad.left, right: pad.right),
                      sliver: cardRows(rest),
                    ),
                  SliverToBoxAdapter(child: SizedBox(height: pad.bottom)),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

/// Loading skeleton for the product grid: shimmering white cards laid out with
/// the exact same geometry as [_ProductGrid], so the switch from skeleton →
/// real products is a seamless in-place swap (no size jump).
class _ProductGridSkeleton extends StatelessWidget {
  final double u;
  const _ProductGridSkeleton({required this.u});

  @override
  Widget build(BuildContext context) {
    final bool showImages = context.watch<KioskAuthProvider>().showImages;
    return LayoutBuilder(
      builder: (context, constraints) {
        final geo = _MenuGridGeometry.resolve(
          areaWidth: constraints.maxWidth,
          u: u,
          showImages: showImages,
        );
        return IgnorePointer(
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            padding: geo.padding,
            itemCount: geo.columns * 2,
            gridDelegate: geo.delegate,
            itemBuilder: (context, index) =>
                _SkeletonCard(tileWidth: geo.tileWidth, showImages: showImages),
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
    final double cu = tileWidth / _MenuSpec.cardWidth;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14 * cu),
        boxShadow: _MenuSpec.softShadow(cu),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment:
            showImages ? MainAxisAlignment.start : MainAxisAlignment.center,
        children: [
          if (showImages) ...[
            Padding(
              padding: EdgeInsets.all(12 * cu),
              child: SizedBox(
                height: 171 * cu,
                child: CustomImageWidget.shimmerBox(),
              ),
            ),
            Container(height: 1 * cu, color: _MenuSpec.cardDivider),
            SizedBox(height: 14 * cu),
          ],
          Center(
            child:
                CustomImageWidget.shimmerBox(width: 180 * cu, height: 18 * cu),
          ),
          SizedBox(height: 10 * cu),
          Center(
            child:
                CustomImageWidget.shimmerBox(width: 80 * cu, height: 16 * cu),
          ),
        ],
      ),
    );
  }
}

// Dark button fill + white text used by the filled cart bar.
const Color _kDarkButton = Color(0xFF1E1E1E);
const Color _kCreamText = Color(0xFFFFFFFF);

/// White rounded card with the screen's soft shadow — cart bar surfaces.
BoxDecoration _cartSurface(double u, {Color color = Colors.white}) =>
    BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(16 * u),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 16 * u,
          offset: Offset(0, 4 * u),
        ),
      ],
    );

/// Cart bar at the bottom of the CONTENT column (never over the sidebar or
/// its logout). Two states, unchanged:
///  • empty  → a single "CART / € 0.00" bar.
///  • filled → the latest item on the left and VIEW CART (with the item
///    count) over CHECK OUT (with the total) on the right.
class _CartBar extends StatelessWidget {
  final double s;
  final double u;
  const _CartBar({required this.s, required this.u});

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
            _MenuSpec.gridPadLeft * u,
            8 * u,
            _MenuSpec.gridPadRight * u,
            16 * u,
          ),
          child: count == 0
              ? _EmptyCartBar(u: u, total: total)
              : _FilledCartBar(
                  u: u,
                  total: total,
                  count: count,
                  cartList: cartList,
                ),
        );
      },
    );
  }
}

class _EmptyCartBar extends StatelessWidget {
  final double u;
  final double total;
  const _EmptyCartBar({required this.u, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64 * u,
      decoration: _cartSurface(u),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16 * u),
        clipBehavior: Clip.antiAlias,
        child: KioskTap(
          onTap: () => openKioskCart(context),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 28 * u),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${(getTranslated('cart', context) ?? 'CART').toUpperCase()} / ${PriceConverterHelper.convertPrice(total)}',
                style: poppinsMedium.copyWith(
                    fontSize: 20 * u, height: 1.2, color: _MenuSpec.ink),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FilledCartBar extends StatelessWidget {
  final double u;
  final double total;
  final int count;
  final List<CartModel?> cartList;
  const _FilledCartBar({
    required this.u,
    required this.total,
    required this.count,
    required this.cartList,
  });

  @override
  Widget build(BuildContext context) {
    // The most recently added item is shown on the left.
    final CartModel? latest = cartList.isNotEmpty ? cartList.last : null;
    return SizedBox(
      height: 136 * u,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
              flex: 47,
              child: _LatestItemCard(
                  u: u, cart: latest, index: cartList.length - 1)),
          SizedBox(width: 12 * u),
          Expanded(
            flex: 44,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _ViewCartButton(u: u, count: count)),
                SizedBox(height: 8 * u),
                Expanded(child: _CheckoutButton(u: u, total: total)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewCartButton extends StatelessWidget {
  final double u;
  final int count;
  const _ViewCartButton({required this.u, required this.count});

  @override
  Widget build(BuildContext context) {
    final double badge = 24 * u;
    return Container(
      decoration: _cartSurface(u),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16 * u),
        clipBehavior: Clip.antiAlias,
        child: KioskTap(
          onTap: () => openKioskCart(context),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  (getTranslated('view_cart', context) ?? 'VIEW CART')
                      .toUpperCase(),
                  style: poppinsMedium.copyWith(
                      fontSize: 16 * u, height: 1.2, color: _MenuSpec.ink),
                ),
                SizedBox(width: 10 * u),
                Container(
                  width: badge,
                  height: badge,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                      color: _kDarkButton, shape: BoxShape.circle),
                  child: Text(
                    '$count',
                    style: poppinsMedium.copyWith(
                        fontSize: 12 * u, height: 1, color: _kCreamText),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckoutButton extends StatelessWidget {
  final double u;
  final double total;
  const _CheckoutButton({required this.u, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cartSurface(u, color: _kDarkButton),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16 * u),
        clipBehavior: Clip.antiAlias,
        child: KioskTap(
          onTap: () => openKioskCheckout(context),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12 * u),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      (getTranslated('check_out', context) ?? 'CHECK OUT')
                          .toUpperCase(),
                      style: poppinsMedium.copyWith(
                          fontSize: 16 * u, height: 1.2, color: _kCreamText),
                    ),
                    SizedBox(width: 12 * u),
                    Text(
                      PriceConverterHelper.convertPrice(total),
                      style: poppinsMedium.copyWith(
                          fontSize: 16 * u, height: 1.2, color: _kCreamText),
                    ),
                  ],
                ),
              ),
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
  final double u;
  final CartModel? cart;
  final int index;
  const _LatestItemCard(
      {required this.u, required this.cart, required this.index});

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
    final double plus = 32 * u;
    return Container(
      decoration: _cartSurface(u),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16 * u),
        clipBehavior: Clip.antiAlias,
        child: KioskTap(
          onTap: () => openKioskCart(context),
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.all(12 * u),
                child: Row(
                  children: [
                    // Latest product image (square). Dropped on a
                    // picture-less device so the text takes the full width.
                    if (showImages) ...[
                      AspectRatio(
                        aspectRatio: 1,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12 * u),
                          child: CustomImageWidget(
                            emptyWhenMissing: true,
                            placeholder: Images.placeholderImage,
                            image: image,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      SizedBox(width: 12 * u),
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
                            style: poppinsMedium.copyWith(
                                fontSize: 15 * u,
                                height: 1.25,
                                color: _MenuSpec.ink),
                          ),
                          SizedBox(height: 4 * u),
                          Text(
                            PriceConverterHelper.convertPrice(unitPrice),
                            style: poppinsRegular.copyWith(
                                fontSize: 14 * u,
                                height: 1.2,
                                color: _MenuSpec.priceInk),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: plus + 4 * u), // room for the "+".
                  ],
                ),
              ),
              // "+" — add another of this item.
              Positioned(
                right: 12 * u,
                bottom: 12 * u,
                child: Material(
                  color: _kDarkButton,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: KioskTap(
                    onTap: product == null
                        ? null
                        : () =>
                            Provider.of<CartProvider>(context, listen: false)
                                .onUpdateCartQuantity(
                                    index: index,
                                    product: product,
                                    isRemove: false),
                    child: SizedBox(
                      width: plus,
                      height: plus,
                      child: Icon(Icons.add, color: _kCreamText, size: 20 * u),
                    ),
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
