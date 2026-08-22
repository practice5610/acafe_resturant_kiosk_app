import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';

/// Resolves kiosk product images.
///
/// Hero rule: the large product image is **always** the product's own photo.
/// Variation option images belong to their option cards only — selecting a
/// size / milk / cup option never replaces the product photo.
class KioskProductImageHelper {
  KioskProductImageHelper._();

  static bool _hasImage(String? image) =>
      image != null && image.isNotEmpty && image != 'def.png';

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
    required String? productImageBaseUrl,
  }) {
    return resolveUrl(
      productImageBaseUrl: productImageBaseUrl,
      filename: product.image,
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

  /// Full URL for a cart line — the product photo, regardless of selection.
  static String cartLineImageUrl({
    required CartModel cart,
    required String? productImageBaseUrl,
  }) {
    return resolveUrl(
      productImageBaseUrl: productImageBaseUrl,
      filename: cart.product?.image,
    );
  }
}
