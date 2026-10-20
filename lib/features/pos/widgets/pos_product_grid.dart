import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_product_image_helper.dart';
import 'package:acafe_customer/features/pos/domain/pos_home_layout.dart';
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/widgets/pos_product_tile.dart';
import 'package:acafe_customer/theme/text_legibility.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';

/// Product grid from Figma `product-row-*`.
///
/// Three columns at every desktop size the design covers; the count is
/// derived from the viewport width ([PosHomeLayout.gridColumns]) rather than
/// fixed, because a fixed three shrank phone tiles to ~90px with ~6px type.
/// Tiles keep the design aspect ratio and scale their content to the cell.
class PosProductGrid extends StatefulWidget {
  final List<Product> products;
  final String? imageBaseUrl;
  final int Function(Product) cartQuantityOf;
  final ValueChanged<Product> onProductTap;

  /// Picture-less device: tiles drop the image block and the grid uses the
  /// shorter [PosHomeSpec.tileHeightNoImage] aspect ratio so they pack denser.
  final bool showImages;

  /// Insets and column policy for the current window. Defaults to the 1366
  /// Figma frame's.
  final PosHomeLayout? layout;

  const PosProductGrid({
    super.key,
    required this.products,
    required this.imageBaseUrl,
    required this.cartQuantityOf,
    required this.onProductTap,
    this.showImages = true,
    this.layout,
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
            color: TextTones.hint,
          ),
        ),
      );
    }

    final PosHomeLayout layout =
        widget.layout ?? PosHomeLayout.resolve(const Size(1366, 1024));

    return LayoutBuilder(
      builder: (context, constraints) => ScrollConfiguration(
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
          padding: EdgeInsets.only(bottom: layout.scrollbarTrackBottom),
          child: GridView.builder(
            controller: _scroll,
            padding: EdgeInsets.only(
              right: layout.gridInsetRight,
              bottom: layout.fadeHeight,
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: layout.gridColumns(constraints.maxWidth),
              crossAxisSpacing: PosHomeSpec.gridColumnGap,
              mainAxisSpacing: PosHomeSpec.gridRowGap,
              childAspectRatio: PosHomeSpec.tileWidth /
                  (widget.showImages
                      ? PosHomeSpec.tileHeight
                      : PosHomeSpec.tileHeightNoImage),
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
                showImages: widget.showImages,
              );
            },
          ),
        ),
      ),
    );
  }
}
