import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_combo_match.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_deal.dart';
import 'package:flutter_test/flutter_test.dart';

Product _product(int id, {double price = 5, String name = 'Item'}) =>
    Product(id: id, name: name, price: price, image: '');

CartModel _line({
  required Product product,
  int quantity = 1,
  double? price,
  double? discountedPrice,
  List<AddOn>? addOns,
}) {
  final double unit = price ?? product.price ?? 0;
  return CartModel(
    unit,
    discountedPrice ?? unit,
    const [],
    0,
    quantity,
    0,
    addOns ?? const [],
    product,
    const [],
  );
}

KioskDeal _deal({
  required int id,
  required List<KioskDealItem> items,
  required double bundlePrice,
  required double originalPrice,
  bool available = true,
}) {
  return KioskDeal(
    id: id,
    title: 'Combo $id',
    bundlePrice: bundlePrice,
    originalPrice: originalPrice,
    savings: originalPrice - bundlePrice,
    savingsPercent: originalPrice == 0
        ? 0
        : (((originalPrice - bundlePrice) / originalPrice) * 100).round(),
    available: available,
    items: items,
  );
}

void main() {
  final latte = _product(1, price: 5, name: 'Latte');
  final poffertjes = _product(2, price: 8, name: 'Poffertjes');
  final extra = _product(3, price: 4, name: 'Cookie');

  KioskDeal lattePoff({
    int id = 10,
    double bundle = 10,
    bool available = true,
  }) =>
      _deal(
        id: id,
        bundlePrice: bundle,
        originalPrice: 13,
        available: available,
        items: [
          KioskDealItem(quantity: 1, product: latte),
          KioskDealItem(quantity: 1, product: poffertjes),
        ],
      );

  test('exact cover produces a combo at the bundle price', () {
    final cart = [
      _line(product: latte),
      _line(product: poffertjes),
    ];
    final match = findKioskComboUpgrade(cart, [lattePoff()]);
    expect(match, isNotNull);
    expect(match!.deal.id, 10);
    expect(match.dealLine.isDeal, isTrue);
    expect(match.dealLine.dealId, 10);
    expect(match.dealLine.bundlePrice, 10);
    expect(match.consume, hasLength(2));
    expect(match.saving, closeTo(3, 0.001));
  });

  test('superset cover leaves extra quantity behind', () {
    final cart = [
      _line(product: latte, quantity: 2),
      _line(product: poffertjes),
    ];
    final match = findKioskComboUpgrade(cart, [lattePoff()]);
    expect(match, isNotNull);
    expect(match!.consume.singleWhere((c) => c.cartIndex == 0).quantity, 1);
    expect(match.consume.singleWhere((c) => c.cartIndex == 1).quantity, 1);
    expect(cart[0].quantity, 2, reason: 'matcher must not mutate the cart');
  });

  test('one product missing returns null', () {
    expect(
      findKioskComboUpgrade([_line(product: latte)], [lattePoff()]),
      isNull,
    );
  });

  test('lines already in a deal are never cannibalised', () {
    final existing = CartModel.deal(
      dealId: 99,
      title: 'Existing',
      bundlePrice: 10,
      originalPrice: 13,
      components: [_line(product: latte), _line(product: poffertjes)],
    );
    expect(findKioskComboUpgrade([existing], [lattePoff()]), isNull);
  });

  test('unavailable deals are skipped', () {
    final cart = [
      _line(product: latte),
      _line(product: poffertjes),
    ];
    expect(
      findKioskComboUpgrade(cart, [lattePoff(available: false)]),
      isNull,
    );
  });

  test('two matching deals: the higher saving wins', () {
    final cart = [
      _line(product: latte),
      _line(product: poffertjes),
    ];
    final cheap = lattePoff(id: 1, bundle: 12);
    final cheaper = lattePoff(id: 2, bundle: 9);
    final match = findKioskComboUpgrade(cart, [cheap, cheaper]);
    expect(match!.deal.id, 2);
    expect(match.saving, closeTo(4, 0.001));
  });

  test('tied savings keep deal-list order', () {
    final cart = [
      _line(product: latte),
      _line(product: poffertjes),
    ];
    final first = lattePoff(id: 1, bundle: 10);
    final second = lattePoff(id: 2, bundle: 10);
    expect(findKioskComboUpgrade(cart, [first, second])!.deal.id, 1);
  });

  test('component order follows deal.slots, not cart order', () {
    final cart = [
      _line(product: poffertjes),
      _line(product: latte),
    ];
    final match = findKioskComboUpgrade(cart, [lattePoff()]);
    final components = match!.dealLine.components!;
    expect(components.map((c) => c.product!.id), [1, 2]);
  });

  test('consumed line of qty 2 yields a qty-1 clone and leaves the original', () {
    final latteLine = _line(product: latte, quantity: 2);
    final cart = [latteLine, _line(product: poffertjes)];
    final match = findKioskComboUpgrade(cart, [lattePoff()]);
    expect(match, isNotNull);
    expect(latteLine.quantity, 2);
    expect(identical(match!.dealLine.components!.first, latteLine), isFalse);
    expect(match.dealLine.components!.first.quantity, 1);
    expect(match.dealLine.components!.first.product!.id, 1);
  });

  test('saving of zero or less is rejected', () {
    final cart = [
      _line(product: latte),
      _line(product: poffertjes),
    ];
    expect(findKioskComboUpgrade(cart, [lattePoff(bundle: 13)]), isNull);
    expect(findKioskComboUpgrade(cart, [lattePoff(bundle: 14)]), isNull);
  });

  test('a product with its own discount does not inflate the caption saving', () {
    // Latte is already €3 instead of €5, so the combo only saves €1 against
    // what the customer is actually paying — not the deal's advertised €3.
    final cart = [
      _line(product: latte, discountedPrice: 3),
      _line(product: poffertjes),
    ];
    final match = findKioskComboUpgrade(cart, [lattePoff(bundle: 10)]);
    expect(match, isNotNull);
    expect(match!.saving, closeTo(1, 0.001));
  });

  test('null product ids and unrelated extra items do not break a match', () {
    final noId = Product(name: 'Ghost', price: 1);
    final cart = [
      _line(product: extra),
      _line(product: latte),
      CartModel(1, 1, const [], 0, 1, 0, const [], noId, const []),
      _line(product: poffertjes),
    ];
    final match = findKioskComboUpgrade(cart, [lattePoff()]);
    expect(match, isNotNull);
    expect(match!.consume.map((c) => c.cartIndex), [1, 3]);
  });
}
