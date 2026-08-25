import 'package:acafe_customer/features/kiosk/screens/kiosk_added_to_cart_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The confirmation beat both ordering experiences finish at. It holds no
/// provider dependency by design, so it can be rendered exactly as shipped.
void main() {
  Widget harness({Size size = const Size(1080, 1920)}) => MediaQuery(
        data: MediaQueryData(size: size),
        child: const MaterialApp(
          home: KioskAddedToCartScreen(
            heroImage: '',
            totalLabel: '€ 8.75',
          ),
        ),
      );

  testWidgets('lays out the whole design without overflow', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(harness());
    await tester.pump(const Duration(milliseconds: 1200));

    expect(tester.takeException(), isNull);
    expect(find.text('Item added to cart!'), findsOneWidget);
    expect(find.text('Your total has been updated'), findsOneWidget);
    expect(find.text('€ 8.75'), findsOneWidget);
  });

  testWidgets('survives a short landscape viewport', (tester) async {
    // The artboard is a tall portrait kiosk; a resized browser window or a
    // landscape tablet is where a fixed-size hero would push the total off
    // the bottom.
    tester.view.physicalSize = const Size(1400, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(harness(size: const Size(1400, 700)));
    await tester.pump(const Duration(milliseconds: 1200));

    expect(tester.takeException(), isNull);
    expect(find.text('€ 8.75'), findsOneWidget);
  });

  testWidgets('and a small tablet', (tester) async {
    tester.view.physicalSize = const Size(600, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(harness(size: const Size(600, 1024)));
    await tester.pump(const Duration(milliseconds: 1200));

    expect(tester.takeException(), isNull);
    expect(find.text('Item added to cart!'), findsOneWidget);
  });

  testWidgets('content animates in rather than appearing fully formed',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump(); // first frame: controller at 0

    Opacity opacityAbove(Finder f) => tester.widget<Opacity>(
        find.ancestor(of: f, matching: find.byType(Opacity)).first);

    final double atStart = opacityAbove(find.text('€ 8.75')).opacity;
    await tester.pump(const Duration(milliseconds: 1200));
    final double atEnd = opacityAbove(find.text('€ 8.75')).opacity;

    expect(atStart, lessThan(0.05), reason: 'total starts hidden');
    expect(atEnd, greaterThan(0.95), reason: 'total ends fully visible');
  });

  testWidgets('tapping anywhere leaves immediately', (tester) async {
    // A customer adding several items must never be made to sit through this.
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  KioskAddedToCartScreen.route(
                      heroImage: '', totalLabel: '€ 8.75'),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Item added to cart!'), findsOneWidget);

    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(find.text('Item added to cart!'), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('returns on its own if the customer walks away', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  KioskAddedToCartScreen.route(
                      heroImage: '', totalLabel: '€ 8.75'),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Item added to cart!'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Item added to cart!'), findsNothing);
  });
}
