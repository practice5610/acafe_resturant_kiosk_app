import 'package:acafe_customer/common/models/place_order_body.dart';
import 'package:flutter_test/flutter_test.dart';

/// A POS split is placed with its first payment. `split_payment: true` makes
/// the backend start it part-paid, so admin lists it only once fully paid.
void main() {
  PlaceOrderBody body({bool? split}) {
    const List<Cart> cart = [];
    return split == null
        ? PlaceOrderBody(
            cart: cart,
            couponDiscountAmount: 0,
            couponDiscountTitle: null,
            couponCode: null,
            orderAmount: 19,
            deliveryAddressId: 0,
            orderType: 'pos',
            paymentMethod: 'cash_on_delivery',
            branchId: 1,
            deliveryTime: 'now',
            deliveryDate: '2026-10-20',
            orderNote: 'Kiosk order',
            distance: 0,
            isPartial: '0',
          )
        : PlaceOrderBody(
            cart: cart,
            couponDiscountAmount: 0,
            couponDiscountTitle: null,
            couponCode: null,
            orderAmount: 19,
            deliveryAddressId: 0,
            orderType: 'pos',
            paymentMethod: 'cash_on_delivery',
            branchId: 1,
            deliveryTime: 'now',
            deliveryDate: '2026-10-20',
            orderNote: 'Kiosk order',
            distance: 0,
            isPartial: '0',
            splitPayment: split,
          );
  }

  test('a split is flagged on the order post', () {
    expect(body(split: true).toJson()['split_payment'], isTrue);
  });

  test('every other sale posts exactly as before: no split_payment key', () {
    expect(body().toJson().containsKey('split_payment'), isFalse);
    expect(body(split: false).toJson().containsKey('split_payment'), isFalse);
  });
}
