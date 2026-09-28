// AC1–AC5, as the bug was actually reported.
//
//   1. Add Americano -> Large, Regular Milk.
//   2. Back to the menu, tap Americano again.
//   3. Change the size to Small, leave the milk alone, add to cart.
//   4. Expected TWO lines; the Large one untouched.
//
// The earlier tests used a single-group fixture (milk only). The reported repro
// has TWO variation groups and changes only the first, which is the case where
// a partial-grid comparison would go wrong — so it gets its own file, and the
// grid is asserted position by position rather than by price.
//
// These drive `CartProvider` through the exact index each UI path passes:
//   *  a product-grid / menu tap  -> `productProvider.cartIndex`, always -1
//   *  a cart / receipt line tap  -> that line's real index
// Kiosk and POS share the model, the matcher, the provider and
// `buildKioskCartModel`, so one matrix covers both; the tap-to-index wiring for
// each is covered by `kiosk_repeated_product_test.dart` and
// `pos_product_customize_test.dart`.

import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/features/cart/domain/cart_line_matcher.dart';
import 'package:acafe_customer/features/cart/domain/reposotories/cart_repo.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_cart_totals.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCartRepo extends CartRepo {
  _FakeCartRepo() : super(sharedPreferences: null);
  @override
  void addToCartList(List<CartModel?> cartProductList) {}
}

/// The index a product-grid / menu tap passes on save. `ProductProvider`'s
/// `cartIndex` is `final int _cartIndex = -1`, so a new add can only ever be
/// this — which is what makes it an add rather than an edit.
const int kNewAdd = -1;

const int _kAmericanoId = 42;

const int _sizeGroup = 0;
const int _milkGroup = 1;
const int _large = 0;
const int _small = 1;
const int _regularMilk = 0;
const int _coconutMilk = 1;

/// Americano with the two groups from the repro, plus two add-ons.
Product _americano() => Product(
      id: _kAmericanoId,
      name: 'Americano',
      price: 3.50,
      tax: 0,
      taxType: 'amount',
      discount: 0,
      discountType: 'amount',
      variations: [
        Variation(
          name: 'Size',
          min: 1,
          max: 1,
          isRequired: true,
          isMultiSelect: false,
          variationValues: [
            VariationValue(level: 'Large', optionPrice: 1.00),
            VariationValue(level: 'Small', optionPrice: 0),
          ],
        ),
        Variation(
          name: 'Milk',
          min: 1,
          max: 1,
          isRequired: true,
          isMultiSelect: false,
          variationValues: [
            VariationValue(level: 'Regular Milk', optionPrice: 0),
            VariationValue(level: 'Coconut Milk', optionPrice: 0.50),
          ],
        ),
      ],
      addOns: [
        AddOns(id: 17, name: 'Extra Shot', price: 0.80, tax: 0),
        AddOns(id: 18, name: 'Vanilla Syrup', price: 0.60, tax: 0),
      ],
    );

/// A line as `buildKioskCartModel` builds it: the variation grid is a boolean
/// per option, and `price` already carries the options' surcharges.
CartModel _line({
  required Product product,
  required int size,
  required int milk,
  List<AddOn>? addOns,
  int quantity = 1,
}) {
  final List<List<bool?>> grid = [
    [size == _large, size == _small],
    [milk == _regularMilk, milk == _coconutMilk],
  ];
  double unit = product.price ?? 0;
  if (size == _large) unit += 1.00;
  if (milk == _coconutMilk) unit += 0.50;
  return CartModel(
    unit,
    unit,
    const [],
    0,
    quantity,
    0,
    addOns ?? const [],
    product,
    grid,
  );
}

CartProvider _cart(List<CartModel?> seed) {
  final CartProvider cart = CartProvider(cartRepo: _FakeCartRepo());
  if (seed.isNotEmpty) cart.replaceCartList(seed);
  return cart;
}

/// Human-readable picks for a line, so a failure names the configuration.
String _describe(CartModel line) {
  final List<Variation> groups = line.product?.variations ?? const [];
  final List<List<bool?>> grid = line.variations ?? const [];
  final List<String> picks = [];
  for (int g = 0; g < groups.length && g < grid.length; g++) {
    final List<VariationValue> values = groups[g].variationValues ?? const [];
    for (int i = 0; i < values.length && i < grid[g].length; i++) {
      if (grid[g][i] == true) picks.add(values[i].level ?? '');
    }
  }
  final String extras = (line.addOnIds ?? const [])
      .map((a) => '+${a.id}x${a.quantity ?? 1}')
      .join(' ');
  return '${picks.join('/')}${extras.isEmpty ? '' : ' $extras'} '
      'qty:${line.quantity}';
}

void main() {
  group('AC1 — the reported repro: Large then Small', () {
    test('changing only the size makes a second line, Large untouched', () {
      final Product product = _americano();
      final CartProvider cart = _cart(const []);

      // 1. Americano, Large, Regular Milk.
      cart.addToCart(
        _line(product: product, size: _large, milk: _regularMilk),
        kNewAdd,
        showMessage: false,
      );
      expect(cart.cartList.length, 1);

      // 2-3. Back to the menu, tap Americano, switch to Small, add.
      cart.addToCart(
        _line(product: product, size: _small, milk: _regularMilk),
        kNewAdd,
        showMessage: false,
      );

      // 4. Two lines.
      expect(cart.cartList.length, 2,
          reason: 'got: ${cart.cartList.map((l) => _describe(l!)).join(' | ')}');

      final CartModel first = cart.cartList[0]!;
      final CartModel second = cart.cartList[1]!;

      // Line 1 is untouched — this is what the bug destroyed.
      expect(first.variations![_sizeGroup], [true, false],
          reason: 'line 1 must still be Large');
      expect(first.variations![_milkGroup], [true, false]);
      expect(first.quantity, 1);
      expect(kioskLineTotal(first), closeTo(4.50, 0.001));

      expect(second.variations![_sizeGroup], [false, true],
          reason: 'line 2 must be Small');
      expect(second.variations![_milkGroup], [true, false],
          reason: 'the milk was not touched');
      expect(second.quantity, 1);
      expect(kioskLineTotal(second), closeTo(3.50, 0.001));

      expect(first.lineId, isNot(second.lineId));
    });

    test('the two lines are independent objects, not two views of one', () {
      final Product product = _americano();
      final CartProvider cart = _cart(const []);
      cart.addToCart(
        _line(
          product: product,
          size: _large,
          milk: _regularMilk,
          addOns: [AddOn(id: 17, quantity: 1)],
        ),
        kNewAdd,
        showMessage: false,
      );
      cart.addToCart(
        _line(
          product: product,
          size: _small,
          milk: _regularMilk,
          addOns: [AddOn(id: 17, quantity: 1)],
        ),
        kNewAdd,
        showMessage: false,
      );

      final CartModel first = cart.cartList[0]!;
      final CartModel second = cart.cartList[1]!;

      // Shared grids would mean editing one line silently rewrote the other.
      expect(identical(first.variations, second.variations), isFalse);
      expect(identical(first.variations![0], second.variations![0]), isFalse);
      expect(identical(first.addOnIds, second.addOnIds), isFalse);

      // And prove it, rather than only asserting on object identity.
      first.variations![_sizeGroup][_large] = false;
      expect(second.variations![_sizeGroup][_large], isFalse,
          reason: 'line 2 was Small already');
      expect(cart.cartList[1]!.variations![_sizeGroup][_small], isTrue,
          reason: 'mutating line 1 must not have touched line 2');
    });

    test('a third size-only variant becomes a third line', () {
      final Product product = _americano();
      final CartProvider cart = _cart(const []);
      cart.addToCart(_line(product: product, size: _large, milk: _regularMilk),
          kNewAdd, showMessage: false);
      cart.addToCart(_line(product: product, size: _small, milk: _regularMilk),
          kNewAdd, showMessage: false);
      cart.addToCart(_line(product: product, size: _small, milk: _coconutMilk),
          kNewAdd, showMessage: false);

      expect(cart.cartList.length, 3);
      expect(cart.cartList.map((l) => l!.lineId).toSet().length, 3);
    });
  });

  group('AC2 — a variation-only change makes a new line', () {
    test('same size, different milk', () {
      final Product product = _americano();
      final CartProvider cart = _cart(const []);
      cart.addToCart(_line(product: product, size: _large, milk: _regularMilk),
          kNewAdd, showMessage: false);
      cart.addToCart(_line(product: product, size: _large, milk: _coconutMilk),
          kNewAdd, showMessage: false);

      expect(cart.cartList.length, 2);
      expect(cart.cartList[0]!.variations![_milkGroup], [true, false]);
      expect(cart.cartList[1]!.variations![_milkGroup], [false, true]);
      expect(kioskLineTotal(cart.cartList[0]!), closeTo(4.50, 0.001));
      expect(kioskLineTotal(cart.cartList[1]!), closeTo(5.00, 0.001));
    });
  });

  group('AC3 — an add-on change makes a new line', () {
    test('add-on added', () {
      final Product product = _americano();
      final CartProvider cart = _cart(const []);
      cart.addToCart(_line(product: product, size: _large, milk: _regularMilk),
          kNewAdd, showMessage: false);
      cart.addToCart(
        _line(
          product: product,
          size: _large,
          milk: _regularMilk,
          addOns: [AddOn(id: 17, quantity: 1)],
        ),
        kNewAdd,
        showMessage: false,
      );

      expect(cart.cartList.length, 2);
      expect(cart.cartList[0]!.addOnIds, isEmpty);
      expect(cart.cartList[1]!.addOnIds!.single.id, 17);
      expect(kioskLineTotal(cart.cartList[1]!), closeTo(5.30, 0.001));
    });

    test('add-on removed', () {
      final Product product = _americano();
      final CartProvider cart = _cart(const []);
      cart.addToCart(
        _line(
          product: product,
          size: _large,
          milk: _regularMilk,
          addOns: [AddOn(id: 17, quantity: 1)],
        ),
        kNewAdd,
        showMessage: false,
      );
      cart.addToCart(_line(product: product, size: _large, milk: _regularMilk),
          kNewAdd, showMessage: false);

      expect(cart.cartList.length, 2);
    });

    test('add-on quantity changed', () {
      final Product product = _americano();
      final CartProvider cart = _cart(const []);
      cart.addToCart(
        _line(
          product: product,
          size: _large,
          milk: _regularMilk,
          addOns: [AddOn(id: 17, quantity: 1)],
        ),
        kNewAdd,
        showMessage: false,
      );
      cart.addToCart(
        _line(
          product: product,
          size: _large,
          milk: _regularMilk,
          addOns: [AddOn(id: 17, quantity: 2)],
        ),
        kNewAdd,
        showMessage: false,
      );

      expect(cart.cartList.length, 2);
      expect(cart.cartList[0]!.addOnIds!.single.quantity, 1);
      expect(cart.cartList[1]!.addOnIds!.single.quantity, 2);
      // 3.50 + 1.00 Large + 0.80*2 shots.
      expect(kioskLineTotal(cart.cartList[1]!), closeTo(6.10, 0.001));
    });

    test('a different add-on at the same quantity', () {
      final Product product = _americano();
      final CartProvider cart = _cart(const []);
      cart.addToCart(
        _line(
            product: product,
            size: _large,
            milk: _regularMilk,
            addOns: [AddOn(id: 17, quantity: 1)]),
        kNewAdd,
        showMessage: false,
      );
      cart.addToCart(
        _line(
            product: product,
            size: _large,
            milk: _regularMilk,
            addOns: [AddOn(id: 18, quantity: 1)]),
        kNewAdd,
        showMessage: false,
      );

      expect(cart.cartList.length, 2);
    });
  });

  group('AC4 — an identical configuration stacks', () {
    test('same size, milk and add-ons => one line, qty 2', () {
      final Product product = _americano();
      final CartProvider cart = _cart(const []);
      cart.addToCart(_line(product: product, size: _large, milk: _regularMilk),
          kNewAdd, showMessage: false);
      final int at = cart.addToCart(
          _line(product: product, size: _large, milk: _regularMilk), kNewAdd,
          showMessage: false);

      expect(cart.cartList.length, 1);
      expect(cart.cartList[0]!.quantity, 2);
      expect(at, 0);
    });

    test('add-on order does not make it a different configuration', () {
      final Product product = _americano();
      final CartProvider cart = _cart(const []);
      cart.addToCart(
        _line(product: product, size: _large, milk: _regularMilk, addOns: [
          AddOn(id: 17, quantity: 1),
          AddOn(id: 18, quantity: 2),
        ]),
        kNewAdd,
        showMessage: false,
      );
      cart.addToCart(
        _line(product: product, size: _large, milk: _regularMilk, addOns: [
          AddOn(id: 18, quantity: 2),
          AddOn(id: 17, quantity: 1),
        ]),
        kNewAdd,
        showMessage: false,
      );

      expect(cart.cartList.length, 1);
      expect(cart.cartList[0]!.quantity, 2);
    });

    test('stacking onto the SECOND of three lines leaves the others alone', () {
      final Product product = _americano();
      final CartProvider cart = _cart([
        _line(product: product, size: _large, milk: _regularMilk),
        _line(product: product, size: _small, milk: _regularMilk),
        _line(product: product, size: _small, milk: _coconutMilk),
      ]);

      cart.addToCart(_line(product: product, size: _small, milk: _regularMilk),
          kNewAdd, showMessage: false);

      expect(cart.cartList.length, 3);
      expect(cart.cartList[0]!.quantity, 1);
      expect(cart.cartList[1]!.quantity, 2);
      expect(cart.cartList[2]!.quantity, 1);
    });
  });

  group('AC5 — editing from the cart touches only that line', () {
    test('a line tap passes its own index and edits in place', () {
      final Product product = _americano();
      final CartProvider cart = _cart([
        _line(product: product, size: _large, milk: _regularMilk),
        _line(product: product, size: _small, milk: _regularMilk),
        _line(product: product, size: _small, milk: _coconutMilk),
      ]);

      // Tap line 2 in the cart and give it a shot.
      final int at = cart.addToCart(
        _line(
          product: product,
          size: _small,
          milk: _regularMilk,
          addOns: [AddOn(id: 17, quantity: 1)],
        ),
        1,
        showMessage: false,
      );

      expect(at, 1);
      expect(cart.cartList.length, 3);
      expect(cart.cartList[0]!.addOnIds, isEmpty);
      expect(cart.cartList[0]!.variations![_sizeGroup], [true, false]);
      expect(cart.cartList[1]!.addOnIds!.single.id, 17);
      expect(cart.cartList[2]!.addOnIds, isEmpty);
      expect(cart.cartList[2]!.variations![_milkGroup], [false, true]);
    });

    test('editing a line INTO another line\'s configuration merges them', () {
      final Product product = _americano();
      final CartProvider cart = _cart([
        _line(product: product, size: _large, milk: _regularMilk),
        _line(product: product, size: _small, milk: _regularMilk),
      ]);

      // Line 2 becomes Large: it is now line 1.
      final int at = cart.addToCart(
          _line(product: product, size: _large, milk: _regularMilk), 1,
          showMessage: false);

      expect(cart.cartList.length, 1);
      expect(cart.cartList[0]!.quantity, 2);
      expect(at, 0);
    });
  });

  group('AC6 — per-line pricing', () {
    test('the cart total is the sum of the line totals', () {
      final Product product = _americano();
      final CartProvider cart = _cart(const []);
      cart.addToCart(
          _line(
              product: product,
              size: _large,
              milk: _regularMilk,
              quantity: 2),
          kNewAdd,
          showMessage: false);
      cart.addToCart(
        _line(
          product: product,
          size: _small,
          milk: _coconutMilk,
          addOns: [AddOn(id: 17, quantity: 2)],
        ),
        kNewAdd,
        showMessage: false,
      );

      // 4.50*2 = 9.00, plus (3.50 + 0.50 coconut + 0.80*2 shots) = 5.60.
      double sum = 0;
      for (final CartModel? line in cart.cartList) {
        sum += kioskLineTotal(line!);
      }
      expect(kioskCartTotal(cart.cartList), closeTo(sum, 0.001));
      expect(kioskCartTotal(cart.cartList), closeTo(14.60, 0.001));
      expect(kioskCartItemCount(cart.cartList), 3);
    });
  });

  group('the signature is what separates the lines', () {
    test('size alone changes it', () {
      final Product product = _americano();
      expect(
        cartLineSignature(_line(product: product, size: _large, milk: _regularMilk)),
        isNot(cartLineSignature(
            _line(product: product, size: _small, milk: _regularMilk))),
      );
    });

    test('and an identical configuration keeps it', () {
      final Product product = _americano();
      expect(
        cartLineSignature(_line(product: product, size: _large, milk: _regularMilk)),
        cartLineSignature(
            _line(product: product, size: _large, milk: _regularMilk, quantity: 9)),
        reason: 'quantity is not part of a line\'s identity',
      );
    });
  });
}
