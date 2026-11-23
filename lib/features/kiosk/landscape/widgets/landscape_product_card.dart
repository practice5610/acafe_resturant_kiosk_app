import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_allergen.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_menu_filter.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_translate.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_product_customize_sheet.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_tap.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_trimmed_image.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/helper/price_converter_helper.dart';
import 'package:acafe_customer/utill/styles.dart';

const Color _kPopularGreen = Color(0xFF357937);
const Color _kSpecialRed = Color(0xFF59030E);
const Color _kOutOfStockGrey = Color(0xFF808080);
const Color _kInk = Color(0xFF111111);
const Color _kDescInk = Color(0xFF8E8E8E);
const Color _kPriceInk = Color(0xFF333333);
const Color _kDivider = Color(0xFFEFEFEF);

/// Mirrors [ProductProvider.checkStock] (`common/providers/product_provider.dart`)
/// for "does one more unit still fit" with quantity 1 — the same rule
/// `CartProvider.setQuantity` enforces before an add is let through. A product
/// with no `branchProduct` (not yet hydrated) or an `unlimited` stock type is
/// never out of stock, matching the portrait rule exactly.
bool kioskLandscapeIsOutOfStock(Product product) {
  final BranchProduct? bp = product.branchProduct;
  if (bp?.stockType == 'unlimited' ||
      bp?.stock == null ||
      bp?.soldQuantity == null) {
    return false;
  }
  final int remaining = bp!.stock! - bp.soldQuantity! - 1;
  return remaining <= 0;
}

/// Landscape (Option B) product grid card — the portrait menu card design:
/// white, radius 14, soft shadow, image area (0.66 × width) > 1px divider >
/// name > short description > allergen icons > price. Height comes from the
/// content; inside a grid row it receives the row's tallest height as a
/// minimum and puts the slack above the price (prices line up per row).
///
/// Everything scales from the card width (`cs = tileWidth / 304`). Fonts are
/// the landscape screen's own (Loew name, Swiss721 description/price). The tap,
/// out-of-stock rule, badge, info dot, image URL and price call are unchanged.
class LandscapeProductCard extends StatelessWidget {
  /// Design-card reference width (portrait card at 864 wide).
  static const double designCardWidth = 304;

  final double tileWidth;
  final Product product;
  final bool showImages;

  const LandscapeProductCard({
    super.key,
    required this.tileWidth,
    required this.product,
    this.showImages = true,
  });

  /// Short description, hidden when empty or a repeat of the name (portrait
  /// card rule).
  String? get _description {
    final String d = (product.description ?? '').trim();
    if (d.isEmpty) return null;
    String norm(String v) =>
        v.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    return norm(d) == norm(product.name ?? '') ? null : d;
  }

  @override
  Widget build(BuildContext context) {
    final splash = Provider.of<SplashProvider>(context, listen: false);
    final double cs = tileWidth / designCardWidth;
    final String image = '${splash.baseUrls?.productImageUrl}/${product.image}';
    final ProductTag? badgeTag = kioskMenuCardBadgeTag(product);
    final bool outOfStock = kioskLandscapeIsOutOfStock(product);
    final Set<KioskAllergen> allergens = kioskProductAllergens(product);
    final Color nameColor = outOfStock ? _kOutOfStockGrey : _kInk;
    final String? description = _description;
    final double imageArea = 0.66 * tileWidth;

    final Widget body = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showImages) ...[
              // Image area: the photo's visible content is contained in a
              // centred box of 78% card width × 88% area height. Never cropped.
              SizedBox(
                height: imageArea,
                child: Center(
                  child: SizedBox(
                    width: tileWidth * 0.78,
                    height: imageArea * 0.88,
                    child: KioskTrimmedImage(image: image),
                  ),
                ),
              ),
              Container(height: 1 * cs, color: _kDivider),
            ],
            Padding(
              padding: EdgeInsets.fromLTRB(14 * cs, 16 * cs, 14 * cs, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    product.name ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    // legibility: out-of-stock (disabled) state, same grey as before
                    style: loewBold.copyWith(
                        fontSize: 15 * cs, height: 1.2, color: nameColor),
                  ),
                  if (description != null) ...[
                    SizedBox(height: 4 * cs),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: swiss721Light.copyWith(
                        fontSize: 11.5 * cs,
                        height: 1.3,
                        // legibility: reference grey #8E8E8E, same as portrait card
                        color: _kDescInk,
                      ),
                    ),
                  ],
                  if (allergens.isNotEmpty) ...[
                    SizedBox(height: 8 * cs),
                    _AllergenRow(cs: cs, allergens: allergens),
                  ],
                ],
              ),
            ),
          ],
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(14 * cs, 8 * cs, 14 * cs, 16 * cs),
          child: Text(
            PriceConverterHelper.convertPrice(product.price ?? 0),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            // legibility: out-of-stock (disabled) state, same grey as before
            style: swiss721Light.copyWith(
                fontSize: 16 * cs,
                height: 1.2,
                color: outOfStock ? _kOutOfStockGrey : _kPriceInk),
          ),
        ),
      ],
    );

    final Widget card = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14 * cs),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10 * cs,
            offset: Offset(0, 2 * cs),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: KioskTap(
          onTap: outOfStock ? null : () => openKioskCustomize(context, product),
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              body,
              if (outOfStock)
                Positioned(
                  left: 10 * cs,
                  top: 10 * cs,
                  child: _OutOfStockBadge(cs: cs),
                )
              else if (badgeTag != null)
                Positioned(
                  left: 10 * cs,
                  top: 10 * cs,
                  child: _Badge(tag: badgeTag, cs: cs),
                ),
              Positioned(
                right: 10 * cs,
                top: 10 * cs,
                child: _InfoDot(cs: cs),
              ),
            ],
          ),
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
            if (i > 0) SizedBox(width: 6 * cs),
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
    final double size = 21 * cs;
    return Semantics(
      label: kioskTranslate(context, allergen.translationKey, allergen.label),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration:
            BoxDecoration(color: allergen.swatch, shape: BoxShape.circle),
        child: SvgPicture.asset(allergen.icon,
            width: size * 0.56, height: size * 0.56),
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
      height: 22 * cs,
      padding: EdgeInsets.symmetric(horizontal: 10 * cs),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _kOutOfStockGrey,
        borderRadius: BorderRadius.circular(500 * cs),
      ),
      child: Text(
        kioskTranslate(context, 'landscape_out_of_stock', 'OUT OF STOCK')
            .toUpperCase(),
        style: loewMedium.copyWith(
            fontSize: 11 * cs, height: 1.0, color: Colors.white),
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
      padding: EdgeInsets.symmetric(horizontal: 10 * cs, vertical: 5.5 * cs),
      decoration: BoxDecoration(
        color: _color,
        borderRadius: BorderRadius.circular(500 * cs),
      ),
      child: Text(
        _label.toUpperCase(),
        style: loewMedium.copyWith(
            fontSize: 11 * cs, height: 1.0, color: Colors.white),
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
      width: 16 * cs,
      height: 16 * cs,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(8 * cs),
      ),
      child: Text('i',
          style: loewBold.copyWith(
              fontSize: 10 * cs, height: 1.0, color: Colors.white)),
    );
  }
}
