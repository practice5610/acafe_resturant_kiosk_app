import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_order_composition.dart';
import 'package:flutter_test/flutter_test.dart';

CartModel _line(String? area) {
  final product = Product();
  product.area = area;
  return CartModel(0, 0, const [], 0, 1, 0, const [], product, const []);
}

void main() {
  group('KioskCourse.of', () {
    test('maps the areas the backend actually stores', () {
      expect(KioskCourse.of(_line('bar').product), KioskCourse.drink);
      expect(KioskCourse.of(_line('kitchen').product), KioskCourse.food);
      expect(
          KioskCourse.of(_line('merchandise').product), KioskCourse.merchandise);
    });

    test('is case- and whitespace-insensitive', () {
      expect(KioskCourse.of(_line(' Kitchen ').product), KioskCourse.food);
      expect(KioskCourse.of(_line('BAR').product), KioskCourse.drink);
    });

    test('treats an unknown or missing area as a drink', () {
      // Safe default in a cafe: calling a drink "food" would make the kiosk
      // offer a customer a drink they are already holding.
      for (final area in <String?>[null, '', 'something_new']) {
        expect(KioskCourse.of(_line(area).product), KioskCourse.drink,
            reason: 'area: ${area ?? "null"}');
      }
    });
  });

  group('upsell rule', () {
    KioskUpsell upsellFor(List<String?> areas) =>
        KioskOrderComposition.of(areas.map(_line).toList()).upsell;

    test('food only asks for a drink', () {
      expect(upsellFor(['kitchen']), KioskUpsell.suggestDrink);
      expect(upsellFor(['kitchen', 'kitchen']), KioskUpsell.suggestDrink);
    });

    test('drinks only asks for food', () {
      expect(upsellFor(['bar']), KioskUpsell.suggestFood);
      expect(upsellFor(['bar', 'bar']), KioskUpsell.suggestFood);
    });

    test('food and drink offers the combo', () {
      expect(upsellFor(['kitchen', 'bar']), KioskUpsell.suggestCombo);
    });

    test('merchandise alone offers nothing', () {
      // A beanie is not a meal and does not make one complete.
      expect(upsellFor(['merchandise']), KioskUpsell.none);
      expect(upsellFor(['merchandise', 'merchandise']), KioskUpsell.none);
    });

    test('merchandise never changes the answer for real items', () {
      expect(upsellFor(['kitchen', 'merchandise']), KioskUpsell.suggestDrink);
      expect(upsellFor(['bar', 'merchandise']), KioskUpsell.suggestFood);
      expect(
          upsellFor(['bar', 'kitchen', 'merchandise']), KioskUpsell.suggestCombo);
    });

    test('an empty cart offers nothing', () {
      expect(KioskOrderComposition.of([]).upsell, KioskUpsell.none);
      expect(KioskOrderComposition.of([null]).upsell, KioskUpsell.none);
    });
  });
}
