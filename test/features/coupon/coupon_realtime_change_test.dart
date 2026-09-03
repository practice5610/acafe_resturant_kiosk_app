import 'package:acafe_customer/features/coupon/domain/models/coupon_model.dart';
import 'package:acafe_customer/features/coupon/providers/coupon_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CouponProvider.applyRealtimeChange', () {
    late CouponProvider provider;

    setUp(() => provider = CouponProvider(couponRepo: null));

    test('does nothing when no coupon is applied', () {
      expect(provider.applyRealtimeChange(5), isFalse);
      expect(provider.coupon, isNull);
    });

    test('ignores a change to a different coupon', () {
      provider.debugSetAppliedCoupon(CouponModel(id: 1, code: 'A'), 3);
      expect(provider.applyRealtimeChange(2), isFalse);
      expect(provider.coupon?.id, 1);
      expect(provider.discount, 3);
    });

    test('drops the applied coupon when that coupon changes', () {
      provider.debugSetAppliedCoupon(CouponModel(id: 9, code: 'SUMMER'), 4);
      expect(provider.applyRealtimeChange(9), isTrue);
      expect(provider.coupon, isNull,
          reason: 'a discount head office just changed or revoked must not '
              'ride into checkout');
      expect(provider.discount, 0.0);
    });

    test('ignores a nonsense id', () {
      provider.debugSetAppliedCoupon(CouponModel(id: 9, code: 'SUMMER'), 4);
      expect(provider.applyRealtimeChange(0), isFalse);
      expect(provider.coupon?.id, 9);
    });
  });
}
