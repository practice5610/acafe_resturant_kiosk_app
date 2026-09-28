// AC6 — the order payload carries one entry per cart LINE.
//
// SCOPE NOTE. The function that maps a cart line to a payload entry
// (`_kioskOrderCartFromLine` in `kiosk_place_order.dart`) is private, and that
// file is explicitly out of scope for this phase — no payload code changed, and
// Phase 1 verified by reading that it already reads `variations`, `addOnIds` and
// `quantity` off the line it is handed. So these tests cover the two things
// that are reachable and that the feature could actually break:
//
//   1. Two lines of one product hold INDEPENDENT variation grids and add-on
//      lists. Aliasing here is the one way the new split-line cart could feed
//      the (unchanged) builder the same modifiers twice.
//   2. The request contract can express two entries with the same `product_id`
//      and different modifiers — the blocker Phase 1 went looking for and did
//      not find.
//
// Direct coverage of the builder needs `_kioskOrderCartFromLine` exposed with
// `@visibleForTesting`, which is a one-line change to a file this phase may not
// touch. Flagged for Step 6.

import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/models/place_order_body.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/cart/domain/reposotories/cart_repo.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCartRepo extends CartRepo {
  _FakeCartRepo() : super(sharedPreferences: null);
  @override
  void addToCartList(List<CartModel?> cartProductList) {}
}

const int _kAmericanoId = 42;

Product _americano() => Product(
      id: _kAmericanoId,
      name: 'Americano',
      price: 3.50,
      variations: [
        Variation(
          name: 'Milk',
          isMultiSelect: false,
          isRequired: true,
          min: 1,
          max: 1,
          variationValues: [
            VariationValue(level: 'Regular Milk', optionPrice: 0),
            VariationValue(level: 'Coconut Milk', optionPrice: 0.50),
          ],
        ),
      ],
      addOns: [
        AddOns(id: 17, name: 'Extra Shot', price: 0.80),
        AddOns(id: 18, name: 'Vanilla Syrup', price: 0.60),
      ],
    );

CartModel _line({
  required Product product,
  required int milk,
  List<AddOn>? addOns,
  int quantity = 1,
}) {
  final double unit = (product.price ?? 0) + (milk == 1 ? 0.50 : 0);
  return CartModel(
    unit,
    unit,
    const [],
    0,
    quantity,
    0.29,
    addOns ?? const [],
    product,
    [
      [milk == 0, milk == 1],
    ],
  );
}

/// The label of every variation value this line ticked, group by group — the
/// same reads `_kioskOrderCartFromLine` performs to build `variations`.
List<String> _pickedLabels(CartModel line) {
  final List<String> labels = [];
  final List<Variation> groups = line.product?.variations ?? const [];
  final List<List<bool?>> picked = line.variations ?? const [];
  for (int i = 0; i < groups.length && i < picked.length; i++) {
    final List<VariationValue> values = groups[i].variationValues ?? const [];
    for (int j = 0; j < values.length && j < picked[i].length; j++) {
      if (picked[i][j] == true) labels.add(values[j].level ?? '');
    }
  }
  return labels;
}

void main() {
  group('AC6 — each line is its own payload entry', () {
    test('two lines of one product keep separate modifiers on the cart', () {
      final Product product = _americano();
      final CartProvider cart = CartProvider(cartRepo: _FakeCartRepo());

      cart.addToCart(_line(product: product, milk: 0), -1, showMessage: false);
      cart.addToCart(
        _line(
          product: product,
          milk: 1,
          addOns: [AddOn(id: 17, quantity: 2), AddOn(id: 18, quantity: 1)],
        ),
        -1,
        showMessage: false,
      );

      expect(cart.cartList.length, 2);
      final CartModel a = cart.cartList[0]!;
      final CartModel b = cart.cartList[1]!;

      // Same product id on both — which is exactly the case the payload has to
      // survive.
      expect(a.product!.id, _kAmericanoId);
      expect(b.product!.id, _kAmericanoId);

      expect(_pickedLabels(a), ['Regular Milk']);
      expect(_pickedLabels(b), ['Coconut Milk']);

      expect(a.addOnIds, isEmpty);
      expect(b.addOnIds!.map((x) => x.id).toList(), [17, 18]);
      expect(b.addOnIds!.map((x) => x.quantity).toList(), [2, 1]);

      // Independent objects, not two views of one list. This is what would
      // silently send the same modifiers twice.
      expect(identical(a.variations, b.variations), isFalse);
      expect(identical(a.addOnIds, b.addOnIds), isFalse);
      expect(a.lineId, isNot(b.lineId));
    });

    test('editing one line does not rewrite the other line’s modifiers', () {
      final Product product = _americano();
      final CartProvider cart = CartProvider(cartRepo: _FakeCartRepo());

      cart.addToCart(_line(product: product, milk: 0), -1, showMessage: false);
      cart.addToCart(_line(product: product, milk: 1), -1, showMessage: false);

      // Line 2 gains a shot. Line 1 must be untouched.
      cart.addToCart(
        _line(
          product: product,
          milk: 1,
          addOns: [AddOn(id: 17, quantity: 1)],
        ),
        1,
        showMessage: false,
      );

      expect(cart.cartList.length, 2);
      expect(_pickedLabels(cart.cartList[0]!), ['Regular Milk']);
      expect(cart.cartList[0]!.addOnIds, isEmpty);
      expect(_pickedLabels(cart.cartList[1]!), ['Coconut Milk']);
      expect(cart.cartList[1]!.addOnIds!.single.id, 17);
    });

    test('the request body carries both entries under one product_id', () {
      final Product product = _americano();
      final CartModel regular = _line(product: product, milk: 0, quantity: 1);
      final CartModel coconut = _line(
        product: product,
        milk: 1,
        quantity: 2,
        addOns: [AddOn(id: 17, quantity: 2)],
      );

      Cart entry(CartModel line) => Cart(
            line.product!.id.toString(),
            line.discountedPrice.toString(),
            const [],
            [
              OrderVariation(
                name: 'Milk',
                values: OrderVariationValue(label: _pickedLabels(line)),
              ),
            ],
            line.discountAmount,
            line.quantity,
            line.taxAmount,
            (line.addOnIds ?? const []).map((a) => a.id).toList(),
            (line.addOnIds ?? const []).map((a) => a.quantity).toList(),
          );

      final Map<String, dynamic> body = PlaceOrderBody(
        cart: [entry(regular), entry(coconut)],
        couponDiscountAmount: 0,
        couponDiscountTitle: null,
        couponCode: null,
        orderNote: '',
        orderAmount: 11.50,
        deliveryAddressId: 0,
        orderType: 'pos',
        paymentMethod: 'cash_on_delivery',
        branchId: 1,
        deliveryTime: 'now',
        deliveryDate: '2026-09-26',
        distance: 0,
        isPartial: '0',
        isCutleryRequired: '0',
      ).toJson();

      final List<dynamic> entries = body['cart'] as List<dynamic>;
      expect(entries.length, 2, reason: 'one entry per line, never per product');

      final Map<String, dynamic> first = entries[0] as Map<String, dynamic>;
      final Map<String, dynamic> second = entries[1] as Map<String, dynamic>;

      expect(first['product_id'], '42');
      expect(second['product_id'], '42');
      expect(first['product_id'], second['product_id'],
          reason: 'the contract must tolerate a repeated product id');

      expect(first['quantity'], 1);
      expect(second['quantity'], 2);

      expect(first['add_on_ids'], isEmpty);
      expect(second['add_on_ids'], [17]);
      expect(second['add_on_qtys'], [2]);

      expect(
        (first['variations'] as List).first['values']['label'],
        ['Regular Milk'],
      );
      expect(
        (second['variations'] as List).first['values']['label'],
        ['Coconut Milk'],
      );

      // Each entry prices its own configuration.
      expect(first['price'], '3.5');
      expect(second['price'], '4.0');
    });
  });
}
