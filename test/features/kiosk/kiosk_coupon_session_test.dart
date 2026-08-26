import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/coupon/domain/models/coupon_model.dart';
import 'package:acafe_customer/features/coupon/providers/coupon_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_coupon_helper.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_session.dart';
import 'package:flutter_test/flutter_test.dart';

/// A previous customer's coupon must not ride into the next kiosk order.
/// CouponProvider is a DI singleton, so session-end has to wipe it even when
/// the checkout widget has already unmounted.
void main() {
  setUp(KioskSession.instance.reset);
  tearDown(KioskSession.instance.reset);

  CouponModel save10() => CouponModel(
        id: 1,
        title: 'Save 10',
        code: 'SAVE10',
        discount: 10,
        discountType: 'percent',
        minPurchase: 0,
        maxDiscount: 0,
      );

  test('a leftover code with no discount is not treated as applied', () {
    final coupon = _MutableCoupon()
      ..applied = save10()
      ..amountOff = 0
      ..typed = 'SAVE10';

    expect(kioskActiveCouponCode(coupon), isEmpty);
    expect(kioskOrderCouponCode(coupon), isNull);
  });

  test('only a coupon that is still taking money off is sent with the order',
      () {
    final coupon = _MutableCoupon()
      ..applied = save10()
      ..amountOff = 2
      ..typed = 'SAVE10';

    expect(kioskActiveCouponCode(coupon), 'SAVE10');
    expect(kioskOrderCouponCode(coupon), 'SAVE10');
  });

  test('ending the customer session drops the coupon without a mounted widget',
      () {
    final cart = _FakeCart();
    final coupon = _MutableCoupon()
      ..applied = save10()
      ..amountOff = 2
      ..typed = 'SAVE10';
    KioskSession.instance
      ..customerName = 'Alex'
      ..applyTip(10);

    endKioskCustomerSession(null, cart: cart, coupon: coupon);

    expect(cart.cleared, isTrue);
    expect(coupon.applied, isNull);
    expect(coupon.amountOff, 0);
    expect(coupon.typed, isEmpty);
    expect(KioskSession.instance.customerName, isEmpty);
    expect(KioskSession.instance.tipPercent, isNull);
  });

  test('removeCouponData wipes code, discount and selected index', () {
    final coupon = CouponProvider(couponRepo: null);
    coupon.removeCouponData(false);
    expect(coupon.coupon, isNull);
    expect(coupon.discount, 0);
    expect(coupon.code, isEmpty);
    expect(coupon.selectedCouponIndex, isNull);
  });
}

class _FakeCart extends CartProvider {
  _FakeCart() : super(cartRepo: null);

  bool cleared = false;

  @override
  void clearCartList() {
    cleared = true;
  }
}

class _MutableCoupon extends CouponProvider {
  _MutableCoupon() : super(couponRepo: null);

  CouponModel? applied;
  double amountOff = 0;
  String typed = '';

  @override
  CouponModel? get coupon => applied;

  @override
  double? get discount => amountOff;

  @override
  String? get code => typed;

  @override
  void removeCouponData(bool notify) {
    applied = null;
    amountOff = 0;
    typed = '';
    if (notify) notifyListeners();
  }
}
