import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/features/cart/domain/cart_line_matcher.dart';
import 'package:flutter_test/flutter_test.dart';

CartModel _line({
  required int productId,
  int quantity = 1,
  List<List<bool?>>? variations,
  List<AddOn>? addOns,
}) {
  return CartModel(
    10,
    10,
    const [],
    0,
    quantity,
    0,
    addOns ?? const [],
    Product(id: productId, name: 'Item'),
    variations ?? const [],
  );
}

void main() {
  group('findMatchingCartLineIndex', () {
    test('finds identical simple product line', () {
      final cart = [_line(productId: 5)];
      final match = findMatchingCartLineIndex(cart, _line(productId: 5));
      expect(match, 0);
    });

    test('returns -1 when no matching line exists', () {
      final cart = [_line(productId: 5)];
      expect(findMatchingCartLineIndex(cart, _line(productId: 6)), -1);
    });

    test('does not match when variation selections differ', () {
      final cart = [
        _line(productId: 1, variations: [
          [true, false],
        ]),
      ];
      final candidate = _line(productId: 1, variations: [
        [false, true],
      ]);
      expect(findMatchingCartLineIndex(cart, candidate), -1);
    });

    test('does not match when add-ons differ', () {
      final cart = [
        _line(productId: 1, addOns: [AddOn(id: 9, quantity: 1)]),
      ];
      expect(findMatchingCartLineIndex(cart, _line(productId: 1)), -1);
    });

    test('does not match when instructions differ', () {
      final cart = [
        CartModel(
          10,
          10,
          const [],
          0,
          1,
          0,
          const [],
          Product(id: 1, name: 'Item'),
          const [],
          instruction: 'SPECIAL INSTRUCTIONS (Optional)',
        ),
      ];
      expect(
        findMatchingCartLineIndex(
          cart,
          CartModel(
            10,
            10,
            const [],
            0,
            1,
            0,
            const [],
            Product(id: 1, name: 'Item'),
            const [],
          ),
        ),
        -1,
      );
    });
  });
}
