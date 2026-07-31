import 'package:flutter/material.dart';
import 'package:acafe_customer/common/responsive/kiosk_responsive.dart';
import 'package:acafe_customer/common/widgets/custom_image_widget.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_manager_provider.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_tap.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_ui.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:acafe_customer/theme/brand_colors.dart';
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

/// Full branch product list (same list the Branch panel's product page
/// shows) with an availability toggle per row -- lets a manager pull an
/// item from the menu without leaving the counter.
class KioskManagerStockScreen extends StatefulWidget {
  const KioskManagerStockScreen({super.key});

  @override
  State<KioskManagerStockScreen> createState() => _KioskManagerStockScreenState();
}

class _KioskManagerStockScreenState extends State<KioskManagerStockScreen> {
  final TextEditingController _searchController = TextEditingController();
  _StockFilter _filter = _StockFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // KioskManagerProvider is a lazy singleton (see di_container.dart), so
      // its product list survives navigating away and back -- only fetch
      // when this is genuinely the first visit of the session (or a
      // previous fetch failed and left the list empty). Otherwise every
      // re-entry into this screen re-hit the network and re-ran the full
      // "load every page" loop for no reason. On a genuinely cold start,
      // loadAllProductsWithCache() shows last session's disk-cached list
      // instantly and re-validates against the network in the background.
      final provider = context.read<KioskManagerProvider>();
      if (provider.products.isEmpty) {
        provider.loadAllProductsWithCache();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
            final double s = KioskResponsive.scale(constraints.maxWidth);
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
                    padding: EdgeInsets.fromLTRB(132 * s, 0, 132 * s, 32 * s),
                    child: Consumer<KioskManagerProvider>(
                      builder: (context, provider, _) {
                        return _StockToolbar(
                          s: s,
                          searchController: _searchController,
                          onSearch: (value) => context
                              .read<KioskManagerProvider>()
                              .loadAllProducts(search: value),
                          filter: _filter,
                          onFilterChanged: (f) => setState(() => _filter = f),
                        );
                      },
                    ),
                  ),
                  Expanded(
                    child: Consumer<KioskManagerProvider>(
                      builder: (context, provider, _) {
                        if (provider.productsLoading && provider.products.isEmpty) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final filtered = _applyFilter(provider.products);
                        if (filtered.isEmpty) {
                          return Center(
                            child: Text(
                              provider.products.isEmpty
                                  ? 'No products found'
                                  : 'No products in this filter',
                              style: loewMedium.copyWith(
                                  fontSize: 40 * s, color: Colors.black45),
                            ),
                          );
                        }
                        return GridView.builder(
                          padding: EdgeInsets.fromLTRB(132 * s, 0, 132 * s, 60 * s),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
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
                              onToggle: (value) =>
                                  provider.toggleProductAvailability(id, value),
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

class _StockToolbar extends StatelessWidget {
  final double s;
  final TextEditingController searchController;
  final ValueChanged<String> onSearch;
  final _StockFilter filter;
  final ValueChanged<_StockFilter> onFilterChanged;

  const _StockToolbar({
    required this.s,
    required this.searchController,
    required this.onSearch,
    required this.filter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 6,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16 * s),
              border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10 * s,
                  offset: Offset(0, 2 * s),
                ),
              ],
            ),
            child: TextField(
              controller: searchController,
              onSubmitted: onSearch,
              style: loewMedium.copyWith(fontSize: 22 * s, color: Colors.black),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search products',
                hintStyle: loewMedium.copyWith(fontSize: 22 * s, color: Colors.black38),
                prefixIcon: Icon(Icons.search, size: 26 * s, color: Colors.black45),
                filled: false,
                contentPadding: EdgeInsets.symmetric(horizontal: 6 * s, vertical: 14 * s),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
        ),
        SizedBox(width: 16 * s),
        Expanded(
          flex: 4,
          child: _FilterTabs(s: s, filter: filter, onChanged: onFilterChanged),
        ),
      ],
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
          Text(value, style: loewExtraBold.copyWith(fontSize: 30 * s, color: fg)),
          Text(label,
              style: loewMedium.copyWith(
                  fontSize: 18 * s, color: fg.withValues(alpha: 0.65))),
        ],
      ),
    );
  }
}

class _FilterTabs extends StatelessWidget {
  final double s;
  final _StockFilter filter;
  final ValueChanged<_StockFilter> onChanged;

  const _FilterTabs({required this.s, required this.filter, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(5 * s),
      decoration: BoxDecoration(
        color: const Color(0xFFF0EBDC),
        borderRadius: BorderRadius.circular(16 * s),
      ),
      child: Row(
        children: [
          Expanded(child: _FilterTab(s: s, label: 'All', selected: filter == _StockFilter.all, onTap: () => onChanged(_StockFilter.all))),
          Expanded(child: _FilterTab(s: s, label: 'In stock', selected: filter == _StockFilter.inStock, onTap: () => onChanged(_StockFilter.inStock))),
          Expanded(child: _FilterTab(s: s, label: 'Out', selected: filter == _StockFilter.outOfStock, onTap: () => onChanged(_StockFilter.outOfStock))),
        ],
      ),
    );
  }
}

class _FilterTab extends StatelessWidget {
  final double s;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterTab({
    required this.s,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return KioskTap(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        alignment: Alignment.center,
        margin: EdgeInsets.symmetric(horizontal: 3 * s),
        padding: EdgeInsets.symmetric(vertical: 11 * s),
        decoration: BoxDecoration(
          color: selected ? BrandColors.secondary : Colors.transparent,
          borderRadius: BorderRadius.circular(12 * s),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 8 * s,
                    offset: Offset(0, 2 * s),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: loewBold.copyWith(
            fontSize: 19 * s,
            color: selected ? Colors.white : Colors.black54,
          ),
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
          color: isAvailable ? Colors.white : _kOutOfStockBg.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(22 * s),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12 * s,
              offset: Offset(0, 4 * s),
            ),
          ],
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
                    style: loewBold.copyWith(fontSize: 30 * s, color: Colors.black),
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
            Text(caption!, style: loewMedium.copyWith(fontSize: 21 * s, color: fg.withValues(alpha: 0.75))),
          ],
        ],
      ),
    );
  }
}
