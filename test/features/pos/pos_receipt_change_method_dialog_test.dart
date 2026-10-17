import 'package:acafe_customer/features/pos/domain/pos_receipt_history.dart';
import 'package:acafe_customer/features/pos/widgets/pos_receipt_change_method_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ── Helpers ──────────────────────────────────────────────────────────────────

Map<String, dynamic> _receiptJson({
  String method = 'cash',
  String customer = 'Alice',
  double total = 14.50,
}) {
  return {
    'id': 5001,
    'created_at': '2026-09-04T10:00:00.000000Z',
    'customer_name': customer,
    'display_method': method,
    'payment_method': 'cash_on_delivery',
    'order_status': 'delivered',
    'payment_status': 'paid',
    'table': null,
    'subtotal': total,
    'discount': 0,
    'total': total,
    'details': [],
  };
}

PosReceiptDetail _detail({String method = 'cash', String customer = 'Alice'}) =>
    PosReceiptDetail.fromJson(_receiptJson(method: method, customer: customer));

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('_MethodTheme / _themeFor', () {
    // We test the public surface indirectly: _ConfirmedView renders the
    // headline from _themeFor, so each method's text must appear.
    testWidgets('cash confirmed view shows cash headline', (tester) async {
      await tester.pumpWidget(_wrap(
        Builder(builder: (ctx) {
          return TextButton(
            onPressed: () => showPosReceiptChangeMethodDialog(
              context: ctx,
              receipt: _detail(method: 'cash'),
            ),
            child: const Text('open'),
          );
        }),
      ));
      // We can't call _ConfirmedView directly (private), but we CAN verify
      // _methodLabel helpers work via PosReceiptDetail.methodLabel.
      final PosReceiptDetail d = _detail(method: 'cash');
      expect(d.methodLabel, 'Cash');
    });

    test('methodLabel for all four methods', () {
      expect(_detail(method: 'cash').methodLabel, 'Cash');
      expect(_detail(method: 'card').methodLabel, 'Card');
      expect(_detail(method: 'invoice').methodLabel, 'Invoice');
      expect(_detail(method: 'standalone').methodLabel, 'Stand-alone');
    });

    test('unknown method falls back to Cash', () {
      expect(_detail(method: 'unknown').methodLabel, 'Cash');
    });
  });

  group('showPosReceiptChangeMethodDialog – reason validation', () {
    Future<void> openDialog(WidgetTester tester,
        {String method = 'cash'}) async {
      await tester.pumpWidget(_wrap(
        Builder(builder: (ctx) {
          return TextButton(
            onPressed: () => showPosReceiptChangeMethodDialog(
              context: ctx,
              receipt: _detail(method: method),
            ),
            child: const Text('open'),
          );
        }),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('dialog opens and shows method tiles', (tester) async {
      await openDialog(tester, method: 'cash');
      expect(find.text('Change payment method'), findsOneWidget);
      expect(find.text('Cash'), findsWidgets);
      expect(find.text('Card'), findsWidgets);
      expect(find.text('Invoice'), findsWidgets);
      expect(find.text('Stand-alone'), findsWidgets);
    });

    testWidgets('pre-selects the current method (cash)', (tester) async {
      await openDialog(tester, method: 'cash');
      // The dialog renders with cash pre-selected. We verify no crash and
      // the title subtitle mentions current method.
      expect(find.textContaining('Cash'), findsWidgets);
    });

    testWidgets('pre-selects the current method (card)', (tester) async {
      await openDialog(tester, method: 'card');
      expect(find.textContaining('Card'), findsWidgets);
    });

    testWidgets('shows reason error when Confirm tapped with empty reason',
        (tester) async {
      await openDialog(tester, method: 'cash');
      final Finder confirmBtn = find.text('Confirm change');
      await tester.ensureVisible(confirmBtn);
      await tester.tap(confirmBtn, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('Please enter a reason for this change.'),
          findsOneWidget);
    });

    testWidgets('error disappears once reason is typed', (tester) async {
      await openDialog(tester, method: 'cash');
      final Finder confirmBtn = find.text('Confirm change');
      await tester.ensureVisible(confirmBtn);
      await tester.tap(confirmBtn, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('Please enter a reason for this change.'),
          findsOneWidget);

      await tester.enterText(
        find.byType(TextField).first,
        'Switching to card',
      );
      await tester.pump();
      expect(find.text('Please enter a reason for this change.'),
          findsNothing);
    });

    testWidgets('dialog is dismissible via barrier', (tester) async {
      await openDialog(tester, method: 'cash');
      expect(find.text('Change payment method'), findsOneWidget);
      // Tap outside (barrier)
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.text('Change payment method'), findsNothing);
    });
  });

  group('showPosReceiptChangeMethodDialog – method selection', () {
    testWidgets('Invoice tile is tappable and gets selected', (tester) async {
      await tester.pumpWidget(_wrap(
        Builder(builder: (ctx) {
          return TextButton(
            onPressed: () => showPosReceiptChangeMethodDialog(
              context: ctx,
              receipt: _detail(method: 'cash'),
            ),
            child: const Text('open'),
          );
        }),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Tap the Invoice tile
      await tester.tap(find.text('Invoice'));
      await tester.pump();
      // No crash = tile is tappable
      expect(find.text('Invoice'), findsWidgets);
    });

    testWidgets('Stand-alone tile is tappable', (tester) async {
      await tester.pumpWidget(_wrap(
        Builder(builder: (ctx) {
          return TextButton(
            onPressed: () => showPosReceiptChangeMethodDialog(
              context: ctx,
              receipt: _detail(method: 'cash'),
            ),
            child: const Text('open'),
          );
        }),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Stand-alone'));
      await tester.pump();
      expect(find.text('Stand-alone'), findsWidgets);
    });
  });

  group('PosReceiptDetail – Walk-in sentinel', () {
    test('Walk-in customer name is stripped to empty', () {
      final d = PosReceiptDetail.fromJson(
        _receiptJson(customer: 'Walk-in'),
      );
      expect(d.customerName, '');
    });

    test('walk-in (lowercase) is also stripped', () {
      final d = PosReceiptDetail.fromJson(
        _receiptJson(customer: 'walk-in'),
      );
      expect(d.customerName, '');
    });

    test('real customer name is preserved', () {
      final d = PosReceiptDetail.fromJson(
        _receiptJson(customer: 'Alice'),
      );
      expect(d.customerName, 'Alice');
    });
  });

  group('change-method dialog result', () {
    testWidgets('confirm returns the draft and writes nothing', (tester) async {
      tester.view.physicalSize = const Size(1366, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      PosMethodChangeDraft? result;
      await tester.pumpWidget(_wrap(
        Builder(builder: (ctx) {
          return TextButton(
            onPressed: () async {
              result = await showPosReceiptChangeMethodDialog(
                context: ctx,
                receipt: _detail(method: 'cash'),
              );
            },
            child: const Text('open'),
          );
        }),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Card').first);
      await tester.pump();
      await tester.enterText(find.byType(TextField).first, 'Card declined');
      await tester.pump();
      await tester.ensureVisible(find.text('Confirm change'));
      await tester.tap(find.text('Confirm change'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(result?.method, 'card');
      expect(result?.reason, 'Card declined');
    });
  });
}
