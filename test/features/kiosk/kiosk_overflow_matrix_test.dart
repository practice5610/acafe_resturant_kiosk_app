import 'package:acafe_customer/features/kiosk/domain/kiosk_coupon_reward.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_added_to_cart_screen.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_cart_screen.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_checkout_email_screen.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_checkout_name_screen.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_confirm_screen.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_coupon_applied_screen.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_coupon_screen.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_login_screen.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_order_success_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/single_child_widget.dart';

import '../../helpers/kiosk_layout_harness.dart';

/// Overflow harness for every major kiosk viewport. Widget tests historically
/// pumped `MaterialApp(home: Screen())` and never mounted the 1440/2572 cap
/// that production runs with — this harness includes [KioskShell].
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<SingleChildWidget> base;
  late List<SingleChildWidget> withAuth;

  setUpAll(() async {
    await loadKioskTestFonts();
    base = await kioskBaseProviders();
    withAuth = await kioskBaseProviders(withAuth: true);
  });

  group('added-to-cart', () {
    for (final size in kioskTargetSizes) {
      testWidgets(
          '${size.width.toInt()}×${size.height.toInt()} does not overflow',
          (tester) async {
        await pumpKioskScreen(
          tester,
          size,
          const KioskAddedToCartScreen(
            heroImage: '',
            totalLabel: '€ 8.75',
          ),
        );
        await tester.pump(const Duration(milliseconds: 1200));
        expectNoOverflow(tester, size);
        expect(find.text('€ 8.75'), findsOneWidget);
      });
    }
  });

  group('order success', () {
    for (final size in kioskTargetSizes) {
      testWidgets(
          '${size.width.toInt()}×${size.height.toInt()} does not overflow',
          (tester) async {
        await pumpKioskScreen(
          tester,
          size,
          const KioskOrderSuccessScreen(
            orderNumber: '#832',
            thankYouText: 'THANK YOU, DYLAN!',
            pickupMessage:
                'Grab it at the counter when your name shows up enjoy!',
          ),
        );
        await tester.pump(const Duration(milliseconds: 950));
        expectNoOverflow(tester, size);
        expect(find.text('ORDER CONFIRMED!'), findsOneWidget);
      });
    }
  });

  group('coupon entry', () {
    for (final size in kioskTargetSizes) {
      testWidgets(
          '${size.width.toInt()}×${size.height.toInt()} does not overflow',
          (tester) async {
        await pumpKioskScreen(
          tester,
          size,
          const KioskCouponScreen(orderAmount: 25),
          providers: base,
        );
        await settleKiosk(tester);
        expectNoOverflow(tester, size);
      });
    }
  });

  group('coupon applied', () {
    for (final size in kioskTargetSizes) {
      testWidgets(
          '${size.width.toInt()}×${size.height.toInt()} does not overflow',
          (tester) async {
        await pumpKioskScreen(
          tester,
          size,
          const KioskCouponAppliedScreen(
            reward: KioskCouponReward(
              kind: KioskCouponRewardKind.percent,
              headline: '10%',
              heading: 'Coupon applied!',
              message: 'Your discount has been applied to your order.',
              savings: 2.5,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));
        expectNoOverflow(tester, size);
      });
    }
  });

  group('cart', () {
    for (final size in kioskTargetSizes) {
      testWidgets(
          '${size.width.toInt()}×${size.height.toInt()} does not overflow',
          (tester) async {
        await pumpKioskScreen(
          tester,
          size,
          const KioskCartScreen(),
          providers: base,
        );
        await settleKiosk(tester);
        expectNoOverflow(tester, size);
        expect(find.byType(KioskCartScreen), findsOneWidget);
      });
    }
  });

  group('order summary', () {
    for (final size in kioskTargetSizes) {
      testWidgets(
          '${size.width.toInt()}×${size.height.toInt()} does not overflow',
          (tester) async {
        await pumpKioskScreen(
          tester,
          size,
          const KioskConfirmScreen(),
          providers: base,
        );
        await settleKiosk(tester);
        expectNoOverflow(tester, size);
        expect(find.byType(KioskConfirmScreen), findsOneWidget);
      });
    }
  });

  group('checkout name', () {
    for (final size in kioskTargetSizes) {
      testWidgets(
          '${size.width.toInt()}×${size.height.toInt()} does not overflow',
          (tester) async {
        await pumpKioskScreen(
          tester,
          size,
          const KioskCheckoutNameScreen(),
        );
        await settleKiosk(tester);
        expectNoOverflow(tester, size);
      });
    }
  });

  group('checkout email', () {
    for (final size in kioskTargetSizes) {
      testWidgets(
          '${size.width.toInt()}×${size.height.toInt()} does not overflow',
          (tester) async {
        await pumpKioskScreen(
          tester,
          size,
          const KioskCheckoutEmailScreen(),
        );
        await settleKiosk(tester);
        expectNoOverflow(tester, size);
      });
    }
  });

  group('device login', () {
    for (final size in kioskTargetSizes) {
      testWidgets(
          '${size.width.toInt()}×${size.height.toInt()} does not overflow',
          (tester) async {
        await pumpKioskScreen(
          tester,
          size,
          const KioskLoginScreen(),
          providers: withAuth,
        );
        await settleKiosk(tester);
        expectNoOverflow(tester, size);
        expect(find.byType(KioskLoginScreen), findsOneWidget);
      });
    }
  });
}
