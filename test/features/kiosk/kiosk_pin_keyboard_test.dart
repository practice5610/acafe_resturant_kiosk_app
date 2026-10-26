import 'package:acafe_customer/features/kiosk/widgets/kiosk_pin_entry_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Staff access / Manager PIN pad must accept a physical keyboard, not only
/// on-screen taps: a till usually has a real keyboard and typing is faster.
void main() {
  Future<void> pumpSheet(
    WidgetTester tester, {
    required Future<String?> Function(String pin) onSubmitPin,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: KioskPinEntrySheet(
        title: 'Staff access',
        prompt: 'Enter your staff PIN to switch to POS',
        submitLabel: 'Switch to POS',
        onSubmitPin: onSubmitPin,
      ),
    ));
    await tester.pump();
  }

  testWidgets('typing four digits submits that exact PIN', (tester) async {
    String? submitted;
    await pumpSheet(tester, onSubmitPin: (pin) async {
      submitted = pin;
      return null; // success
    });

    await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.pumpAndSettle();

    expect(submitted, '4321');
  });

  testWidgets('numpad digits work too', (tester) async {
    String? submitted;
    await pumpSheet(tester, onSubmitPin: (pin) async {
      submitted = pin;
      return null;
    });

    await tester.sendKeyEvent(LogicalKeyboardKey.numpad1);
    await tester.sendKeyEvent(LogicalKeyboardKey.numpad2);
    await tester.sendKeyEvent(LogicalKeyboardKey.numpad3);
    await tester.sendKeyEvent(LogicalKeyboardKey.numpad4);
    await tester.pumpAndSettle();

    expect(submitted, '1234');
  });

  testWidgets('Backspace deletes before the four-digit auto-submit',
      (tester) async {
    final List<String> attempts = [];
    await pumpSheet(tester, onSubmitPin: (pin) async {
      attempts.add(pin);
      return 'nope'; // keep the pad open
    });

    await tester.sendKeyEvent(LogicalKeyboardKey.digit9);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit9); // typo
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace); // fix it
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
    await tester.pumpAndSettle();

    expect(attempts, ['9123']);
  });

  testWidgets('never submits more than four digits', (tester) async {
    final List<String> attempts = [];
    await pumpSheet(tester, onSubmitPin: (pin) async {
      attempts.add(pin);
      return 'nope';
    });

    for (final k in [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5, // ignored: pad is full / cleared on miss
    ]) {
      await tester.sendKeyEvent(k);
    }
    await tester.pumpAndSettle();

    expect(attempts.first, '1234');
    expect(attempts.first.length, 4);
  });
}
