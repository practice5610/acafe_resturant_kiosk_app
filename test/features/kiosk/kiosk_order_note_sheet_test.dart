import 'package:acafe_customer/features/cart/domain/reposotories/cart_repo.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_order_note_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The order-note modal is a note card over CONTINUE — one centred column —
/// with no on-screen keyboard. Customers type with the device keyboard.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Without a localization delegate `getTranslated` echoes its key, so the
  /// button may render as "continue" here and "CONTINUE" in the app.
  Finder labelled(String text) => find.byWidgetPredicate(
      (w) => w is Text && (w.data ?? '').toLowerCase() == text.toLowerCase(),
      description: 'Text "$text" (any case)');

  Future<void> pumpSheet(WidgetTester tester, Size viewport) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<CartProvider>(
              create: (_) =>
                  CartProvider(cartRepo: CartRepo(sharedPreferences: prefs))),
        ],
        child: const MaterialApp(home: KioskOrderNoteSheet()),
      ),
    );
    await tester.pump();
  }

  const List<Size> viewports = [
    Size(1024, 768),
    Size(1366, 768),
    Size(1512, 905), // MacBook Pro 14" browser window
    Size(1920, 1080),
    Size(2560, 1440),
    Size(3024, 1964), // the same display, unscaled
    Size(408, 826),
    Size(768, 1280),
    Size(1080, 1920), // portrait kiosk
  ];

  for (final Size viewport in viewports) {
    testWidgets(
        'lays out the note card and CONTINUE at '
        '${viewport.width.toInt()}x${viewport.height.toInt()}', (tester) async {
      await pumpSheet(tester, viewport);

      expect(tester.takeException(), isNull);
      expect(find.byType(TextField), findsOneWidget);
      expect(labelled('Continue'), findsOneWidget);
      expect(labelled('Space'), findsNothing);
      expect(labelled('Clear'), findsNothing);
      expect(find.text('Q'), findsNothing);
    });
  }

  testWidgets('no overflow through openKioskOrderNote at Retina scale',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    tester.view.physicalSize = const Size(3024, 1964);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    late BuildContext ctx;
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<CartProvider>(
            create: (_) =>
                CartProvider(cartRepo: CartRepo(sharedPreferences: prefs))),
      ],
      child: MaterialApp(
        home: Builder(builder: (context) {
          ctx = context;
          return const Scaffold(body: SizedBox.expand());
        }),
      ),
    ));

    openKioskOrderNote(ctx);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    const double logicalWidth = 3024 / 2;
    expect(tester.getRect(labelled('Continue')).right,
        lessThanOrEqualTo(logicalWidth + 0.5));
  });

  testWidgets('the note sits above CONTINUE, centred on the same column',
      (tester) async {
    for (final Size viewport in viewports) {
      await pumpSheet(tester, viewport);

      final Rect field = tester.getRect(find.byType(TextField));
      final Rect continueBtn = tester.getRect(labelled('Continue'));

      expect(field.bottom, lessThanOrEqualTo(continueBtn.top),
          reason: 'the note must be above CONTINUE at '
              '${viewport.width}x${viewport.height}');
      expect((field.center.dx - continueBtn.center.dx).abs(), lessThan(2.0),
          reason: 'the card and CONTINUE share a centre line at '
              '${viewport.width}x${viewport.height}');
    }
  });

  testWidgets('the whole stack fits the window at every viewport',
      (tester) async {
    for (final Size viewport in viewports) {
      await pumpSheet(tester, viewport);

      final Rect back = tester.getRect(find.byType(Icon).first);
      final Rect continueBtn = tester.getRect(labelled('Continue'));

      expect(back.top, greaterThanOrEqualTo(-0.5),
          reason: 'the card is cut off the top at '
              '${viewport.width}x${viewport.height}');
      expect(continueBtn.bottom, lessThanOrEqualTo(viewport.height + 0.5),
          reason: 'CONTINUE runs to ${continueBtn.bottom} of '
              '${viewport.height} at ${viewport.width}x${viewport.height}');

      expect(tester.getRect(find.byType(TextField)).height,
          greaterThanOrEqualTo(36.0),
          reason: 'the note field collapsed at '
              '${viewport.width}x${viewport.height}');
    }
  });

  testWidgets('the field accepts typed input from a system keyboard',
      (tester) async {
    await pumpSheet(tester, const Size(1512, 905));

    await tester.enterText(find.byType(TextField), 'Extra napkins please');
    await tester.pump();

    expect(find.text('Extra napkins please'), findsOneWidget);
  });

  testWidgets('CONTINUE saves the note to the cart', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final cart = CartProvider(cartRepo: CartRepo(sharedPreferences: prefs));

    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    late BuildContext ctx;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<CartProvider>.value(value: cart),
        ],
        child: MaterialApp(
          home: Builder(builder: (context) {
            ctx = context;
            return const Scaffold(body: SizedBox.expand());
          }),
        ),
      ),
    );

    openKioskOrderNote(ctx);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'No straw');
    await tester.pump();
    await tester.tap(labelled('Continue'));
    await tester.pumpAndSettle();

    expect(cart.orderNote, 'No straw');
    expect(find.byType(TextField), findsNothing);
  });
}
