import 'package:flutter/foundation.dart';

import 'package:acafe_customer/features/coupon/domain/models/coupon_model.dart';

/// What the customer is actually being given.
enum KioskCouponRewardKind {
  /// A percentage off the order — the banner shows the rate ("10%").
  percent,

  /// A fixed sum off the order — the banner shows the money ("€5").
  amount,

  /// A perk that takes no money off: a free product or an upgrade. The banner
  /// shows "FREE" and the coupon's own title names the item.
  freeItem,
}

/// The benefit a validated coupon grants, resolved into the exact strings the
/// confirmation screen paints (Figma POS nodes 1385:15875 / 1385:15897).
///
/// Resolving here rather than inside the screen keeps
/// [KioskCouponAppliedScreen] a pure renderer — it holds no provider, no
/// currency config and no translation lookup — so the screen can be rendered in
/// a widget test and this mapping can be unit tested on its own.
///
/// ## How the three kinds are told apart
/// `coupons` stores `discount_type` (`percent` | `amount`) and a `discount`;
/// there is no free-product coupon type in the schema. So the rule is: a coupon
/// that takes **no money** off is a perk — its benefit is whatever its title
/// names ("Free croissant", "Size upgrade") — and anything else shows its
/// money. Nothing is guessed from the wording of the title.
@immutable
class KioskCouponReward {
  final KioskCouponRewardKind kind;

  /// The big value in the green banner: "10%", "€5", "FREE".
  final String headline;

  /// "Coupon applied!"
  final String heading;

  /// The line under the heading.
  final String message;

  /// Money off the order, in currency. Zero for a [KioskCouponRewardKind.freeItem].
  final double savings;

  const KioskCouponReward({
    required this.kind,
    required this.headline,
    required this.heading,
    required this.message,
    this.savings = 0,
  });

  /// Maps an applied [coupon] and the [discount] it produced onto the screen's
  /// copy.
  ///
  /// [formatPrice] and [translate] are injected so this stays free of
  /// `PriceConverterHelper`'s provider lookup and of the localization delegate:
  /// the screen passes the real ones, tests pass fakes.
  factory KioskCouponReward.resolve({
    required CouponModel? coupon,
    required double discount,
    required double orderAmount,
    required String Function(double amount) formatPrice,
    required String Function(String key, String fallback) translate,
  }) {
    final String heading = translate('coupon_applied', 'Coupon applied!');
    final String applied = translate(
      'your_discount_has_been_applied_to_your_order',
      'Your discount has been applied to your order.',
    );

    // No money off: the benefit is the item the coupon names.
    if (discount <= 0) {
      final String title = coupon?.title?.trim() ?? '';
      return KioskCouponReward(
        kind: KioskCouponRewardKind.freeItem,
        // Its own key rather than the app-wide `free`, which is still English
        // in every language file and is shared with price labels.
        headline: translate('coupon_free_reward', 'Free').toUpperCase(),
        heading: heading,
        message: title.isNotEmpty
            ? title
            : translate(
                'your_reward_has_been_added_to_your_order',
                'Your reward has been added to your order.',
              ),
      );
    }

    final double rate = coupon?.discount ?? 0;
    if (coupon?.discountType == 'percent' && rate > 0) {
      // `max_discount` can cap a percentage below its headline rate. When it
      // does, the subtitle names the money instead, so the banner never
      // promises more than the till will take off.
      final bool capped = (rate / 100) * orderAmount > discount + 0.005;
      return KioskCouponReward(
        kind: KioskCouponRewardKind.percent,
        headline: '${_trimZeros(rate)}%',
        heading: heading,
        message: capped
            ? '${translate('you_save', 'You save')} ${formatPrice(discount)}'
            : applied,
        savings: discount,
      );
    }

    return KioskCouponReward(
      kind: KioskCouponRewardKind.amount,
      headline: _trimWholeDecimals(formatPrice(discount), discount),
      heading: heading,
      message: applied,
      savings: discount,
    );
  }

  /// 10.0 -> "10", 12.5 -> "12.5". The rate is stored as a decimal, and
  /// "10.0%" in 256px type reads as a mistake.
  static String _trimZeros(double value) {
    final String text = value.toStringAsFixed(2);
    return text
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  /// "€5.00" -> "€5", matching the design's clean headline, but only for a
  /// whole amount: "€5.50" keeps its cents. The lookahead makes this safe for
  /// both separator conventions — in "1.000,00 €" only the trailing ",00" has
  /// no digits after it.
  static String _trimWholeDecimals(String formatted, double value) {
    if (value != value.roundToDouble()) return formatted;
    return formatted.replaceFirst(RegExp(r'[.,]0+(?=[^\d]*$)'), '');
  }
}

/// The order-summary row label for an applied coupon — Figma POS node
/// 1385:15938 draws it as plain "DISCOUNT", and the brief asks for the coupon
/// to be named on it, so it becomes "DISCOUNT · SUMMER SALE".
///
/// Prefers the coupon's title (the offer name a customer can recognise) and
/// falls back to the code they typed; with neither, the row is just the
/// discount word, exactly as the artboard draws it.
String kioskCouponRowLabel({
  required String discountLabel,
  String? title,
  String? code,
}) {
  final String name = (title?.trim().isNotEmpty ?? false)
      ? title!.trim()
      : (code?.trim() ?? '');
  final String label = discountLabel.trim().toUpperCase();
  if (name.isEmpty) return label;
  return '$label · ${name.toUpperCase()}';
}
