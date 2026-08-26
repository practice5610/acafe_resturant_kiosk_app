import 'dart:io';

import 'package:acafe_customer/features/kiosk/screens/kiosk_order_success_screen.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

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

  Finder logo() => find.byWidgetPredicate(
        (w) =>
            w is SvgPicture &&
            w.bytesLoader is SvgAssetLoader &&
            (w.bytesLoader as SvgAssetLoader).assetName ==
                Images.kioskLogoWhiteSvg,
      );

  Future<void> render(WidgetTester tester, {Size size = const Size(1080, 1920)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: KioskOrderSuccessScreen(
          orderNumber: '#832',
          thankYouText: 'THANK YOU, DYLAN!',
          pickupMessage:
              'Grab it at the counter when your name shows up enjoy!',
          confirmedText: 'ORDER CONFIRMED!',
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('confirmed beat draws the check and the wordmark',
      (tester) async {
    await render(tester);
    await tester.pump(const Duration(milliseconds: 950));

    expect(tester.takeException(), isNull);
    expect(logo(), findsOneWidget);
    expect(find.text('ORDER CONFIRMED!'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('advances to the order-number thank-you beat', (tester) async {
    await render(tester);
    await tester.pump(const Duration(milliseconds: 950));

    await tester.tap(find.byType(KioskOrderSuccessScreen));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.text('#832'), findsOneWidget);
    expect(find.text('THANK YOU, DYLAN!'), findsOneWidget);
    expect(
      find.text('Grab it at the counter when your name shows up enjoy!'),
      findsOneWidget,
    );
  });

  testWidgets('survives a short landscape viewport', (tester) async {
    await render(tester, size: const Size(1400, 700));
    await tester.pump(const Duration(milliseconds: 950));
    expect(tester.takeException(), isNull);
    expect(find.text('ORDER CONFIRMED!'), findsOneWidget);

    await tester.tap(find.byType(KioskOrderSuccessScreen));
    await tester.pump(const Duration(milliseconds: 900));
    expect(tester.takeException(), isNull);
    expect(find.text('#832'), findsOneWidget);
  });

  testWidgets('tapping the thank-you beat leaves immediately', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                KioskOrderSuccessScreen.route(
                  orderNumber: '#832',
                  thankYouText: 'THANK YOU, DYLAN!',
                  pickupMessage:
                      'Grab it at the counter when your name shows up enjoy!',
                ),
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(KioskOrderSuccessScreen));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byType(KioskOrderSuccessScreen));
    await tester.pumpAndSettle();

    expect(find.text('go'), findsOneWidget);
    expect(find.byType(KioskOrderSuccessScreen), findsNothing);
  });
}
