import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_product_image_helper.dart';
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/widgets/pos_product_tile.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';

/// Fixed 3-column product grid from Figma `product-row-*`.
///
/// Column count is a design constant, not derived from measured width — the
/// tiles shrink inside the cells when the window is narrower than 1366.
class PosProductGrid extends StatefulWidget {
  final List<Product> products;
  final String? imageBaseUrl;
  final int Function(Product) cartQuantityOf;
  final ValueChanged<Product> onProductTap;

  const PosProductGrid({
    super.key,
    required this.products,
    required this.imageBaseUrl,
    required this.cartQuantityOf,
    required this.onProductTap,
  });

  @override
  State<PosProductGrid> createState() => _PosProductGridState();
}

class _PosProductGridState extends State<PosProductGrid> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.products.isEmpty) {
      return Center(
        child: Text(
          'No products',
          style: loewMedium.copyWith(
            fontSize: 16,
            color: PosHomeSpec.inkAlpha(0.4),
          ),
        ),
      );
    }

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: RawScrollbar(
        controller: _scroll,
        thumbVisibility: true,
        trackVisibility: true,
        thickness: PosHomeSpec.scrollbarWidth,
        radius: const Radius.circular(PosHomeSpec.scrollbarRadius),
        thumbColor: PosHomeSpec.inkAlpha(0.4),
        trackColor: PosHomeSpec.inkAlpha(0.08),
        trackBorderColor: Colors.transparent,
        padding: const EdgeInsets.only(bottom: PosHomeSpec.scrollbarTrackBottom),
        child: GridView.builder(
          controller: _scroll,
          padding: const EdgeInsets.only(
            right: PosHomeSpec.gridViewportRightPad,
            bottom: PosHomeSpec.contentFadeHeight,
          ),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: PosHomeSpec.gridColumns,
            crossAxisSpacing: PosHomeSpec.gridColumnGap,
            mainAxisSpacing: PosHomeSpec.gridRowGap,
            childAspectRatio: PosHomeSpec.tileWidth / PosHomeSpec.tileHeight,
          ),
          itemCount: widget.products.length,
          itemBuilder: (context, index) {
            final product = widget.products[index];
            return PosProductTile(
              product: product,
              imageUrl: KioskProductImageHelper.heroImageUrl(
                product: product,
                productImageBaseUrl: widget.imageBaseUrl,
              ),
              cartQuantity: widget.cartQuantityOf(product),
              onTap: () => widget.onProductTap(product),
            );
          },
        ),
      ),
    );
  }
}
