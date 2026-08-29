import 'dart:math' as math;

import 'package:acafe_customer/features/kiosk/screens/kiosk_login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/single_child_widget.dart';

import '../../helpers/kiosk_layout_harness.dart';

/// The login card is a fixed object, centred on both axes: 440pt wide from the
/// tablet breakpoint up, ~90% of the screen below it, with type and control
/// heights that never move. These tests hold that contract at the viewports the
/// kiosk actually ships on.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<SingleChildWidget> withAuth;

  setUpAll(() async {
    await loadKioskTestFonts();
    withAuth = await kioskBaseProviders(withAuth: true);
  });

  double fontSizeOf(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).style!.fontSize!;

  for (final size in const [
    Size(800, 1280), // portrait tablet kiosk
    Size(1280, 800), // landscape kiosk
    Size(1920, 1080), // large POS monitor
    Size(375, 812), // narrow browser window
    Size(1080, 1920), // production kiosk panel
  ]) {
    final String label = '${size.width.toInt()}×${size.height.toInt()}';

    testWidgets('login card is fixed-width and centred at $label',
        (tester) async {
      await pumpKioskScreen(
        tester,
        size,
        const KioskLoginScreen(),
        providers: withAuth,
      );
      await settleKiosk(tester);
      expectNoOverflow(tester, size);

      final Rect cardRect =
          tester.getRect(find.byKey(const ValueKey('kioskLoginCard')));

      // 1. Width is capped — never stretched edge to edge.
      final double expectedWidth =
          size.width < 600 ? math.min(size.width * 0.9, 440.0) : 440.0;
      expect(cardRect.width, closeTo(expectedWidth, 0.5),
          reason: 'card width at $label');

      // 2. Centred horizontally, and vertically whenever it fits.
      expect(cardRect.center.dx, closeTo(size.width / 2, 1),
          reason: 'horizontal centring at $label');
      if (cardRect.height <= size.height) {
        expect(cardRect.center.dy, closeTo(size.height / 2, 1),
            reason: 'vertical centring at $label');
      }

      // 3. The card stays on screen.
      expect(cardRect.top, greaterThanOrEqualTo(-0.5), reason: 'clipped top');
      expect(cardRect.bottom, lessThanOrEqualTo(size.height + 0.5),
          reason: 'clipped bottom');
    });

    testWidgets('login type and touch targets are constant at $label',
        (tester) async {
      await pumpKioskScreen(
        tester,
        size,
        const KioskLoginScreen(),
        providers: withAuth,
      );
      await settleKiosk(tester);

      // Type never scales with the window; only the compact-height variant of
      // the wordmark changes, and only below 700pt tall.
      expect(fontSizeOf(tester, 'A/CAFÉ'), size.height < 700 ? 38 : 48);
      expect(fontSizeOf(tester, 'Device login'), 22);
      expect(fontSizeOf(tester, 'LOGIN'), 18);
      expect(fontSizeOf(tester, 'USERNAME'), 14);

      // Kiosk touch targets.
      for (final target in const ['USERNAME', 'PASSWORD']) {
        final Rect field = tester.getRect(
          find.ancestor(
            of: find.text(target),
            matching: find.byType(Column),
          ).first,
        );
        expect(field.width, greaterThan(0), reason: 'field laid out at $label');
      }
      expect(tester.getSize(find.text('LOGIN')).height, greaterThan(0));
      final Rect button = tester.getRect(
        find.ancestor(of: find.text('LOGIN'), matching: find.byType(SizedBox))
            .first,
      );
      expect(button.height, greaterThanOrEqualTo(56),
          reason: 'login button touch target at $label');
    });
  }

  testWidgets('short window keeps the card on screen without clipping',
      (tester) async {
    const Size size = Size(1024, 600);
    await pumpKioskScreen(
      tester,
      size,
      const KioskLoginScreen(),
      providers: withAuth,
    );
    await settleKiosk(tester);
    expectNoOverflow(tester, size);

    expect(fontSizeOf(tester, 'A/CAFÉ'), 38, reason: 'compact wordmark');
    expect(find.text('LOGIN'), findsOneWidget);
  });
}
