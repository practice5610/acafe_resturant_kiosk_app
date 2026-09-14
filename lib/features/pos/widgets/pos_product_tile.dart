import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/common/widgets/custom_image_widget.dart';
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/helper/price_converter_helper.dart';
import 'package:acafe_customer/helper/product_helper.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';

/// One product in the grid.
///
/// Geometry is the Figma tile (221.33×320): 16px inset, a 220px image block,
/// 12px to a 70px info block (19+3+16 text, 10px gap, 22px action row), and
/// 2px under the info — not a uniform 16px bottom pad.
///
/// `PosProductGrid`'s cells lock `childAspectRatio` to this tile's design
/// ratio, so the cell's *height* always tracks its *width* — but the grid's
/// column count is a fixed constant (not derived from measured width, see
/// that file's own doc comment), so the cell itself renders narrower (and
/// therefore shorter) than the 221.33×320 design below the 1366px design
/// width. Every dimension here used to be an absolute pixel literal, which
/// never shrank to match — the mismatch overflowed the Column by however
/// many px the cell fell short of 320. A single width-derived `scale`
/// (`constraints.maxWidth / tileWidth`) applied to every one of those
/// literals keeps the tile's content proportional to whatever size the cell
/// actually got, so it can never demand more height than the cell has.
class PosProductTile extends StatelessWidget {
  final Product product;
  final String imageUrl;

  /// Quantity of this product currently in the cart. Renders the badge when
  /// greater than zero.
  final int cartQuantity;
  final VoidCallback onTap;

  const PosProductTile({
    super.key,
    required this.product,
    required this.imageUrl,
    required this.cartQuantity,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double s = constraints.maxWidth / PosHomeSpec.tileWidth;

        return Material(
          color: PosHomeSpec.tileBg,
          borderRadius: BorderRadius.circular(PosHomeSpec.tileRadius * s),
          clipBehavior: Clip.antiAlias,
          elevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(PosHomeSpec.tileRadius * s),
            child: Stack(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    PosHomeSpec.tilePadding * s,
                    PosHomeSpec.tilePadding * s,
                    PosHomeSpec.tilePadding * s,
                    PosHomeSpec.tileBottomPadding * s,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: PosHomeSpec.tileImageHeight * s,
                        width: double.infinity,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                              PosHomeSpec.tileImageRadius * s),
                          child: Center(
                            child: CustomImageWidget(
                              image: imageUrl,
                              height: PosHomeSpec.tileImageHeight * s,
                              fit: BoxFit.contain,
                              useShimmer: true,
                              cacheWidth:
                                  CustomImageWidget.kKioskProductCacheWidth,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: PosHomeSpec.tileImageGap * s),
                      SizedBox(
                        height: PosHomeSpec.tileInfoHeight * s,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              height: PosHomeSpec.tileTextBlockHeight * s,
                              child: Column(
                                children: [
                                  SizedBox(
                                    height: PosHomeSpec.tileNameBox * s,
                                    child: Text(
                                      product.name ?? '',
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: loewExtraBold.copyWith(
                                        fontSize: PosHomeSpec.tileNameSize * s,
                                        color: PosHomeSpec.ink,
                                        height: PosHomeSpec.tileNameHeight,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: PosHomeSpec.tileNameGap * s),
                                  SizedBox(
                                    height: PosHomeSpec.tilePriceBox * s,
                                    child: Text(
                                      PosHomeSpec.formatPrice(
                                        PriceConverterHelper
                                                .convertWithDiscount(
                                              ProductHelper
                                                      .getBranchProductVariationWithPrice(
                                                          product)
                                                  .price ??
                                                  product.price,
                                              product.discount,
                                              product.discountType,
                                            ) ??
                                            product.price ??
                                            0,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: swiss721Light.copyWith(
                                        fontSize:
                                            PosHomeSpec.tilePriceSize * s,
                                        color: PosHomeSpec.inkAlpha(0.6),
                                        height: PosHomeSpec.tilePriceHeight,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: PosHomeSpec.tileInfoGap * s),
                            SizedBox(
                                height: PosHomeSpec.tileActionRowHeight * s),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (cartQuantity > 0)
                  Positioned(
                    top: PosHomeSpec.qtyBadgeInset * s,
                    right: PosHomeSpec.qtyBadgeInset * s,
                    child: _QtyBadge(quantity: cartQuantity, scale: s),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _QtyBadge extends StatelessWidget {
  final int quantity;
  final double scale;

  const _QtyBadge({required this.quantity, required this.scale});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: PosHomeSpec.qtyBadgeSize * scale,
      height: PosHomeSpec.qtyBadgeSize * scale,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: PosHomeSpec.ink,
        borderRadius: BorderRadius.circular(PosHomeSpec.qtyBadgeSize * scale / 2),
      ),
      child: Text(
        '$quantity',
        style: loewBold.copyWith(
          fontSize: PosHomeSpec.qtyBadgeLabelSize * scale,
          color: Colors.white,
          height: 16 / 13.2,
        ),
      ),
    );
  }
}
