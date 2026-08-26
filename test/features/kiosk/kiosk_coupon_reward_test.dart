import 'dart:convert';
import 'dart:io';

import 'package:acafe_customer/common/models/api_response_model.dart';
import 'package:acafe_customer/features/coupon/domain/models/coupon_model.dart';
import 'package:acafe_customer/features/coupon/providers/coupon_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_coupon_reward.dart';
import 'package:flutter_test/flutter_test.dart';

/// The mapping from "the backend accepted this code" to the words and the
/// number the customer reads on the confirmation (Figma POS nodes 1385:15875 /
/// 1385:15897). Pure, because the screen is handed the finished strings.
void main() {
  // Stand-ins for the app's currency formatting and translation lookup, so
  // these tests need neither SplashProvider's config nor a localization
  // delegate. `€` on the left is the kiosk's own configuration.
  String euros(double value) => '€${value.toStringAsFixed(2)}';
  String fallback(String key, String fallbackText) => fallbackText;

  KioskCouponReward resolve({
    required CouponModel? coupon,
    required double discount,
    double orderAmount = 50,
    String Function(double)? formatPrice,
  }) =>
      KioskCouponReward.resolve(
        coupon: coupon,
        discount: discount,
        orderAmount: orderAmount,
        formatPrice: formatPrice ?? euros,
        translate: fallback,
      );

  CouponModel coupon({
    String? title,
    String discountType = 'percent',
    double discount = 10,
    double maxDiscount = 0,
  }) =>
      CouponModel(
        id: 1,
        title: title,
        code: 'A81739266',
        discount: discount,
        discountType: discountType,
        maxDiscount: maxDiscount,
        minPurchase: 0,
      );

  group('percentage coupons', () {
    test('lead with the rate, not the money', () {
      final reward = resolve(coupon: coupon(discount: 10), discount: 5);

      expect(reward.kind, KioskCouponRewardKind.percent);
      expect(reward.headline, '10%');
      expect(reward.heading, 'Coupon applied!');
      expect(reward.message, 'Your discount has been applied to your order.');
      expect(reward.savings, 5);
    });

    test('drop the stored decimal but keep a real fraction', () {
      expect(resolve(coupon: coupon(discount: 10), discount: 5).headline, '10%');
      expect(
        resolve(coupon: coupon(discount: 12.5), discount: 6.25).headline,
        '12.5%',
      );
    });

    test('name the money when max_discount caps the rate', () {
      // 10% of €50 is €5, but the coupon caps at €2 — promising "10%" alone
      // would overstate what the till takes off.
      final reward = resolve(
        coupon: coupon(discount: 10, maxDiscount: 2),
        discount: 2,
      );

      expect(reward.headline, '10%');
      expect(reward.message, 'You save €2.00');
    });
  });

  group('fixed-amount coupons', () {
    test('show the money, with a whole amount left clean', () {
      final reward = resolve(
        coupon: coupon(discountType: 'amount', discount: 5),
        discount: 5,
      );

      expect(reward.kind, KioskCouponRewardKind.amount);
      expect(reward.headline, '€5');
      expect(reward.savings, 5);
    });

    test('keep the cents when there are any', () {
      final reward = resolve(
        coupon: coupon(discountType: 'amount', discount: 5.5),
        discount: 5.5,
      );

      expect(reward.headline, '€5.50');
    });

    test('trim only the trailing zeros of a right-positioned currency', () {
      final reward = resolve(
        coupon: coupon(discountType: 'amount', discount: 1000),
        discount: 1000,
        formatPrice: (value) =>
            '${value.toStringAsFixed(2).replaceAll('.', ',')} €'
                .replaceFirst('1000', '1.000'),
      );

      expect(reward.headline, '1.000 €',
          reason: 'the thousands separator is not a decimal point');
    });
  });

  group('coupons that take no money off', () {
    test('are shown as the free item they name', () {
      final reward = resolve(
        coupon: coupon(discountType: 'amount', discount: 0, title: 'Free croissant'),
        discount: 0,
      );

      expect(reward.kind, KioskCouponRewardKind.freeItem);
      expect(reward.headline, 'FREE');
      expect(reward.message, 'Free croissant');
      expect(reward.savings, 0);
    });

    test('fall back to generic copy when the coupon has no title', () {
      final reward = resolve(
        coupon: coupon(discountType: 'amount', discount: 0, title: '  '),
        discount: 0,
      );

      expect(reward.headline, 'FREE');
      expect(reward.message, 'Your reward has been added to your order.');
    });
  });

  group('backend rejection messages', () {
    test('are read out of the error envelope ApiErrorHandler builds', () {
      final message = CouponProvider.couponErrorMessage(
        ApiResponseModel.withError({
          'errors': [
            {'code': 'coupon', 'message': 'coupon_limit_over'}
          ]
        }),
      );

      expect(message, 'coupon_limit_over');
    });

    test('fall back to a transport failure string', () {
      expect(
        CouponProvider.couponErrorMessage(
          ApiResponseModel.withError('Connection failed'),
        ),
        'Connection failed',
      );
      expect(
        CouponProvider.couponErrorMessage(ApiResponseModel.withError('  ')),
        isNull,
      );
    });
  });

  test('every string the confirmation asks for exists in all four languages',
      () {
    const keys = [
      'coupon_applied',
      'your_discount_has_been_applied_to_your_order',
      'your_reward_has_been_added_to_your_order',
      'coupon_free_reward',
      'you_save',
      'minimum_purchase_amount_is',
      'coupon_not_found',
      'coupon_limit_over',
    ];
    for (final code in const ['en', 'de', 'fr', 'nl']) {
      final values = json.decode(
        File('assets/language/$code.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      for (final key in keys) {
        expect(values[key], isNotNull, reason: '$key missing from $code.json');
        expect('${values[key]}'.trim(), isNotEmpty,
            reason: '$key empty in $code.json');
      }
    }
  });
}
