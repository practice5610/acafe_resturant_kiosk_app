import 'package:flutter/material.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/common/widgets/custom_image_widget.dart';
import 'package:acafe_customer/features/category/domain/category_model.dart';
import 'package:acafe_customer/features/category/providers/category_provider.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/helper/product_helper.dart';

/// Warms Flutter's image cache for kiosk menu product/category images.
///
/// Deliberately NOT "precache everything": decoding all categories' products at
/// once overflows Flutter's image cache and evicts the visible category's images
/// (which is what makes cards re-shimmer). Instead we warm the SELECTED category
/// first — optionally awaited so the first menu paint is flicker-free — and its
/// immediate neighbours in the background. The long tail is served instantly
/// from the browser HTTP cache (CDN sends `Cache-Control: immutable`).
class KioskMenuImageHelper {
  /// Precache the selected category's product images (+ category thumbnails),
  /// then the neighbouring categories in the background.
  ///
  /// Pass [awaitVisible] to resolve only once the selected category's images are
  /// cached — use that right before navigating to the menu so the first paint
  /// has no shimmer.
  static Future<void> precacheAroundSelected(
    BuildContext context,
    CategoryProvider categories,
    SplashProvider splash, {
    bool awaitVisible = false,
    int neighbours = 1,
    bool includeOptions = false,
  }) async {
    _precacheCategoryThumbnails(context, categories, splash);

    final List<CategoryModel> list = categories.categoryList ?? const [];
    if (list.isEmpty) return;

    int index =
        list.indexWhere((c) => '${c.id}' == categories.selectedSubCategoryId);
    if (index < 0) index = 0;

    // Visible category first (awaited when requested).
    final visible = _productsForIndex(categories, list, index);
    if (awaitVisible) {
      await Future.wait([
        precacheProducts(context, splash, visible, awaitAll: true),
        if (includeOptions)
          precacheProductOptions(context, splash, visible, awaitAll: true),
      ]);
    } else {
      precacheProducts(context, splash, visible);
      if (includeOptions) precacheProductOptions(context, splash, visible);
    }

    if (!context.mounted) return;

    // Neighbours (previous/next categories) in the background so the next tap is
    // instant too, without churning the cache with every category at once.
    for (int d = 1; d <= neighbours; d++) {
      for (final n in [index - d, index + d]) {
        if (n >= 0 && n < list.length) {
          final neighbour = _productsForIndex(categories, list, n);
          precacheProducts(context, splash, neighbour);
          if (includeOptions) {
            precacheProductOptions(context, splash, neighbour);
          }
        }
      }
    }
  }

  /// Precache a specific list of product images. Fire-and-forget by default;
  /// pass [awaitAll] to resolve only once every image is cached (or has failed).
  static Future<void> precacheProducts(
    BuildContext context,
    SplashProvider splash,
    List<Product> products, {
    bool awaitAll = false,
  }) async {
    final String? base = splash.baseUrls?.productImageUrl;
    if (base == null) return;

    final List<Future<void>> futures = [];
    for (final product in products) {
      final f = _precache(context, '$base/${product.image}',
          cacheWidth: CustomImageWidget.kKioskProductCacheWidth);
      if (awaitAll) futures.add(f);
    }
    if (awaitAll && futures.isNotEmpty) await Future.wait(futures);
  }

  /// Cache widths the POS customize screen renders option cards at — they are
  /// part of the cache key on native, so these must match the widgets
  /// (`_DietaryCard` 200, `_VesselCard` 320, `_AddOnCard` 240 in
  /// `pos_product_customize_screen.dart`). On web the width is ignored.
  static const int posVariationCacheWidth = 200;
  static const int posVesselCacheWidth = 320;
  static const int posAddonCacheWidth = 240;

  /// Precache the images the customize screen shows for [products]: every
  /// variation option (size / dietary / cup) and every add-on. Add-ons are
  /// shared across many products, so URLs are de-duplicated first — a
  /// category of 20 drinks usually needs only a handful of downloads.
  static Future<void> precacheProductOptions(
    BuildContext context,
    SplashProvider splash,
    List<Product> products, {
    bool awaitAll = false,
  }) async {
    final urls = optionImageUrls(
      products,
      productImageBase: splash.baseUrls?.productImageUrl,
      addonImageBase: splash.baseUrls?.addonImageUrl,
    );
    final Set<String> variationUrls = urls.variations;
    final Set<String> addonUrls = urls.addons;

    final List<Future<void>> futures = [
      for (final url in variationUrls) ...[
        _precache(context, url, cacheWidth: posVariationCacheWidth),
        _precache(context, url, cacheWidth: posVesselCacheWidth),
      ],
      for (final url in addonUrls)
        _precache(context, url, cacheWidth: posAddonCacheWidth),
    ];
    if (awaitAll && futures.isNotEmpty) await Future.wait(futures);
  }

  /// The de-duplicated option image URLs for [products] — variation values
  /// (under the product image base) and add-ons (under the add-on base).
  /// Pure, so it is testable without a network or a widget tree.
  @visibleForTesting
  static ({Set<String> variations, Set<String> addons}) optionImageUrls(
    List<Product> products, {
    required String? productImageBase,
    required String? addonImageBase,
  }) {
    final Set<String> variations = {};
    final Set<String> addons = {};
    for (final product in products) {
      if (productImageBase != null) {
        for (final variation
            in ProductHelper.effectiveVariations(product) ?? const []) {
          for (final value in variation.variationValues ?? const []) {
            final String? image = value.image;
            if (image != null && image.isNotEmpty && image != 'def.png') {
              variations.add('$productImageBase/$image');
            }
          }
        }
      }
      if (addonImageBase != null) {
        for (final group in product.effectiveAddOnGroups) {
          for (final addon in group.addons) {
            if (addon.hasImage) addons.add('$addonImageBase/${addon.image}');
          }
        }
        for (final addon in product.addOns ?? const []) {
          if (addon.hasImage) addons.add('$addonImageBase/${addon.image}');
        }
      }
    }
    return (variations: variations, addons: addons);
  }

  static List<Product> _productsForIndex(
      CategoryProvider categories, List<CategoryModel> list, int index) {
    final int? id = list[index].id;
    if (id == null) return const [];
    return categories.kioskProductsForCategoryIds([id]);
  }

  static void _precacheCategoryThumbnails(BuildContext context,
      CategoryProvider categories, SplashProvider splash) {
    final String? base = splash.baseUrls?.categoryImageUrl;
    if (base == null) return;
    for (final category in categories.categoryList ?? const []) {
      if ((category.image ?? '').isNotEmpty) {
        _precache(context, '$base/${category.image}',
            cacheWidth: CustomImageWidget.kKioskThumbCacheWidth);
      }
    }
  }

  static Future<void> _precache(BuildContext context, String rawUrl,
      {int? cacheWidth}) {
    if (CustomImageWidget.resolveWebImageUrl(rawUrl).isEmpty) {
      return Future.value();
    }
    // Warm the EXACT provider the widget renders with (same cacheKey + the same
    // ResizeImage/memCacheWidth wrapping), so the grid reads back this entry
    // instead of re-downloading — see CustomImageWidget.provider.
    return precacheImage(
      CustomImageWidget.provider(rawUrl, cacheWidth: cacheWidth),
      context,
    ).catchError((_) {});
  }
}
