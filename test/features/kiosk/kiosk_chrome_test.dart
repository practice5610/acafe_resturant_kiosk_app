import 'dart:io';

import 'package:acafe_customer/features/kiosk/domain/kiosk_chrome_spec.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_customize_spec.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_checkout_email_screen.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_checkout_name_screen.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_confirm_screen.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_coupon_screen.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/single_child_widget.dart';

import '../../helpers/kiosk_layout_harness.dart';

/// Locks in the shared kiosk chrome: ONE back button, ONE action bar, one
/// chrome scale, and a header in which the step indicator cannot reach back
/// under the back button.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<SingleChildWidget> base;
  setUpAll(() async {
    await loadKioskTestFonts();
    base = await kioskBaseProviders();
  });

  group('chrome scale', () {
    const List<Size> viewports = [
      Size(1080, 1920),
      Size(1366, 1024),
      Size(1024, 768),
      Size(800, 1280),
      Size(600, 1000),
      Size(540, 960),
      Size(480, 800),
      Size(360, 640),
    ];

    test('the reference artboard height is the two-step product it names', () {
      // Tallest step (Cup or Can) of a described two-step product, plus the
      // step-flow chrome above it: back-button top inset, progress bar, and
      // the "Your Choices" row.
      final double vessel = kioskCustomizeArtboardHeight(
        hasDescription: true,
        variationPanels: 0,
        hasAddOns: false,
        hasVessel: true,
      );
      expect(kKioskChromeReferenceArtboardHeight,
          closeTo(vessel + KioskCustomizeSpec.backButtonTop + 227 + 271, 0.01));
    });

    test(
        'reference scale is the /menu-kiosk customize scale, width-bound in '
        'portrait', () {
      for (final Size v in viewports) {
        expect(
          referenceChromeScale(v),
          kioskCustomizeScale(
              viewport: v, artboardHeight: kKioskChromeReferenceArtboardHeight),
        );
      }
      // Portrait: exactly width / 2572, i.e. what /menu-kiosk draws.
      for (final Size v in viewports.where((v) => v.height > v.width)) {
        expect(referenceChromeScale(v), closeTo(v.width / 2572, 1e-9));
      }
    });

    test('never exceeds the reference scale nor the page scale', () {
      // Structural: it is a min(), so no input can make it exceed either bound.
      for (final Size v in viewports) {
        for (double page = 0.05; page <= 1.2; page += 0.05) {
          final double c = kioskChromeScale(v, page);
          expect(c, lessThanOrEqualTo(page));
          expect(c, lessThanOrEqualTo(referenceChromeScale(v)));
        }
      }
    });

    test('the back button is 10% larger on portrait only', () {
      expect(KioskChromeSpec.backPortraitFactor, 1.1);
    });

    test('spec values are the /menu-kiosk reference', () {
      // 100 / 4 / 50: the same circle as the step indicator beside it.
      expect(KioskChromeSpec.backDiameter, 100);
      expect(KioskChromeSpec.backBorder, 4);
      expect(KioskChromeSpec.backIcon, 50);
      expect(KioskChromeSpec.insetLeft, 86);
      expect(KioskChromeSpec.insetTop, 93);
      expect(KioskChromeSpec.barHeight, 252);
      expect(KioskChromeSpec.barFontSize, 72);
      expect(KioskChromeSpec.barRadius, 30);
      expect(KioskChromeSpec.barGap, 22);
      expect(KioskChromeSpec.barInsetHorizontal, 86);
      expect(KioskChromeSpec.barTopGap, 72);
      expect(KioskChromeSpec.barBottomGap, 87);
    });
  });

  group('one back button, one action bar', () {
    final List<File> kioskFiles = [
      ...Directory('lib/features/kiosk').listSync(recursive: true),
      ...Directory('lib/features/search').listSync(recursive: true),
    ].whereType<File>().where((f) => f.path.endsWith('.dart')).toList();

    test('no back-button size / border / icon override survives', () {
      final RegExp deleted = RegExp(
          r'KioskBackButton\.(scaled|header)|headerSizeFor|headerMinSize|'
          r'KioskBackButton\.header(Size|Border|Icon)');
      final List<String> offenders = [
        for (final f in kioskFiles)
          if (deleted.hasMatch(f.readAsStringSync())) f.path,
      ];
      expect(offenders, isEmpty);

      // Every construction passes only `s`, `onTap`, `fallback`.
      final RegExp overrides = RegExp(
          r'KioskBackButton\(([^)]*?)\b(size|borderWidth|iconSize)\s*:',
          dotAll: true);
      final List<String> bad = [
        for (final f in kioskFiles)
          if (overrides.hasMatch(f.readAsStringSync())) f.path,
      ];
      expect(bad, isEmpty);
    });

    test('no bespoke back button survives anywhere in the kiosk', () {
      final RegExp bespoke =
          RegExp(r'KioskCircleBack|Icons\.arrow_back\b|Icons\.chevron_left');
      final List<String> offenders = [
        for (final f in kioskFiles)
          if (bespoke.hasMatch(f.readAsStringSync())) f.path,
      ];
      expect(offenders, isEmpty);
    });

    test('the six screens build no bespoke footer / action buttons', () {
      // Scoped to the six screens' own files: the tip sheet and the landscape
      // dialogs are separate surfaces with their own follow-up pass.
      const List<String> sixScreens = [
        'screens/kiosk_cart_screen.dart',
        'screens/kiosk_coupon_screen.dart',
        'screens/kiosk_checkout_name_screen.dart',
        'screens/kiosk_checkout_email_screen.dart',
        'screens/kiosk_confirm_screen.dart',
        'screens/kiosk_checkout_widgets.dart',
        'screens/kiosk_product_customize_step_flow.dart',
        'screens/kiosk_product_customize_sheet.dart',
      ];
      final List<String> offenders = [
        for (final s in sixScreens)
          if (RegExp(r'class _FooterButton|class _ActionButton|forceScaled')
              .hasMatch(File('lib/features/kiosk/$s').readAsStringSync()))
            s,
      ];
      expect(offenders, isEmpty);
    });

    test('the coupon screen no longer scrolls its whole body', () {
      final String src =
          File('lib/features/kiosk/screens/kiosk_coupon_screen.dart')
              .readAsStringSync();
      expect(src.contains('SingleChildScrollView'), isFalse);
    });
  });

  group('step indicator never overlaps the back button', () {
    Finder node() =>
        find.byWidgetPredicate((w) => w.runtimeType.toString() == '_StepNode');

    for (final double w in [360, 412, 480, 540, 600, 1080]) {
      final Size size = Size(w, w * 16 / 9);
      for (final entry in <String, Widget Function()>{
        'name': () => const KioskCheckoutNameScreen(),
        'email': () => const KioskCheckoutEmailScreen(),
        'confirm': () => const KioskConfirmScreen(),
      }.entries) {
        testWidgets('${entry.key} at ${w.toInt()} px wide', (tester) async {
          await pumpKioskScreen(tester, size, entry.value(),
              providers: List.of(base));
          await settleKiosk(tester);
          final Rect back = tester.getRect(find.byType(KioskBackButton));
          final Rect first = tester.getRect(node().first);
          expect(back.left, greaterThanOrEqualTo(0));
          expect(first.left - back.right, greaterThan(0),
              reason: 'the stepper must start after the back button');
          expectNoOverflow(tester, size);
        });
      }
    }
  });

  group('coupon never overflows', () {
    for (final Size size in const [
      Size(1080, 1920),
      Size(1366, 1024),
      Size(1024, 768),
      Size(800, 1280),
      Size(600, 1000),
      Size(540, 960),
      Size(480, 800),
      Size(360, 640),
    ]) {
      testWidgets('${size.width.toInt()}x${size.height.toInt()}',
          (tester) async {
        await pumpKioskScreen(
            tester, size, const KioskCouponScreen(orderAmount: 25),
            providers: List.of(base));
        await settleKiosk(tester);
        expectNoOverflow(tester, size);
        // The pinned bar is fully on screen.
        final Rect bar = tester.getRect(find.text('CONTINUE'));
        expect(bar.bottom, lessThanOrEqualTo(size.height));
      });
    }
  });
}
