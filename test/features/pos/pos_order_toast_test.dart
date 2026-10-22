import 'package:acafe_customer/features/pos/widgets/pos_order_toast.dart';
import 'package:acafe_customer/main.dart' show navigatorKey;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('order toast shows bottom-right, never blocks taps, auto-dismisses',
      (tester) async {
    int tapsBehind = 0;

    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      home: Scaffold(
        // A full-screen button sitting UNDER where the toast paints.
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => tapsBehind++,
          child: const SizedBox.expand(),
        ),
      ),
    ));

    showPosOrderToast('Order created successfully');
    await tester.pump(); // insert the entry
    await tester.pump(const Duration(milliseconds: 250)); // fade in

    expect(find.text('Order created successfully'), findsOneWidget);

    // The toast is wrapped in IgnorePointer, so a tap at its exact location
    // falls through to the button behind it — the UI is never blocked.
    expect(
      find.ancestor(
        of: find.text('Order created successfully'),
        matching: find.byType(IgnorePointer),
      ),
      findsOneWidget,
    );
    await tester.tapAt(tester.getCenter(find.text('Order created successfully')));
    await tester.pump();
    expect(tapsBehind, 1, reason: 'the tap reached the control behind the toast');

    // It clears itself without any dismiss action.
    await tester.pumpAndSettle();
    expect(find.text('Order created successfully'), findsNothing);
  });
}
