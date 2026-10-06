import 'package:acafe_customer/features/pos/widgets/pos_complete_confirmation_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A tap on the dimmed area outside the card closes the confirmation, resolving
/// to "not confirmed" -- the same as Cancel. The card itself must swallow taps
/// so tapping inside it never dismisses.
void main() {
  Future<bool?> openAndGet(WidgetTester tester, {required Offset tapAt}) async {
    bool? result = true;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) {
          return Center(
            child: ElevatedButton(
              onPressed: () async {
                result = await PosCompleteConfirmationDialog.show(
                  context,
                  heading: 'Log out this terminal?',
                  confirmLabel: 'Log Out',
                  compact: true,
                );
              },
              child: const Text('open'),
            ),
          );
        }),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Log out this terminal?'), findsOneWidget);

    await tester.tapAt(tapAt);
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('a tap outside the card dismisses it', (tester) async {
    final result = await openAndGet(tester, tapAt: const Offset(8, 8));
    expect(find.text('Log out this terminal?'), findsNothing);
    expect(result, isNull);
  });

  testWidgets('tapping the heading inside the card keeps it open',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) {
          return Center(
            child: ElevatedButton(
              onPressed: () => PosCompleteConfirmationDialog.show(
                context,
                heading: 'Log out this terminal?',
                confirmLabel: 'Log Out',
                compact: true,
              ),
              child: const Text('open'),
            ),
          );
        }),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Log out this terminal?'));
    await tester.pumpAndSettle();

    expect(find.text('Log out this terminal?'), findsOneWidget,
        reason: 'a tap inside the card must not dismiss it');
  });
}
