import 'dart:convert';
import 'dart:io';

import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/coupon/providers/coupon_provider.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_coupon_screen.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_ui.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Coupon entry (Figma POS node 1385:15500). The artboard is a 2572 x 4530
/// portrait kiosk, so these checks are about the screen surviving every
/// viewport the kiosk actually ships on — portrait kiosk, resized browser
/// window, short landscape display — without overflowing or dropping a section,
/// and about the on-screen board driving the same controller a physical
/// keyboard would.
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

  Widget harness() {
    // No AppLocalization delegate on purpose: this is the same convention the
    // language-sheet test uses, and it doubles as proof that every string on
    // the screen falls back to readable copy instead of a raw key. Coverage
    // that the keys exist in every language file lives below.
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CouponProvider(couponRepo: null)),
        ChangeNotifierProvider(create: (_) => CartProvider(cartRepo: null)),
      ],
      child: const MaterialApp(home: KioskCouponScreen(orderAmount: 25)),
    );
  }

  /// Settles without `pumpAndSettle`, which never returns while the field's
  /// caret is blinking.
  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  Future<void> render(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(harness());
    await settle(tester);
  }

  Finder svgKey(String asset) => find.byWidgetPredicate(
        (w) =>
            w is SvgPicture &&
            w.bytesLoader is SvgAssetLoader &&
            (w.bytesLoader as SvgAssetLoader).assetName == asset,
      );

  TextField fieldOf(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField));

  const viewports = <String, Size>{
    'portrait kiosk': Size(1080, 1920),
    'resized browser window': Size(600, 1000),
    'short landscape display': Size(1500, 900),
    'large landscape display': Size(2560, 1440),
  };

  for (final entry in viewports.entries) {
    testWidgets('lays out every section on a ${entry.key}', (tester) async {
      await render(tester, entry.value);

      expect(tester.takeException(), isNull);
      expect(find.text('Enter your code'), findsOneWidget);
      expect(find.byType(KioskBackButton), findsOneWidget);
      expect(find.text('SCAN YOUR CODE'), findsOneWidget);
      expect(find.text('Use the scanner below you'), findsOneWidget);
      expect(find.text('BACK'), findsOneWidget);
      expect(find.text('CONTINUE'), findsOneWidget);
      expect(find.text('Space'), findsOneWidget);
      expect(find.text('Clear'), findsOneWidget);
      // Digits, QWERTY, ASDFGHJKL and ZXCVBNM — no row dropped or clipped.
      expect(find.text('1'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      expect(find.text('Q'), findsOneWidget);
      expect(find.text('L'), findsOneWidget);
      expect(find.text('M'), findsOneWidget);
      expect(svgKey(Images.kioskKeyShiftSvg), findsOneWidget);
      expect(svgKey(Images.kioskKeyBackspaceSvg), findsOneWidget);
      expect(svgKey(Images.kioskCouponQrSvg), findsOneWidget);
    });
  }

  testWidgets('header back button pops to the previous route', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => CouponProvider(couponRepo: null)),
          ChangeNotifierProvider(create: (_) => CartProvider(cartRepo: null)),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const KioskCouponScreen(orderAmount: 25),
                    ),
                  ),
                  child: const Text('open coupon'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open coupon'));
    await settle(tester);

    expect(find.text('Enter your code'), findsOneWidget);
    await tester.tap(find.byType(KioskBackButton));
    await settle(tester);

    expect(find.text('Enter your code'), findsNothing);
    expect(find.text('open coupon'), findsOneWidget);
  });

  testWidgets('never renders a raw translation key', (tester) async {
    await render(tester, const Size(1080, 1920));

    expect(find.text('enter_your_code'), findsNothing);
    expect(find.text('scan_your_code'), findsNothing);
    expect(find.text('use_the_scanner_below_you'), findsNothing);
    expect(find.text('back'), findsNothing);
  });

  testWidgets('keys type into the field; backspace and clear undo it',
      (tester) async {
    await render(tester, const Size(1080, 1920));

    for (final key in ['Z', 'X', '9']) {
      await tester.tap(find.text(key));
      await tester.pump();
    }
    expect(fieldOf(tester).controller!.text, 'ZX9');

    await tester.tap(svgKey(Images.kioskKeyBackspaceSvg));
    await tester.pump();
    expect(fieldOf(tester).controller!.text, 'ZX');

    await tester.tap(find.text('Space'));
    await tester.pump();
    expect(fieldOf(tester).controller!.text, 'ZX ');

    await tester.tap(find.text('Clear'));
    await tester.pump();
    expect(fieldOf(tester).controller!.text, isEmpty);
  });

  testWidgets(
      'a run of keys builds one code on a desktop/web-style host',
      (tester) async {
    // Regression: tapping a key is a tap OUTSIDE the field, so the framework
    // unfocused it; re-focusing then re-selected the whole value
    // (`selectAllOnFocus` defaults to true on web and desktop), and the next
    // key replaced the code instead of appending to it — the kiosk could only
    // ever hold one character. macOS reproduces the web path exactly.
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await render(tester, const Size(1080, 1920));

      for (final key in ['A', '8', '1', '7', '3', '9']) {
        await tester.tap(find.text(key));
        await tester.pump();
      }
      expect(fieldOf(tester).controller!.text, 'A81739');
      expect(
        fieldOf(tester).controller!.selection,
        const TextSelection.collapsed(offset: 6),
        reason: 'the caret stays at the end instead of selecting the code',
      );
    } finally {
      // Must be cleared inside the test body: the binding asserts on it before
      // `addTearDown` callbacks run.
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('shift flips the caps the board shows and the case it types',
      (tester) async {
    await render(tester, const Size(1080, 1920));

    // Coupon codes are upper case, so the board opens shifted.
    expect(find.text('Q'), findsOneWidget);
    expect(find.text('q'), findsNothing);

    await tester.tap(svgKey(Images.kioskKeyShiftSvg));
    await tester.pump();
    expect(find.text('q'), findsOneWidget);
    expect(find.text('Q'), findsNothing);

    await tester.tap(find.text('q'));
    await tester.pump();
    expect(fieldOf(tester).controller!.text, 'q');
  });

  test('every string the screen asks for exists in all four languages', () {
    const keys = [
      'enter_your_code',
      'scan_your_code',
      'use_the_scanner_below_you',
      'back',
      'continue',
      'space',
      'clear',
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
