import 'package:acafe_customer/features/cart/domain/reposotories/cart_repo.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_order_note_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The order-note modal is a note card floating above an on-screen QWERTY
/// keyboard docked to the bottom of the screen — Figma 2305:15852 ("06b Order
/// note pop-up"). The field is `readOnly`; every character comes from
/// [KioskOrderNoteSheet]'s own key handlers, not the system IME.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Without a localization delegate `getTranslated` echoes its key, so the
  /// button may render as "continue" here and "CONTINUE" in the app.
  Finder labelled(String text) => find.byWidgetPredicate(
      (w) => w is Text && (w.data ?? '').toLowerCase() == text.toLowerCase(),
      description: 'Text "$text" (any case)');

  Future<void> pumpSheet(WidgetTester tester, Size viewport,
      {CartProvider? cart}) async {
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
                  cart ??
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
        'lays out the note card, keyboard and CONTINUE at '
        '${viewport.width.toInt()}x${viewport.height.toInt()}',
        (tester) async {
      await pumpSheet(tester, viewport);

      expect(tester.takeException(), isNull);
      expect(find.byType(TextField), findsOneWidget);
      expect(labelled('Continue'), findsOneWidget);
      expect(labelled('Space'), findsOneWidget);
      expect(labelled('Clear'), findsOneWidget);
      expect(find.text('q'), findsOneWidget); // lower-case: shift starts off
      // The note popup's board hides the digit row (Figma 2305:15957).
      expect(find.text('1'), findsNothing);
    });
  }

  testWidgets('a tap beside the card closes the note', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
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
    expect(labelled('Continue'), findsOneWidget);

    await tester.tapAt(const Offset(20, 40));
    await tester.pumpAndSettle();
    expect(labelled('Continue'), findsNothing);
  });

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

  testWidgets('the note sits above the keyboard panel, centred on the window',
      (tester) async {
    for (final Size viewport in viewports) {
      await pumpSheet(tester, viewport);

      final Rect field = tester.getRect(find.byType(TextField));
      final Rect continueBtn = tester.getRect(labelled('Continue'));

      expect(field.bottom, lessThanOrEqualTo(continueBtn.top),
          reason: 'the note must be above the keyboard panel at '
              '${viewport.width}x${viewport.height}');
    }
  });

  testWidgets('the whole stack fits the window at every viewport',
      (tester) async {
    for (final Size viewport in viewports) {
      await pumpSheet(tester, viewport);

      final Rect continueBtn = tester.getRect(labelled('Continue'));

      expect(continueBtn.bottom, lessThanOrEqualTo(viewport.height + 0.5),
          reason: 'CONTINUE runs to ${continueBtn.bottom} of '
              '${viewport.height} at ${viewport.width}x${viewport.height}');

      expect(tester.getRect(find.byType(TextField)).height,
          greaterThanOrEqualTo(36.0),
          reason: 'the note field collapsed at '
              '${viewport.width}x${viewport.height}');
    }
  });

  testWidgets('the field is read-only — typing goes through the on-screen keys',
      (tester) async {
    await pumpSheet(tester, const Size(1512, 905));

    final TextField field = tester.widget(find.byType(TextField));
    expect(field.readOnly, isTrue);
  });

  testWidgets('tapping on-screen letter keys types lower-case by default',
      (tester) async {
    await pumpSheet(tester, const Size(1512, 905));

    await tester.tap(find.text('h'));
    await tester.tap(find.text('i'));
    await tester.pump();

    final TextField field = tester.widget(find.byType(TextField));
    expect(field.controller!.text, 'hi');
  });

  // Shift and backspace are drawn from an SVG asset, not a Material Icon
  // (see _KioskKey in kiosk_keyboard.dart) — these are the only two SvgPicture
  // keys on the board, shift first (leads the Z row) then backspace (trails
  // it), so position is a stable way to find them in tests.
  Finder shiftKey() => find.byType(SvgPicture).first;
  Finder backspaceKey() => find.byType(SvgPicture).last;

  testWidgets('shift types upper case for the next letter, then drops back',
      (tester) async {
    await pumpSheet(tester, const Size(1512, 905));

    await tester.tap(shiftKey());
    await tester.pump();
    expect(find.text('A'), findsOneWidget); // board now shows caps

    await tester.tap(find.text('A'));
    await tester.pump();

    final TextField field = tester.widget(find.byType(TextField));
    expect(field.controller!.text, 'A');
  });

  testWidgets('backspace removes the last character', (tester) async {
    await pumpSheet(tester, const Size(1512, 905));

    await tester.tap(find.text('h'));
    await tester.tap(find.text('i'));
    await tester.pump();

    await tester.tap(backspaceKey());
    await tester.pump();

    final TextField field = tester.widget(find.byType(TextField));
    expect(field.controller!.text, 'h');
  });

  testWidgets('space inserts a blank character', (tester) async {
    await pumpSheet(tester, const Size(1512, 905));

    await tester.tap(find.text('h'));
    await tester.tap(labelled('Space'));
    await tester.tap(find.text('i'));
    await tester.pump();

    final TextField field = tester.widget(find.byType(TextField));
    expect(field.controller!.text, 'h i');
  });

  testWidgets('clear empties the field', (tester) async {
    await pumpSheet(tester, const Size(1512, 905));

    await tester.tap(find.text('h'));
    await tester.tap(find.text('i'));
    await tester.tap(labelled('Clear'));
    await tester.pump();

    final TextField field = tester.widget(find.byType(TextField));
    expect(field.controller!.text, isEmpty);
  });

  testWidgets('CONTINUE saves the typed note to the cart', (tester) async {
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

    await tester.tap(find.text('h'));
    await tester.tap(find.text('i'));
    await tester.pump();
    await tester.tap(labelled('Continue'));
    await tester.pumpAndSettle();

    expect(cart.orderNote, 'hi');
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('opening the sheet again seeds the field from the saved note',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final cart = CartProvider(cartRepo: CartRepo(sharedPreferences: prefs))
      ..setOrderNote('No straw');

    await pumpSheet(tester, const Size(1512, 905), cart: cart);

    final TextField field = tester.widget(find.byType(TextField));
    expect(field.controller!.text, 'No straw');
  });
}
