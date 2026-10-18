import 'package:acafe_customer/common/models/api_response_model.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:acafe_customer/di_container.dart' show sl;
import 'package:acafe_customer/features/pos/domain/pos_receipt_history.dart';
import 'package:acafe_customer/features/pos/domain/pos_refund_repo.dart';
import 'package:acafe_customer/features/pos/domain/pos_refund_session.dart';
import 'package:acafe_customer/features/pos/screens/pos_refund_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pos_payment_audit_golden_test.dart';

/// Records every refund call and answers like `RefundController`.
class _RecordingRefundRepo extends PosRefundRepo {
  _RecordingRefundRepo(DioClient dio, {required this.ledger, this.failCreate = false})
      : super(dioClient: dio);

  final Map<String, dynamic> ledger;
  final bool failCreate;
  final List<Map<String, dynamic>> creates = [];

  static ApiResponseModel _ok(Map<String, dynamic> data) =>
      ApiResponseModel.withSuccess(Response<dynamic>(
        requestOptions: RequestOptions(path: ''),
        statusCode: 200,
        data: data,
      ));

  @override
  Future<ApiResponseModel> list({required int orderId, required int deviceId}) async =>
      _ok(ledger);

  @override
  Future<ApiResponseModel> create({
    required int orderId,
    required int deviceId,
    required String reference,
    String? reason,
    List<int>? itemsJson,
    int? partialPaymentId,
    int? splitGroupId,
  }) async {
    creates.add({
      'order_id': orderId,
      'reason': reason,
      'items_json': itemsJson,
      'partial_payment_id': partialPaymentId,
      'split_group_id': splitGroupId,
    });
    if (failCreate) {
      return ApiResponseModel.withError('This payment has already been fully refunded.');
    }
    // The backend refunds the whole remaining balance of the source.
    final PosRefundSplit? split = partialPaymentId == null
        ? null
        : PosRefundSession.instance.splits
            .firstWhere((s) => s.id == partialPaymentId);
    return _ok({
      'refund_id': 7,
      'refund_seq': 1,
      'amount': posRefundableAmount(ledger: ledger, split: split),
      'method': split?.method ?? 'card',
    });
  }
}

PosReceiptDetail _order() => PosReceiptDetail(
      id: 27362,
      placedAt: null,
      customerName: 'Dylan',
      table: null,
      method: 'card',
      subtotal: 19,
      discount: 0,
      total: 19,
      orderStatus: 'delivered',
      paymentStatus: 'paid',
      lines: figmaTicket(),
    );

Future<_RecordingRefundRepo> _pumpRefund(
  WidgetTester tester, {
  required Map<String, dynamic> ledger,
  List<PosRefundSplit> splits = const [],
  bool failCreate = false,
}) async {
  final session = PosRefundSession.instance;
  session.reset();
  addTearDown(session.reset);
  session.order = _order();
  session.splits = splits;
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final repo = _RecordingRefundRepo(
    DioClient('http://localhost', null,
        loggingInterceptor: LoggingInterceptor(), sharedPreferences: prefs),
    ledger: ledger,
    failCreate: failCreate,
  );
  if (sl.isRegistered<PosRefundRepo>()) sl.unregister<PosRefundRepo>();
  sl.registerSingleton<PosRefundRepo>(repo);
  addTearDown(() => sl.unregister<PosRefundRepo>());
  await pumpPaymentApp(tester, (_) => const PosRefundScreen());
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pump();
  return repo;
}

Future<void> _tapVisible(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  setUpAll(loadPaymentFonts);

  group('posRefundableAmount (mirrors RefundController::create)', () {
    test('order level: refundable_remaining minus order-level pending', () {
      final double amount = posRefundableAmount(ledger: {
        'refundable_remaining': 19.0,
        'refunds': [
          {'amount': 5.0, 'status': 'pending', 'partial_payment_id': null, 'split_group_id': null},
          {'amount': 2.0, 'status': 'failed', 'partial_payment_id': null, 'split_group_id': null},
        ],
      });
      expect(amount, 14.0);
    });

    test('split: the split amount minus refunds reserved against it', () {
      const split = PosRefundSplit(id: 11, seq: 1, method: 'cash', amount: 12);
      final double amount = posRefundableAmount(split: split, ledger: {
        'refundable_remaining': 19.0,
        'refunds': [
          {'amount': 4.5, 'status': 'succeeded', 'partial_payment_id': 11},
          {'amount': 1.0, 'status': 'pending', 'partial_payment_id': 11},
          {'amount': 3.0, 'status': 'succeeded', 'partial_payment_id': 12},
          {'amount': 9.0, 'status': 'failed', 'partial_payment_id': 11},
        ],
      });
      expect(amount, 6.5);
    });

    test('an already fully refunded source quotes zero, never negative', () {
      const split = PosRefundSplit(id: 11, seq: 1, method: 'cash', amount: 12);
      expect(
        posRefundableAmount(split: split, ledger: {
          'refunds': [
            {'amount': 12.0, 'status': 'succeeded', 'partial_payment_id': 11},
            {'amount': 1.0, 'status': 'pending', 'partial_payment_id': 11},
          ],
        }),
        0,
      );
    });

    test('cents are exact (no float drift)', () {
      expect(
        posRefundableAmount(ledger: {
          'refundable_remaining': 0.3,
          'refunds': [
            {'amount': 0.1, 'status': 'pending', 'partial_payment_id': null, 'split_group_id': null},
          ],
        }),
        0.2,
      );
    });
  });

  group('refund screen quotes what create refunds', () {
    testWidgets('the quote, the bar and the confirmation all name the backend amount',
        (tester) async {
      final repo = await _pumpRefund(tester, ledger: {
        'refundable_remaining': 19.0,
        'refunds': const [],
      });
      // Ticking one €6 line does not change the money: the backend refunds the
      // whole remaining balance.
      PosRefundSession.instance.selectedItemIndices.value = {0};
      await tester.pump();
      expect(find.text('€ 19.00'), findsWidgets);

      await _tapVisible(tester, find.text('Continue to refund method'));
      expect(find.text('Confirm refund · € 19.00'), findsOneWidget);
      await _tapVisible(tester, find.text('Original payment'));
      await _tapVisible(tester, find.text('Confirm refund · € 19.00'));

      // Request payload: the order, the reason, no split source, and no
      // items_json (the backend does not refund by item).
      expect(repo.creates, hasLength(1));
      expect(repo.creates.single['order_id'], 27362);
      expect(repo.creates.single['items_json'], isNull);
      expect(repo.creates.single['partial_payment_id'], isNull);
      // The amount the card asks to confirm is the one create returned, which
      // is the one quoted.
      expect(PosRefundSession.instance.refundAmount.value, 19.0);
      expect(find.text('€ 19.00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a split refund quotes and sends that split only', (tester) async {
      final repo = await _pumpRefund(
        tester,
        ledger: {
          'refundable_remaining': 19.0,
          'refunds': [
            {'amount': 2.0, 'status': 'succeeded', 'partial_payment_id': 11},
          ],
        },
        splits: const [
          PosRefundSplit(id: 11, seq: 1, method: 'cash', amount: 12),
          PosRefundSplit(id: 12, seq: 2, method: 'card', amount: 7),
        ],
      );
      await _tapVisible(tester, find.text('Continue to refund method'));
      final Finder payment1 = find.text('Payment 1');
      await tester.scrollUntilVisible(payment1, 200,
          scrollable: find.byType(Scrollable).first);
      await _tapVisible(tester, payment1);
      expect(find.text('Confirm refund · € 10.00'), findsOneWidget);
      await _tapVisible(tester, find.text('Confirm refund · € 10.00'));
      expect(repo.creates.single['partial_payment_id'], 11);
      expect(PosRefundSession.instance.refundAmount.value, 10.0);
      expect(find.text('Refund € 10.00'), findsOneWidget);
    });

    testWidgets('an API failure shows the error and changes nothing', (tester) async {
      await _pumpRefund(
        tester,
        ledger: {'refundable_remaining': 19.0, 'refunds': const []},
        failCreate: true,
      );
      await _tapVisible(tester, find.text('Continue to refund method'));
      await _tapVisible(tester, find.text('Confirm refund · € 19.00'));
      expect(find.text('This payment has already been fully refunded.'),
          findsOneWidget);
      // Still on the method step; nothing pending.
      expect(find.text('REFUND METHOD'), findsOneWidget);
      expect(PosRefundSession.instance.pendingRefundSeq.value, isNull);
      expect(PosRefundSession.instance.busy.value, isFalse);
    });

    testWidgets('a ledger that fails to load quotes "—", not a guess',
        (tester) async {
      final session = PosRefundSession.instance;
      await _pumpRefund(tester, ledger: const {});
      session.refundLedger.value = null;
      await tester.pump();
      expect(find.text('—'), findsOneWidget);
    });
  });
}
