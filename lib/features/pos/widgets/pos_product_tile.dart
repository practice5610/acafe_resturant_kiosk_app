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
    return Material(
      color: PosHomeSpec.tileBg,
      borderRadius: BorderRadius.circular(PosHomeSpec.tileRadius),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PosHomeSpec.tileRadius),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                PosHomeSpec.tilePadding,
                PosHomeSpec.tilePadding,
                PosHomeSpec.tilePadding,
                PosHomeSpec.tileBottomPadding,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: PosHomeSpec.tileImageHeight,
                    width: double.infinity,
                    child: ClipRRect(
                      borderRadius:
                          BorderRadius.circular(PosHomeSpec.tileImageRadius),
                      child: Center(
                        child: CustomImageWidget(
                          image: imageUrl,
                          height: PosHomeSpec.tileImageHeight,
                          fit: BoxFit.contain,
                          useShimmer: true,
                          cacheWidth:
                              CustomImageWidget.kKioskProductCacheWidth,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: PosHomeSpec.tileImageGap),
                  SizedBox(
                    height: PosHomeSpec.tileInfoHeight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: PosHomeSpec.tileTextBlockHeight,
                          child: Column(
                            children: [
                              SizedBox(
                                height: PosHomeSpec.tileNameBox,
                                child: Text(
                                  product.name ?? '',
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: loewExtraBold.copyWith(
                                    fontSize: PosHomeSpec.tileNameSize,
                                    color: PosHomeSpec.ink,
                                    height: PosHomeSpec.tileNameHeight,
                                  ),
                                ),
                              ),
                              const SizedBox(height: PosHomeSpec.tileNameGap),
                              SizedBox(
                                height: PosHomeSpec.tilePriceBox,
                                child: Text(
                                  PosHomeSpec.formatPrice(
                                    PriceConverterHelper.convertWithDiscount(
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
                                    fontSize: PosHomeSpec.tilePriceSize,
                                    color: PosHomeSpec.inkAlpha(0.6),
                                    height: PosHomeSpec.tilePriceHeight,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: PosHomeSpec.tileInfoGap),
                        const SizedBox(height: PosHomeSpec.tileActionRowHeight),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (cartQuantity > 0)
              Positioned(
                top: PosHomeSpec.qtyBadgeInset,
                right: PosHomeSpec.qtyBadgeInset,
                child: _QtyBadge(quantity: cartQuantity),
              ),
          ],
        ),
      ),
    );
  }
}

class _QtyBadge extends StatelessWidget {
  final int quantity;

  const _QtyBadge({required this.quantity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: PosHomeSpec.qtyBadgeSize,
      height: PosHomeSpec.qtyBadgeSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: PosHomeSpec.ink,
        borderRadius: BorderRadius.circular(PosHomeSpec.qtyBadgeSize / 2),
      ),
      child: Text(
        '$quantity',
        style: loewBold.copyWith(
          fontSize: PosHomeSpec.qtyBadgeLabelSize,
          color: Colors.white,
          height: 16 / 13.2,
        ),
      ),
    );
  }
}
