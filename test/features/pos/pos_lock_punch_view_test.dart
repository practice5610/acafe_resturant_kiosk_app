import 'package:acafe_customer/features/pos/domain/pos_punch_source.dart';
import 'package:acafe_customer/features/pos/widgets/pos_lock_punch_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A stand-in for the punch API. Returns whatever the test hands it and records
/// what it was asked for, so the inline lock-screen flow can be checked without
/// a real backend. Mirrors the fake in pos_punch_test.dart.
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

Future<void> _pump(
  WidgetTester tester,
  PosPunchSource source, {
  VoidCallback? onBack,
}) async {
  // The PIN card is tall; give the surface room so its keypad is on-screen.
  tester.view.physicalSize = const Size(1200, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PosLockPunchView(
          source: source,
          onBack: onBack ?? () {},
        ),
      ),
    ),
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
  testWidgets('offers two punch actions and a way back to sign in',
      (tester) async {
    await _pump(tester, _FakePunchSource(const PosPunchResult(PosPunchStatus.ok)));

    expect(find.byKey(const Key('pos-lock-punch-in')), findsOneWidget);
    expect(find.byKey(const Key('pos-lock-punch-out')), findsOneWidget);
    expect(find.byKey(const Key('pos-lock-punch-back')), findsOneWidget);
    // No PIN card until a direction is chosen.
    expect(find.text('Enter your PIN'), findsNothing);
  });

  testWidgets('back to sign in calls onBack', (tester) async {
    int backs = 0;
    await _pump(
      tester,
      _FakePunchSource(const PosPunchResult(PosPunchStatus.ok)),
      onBack: () => backs++,
    );

    await tester.tap(find.byKey(const Key('pos-lock-punch-back')));
    await tester.pumpAndSettle();

    expect(backs, 1);
  });

  testWidgets('choosing punch in shows the PIN, and a valid PIN records it',
      (tester) async {
    final source = _FakePunchSource(const PosPunchResult(
      PosPunchStatus.ok,
      direction: 'in',
      message: "You're punched in.",
      staffName: 'Sara',
    ));
    await _pump(tester, source);

    await tester.tap(find.byKey(const Key('pos-lock-punch-in')));
    await tester.pumpAndSettle();
    // The card captions itself: "Punch In" + "Enter your PIN", no logo.
    expect(find.text('Punch In'), findsOneWidget);
    expect(find.text('Enter your PIN'), findsOneWidget);

    await _enterPin(tester, '1234');

    expect(source.lastDirection, 'in');
    expect(source.lastPin, '1234');
    // Back on the tiles, with a success confirmation.
    expect(find.byKey(const Key('pos-punch-result')), findsOneWidget);
    expect(find.text("You're punched in."), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });

  testWidgets('punch out sends the out direction', (tester) async {
    final source = _FakePunchSource(const PosPunchResult(
      PosPunchStatus.ok,
      direction: 'out',
      message: "You're punched out.",
    ));
    await _pump(tester, source);

    await tester.tap(find.byKey(const Key('pos-lock-punch-out')));
    await tester.pumpAndSettle();
    expect(find.text('Punch Out'), findsOneWidget);

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

    await tester.tap(find.byKey(const Key('pos-lock-punch-in')));
    await tester.pumpAndSettle();
    await _enterPin(tester, '9999');

    expect(find.text('That PIN was not recognised.'), findsOneWidget);
    expect(find.byKey(const Key('pos-punch-result')), findsNothing);
  });

  testWidgets('back from the PIN entry returns to the two choices',
      (tester) async {
    int backs = 0;
    await _pump(
      tester,
      _FakePunchSource(const PosPunchResult(PosPunchStatus.ok)),
      onBack: () => backs++,
    );

    await tester.tap(find.byKey(const Key('pos-lock-punch-in')));
    await tester.pumpAndSettle();
    expect(find.text('Enter your PIN'), findsOneWidget);

    // Back from the PIN card steps to the choices, not out to sign in.
    await tester.tap(find.byKey(const Key('pos-lock-punch-back')));
    await tester.pumpAndSettle();

    expect(backs, 0);
    expect(find.text('Enter your PIN'), findsNothing);
    expect(find.byKey(const Key('pos-lock-punch-in')), findsOneWidget);
  });
}
