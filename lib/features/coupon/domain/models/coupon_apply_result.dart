import 'package:flutter/foundation.dart';

import 'package:acafe_customer/features/coupon/domain/models/coupon_model.dart';

/// Why an "apply coupon" attempt ended the way it did.
///
/// `applyCoupon` only ever returned a discount, so a code the backend rejected
/// and a valid code on a basket that is too small were indistinguishable — both
/// came back as `0.0` and the kiosk reported "Invalid code" for either. The
/// coupon screen needs to tell them apart to say something useful, so the
/// detailed call reports the outcome instead of collapsing it to a number.
enum CouponApplyStatus {
  /// The code is valid and a benefit is now attached to the order.
  applied,

  /// The code is valid, but the basket is below the coupon's `min_purchase`,
  /// so nothing was applied.
  belowMinPurchase,

  /// The backend rejected the code (unknown, expired, limit reached), or the
  /// request never got through.
  failed,
}

@immutable
class CouponApplyResult {
  final CouponApplyStatus status;

  /// The coupon the code resolved to — present for every status except
  /// [CouponApplyStatus.failed], where there is nothing to resolve.
  final CouponModel? coupon;

  /// Money taken off the order. Zero unless [status] is
  /// [CouponApplyStatus.applied]; can legitimately be zero *while* applied when
  /// the coupon's benefit is a free item rather than a discount.
  final double discount;

  /// The basket total this coupon needs, for [CouponApplyStatus.belowMinPurchase].
  final double minPurchase;

  /// What the backend said. Often a raw snake_case key (`coupon_not_found`,
  /// `coupon_limit_over`) because the API returns `translate(...)` output, so
  /// callers should run it back through their own lookup before showing it.
  final String? errorMessage;

  const CouponApplyResult({
    required this.status,
    this.coupon,
    this.discount = 0,
    this.minPurchase = 0,
    this.errorMessage,
  });

  const CouponApplyResult.applied({
    required CouponModel? coupon,
    required double discount,
  }) : this(
          status: CouponApplyStatus.applied,
          coupon: coupon,
          discount: discount,
        );

  const CouponApplyResult.belowMinPurchase({
    required CouponModel? coupon,
    required double minPurchase,
  }) : this(
          status: CouponApplyStatus.belowMinPurchase,
          coupon: coupon,
          minPurchase: minPurchase,
        );

  const CouponApplyResult.failed({String? message})
      : this(status: CouponApplyStatus.failed, errorMessage: message);

  bool get isApplied => status == CouponApplyStatus.applied;
}
