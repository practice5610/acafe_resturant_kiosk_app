import 'package:acafe_customer/features/pos/domain/pos_receipt_history.dart';
import 'package:acafe_customer/features/pos/widgets/pos_receipt_changes_saved_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _receipt = PosReceiptDetail(
  id: 100017,
  placedAt: null,
  customerName: '',
  table: null,
  method: 'card',
  subtotal: 44,
  discount: 4.4,
  total: 39.6,
  orderStatus: 'delivered',
  paymentStatus: 'paid',
  lines: [],
);

/// Home → "Receipts" page → card, so a stray second pop would visibly take
/// the Receipts page with it.
Widget _app({required VoidCallback onDone}) => MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (receiptsContext) => Scaffold(
                  body: Column(
                    children: [
                      const Text('receipts-page'),
                      TextButton(
                        onPressed: () => showPosReceiptChangesSavedDialog(
                          context: receiptsContext,
                          receipt: _receipt,
                          newTotal: 39.6,
                          onDone: onDone,
                        ),
                        child: const Text('save'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            child: const Text('open-receipts'),
          ),
        ),
      ),
    );

Future<void> _save(WidgetTester tester, {required VoidCallback onDone}) async {
  await tester.pumpWidget(_app(onDone: onDone));
  await tester.tap(find.text('open-receipts'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('save'));
  await tester.pump(); // route pushed
  await tester.pump(const Duration(milliseconds: 300)); // fade-in settles
}

void main() {
  testWidgets('fades in, has no BACK button, and fades itself out',
      (tester) async {
    int done = 0;
    await _save(tester, onDone: () => done++);

    expect(find.text('Changes saved'), findsOneWidget);
    expect(find.text('€ 39.60'), findsOneWidget);
    expect(find.text('BACK TO RECEIPTS'), findsNothing);

    // Still up mid-hold; edit mode not left yet.
    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.text('Changes saved'), findsOneWidget);
    expect(done, 0);

    // Past the hold + exit transition: gone, Receipts page untouched.
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();
    expect(find.text('Changes saved'), findsNothing);
    expect(find.text('receipts-page'), findsOneWidget);
    expect(done, 1);
  });

  testWidgets('tapping the card dismisses early', (tester) async {
    int done = 0;
    await _save(tester, onDone: () => done++);

    await tester.tap(find.text('Changes saved'));
    await tester.pumpAndSettle();
    expect(find.text('Changes saved'), findsNothing);
    expect(find.text('receipts-page'), findsOneWidget);
    expect(done, 1);
  });

  testWidgets('backdrop tap during the hold does not double-pop',
      (tester) async {
    int done = 0;
    await _save(tester, onDone: () => done++);

    // Close it through the barrier, then let the auto-close timer's deadline
    // pass while the exit transition is still running.
    await tester.tapAt(const Offset(8, 8));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 2000));
    await tester.pumpAndSettle();

    expect(find.text('Changes saved'), findsNothing);
    expect(find.text('receipts-page'), findsOneWidget);
    expect(done, 1);
  });
}
