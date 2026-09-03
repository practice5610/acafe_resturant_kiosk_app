import 'package:acafe_customer/features/pos/widgets/pos_pin_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host({
  required Future<bool> Function(String) onSubmit,
  int pinLength = 4,
  double width = 600,
}) {
  return MaterialApp(
    home: Scaffold(
      // Mirrors PosLoginScreen: the card is centred and scrolls only when the
      // viewport is shorter than it.
      body: SingleChildScrollView(
        child: Center(
          child: SizedBox(
            width: width,
            child: PosPinCard(pinLength: pinLength, onSubmit: onSubmit),
          ),
        ),
      ),
    ),
  );
}

int filledDots(WidgetTester tester) => tester
    .widgetList<PosPinDot>(find.byType(PosPinDot))
    .where((d) => d.filled)
    .length;

/// The card is 688px tall at full size, so the default 800x600 test surface
/// puts the confirm button below the fold and taps miss it.
Future<void> pumpCard(
  WidgetTester tester, {
  required Future<bool> Function(String) onSubmit,
  int pinLength = 4,
  double width = 600,
  Size surface = const Size(900, 1000),
}) async {
  tester.view.physicalSize = surface;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
      host(onSubmit: onSubmit, pinLength: pinLength, width: width));
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pump();
}

void main() {
  testWidgets('renders the design: wordmark, title, keypad, confirm',
      (tester) async {
    await pumpCard(tester, onSubmit: (_) async => true);

    expect(find.text('Enter Personal PIN'), findsOneWidget);
    expect(find.text('VERIFY & LOGIN'), findsOneWidget);
    for (final d in ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0']) {
      expect(find.text(d), findsOneWidget, reason: 'key $d missing');
    }
  });

  testWidgets('digits fill the boxes and backspace removes the last',
      (tester) async {
    await pumpCard(tester, onSubmit: (_) async => true);

    expect(filledDots(tester), 0);

    await tapKey(tester, '1');
    await tapKey(tester, '2');
    await tester.pumpAndSettle();
    expect(filledDots(tester), 2);

    // Backspace is the only keypad key that renders an SVG icon.
    await tester.tap(find.byType(SvgPicture).last);
    await tester.pumpAndSettle();
    expect(filledDots(tester), 1);
  });

  testWidgets('confirm is disabled until the PIN is complete', (tester) async {
    await pumpCard(tester, onSubmit: (_) async => true);

    Opacity confirmOpacity() => tester.widget<Opacity>(
          find.ancestor(
            of: find.text('VERIFY & LOGIN'),
            matching: find.byType(Opacity),
          ).last,
        );

    expect(confirmOpacity().opacity, 0.4);

    await tapKey(tester, '1');
    await tapKey(tester, '2');
    await tapKey(tester, '3');
    await tester.pumpAndSettle();
    expect(confirmOpacity().opacity, 0.4, reason: '3 of 4 digits');

    await tapKey(tester, '4');
    await tester.pumpAndSettle();
    expect(confirmOpacity().opacity, 1.0, reason: 'complete');
  });

  testWidgets('a complete PIN is handed to onSubmit exactly once',
      (tester) async {
    final submitted = <String>[];
    await pumpCard(tester, onSubmit: (pin) async {
      submitted.add(pin);
      return true;
    });

    for (final d in ['9', '1', '3', '7']) {
      await tapKey(tester, d);
    }
    await tester.pumpAndSettle();

    // Entering the last digit must NOT auto-submit — the design has an
    // explicit confirm button, unlike the kiosk manager modal.
    expect(submitted, isEmpty);

    await tester.tap(find.text('VERIFY & LOGIN'));
    await tester.pumpAndSettle();
    expect(submitted, ['9137']);
  });

  testWidgets('a rejected PIN shakes the card and clears the entry',
      (tester) async {
    await pumpCard(tester, onSubmit: (_) async => false);

    for (final d in ['1', '1', '1', '1']) {
      await tapKey(tester, d);
    }
    await tester.pumpAndSettle();
    expect(filledDots(tester), 4);

    await tester.tap(find.text('VERIFY & LOGIN'));
    await tester.pump();

    // Mid-shake the card is displaced from centre.
    await tester.pump(const Duration(milliseconds: 80));
    final shifted = tester
        .widgetList<Transform>(find.byType(Transform))
        .any((t) => t.transform.getTranslation().x.abs() > 1);
    expect(shifted, isTrue, reason: 'card should shake on reject');

    await tester.pumpAndSettle();
    expect(filledDots(tester), 0, reason: 'entry should clear after reject');
  });

  testWidgets('an accepted PIN neither shakes nor clears', (tester) async {
    await pumpCard(tester, onSubmit: (_) async => true);

    for (final d in ['1', '2', '3', '4']) {
      await tapKey(tester, d);
    }
    await tester.pumpAndSettle();

    await tester.tap(find.text('VERIFY & LOGIN'));
    await tester.pumpAndSettle();

    expect(filledDots(tester), 4, reason: 'host navigates away; card holds');
  });

  testWidgets('hardware keyboard digits, backspace, and enter work',
      (tester) async {
    final submitted = <String>[];
    await pumpCard(tester, onSubmit: (pin) async {
      submitted.add(pin);
      return true;
    });

    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.sendKeyEvent(LogicalKeyboardKey.numpad3);
    await tester.pump();
    expect(filledDots(tester), 3);

    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(filledDots(tester), 2);

    await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
    await tester.pump();
    expect(filledDots(tester), 4);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(submitted, ['1234']);
  });

  testWidgets('the row-4 spacer is present but not interactive',
      (tester) async {
    await pumpCard(tester, onSubmit: (_) async => true);
    // It occupies a grid cell (so the keypad is 12 cells) but cannot be hit.
    expect(find.byType(IgnorePointer), findsWidgets);
    expect(find.text(','), findsNothing);
  });

  testWidgets('renders at six digits without overflowing', (tester) async {
    await pumpCard(tester, onSubmit: (_) async => true, pinLength: 6);
    expect(tester.takeException(), isNull);
  });

  group('responsive', () {
    for (final width in <double>[1920, 1366, 1080, 800, 460, 360]) {
      testWidgets('no overflow at ${width.toInt()}px wide', (tester) async {
        await pumpCard(tester,
            onSubmit: (_) async => true,
            width: width,
            surface: Size(width, 1200));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('caps at the 460 board and never inflates past it',
        (tester) async {
      await pumpCard(tester,
          onSubmit: (_) async => true,
          width: 1200,
          surface: const Size(1400, 1000));

      final card = tester.getSize(find.byKey(PosPinCard.surfaceKey));
      expect(card.width, 460, reason: 'caps at the design board');
    });
  });
}
