import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';

/// Resolves kiosk product images from variant selections.
///
/// Hero rule: only the **first** variation group (index 0) can replace the
/// large product image when its selected option has an `image`. Later groups
/// show images on their cards only; hero falls back to the product default.
class KioskProductImageHelper {
  KioskProductImageHelper._();

  /// Index of the variation group that controls the hero image.
  ///
  /// Only the **first** group (index 0) can control the hero. If that group has
  /// no option images, the hero stays on the product default and later groups
  /// (e.g. milk type) show images on their cards only.
  static int? heroVariationGroupIndex(Product? product) {
    final variations = product?.variations;
    if (variations == null || variations.isEmpty) return null;
    final values = variations.first.variationValues ?? [];
    if (values.any((v) => _hasImage(v.image))) return 0;
    return null;
  }

  static bool _hasImage(String? image) =>
      image != null && image.isNotEmpty && image != 'def.png';

  /// Filename for the hero image (variant or product default).
  static String? heroImageFilename(
    Product? product,
    List<List<bool?>>? selectedVariations,
  ) {
    if (product == null) return null;
    final heroIndex = heroVariationGroupIndex(product);
    if (heroIndex != null &&
        selectedVariations != null &&
        heroIndex < selectedVariations.length) {
      final variations = product.variations ?? [];
      if (heroIndex < variations.length) {
        final values = variations[heroIndex].variationValues ?? [];
        final selected = selectedVariations[heroIndex];
        for (int i = 0; i < values.length && i < selected.length; i++) {
          if (selected[i] == true && _hasImage(values[i].image)) {
            return values[i].image;
          }
        }
      }
    }
    return product.image;
  }

  static String resolveUrl({
    required String? productImageBaseUrl,
    required String? filename,
  }) {
    if (productImageBaseUrl == null ||
        productImageBaseUrl.isEmpty ||
        filename == null ||
        filename.isEmpty) {
      return '';
    }
    return '$productImageBaseUrl/$filename';
  }

  /// Full URL for the hero / main product image area.
  static String heroImageUrl({
    required Product product,
    required List<List<bool?>>? selectedVariations,
    required String? productImageBaseUrl,
  }) {
    return resolveUrl(
      productImageBaseUrl: productImageBaseUrl,
      filename: heroImageFilename(product, selectedVariations),
    );
  }

  /// Full URL for a variation option card. Empty when the option has no image
  /// of its own — cards must not fall back to the product photo.
  static String optionCardImageUrl({
    required VariationValue value,
    required String? productImageBaseUrl,
  }) {
    if (!_hasImage(value.image)) return '';
    return resolveUrl(
      productImageBaseUrl: productImageBaseUrl,
      filename: value.image,
    );
  }

  /// Full URL for a cart line (uses saved selection matrix).
  static String cartLineImageUrl({
    required CartModel cart,
    required String? productImageBaseUrl,
  }) {
    return heroImageUrl(
      product: cart.product!,
      selectedVariations: cart.variations,
      productImageBaseUrl: productImageBaseUrl,
    );
  }
}
