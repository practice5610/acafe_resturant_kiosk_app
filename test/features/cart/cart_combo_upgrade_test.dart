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
}
