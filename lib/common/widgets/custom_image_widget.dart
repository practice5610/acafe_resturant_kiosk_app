import 'package:cached_network_image/cached_network_image.dart';
import 'package:cached_network_image_platform_interface/cached_network_image_platform_interface.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:acafe_customer/utill/images.dart';

class CustomImageWidget extends StatelessWidget {
  final String image;
  final double? height;
  final double? width;
  final BoxFit? fit;
  final bool isNotification;
  final String placeholder;

  /// When true, a shimmer skeleton (sized to fill the slot) is shown while the
  /// network image downloads, instead of the static coffee placeholder. The
  /// coffee placeholder is still used when the image is missing or fails to
  /// load. Used by the kiosk menu so cards show a skeleton, not a stock image.
  final bool useShimmer;

  /// Absolute pixel width to decode + cache the image at (via [ResizeImage]).
  /// null = full resolution. Product/rail thumbnails set this so an 800×1200
  /// source (~3.7 MB decoded) is cached small — far less memory, so the image
  /// cache doesn't evict + re-decode it (the shimmer "pop") on scroll / category
  /// switch. Precache via [provider] with the SAME value so the warmed entry is
  /// the exact one the grid reads back (memCacheWidth changes the cache key).
  final int? cacheWidth;

  /// Shared decode width (px) for kiosk product images — used by BOTH the grid
  /// cards and the precache so they warm/read the identical cache entry.
  static const int kKioskProductCacheWidth = 600;

  /// Shared decode width (px) for kiosk category / rail thumbnails.
  static const int kKioskThumbCacheWidth = 300;

  const CustomImageWidget({
    super.key,
    required this.image,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
    this.isNotification = false,
    this.placeholder = '',
    this.useShimmer = false,
    this.cacheWidth,
  });

  /// Grey shimmer box that fills the image slot — used as the loading skeleton.
  static Widget shimmerBox({double? height, double? width}) {
    return Shimmer(
      color: const Color(0xFFE4E4E4),
      colorOpacity: 0.35,
      child: Container(
        height: height,
        width: width,
        color: const Color(0xFFEDEDED),
      ),
    );
  }

  static bool isDefaultImage(String image) {
    if (image.isEmpty) return true;
    final path = Uri.tryParse(image)?.path ?? image;
    return path.endsWith('/def.png') || path.endsWith('def.png');
  }

  static String normalizeStorageUrl(String image) {
    final uri = Uri.tryParse(image);
    if (uri == null || !uri.path.contains('/storage/app/public/')) {
      return image;
    }
    final base = Uri.parse(AppConstants.baseUrl);
    return base.replace(path: uri.path, query: null, fragment: null).toString();
  }

  static String resolveWebImageUrl(String image) {
    if (!kIsWeb || image.isEmpty || isDefaultImage(image)) return image;
    // Load straight from the CDN (no /image-proxy hop). CloudFront serves images
    // with CORS enabled, so the browser can fetch them cross-origin directly.
    return normalizeStorageUrl(image);
  }

  /// The EXACT [ImageProvider] this widget renders with for a given [image] and
  /// [cacheWidth]. Precache through this so the warmed cache entry has the same
  /// key the grid reads: CachedNetworkImage feeds `memCacheWidth` into a
  /// `ResizeImage` (via OctoImage), which changes the cache key — a plain
  /// provider would warm a DIFFERENT entry and the grid would still re-download.
  static ImageProvider provider(String image, {int? cacheWidth}) {
    final ImageProvider base = CachedNetworkImageProvider(
      resolveWebImageUrl(image),
      cacheKey: image,
    );
    // No resize on web: the web engine's decode-with-target-size path throws
    // "EncodingError: The source image cannot be decoded" for many images. So
    // downscaling is native-only; on web we warm the plain provider (matching
    // the widget below, which also skips memCacheWidth on web).
    if (kIsWeb) return base;
    // Mirrors OctoImage's `ResizeImage.resizeIfNeeded(memCacheWidth, null, base)`.
    return ResizeImage.resizeIfNeeded(cacheWidth, null, base);
  }

  @override
  Widget build(BuildContext context) {
    final placeholderWidget = Image.asset(
      placeholder.isNotEmpty ? placeholder : Images.placeholderImage,
      height: height, width: width, fit: fit,
    );

    // Skeleton shown while the network image is loading (only when requested).
    final loadingWidget =
        useShimmer ? shimmerBox(height: height, width: width) : placeholderWidget;

    if (image.isEmpty || (kIsWeb && isDefaultImage(image))) {
      return placeholderWidget;
    }

    // Decode at [cacheWidth] (or the display width) instead of the source's full
    // 800×1200 resolution, to cut memory + decode time and avoid image-cache
    // eviction churn (the shimmer "pop" on scroll / category switch). Cache by
    // the raw image URL so the same asset is reused across navigation.
    // Downscale decode on NATIVE only. On web, memCacheWidth routes through
    // ResizeImage → ui.instantiateImageCodec(targetWidth), which throws
    // "EncodingError: The source image cannot be decoded" for many images.
    final double dpr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 2.0;
    final int? memCacheWidth = kIsWeb
        ? null
        : (cacheWidth ??
            (width != null && width!.isFinite ? (width! * dpr).round() : null));

    return CachedNetworkImage(
      imageUrl: resolveWebImageUrl(image),
      cacheKey: image,
      height: height,
      width: width,
      fit: fit,
      memCacheWidth: memCacheWidth,
      // Short fade so a cache hit appears almost instantly (no slow pop), and
      // there is no placeholder flash when the widget is rebuilt for a hit.
      fadeInDuration: const Duration(milliseconds: 150),
      fadeOutDuration: const Duration(milliseconds: 50),
      // No custom headers on web: keeps the image GET a "simple" CORS request
      // (no preflight), which the CDN's CORS policy answers directly.
      imageRenderMethodForWeb: kIsWeb ? ImageRenderMethodForWeb.HttpGet : ImageRenderMethodForWeb.HtmlImage,
      placeholder: (context, url) => loadingWidget,
      errorWidget: (context, url, error) => placeholderWidget,
    );
  }
}
