import 'package:acafe_customer/common/models/api_response_model.dart';
import 'package:acafe_customer/di_container.dart' show sl;
import 'package:acafe_customer/features/kiosk/domain/kiosk_payment_service.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_place_order.dart';
import 'package:acafe_customer/features/pos/domain/pos_checkout.dart';
import 'package:acafe_customer/features/pos/domain/pos_sale_session.dart';
import 'package:acafe_customer/features/pos/domain/pos_split_by_item_repo.dart';
import 'package:acafe_customer/features/pos/domain/pos_split_repo.dart';
import 'package:acafe_customer/features/pos/widgets/pos_keypad.dart';
import 'package:acafe_customer/features/pos/widgets/pos_pay_shell.dart';
import 'package:acafe_customer/features/pos/widgets/pos_split_by_item_panel.dart';
import 'package:acafe_customer/features/pos/widgets/pos_split_summary_panel.dart';
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

/// The terminal: approves every charge unless told otherwise.
class FakeTerminal implements KioskPaymentService {
  final List<double> charged = [];
  KioskPaymentStatus answer = KioskPaymentStatus.paid;

  @override
  Future<KioskPaymentResult> pay({
    required double amount,
    required String idempotencyKey,
  }) async {
    charged.add(amount);
    return KioskPaymentResult(answer, paymentRef: 'tx-${charged.length}');
  }

  @override
  Future<void> cancel() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// `SplitPaymentController::record`: 422 above what is still owed.
class FakeSplitRepo implements PosSplitRepo {
  double grandTotal = 19;
  final List<Map<String, dynamic>> payments = [];
  final List<double> rejected = [];

  int get _paidCents =>
      payments.fold(0, (a, p) => a + _cents(p['paid_amount'] as double));

  @override
  Future<ApiResponseModel> record({
    required int orderId,
    required String paidWith,
    required double paidAmount,
    required int deviceId,
    required String reference,
    String? transactionReference,
  }) async {
    final int remaining = _cents(grandTotal) - _paidCents;
    if (_cents(paidAmount) <= 0 || _cents(paidAmount) > remaining) {
      rejected.add(paidAmount);
      return ApiResponseModel.withError('Amount exceeds remaining balance.');
    }
    payments.add({
      'seq': payments.length + 1,
      'paid_with': paidWith,
      'paid_amount': paidAmount,
      'reference': reference,
    });
    final int left = _cents(grandTotal) - _paidCents;
    return _ok({
      'order_id': orderId,
      'grand_total': grandTotal,
      'payments': payments,
      'paid': _paidCents / 100,
      'remaining': left / 100,
      'fully_paid': left == 0,
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// `SplitByItemController`: create-groups must sum to the order total (±1
/// cent) and replaces any groups already there; record-payment settles one
/// group and must not exceed it. Response shapes as the controller's.
class FakeSbiRepo implements PosSplitByItemRepo {
  double grandTotal = 19;
  List<Map<String, dynamic>> groups = [];
  final List<List<Map<String, dynamic>>> creates = [];
  final List<(int, String, double)> records = [];

  Map<String, dynamic> _snapshot(int orderId) {
    final int paid = groups
        .where((g) => g['status'] == 'succeeded')
        .fold(0, (a, g) => a + _cents(g['amount'] as double));
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
  Future<ApiResponseModel> createGroups({
    required int orderId,
    required int deviceId,
    required List<Map<String, dynamic>> groups,
  }) async {
    creates.add(groups);
    final int sum =
        groups.fold(0, (a, g) => a + _cents((g['amount'] as num).toDouble()));
    if ((sum - _cents(grandTotal)).abs() > 1) {
      return ApiResponseModel.withError('Group amounts must sum to order total.');
    }
    this.groups = [
      for (int i = 0; i < groups.length; i++)
        {
          'seq': i + 1,
          'amount': (groups[i]['amount'] as num).toDouble(),
          'item_ids': groups[i]['item_ids'],
          'status': 'pending',
        },
    ];
    return _ok({
      'order_id': orderId,
      'grand_total': grandTotal,
      'groups': [
        for (final g in this.groups)
          {
            'seq': g['seq'],
            'amount': g['amount'],
            'item_ids': g['item_ids'],
            'status': g['status'],
          },
      ],
    });
  }

  @override
  Future<ApiResponseModel> recordPayment({
    required int orderId,
    required int groupSeq,
    required String paidWith,
    required double paidAmount,
    required int deviceId,
    required String reference,
    String? transactionReference,
  }) async {
    final Map<String, dynamic>? g =
        groups.where((g) => g['seq'] == groupSeq).firstOrNull;
    if (g == null) return ApiResponseModel.withError('Group not found.');
    if (_cents(paidAmount) > _cents(g['amount'] as double)) {
      return ApiResponseModel.withError('Payment exceeds group amount.');
    }
    records.add((groupSeq, paidWith, paidAmount));
    g['status'] = 'succeeded';
    g['paid_with'] = paidWith;
    g['reference'] = reference;
    return _ok(_snapshot(orderId)..['replayed'] = false);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ── Harness ────────────────────────────────────────────────────────────────

late FakeTerminal terminal;
late FakeSplitRepo splitRepo;
late FakeSbiRepo sbiRepo;
late List<double> placed;
bool placeFails = false;

void _register<T extends Object>(T instance) {
  if (sl.isRegistered<T>()) sl.unregister<T>();
  sl.registerSingleton<T>(instance);
}

void setUpFlowFakes() {
  terminal = FakeTerminal();
  splitRepo = FakeSplitRepo();
  sbiRepo = FakeSbiRepo();
  placed = [];
  placeFails = false;
  _register<KioskPaymentService>(terminal);
  _register<PosSplitRepo>(splitRepo);
  _register<PosSplitByItemRepo>(sbiRepo);
  debugPosPlaceOrder = (context,
      {required amount,
      paymentRef,
      bringChangeAmount,
      tipAmountOverride}) async {
    if (placeFails) {
      return const KioskPlaceResult(success: false, message: 'Server down');
    }
    placed.add(amount);
    return const KioskPlaceResult(success: true, orderId: '27362');
  };
}

void tearDownFlowFakes() {
  debugPosPlaceOrder = null;
  for (final unregister in [
    () => sl.unregister<KioskPaymentService>(),
    () => sl.unregister<PosSplitRepo>(),
    () => sl.unregister<PosSplitByItemRepo>(),
  ]) {
    try {
      unregister();
    } catch (_) {}
  }
}

Future<void> tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.tap(f);
  await tester.pumpAndSettle();
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

    testWidgets('a failed order placement keeps the chooser up',
        (tester) async {
      await openChooser(tester);
      placeFails = true;
      await confirmBar(tester);
      expect(find.byType(PosSplitChooserPanel), findsOneWidget);
      expect(bar(tester), ('Continue', true));
    });
  });

  group('2a · split by item', () {
    Future<void> pick(WidgetTester tester, List<String> names) async {
      for (final n in names) {
        await tap(tester, inPane(PosSplitByItemPanel, n));
      }
    }

    testWidgets('card, two guests: groups sum to the total, then Order Paid',
        (tester) async {
      await openChooser(tester);
      await confirmBar(tester);
      expect(placed, [19]);
      expect(find.text('SELECT ITEMS FOR PAYMENT 1'), findsOneWidget);
      expect(bar(tester), ('Start Payment 1 · € 0.00', false));

      await pick(tester, ['Oat Milk Matcha', 'Vanilla Matcha Latte']);
      expect(bar(tester), ('Start Payment 1 · € 12.00', true));
      await confirmBar(tester);

      // One create-groups call defining the whole split (the pick + the
      // rest), summing to the order total.
      expect(sbiRepo.creates, hasLength(1));
      expect(sbiRepo.creates.single, [
        {'item_ids': [0, 1], 'amount': 12.0},
        {'item_ids': [2], 'amount': 7.0},
      ]);
      expect(terminal.charged, [12]);
      expect(sbiRepo.records, [(1, 'card', 12.0)]);
      expect(find.text('Split Payment 1 Successful'), findsOneWidget);

      await tap(tester, find.text('Start next payment'));
      // The rest comes ticked; the paid items are inert "Paid" rows.
      expect(find.text('SELECT ITEMS FOR PAYMENT 2'), findsOneWidget);
      expect(bar(tester), ('Start Payment 2 · € 7.00', true));
      await confirmBar(tester);

      expect(sbiRepo.creates, hasLength(1), reason: 'never re-created');
      expect(terminal.charged, [12, 7]);
      expect(sbiRepo.records.last, (2, 'card', 7.0));
      expect(find.text('Order Paid'), findsOneWidget);

      await tap(tester, find.text('Next order'));
      expect(find.text('ROUTE /pos-home'), findsOneWidget);
    });

    testWidgets('payment 2 must settle the remaining group as a whole',
        (tester) async {
      await openChooser(tester);
      await confirmBar(tester);
      await pick(tester, ['Oat Milk Matcha']);
      await confirmBar(tester);
      await tap(tester, find.text('Start next payment'));
      expect(bar(tester), ('Start Payment 2 · € 13.00', true));
      // Unticking one of the remaining items cannot be paid separately.
      await pick(tester, ['Mango Matcha']);
      expect(bar(tester).$2, isFalse);
      await pick(tester, ['Mango Matcha']);
      expect(bar(tester), ('Start Payment 2 · € 13.00', true));
    });

    testWidgets('every item in one payment: a single group, the whole total',
        (tester) async {
      await openChooser(tester);
      await confirmBar(tester);
      await pick(tester, ['Oat Milk Matcha', 'Vanilla Matcha Latte', 'Mango Matcha']);
      expect(bar(tester), ('Start Payment 1 · € 19.00', true));
      await confirmBar(tester);
      expect(sbiRepo.creates.single, [
        {'item_ids': [0, 1, 2], 'amount': 19.0},
      ]);
      expect(find.text('Order Paid'), findsOneWidget);
    });

    testWidgets('a declined card retries without re-creating the groups',
        (tester) async {
      await openChooser(tester);
      await confirmBar(tester);
      await pick(tester, ['Oat Milk Matcha', 'Vanilla Matcha Latte']);
      terminal.answer = KioskPaymentStatus.failed;
      await confirmBar(tester);
      expect(find.text('Try Again'), findsOneWidget);
      terminal.answer = KioskPaymentStatus.paid;
      await tap(tester, find.text('Try Again'));
      expect(sbiRepo.creates, hasLength(1));
      expect(terminal.charged, [12, 12]);
      expect(sbiRepo.records, [(1, 'card', 12.0)]);
    });

    testWidgets('cash (frame 15): tender, change due, records the amount due',
        (tester) async {
      await openChooser(tester);
      await confirmBar(tester);
      await pick(tester, ['Oat Milk Matcha', 'Vanilla Matcha Latte']);
      await tap(tester, inPane(PosPayWithRow, 'Cash'));
      expect(bar(tester), ('Start Payment 1 · € 12.00', true));
      await confirmBar(tester);

      // The tender step: nothing sent yet, Exact by default.
      expect(sbiRepo.creates, isEmpty);
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
      expect(sbiRepo.records, [(1, 'cash', 12.0)]);
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
      expect(placed, [19]);
      expect(find.text('GUEST 1 · CUSTOM AMOUNT'), findsOneWidget);
      expect(find.text('Enter the amount this guest pays'), findsOneWidget);
      expect(bar(tester), ('Start Payment 1', false));

      await keys(tester, '0');
      expect(bar(tester), ('Start Payment 1', false), reason: 'zero');

      await backspace(tester);
      await keys(tester, '25');
      expect(bar(tester), ('Start Payment 1', false), reason: 'over € 19.00');

      await backspace(tester, 2);
      await keys(tester, '8,555');
      expect(bar(tester), ('Start Payment 1 · € 8.55', true),
          reason: 'a third decimal is ignored');
      await backspace(tester);
      await keys(tester, '0');
      expect(bar(tester), ('Start Payment 1 · € 8.50', true));
    });

    testWidgets('two guests, card then cash with change, then Order Paid',
        (tester) async {
      await openCustom(tester);
      await keys(tester, '8,5');
      await confirmBar(tester);
      expect(terminal.charged, [8.5]);
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
      expect(find.text('Order Paid'), findsOneWidget);
    });
  });

  group('split by payment (unchanged saving path)', () {
    testWidgets('card above the remaining is blocked before the backend',
        (tester) async {
      await pumpPaymentScreen(tester, routed: true);
      await tap(tester, find.text('Split by payment'));
      expect(placed, [19]);
      await keys(tester, '25');
      expect(bar(tester), ('Start Payment 1', false));
      await backspace(tester, 2);
      await keys(tester, '9');
      expect(bar(tester), ('Start Payment 1', true));
      await confirmBar(tester);
      expect(terminal.charged, [9]);
      expect(splitRepo.payments.single['paid_amount'], 9.0);
    });

    testWidgets('cash over-tender records only what is owed (was a 422)',
        (tester) async {
      await pumpPaymentScreen(tester, routed: true);
      await tap(tester, find.text('Split by payment'));
      await tap(
          tester,
          find.descendant(
              of: find.byType(PosSplitMethodToggle),
              matching: find.text('Cash')));
      await tap(tester, find.text('€ 50'));
      await confirmBar(tester);
      expect(splitRepo.rejected, isEmpty);
      expect(splitRepo.payments.single['paid_amount'], 19.0);
      expect(find.text('Order Paid'), findsOneWidget);
    });
  });
}
