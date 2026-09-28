import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:flutter_test/flutter_test.dart';

CartModel _line({
  required int productId,
  int quantity = 1,
  double price = 5,
}) {
  return CartModel(
    price,
    price,
    const [],
    0,
    quantity,
    0,
    const [],
    Product(id: productId, name: 'Item $productId', price: price),
    const [],
  );
}

void main() {
  CartProvider seeded(List<CartModel?> lines) {
    final CartProvider cart = CartProvider(cartRepo: null);
    cart.replaceCartList(lines);
    return cart;
  }

  test('highest-index-first consume does not shift remaining indices', () {
    final a = _line(productId: 1, price: 5);
    final b = _line(productId: 2, price: 8);
    final leftover = _line(productId: 1, price: 5);
    final cart = seeded([a, b, leftover]);
    expect(cart.amount, 18);

    final deal = CartModel.deal(
      dealId: 10,
      title: 'Combo',
      bundlePrice: 10,
      originalPrice: 13,
      components: [
        _line(productId: 1, price: 5),
        _line(productId: 2, price: 8),
      ],
    );

    cart.applyComboUpgrade(consume: {0: 1, 1: 1}, dealLine: deal);

    expect(cart.cartList, hasLength(2));
    expect(cart.cartList[0]!.product!.id, 1);
    expect(cart.cartList[0]!.isDeal, isFalse);
    expect(cart.cartList[1]!.isDeal, isTrue);
    expect(cart.cartList[1]!.dealId, 10);
    expect(cart.amount, 15);
  });

  test('consuming one unit from qty 2 leaves qty 1 on that line', () {
    final lattes = _line(productId: 1, quantity: 2, price: 5);
    final food = _line(productId: 2, price: 8);
    final cart = seeded([lattes, food]);
    expect(cart.amount, 18);

    final deal = CartModel.deal(
      dealId: 10,
      title: 'Combo',
      bundlePrice: 10,
      originalPrice: 13,
      components: [
        _line(productId: 1, price: 5),
        _line(productId: 2, price: 8),
      ],
    );

    cart.applyComboUpgrade(consume: {0: 1, 1: 1}, dealLine: deal);

    expect(cart.cartList, hasLength(2));
    expect(cart.cartList[0]!.product!.id, 1);
    expect(cart.cartList[0]!.quantity, 1);
    expect(cart.cartList[0]!.isDeal, isFalse);
    expect(cart.cartList[1]!.isDeal, isTrue);
    expect(cart.amount, 15);
  });

  test('an identical existing combo merges into one line', () {
    final existing = CartModel.deal(
      dealId: 10,
      title: 'Combo',
      bundlePrice: 10,
      originalPrice: 13,
      components: [
        _line(productId: 1, price: 5),
        _line(productId: 2, price: 8),
      ],
    );
    final a = _line(productId: 1, price: 5);
    final b = _line(productId: 2, price: 8);
    final cart = seeded([existing, a, b]);

    final upgrade = CartModel.deal(
      dealId: 10,
      title: 'Combo',
      bundlePrice: 10,
      originalPrice: 13,
      components: [
        _line(productId: 1, price: 5),
        _line(productId: 2, price: 8),
      ],
    );

    cart.applyComboUpgrade(consume: {1: 1, 2: 1}, dealLine: upgrade);

    expect(cart.cartList, hasLength(1));
    expect(cart.cartList[0]!.isDeal, isTrue);
    expect(cart.cartList[0]!.quantity, 2);
    expect(cart.amount, 20);
  });

  test('copyWithQuantity clones fields without mutating the original', () {
    final original = _line(productId: 1, quantity: 2, price: 5);
    original.quantity = 2;
    final clone = original.copyWithQuantity(1);
    expect(clone.quantity, 1);
    expect(original.quantity, 2);
    expect(identical(clone, original), isFalse);
    clone.quantity = 9;
    expect(original.quantity, 2);
  });
  // The combo upgrade walks the cart by INDEX. Now that one product can hold
  // several differently configured lines, that walk has to pick off exactly the
  // units it was told to and leave the sibling configurations alone.
  group('with several configurations of one product in the cart', () {
    CartModel configured({
      required int productId,
      required int pick,
      int quantity = 1,
      double price = 5,
    }) {
      return CartModel(
        price,
        price,
        const [],
        0,
        quantity,
        0,
        const [],
        Product(id: productId, name: 'Item $productId', price: price),
        [
          [pick == 0, pick == 1],
        ],
      );
    }

    test('consumes only the configuration it was pointed at', () {
      final regular = configured(productId: 1, pick: 0, quantity: 2);
      final oat = configured(productId: 1, pick: 1);
      final food = configured(productId: 2, pick: 0, price: 8);
      final cart = seeded([regular, oat, food]);
      expect(cart.amount, 23);

      final deal = CartModel.deal(
        dealId: 10,
        title: 'Combo',
        bundlePrice: 10,
        originalPrice: 13,
        components: [
          configured(productId: 1, pick: 0),
          configured(productId: 2, pick: 0, price: 8),
        ],
      );

      // Take one Regular and the food. The Oat line must not be touched.
      cart.applyComboUpgrade(consume: {0: 1, 2: 1}, dealLine: deal);

      expect(cart.cartList, hasLength(3));
      expect(cart.cartList[0]!.quantity, 1);
      expect(cart.cartList[0]!.variations![0], [true, false]);
      expect(cart.cartList[1]!.variations![0], [false, true],
          reason: 'the oat line survives untouched');
      expect(cart.cartList[1]!.quantity, 1);
      expect(cart.cartList[2]!.isDeal, isTrue);
      expect(cart.amount, 20);
    });

    test('emptying one configuration leaves its sibling in place', () {
      final regular = configured(productId: 1, pick: 0);
      final oat = configured(productId: 1, pick: 1);
      final food = configured(productId: 2, pick: 0, price: 8);
      final cart = seeded([regular, oat, food]);

      final deal = CartModel.deal(
        dealId: 10,
        title: 'Combo',
        bundlePrice: 10,
        originalPrice: 13,
        components: [
          configured(productId: 1, pick: 1),
          configured(productId: 2, pick: 0, price: 8),
        ],
      );

      // The Oat line is fully consumed and removed; Regular stays.
      cart.applyComboUpgrade(consume: {1: 1, 2: 1}, dealLine: deal);

      expect(cart.cartList, hasLength(2));
      expect(cart.cartList[0]!.isDeal, isFalse);
      expect(cart.cartList[0]!.product!.id, 1);
      expect(cart.cartList[0]!.variations![0], [true, false]);
      expect(cart.cartList[1]!.isDeal, isTrue);
      expect(cart.amount, 15);
    });

    test('a deal only merges with a deal built from the same configurations',
        () {
      final existing = CartModel.deal(
        dealId: 10,
        title: 'Combo',
        bundlePrice: 10,
        originalPrice: 13,
        components: [
          configured(productId: 1, pick: 0),
          configured(productId: 2, pick: 0, price: 8),
        ],
      );
      final oat = configured(productId: 1, pick: 1);
      final food = configured(productId: 2, pick: 0, price: 8);
      final cart = seeded([existing, oat, food]);

      // Same deal id, but the drink inside is Oat rather than Regular, so this
      // is a different combo and must not stack onto the existing line.
      final upgrade = CartModel.deal(
        dealId: 10,
        title: 'Combo',
        bundlePrice: 10,
        originalPrice: 13,
        components: [
          configured(productId: 1, pick: 1),
          configured(productId: 2, pick: 0, price: 8),
        ],
      );

      cart.applyComboUpgrade(consume: {1: 1, 2: 1}, dealLine: upgrade);

      expect(cart.cartList, hasLength(2));
      expect(cart.cartList[0]!.isDeal, isTrue);
      expect(cart.cartList[0]!.quantity, 1);
      expect(cart.cartList[1]!.isDeal, isTrue);
      expect(cart.cartList[1]!.quantity, 1);
      expect(cart.cartList[1]!.components![0].variations![0], [false, true]);
    });
  });
}
