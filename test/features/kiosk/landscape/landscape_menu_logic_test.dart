import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/features/cart/domain/reposotories/cart_repo.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/kiosk/landscape/landscape_menu_logic.dart';
import 'package:flutter_test/flutter_test.dart';

/// The landscape menu's add-detection (B-03) and the reused quantity-merge rule.

/// A CartProvider whose persistence is a no-op, so addToCart's real merge logic
/// runs without SharedPreferences or a navigator context.
class _FakeCartRepo extends CartRepo {
  _FakeCartRepo() : super(sharedPreferences: null);
  @override
  void addToCartList(List<CartModel?> cartProductList) {}
}

CartModel _line(String name, {List<List<bool?>>? variations}) => CartModel(
      6.0,
      6.0,
      const [],
      0,
      1,
      0,
      const [],
      Product(id: 1, name: name, image: '', price: 6.0),
      variations ?? const [],
    );

void main() {
  group('landscapeJustAddedIndex (B-03 green border + toast trigger)', () {
    test('a newly appended line returns its index', () {
      final prev = <CartModel?>[_line('Latte')];
      final next = <CartModel?>[_line('Latte'), _line('Matcha')];
      expect(landscapeJustAddedIndex(prev, next), 1);
    });

    test('the first ever line returns index 0', () {
      expect(landscapeJustAddedIndex(const [], <CartModel?>[_line('Latte')]), 0);
    });

    test('no change in length returns null (a panel +/- is not an add)', () {
      final a = <CartModel?>[_line('Latte')];
      final b = <CartModel?>[_line('Latte')];
      expect(landscapeJustAddedIndex(a, b), isNull);
    });

    test('a removed line returns null', () {
      final prev = <CartModel?>[_line('Latte'), _line('Matcha')];
      final next = <CartModel?>[_line('Latte')];
      expect(landscapeJustAddedIndex(prev, next), isNull);
    });
  });

  group('quantity-merge rule (reused CartProvider.addToCart)', () {
    test('adding the same product with the same choices increases quantity', () {
      final cart = CartProvider(cartRepo: _FakeCartRepo());
      cart.addToCart(_line('Latte'), null, showMessage: false);
      cart.addToCart(_line('Latte'), null, showMessage: false);
      expect(cart.cartList.length, 1);
      expect(cart.cartList.first!.quantity, 2);
    });

    test('a different choice set adds a separate row', () {
      final cart = CartProvider(cartRepo: _FakeCartRepo());
      cart.addToCart(
          _line('Latte', variations: [
            [true, false]
          ]),
          null,
          showMessage: false);
      cart.addToCart(
          _line('Latte', variations: [
            [false, true]
          ]),
          null,
          showMessage: false);
      expect(cart.cartList.length, 2);
    });
  });
}
