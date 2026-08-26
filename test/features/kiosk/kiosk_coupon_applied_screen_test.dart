import 'dart:io';

import 'package:acafe_customer/features/kiosk/domain/kiosk_coupon_reward.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_coupon_applied_screen.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

/// The coupon-applied confirmation (Figma POS nodes 1385:15875 and
/// 1385:15897). The two artboards differ only in the value in the banner, so
/// the checks below are about the one screen carrying whichever reward it is
/// handed, on every viewport the kiosk ships on, and about never trapping the
/// customer on it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Real type, so text measurement matches what the kiosk renders.
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

  // Every string arrives resolved, which is exactly why no localization
  // delegate is needed here (see kiosk_coupon_reward_test for the mapping).
  const percentReward = KioskCouponReward(
    kind: KioskCouponRewardKind.percent,
    headline: '10%',
    heading: 'Coupon applied!',
    message: 'Your discount has been applied to your order.',
    savings: 5,
  );
  const amountReward = KioskCouponReward(
    kind: KioskCouponRewardKind.amount,
    headline: '€5',
    heading: 'Coupon applied!',
    message: 'Your discount has been applied to your order.',
    savings: 5,
  );
  const freeReward = KioskCouponReward(
    kind: KioskCouponRewardKind.freeItem,
    headline: 'FREE',
    heading: 'Coupon applied!',
    message: 'Free croissant',
  );

  Finder svgKey(String asset) => find.byWidgetPredicate(
        (w) =>
            w is SvgPicture &&
            w.bytesLoader is SvgAssetLoader &&
            (w.bytesLoader as SvgAssetLoader).assetName == asset,
      );

  Future<void> render(
    WidgetTester tester,
    Size size, {
    KioskCouponReward reward = percentReward,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: KioskCouponAppliedScreen(reward: reward)),
    );
    // Through the entrance, but well short of the hold.
    await tester.pump(const Duration(milliseconds: 1300));
  }

  const viewports = <String, Size>{
    'portrait kiosk': Size(1080, 1920),
    'resized browser window': Size(600, 1000),
    'short landscape display': Size(1500, 900),
    'large landscape display': Size(2560, 1440),
  };

  for (final entry in viewports.entries) {
    testWidgets('shows the reward on a ${entry.key}', (tester) async {
      await render(tester, entry.value);

      expect(tester.takeException(), isNull);
      expect(find.text('10%'), findsOneWidget);
      expect(find.text('Coupon applied!'), findsOneWidget);
      expect(
        find.text('Your discount has been applied to your order.'),
        findsOneWidget,
      );
      // Wordmark and the tick in the success badge.
      expect(svgKey(Images.kioskLogoWhiteSvg), findsOneWidget);
      expect(svgKey(Images.kioskCheckSvg), findsOneWidget);
    });
  }

  testWidgets('carries a fixed amount instead of a rate', (tester) async {
    await render(tester, const Size(1080, 1920), reward: amountReward);

    expect(find.text('€5'), findsOneWidget);
    expect(find.text('10%'), findsNothing);
  });

  testWidgets('names the free item a perk coupon grants', (tester) async {
    await render(tester, const Size(1080, 1920), reward: freeReward);

    expect(find.text('FREE'), findsOneWidget);
    expect(find.text('Free croissant'), findsOneWidget);
  });

  testWidgets('the reward is on screen before the entrance finishes',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: KioskCouponAppliedScreen(reward: percentReward)),
    );
    await tester.pump(const Duration(milliseconds: 700));

    // Built from frame one — the choreography only fades and lifts it, so a
    // customer glancing early still sees what they got.
    expect(find.text('10%'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 3000));
  });

  group('returning to the cart', () {
    Future<void> pushOnto(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context)
                      .push(KioskCouponAppliedScreen.route(percentReward)),
                  child: const Text('cart'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('cart'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('10%'), findsOneWidget);
    }

    testWidgets('a tap anywhere skips straight back', (tester) async {
      await pushOnto(tester);

      await tester.tapAt(const Offset(200, 200));
      await tester.pumpAndSettle();

      expect(find.text('10%'), findsNothing);
      expect(find.text('cart'), findsOneWidget);
    });

    testWidgets('it leaves on its own after the hold', (tester) async {
      await pushOnto(tester);

      // Still holding at the end of the entrance.
      await tester.pump(const Duration(milliseconds: 1300));
      expect(find.text('10%'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pumpAndSettle();

      expect(find.text('10%'), findsNothing);
      expect(find.text('cart'), findsOneWidget);
    });

    testWidgets('a tap during the hold does not pop twice', (tester) async {
      await pushOnto(tester);

      await tester.tapAt(const Offset(200, 200));
      await tester.pump(const Duration(milliseconds: 3000));
      await tester.pumpAndSettle();

      // The host is still there: the auto-timer did not pop it as well.
      expect(find.text('cart'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
