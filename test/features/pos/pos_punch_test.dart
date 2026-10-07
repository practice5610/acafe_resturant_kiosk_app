import 'package:acafe_customer/features/pos/domain/pos_punch_source.dart';
import 'package:acafe_customer/features/pos/screens/pos_punch_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A stand-in for the punch API. Returns whatever the test hands it and records
/// the direction/PIN it was asked for, so the flow can be checked without a
/// real backend.
class _FakePunchSource implements PosPunchSource {
  _FakePunchSource(this.result);

  PosPunchResult result;
  String? lastDirection;
  String? lastPin;
  int calls = 0;

  @override
  Future<PosPunchResult> punch({
    required String direction,
    required String pin,
  }) async {
    calls++;
    lastDirection = direction;
    lastPin = pin;
    return result;
  }
}

Future<void> _pump(WidgetTester tester, PosPunchSource source) async {
  // The PIN card is tall; give the surface room so its keypad is on-screen.
  tester.view.physicalSize = const Size(1200, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: PosPunchScreen(source: source))),
  );
  await tester.pumpAndSettle();
}

Future<void> _enterPin(WidgetTester tester, String pin) async {
  for (final digit in pin.split('')) {
    await tester.tap(find.text(digit).last);
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('offers two clearly separated punch actions', (tester) async {
    await _pump(tester, _FakePunchSource(const PosPunchResult(PosPunchStatus.ok)));

    expect(find.byKey(const Key('pos-punch-in-action')), findsOneWidget);
    expect(find.byKey(const Key('pos-punch-out-action')), findsOneWidget);
    expect(find.text('Punch In'), findsOneWidget);
    expect(find.text('Punch Out'), findsOneWidget);
  });

  testWidgets('a valid PIN punches in and shows a success confirmation',
      (tester) async {
    final source = _FakePunchSource(const PosPunchResult(
      PosPunchStatus.ok,
      direction: 'in',
      message: "You're punched in.",
      staffName: 'Sara',
    ));
    await _pump(tester, source);

    await tester.tap(find.byKey(const Key('pos-punch-in-action')));
    await tester.pumpAndSettle();
    await _enterPin(tester, '1234');

    expect(source.lastDirection, 'in');
    expect(source.lastPin, '1234');
    expect(find.byKey(const Key('pos-punch-result')), findsOneWidget);
    expect(find.text("You're punched in."), findsOneWidget);
    // A real punch reads as a success.
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });

  testWidgets('a skipped punch is shown as NOT recorded, never a success',
      (tester) async {
    final source = _FakePunchSource(const PosPunchResult(
      PosPunchStatus.skipped,
      direction: 'in',
      message:
          "Your attendance profile isn't set up (no Planday department or shift). Ask a manager.",
    ));
    await _pump(tester, source);

    await tester.tap(find.byKey(const Key('pos-punch-in-action')));
    await tester.pumpAndSettle();
    await _enterPin(tester, '1234');

    expect(find.byKey(const Key('pos-punch-result')), findsOneWidget);
    expect(
      find.text(
          "Your attendance profile isn't set up (no Planday department or shift). Ask a manager."),
      findsOneWidget,
    );
    // Crucially NOT a green success — nothing was recorded.
    expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
  });

  testWidgets('punch out sends the out direction', (tester) async {
    final source = _FakePunchSource(const PosPunchResult(
      PosPunchStatus.ok,
      direction: 'out',
      message: "You're punched out.",
    ));
    await _pump(tester, source);

    await tester.tap(find.byKey(const Key('pos-punch-out-action')));
    await tester.pumpAndSettle();
    await _enterPin(tester, '1234');

    expect(source.lastDirection, 'out');
    expect(find.text("You're punched out."), findsOneWidget);
  });

  testWidgets('a wrong PIN keeps the card up with a note and no confirmation',
      (tester) async {
    final source = _FakePunchSource(const PosPunchResult(
      PosPunchStatus.invalidPin,
      direction: 'in',
      message: 'That PIN was not recognised.',
      attemptsRemaining: 4,
    ));
    await _pump(tester, source);

    await tester.tap(find.byKey(const Key('pos-punch-in-action')));
    await tester.pumpAndSettle();
    await _enterPin(tester, '9999');

    // The note shows in the still-open card; no success/error banner appears.
    expect(find.text('That PIN was not recognised.'), findsOneWidget);
    expect(find.byKey(const Key('pos-punch-result')), findsNothing);
  });

  testWidgets('a Planday failure shows an error state, not a success',
      (tester) async {
    final source = _FakePunchSource(const PosPunchResult(
      PosPunchStatus.failed,
      direction: 'in',
      message: "Couldn't reach the time clock. Your punch was not recorded.",
    ));
    await _pump(tester, source);

    await tester.tap(find.byKey(const Key('pos-punch-in-action')));
    await tester.pumpAndSettle();
    await _enterPin(tester, '1234');

    expect(find.byKey(const Key('pos-punch-result')), findsOneWidget);
    expect(
      find.text("Couldn't reach the time clock. Your punch was not recorded."),
      findsOneWidget,
    );
  });

  testWidgets('offers a way back to the POS', (tester) async {
    await _pump(tester, _FakePunchSource(const PosPunchResult(PosPunchStatus.ok)));

    expect(find.byKey(const Key('pos-punch-back')), findsOneWidget);
  });
}
