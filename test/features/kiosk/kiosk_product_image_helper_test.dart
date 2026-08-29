import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_product_image_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('KioskProductImageHelper.optionCardImageUrl', () {
    test('returns empty when the option has no image of its own', () {
      final url = KioskProductImageHelper.optionCardImageUrl(
        value: VariationValue(level: 'Regular Milk', optionPrice: 0),
        productImageBaseUrl: 'http://localhost/product',
      );

      expect(url, isEmpty);
    });

    test('returns empty for def.png sentinel', () {
      final url = KioskProductImageHelper.optionCardImageUrl(
        value: VariationValue(
          level: 'Oat Milk',
          optionPrice: 0.5,
          image: 'def.png',
        ),
        productImageBaseUrl: 'http://localhost/product',
      );

      expect(url, isEmpty);
    });

    test('returns the option image url when artwork is present', () {
      final url = KioskProductImageHelper.optionCardImageUrl(
        value: VariationValue(
          level: 'Almond Milk',
          optionPrice: 0.5,
          image: 'oat.png',
        ),
        productImageBaseUrl: 'http://localhost/product',
      );

      expect(url, 'http://localhost/product/oat.png');
    });

    test('hero still uses the product photo independently', () {
      final product = Product(id: 1, name: 'Americano', image: 'hero.png');
      final hero = KioskProductImageHelper.heroImageUrl(
        product: product,
        productImageBaseUrl: 'http://localhost/product',
      );

      expect(hero, 'http://localhost/product/hero.png');
    });
  });
}
