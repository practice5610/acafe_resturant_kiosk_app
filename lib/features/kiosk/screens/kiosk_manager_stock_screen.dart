import 'package:flutter/material.dart';
import 'package:acafe_customer/common/responsive/kiosk_layout.dart';
import 'package:acafe_customer/common/responsive/kiosk_responsive.dart';
import 'package:acafe_customer/common/widgets/custom_image_widget.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_manager_provider.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_search_field.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_tap.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_ui.dart';
import 'package:acafe_customer/features/category/providers/category_provider.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:provider/provider.dart';

enum _StockFilter { all, inStock, outOfStock }

// Soft danger tint, matching the "CLOSED" badge pair already used on the
// sales-overview manager screen -- keeps the red used here consistent across
// the manager subtree instead of inventing a new one.
const Color _kOutOfStockBg = Color(0xFFF5EAEA);
const Color _kOutOfStockFg = Color(0xFF8A2E2E);
const Color _kInStockBg = Color(0xFFF1E9D8);
const Color _kInStockFg = Color(0xFF8A6D3B);

// Toolbar chrome neutrals and elevation now live with the shared manager
// search field, so the stock list and transaction history stay one look.
const Color _kHairline = kKioskHairline;
const Color _kSubtleFill = kKioskSubtleFill;

List<BoxShadow> _cardShadow(double s) => kioskCardShadow(s);

double _stroke(double value, double s) => kioskStroke(value, s);

/// Full branch product list (same list the Branch panel's product page
/// shows) with an availability toggle per row -- lets a manager pull an
/// item from the menu without leaving the counter.
class KioskManagerStockScreen extends StatefulWidget {
  const KioskManagerStockScreen({super.key});

  @override
  State<KioskManagerStockScreen> createState() =>
      _KioskManagerStockScreenState();
}

class _KioskManagerStockScreenState extends State<KioskManagerStockScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  _StockFilter _filter = _StockFilter.all;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onQueryChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Always re-validate: the provider is a lazy singleton so an in-memory
      // list can survive navigating away. loadAllProductsWithCache() paints
      // what's already known, then refreshes from the network so the count
      // stays in sync with this branch's catalog.
      context.read<KioskManagerProvider>().loadAllProductsWithCache();
    });
  }

  void _onQueryChanged() {
    final next = _searchController.text.trim().toLowerCase();
    if (next == _query) return;
    setState(() => _query = next);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onQueryChanged);
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  /// Name match, in memory. The screen always loads the branch's *entire*
  /// catalog up front (loadAllProducts pages until exhausted), so filtering
  /// locally is complete -- and it removes the round-trip that forced the old
  /// "type, then press the arrow" search.
  List<Map<String, dynamic>> _search(List<Map<String, dynamic>> products) {
    if (_query.isEmpty) return products;
    return products
        .where(
            (p) => (p['name']?.toString().toLowerCase() ?? '').contains(_query))
        .toList();
  }

  List<Map<String, dynamic>> _applyFilter(List<Map<String, dynamic>> products) {
    switch (_filter) {
      case _StockFilter.inStock:
        return products.where((p) => p['is_available'] == true).toList();
      case _StockFilter.outOfStock:
        return products.where((p) => p['is_available'] != true).toList();
      case _StockFilter.all:
        return products;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KioskUI.pageBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double s = KioskLayout.scaleOf(context, constraints);
            final double contentWidth =
                constraints.maxWidth.clamp(0.0, KioskResponsive.designWidth);
            final int columns = (contentWidth - 264 * s) > 900 * s ? 2 : 1;

            return KioskCenteredContent(
              child: Column(
                children: [
                  Consumer<KioskManagerProvider>(
                    builder: (context, provider, _) {
                      return KioskHeaderBar(
                        s: s,
                        title: 'MARK OUT OF STOCK',
                        fallback: RouterHelper.getKioskManagerDashboardRoute,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _StatChip(
                              s: s,
                              value: '${provider.products.length}',
                              label: 'products',
                            ),
                            SizedBox(width: 16 * s),
                            _StatChip(
                              s: s,
                              value: '${provider.outOfStockCount}',
                              label: 'out of stock',
                              tinted: provider.outOfStockCount > 0,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(132 * s, 0, 132 * s, 40 * s),
                    child: Consumer<KioskManagerProvider>(
                      builder: (context, provider, _) {
                        // Segment counts follow the search, so they always
                        // describe what tapping that segment would actually
                        // show -- the header chips stay catalog-wide.
                        final searched = _search(provider.products);
                        final int inStock = searched
                            .where((p) => p['is_available'] == true)
                            .length;
                        return _StockToolbar(
                          s: s,
                          searchController: _searchController,
                          searchFocus: _searchFocus,
                          hasQuery: _query.isNotEmpty,
                          onClear: () {
                            _searchController.clear();
                            _searchFocus.requestFocus();
                          },
                          filter: _filter,
                          onFilterChanged: (f) => setState(() => _filter = f),
                          counts: {
                            _StockFilter.all: searched.length,
                            _StockFilter.inStock: inStock,
                            _StockFilter.outOfStock: searched.length - inStock,
                          },
                        );
                      },
                    ),
                  ),
                  Expanded(
                    child: Consumer<KioskManagerProvider>(
                      builder: (context, provider, _) {
                        if (provider.productsLoading &&
                            provider.products.isEmpty) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        final filtered =
                            _applyFilter(_search(provider.products));
                        if (filtered.isEmpty) {
                          return Center(
                            child: Text(
                              provider.products.isEmpty
                                  ? 'No products found'
                                  : _query.isNotEmpty
                                      ? 'Nothing matches “${_searchController.text.trim()}”'
                                      : 'No products in this filter',
                              textAlign: TextAlign.center,
                              style: loewMedium.copyWith(
                                  fontSize: 40 * s, color: Colors.black45),
                            ),
                          );
                        }
                        return GridView.builder(
                          padding:
                              EdgeInsets.fromLTRB(132 * s, 0, 132 * s, 60 * s),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            mainAxisSpacing: 20 * s,
                            crossAxisSpacing: 20 * s,
                            mainAxisExtent: 176 * s,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final product = filtered[index];
                            final int id = product['id'];
                            return _ProductStockCard(
                              s: s,
                              product: product,
                              toggling: provider.isTogglingProduct(id),
                              onToggle: (value) async {
                                final ok = await provider
                                    .toggleProductAvailability(id, value);
                                if (!ok || !context.mounted) return;
                                context
                                    .read<CategoryProvider>()
                                    .applyKioskAvailability(
                                      productId: id,
                                      isAvailable: value,
                                    );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Search field + All / In stock / Out of stock switch.
///
/// Both controls are pills at the same height, on white with the card shadow:
/// the page already reserves rounded *rectangles* for content surfaces (cards,
/// manager tiles) and pills for controls (the availability switch, the status
/// badges), so chrome and content stay visually separable.
class _StockToolbar extends StatelessWidget {
  final double s;
  final TextEditingController searchController;
  final FocusNode searchFocus;
  final bool hasQuery;
  final VoidCallback onClear;
  final _StockFilter filter;
  final ValueChanged<_StockFilter> onFilterChanged;
  final Map<_StockFilter, int> counts;

  const _StockToolbar({
    required this.s,
    required this.searchController,
    required this.searchFocus,
    required this.hasQuery,
    required this.onClear,
    required this.filter,
    required this.onFilterChanged,
    required this.counts,
  });

  @override
  Widget build(BuildContext context) {
    // Sized against the same artboard as the rest of the screen (176 tall
    // cards, 30pt product names). The old 56/18 chrome was authored at roughly
    // half that scale, which is why it read as a different app.
    final double barHeight = 92 * s;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Only reachable once the scale clamp kicks in (< ~620px wide), where
        // the two controls no longer fit side by side.
        final bool stacked = constraints.maxWidth < 620;

        final Widget search = KioskSearchField(
          s: s,
          height: barHeight,
          controller: searchController,
          focusNode: searchFocus,
          hasQuery: hasQuery,
          onClear: onClear,
          hintText: 'Search products',
        );

        final Widget filters = _FilterSwitch(
          s: s,
          height: barHeight,
          filter: filter,
          onFilterChanged: onFilterChanged,
          counts: counts,
          fillWidth: stacked,
        );

        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [search, SizedBox(height: 24 * s), filters],
          );
        }

        return Row(
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 760 * s),
              child: search,
            ),
            const Spacer(),
            filters,
          ],
        );
      },
    );
  }
}

class _FilterSwitch extends StatelessWidget {
  final double s;
  final double height;
  final _StockFilter filter;
  final ValueChanged<_StockFilter> onFilterChanged;
  final Map<_StockFilter, int> counts;
  final bool fillWidth;

  const _FilterSwitch({
    required this.s,
    required this.height,
    required this.filter,
    required this.onFilterChanged,
    required this.counts,
    required this.fillWidth,
  });

  @override
  Widget build(BuildContext context) {
    final double pad = 8 * s;

    Widget segment(_StockFilter value, String label) {
      final Widget child = _FilterSegment(
        s: s,
        height: height - pad * 2,
        label: label,
        count: counts[value] ?? 0,
        selected: filter == value,
        danger: value == _StockFilter.outOfStock,
        onTap: () => onFilterChanged(value),
      );
      return fillWidth ? Expanded(child: child) : child;
    }

    return Container(
      height: height,
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(color: _kHairline, width: _stroke(1.5, s)),
        boxShadow: _cardShadow(s),
      ),
      child: Row(
        mainAxisSize: fillWidth ? MainAxisSize.max : MainAxisSize.min,
        children: [
          segment(_StockFilter.all, 'ALL'),
          segment(_StockFilter.inStock, 'IN STOCK'),
          segment(_StockFilter.outOfStock, 'OUT OF STOCK'),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final double s;
  final String value;
  final String label;
  final bool tinted;

  const _StatChip({
    required this.s,
    required this.value,
    required this.label,
    this.tinted = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg = tinted ? _kOutOfStockBg : Colors.white;
    final Color fg = tinted ? _kOutOfStockFg : Colors.black;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 28 * s, vertical: 12 * s),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18 * s),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: loewExtraBold.copyWith(fontSize: 30 * s, color: fg)),
          Text(label,
              style: loewMedium.copyWith(
                  fontSize: 18 * s, color: fg.withValues(alpha: 0.65))),
        ],
      ),
    );
  }
}

/// One segment of the filter switch: label + live count.
///
/// The count is what makes this a manager tool rather than three buttons --
/// "OUT OF STOCK 3" answers the question the screen exists for without having
/// to select the tab first. An unselected out-of-stock segment carrying a
/// non-zero count is tinted with the same danger pair as the row badges.
class _FilterSegment extends StatelessWidget {
  final double s;
  final double height;
  final String label;
  final int count;
  final bool selected;
  final bool danger;
  final VoidCallback onTap;

  const _FilterSegment({
    required this.s,
    required this.height,
    required this.label,
    required this.count,
    required this.selected,
    required this.danger,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool alert = danger && count > 0;

    final Color labelFg = selected
        ? KioskUI.cream
        : alert
            ? _kOutOfStockFg
            : KioskUI.dark.withValues(alpha: 0.55);

    final Color badgeBg = selected
        ? Colors.white.withValues(alpha: 0.18)
        : alert
            ? _kOutOfStockBg
            : _kSubtleFill;

    final Color badgeFg = selected
        ? KioskUI.cream
        : alert
            ? _kOutOfStockFg
            : KioskUI.dark.withValues(alpha: 0.6);

    return KioskTap(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        height: height,
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(horizontal: 28 * s),
        decoration: BoxDecoration(
          color: selected ? KioskUI.dark : Colors.transparent,
          borderRadius: BorderRadius.circular(height / 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                style: loewBold.copyWith(
                  fontSize: 23 * s,
                  letterSpacing: 1.2 * s,
                  color: labelFg,
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            SizedBox(width: 14 * s),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              constraints: BoxConstraints(minWidth: 46 * s),
              padding:
                  EdgeInsets.symmetric(horizontal: 12 * s, vertical: 5 * s),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(30 * s),
              ),
              child: Text(
                '$count',
                style: loewExtraBold.copyWith(fontSize: 20 * s, color: badgeFg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductStockCard extends StatelessWidget {
  final double s;
  final Map<String, dynamic> product;
  final bool toggling;
  final ValueChanged<bool> onToggle;

  const _ProductStockCard({
    required this.s,
    required this.product,
    required this.toggling,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final bool isAvailable = product['is_available'] == true;
    final String stockType = product['stock_type']?.toString() ?? 'unlimited';
    final int stock = (product['stock'] as num?)?.toInt() ?? 0;

    return KioskTap(
      onTap: toggling ? null : () => onToggle(!isAvailable),
      child: Container(
        padding: EdgeInsets.all(20 * s),
        decoration: BoxDecoration(
          color: isAvailable
              ? Colors.white
              : _kOutOfStockBg.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(22 * s),
          boxShadow: _cardShadow(s),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16 * s),
              child: CustomImageWidget(
                image: product['image_full_path']?.toString() ?? '',
                width: 100 * s,
                height: 100 * s,
                fit: BoxFit.cover,
              ),
            ),
            SizedBox(width: 20 * s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    product['name']?.toString() ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: loewBold.copyWith(
                        fontSize: 30 * s, color: Colors.black),
                  ),
                  SizedBox(height: 10 * s),
                  _StatusPill(
                    s: s,
                    isAvailable: isAvailable,
                    caption: stockType == 'unlimited' ? null : 'Stock: $stock',
                  ),
                ],
              ),
            ),
            SizedBox(width: 12 * s),
            if (toggling)
              SizedBox(
                width: 28 * s,
                height: 28 * s,
                child: CircularProgressIndicator(strokeWidth: 3 * s),
              )
            else
              IgnorePointer(child: KioskSwitch(value: isAvailable, s: s)),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final double s;
  final bool isAvailable;
  final String? caption;

  const _StatusPill({required this.s, required this.isAvailable, this.caption});

  @override
  Widget build(BuildContext context) {
    final Color bg = isAvailable ? _kInStockBg : _kOutOfStockBg;
    final Color fg = isAvailable ? _kInStockFg : _kOutOfStockFg;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16 * s, vertical: 8 * s),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20 * s),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9 * s,
            height: 9 * s,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          SizedBox(width: 9 * s),
          Text(
            isAvailable ? 'In stock' : 'Out of stock',
            style: loewBold.copyWith(fontSize: 21 * s, color: fg),
          ),
          if (caption != null) ...[
            SizedBox(width: 9 * s),
            Text(caption!,
                style: loewMedium.copyWith(
                    fontSize: 21 * s, color: fg.withValues(alpha: 0.75))),
          ],
        ],
      ),
    );
  }
}
