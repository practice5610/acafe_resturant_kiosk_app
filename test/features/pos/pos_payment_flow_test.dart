import 'dart:async';

import 'package:acafe_customer/common/models/api_response_model.dart';
import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/di_container.dart' show sl;
import 'package:acafe_customer/features/kiosk/domain/kiosk_payment_service.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_place_order.dart';
import 'package:acafe_customer/features/pos/domain/pos_checkout.dart';
import 'package:acafe_customer/features/pos/domain/pos_invoice_repo.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipt_history.dart';
import 'package:acafe_customer/features/pos/domain/pos_standalone_repo.dart';
import 'package:acafe_customer/features/pos/widgets/pos_invoice_panel.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipt_send_repo.dart';
import 'package:acafe_customer/features/pos/domain/pos_refund_repo.dart';
import 'package:acafe_customer/features/pos/domain/pos_refund_session.dart';
import 'package:acafe_customer/features/pos/screens/pos_payment_selection_screen.dart';
import 'package:acafe_customer/features/pos/screens/pos_refund_screen.dart';
import 'package:acafe_customer/features/pos/widgets/pos_receipt_dialog.dart';
import 'package:acafe_customer/features/pos/widgets/pos_receipt_line.dart';
import 'package:acafe_customer/features/pos/domain/pos_sale_session.dart';
import 'package:acafe_customer/features/pos/domain/pos_split_by_item_repo.dart';
import 'package:acafe_customer/features/pos/domain/pos_split_repo.dart';
import 'package:acafe_customer/features/pos/widgets/pos_keypad.dart';
import 'package:acafe_customer/features/pos/widgets/pos_declined_card.dart';
import 'package:acafe_customer/features/pos/widgets/pos_payment_method_card.dart';
import 'package:acafe_customer/features/pos/widgets/pos_payment_method_selector.dart';
import 'package:acafe_customer/features/pos/widgets/pos_pay_shell.dart';
import 'package:acafe_customer/features/pos/widgets/pos_split_by_item_panel.dart';
import 'package:acafe_customer/features/pos/widgets/pos_standalone_panel.dart';
import 'package:acafe_customer/features/pos/widgets/pos_split_summary_panel.dart';
import 'package:acafe_customer/features/pos/widgets/pos_waiting_card.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pos_payment_audit_golden_test.dart';

/// Walks the payment flows through the real [PosPaymentSelectionScreen],
/// against fakes that answer like the Laravel controllers (same validations,
/// same response shapes). Nothing here talks to a network.
///
/// The Dylan € 19.00 ticket: Oat Milk Matcha 6, Vanilla Matcha Latte 6,
/// Mango Matcha 7.

// ── Fakes ──────────────────────────────────────────────────────────────────

ApiResponseModel _ok(Map<String, dynamic> data) =>
    ApiResponseModel.withSuccess(Response<dynamic>(
      requestOptions: RequestOptions(path: ''),
      statusCode: 200,
      data: data,
    ));

int _cents(num v) => (v * 100).round();

/// The terminal: approves every charge unless told otherwise. With [hold] a
/// charge waits (the waiting card stays up) until [release] or a cancel.
class FakeTerminal implements KioskPaymentService {
  final List<double> charged = [];
  final List<String> keys = [];
  KioskPaymentStatus answer = KioskPaymentStatus.paid;
  bool hold = false;
  Completer<KioskPaymentResult>? _pending;

  @override
  Future<KioskPaymentResult> pay({
    required double amount,
    required String idempotencyKey,
  }) {
    charged.add(amount);
    keys.add(idempotencyKey);
    if (hold) {
      _pending = Completer<KioskPaymentResult>();
      return _pending!.future;
    }
    return Future.value(
        KioskPaymentResult(answer, paymentRef: 'tx-${charged.length}'));
  }

  void release([KioskPaymentStatus? status]) {
    final Completer<KioskPaymentResult>? pending = _pending;
    _pending = null;
    pending?.complete(KioskPaymentResult(status ?? answer,
        paymentRef: 'tx-${charged.length}'));
  }

  @override
  Future<void> cancel() async => release(KioskPaymentStatus.canceled);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// `SplitPaymentController::record`: 422 above what is still owed; a
/// replayed reference returns the same snapshot without a second row.
class FakeSplitRepo implements PosSplitRepo {
  double grandTotal = 19;

  /// Backend-needs B3: the snapshot carries each payment's id.
  bool withIds = false;

  /// The next record fails as a dropped connection would: nothing saved.
  bool failNext = false;
  final List<Map<String, dynamic>> payments = [];
  final List<double> rejected = [];
  final List<String> references = [];

  int get _paidCents =>
      payments.fold(0, (a, p) => a + _cents(p['paid_amount'] as double));

  Map<String, dynamic> _snapshot(int orderId) {
    final int left = _cents(grandTotal) - _paidCents;
    return {
      'order_id': orderId,
      'grand_total': grandTotal,
      'payments': payments,
      'paid': _paidCents / 100,
      'remaining': left / 100,
      'fully_paid': left == 0,
    };
  }

  @override
  Future<ApiResponseModel> record({
    required int orderId,
    required String paidWith,
    required double paidAmount,
    required int deviceId,
    required String reference,
    String? transactionReference,
  }) async {
    references.add(reference);
    if (failNext) {
      failNext = false;
      return ApiResponseModel.withError('Connection lost');
    }
    if (payments.any((p) => p['reference'] == reference)) {
      return _ok(_snapshot(orderId)..['replayed'] = true);
    }
    final int remaining = _cents(grandTotal) - _paidCents;
    if (_cents(paidAmount) <= 0 || _cents(paidAmount) > remaining) {
      rejected.add(paidAmount);
      return ApiResponseModel.withError('Amount exceeds remaining balance.');
    }
    payments.add({
      if (withIds) 'id': 100 + payments.length + 1,
      'seq': payments.length + 1,
      'paid_with': paidWith,
      'paid_amount': paidAmount,
      'reference': reference,
    });
    return _ok(_snapshot(orderId)..['replayed'] = false);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// `SplitByItemController::payItems`: one guest's items recorded as a paid
/// group; rejects an item already paid and more than the remaining balance;
/// idempotent on the reference. Response shape as the controller's.
class FakeSbiRepo implements PosSplitByItemRepo {
  double grandTotal = 19;
  bool withIds = false;
  bool failNext = false;
  List<Map<String, dynamic>> groups = [];

  /// Each saved payment: (item ids joined, method, amount).
  final List<(String, String, double)> pays = [];
  final List<String> rejected = [];

  Map<String, dynamic> _snapshot(int orderId) {
    final int paid =
        groups.fold(0, (a, g) => a + _cents(g['amount'] as double));
    final int left = _cents(grandTotal) - paid;
    return {
      'order_id': orderId,
      'grand_total': grandTotal,
      'paid': paid / 100,
      'remaining': (left < 0 ? 0 : left) / 100,
      'fully_paid': left <= 0,
      'groups': groups,
    };
  }

  @override
  Future<ApiResponseModel> payItems({
    required int orderId,
    required int deviceId,
    required List<int> itemIds,
    required double amount,
    required String paidWith,
    required String reference,
    String? transactionReference,
  }) async {
    if (failNext) {
      failNext = false;
      return ApiResponseModel.withError('Connection lost');
    }
    if (groups.any((g) => g['reference'] == reference)) {
      return _ok(_snapshot(orderId)..['replayed'] = true);
    }
    final Set<int> paidIds = {
      for (final g in groups) ...(g['item_ids'] as List).cast<int>(),
    };
    if (itemIds.any(paidIds.contains)) {
      rejected.add(reference);
      return ApiResponseModel.withError('Item already paid.');
    }
    final int paid =
        groups.fold(0, (a, g) => a + _cents(g['amount'] as double));
    final int remaining = _cents(grandTotal) - paid;
    if (_cents(amount) <= 0 || _cents(amount) > remaining) {
      rejected.add(reference);
      return ApiResponseModel.withError('The payment exceeds the remaining balance.');
    }
    pays.add((itemIds.join(','), paidWith, amount));
    groups.add({
      if (withIds) 'id': 200 + groups.length + 1,
      'seq': groups.length + 1,
      'amount': amount,
      'item_ids': itemIds,
      'paid_with': paidWith,
      'status': 'succeeded',
      'reference': reference,
    });
    return _ok(_snapshot(orderId)..['replayed'] = false);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// `RefundController`: `create` reserves the whole remaining balance of the
/// source (a split row by `partial_payment_id`, a group by `split_group_id`)
/// as `pending`; `confirm` settles it; `list` reports the ledger.
class FakeRefundRepo implements PosRefundRepo {
  FakeRefundRepo(this.splits, this.groups);

  /// The paid sources, read from the split fakes like the controller reads
  /// `order_partial_payments` / `order_split_groups`.
  final FakeSplitRepo splits;
  final FakeSbiRepo groups;
  final List<Map<String, dynamic>> refunds = [];
  final List<Map<String, dynamic>> created = [];
  final List<Map<String, dynamic>> confirmed = [];

  @override
  Future<ApiResponseModel> list({
    required int orderId,
    required int deviceId,
  }) async =>
      _ok({
        'refundable_remaining': 19.0,
        'refunds': [for (final r in refunds) Map<String, dynamic>.from(r)],
      });

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
    created.add({
      'partial_payment_id': partialPaymentId,
      'split_group_id': splitGroupId,
      'items_json': itemsJson,
    });
    final int? id = partialPaymentId ?? splitGroupId;
    final String key = partialPaymentId != null
        ? 'partial_payment_id'
        : splitGroupId != null
            ? 'split_group_id'
            : 'order';
    // A single-payment order (the Receipts entry): its paid total, card.
    final Map<String, dynamic> source = partialPaymentId != null
        ? splits.payments.firstWhere((p) => p['id'] == id)
        : splitGroupId != null
            ? groups.groups.firstWhere((g) => g['id'] == id)
            : {'amount': 19.0, 'paid_with': 'card'};
    final double paid =
        (source['paid_amount'] ?? source['amount'] as num).toDouble();
    final int reserved = refunds
        .where((r) => key == 'order' ? r.containsKey('order') : r[key] == id)
        .fold(0, (a, r) => a + _cents(r['amount'] as double));
    final int left = _cents(paid) - reserved;
    if (left <= 0) {
      return ApiResponseModel.withError('This payment is already fully refunded.');
    }
    refunds.add({
      key: id ?? orderId,
      'amount': left / 100,
      'status': 'pending',
      'refund_seq': refunds.length + 1,
    });
    return _ok({
      'refund_id': refunds.length,
      'refund_seq': refunds.length,
      'amount': left / 100,
      'method': source['paid_with'],
    });
  }

  @override
  Future<ApiResponseModel> confirm({
    required int orderId,
    required int refundSeq,
    required String method,
    required String reference,
    required int deviceId,
    String? approvalCode,
  }) async {
    confirmed.add({'refund_seq': refundSeq, 'method': method});
    refunds[refundSeq - 1]['status'] = 'succeeded';
    return _ok({'status': 'succeeded'});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// `ReceiptController::send`.
class FakeReceiptSendRepo implements PosReceiptSendRepo {
  final List<(int, String)> sent = [];

  @override
  Future<ApiResponseModel> send({
    required int orderId,
    required String method,
    String? email,
    required int deviceId,
    required String reference,
  }) async {
    sent.add((orderId, method));
    return _ok({'status': 'sent', 'replayed': false});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// `InvoiceController::create` / `StandalonePaymentController::record`.
class FakeInvoiceRepo implements PosInvoiceRepo {
  final List<Map<String, dynamic>> created = [];
  final List<String> references = [];
  bool failNext = false;

  @override
  Future<ApiResponseModel> create(Map<String, dynamic> payload) async {
    references.add('${payload['reference']}');
    if (failNext) {
      failNext = false;
      return ApiResponseModel.withError('Connection lost');
    }
    if (created.any((c) => c['reference'] == payload['reference'])) {
      return _ok({'invoice_id': 1, 'replayed': true});
    }
    created.add(payload);
    return _ok({'invoice_id': 1, 'replayed': false});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeStandaloneRepo implements PosStandaloneRepo {
  final List<(int, String?)> recorded = [];
  final List<String> references = [];
  bool failNext = false;

  @override
  Future<ApiResponseModel> record({
    required int orderId,
    required int deviceId,
    required String reference,
    String? approvalCode,
  }) async {
    references.add(reference);
    if (failNext) {
      failNext = false;
      return ApiResponseModel.withError('Connection lost');
    }
    recorded.add((orderId, approvalCode));
    return _ok({'payment_status': 'paid', 'replayed': false});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ── Harness ────────────────────────────────────────────────────────────────

late FakeTerminal terminal;
late FakeSplitRepo splitRepo;
late FakeSbiRepo sbiRepo;
late FakeRefundRepo refundRepo;
late FakeReceiptSendRepo receiptRepo;
late FakeInvoiceRepo invoiceRepo;
late FakeStandaloneRepo standaloneRepo;
late List<double> placed;

/// Per placed order: did it go up as a split (placed before fully paid)?
late List<bool> placedAsSplit;
bool placeFails = false;

/// When set, the order post waits for it — a slow network.
Completer<void>? placeGate;

void _register<T extends Object>(T instance) {
  if (sl.isRegistered<T>()) sl.unregister<T>();
  sl.registerSingleton<T>(instance);
}

void setUpFlowFakes() {
  terminal = FakeTerminal();
  splitRepo = FakeSplitRepo();
  sbiRepo = FakeSbiRepo();
  refundRepo = FakeRefundRepo(splitRepo, sbiRepo);
  receiptRepo = FakeReceiptSendRepo();
  invoiceRepo = FakeInvoiceRepo();
  standaloneRepo = FakeStandaloneRepo();
  placed = [];
  placedAsSplit = [];
  placeFails = false;
  placeGate = null;
  _register<KioskPaymentService>(terminal);
  _register<PosSplitRepo>(splitRepo);
  _register<PosSplitByItemRepo>(sbiRepo);
  _register<PosRefundRepo>(refundRepo);
  _register<PosReceiptSendRepo>(receiptRepo);
  _register<PosInvoiceRepo>(invoiceRepo);
  _register<PosStandaloneRepo>(standaloneRepo);
  debugPosPlaceOrder = (context,
      {required amount,
      paymentRef,
      bringChangeAmount,
      tipAmountOverride,
      splitPayment = false}) async {
    if (placeGate != null) await placeGate!.future;
    if (placeFails) {
      return const KioskPlaceResult(success: false, message: 'Server down');
    }
    placed.add(amount);
    placedAsSplit.add(splitPayment);
    // The order the split controllers see is the one just placed.
    splitRepo.grandTotal = amount;
    sbiRepo.grandTotal = amount;
    return const KioskPlaceResult(success: true, orderId: '27362');
  };
}

void tearDownFlowFakes() {
  debugPosPlaceOrder = null;
  for (final unregister in [
    () => sl.unregister<KioskPaymentService>(),
    () => sl.unregister<PosSplitRepo>(),
    () => sl.unregister<PosSplitByItemRepo>(),
    () => sl.unregister<PosRefundRepo>(),
    () => sl.unregister<PosReceiptSendRepo>(),
    () => sl.unregister<PosInvoiceRepo>(),
    () => sl.unregister<PosStandaloneRepo>(),
  ]) {
    try {
      unregister();
    } catch (_) {}
  }
}

Future<void> tap(WidgetTester tester, Finder f) async {
  // On a short window the panes stack into one lazily built scroll: bring
  // the control in, as an operator would scroll to it.
  if (f.evaluate().isEmpty) {
    final Finder panes = find.descendant(
        of: find.byType(PosPayThreePane), matching: find.byType(Scrollable));
    if (panes.evaluate().isNotEmpty) {
      await tester.scrollUntilVisible(f, 200, scrollable: panes.first);
    }
  }
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

/// For steps with a looping animation (the terminal's waiting dots), where
/// nothing ever settles.
Future<void> tapAndPump(WidgetTester tester, Finder f) async {
  await tester.tap(f);
  for (int i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The sticky bar's label and whether it is live.
(String, bool) bar(WidgetTester tester) {
  final PosPayPillBar b = tester.widget<PosPayPillBar>(find.byType(PosPayPillBar));
  return (b.label, b.onConfirm != null);
}

Future<void> confirmBar(WidgetTester tester) async {
  tester.widget<PosPayPillBar>(find.byType(PosPayPillBar)).onConfirm!();
  await tester.pumpAndSettle();
}

/// [confirmBar] when the next step animates forever (the terminal card).
Future<void> confirmBarNoSettle(WidgetTester tester) async {
  tester.widget<PosPayPillBar>(find.byType(PosPayPillBar)).onConfirm!();
  for (int i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> keys(WidgetTester tester, String typed) async {
  for (final String k in typed.split('')) {
    await tap(
        tester,
        find.descendant(
            of: find.byType(PosKeypad), matching: find.text(k)));
  }
}

Future<void> backspace(WidgetTester tester, [int times = 1]) async {
  for (int i = 0; i < times; i++) {
    tester.widget<PosKeypad>(find.byType(PosKeypad)).onBackspace();
    await tester.pumpAndSettle();
  }
}

Finder inPane(Type pane, String text) =>
    find.descendant(of: find.byType(pane), matching: find.text(text));

Future<void> openChooser(WidgetTester tester) async {
  await pumpPaymentScreen(tester, routed: true);
  await tap(tester, find.text('Split by item'));
}

void main() {
  setUpAll(loadPaymentFonts);
  setUp(() {
    PosSaleSession.instance.reset();
    setUpFlowFakes();
  });
  tearDown(() {
    tearDownFlowFakes();
    PosSaleSession.instance.reset();
  });

  Finder snack(String text) =>
      find.descendant(of: find.byType(SnackBar), matching: find.textContaining(text));

  group('2a · split chooser (frame 13)', () {
    testWidgets('"Split by item" opens the chooser; nothing is placed yet',
        (tester) async {
      await openChooser(tester);
      expect(find.byType(PosSplitChooserPanel), findsOneWidget);
      expect(find.text('DIVIDE BETWEEN GUESTS'), findsOneWidget);
      expect(bar(tester), ('Continue', true));
      expect(placed, isEmpty);
    });

    testWidgets('re-tapping the active row, or Card, closes it', (tester) async {
      await openChooser(tester);
      await tap(tester, find.text('Split by item'));
      expect(find.byType(PosSplitChooserPanel), findsNothing);
      expect(bar(tester).$1, 'Confirm Payment');

      await tap(tester, find.text('Split by item'));
      await tap(tester, find.text('Card'));
      expect(find.byType(PosSplitChooserPanel), findsNothing);
      expect(placed, isEmpty);
    });

    testWidgets('Continue is instant and places nothing', (tester) async {
      await openChooser(tester);
      await confirmBar(tester);
      expect(find.byType(PosSplitByItemPanel), findsOneWidget);
      expect(placed, isEmpty, reason: 'placed with the first payment');
    });
  });

  group('2a · split by item: each guest pays for their own items', () {
    Future<void> pick(WidgetTester tester, List<String> names) async {
      for (final n in names) {
        await tap(tester, inPane(PosSplitByItemPanel, n));
      }
    }

    testWidgets('two guests, card: one order, two payments, then home',
        (tester) async {
      await openChooser(tester);
      await confirmBar(tester);
      expect(find.text('SELECT ITEMS FOR PAYMENT 1'), findsOneWidget);
      expect(bar(tester), ('Start Payment 1 · € 0.00', false));

      await pick(tester, ['Oat Milk Matcha', 'Vanilla Matcha Latte']);
      expect(bar(tester), ('Start Payment 1 · € 12.00', true));
      await confirmBar(tester);

      // Charged first, then the order placed once, then the guest's items.
      expect(terminal.charged, [12]);
      expect(placed, [19]);
      // Placed part-paid, so admin lists it only once the last guest pays.
      expect(placedAsSplit, [true]);
      expect(sbiRepo.pays, [('0,1', 'card', 12.0)]);
      expect(find.text('Split Payment 1 Successful'), findsOneWidget);

      await tap(tester, find.text('Start next payment'));
      // What is still unpaid comes ticked; the paid items are inert "Paid".
      expect(find.text('SELECT ITEMS FOR PAYMENT 2'), findsOneWidget);
      expect(find.text('Paid'), findsNWidgets(2));
      expect(bar(tester), ('Start Payment 2 · € 7.00', true));
      await confirmBar(tester);

      expect(placed, [19], reason: 'never placed twice');
      expect(terminal.charged, [12, 7]);
      expect(sbiRepo.pays.last, ('2', 'card', 7.0));
      // The "Order Paid" card is disabled for now: a settled order goes
      // straight home.
      expect(find.text('Order Paid'), findsNothing);
      expect(find.text('ROUTE /pos-home'), findsOneWidget);
    });

    testWidgets('three guests: guest 2 pays for one of the remaining items',
        (tester) async {
      await openChooser(tester);
      await confirmBar(tester);
      await pick(tester, ['Oat Milk Matcha']);
      await confirmBar(tester);
      await tap(tester, find.text('Start next payment'));

      // Both remaining items come ticked; guest 2 only had the latte.
      expect(bar(tester), ('Start Payment 2 · € 13.00', true));
      await pick(tester, ['Mango Matcha']);
      expect(bar(tester), ('Start Payment 2 · € 6.00', true));
      expect(find.text('€ 7.00 remaining after this payment'), findsOneWidget);
      await tap(tester, inPane(PosPayWithRow, 'Cash'));
      await confirmBar(tester); // the cash step
      await confirmBar(tester); // Exact
      await tap(tester, find.text('Start next payment'));

      expect(find.text('SELECT ITEMS FOR PAYMENT 3'), findsOneWidget);
      expect(bar(tester), ('Start Payment 3 · € 7.00', true));
      await confirmBar(tester);

      expect(sbiRepo.pays, [
        ('0', 'card', 6.0),
        ('1', 'cash', 6.0),
        ('2', 'card', 7.0),
      ]);
      expect(placed, [19]);
      // The "Order Paid" card is disabled for now: a settled order goes
      // straight home.
      expect(find.text('Order Paid'), findsNothing);
      expect(find.text('ROUTE /pos-home'), findsOneWidget);
    });

    testWidgets('every item in one payment: the whole total, then home',
        (tester) async {
      await openChooser(tester);
      await confirmBar(tester);
      await pick(tester, ['Oat Milk Matcha', 'Vanilla Matcha Latte', 'Mango Matcha']);
      expect(bar(tester), ('Start Payment 1 · € 19.00', true));
      await confirmBar(tester);
      expect(sbiRepo.pays.single, ('0,1,2', 'card', 19.0));
      // The "Order Paid" card is disabled for now: a settled order goes
      // straight home.
      expect(find.text('Order Paid'), findsNothing);
      expect(find.text('ROUTE /pos-home'), findsOneWidget);
    });

    testWidgets('a declined card places nothing; Try Again pays once',
        (tester) async {
      await openChooser(tester);
      await confirmBar(tester);
      await pick(tester, ['Oat Milk Matcha', 'Vanilla Matcha Latte']);
      terminal.answer = KioskPaymentStatus.failed;
      await confirmBar(tester);
      expect(find.text('Try Again'), findsOneWidget);
      expect(placed, isEmpty, reason: 'no order for a declined card');

      terminal.answer = KioskPaymentStatus.paid;
      await tap(tester, find.text('Try Again'));
      expect(terminal.charged, [12, 12]);
      expect(terminal.keys.toSet(), hasLength(1),
          reason: 'the retry is the same payment to the terminal');
      expect(sbiRepo.pays, [('0,1', 'card', 12.0)]);
      expect(placed, [19]);
    });

    testWidgets('cash (frame 15): tender, change due, records the share',
        (tester) async {
      await openChooser(tester);
      await confirmBar(tester);
      await pick(tester, ['Oat Milk Matcha', 'Vanilla Matcha Latte']);
      await tap(tester, inPane(PosPayWithRow, 'Cash'));
      expect(bar(tester), ('Start Payment 1 · € 12.00', true));
      await confirmBar(tester);

      // The tender step: nothing taken or placed yet, Exact by default.
      expect(sbiRepo.pays, isEmpty);
      expect(placed, isEmpty);
      expect(find.text('PAYMENT 1 · AMOUNT DUE € 12.00'), findsOneWidget);
      expect(find.text('By item · Oat Milk Matcha, Vanilla Matcha Latte'),
          findsOneWidget);
      expect(bar(tester), ('Confirm Payment · € 12.00', true));

      // Too little: the bar stays off.
      await backspace(tester, 6);
      await keys(tester, '10');
      expect(bar(tester).$2, isFalse);

      await tap(tester, find.text('€ 20'));
      expect(
          find.descendant(
              of: find.byKey(const Key('change-due')),
              matching: find.text('€ 8.00')),
          findsOneWidget);
      await confirmBar(tester);

      expect(terminal.charged, isEmpty, reason: 'cash never hits the terminal');
      expect(sbiRepo.pays, [('0,1', 'cash', 12.0)]);
      expect(find.text('Split Payment 1 Successful'), findsOneWidget);
    });

    testWidgets('cash step: Card on its toggle goes back to the item picker',
        (tester) async {
      await openChooser(tester);
      await confirmBar(tester);
      await pick(tester, ['Oat Milk Matcha']);
      await tap(tester, inPane(PosPayWithRow, 'Cash'));
      await confirmBar(tester);
      expect(find.textContaining('AMOUNT DUE'), findsOneWidget);
      await tap(
          tester,
          find.descendant(
              of: find.byType(PosSplitMethodToggle),
              matching: find.text('Card')));
      expect(find.textContaining('AMOUNT DUE'), findsNothing);
      expect(find.text('SELECT ITEMS FOR PAYMENT 1'), findsOneWidget);
      expect(bar(tester), ('Start Payment 1 · € 6.00', true));
    });

    testWidgets('rows read as frame 21: add-ons under the name, "× 2"',
        (tester) async {
      await pumpPaymentScreen(tester, routed: true, lines: [
        ...figmaTicket(),
        figmaLine('Iced Americano', 3.5, id: 4),
        figmaLine('Cappuccino', 3.8, added: const ['Oat milk'], id: 5)
          ..quantity = 2,
      ]);
      await tap(tester, find.text('Split by item'));
      await confirmBar(tester);
      expect(inPane(PosSplitByItemPanel, 'Cappuccino × 2'), findsOneWidget);
      expect(inPane(PosSplitByItemPanel, '€ 7.60'), findsOneWidget);
      expect(
          inPane(PosSplitByItemPanel,
              'Mango purée · Coconut milk · Honey drizzle · Chia seeds · No whipped cream'),
          findsOneWidget);
      // No add-ons: the unit.
      expect(inPane(PosSplitByItemPanel, 'Cup'), findsOneWidget);
    });

  });

  group('2a · custom amount (frame 19)', () {
    Future<void> openCustom(WidgetTester tester) async {
      await openChooser(tester);
      await tap(tester, find.text('Custom amount'));
      await confirmBar(tester);
    }

    testWidgets('validates: no zero, no overpay, currency decimals',
        (tester) async {
      await openCustom(tester);
      expect(placed, isEmpty);
      expect(find.text('GUEST 1 · CUSTOM AMOUNT'), findsOneWidget);
      expect(find.text('Enter the amount this guest pays'), findsOneWidget);
      expect(bar(tester), ('Start Payment 1', false));

      await keys(tester, '0');
      expect(bar(tester), ('Start Payment 1', false), reason: 'zero');

      await backspace(tester);
      await keys(tester, '25');
      expect(bar(tester), ('Enter at most € 19.00', false),
          reason: 'over € 19.00');

      await backspace(tester, 2);
      await keys(tester, '8.555');
      expect(bar(tester), ('Start Payment 1 · € 8.55', true),
          reason: 'a third decimal is ignored');
      await backspace(tester);
      await keys(tester, '0');
      expect(bar(tester), ('Start Payment 1 · € 8.50', true));
    });

    testWidgets('two guests, card then cash with change, then home',
        (tester) async {
      await openCustom(tester);
      await keys(tester, '8.5');
      await confirmBar(tester);
      expect(terminal.charged, [8.5]);
      expect(placed, [19]);
      expect(splitRepo.payments.single['paid_amount'], 8.5);
      await tap(tester, find.text('Start next payment'));

      // Still the "Split by item" path in the OTHER group.
      expect(find.text('Guest 1'), findsOneWidget);
      expect(find.text('GUEST 2 · CUSTOM AMOUNT'), findsOneWidget);

      await tap(
          tester,
          find.descendant(
              of: find.byType(PosSplitMethodToggle),
              matching: find.text('Cash')));
      await tap(tester, find.text('€ 20'));
      // Records what is owed (10.50), not the tender.
      expect(bar(tester), ('Start Payment 2 · € 10.50', true));
      await confirmBar(tester);
      expect(splitRepo.rejected, isEmpty);
      expect(splitRepo.payments.last['paid_amount'], 10.5);
      expect(placed, [19]);
      // The "Order Paid" card is disabled for now: a settled order goes
      // straight home.
      expect(find.text('Order Paid'), findsNothing);
      expect(find.text('ROUTE /pos-home'), findsOneWidget);
    });
  });

  group('split by payment', () {
    Future<void> openSplit(WidgetTester tester) async {
      await pumpPaymentScreen(tester, routed: true);
      await tap(tester, find.text('Split by payment'));
    }

    Future<void> toCash(WidgetTester tester) => tap(
        tester,
        find.descendant(
            of: find.byType(PosSplitMethodToggle),
            matching: find.text('Cash')));

    testWidgets('€ 19: € 12 on card, the rest in cash — one order, then home',
        (tester) async {
      await openSplit(tester);
      expect(placed, isEmpty, reason: 'entering the mode places nothing');
      await keys(tester, '12');
      expect(bar(tester), ('Start Payment 1', true));
      await confirmBar(tester);
      expect(terminal.charged, [12]);
      expect(placed, [19]);
      // Placed part-paid, so admin lists it only once the last payment is in.
      expect(placedAsSplit, [true]);
      expect(splitRepo.payments.single['paid_amount'], 12.0);
      expect(find.text('Split Payment 1 Successful'), findsOneWidget);
      await tap(tester, find.text('Start next payment'));

      expect(find.text('PAYMENT 2'), findsOneWidget);
      await toCash(tester);
      await tap(tester, find.text('Exact'));
      await confirmBar(tester);
      expect(terminal.charged, [12], reason: 'cash never hits the terminal');
      expect(splitRepo.payments.last['paid_with'], 'cash');
      expect(splitRepo.payments.last['paid_amount'], 7.0);
      expect(placed, [19], reason: 'never placed twice');
      // The "Order Paid" card is disabled for now: a settled order goes
      // straight home.
      expect(find.text('Order Paid'), findsNothing);
      expect(find.text('ROUTE /pos-home'), findsOneWidget);
    });

    testWidgets('card above the remaining says so and is blocked',
        (tester) async {
      await openSplit(tester);
      await keys(tester, '25');
      expect(bar(tester), ('Enter at most € 19.00', false));
      await backspace(tester, 2);
      await keys(tester, '9');
      expect(bar(tester), ('Start Payment 1', true));
      await confirmBar(tester);
      expect(terminal.charged, [9]);
      expect(splitRepo.payments.single['paid_amount'], 9.0);
    });

    testWidgets('cash over-tender records only what is owed (was a 422)',
        (tester) async {
      await openSplit(tester);
      await toCash(tester);
      await tap(tester, find.text('€ 50'));
      await confirmBar(tester);
      expect(splitRepo.rejected, isEmpty);
      expect(splitRepo.payments.single['paid_amount'], 19.0);
      // The "Order Paid" card is disabled for now: a settled order goes
      // straight home.
      expect(find.text('Order Paid'), findsNothing);
      expect(find.text('ROUTE /pos-home'), findsOneWidget);
    });

    testWidgets('switching away before paying leaves no order behind',
        (tester) async {
      await openSplit(tester);
      await tap(tester, inPane(PosPaymentMethodSelector, 'Card'));
      await tap(tester, find.text('Split by payment'));
      await tap(tester, find.text('Split by item'));
      await tap(tester, find.text('Split by payment'));
      expect(placed, isEmpty, reason: 'was one kitchen order per tap');
      expect(find.text('PAYMENT 1'), findsOneWidget);
    });

    testWidgets('the waiting card quotes the payment, not the order total',
        (tester) async {
      await openSplit(tester);
      await keys(tester, '9');
      terminal.hold = true;
      await confirmBarNoSettle(tester);
      expect(
          find.descendant(
              of: find.byType(PosWaitingCard), matching: find.text('€ 9.00')),
          findsOneWidget);
      terminal.release();
      await tester.pumpAndSettle();
      expect(find.text('Split Payment 1 Successful'), findsOneWidget);
    });

    testWidgets('after a cancelled charge the next one can still be cancelled',
        (tester) async {
      await openSplit(tester);
      await keys(tester, '9');
      terminal.hold = true;
      await confirmBarNoSettle(tester);
      await tapAndPump(tester, find.text('Cancel Transaction'));
      await tester.pumpAndSettle();
      expect(find.byType(PosWaitingCard), findsNothing);
      expect(placed, isEmpty);

      await confirmBarNoSettle(tester);
      final PosWaitingCard card =
          tester.widget<PosWaitingCard>(find.byType(PosWaitingCard));
      expect(card.cancelling, isFalse, reason: 'was stuck on "Cancelling..."');
      expect(card.onCancel, isNotNull);
      terminal.release();
      await tester.pumpAndSettle();
    });

    testWidgets('card approved but the save fails: saving again never re-charges',
        (tester) async {
      await openSplit(tester);
      await keys(tester, '9');
      splitRepo.failNext = true;
      await confirmBar(tester);
      expect(terminal.charged, [9]);
      expect(splitRepo.payments, isEmpty);
      expect(snack('the card will not be charged again'), findsOneWidget);
      expect(bar(tester), ('Save Payment 1 · € 9.00', true));

      // The amount is what was charged: the keypad no longer changes it.
      await keys(tester, '5');
      expect(bar(tester), ('Save Payment 1 · € 9.00', true));

      await confirmBar(tester);
      expect(terminal.charged, [9], reason: 'not charged again');
      expect(placed, [19], reason: 'not placed again');
      expect(splitRepo.payments.single['paid_amount'], 9.0);
      expect(splitRepo.references.toSet(), hasLength(1),
          reason: 'the retry replays the same reference');
      expect(find.text('Split Payment 1 Successful'), findsOneWidget);
    });

    testWidgets('card approved but the order fails to place: retry places once',
        (tester) async {
      await openSplit(tester);
      await keys(tester, '9');
      placeFails = true;
      await confirmBar(tester);
      expect(terminal.charged, [9]);
      expect(placed, isEmpty);
      expect(bar(tester), ('Save Payment 1 · € 9.00', true));

      placeFails = false;
      await confirmBar(tester);
      expect(terminal.charged, [9]);
      expect(placed, [19]);
      expect(splitRepo.payments.single['paid_amount'], 9.0);
    });

    testWidgets('once a payment is in, the method and the ticket are locked',
        (tester) async {
      await openSplit(tester);
      await keys(tester, '9');
      await confirmBar(tester);
      await tap(tester, find.text('Start next payment'));

      await tap(tester, inPane(PosPaymentMethodSelector, 'Cash'));
      expect(snack('Finish this split payment first'), findsOneWidget);
      expect(find.text('PAYMENT 2'), findsOneWidget);

      tester
          .widget<PosReceiptLine>(find.byType(PosReceiptLine).first)
          .onIncrement!();
      await tester.pumpAndSettle();
      expect(find.text('€ 10.00'), findsWidgets,
          reason: 'still € 10.00 to pay: the ticket did not change');
    });

    testWidgets('Back mid-split asks first; Stay keeps it, Leave ends the sale',
        (tester) async {
      await openSplit(tester);
      await keys(tester, '9');
      await confirmBar(tester);
      await tap(tester, find.text('Start next payment'));

      await tester.tap(find.descendant(
          of: find.byType(PosPayBackRow), matching: find.byType(InkWell)));
      await tester.pumpAndSettle();
      expect(find.text('Leave this split payment?'), findsOneWidget);
      expect(
          find.text('€ 9.00 is paid and € 10.00 is still open. The order '
              'stays saved as partially paid.'),
          findsOneWidget);
      await tap(tester, find.text('Stay'));
      expect(find.text('PAYMENT 2'), findsOneWidget);

      await tester.tap(find.descendant(
          of: find.byType(PosPayBackRow), matching: find.byType(InkWell)));
      await tester.pumpAndSettle();
      await tap(tester, find.text('Leave'));
      expect(find.text('ROUTE /pos-home'), findsOneWidget);
      expect(placed, [19]);
    });
  });

  group('2b · Refund one payment from its row', () {
    Finder pill() => find.descendant(
        of: find.byType(PosSplitPaidRow), matching: find.text('Refund'));

    Future<void> payFirstSplit(WidgetTester tester,
        {required String amount, bool cash = false}) async {
      await pumpPaymentScreen(tester, routed: true);
      await tap(tester, find.text('Split by payment'));
      if (cash) {
        await tap(
            tester,
            find.descendant(
                of: find.byType(PosSplitMethodToggle),
                matching: find.text('Cash')));
      }
      await keys(tester, amount);
      await confirmBar(tester);
      await tap(tester, find.text('Start next payment'));
    }

    testWidgets('no payment id from the backend (today): no Refund pill',
        (tester) async {
      await payFirstSplit(tester, amount: '9');
      expect(find.byType(PosSplitPaidRow), findsOneWidget);
      expect(pill(), findsNothing);
    });

    testWidgets('card: 29 → create → 27 → confirm → 30 → back to the sale',
        (tester) async {
      splitRepo.withIds = true;
      await payFirstSplit(tester, amount: '9');
      expect(pill(), findsOneWidget);
      await tap(tester, pill());

      // Frame 29, before anything is created.
      expect(find.text('Refund Payment 1?'), findsOneWidget);
      expect(find.text('Refund € 9.00'), findsOneWidget);
      expect(refundRepo.created, isEmpty);
      await tapAndPump(tester, find.text('Refund € 9.00'));

      // Only that payment: by its partial_payment_id, no items.
      expect(refundRepo.created.single, {
        'partial_payment_id': 101,
        'split_group_id': null,
        'items_json': null,
      });
      expect(find.text('Waiting for card on terminal...'), findsOneWidget);
      await tapAndPump(tester, find.text('Confirm Refund'));
      await tester.pumpAndSettle();
      expect(refundRepo.confirmed.single, {'refund_seq': 1, 'method': 'card'});

      expect(find.text('Payment 1 Refunded'), findsOneWidget);
      expect(find.text('€ 9.00'), findsWidgets);
      await tap(tester, find.text('Back to order'));

      // The sale is still there, on the next payment.
      expect(find.text('PAYMENT 2'), findsOneWidget);
      expect(find.byType(PosSplitPaidRow), findsOneWidget);
      expect(splitRepo.payments, hasLength(1));
    });

    testWidgets('cash: one tap on "Refund € X" pays it out', (tester) async {
      splitRepo.withIds = true;
      await payFirstSplit(tester, amount: '5', cash: true);
      await tap(tester, pill());
      expect(find.text('Cash · hand the refund to the customer from the drawer'),
          findsOneWidget);
      await tap(tester, find.text('Refund € 5.00'));
      expect(refundRepo.created, hasLength(1));
      expect(refundRepo.confirmed.single, {'refund_seq': 1, 'method': 'cash'});
      expect(find.text('Payment 1 Refunded'), findsOneWidget);
    });

    testWidgets('Cancel on 29 goes back and creates nothing', (tester) async {
      splitRepo.withIds = true;
      await payFirstSplit(tester, amount: '9');
      await tap(tester, pill());
      await tap(tester, find.text('Cancel'));
      expect(find.text('PAYMENT 2'), findsOneWidget);
      expect(refundRepo.created, isEmpty);
    });

    testWidgets('a refunded payment quotes € 0.00 and cannot be refunded again',
        (tester) async {
      splitRepo.withIds = true;
      await payFirstSplit(tester, amount: '5', cash: true);
      await tap(tester, pill());
      await tap(tester, find.text('Refund € 5.00'));
      await tap(tester, find.text('Back to order'));
      await tap(tester, pill());
      expect(find.text('This payment has already been refunded.'),
          findsOneWidget);
      final PosPaymentCardButton refund = tester.widget<PosPaymentCardButton>(
          find.widgetWithText(PosPaymentCardButton, 'Refund € 0.00'));
      expect(refund.onTap, isNull);
    });

    testWidgets('split by item: refunds the group by split_group_id',
        (tester) async {
      sbiRepo.withIds = true;
      await openChooser(tester);
      await confirmBar(tester);
      await tap(tester, inPane(PosSplitByItemPanel, 'Oat Milk Matcha'));
      await tap(tester, inPane(PosSplitByItemPanel, 'Vanilla Matcha Latte'));
      await tap(tester, inPane(PosPayWithRow, 'Cash'));
      await confirmBar(tester);
      await confirmBar(tester);
      await tap(tester, find.text('Start next payment'));

      await tap(tester, pill());
      expect(find.text('Cash · Oat Milk Matcha, Vanilla Matcha Latte'),
          findsOneWidget);
      await tap(tester, find.text('Refund € 12.00'));
      expect(refundRepo.created.single['split_group_id'], 201);
      expect(refundRepo.created.single['partial_payment_id'], isNull);
      expect(find.text('Payment 1 Refunded'), findsOneWidget);
    });
  });

  group('refunds from Receipts · 2d Receipt on the success card', () {
    Future<void> openRefund(WidgetTester tester) async {
      PosRefundSession.instance
        ..reset()
        ..order = PosReceiptDetail(
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
      addTearDown(PosRefundSession.instance.reset);
      await pumpPaymentApp(tester, (_) => const PosRefundScreen(),
          routed: true);
      await tester.pumpAndSettle();
    }

    Future<void> tick(WidgetTester tester, List<String> names) async {
      for (final n in names) {
        await tap(
            tester,
            find.descendant(
                of: find.byType(PosReceiptLine), matching: find.text(n)));
      }
    }

    Future<void> toMethod(WidgetTester tester, List<String> items) async {
      await tick(tester, items);
      await tap(tester, find.text('Customer changed mind'));
      await confirmBar(tester);
      expect(find.text('REFUND METHOD'), findsOneWidget);
    }

    testWidgets('partial (one item): card → 27 → 28 → Receipt → print → next',
        (tester) async {
      await openRefund(tester);
      await toMethod(tester, ['Oat Milk Matcha']);
      // Frame 26 opens on the original payment.
      expect(PosRefundSession.instance.refundMethod.value, 'card');
      // The backend refunds the whole remaining balance (R1 / B1).
      expect(bar(tester), ('Confirm refund · € 19.00', true));
      await confirmBarNoSettle(tester);
      expect(refundRepo.created.single['items_json'], isNull);
      expect(find.text('Waiting for card on terminal...'), findsOneWidget);
      await tapAndPump(tester, find.text('Confirm Refund'));
      await tester.pumpAndSettle();
      expect(refundRepo.confirmed.single['method'], 'card');

      // Frame 28: Receipt above Next order.
      expect(find.text('Refund Successful'), findsOneWidget);
      expect(tester.getTopLeft(find.text('Receipt')).dy,
          lessThan(tester.getTopLeft(find.text('Next order')).dy));
      await tap(tester, find.text('Receipt'));
      expect(find.byType(PosReceiptDialog), findsOneWidget);
      await tap(tester, find.text('Print'));
      await tap(tester, find.text('Print receipt'));
      expect(receiptRepo.sent, [(27362, 'print')]);
      expect(find.text('ROUTE /pos-home'), findsOneWidget);
    });

    testWidgets('full (every item): Next order goes to the counter',
        (tester) async {
      await openRefund(tester);
      await toMethod(
          tester, ['Oat Milk Matcha', 'Vanilla Matcha Latte', 'Mango Matcha']);
      await confirmBarNoSettle(tester);
      await tapAndPump(tester, find.text('Confirm Refund'));
      await tester.pumpAndSettle();
      await tap(tester, find.text('Next order'));
      expect(find.text('ROUTE /pos-home'), findsOneWidget);
      expect(receiptRepo.sent, isEmpty);
    });

    testWidgets('Receipt then "skip" stays on the success card',
        (tester) async {
      await openRefund(tester);
      await toMethod(tester, ['Oat Milk Matcha']);
      await confirmBarNoSettle(tester);
      await tapAndPump(tester, find.text('Confirm Refund'));
      await tester.pumpAndSettle();
      await tap(tester, find.text('Receipt'));
      final PosReceiptDialog dialog =
          tester.widget<PosReceiptDialog>(find.byType(PosReceiptDialog));
      dialog.onSkip();
      await tester.pumpAndSettle();
      expect(find.byType(PosReceiptDialog), findsNothing);
      expect(find.text('Refund Successful'), findsOneWidget);
    });

    testWidgets('Cash on a card order is refunded as cash (was sent as card)',
        (tester) async {
      await openRefund(tester);
      await toMethod(tester, ['Oat Milk Matcha']);
      await tap(tester, find.text('Cash'));
      expect(find.text('Hand the cash to the customer from the drawer.'),
          findsOneWidget);
      await confirmBar(tester);
      expect(find.text('Cash Refund'), findsOneWidget);
      await tap(tester, find.text('Refund € 19.00'));
      expect(refundRepo.confirmed.single['method'], 'cash');
      expect(find.text('Refund Successful'), findsOneWidget);
    });
  });

  group('card · cash · invoice · stand-alone → success → Receipt / Next order',
      () {
    void receiptAboveNext(WidgetTester tester) => expect(
        tester.getTopLeft(find.text('Receipt')).dy,
        lessThan(tester.getTopLeft(find.text('Next order')).dy));

    testWidgets('card: charged once → straight to the counter',
        (tester) async {
      await pumpPaymentScreen(tester, routed: true);
      expect(bar(tester), ('Confirm Payment', true));
      await confirmBar(tester);
      expect(terminal.charged, [19]);
      expect(placed, [19]);
      expect(placedAsSplit, [false]);
      // The "Order Paid" card is disabled for now: a settled order goes
      // straight home.
      expect(find.text('Order Paid'), findsNothing);
      expect(find.text('ROUTE /pos-home'), findsOneWidget);
    });

    testWidgets('cash with change: € 20 on € 19 → € 1.00 → counter',
        (tester) async {
      await pumpPaymentScreen(tester,
          routed: true, method: PosPaymentMethod.cash);
      await tap(tester, find.text('€ 20'));
      expect(
          find.descendant(
              of: find.byKey(const Key('change-due')),
              matching: find.text('€ 1.00')),
          findsOneWidget);
      await confirmBar(tester);
      expect(terminal.charged, isEmpty);
      expect(placed, [19]);
      // The "Order Paid" card is disabled for now: a settled order goes
      // straight home.
      expect(find.text('Order Paid'), findsNothing);
      expect(find.text('ROUTE /pos-home'), findsOneWidget);
    });

    testWidgets('going home holds the last frame: the ticket never empties',
        (tester) async {
      await pumpPaymentScreen(tester, routed: true);
      tester.widget<PosPayPillBar>(find.byType(PosPayPillBar)).onConfirm!();
      final Finder home = find.text('ROUTE /pos-home');
      for (int i = 0; i < 20 && home.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(home, findsOneWidget);

      // Mid-slide: the cart is already cleared, but the payment screen is
      // still the picture it last painted, not a live (empty) ticket.
      final Finder pay = find.byType(PosPaymentSelectionScreen);
      expect(pay, findsOneWidget);
      expect(find.descendant(of: pay, matching: find.byType(RawImage)),
          findsOneWidget);
      expect(find.descendant(of: pay, matching: find.byType(PosPayReceiptCard)),
          findsNothing);

      await tester.pumpAndSettle();
      expect(pay, findsNothing);
      expect(home, findsOneWidget);
    });

    testWidgets('cash short of the total cannot be confirmed', (tester) async {
      await pumpPaymentScreen(tester,
          routed: true, method: PosPaymentMethod.cash);
      await tap(tester, find.text('€ 10'));
      expect(bar(tester), ('Confirm Payment', false));
    });

    testWidgets('invoice: company name required → Invoice created → counter',
        (tester) async {
      await pumpPaymentScreen(tester, routed: true);
      await tap(tester, find.text('Invoice'));
      expect(placed, isEmpty, reason: 'placed at Confirm Payment');
      expect(bar(tester), ('Confirm Payment', false));
      await tester.enterText(
          find.descendant(
              of: find.byType(PosInvoicePanel),
              matching: find.byType(TextField)).first,
          'Acafe B.V.');
      await tester.pumpAndSettle();
      expect(bar(tester), ('Confirm Payment', true));
      await confirmBar(tester);
      expect(placed, [19]);
      expect(placedAsSplit, [false]);
      expect(invoiceRepo.created.single['company_name'], 'Acafe B.V.');
      expect(invoiceRepo.created.single['reference'], 'pos-inv-27362');
      expect(find.text('Invoice created'), findsOneWidget);
      receiptAboveNext(tester);
      await tap(tester, find.text('Next order'));
      expect(find.text('ROUTE /pos-home'), findsOneWidget);
    });

    testWidgets('stand-alone: recorded with the approval code → Receipt (print)',
        (tester) async {
      await pumpPaymentScreen(tester, routed: true);
      await tap(tester, find.text('Stand-alone'));
      expect(placed, isEmpty, reason: 'placed at Confirm Payment');
      await tester.enterText(
          find.descendant(
              of: find.byType(PosStandalonePanel),
              matching: find.byType(TextField)),
          '123456');
      await tester.pumpAndSettle();
      await confirmBar(tester);
      expect(placed, [19]);
      expect(placedAsSplit, [false]);
      expect(standaloneRepo.recorded.single, (27362, '123456'));
      expect(standaloneRepo.references, ['pos-sa-27362']);
      expect(find.text('Payment confirmed'), findsOneWidget);
      receiptAboveNext(tester);
      await tap(tester, find.text('Receipt'));
      await tap(tester, find.text('Print'));
      await tap(tester, find.text('Print receipt'));
      expect(receiptRepo.sent, [(27362, 'print')]);
      expect(find.text('ROUTE /pos-home'), findsOneWidget);
    });
  });

  group('invoice · stand-alone: instant, no flash, nothing left behind', () {
    Future<void> fillCompany(WidgetTester tester) async {
      await tester.enterText(
          find.descendant(
              of: find.byType(PosInvoicePanel),
              matching: find.byType(TextField)).first,
          'Acafe B.V.');
      await tester.pumpAndSettle();
    }

    for (final String option in ['Invoice', 'Stand-alone']) {
      testWidgets('$option opens in the same frame — the keypad never flashes',
          (tester) async {
        await pumpPaymentScreen(tester,
            routed: true, method: PosPaymentMethod.cash);
        expect(find.byType(PosKeypad), findsOneWidget);
        // A slow network: had the tap placed the order, the cash pane would
        // still be up while it waited.
        placeGate = Completer<void>();
        await tester.tap(find.text(option));
        await tester.pump();
        expect(find.byType(PosKeypad), findsNothing);
        expect(
            find.byType(option == 'Invoice'
                ? PosInvoicePanel
                : PosStandalonePanel),
            findsOneWidget);
        expect(placed, isEmpty);
        placeGate!.complete();
        await tester.pumpAndSettle();
      });
    }

    testWidgets('switching between the options places nothing', (tester) async {
      await pumpPaymentScreen(tester, routed: true);
      await tap(tester, find.text('Invoice'));
      await tap(tester, find.text('Stand-alone'));
      await tap(tester, find.text('Invoice'));
      await tap(tester, inPane(PosPaymentMethodSelector, 'Card'));
      await tap(tester, find.text('Stand-alone'));
      expect(placed, isEmpty, reason: 'was one kitchen order per tap');
    });

    testWidgets('a failed invoice is retried on the same order and reference',
        (tester) async {
      await pumpPaymentScreen(tester, routed: true);
      await tap(tester, find.text('Invoice'));
      await fillCompany(tester);
      invoiceRepo.failNext = true;
      await confirmBar(tester);
      expect(snack('Tap Confirm Payment to try again'), findsOneWidget);
      expect(find.byType(PosInvoicePanel), findsOneWidget);
      expect(placed, [19]);

      // The order is sent: switching method is no longer possible.
      await tap(tester, inPane(PosPaymentMethodSelector, 'Card'));
      expect(snack('already sent'), findsOneWidget);

      await confirmBar(tester);
      expect(placed, [19], reason: 'not placed twice');
      expect(invoiceRepo.references, ['pos-inv-27362', 'pos-inv-27362']);
      expect(invoiceRepo.created, hasLength(1));
      expect(find.text('Invoice created'), findsOneWidget);
    });

    testWidgets('a failed stand-alone save is retried on the same order',
        (tester) async {
      await pumpPaymentScreen(tester, routed: true);
      await tap(tester, find.text('Stand-alone'));
      standaloneRepo.failNext = true;
      await confirmBar(tester);
      expect(snack('Tap Confirm Payment to try again'), findsOneWidget);
      await confirmBar(tester);
      expect(placed, [19]);
      expect(standaloneRepo.references, ['pos-sa-27362', 'pos-sa-27362']);
      expect(standaloneRepo.recorded, hasLength(1));
      expect(find.text('Payment confirmed'), findsOneWidget);
    });

    testWidgets('a declined card leaves Card selected (was deselected)',
        (tester) async {
      await pumpPaymentScreen(tester, routed: true);
      terminal.answer = KioskPaymentStatus.failed;
      await confirmBar(tester);
      tester.widget<PosDeclinedCard>(find.byType(PosDeclinedCard)).onCancel!();
      await tester.pumpAndSettle();
      final PosPaymentMethodCard card = tester.widget<PosPaymentMethodCard>(
          find.byType(PosPaymentMethodCard).first);
      expect(card.method, PosPaymentMethod.card);
      expect(card.selected, isTrue);
    });
  });

  group('stress: the new panes with long text, many rows, five figures', () {
    List<CartModel> longTicket() => [
          for (int i = 0; i < 14; i++)
            figmaLine(
              i.isEven
                  ? 'Ceremonial Grade Uji Matcha Latte with Oat Milk and Extra Vanilla Foam $i'
                  : 'Iced Matcha $i',
              1234.56,
              added: const ['Oat milk', 'Vanilla syrup'],
              id: i + 1,
            ),
        ];

    const sizes = <Size>[Size(1366, 1024), Size(900, 600), Size(768, 1024)];

    for (final size in sizes) {
      final String at = '${size.width.toInt()}x${size.height.toInt()}';

      testWidgets('chooser → custom amount, € 17,283.84 at $at', (tester) async {
        await pumpPaymentScreen(tester,
            routed: true, size: size, lines: longTicket());
        await tap(tester, find.text('Split by item'));
        expect(tester.takeException(), isNull);
        await tap(tester, find.text('Custom amount'));
        await confirmBar(tester);
        expect(tester.takeException(), isNull);
        await keys(tester, '99999');
        expect(bar(tester).$2, isFalse, reason: 'above the remaining');
        await backspace(tester, 5);
        await keys(tester, '12345.67');
        expect(bar(tester), ('Start Payment 1 · € 12,345.67', true));
        expect(tester.takeException(), isNull);
      });

      testWidgets('split by item, 14 long lines, cash step at $at',
          (tester) async {
        await pumpPaymentScreen(tester,
            routed: true, size: size, lines: longTicket());
        await tap(tester, find.text('Split by item'));
        await confirmBar(tester);
        expect(tester.takeException(), isNull);
        expect(find.textContaining('· 0 OF 14'), findsOneWidget);
        final Finder rows = find.descendant(
            of: find.byType(PosSplitByItemPanel),
            matching: find.textContaining('Ceremonial Grade'));
        await tap(tester, rows.first);
        await tap(tester, inPane(PosPayWithRow, 'Cash'));
        await confirmBar(tester);
        expect(find.textContaining('AMOUNT DUE € 1,234.56'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await confirmBar(tester);
        expect(sbiRepo.pays.single.$3, 1234.56);
        expect(tester.takeException(), isNull);
      });

      testWidgets('split by payment with six paid rows at $at', (tester) async {
        await pumpPaymentScreen(tester, routed: true, size: size);
        await tap(tester, find.text('Split by payment'));
        for (int i = 0; i < 6; i++) {
          await keys(tester, '1');
          await confirmBar(tester);
          await tap(tester, find.text('Start next payment'));
        }
        expect(find.byType(PosSplitPaidRow), findsNWidgets(6));
        expect(find.text('PAYMENT 7'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
