// Repeated products get their own cart line.
//
// The cart is a LIST OF CONFIGURATIONS, not a set of products. These tests pin
// the rules that make that true: an add either stacks onto a line with the same
// configuration signature or starts a new one, an edit can fold a line back
// into its twin, and quantity controls touch exactly the line they were tapped
// on. They are the regression net for the bug where a second Americano
// overwrote the first.
//
// Most of this runs without a widget tree: `addToCart(..., showMessage: false)`
// skips the snackbar (which needs `Get.context`), and `_FakeCartRepo` stands in
// for the SharedPreferences write. The `onUpdateCartQuantity` group does need a
// tree — it reads `ProductProvider` off `Get.context` for the stock check.

import 'dart:convert';

import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/common/providers/product_provider.dart';
import 'package:acafe_customer/features/cart/domain/cart_line_matcher.dart';
import 'package:acafe_customer/features/cart/domain/reposotories/cart_repo.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_cart_totals.dart';
import 'package:acafe_customer/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Swallows the persistence write. The real [CartRepo.addToCartList] reaches
/// for `Get.context!` to resolve the branch-scoped key, which a unit test has
/// no way to provide.
class _FakeCartRepo extends CartRepo {
  _FakeCartRepo() : super(sharedPreferences: null);

  /// Every list handed to the repo, so a test can assert what was persisted.
  final List<List<CartModel?>> writes = [];

  @override
  void addToCartList(List<CartModel?> cartProductList) {
    writes.add(List<CartModel?>.from(cartProductList));
  }
}

/// Serves a pre-baked stored cart, so restore can be exercised without
/// SharedPreferences or a BranchProvider.
class _RestoreCartRepo extends CartRepo {
  _RestoreCartRepo(this.storedJson) : super(sharedPreferences: null);

  final List<String> storedJson;

  @override
  List<CartModel> getCartList(BuildContext context) => storedJson
      .map((s) => CartModel.fromJson(jsonDecode(s) as Map<String, dynamic>))
      .toList();

  @override
  void addToCartList(List<CartModel?> cartProductList) {}
}

const int _kAmericanoId = 42;

/// Americano: one variation group (Milk: Regular / Coconut) and one paid add-on.
Product _americano({
  int? stock,
  int soldQuantity = 0,
  String stockType = 'unlimited',
}) {
  return Product(
    id: _kAmericanoId,
    name: 'Americano',
    price: 3.50,
    variations: [
      Variation(
        name: 'Milk',
        // `Variation.toJson` dereferences both of these, so a fixture that
        // leaves them null cannot survive a persistence round-trip.
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
    addOns: [AddOns(id: 17, name: 'Extra Shot', price: 0.80)],
    branchProduct: BranchProduct(
      stock: stock,
      soldQuantity: soldQuantity,
      stockType: stockType,
    ),
  );
}

/// Which milk index this line picked. `null` picks nothing.
List<List<bool?>> _milk(int? index) => [
      [index == 0, index == 1],
    ];

/// A line as `buildKioskCartModel` would produce it: `price` already carries
/// the chosen variation, `discountedPrice` equals it (no product discount).
CartModel _line({
  required Product product,
  int? milk,
  List<AddOn>? addOns,
  int quantity = 1,
  String? instruction,
}) {
  final double variationPrice = milk == 1 ? 0.50 : 0;
  final double unit = (product.price ?? 0) + variationPrice;
  return CartModel(
    unit,
    unit,
    const [],
    0,
    quantity,
    0,
    addOns ?? const [],
    product,
    _milk(milk),
    instruction: instruction,
  );
}

CartProvider _cart(_FakeCartRepo repo, [List<CartModel?> seed = const []]) {
  final CartProvider cart = CartProvider(cartRepo: repo);
  if (seed.isNotEmpty) cart.replaceCartList(seed);
  return cart;
}

void main() {
  group('AC1 — different configurations become separate lines', () {
    test('two milks on the same product => two lines', () {
      final Product product = _americano();
      final CartProvider cart = _cart(_FakeCartRepo());

      cart.addToCart(_line(product: product, milk: 0), -1, showMessage: false);
      cart.addToCart(_line(product: product, milk: 1), -1, showMessage: false);

      expect(cart.cartList.length, 2);
      expect(cart.cartList[0]!.quantity, 1);
      expect(cart.cartList[1]!.quantity, 1);
      expect(cart.cartList[0]!.variations![0], [true, false]);
      expect(cart.cartList[1]!.variations![0], [false, true]);
      // Each line prices its own configuration: coconut costs 0.50 more.
      expect(kioskLineTotal(cart.cartList[0]!), closeTo(3.50, 0.001));
      expect(kioskLineTotal(cart.cartList[1]!), closeTo(4.00, 0.001));
    });

    test('same milk, different add-ons => two lines', () {
      final Product product = _americano();
      final CartProvider cart = _cart(_FakeCartRepo());

      cart.addToCart(_line(product: product, milk: 0), -1, showMessage: false);
      cart.addToCart(
        _line(product: product, milk: 0, addOns: [AddOn(id: 17, quantity: 1)]),
        -1,
        showMessage: false,
      );

      expect(cart.cartList.length, 2);
      expect(kioskLineTotal(cart.cartList[1]!), closeTo(4.30, 0.001));
    });

    test('same add-on at a different quantity => two lines', () {
      final Product product = _americano();
      final CartProvider cart = _cart(_FakeCartRepo());

      cart.addToCart(
        _line(product: product, milk: 0, addOns: [AddOn(id: 17, quantity: 1)]),
        -1,
        showMessage: false,
      );
      cart.addToCart(
        _line(product: product, milk: 0, addOns: [AddOn(id: 17, quantity: 2)]),
        -1,
        showMessage: false,
      );

      expect(cart.cartList.length, 2);
    });

    test('different instruction => two lines', () {
      final Product product = _americano();
      final CartProvider cart = _cart(_FakeCartRepo());

      cart.addToCart(_line(product: product, milk: 0, instruction: 'extra hot'),
          -1, showMessage: false);
      cart.addToCart(_line(product: product, milk: 0), -1, showMessage: false);

      expect(cart.cartList.length, 2);
    });

    test('addToCart returns the index of the new line', () {
      final Product product = _americano();
      final CartProvider cart = _cart(_FakeCartRepo());

      expect(
        cart.addToCart(_line(product: product, milk: 0), -1,
            showMessage: false),
        0,
      );
      expect(
        cart.addToCart(_line(product: product, milk: 1), -1,
            showMessage: false),
        1,
      );
    });
  });

  group('AC2 — the same configuration stacks', () {
    test('identical config twice => one line, qty 2', () {
      final Product product = _americano();
      final CartProvider cart = _cart(_FakeCartRepo());

      cart.addToCart(_line(product: product, milk: 0), -1, showMessage: false);
      final int second = cart.addToCart(
          _line(product: product, milk: 0), -1,
          showMessage: false);

      expect(cart.cartList.length, 1);
      expect(cart.cartList[0]!.quantity, 2);
      expect(second, 0, reason: 'stacked onto the existing line');
    });

    test('a null index stacks the same way -1 does', () {
      final Product product = _americano();
      final CartProvider cart = _cart(_FakeCartRepo());

      cart.addToCart(_line(product: product, milk: 0), null,
          showMessage: false);
      cart.addToCart(_line(product: product, milk: 0), null,
          showMessage: false);

      expect(cart.cartList.length, 1);
      expect(cart.cartList[0]!.quantity, 2);
    });

    test('adding a qty-2 line onto a qty-1 line sums to 3', () {
      final Product product = _americano();
      final CartProvider cart = _cart(_FakeCartRepo());

      cart.addToCart(_line(product: product, milk: 0), -1, showMessage: false);
      cart.addToCart(_line(product: product, milk: 0, quantity: 2), -1,
          showMessage: false);

      expect(cart.cartList.length, 1);
      expect(cart.cartList[0]!.quantity, 3);
    });
  });

  group('AC3 — an edit folds a line into its twin', () {
    test('editing line 2 to match line 1 merges into one qty-2 line', () {
      final Product product = _americano();
      final _FakeCartRepo repo = _FakeCartRepo();
      final CartProvider cart = _cart(repo, [
        _line(product: product, milk: 0),
        _line(product: product, milk: 1),
      ]);

      // Reopen line 2 and switch coconut -> regular.
      final int survivor = cart.addToCart(
        _line(product: product, milk: 0),
        1,
        showMessage: false,
      );

      expect(cart.cartList.length, 1);
      expect(cart.cartList[0]!.quantity, 2);
      expect(survivor, 0, reason: 'the returned index must name the survivor');
      expect(cart.cartList[0]!.variations![0], [true, false]);
      expect(repo.writes.last.length, 1, reason: 'the merge was persisted');
    });

    test('editing line 1 to match line 2 also merges, and reports the index',
        () {
      final Product product = _americano();
      final CartProvider cart = _cart(_FakeCartRepo(), [
        _line(product: product, milk: 0),
        _line(product: product, milk: 1),
      ]);

      // Line 1 becomes coconut: its twin sits AFTER it, so the surviving
      // index shifts down when the edited slot is removed.
      final int survivor =
          cart.addToCart(_line(product: product, milk: 1), 0,
              showMessage: false);

      expect(cart.cartList.length, 1);
      expect(cart.cartList[0]!.quantity, 2);
      expect(survivor, 0);
      expect(cart.cartList[0]!.variations![0], [false, true]);
    });

    test('an edit that matches nothing stays its own line', () {
      final Product product = _americano();
      final CartProvider cart = _cart(_FakeCartRepo(), [
        _line(product: product, milk: 0),
        _line(product: product, milk: 1),
      ]);

      final int at = cart.addToCart(
        _line(product: product, milk: 1, addOns: [AddOn(id: 17, quantity: 1)]),
        1,
        showMessage: false,
      );

      expect(cart.cartList.length, 2);
      expect(at, 1);
      expect(cart.cartList[1]!.addOnIds!.single.id, 17);
    });

    test('a merge sums quantities rather than replacing them', () {
      final Product product = _americano();
      final CartProvider cart = _cart(_FakeCartRepo(), [
        _line(product: product, milk: 0, quantity: 2),
        _line(product: product, milk: 1, quantity: 3),
      ]);

      cart.addToCart(_line(product: product, milk: 0, quantity: 3), 1,
          showMessage: false);

      expect(cart.cartList.length, 1);
      expect(cart.cartList[0]!.quantity, 5);
    });

    test('an out-of-range edit index is refused, not thrown', () {
      final Product product = _americano();
      final CartProvider cart =
          _cart(_FakeCartRepo(), [_line(product: product, milk: 0)]);

      expect(cart.addToCart(_line(product: product, milk: 1), 7,
              showMessage: false),
          -1);
      expect(cart.cartList.length, 1);
      expect(cart.cartList[0]!.variations![0], [true, false],
          reason: 'the surviving line was left alone');
    });
  });

  group('AC5 — the cart total is the sum of its lines', () {
    test('amount and kioskCartTotal agree across mixed configurations', () {
      final Product product = _americano();
      final CartProvider cart = _cart(_FakeCartRepo());

      cart.addToCart(_line(product: product, milk: 0, quantity: 2), -1,
          showMessage: false);
      cart.addToCart(
        _line(product: product, milk: 1, addOns: [AddOn(id: 17, quantity: 2)]),
        -1,
        showMessage: false,
      );

      // 3.50*2 = 7.00, then (3.50 + 0.50 coconut + 0.80*2 shots) = 5.60.
      expect(kioskCartTotal(cart.cartList), closeTo(12.60, 0.001));
      expect(kioskCartItemCount(cart.cartList), 3);
      // `amount` tracks the lines without add-ons; it must still equal the sum
      // of discountedPrice * qty over every line.
      expect(cart.amount, closeTo(3.50 * 2 + 4.00, 0.001));
    });

    test('a merge leaves amount equal to a full recompute', () {
      final Product product = _americano();
      final CartProvider cart = _cart(_FakeCartRepo(), [
        _line(product: product, milk: 0),
        _line(product: product, milk: 1),
      ]);

      cart.addToCart(_line(product: product, milk: 0), 1, showMessage: false);

      double expected = 0;
      for (final CartModel? line in cart.cartList) {
        expected += (line!.discountedPrice ?? 0) * (line.quantity ?? 1);
      }
      expect(cart.amount, closeTo(expected, 0.001));
      expect(cart.amount, closeTo(7.00, 0.001));
    });
  });

  group('lineId', () {
    test('every line gets a distinct id', () {
      final Product product = _americano();
      final CartModel a = _line(product: product, milk: 0);
      final CartModel b = _line(product: product, milk: 1);
      expect(a.lineId, isNot(b.lineId));
    });

    test('copyWithQuantity produces a new identity', () {
      final CartModel a = _line(product: _americano(), milk: 0, quantity: 2);
      expect(a.copyWithQuantity(1).lineId, isNot(a.lineId));
    });

    test('is absent from the persisted JSON', () {
      final Map<String, dynamic> json =
          _line(product: _americano(), milk: 0).toJson();
      expect(json.containsKey('line_id'), isFalse);
      expect(json.containsKey('lineId'), isFalse);
      expect(
        json.keys.toSet(),
        {
          'price',
          'discounted_price',
          'variation',
          'discount_amount',
          'quantity',
          'tax_amount',
          'add_on_ids',
          'product',
          'variations',
        },
        reason: 'the stored cart shape must not change',
      );
    });

    test('a stray persisted line_id is ignored on read', () {
      final Map<String, dynamic> json =
          _line(product: _americano(), milk: 0).toJson();
      json['line_id'] = 999;
      final CartModel restored = CartModel.fromJson(json);
      expect(restored.lineId, isNot(999));
    });

    testWidgets('getCartData stamps unique ids onto restored lines',
        (tester) async {
      final Product product = _americano();
      final String a = jsonEncode(_line(product: product, milk: 0).toJson());
      final String b = jsonEncode(_line(product: product, milk: 1).toJson());
      final CartProvider cart =
          CartProvider(cartRepo: _RestoreCartRepo([a, b, a]));

      late BuildContext ctx;
      await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      })));

      cart.getCartData(ctx);

      expect(cart.cartList.length, 3);
      final Set<int> ids =
          cart.cartList.map((line) => line!.lineId).toSet();
      expect(ids.length, 3, reason: 'restored lines must not share an id');
      // A restored cart keeps its lines apart — two of these are the same
      // configuration, which the restore must not collapse.
      expect(cart.cartList[0]!.variations![0], [true, false]);
      expect(cart.cartList[1]!.variations![0], [false, true]);
      expect(cart.amount, closeTo(3.50 + 4.00 + 3.50, 0.001));
    });
  });

  group('AC4 / D-4 — onUpdateCartQuantity touches one line', () {
    Future<CartProvider> pump(
      WidgetTester tester,
      List<CartModel?> seed,
    ) async {
      final CartProvider cart = _cart(_FakeCartRepo(), seed);
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<CartProvider>.value(value: cart),
          ChangeNotifierProvider<ProductProvider>(
              create: (_) => ProductProvider(productRepo: null)),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          home: const Scaffold(body: SizedBox()),
        ),
      ));
      return cart;
    }

    testWidgets('"+" on line 1 leaves line 2 alone', (tester) async {
      final Product product = _americano();
      final CartProvider cart = await pump(tester, [
        _line(product: product, milk: 0),
        _line(product: product, milk: 1),
      ]);

      cart.onUpdateCartQuantity(index: 0, product: product, isRemove: false);
      await tester.pump();

      expect(cart.cartList[0]!.quantity, 1 + 1);
      expect(cart.cartList[1]!.quantity, 1,
          reason: 'the sibling line must not move');
      expect(cart.cartList.length, 2);
    });

    testWidgets('"+" writes the line quantity, never the product total',
        (tester) async {
      final Product product = _americano();
      final CartProvider cart = await pump(tester, [
        _line(product: product, milk: 0, quantity: 4),
        _line(product: product, milk: 1, quantity: 6),
      ]);

      cart.onUpdateCartQuantity(index: 0, product: product, isRemove: false);
      await tester.pump();

      // The old code wrote getCartProductQuantityCount + 1 == 11 here.
      expect(cart.cartList[0]!.quantity, 5);
      expect(cart.cartList[1]!.quantity, 6);
    });

    testWidgets('"−" on line 2 leaves line 1 alone', (tester) async {
      final Product product = _americano();
      final CartProvider cart = await pump(tester, [
        _line(product: product, milk: 0, quantity: 3),
        _line(product: product, milk: 1, quantity: 2),
      ]);

      cart.onUpdateCartQuantity(index: 1, product: product, isRemove: true);
      await tester.pump();

      expect(cart.cartList[0]!.quantity, 3);
      expect(cart.cartList[1]!.quantity, 1);
    });

    testWidgets('"−" on the last unit removes only that line', (tester) async {
      final Product product = _americano();
      final CartProvider cart = await pump(tester, [
        _line(product: product, milk: 0, quantity: 2),
        _line(product: product, milk: 1),
      ]);

      cart.onUpdateCartQuantity(index: 1, product: product, isRemove: true);
      await tester.pump();

      expect(cart.cartList.length, 1);
      expect(cart.cartList[0]!.quantity, 2);
      expect(cart.cartList[0]!.variations![0], [true, false]);
    });

    testWidgets('a second line of the product no longer blocks the stepper',
        (tester) async {
      final Product product = _americano();
      final CartProvider cart = await pump(tester, [
        _line(product: product, milk: 0),
        _line(product: product, milk: 1),
        _line(product: product, milk: 0, addOns: [AddOn(id: 17, quantity: 1)]),
      ]);

      // Three lines of one product. The old `_isProductInCart` guard refused
      // outright at two.
      cart.onUpdateCartQuantity(index: 2, product: product, isRemove: false);
      await tester.pump();

      expect(cart.cartList[2]!.quantity, 2);
      expect(cart.cartList[0]!.quantity, 1);
      expect(cart.cartList[1]!.quantity, 1);
    });

    testWidgets('stock is counted across every line of the product',
        (tester) async {
      // 5 in stock, 0 sold. `ProductProvider.checkStock` refuses once
      // stock - requested hits zero, so this product tops out at 4 units in
      // the cart however they are configured. Two lines already hold 3.
      final Product product =
          _americano(stock: 5, soldQuantity: 0, stockType: 'daily');
      final CartProvider cart = await pump(tester, [
        _line(product: product, milk: 0, quantity: 2),
        _line(product: product, milk: 1, quantity: 1),
      ]);

      cart.onUpdateCartQuantity(index: 0, product: product, isRemove: false);
      await tester.pump();
      expect(cart.cartList[0]!.quantity, 3, reason: '4th unit is available');

      // Cart now holds 4. A 5th must be refused on EITHER line — this is the
      // oversell a per-line stock check would have allowed, since neither line
      // is anywhere near the limit on its own.
      cart.onUpdateCartQuantity(index: 1, product: product, isRemove: false);
      await tester.pump();
      expect(cart.cartList[1]!.quantity, 1, reason: 'blocked on the sibling');

      cart.onUpdateCartQuantity(index: 0, product: product, isRemove: false);
      await tester.pump();
      expect(cart.cartList[0]!.quantity, 3, reason: 'blocked on the same line');
    });

    testWidgets('a decrement is never blocked by stock', (tester) async {
      final Product product =
          _americano(stock: 1, soldQuantity: 5, stockType: 'daily');
      final CartProvider cart = await pump(tester, [
        _line(product: product, milk: 0, quantity: 2),
      ]);

      cart.onUpdateCartQuantity(index: 0, product: product, isRemove: true);
      await tester.pump();

      expect(cart.cartList[0]!.quantity, 1);
    });
  });

  // What `pos_product_customize_screen._addToCart` does now: a plain
  // `addToCart`, with no product-id collapse behind it. The old sequence edited
  // the last line of the product and then deleted its siblings, which is why a
  // second Americano overwrote the first.
  group('POS save sequence no longer collapses a product', () {
    test('a new POS add with no index becomes its own line', () {
      final Product product = _americano();
      final CartProvider cart = _cart(_FakeCartRepo(), [
        _line(product: product, milk: 0),
      ]);

      // -1 is what `productProvider.cartIndex` always yields, and it is now the
      // only thing a product-grid tap can pass.
      cart.addToCart(_line(product: product, milk: 1), -1, showMessage: false);

      expect(cart.cartList.length, 2);
      expect(cart.cartList[0]!.variations![0], [true, false]);
      expect(cart.cartList[1]!.variations![0], [false, true]);
    });

    test('several configurations of one product coexist on the receipt', () {
      final Product product = _americano();
      final CartProvider cart = _cart(_FakeCartRepo());

      cart.addToCart(_line(product: product, milk: 0), -1, showMessage: false);
      cart.addToCart(_line(product: product, milk: 1), -1, showMessage: false);
      cart.addToCart(
        _line(product: product, milk: 0, addOns: [AddOn(id: 17, quantity: 1)]),
        -1,
        showMessage: false,
      );

      expect(cart.cartList.length, 3);
      expect(cart.cartList.map((l) => l!.lineId).toSet().length, 3);
    });

    test('an explicit line edit still targets exactly that line', () {
      final Product product = _americano();
      final CartProvider cart = _cart(_FakeCartRepo(), [
        _line(product: product, milk: 0),
        _line(product: product, milk: 1),
        _line(product: product, milk: 0, addOns: [AddOn(id: 17, quantity: 1)]),
      ]);

      // Receipt-pane tap on line 2 -> add a shot. Nothing else moves.
      cart.addToCart(
        _line(product: product, milk: 1, addOns: [AddOn(id: 18, quantity: 1)]),
        1,
        showMessage: false,
      );

      expect(cart.cartList.length, 3);
      expect(cart.cartList[0]!.addOnIds, isEmpty);
      expect(cart.cartList[1]!.addOnIds!.single.id, 18);
      expect(cart.cartList[2]!.addOnIds!.single.id, 17);
    });
  });

  group('the matcher decides, not the product id', () {
    test('signature equality lines up with what the cart did', () {
      final Product product = _americano();
      final CartModel regular = _line(product: product, milk: 0);
      final CartModel coconut = _line(product: product, milk: 1);

      expect(cartLineSignature(regular), cartLineSignature(regular));
      expect(cartLineSignature(regular), isNot(cartLineSignature(coconut)));

      final CartProvider cart = _cart(_FakeCartRepo());
      cart.addToCart(regular, -1, showMessage: false);
      cart.addToCart(coconut, -1, showMessage: false);
      expect(cart.cartList.length, 2);
    });
  });
}
