import 'package:acafe_customer/features/kiosk/providers/kiosk_manager_provider.dart';
import 'package:acafe_customer/features/pos/domain/pos_products_settings_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_settings_spec.dart';
import 'package:acafe_customer/features/pos/widgets/pos_search_field.dart';
import 'package:acafe_customer/features/pos/widgets/pos_settings_availability_list.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Settings → PRODUCTS (Figma **1641:3975**).
///
/// Drives `product_by_branches.is_available` for this terminal's branch — the
/// exact flag `KioskController::products()` filters on, so a toggle here adds
/// or removes the product from the customer kiosk menu immediately.
///
/// Reuses [KioskManagerProvider], which already owns the full-catalog fetch,
/// the disk cache, and the optimistic per-product toggle with revert-on-error.
/// Search is client-side over the already-loaded catalog (the same approach the
/// kiosk Mark-Out-of-Stock screen takes), so typing never hits the network.
class PosProductsSettingsPanel extends StatefulWidget {
  const PosProductsSettingsPanel({super.key});

  static const String pageTitle = 'PRODUCT AVAILABILITY';
  static const String pageSubtitle =
      'Configure which bakery and custom espresso drinks are displayed active '
      'on customer kiosks';
  static const String searchHint =
      'Search by product name, category, or SKU...';

  @override
  State<PosProductsSettingsPanel> createState() =>
      _PosProductsSettingsPanelState();
}

class _PosProductsSettingsPanelState extends State<PosProductsSettingsPanel> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    // Paints from the disk cache first, then refreshes silently — entering the
    // tab never shows an empty card when a catalog is already known.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<KioskManagerProvider>().loadAllProductsWithCache();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    final String next = value.trim().toLowerCase();
    if (next == _query) return;
    setState(() => _query = next);
  }

  /// Matches name, category, and SKU. Every term must hit at least one field,
  /// so "matcha 8104" narrows rather than widens.
  bool _matches(Map<String, dynamic> product) {
    if (_query.isEmpty) return true;

    final String haystack = [
      product['name'],
      product['category_name'],
      product['sku'],
    ].whereType<Object>().join(' ').toLowerCase();

    return _query
        .split(RegExp(r'\s+'))
        .every((String term) => haystack.contains(term));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _ProductsHeader(),
        const SizedBox(height: PosProductsSettingsSpec.sectionGap),
        PosSearchField(
          controller: _search,
          onChanged: _onQueryChanged,
          hintText: PosProductsSettingsPanel.searchHint,
          style: PosSearchFieldStyle.settings,
        ),
        const SizedBox(height: PosProductsSettingsSpec.sectionGap),
        Expanded(
          child: Selector<KioskManagerProvider, _ProductListShape>(
            // Depends only on which rows are visible, never on their toggle
            // state — flipping one product cannot rebuild the whole list.
            selector: (_, provider) => _ProductListShape(
              ids: provider.products
                  .where(_matches)
                  .map<int?>((p) => (p['id'] as num?)?.toInt())
                  .whereType<int>()
                  .toList(growable: false),
              loading: provider.productsLoading && provider.products.isEmpty,
            ),
            builder: (context, shape, __) {
              return PosSettingsAvailabilityCard(
                ids: shape.ids,
                loading: shape.loading,
                query: _search.text.trim(),
                emptyMessage: 'No products in this branch catalogue yet.',
                noMatchMessage: (String query) =>
                    'Nothing matches \u201C$query\u201D.',
                rowBuilder: (context, id, showDivider) => _ProductRow(
                  key: ValueKey<int>(id),
                  productId: id,
                  showDivider: showDivider,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Visible-row identity for the list-level selector.
@immutable
class _ProductListShape {
  final List<int> ids;
  final bool loading;

  const _ProductListShape({required this.ids, required this.loading});

  @override
  bool operator ==(Object other) =>
      other is _ProductListShape &&
      other.loading == loading &&
      listEquals(other.ids, ids);

  @override
  int get hashCode => Object.hash(loading, Object.hashAll(ids));
}

// ── Header ──────────────────────────────────────────────────────────────────

class _ProductsHeader extends StatelessWidget {
  const _ProductsHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          PosProductsSettingsPanel.pageTitle,
          style: loewExtraBold.copyWith(
            fontSize: PosSettingsSpec.titleSize,
            color: PosSettingsSpec.ink,
            height: 1.1,
          ),
        ),
        const SizedBox(height: PosSettingsSpec.headerGap),
        Text(
          PosProductsSettingsPanel.pageSubtitle,
          style: loewRegular.copyWith(
            fontSize: PosSettingsSpec.subtitleSize,
            color: PosSettingsSpec.inkMuted(),
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

// ── Row ─────────────────────────────────────────────────────────────────────

/// Reads its own product out of the provider, so a toggle repaints one row.
class _ProductRow extends StatelessWidget {
  final int productId;
  final bool showDivider;

  const _ProductRow({
    super.key,
    required this.productId,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    return Selector<KioskManagerProvider, _ProductRowState>(
      selector: (_, provider) {
        final Map<String, dynamic> product = provider.products.firstWhere(
          (p) => (p['id'] as num?)?.toInt() == productId,
          orElse: () => const <String, dynamic>{},
        );
        return _ProductRowState(
          name: product['name']?.toString() ?? '',
          // `sku` is derived server-side (KioskManagerController::products).
          // The fallback only covers rows hydrated from a disk cache written
          // before that field existed; the silent refresh on entry replaces
          // them, so it is a migration bridge, not a second source of truth.
          sku: product['sku']?.toString() ?? 'SKU-$productId',
          image: product['image_full_path']?.toString() ?? '',
          price: (product['price'] as num?)?.toDouble() ?? 0,
          available: product['is_available'] == true,
          busy: provider.isTogglingProduct(productId),
        );
      },
      builder: (context, state, __) {
        return PosSettingsAvailabilityRow(
          name: state.name,
          subLabel: state.sku,
          image: state.image,
          price: state.price,
          available: state.available,
          busy: state.busy,
          showDivider: showDivider,
          onChanged: (bool next) {
            context
                .read<KioskManagerProvider>()
                .toggleProductAvailability(productId, next);
          },
        );
      },
    );
  }
}

/// Per-row slice of provider state.
@immutable
class _ProductRowState {
  final String name;
  final String sku;
  final String image;
  final double price;
  final bool available;
  final bool busy;

  const _ProductRowState({
    required this.name,
    required this.sku,
    required this.image,
    required this.price,
    required this.available,
    required this.busy,
  });

  @override
  bool operator ==(Object other) =>
      other is _ProductRowState &&
      other.name == name &&
      other.sku == sku &&
      other.image == image &&
      other.price == price &&
      other.available == available &&
      other.busy == busy;

  @override
  int get hashCode => Object.hash(name, sku, image, price, available, busy);
}
