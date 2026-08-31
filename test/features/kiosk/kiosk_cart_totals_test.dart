import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_cart_totals.dart';
import 'package:flutter_test/flutter_test.dart';

Product _product({
  required int id,
  double price = 10,
  List<AddOns>? addOns,
}) {
  return Product(
    id: id,
    name: 'Drink $id',
    price: price,
    image: '',
    addOns: addOns ?? const [],
  );
}

CartModel _line({
  required Product product,
  int quantity = 1,
  double? price,
  double? discountedPrice,
  List<AddOn>? addOnIds,
}) {
  final double unit = price ?? product.price ?? 0;
  final double payable = discountedPrice ?? unit;
  return CartModel(
    unit,
    payable,
    const [],
    unit - payable,
    quantity,
    0,
    addOnIds ?? const [],
    product,
    const [],
  );
}

void main() {
  group('kioskLineTotal with add-ons', () {
    final product = _product(
      id: 1,
      price: 10,
      addOns: [AddOns(id: 7, name: 'Caramel', price: 1.50)],
    );

    test('scales add-ons with quantity (same as deal lines)', () {
      final line = _line(
        product: product,
        quantity: 3,
        discountedPrice: 10,
        addOnIds: [AddOn(id: 7, quantity: 1)],
      );

      // (10 + 1.50) × 3 — not 10×3 + 1.50
      expect(kioskLineTotal(line), 34.50);
      expect(kioskLineOriginalTotal(line), 34.50);
    });

    test('unit price stays stable when quantity changes', () {
      final one = _line(
        product: product,
        quantity: 1,
        discountedPrice: 17.50,
        addOnIds: [AddOn(id: 7, quantity: 1)],
      );
      final many = _line(
        product: product,
        quantity: 21,
        discountedPrice: 17.50,
        addOnIds: [AddOn(id: 7, quantity: 1)],
      );

      expect(kioskLineUnitPrice(one), 19.00);
      expect(kioskLineUnitPrice(many), 19.00);
      expect(kioskLineTotal(many) / 21, kioskLineUnitPrice(many));
    });

    test('cart total grows by a full unit when qty increments', () {
      final at21 = _line(
        product: product,
        quantity: 21,
        discountedPrice: 17.50,
        addOnIds: [AddOn(id: 7, quantity: 1)],
      );
      final at22 = _line(
        product: product,
        quantity: 22,
        discountedPrice: 17.50,
        addOnIds: [AddOn(id: 7, quantity: 1)],
      );

      final delta =
          kioskCartTotal([at22]) - kioskCartTotal([at21]);
      expect(delta, kioskLineUnitPrice(at21));
      expect(delta, 19.00);
    });
  });

  group('lines without add-ons', () {
    test('match discounted price × qty', () {
      final product = _product(id: 2, price: 19.50);
      final line = _line(
        product: product,
        quantity: 2,
        price: 19.50,
        discountedPrice: 17.50,
      );

      expect(kioskLineTotal(line), 35.00);
      expect(kioskLineOriginalTotal(line), 39.00);
      expect(kioskLineUnitPrice(line), 17.50);
    });
  });

  group('one payable per line, everywhere it is shown', () {
    // The bug this guards: `discounted_price` was written from the product's
    // BASE price, so a +11.00 variation was missing from it. The menu cart bar
    // (sum of line totals) then quoted 104.00 while the cart screen's YOUR PAY
    // (items - discount + tax) quoted 115.00, and the cart line card struck
    // 111.00 through to advertise a discount the product does not have.
    final product = _product(id: 3, price: 100);

    test('an undiscounted line reads the same on the bar and in the summary',
        () {
      // Large +10.00, two milks at +0.50 — priced into `price` by the
      // customize screen.
      final line = _line(product: product, price: 111, discountedPrice: 111);

      expect(kioskLineTotal(line), 111);
      expect(kioskLineOriginalTotal(line), 111,
          reason: 'nothing to strike through: this product has no discount');
      expect(kioskCartTotal([line]), kioskGrandTotal([line]));
    });

    test('a genuinely discounted line strikes through its own list price', () {
      // 10% off 111.00.
      final line = _line(product: product, price: 111, discountedPrice: 99.90);

      expect(kioskLineTotal(line), closeTo(99.90, 0.001));
      expect(kioskLineOriginalTotal(line), 111);
      expect(kioskCartTotal([line]), closeTo(kioskGrandTotal([line]), 0.001));
    });

    test('a stored discount_amount cannot pull the two apart', () {
      // The shape an older build persisted: variations reached `price` but not
      // `discounted_price`, and `discount_amount` agreed with neither. The bar
      // and the summary must still quote one number for it.
      final stale = CartModel(
        111, // price, variations included
        100, // discounted_price, variations missing
        const [],
        0, // discount_amount, agreeing with neither
        1,
        0,
        const [],
        product,
        const [],
      );

      expect(kioskCartTotal([stale]), kioskGrandTotal([stale]));
    });
  });
}
