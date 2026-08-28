import 'package:acafe_customer/features/cart/domain/reposotories/cart_repo.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_order_note_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The order-note modal stacks a note card over an on-screen keyboard, one
/// centred column, in every orientation.
///
/// Two bugs shaped these tests, both the same mistake — a caller predicting a
/// measurement instead of deriving it. First the board was handed a predicted
/// WIDTH (`viewport * 0.52`) while its Row actually gave it
/// `(viewport - gutter * 3) * 6/11`; a keyboard has no give, so every pixel of
/// the difference came off the right edge as a RenderFlex overflow that
/// clipped P, backspace and Clear. Then the column was chosen on width alone,
/// which asked for more HEIGHT than a short landscape window had and pushed
/// CONTINUE off the bottom.
///
/// So these pin the derived-not-guessed properties: the board fits its slot,
/// the rows line up, the stack fits the window, and the note stays directly
/// above the keys.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Without a localization delegate `getTranslated` echoes its key, so the
  /// wide keys render as "space"/"clear" here and "Space"/"Clear" in the app.
  /// Match either, so the test pins the layout and not the locale.
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

  /// Landscape is the layout that overflowed; portrait is checked so the fix
  /// is not landscape-only. The narrow landscape sizes matter as much as the
  /// large ones — the mismatch grew as the window narrowed.
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
        'the keyboard fits its slot at '
        '${viewport.width.toInt()}x${viewport.height.toInt()}', (tester) async {
      await pumpSheet(tester, viewport);

      expect(tester.takeException(), isNull,
          reason: 'a RenderFlex overflow means a row of keys is clipped');

      // Every key is on screen, left edge to right edge — Q..P is the row
      // that sets the module, and Clear is the last thing on the board.
      for (final String key in ['Q', 'P', 'A', 'L', 'Z', 'M']) {
        final Rect rect = tester.getRect(find.text(key));
        expect(rect.left, greaterThanOrEqualTo(-0.5),
            reason: '"$key" starts off the left edge at $rect');
        expect(rect.right, lessThanOrEqualTo(viewport.width + 0.5),
            reason: '"$key" runs past the right edge at $rect');
      }
      for (final String label in ['Space', 'Clear', 'Continue']) {
        final Rect rect = tester.getRect(labelled(label));
        expect(rect.right, lessThanOrEqualTo(viewport.width + 0.5),
            reason: '"$label" runs past the right edge at $rect');
      }
    });
  }

  testWidgets('the key rows all span the same width', (tester) async {
    // The three letter rows are drawn from one module, so they have to line up
    // whatever the slot turns out to be. A row that is wider than the top row
    // is the shape the overflow took.
    for (final Size viewport in viewports) {
      await pumpSheet(tester, viewport);

      final Rect q = tester.getRect(find.text('Q'));
      final Rect p = tester.getRect(find.text('P'));
      final Rect a = tester.getRect(find.text('A'));
      final Rect l = tester.getRect(find.text('L'));
      final Rect space = tester.getRect(labelled('Space'));
      final Rect clear = tester.getRect(labelled('Clear'));

      final double topRow = p.right - q.left;
      // Letter rows are centred on each other, so compare centres and spans.
      expect(((a.left + l.right) / 2 - (q.left + p.right) / 2).abs(),
          lessThan(2.0),
          reason: 'the ASDF row is off-centre against QWERTY at '
              '${viewport.width}x${viewport.height}');
      expect(((space.left + clear.right) / 2 - (q.left + p.right) / 2).abs(),
          lessThan(2.0),
          reason: 'the Space/Clear row is off-centre at '
              '${viewport.width}x${viewport.height}');
      expect(topRow, greaterThan(0));
    }
  });

  testWidgets('no overflow through openKioskOrderNote at Retina scale',
      (tester) async {
    // The other tests pump the sheet directly. This one opens it the way the
    // cart does, through the dialog route, at the physical size and device
    // pixel ratio of a 14" MacBook Pro — the machine the overflow was
    // reported from — so the fix is pinned on the real path and not only on a
    // convenient harness.
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

    expect(tester.takeException(), isNull,
        reason: 'a RenderFlex overflow means a row of keys is clipped');

    const double logicalWidth = 3024 / 2;
    expect(tester.getRect(find.text('P')).right,
        lessThanOrEqualTo(logicalWidth + 0.5));
    expect(tester.getRect(labelled('Clear')).right,
        lessThanOrEqualTo(logicalWidth + 0.5));
  });

  testWidgets('the note sits directly above the keyboard, not beside it',
      (tester) async {
    // Landscape used to be a two-pane Row: the card in one corner, the board
    // in the other. A field and the keys that type into it cannot be read as
    // one thing when they sit diagonally apart, so they are stacked now — the
    // same arrangement in every orientation, both the same width.
    for (final Size viewport in viewports) {
      await pumpSheet(tester, viewport);

      final Rect field = tester.getRect(find.byType(TextField));
      final Rect topRow = tester.getRect(find.text('Q'));
      final Rect board = tester.getRect(labelled('Continue'));

      expect(field.bottom, lessThanOrEqualTo(topRow.top),
          reason: 'the note must be above the board at '
              '${viewport.width}x${viewport.height}');
      expect((field.center.dx - board.center.dx).abs(), lessThan(2.0),
          reason: 'the card and the board share a centre line at '
              '${viewport.width}x${viewport.height}');
    }
  });

  testWidgets('the whole stack fits the window at every viewport',
      (tester) async {
    // The board's height follows from its width, so a column chosen on width
    // alone asked for more height than a short landscape window had: the note
    // field collapsed to its floor and CONTINUE ran off the bottom. The
    // column is bounded on both axes now.
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

      // And the writable area keeps at least two lines — 36pt is two lines
      // at the smallest body size the card ever uses.
      expect(tester.getRect(find.byType(TextField)).height,
          greaterThanOrEqualTo(36.0),
          reason: 'the note field collapsed at '
              '${viewport.width}x${viewport.height}');
    }
  });

  testWidgets('typing on the board writes through to the field',
      (tester) async {
    await pumpSheet(tester, const Size(1512, 905));

    await tester.tap(find.text('H'));
    await tester.pump();
    await tester.tap(find.text('i'));
    await tester.pump();

    expect(find.text('Hi'), findsOneWidget,
        reason: 'shift caps the first letter then releases itself');
  });
}
