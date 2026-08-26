import 'dart:io';

import 'package:acafe_customer/features/kiosk/domain/kiosk_coupon_reward.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_coupon_applied_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders the coupon-applied confirmation to PNG so the layout can be
/// compared against the Figma frames by eye — `1385:15875` (the 10% artboard)
/// and `1385:15897` (the €5 one) — rather than only by assertion.
///
/// The images are a review aid as much as a guard. After a deliberate design
/// change — or a Flutter/font upgrade that shifts glyph rendering — regenerate
/// and look at the result:
///
///   flutter test --update-goldens test/features/kiosk/coupon_applied_golden_test.dart
///
/// Captured after the entrance has finished and before the hold expires, so the
/// frame is the settled design rather than a moment mid-animation.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    const families = <String, List<String>>{
      'Loew': [
        'assets/fonts/Loew-Regular.ttf',
        'assets/fonts/Loew-Medium.ttf',
        'assets/fonts/Loew-Bold.ttf',
        'assets/fonts/Loew-ExtraBold.ttf',
      ],
      'Swiss721': ['assets/fonts/Swiss721-Light.ttf'],
    };
    for (final family in families.entries) {
      final loader = FontLoader(family.key);
      for (final path in family.value) {
        loader.addFont(
          File(path).readAsBytes().then((b) => b.buffer.asByteData()),
        );
      }
      await loader.load();
    }
  });

  const rewards = <String, KioskCouponReward>{
    'percent': KioskCouponReward(
      kind: KioskCouponRewardKind.percent,
      headline: '10%',
      heading: 'Coupon applied!',
      message: 'Your discount has been applied to your order.',
      savings: 5,
    ),
    'amount': KioskCouponReward(
      kind: KioskCouponRewardKind.amount,
      headline: '€5',
      heading: 'Coupon applied!',
      message: 'Your discount has been applied to your order.',
      savings: 5,
    ),
  };

  for (final entry in rewards.entries) {
    testWidgets('coupon applied — ${entry.key}', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(home: KioskCouponAppliedScreen(reward: entry.value)),
      );
      await tester.pump(const Duration(milliseconds: 1300));

      await expectLater(
        find.byType(KioskCouponAppliedScreen),
        matchesGoldenFile('goldens/coupon_applied_${entry.key}_1080x1920.png'),
      );
    });
  }
}
