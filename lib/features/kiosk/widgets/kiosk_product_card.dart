// The kiosk PRODUCT CARD (Figma card 02, nodes 2305:12471 / 2305:14909).
//
// ONE card, shared by the menu grid and the upsell sheet so the two can never
// drift. Moved verbatim out of kiosk_menu_screen.dart, where it was the private
// `_KioskProductCard`; the only additions are the optional [showDescription],
// [showInfoIcon] and [onTap] params, whose defaults reproduce the grid exactly.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/common/responsive/kiosk_layout.dart';
import 'package:acafe_customer/common/widgets/custom_asset_image_widget.dart';
import 'package:acafe_customer/common/widgets/custom_image_widget.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_allergen.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_menu_filter.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_product_customize_sheet.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_tap.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_trimmed_image.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_ui.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/helper/price_converter_helper.dart';
import 'package:acafe_customer/theme/brand_colors.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';

const Color _kPopularGreen = Color(0xFF357937);
const Color _kSpecialRed = Color(0xFF59030E);

/// A merchandising badge (POPULAR, NEW, …) drawn on the card.
class KioskCardBadge {
  final String label;
  final Color color;
  const KioskCardBadge(this.label, this.color);
}

/// Badge from merchandising tags only (Popular, Specials, …).
/// Allergen tags never appear here — see [kioskMenuCardBadgeTag].
KioskCardBadge? kioskCardBadgeFor(Product product) {
  final ProductTag? chosen = kioskMenuCardBadgeTag(product);
  if (chosen == null) return null;
  final String raw = chosen.tag?.trim() ?? '';
  if (raw.isEmpty) return null;
  return KioskCardBadge(kioskCardBadgeLabel(raw), _kioskCardBadgeColor(chosen));
}

String kioskCardBadgeLabel(String tag) {
  if (normalizeKioskTag(tag) == 'specials') return 'Special';
  if (tag.length <= 1) return tag.toUpperCase();
  return '${tag[0].toUpperCase()}${tag.substring(1).toLowerCase()}';
}

Color _kioskCardBadgeColor(ProductTag tag) {
  final Color? fromHex = _kioskColorFromHex(tag.color);
  if (fromHex != null) return fromHex;
  switch (normalizeKioskTag(tag.tag ?? '')) {
    case 'popular':
      return _kPopularGreen;
    case 'specials':
      return _kSpecialRed;
    default:
      return _kSpecialRed;
  }
}

Color? _kioskColorFromHex(String? hex) {
  if (hex == null) return null;
  final String value = hex.replaceFirst('#', '').trim();
  if (value.length != 6) return null;
  final int? parsed = int.tryParse(value, radix: 16);
  if (parsed == null) return null;
  return Color(0xFF000000 | parsed);
}

// ─────────────────────────────────────────────────────────────────────────────
// Product card — Figma node 2305:12471 redesign
//
// Stack-based layout with ABSOLUTE positioning inside a fixed-size SizedBox.
// Every vertical offset is measured from the top of the card in design px and
// scaled by `ts = tileWidth / 548`. Content length never shifts any baseline.
// ─────────────────────────────────────────────────────────────────────────────

/// Design-unit constants for the product card (Figma 2305:12471).
/// Centralised here so they map 1:1 to the design spec.
class KioskCardDesign {
  KioskCardDesign._();

  // Card frame
  static const double cardWidth = 548;
  static const double cardHeight = 823;
  static const double cardRadius = 33;
  static const double cardBorderWidth = 5.5;

  /// Gentle card lift (Material elevation), kept faint on purpose.
  static const double cardElevation = 3;
  static const Color cardElevationColor = Color(0x33A89F82);

  // Photo feather mask
  static const double photoTop = -11;
  static const double photoWidthFraction = 0.82; // 82% of card width
  static const double photoHeight = 630;
  // The feather mask is a radial gradient: opaque centre → transparent edge.
  // Stops from the Figma SVG (paint0_radial_0_91): 0→0.45 opaque, 0.92→ transparent.
  static const double featherOpaqueStop = 0.45;
  static const double featherFadeStop = 0.92;

  // Allergen icons row
  static const double allergenTop = 574;
  static const double allergenIconSize = 32;
  static const double allergenIconGap = 6;
  static const double allergenRowHeight = 32;

  // Name text box
  static const double nameTop = 628;
  static const double nameHeight = 67; // fixed 2-line box
  static const double nameFontSize = 31.68;
  static const double nameLineHeight = 1.05;

  // Description
  static const double descGap = 7; // below name box
  static const double descHeight = 27;
  static const double descFontSize = 22;
  static const double descLineHeight = 1.2;

  // Price
  static const double priceGap = 9; // below description
  static const double priceHeight = 42;
  static const double priceFontSize = 39.6;
  static const double priceLineHeight = 1.05;

  // Text side inset (from card edge to text block)
  static const double textInset = 24;

  // Badge (POPULAR / OUT OF STOCK)
  static const double badgeTop = 38.5;
  static const double badgeLeft = 27.5;
  static const double badgeHeight = 68;
  static const double badgeRadius = 1098.9; // full pill
  static const double badgeFontSize = 35.2;

  // Info icon
  static const double infoTop = 24;
  static const double infoRight = 23;
  static const double infoSize = 40;
  static const double infoFontSize = 22;

  // Out-of-stock
  static const double outOfStockOpacity = 0.45;
  static const Color outOfStockBadgeColor = Color(0xFF808080);
  static const Color outOfStockTextColor = Color(0xFF808080);
}

class KioskProductCard extends StatelessWidget {
  final double s;
  final double tileWidth;
  final Product product;
  final KioskCardBadge? badge;
  final bool showImages;

  /// Menu grid: true (name → description → price). Upsell: false — Figma
  /// 2305:14909 has no description, so the price sits 9px under the name box
  /// (628 + 67 + 9 = 704) instead of under the description.
  final bool showDescription;

  /// The (i) ingredients button, top-right. The upsell design has none.
  final bool showInfoIcon;

  /// Replaces the default tap (open customize). The upsell uses it to close the
  /// sheet once the item has actually been added.
  final VoidCallback? onTap;

  /// Menu-grid redesign (300×340 reference card: contained image, divider,
  /// name / description / allergens / price stacked). The upsell sheet leaves
  /// this off and keeps card 02 unchanged. Same data, same taps.
  final bool menuStyle;

  const KioskProductCard({
    super.key,
    required this.s,
    required this.tileWidth,
    required this.product,
    this.badge,
    this.showImages = true,
    this.showDescription = true,
    this.showInfoIcon = true,
    this.onTap,
    this.menuStyle = false,
  });

  void _handleTap(BuildContext context) =>
      onTap != null ? onTap!() : openKioskCustomize(context, product);

  /// Out of stock when the branch-level record explicitly says so.
  /// A null [BranchProduct] means the product has no branch override — treat
  /// it as available (the backend would not include it otherwise).
  bool get _isOutOfStock =>
      product.branchProduct != null &&
      product.branchProduct!.isAvailable != true;

  @override
  Widget build(BuildContext context) {
    // Picture-less device: use the compact text-only card.
    if (!showImages) {
      return menuStyle
          ? _buildMenuTextOnlyCard(context)
          : _buildTextOnlyCard(context);
    }
    if (menuStyle) return _buildMenuCard(context);

    final double ts = tileWidth / KioskCardDesign.cardWidth;
    final double cardRadius = KioskCardDesign.cardRadius * ts;
    final double cardBorderWidth = KioskCardDesign.cardBorderWidth * ts;
    final double tileHeight =
        tileWidth * (KioskCardDesign.cardHeight / KioskCardDesign.cardWidth);

    final cardContent = SizedBox(
      width: tileWidth,
      height: tileHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Feathered photo ──
          _buildPhoto(context, ts),

          // ── Allergen icons ──
          _buildAllergenRow(ts),

          // ── Name (fixed 2-line box) ──
          _buildName(ts),

          // ── Description ──
          if (showDescription) _buildDescription(ts),

          // ── Price ──
          _buildPrice(ts),

          // ── Badge (POPULAR / OUT OF STOCK) ──
          if (badge != null && !_isOutOfStock) _buildBadge(ts),
          if (_isOutOfStock) _buildOutOfStockBadge(ts),
        ],
      ),
    );

    final card = Material(
      color: Colors.white,
      // Gentle lift: low elevation, very faint warm tint (no dark drop shadow).
      elevation: KioskCardDesign.cardElevation,
      shadowColor: KioskCardDesign.cardElevationColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cardRadius),
        side: BorderSide(color: BrandColors.cardBorder, width: cardBorderWidth),
      ),
      clipBehavior: Clip.antiAlias,
      child: cardContent,
    );

    // Out-of-stock: fade the card and block taps (but keep the info icon live).
    // The info icon is positioned OUTSIDE the card's tap area via a separate
    // Stack layer, so AbsorbPointer on the card does not kill it.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Card body — tappable unless out of stock.
        Opacity(
          opacity: _isOutOfStock ? KioskCardDesign.outOfStockOpacity : 1.0,
          child: _isOutOfStock
              ? AbsorbPointer(child: card)
              : KioskTap(
                  onTap: () => _handleTap(context),
                  child: card,
                ),
        ),
        // ── Info (i) icon — always tappable ──
        if (showInfoIcon) _buildInfoIcon(context, ts),
      ],
    );
  }

  // ── Menu-grid redesign ────────────────────────────────────────────────
  // Authored against a 300×340 reference card; `cu` = tileWidth / 300.

  static const Color _menuInk = Color(0xFF111111);
  // Reference grey, as specified (3.3:1 on white — below the 4.5:1 guard;
  // opted out at the style call by request).
  static const Color _menuDescInk = Color(0xFF8E8E8E);

  /// The short description the old card showed (`product.description`), or
  /// null when it is empty or only repeats the product name.
  String? get _menuDescription {
    final String desc = (product.description ?? '').trim();
    if (desc.isEmpty) return null;
    String norm(String v) =>
        v.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (norm(desc) == norm(product.name ?? '')) return null;
    return desc;
  }

  static const Color _menuPriceInk = Color(0xFF333333);
  static const Color _menuDivider = Color(0xFFEFEFEF);

  String _priceText() => PriceConverterHelper.convertPrice(
        product.price,
        discount: product.discount,
        discountType: product.discountType,
      );

  BoxDecoration _menuCardDecoration(double cu) => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14 * cu),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10 * cu,
            offset: Offset(0, 2 * cu),
          ),
        ],
      );

  /// Wraps a menu card body with the out-of-stock fade/tap-block and the info
  /// icon, exactly as the original card does.
  Widget _menuShell(BuildContext context, double cu, Widget body,
      {required bool withInfo}) {
    final card = Container(
      decoration: _menuCardDecoration(cu),
      clipBehavior: Clip.antiAlias,
      child: Material(color: Colors.transparent, child: body),
    );
    // The card body sizes the Stack (passthrough keeps the grid row's minimum
    // height, so every card in a row is as tall as the tallest).
    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.passthrough,
      children: [
        Opacity(
          opacity: _isOutOfStock ? KioskCardDesign.outOfStockOpacity : 1.0,
          child: _isOutOfStock
              ? AbsorbPointer(child: card)
              : KioskTap(onTap: () => _handleTap(context), child: card),
        ),
        if (badge != null && !_isOutOfStock)
          _menuBadge(cu, badge!.label.toUpperCase(), badge!.color),
        if (_isOutOfStock)
          _menuBadge(cu, 'OUT OF STOCK', KioskCardDesign.outOfStockBadgeColor),
        if (withInfo && showInfoIcon)
          Positioned(
            top: 8 * cu,
            right: 8 * cu,
            child: KioskTap(
              onTap: () => _showProductInfoDialog(context),
              // Generous hit box around a small, quiet glyph.
              child: Padding(
                padding: EdgeInsets.all(4 * cu),
                child: Container(
                  width: 16 * cu,
                  height: 16 * cu,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    'i',
                    style: poppinsMedium.copyWith(
                      fontSize: 10 * cu,
                      height: 1,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _menuBadge(double cu, String label, Color color) => Positioned(
        top: 10 * cu,
        left: 10 * cu,
        child: Container(
          height: 22 * cu,
          padding: EdgeInsets.symmetric(horizontal: 10 * cu),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(11 * cu),
          ),
          child: Text(
            label,
            style: poppinsMedium.copyWith(
                fontSize: 11 * cu,
                height: 1,
                letterSpacing: 0,
                color: Colors.white),
          ),
        ),
      );

  Widget _menuName(double cu) => Text(
        product.name ?? '',
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        // legibility: out-of-stock (disabled) state, same grey as before
        style: poppinsMedium.copyWith(
          fontSize: 14 * cu,
          height: 1.3,
          letterSpacing: 0,
          color: _isOutOfStock ? KioskCardDesign.outOfStockTextColor : _menuInk,
        ),
      );

  Widget _menuPrice(double cu) => Text(
        _priceText(),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        // legibility: out-of-stock (disabled) state, same grey as before
        style: poppinsRegular.copyWith(
          fontSize: 14 * cu,
          height: 1.3,
          letterSpacing: 0,
          color: _isOutOfStock
              ? KioskCardDesign.outOfStockTextColor
              : _menuPriceInk,
        ),
      );

  Widget _buildMenuCard(BuildContext context) {
    final double cu = tileWidth / 300;
    final splash = Provider.of<SplashProvider>(context, listen: false);
    final String image = '${splash.baseUrls?.productImageUrl}/${product.image}';
    final Set<KioskAllergen> allergens = kioskProductAllergens(product);
    final double icon = 21 * cu;

    // Height comes from the content. Inside a grid row the card receives a
    // MINIMUM height (the row's tallest card); the min-size Column then puts
    // that slack between the text and the price (spaceBetween), so prices
    // line up at the bottom of the row. No fixed heights, no empty slots.
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // a. Image area — 200 tall on a 304-wide card (= 197 at 300), 8
            // padding. The photo is contained by its visible content, not its
            // transparent canvas (see KioskTrimmedImage), at full resolution.
            SizedBox(
              height: 197 * cu,
              child: Padding(
                padding: EdgeInsets.all(8 * cu),
                child: KioskTrimmedImage(image: image),
              ),
            ),
            // b. Divider under the image.
            Container(height: 1 * cu, color: _menuDivider),
            Padding(
              padding: EdgeInsets.fromLTRB(16 * cu, 16 * cu, 16 * cu, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // c. Name.
                  _menuName(cu),
                  // d. Short description. Hidden (with its gap) when empty
                  // or a repeat of the name.
                  if (showDescription && _menuDescription != null) ...[
                    SizedBox(height: 4 * cu),
                    Text(
                      _menuDescription!,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: poppinsRegular.copyWith(
                        fontSize: 11 * cu,
                        height: 1.35,
                        letterSpacing: 0,
                        // legibility: reference grey #8E8E8E, requested by design
                        color: _menuDescInk,
                      ),
                    ),
                  ],
                  // e. Allergen / dietary icons (kioskProductAllergens), 21
                  // with 6 gaps. Hidden (with its gap) when there are none.
                  if (allergens.isNotEmpty) ...[
                    SizedBox(height: 8 * cu),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (int i = 0; i < allergens.length; i++) ...[
                          if (i > 0) SizedBox(width: 6 * cu),
                          Container(
                            width: icon,
                            height: icon,
                            decoration: BoxDecoration(
                              color: allergens.elementAt(i).swatch,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: CustomAssetImageWidget(
                                allergens.elementAt(i).icon,
                                width: icon * 0.57,
                                height: icon * 0.57,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        // f. Price — 8 below the content above, 16 above the card bottom.
        Padding(
          padding: EdgeInsets.fromLTRB(16 * cu, 8 * cu, 16 * cu, 16 * cu),
          child: _menuPrice(cu),
        ),
      ],
    );
    return _menuShell(context, cu, body, withInfo: true);
  }

  /// Picture-less device, menu style: name + price on the new card surface.
  Widget _buildMenuTextOnlyCard(BuildContext context) {
    final double cu = tileWidth / 300;
    final body = Padding(
      padding: EdgeInsets.fromLTRB(16 * cu, 12 * cu, 16 * cu, 12 * cu),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _menuName(cu),
          SizedBox(height: 6 * cu),
          _menuPrice(cu),
        ],
      ),
    );
    return _menuShell(context, cu, body, withInfo: false);
  }

  /// Compact text-only card (picture-less device / show-images off).
  Widget _buildTextOnlyCard(BuildContext context) {
    final double ts = tileWidth / KioskCardDesign.cardWidth;
    final double cardRadius = KioskCardDesign.cardRadius * ts;
    final double cardBorderWidth = KioskCardDesign.cardBorderWidth * ts;

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cardRadius),
        side: BorderSide(color: BrandColors.cardBorder, width: cardBorderWidth),
      ),
      clipBehavior: Clip.antiAlias,
      child: KioskTap(
        onTap: _isOutOfStock ? null : () => _handleTap(context),
        child: Opacity(
          opacity: _isOutOfStock ? KioskCardDesign.outOfStockOpacity : 1.0,
          child: Padding(
            padding: EdgeInsets.fromLTRB(24 * ts, 16 * ts, 24 * ts, 24 * ts),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (badge != null) ...[
                  Center(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 20 * ts, vertical: 6 * ts),
                      decoration: BoxDecoration(
                        color: _isOutOfStock
                            ? KioskCardDesign.outOfStockBadgeColor
                            : badge!.color,
                        borderRadius: BorderRadius.circular(10 * ts),
                      ),
                      child: Text(
                        _isOutOfStock ? 'OUT OF STOCK' : badge!.label,
                        style: loewMedium.copyWith(
                            color: Colors.white, fontSize: 28 * ts),
                      ),
                    ),
                  ),
                  SizedBox(height: 12 * ts),
                ],
                Text(
                  product.name ?? '',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: loewExtraBold.copyWith(
                    fontSize: KioskCardDesign.nameFontSize * ts,
                    height: KioskCardDesign.nameLineHeight,
                    letterSpacing: 0,
                    color: _isOutOfStock
                        ? KioskCardDesign.outOfStockTextColor
                        : Colors.black,
                  ),
                ),
                SizedBox(height: 8 * ts),
                Text(
                  PriceConverterHelper.convertPrice(
                    product.price,
                    discount: product.discount,
                    discountType: product.discountType,
                  ),
                  textAlign: TextAlign.center,
                  style: swiss721Light.copyWith(
                    fontSize: KioskCardDesign.priceFontSize * ts,
                    height: KioskCardDesign.priceLineHeight,
                    color: _isOutOfStock
                        ? KioskCardDesign.outOfStockTextColor
                        : Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Feathered product photo with radial gradient mask.
  Widget _buildPhoto(BuildContext context, double ts) {
    final splash = Provider.of<SplashProvider>(context, listen: false);
    final String image = '${splash.baseUrls?.productImageUrl}/${product.image}';
    final double photoWidth = tileWidth * KioskCardDesign.photoWidthFraction;
    final double photoHeight = KioskCardDesign.photoHeight * ts;
    final double photoLeft = (tileWidth - photoWidth) / 2;

    return Positioned(
      top: KioskCardDesign.photoTop * ts,
      left: photoLeft,
      width: photoWidth,
      height: photoHeight,
      child: ShaderMask(
        shaderCallback: (Rect bounds) => const RadialGradient(
          center: Alignment.center,
          radius: 1.0,
          colors: [
            Colors.black,
            Colors.black,
            Colors.transparent,
          ],
          stops: [
            0.0,
            KioskCardDesign.featherOpaqueStop,
            KioskCardDesign.featherFadeStop,
          ],
        ).createShader(bounds),
        blendMode: BlendMode.dstIn,
        child: CustomImageWidget(
          emptyWhenMissing: true,
          placeholder: Images.placeholderImage,
          image: image,
          fit: BoxFit.cover,
          useShimmer: true,
          cacheWidth: CustomImageWidget.kKioskProductCacheWidth,
        ),
      ),
    );
  }

  /// Allergen icons row — always reserves its height even with no allergens.
  Widget _buildAllergenRow(double ts) {
    final Set<KioskAllergen> allergens = kioskProductAllergens(product);
    final double iconSize = KioskCardDesign.allergenIconSize * ts;
    final double iconGap = KioskCardDesign.allergenIconGap * ts;

    return Positioned(
      top: KioskCardDesign.allergenTop * ts,
      left: 0,
      right: 0,
      height: KioskCardDesign.allergenRowHeight * ts,
      child: allergens.isEmpty
          ? SizedBox(height: KioskCardDesign.allergenRowHeight * ts)
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < allergens.length; i++) ...[
                  if (i > 0) SizedBox(width: iconGap),
                  Container(
                    width: iconSize,
                    height: iconSize,
                    decoration: BoxDecoration(
                      color: allergens.elementAt(i).swatch,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: CustomAssetImageWidget(
                        allergens.elementAt(i).icon,
                        width: iconSize * 0.57,
                        height: iconSize * 0.57,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  /// Product name — fixed 2-line box, vertically centered when 1 line.
  Widget _buildName(double ts) {
    final double nameHeight = KioskCardDesign.nameHeight * ts;
    final double textInset = KioskCardDesign.textInset * ts;

    return Positioned(
      top: KioskCardDesign.nameTop * ts,
      left: textInset,
      right: textInset,
      height: nameHeight,
      child: Center(
        child: Text(
          product.name ?? '',
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: loewExtraBold.copyWith(
            fontSize: KioskCardDesign.nameFontSize * ts,
            height: KioskCardDesign.nameLineHeight,
            letterSpacing: 0,
            color: _isOutOfStock
                ? KioskCardDesign.outOfStockTextColor
                : Colors.black,
          ),
        ),
      ),
    );
  }

  /// Product description — 1 line with ellipsis.
  Widget _buildDescription(double ts) {
    final double descTop = (KioskCardDesign.nameTop +
            KioskCardDesign.nameHeight +
            KioskCardDesign.descGap) *
        ts;
    final double textInset = KioskCardDesign.textInset * ts;

    return Positioned(
      top: descTop,
      left: textInset,
      right: textInset,
      height: KioskCardDesign.descHeight * ts,
      child: Center(
        child: Text(
          product.description ?? '',
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: swiss721Light.copyWith(
            fontSize: KioskCardDesign.descFontSize * ts,
            height: KioskCardDesign.descLineHeight,
            color: const Color(0xFF4D4D4D),
          ),
        ),
      ),
    );
  }

  /// Price — single line.
  Widget _buildPrice(double ts) {
    final double priceTop = (KioskCardDesign.nameTop +
            KioskCardDesign.nameHeight +
            (showDescription
                ? KioskCardDesign.descGap + KioskCardDesign.descHeight
                : 0) +
            KioskCardDesign.priceGap) *
        ts;
    final double textInset = KioskCardDesign.textInset * ts;

    return Positioned(
      top: priceTop,
      left: textInset,
      right: textInset,
      height: KioskCardDesign.priceHeight * ts,
      child: Center(
        child: Text(
          PriceConverterHelper.convertPrice(
            product.price,
            discount: product.discount,
            discountType: product.discountType,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: swiss721Light.copyWith(
            fontSize: KioskCardDesign.priceFontSize * ts,
            height: KioskCardDesign.priceLineHeight,
            color: _isOutOfStock
                ? KioskCardDesign.outOfStockTextColor
                : Colors.black,
          ),
        ),
      ),
    );
  }

  /// POPULAR badge — green pill, top-left.
  Widget _buildBadge(double ts) {
    return Positioned(
      top: KioskCardDesign.badgeTop * ts,
      left: KioskCardDesign.badgeLeft * ts,
      child: Container(
        height: KioskCardDesign.badgeHeight * ts,
        padding: EdgeInsets.symmetric(horizontal: 28 * ts),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: badge!.color,
          borderRadius: BorderRadius.circular(KioskCardDesign.badgeRadius * ts),
        ),
        child: Text(
          badge!.label.toUpperCase(),
          style: loewMedium.copyWith(
            fontSize: KioskCardDesign.badgeFontSize * ts,
            height: 1,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  /// OUT OF STOCK badge — grey pill, top-left.
  Widget _buildOutOfStockBadge(double ts) {
    return Positioned(
      top: KioskCardDesign.badgeTop * ts,
      left: KioskCardDesign.badgeLeft * ts,
      child: Container(
        height: KioskCardDesign.badgeHeight * ts,
        padding: EdgeInsets.symmetric(horizontal: 28 * ts),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: KioskCardDesign.outOfStockBadgeColor,
          borderRadius: BorderRadius.circular(KioskCardDesign.badgeRadius * ts),
        ),
        child: Text(
          'OUT OF STOCK',
          style: loewMedium.copyWith(
            fontSize: KioskCardDesign.badgeFontSize * ts,
            height: 1,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  /// Info (i) icon — 40×40 circle, top-right, independently tappable.
  Widget _buildInfoIcon(BuildContext context, double ts) {
    final double infoSize = KioskCardDesign.infoSize * ts;
    final double infoRight = KioskCardDesign.infoRight * ts;
    final double infoTop = KioskCardDesign.infoTop * ts;

    return Positioned(
      top: infoTop,
      right: infoRight,
      child: KioskTap(
        onTap: () => _showProductInfoDialog(context),
        child: Container(
          width: infoSize,
          height: infoSize,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(infoSize / 2),
          ),
          alignment: Alignment.center,
          child: Text(
            'i',
            style: loewBold.copyWith(
              fontSize: KioskCardDesign.infoFontSize * ts,
              height: 1,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  /// Ingredients & allergens info popup.
  void _showProductInfoDialog(BuildContext context) {
    final Set<KioskAllergen> allergens = kioskProductAllergens(product);
    final double s = KioskLayout.scaleOf(context);
    showDialog(
      context: context,
      builder: (context) => _ProductInfoDialog(
        product: product,
        allergens: allergens,
        s: s,
      ),
    );
  }
}

/// Ingredients & allergens popup dialog.
class _ProductInfoDialog extends StatelessWidget {
  final Product product;
  final Set<KioskAllergen> allergens;
  final double s;
  const _ProductInfoDialog({
    required this.product,
    required this.allergens,
    required this.s,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: KioskUI.pageBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30 * s),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 600 * s),
        child: Padding(
          padding: EdgeInsets.all(40 * s),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      product.name ?? '',
                      style: loewExtraBold.copyWith(
                        fontSize: 36 * s,
                        height: 1.1,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  KioskTap(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.close, size: 36 * s, color: Colors.black),
                  ),
                ],
              ),
              if (product.description != null &&
                  product.description!.isNotEmpty) ...[
                SizedBox(height: 16 * s),
                Text(
                  product.description!,
                  style: swiss721Light.copyWith(
                    fontSize: 24 * s,
                    height: 1.3,
                    color: const Color(0xFF4D4D4D),
                  ),
                ),
              ],
              if (allergens.isNotEmpty) ...[
                SizedBox(height: 28 * s),
                Text(
                  'Allergens',
                  style: loewBold.copyWith(
                    fontSize: 28 * s,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 16 * s),
                Wrap(
                  spacing: 12 * s,
                  runSpacing: 12 * s,
                  children: allergens.map((allergen) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 36 * s,
                          height: 36 * s,
                          decoration: BoxDecoration(
                            color: allergen.swatch,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: CustomAssetImageWidget(
                              allergen.icon,
                              width: 20 * s,
                              height: 20 * s,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(width: 8 * s),
                        Text(
                          allergen.label,
                          style: swiss721Light.copyWith(
                            fontSize: 24 * s,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
