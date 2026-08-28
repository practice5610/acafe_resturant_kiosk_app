import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_order_composition.dart';
import 'package:flutter_test/flutter_test.dart';

CartModel _line({
  String? area,
  bool cupCan = false,
  String cupCanName = 'Can or cup?',
}) {
  final product = Product(
    variations: cupCan ? [Variation(name: cupCanName)] : const [],
  );
  product.area = area;
  return CartModel(0, 0, const [], 0, 1, 0, const [], product, const []);
}

CartModel _deal(List<CartModel> components) => CartModel.deal(
      dealId: 1,
      title: 'Combo',
      bundlePrice: 10,
      originalPrice: 14,
      components: components,
    );

void main() {
  group('productHasCupCanOption', () {
    test('matches the generated Can or cup? group', () {
      expect(productHasCupCanOption(_line(cupCan: true).product), isTrue);
    });

    test('matches hand-authored cup/can group names', () {
      expect(
          productHasCupCanOption(_line(cupCan: true, cupCanName: 'Cup').product),
          isTrue);
      expect(
          productHasCupCanOption(_line(cupCan: true, cupCanName: 'CAN').product),
          isTrue);
    });

    test('does not treat Pecan as a vessel', () {
      expect(
          productHasCupCanOption(
              _line(cupCan: true, cupCanName: 'Pecan').product),
          isFalse);
    });

    test('is false when the product has no variations', () {
      expect(productHasCupCanOption(_line().product), isFalse);
      expect(productHasCupCanOption(null), isFalse);
    });
  });

  group('KioskCourse.of', () {
    test('a cup/can option is a drink even when area says kitchen', () {
      expect(KioskCourse.of(_line(area: 'kitchen', cupCan: true).product),
          KioskCourse.drink);
    });

    test('no cup/can is food even when area says bar', () {
      expect(KioskCourse.of(_line(area: 'bar').product), KioskCourse.food);
    });

    test('area alone no longer decides food vs drink', () {
      expect(KioskCourse.of(_line(area: 'kitchen').product), KioskCourse.food);
      expect(KioskCourse.of(_line(area: 'bar').product), KioskCourse.food);
      expect(KioskCourse.of(_line(area: null).product), KioskCourse.food);
      expect(KioskCourse.of(_line(area: '').product), KioskCourse.food);
    });

    test('merchandise area stays merchandise even with cup/can', () {
      expect(
          KioskCourse.of(_line(area: 'merchandise', cupCan: true).product),
          KioskCourse.merchandise);
      expect(KioskCourse.of(_line(area: ' Merchandise ').product),
          KioskCourse.merchandise);
    });
  });

  group('upsell rule', () {
    KioskUpsell upsellFor(List<CartModel> lines) =>
        KioskOrderComposition.of(lines).upsell;

    test('food only asks for a drink', () {
      expect(upsellFor([_line()]), KioskUpsell.suggestDrink);
      expect(upsellFor([_line(), _line(area: 'kitchen')]),
          KioskUpsell.suggestDrink);
    });

    test('drinks only asks for food', () {
      expect(upsellFor([_line(cupCan: true)]), KioskUpsell.suggestFood);
      expect(upsellFor([_line(cupCan: true), _line(cupCan: true)]),
          KioskUpsell.suggestFood);
    });

    test('food and drink offers the combo', () {
      expect(upsellFor([_line(), _line(cupCan: true)]), KioskUpsell.suggestCombo);
    });

    test('merchandise alone offers nothing', () {
      expect(upsellFor([_line(area: 'merchandise')]), KioskUpsell.none);
      expect(
          upsellFor(
              [_line(area: 'merchandise'), _line(area: 'merchandise')]),
          KioskUpsell.none);
    });

    test('merchandise never changes the answer for real items', () {
      expect(upsellFor([_line(), _line(area: 'merchandise')]),
          KioskUpsell.suggestDrink);
      expect(upsellFor([_line(cupCan: true), _line(area: 'merchandise')]),
          KioskUpsell.suggestFood);
      expect(
          upsellFor([
            _line(cupCan: true),
            _line(),
            _line(area: 'merchandise'),
          ]),
          KioskUpsell.suggestCombo);
    });

    test('a combo deal is classified from its components, not the first product',
        () {
      expect(
        upsellFor([
          _deal([_line(), _line(cupCan: true)]),
        ]),
        KioskUpsell.suggestCombo,
      );
      expect(
        upsellFor([
          _deal([_line()]),
        ]),
        KioskUpsell.suggestDrink,
      );
      expect(
        upsellFor([
          _deal([_line(cupCan: true)]),
        ]),
        KioskUpsell.suggestFood,
      );
    });

    test('an empty cart offers nothing', () {
      expect(KioskOrderComposition.of([]).upsell, KioskUpsell.none);
      expect(KioskOrderComposition.of([null]).upsell, KioskUpsell.none);
    });
  });
}
