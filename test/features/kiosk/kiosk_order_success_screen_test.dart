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
          orderNumber: '832',
          customerName: 'Dylan',
          receiptUrl: 'https://acafepos.com/order-details?id=832',
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

  testWidgets('advances to the thank-you beat with name, order and receipt',
      (tester) async {
    await render(tester);
    await tester.pump(const Duration(milliseconds: 950));

    await tester.tap(find.byType(KioskOrderSuccessScreen));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.text('THANK YOU!'), findsOneWidget);
    expect(find.text('DYLAN'), findsOneWidget);
    expect(find.text('Order /832'), findsOneWidget);
    expect(find.text('Scan for your receipt'), findsOneWidget);
    expect(find.text('No paper receipt is printed'), findsOneWidget);
    expect(find.text('PLACE NEW ORDER'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
  });

  testWidgets('countdown ticks down and auto-leaves at zero', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                KioskOrderSuccessScreen.route(
                  orderNumber: '832',
                  customerName: 'Dylan',
                  receiptUrl: 'https://acafepos.com/order-details?id=832',
                  countdownSeconds: 3,
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
    await tester.pump(const Duration(milliseconds: 950));
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.text('3'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('2'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('go'), findsOneWidget);
    expect(find.byType(KioskOrderSuccessScreen), findsNothing);
  });

  testWidgets('survives a short landscape viewport', (tester) async {
    await render(tester, size: const Size(1400, 700));
    await tester.pump(const Duration(milliseconds: 950));
    expect(tester.takeException(), isNull);
    expect(find.text('ORDER CONFIRMED!'), findsOneWidget);

    await tester.tap(find.byType(KioskOrderSuccessScreen));
    await tester.pump(const Duration(milliseconds: 900));
    expect(tester.takeException(), isNull);
    expect(find.text('DYLAN'), findsOneWidget);
  });

  testWidgets('tapping the thank-you beat leaves immediately', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                KioskOrderSuccessScreen.route(
                  orderNumber: '832',
                  customerName: 'Dylan',
                  receiptUrl: 'https://acafepos.com/order-details?id=832',
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
