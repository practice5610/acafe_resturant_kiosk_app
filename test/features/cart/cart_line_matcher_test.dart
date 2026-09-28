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

    test('matches identical deal lines by deal id and components', () {
      final espresso = _line(productId: 1);
      final croissant = _line(productId: 2);
      final dealA = CartModel.deal(
        dealId: 9,
        title: 'Special',
        bundlePrice: 12,
        originalPrice: 16,
        components: [espresso, croissant],
      );
      final dealB = CartModel.deal(
        dealId: 9,
        title: 'Special',
        bundlePrice: 12,
        originalPrice: 16,
        components: [_line(productId: 1), _line(productId: 2)],
      );
      expect(findMatchingCartLineIndex([dealA], dealB), 0);
    });

    test('does not match deals with different component options', () {
      final dealA = CartModel.deal(
        dealId: 9,
        title: 'Special',
        bundlePrice: 12,
        originalPrice: 16,
        components: [
          _line(productId: 1, variations: [
            [true, false],
          ]),
          _line(productId: 2),
        ],
      );
      final dealB = CartModel.deal(
        dealId: 9,
        title: 'Special',
        bundlePrice: 12,
        originalPrice: 16,
        components: [
          _line(productId: 1, variations: [
            [false, true],
          ]),
          _line(productId: 2),
        ],
      );
      expect(findMatchingCartLineIndex([dealA], dealB), -1);
    });
  });
  // The add / merge / split matrix, stated once against the matcher itself so a
  // failure points at the rule rather than at whichever screen tripped over it.
  group('add / merge / split matrix', () {
    List<List<bool?>> milk(int index) => [
          [index == 0, index == 1],
        ];

    test('same product, same everything => merge', () {
      final cart = [_line(productId: 1, variations: milk(0))];
      expect(
          findMatchingCartLineIndex(cart, _line(productId: 1, variations: milk(0))),
          0);
    });

    test('same product, different variation => split', () {
      final cart = [_line(productId: 1, variations: milk(0))];
      expect(
          findMatchingCartLineIndex(cart, _line(productId: 1, variations: milk(1))),
          -1);
    });

    test('same product, extra add-on => split', () {
      final cart = [_line(productId: 1, variations: milk(0))];
      expect(
        findMatchingCartLineIndex(
          cart,
          _line(
            productId: 1,
            variations: milk(0),
            addOns: [AddOn(id: 7, quantity: 1)],
          ),
        ),
        -1,
      );
    });

    test('same add-on, different add-on quantity => split', () {
      final cart = [
        _line(productId: 1, addOns: [AddOn(id: 7, quantity: 1)]),
      ];
      expect(
        findMatchingCartLineIndex(
          cart,
          _line(productId: 1, addOns: [AddOn(id: 7, quantity: 2)]),
        ),
        -1,
      );
    });

    test('add-on order does not matter => merge', () {
      final cart = [
        _line(
          productId: 1,
          addOns: [AddOn(id: 9, quantity: 1), AddOn(id: 3, quantity: 2)],
        ),
      ];
      expect(
        findMatchingCartLineIndex(
          cart,
          _line(
            productId: 1,
            addOns: [AddOn(id: 3, quantity: 2), AddOn(id: 9, quantity: 1)],
          ),
        ),
        0,
      );
    });

    test('a line only merges with its own twin among several candidates', () {
      final cart = [
        _line(productId: 1, variations: milk(0)),
        _line(productId: 2),
        _line(productId: 1, variations: milk(1)),
      ];
      expect(
          findMatchingCartLineIndex(cart, _line(productId: 1, variations: milk(1))),
          2);
    });

    test('quantity is not part of identity => merge', () {
      final cart = [_line(productId: 1, quantity: 4)];
      expect(findMatchingCartLineIndex(cart, _line(productId: 1, quantity: 1)), 0);
    });
  });

  group('cartLineSignature', () {
    List<List<bool?>> milk(int index) => [
          [index == 0, index == 1],
        ];

    test('equal signatures exactly where the matcher merges', () {
      final pairs = <List<CartModel>>[
        // merge
        [_line(productId: 1), _line(productId: 1)],
        [
          _line(productId: 1, variations: milk(0)),
          _line(productId: 1, variations: milk(0)),
        ],
        [
          _line(productId: 1, addOns: [AddOn(id: 9, quantity: 1), AddOn(id: 3, quantity: 2)]),
          _line(productId: 1, addOns: [AddOn(id: 3, quantity: 2), AddOn(id: 9, quantity: 1)]),
        ],
        [_line(productId: 1, quantity: 5), _line(productId: 1, quantity: 1)],
        // split
        [_line(productId: 1), _line(productId: 2)],
        [
          _line(productId: 1, variations: milk(0)),
          _line(productId: 1, variations: milk(1)),
        ],
        [
          _line(productId: 1, addOns: [AddOn(id: 7, quantity: 1)]),
          _line(productId: 1, addOns: [AddOn(id: 7, quantity: 2)]),
        ],
        [
          _line(productId: 1, variations: milk(0)),
          _line(productId: 1, variations: const []),
        ],
      ];

      for (final pair in pairs) {
        final bool matched = cartLinesMatch(pair[0], pair[1]);
        final bool sameSignature =
            cartLineSignature(pair[0]) == cartLineSignature(pair[1]);
        expect(sameSignature, matched,
            reason: 'signature and matcher disagreed on '
                '${cartLineSignature(pair[0])} vs ${cartLineSignature(pair[1])}');
      }
    });

    test('records the variation grid shape, not just the ticks', () {
      // Same ticks (none), different shape: the matcher rejects these because
      // the product's variation groups changed underneath the cart.
      final a = _line(productId: 1, variations: const []);
      final b = _line(productId: 1, variations: [
        [false, false],
      ]);
      expect(cartLinesMatch(a, b), isFalse);
      expect(cartLineSignature(a), isNot(cartLineSignature(b)));
    });

    test('names the product and the picks it holds', () {
      final signature =
          cartLineSignature(_line(productId: 42, variations: milk(1), addOns: [
        AddOn(id: 17, quantity: 2),
      ]));
      expect(signature, contains('p:42'));
      expect(signature, contains('0.1'));
      expect(signature, contains('17x2'));
    });

    test('a deal signature carries the deal id and its components', () {
      final deal = CartModel.deal(
        dealId: 9,
        title: 'Special',
        bundlePrice: 12,
        originalPrice: 16,
        components: [_line(productId: 1), _line(productId: 2)],
      );
      final signature = cartLineSignature(deal);
      expect(signature, startsWith('deal:9['));
      expect(signature, contains('p:1'));
      expect(signature, contains('p:2'));
      expect(signature, isNot(cartLineSignature(_line(productId: 1))));
    });
  });
}
