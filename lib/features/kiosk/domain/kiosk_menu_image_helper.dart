import 'package:flutter/material.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/common/widgets/custom_image_widget.dart';
import 'package:acafe_customer/features/category/domain/category_model.dart';
import 'package:acafe_customer/features/category/providers/category_provider.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';

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
      await precacheProducts(context, splash, visible, awaitAll: true);
    } else {
      precacheProducts(context, splash, visible);
    }

    // Neighbours (previous/next categories) in the background so the next tap is
    // instant too, without churning the cache with every category at once.
    for (int d = 1; d <= neighbours; d++) {
      for (final n in [index - d, index + d]) {
        if (n >= 0 && n < list.length) {
          precacheProducts(context, splash, _productsForIndex(categories, list, n));
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

  static List<Product> _productsForIndex(
      CategoryProvider categories, List<CategoryModel> list, int index) {
    final int? id = list[index].id;
    if (id == null) return const [];
    return categories.kioskProductsForCategoryIds([id]);
  }

  static void _precacheCategoryThumbnails(
      BuildContext context, CategoryProvider categories, SplashProvider splash) {
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
