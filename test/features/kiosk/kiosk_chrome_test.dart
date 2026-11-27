import 'dart:io';

import 'package:acafe_customer/features/kiosk/domain/kiosk_chrome_spec.dart';
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
    test('is the kiosk scale function, flat', () {
      for (final Size v in const [
        Size(1080, 1920),
        Size(1366, 1024),
        Size(1024, 768),
        Size(600, 1000),
        Size(360, 640),
      ]) {
        expect(kioskChromeScale(v), closeTo(_kioskScale(v), 1e-9));
      }
    });

    test('Version A is never larger than today nor than the unified scale', () {
      // Structural: it is a min(), so no input can make it exceed either bound.
      for (final Size v in const [
        Size(1080, 1920),
        Size(1366, 1024),
        Size(1024, 768),
        Size(360, 640),
      ]) {
        for (double page = 0.05; page <= 1.2; page += 0.05) {
          final double a = kioskChromeScaleVersionA(v, page);
          expect(a, lessThanOrEqualTo(page));
          expect(a, lessThanOrEqualTo(kioskChromeScale(v)));
        }
      }
    });

    test('spec values are the /menu-kiosk reference', () {
      expect(KioskChromeSpec.backDiameter, 141);
      expect(KioskChromeSpec.backBorder, 5);
      expect(KioskChromeSpec.backIcon, 55);
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
    Finder node() => find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_StepNode');

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

double _kioskScale(Size v) {
  // Independent restatement of KioskResponsive.scale (0.24..1.0 clamp).
  final double byWidth = (v.width / 2572).clamp(0.24, 1.0);
  if (v.height >= v.width) return byWidth;
  final double byHeight = (v.height / 2160).clamp(0.24, 1.0);
  return byWidth < byHeight ? byWidth : byHeight;
}
