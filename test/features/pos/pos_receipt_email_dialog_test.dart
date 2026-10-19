import 'package:acafe_customer/common/models/api_response_model.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/di_container.dart' as di;
import 'package:acafe_customer/features/pos/domain/pos_receipt_history.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipt_send_repo.dart';
import 'package:acafe_customer/features/pos/widgets/pos_receipt_email_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubSendRepo implements PosReceiptSendRepo {
  @override
  DioClient get dioClient => throw UnimplementedError();

  @override
  Future<ApiResponseModel> send({
    required int orderId,
    required String method,
    String? email,
    required int deviceId,
    required String reference,
  }) async =>
      ApiResponseModel.withSuccess(null);
}

const _receipt = PosReceiptDetail(
  id: 100014,
  placedAt: null,
  customerName: '',
  table: null,
  method: 'Cash',
  subtotal: 6.5,
  discount: 0,
  total: 6.5,
  orderStatus: 'delivered',
  paymentStatus: 'paid',
  lines: [],
);

/// Home → "Receipts" page → dialog, so a stray second pop would visibly take
/// the Receipts page with it.
Widget _app() => MaterialApp(
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
                        onPressed: () => showPosReceiptEmailDialog(
                          context: receiptsContext,
                          receipt: _receipt,
                          deviceId: 1,
                        ),
                        child: const Text('open-email'),
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

Future<void> _sendEmail(WidgetTester tester) async {
  await tester.pumpWidget(_app());
  await tester.tap(find.text('open-receipts'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('open-email'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), 'guest@example.com');
  await tester.tap(find.text('Send receipt'));
  await tester.pump(); // send resolves
  await tester.pump(const Duration(milliseconds: 300)); // swap settles
}

void main() {
  setUp(() {
    if (!di.sl.isRegistered<PosReceiptSendRepo>()) {
      di.sl.registerLazySingleton<PosReceiptSendRepo>(() => _StubSendRepo());
    }
  });

  tearDown(() {
    if (di.sl.isRegistered<PosReceiptSendRepo>()) {
      di.sl.unregister<PosReceiptSendRepo>();
    }
  });

  testWidgets('success card has no BACK button and fades itself out',
      (tester) async {
    await _sendEmail(tester);

    expect(find.text('Email Sent Successfully'), findsOneWidget);
    expect(find.text('guest@example.com'), findsOneWidget);
    expect(find.text('BACK'), findsNothing);

    // Still up mid-hold.
    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.text('Email Sent Successfully'), findsOneWidget);

    // Past the hold + exit transition: gone, Receipts page untouched.
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();
    expect(find.text('Email Sent Successfully'), findsNothing);
    expect(find.text('receipts-page'), findsOneWidget);
  });

  testWidgets('tapping the card dismisses early', (tester) async {
    await _sendEmail(tester);

    await tester.tap(find.text('Email Sent Successfully'));
    await tester.pumpAndSettle();
    expect(find.text('Email Sent Successfully'), findsNothing);
    expect(find.text('receipts-page'), findsOneWidget);
  });

  testWidgets('backdrop tap during the hold does not double-pop',
      (tester) async {
    await _sendEmail(tester);

    // Close it through the barrier, then let the auto-close timer's deadline
    // pass while the exit transition is still running.
    await tester.tapAt(const Offset(8, 8));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 2000));
    await tester.pumpAndSettle();

    expect(find.text('Email Sent Successfully'), findsNothing);
    expect(find.text('receipts-page'), findsOneWidget);
  });
}
