import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/common/widgets/custom_image_widget.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_allergen.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_menu_filter.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_translate.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_product_customize_sheet.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_tap.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/helper/price_converter_helper.dart';
import 'package:acafe_customer/theme/brand_colors.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';

const Color _kPopularGreen = Color(0xFF357937);
const Color _kSpecialRed = Color(0xFF59030E);
const Color _kOutOfStockGrey = Color(0xFF808080);

/// Mirrors [ProductProvider.checkStock] (`common/providers/product_provider.dart`)
/// for "does one more unit still fit" with quantity 1 — the same rule
/// `CartProvider.setQuantity` enforces before an add is let through. A product
/// with no `branchProduct` (not yet hydrated) or an `unlimited` stock type is
/// never out of stock, matching the portrait rule exactly.
bool kioskLandscapeIsOutOfStock(Product product) {
  final BranchProduct? bp = product.branchProduct;
  if (bp?.stockType == 'unlimited' || bp?.stock == null || bp?.soldQuantity == null) {
    return false;
  }
  final int remaining = bp!.stock! - bp.soldQuantity! - 1;
  return remaining <= 0;
}

/// Landscape (Option B) product grid card — Figma B-01 cards. A bordered rounded
/// photo with a merchandising badge and an info dot, then the name, a one-line
/// description and the price beneath.
///
/// Tapping opens the existing product customize flow ([openKioskCustomize]); the
/// badge, image URL and tap are the same logic the portrait grid uses, so there
/// is no duplicated behaviour — only a landscape-tuned layout.
class LandscapeProductCard extends StatelessWidget {
  /// Design-card reference width (Figma landscape card ≈ 250px).
  static const double designCardWidth = 250;

  final double tileWidth;
  final Product product;
  final bool showImages;

  const LandscapeProductCard({
    super.key,
    required this.tileWidth,
    required this.product,
    this.showImages = true,
  });

  @override
  Widget build(BuildContext context) {
    final splash = Provider.of<SplashProvider>(context, listen: false);
    final double cs = tileWidth / designCardWidth;
    final String image = '${splash.baseUrls?.productImageUrl}/${product.image}';
    final ProductTag? badgeTag = kioskMenuCardBadgeTag(product);
    final bool outOfStock = kioskLandscapeIsOutOfStock(product);
    final Set<KioskAllergen> allergens = kioskProductAllergens(product);
    final Color nameColor = outOfStock ? _kOutOfStockGrey : Colors.black;

    final Widget card = Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15 * cs),
        side: BorderSide(color: BrandColors.cardBorder, width: (2.5 * cs).clamp(1.0, 4.0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: KioskTap(
        onTap: outOfStock ? null : () => openKioskCustomize(context, product),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment:
              showImages ? MainAxisAlignment.start : MainAxisAlignment.center,
          children: [
            if (showImages)
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomImageWidget(
                        emptyWhenMissing: true,
                        placeholder: Images.placeholderImage,
                        image: image,
                        fit: BoxFit.cover,
                      ),
                    ),
                    if (outOfStock)
                      const Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: Color(0x2E808080)),
                        ),
                      ),
                    if (outOfStock)
                      const Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: Color(0x59FFFFFF)),
                        ),
                      ),
                    if (outOfStock)
                      Positioned(
                        left: 10.26 * cs,
                        top: 17.77 * cs,
                        child: _OutOfStockBadge(cs: cs),
                      )
                    else if (badgeTag != null)
                      Positioned(
                        left: 12.38 * cs,
                        top: 17.55 * cs,
                        child: _Badge(tag: badgeTag, cs: cs),
                      ),
                    Positioned(
                      right: 11.37 * cs,
                      top: 10.94 * cs,
                      child: _InfoDot(cs: cs),
                    ),
                    if (allergens.isNotEmpty)
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 261.61 * cs,
                        child: _AllergenRow(cs: cs, allergens: allergens),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(10 * cs, 12 * cs, 10 * cs, 14 * cs),
              child: Column(
                children: [
                  Text(
                    product.name ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: loewBold.copyWith(
                        fontSize: 14.5 * cs, height: 1.05, color: nameColor),
                  ),
                  if ((product.description ?? '').trim().isNotEmpty) ...[
                    SizedBox(height: 4 * cs),
                    Text(
                      product.description!.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: swiss721Light.copyWith(
                          fontSize: 10 * cs, color: const Color(0xFF4D4D4D)),
                    ),
                  ],
                  SizedBox(height: 6 * cs),
                  Text(
                    PriceConverterHelper.convertPrice(product.price ?? 0),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style:
                        swiss721Light.copyWith(fontSize: 18 * cs, color: nameColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return outOfStock ? Opacity(opacity: 0.45, child: card) : card;
  }
}

/// Row of allergen circles, centered as a group above the info block — Figma
/// B-01 card detail. One circle per declared allergen; order follows
/// [KioskAllergen.values] so it is stable across rebuilds.
class _AllergenRow extends StatelessWidget {
  final double cs;
  final Set<KioskAllergen> allergens;
  const _AllergenRow({required this.cs, required this.allergens});

  @override
  Widget build(BuildContext context) {
    final List<KioskAllergen> ordered =
        KioskAllergen.values.where(allergens.contains).toList();
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < ordered.length; i++) ...[
            if (i > 0) SizedBox(width: 2.735 * cs),
            _AllergenDot(allergen: ordered[i], cs: cs),
          ],
        ],
      ),
    );
  }
}

class _AllergenDot extends StatelessWidget {
  final KioskAllergen allergen;
  final double cs;
  const _AllergenDot({required this.allergen, required this.cs});

  @override
  Widget build(BuildContext context) {
    final double size = 14.585 * cs;
    return Semantics(
      label: kioskTranslate(context, allergen.translationKey, allergen.label),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: allergen.swatch, shape: BoxShape.circle),
        child: SvgPicture.asset(allergen.icon, width: size * 0.56, height: size * 0.56),
      ),
    );
  }
}

/// "OUT OF STOCK" pill replacing the merchandising badge. Figma values: fill
/// #808080, ~154.96 x 30.99, fully rounded, Loew Medium 16.043 white.
class _OutOfStockBadge extends StatelessWidget {
  final double cs;
  const _OutOfStockBadge({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 154.96 * cs,
      height: 30.99 * cs,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _kOutOfStockGrey,
        borderRadius: BorderRadius.circular(500 * cs),
      ),
      child: Text(
        kioskTranslate(context, 'landscape_out_of_stock', 'OUT OF STOCK').toUpperCase(),
        style: loewMedium.copyWith(fontSize: 16.043 * cs, height: 1.0, color: Colors.white),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final ProductTag tag;
  final double cs;
  const _Badge({required this.tag, required this.cs});

  Color get _color {
    final String? hex = tag.color;
    if (hex != null) {
      final String v = hex.replaceFirst('#', '').trim();
      if (v.length == 6) {
        final int? parsed = int.tryParse(v, radix: 16);
        if (parsed != null) return Color(0xFF000000 | parsed);
      }
    }
    return normalizeKioskTag(tag.tag ?? '') == 'popular'
        ? _kPopularGreen
        : _kSpecialRed;
  }

  String get _label {
    final String raw = tag.tag?.trim() ?? '';
    if (normalizeKioskTag(raw) == 'specials') return 'Special';
    if (raw.length <= 1) return raw.toUpperCase();
    return '${raw[0].toUpperCase()}${raw.substring(1).toLowerCase()}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14 * cs, vertical: 6 * cs),
      decoration: BoxDecoration(
        color: _color,
        borderRadius: BorderRadius.circular(500 * cs),
      ),
      child: Text(
        _label.toUpperCase(),
        style: loewMedium.copyWith(
            fontSize: 16 * cs, height: 1.0, color: Colors.white),
      ),
    );
  }
}

class _InfoDot extends StatelessWidget {
  final double cs;
  const _InfoDot({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18 * cs,
      height: 18 * cs,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(9 * cs),
      ),
      child: Text('i',
          style: loewBold.copyWith(
              fontSize: 10 * cs, height: 1.0, color: Colors.white)),
    );
  }
}
