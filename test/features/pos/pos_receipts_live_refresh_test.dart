import 'dart:async';
import 'dart:io';

import 'package:acafe_customer/common/models/api_response_model.dart';
import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/reposotories/product_repo.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:acafe_customer/di_container.dart' as di;
import 'package:acafe_customer/features/kiosk/domain/kiosk_manager_repo.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_manager_provider.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipt_history.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipt_reopen_repo.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipt_save_changes_repo.dart';
import 'package:acafe_customer/features/pos/screens/pos_receipts_screen.dart';
import 'package:acafe_customer/features/pos/widgets/pos_receipt_detail_panel.dart';
import 'package:acafe_customer/features/pos/widgets/pos_receipt_panel.dart';
import 'package:acafe_customer/features/pos/widgets/pos_receipts_table.dart';
import 'package:acafe_customer/features/realtime/order_changed_event.dart';
import 'package:acafe_customer/features/realtime/product_realtime_controller.dart';
import 'package:acafe_customer/features/realtime/product_realtime_gateway.dart';
import 'package:acafe_customer/features/splash/domain/reposotories/splash_repo.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pos_test_kiosk_auth.dart';

/// Receipts must follow the server live: a saved edit, another till's refund
/// or a reopened receipt shows up in the list and the open receipt without the
/// operator reloading — and without the table blanking to a spinner or the
/// edit sidebar losing its unsaved edits while it happens.

Response<dynamic> _ok(Object data) => Response<dynamic>(
      requestOptions: RequestOptions(path: '/'),
      statusCode: 200,
      data: data,
    );

const int _orderId = 100014;

/// One line, as `transactions/{id}` returns it, with two optional add-ons so
/// the edit sidebar has something to show.
Map<String, dynamic> _line() => {
      'product_id': 7,
      'price': 11.0,
      'quantity': 1,
      'discount_on_product': 0,
      'tax_amount': 0,
      'add_on_ids': <int>[],
      'add_on_qtys': <int>[],
      'add_on_prices': <double>[],
      'variation': <dynamic>[],
      'product_details': {
        'id': 7,
        'name': 'Fresh Mint Tea',
        'price': 11.0,
        'image': 'mint.png',
        'variations': <dynamic>[],
        'add_ons': [
          {'id': 70, 'name': 'Honey', 'price': 0.5, 'is_default': 0},
          {'id': 71, 'name': 'Lemon', 'price': 0.3, 'is_default': 0},
        ],
      },
    };

/// Stands in for the server. [amounts] is the order_amount column; tests move
/// it to play "something changed on the server".
class _FakeManagerRepo implements KioskManagerRepo {
  _FakeManagerRepo(this.sharedPreferences, {int rows = 3}) {
    for (int i = 0; i < rows; i++) {
      amounts[_orderId - i] = 11.0 + i;
    }
  }

  @override
  final SharedPreferences sharedPreferences;

  /// Newest first, the order the endpoint sorts by.
  final Map<int, double> amounts = {};

  final List<Map<String, Object?>> listQueries = [];
  int detailCalls = 0;

  /// While set, responses wait on it — lets a test look at the screen mid-flight.
  Completer<void>? holdList;
  Completer<void>? holdDetail;

  @override
  Future<ApiResponseModel> getTransactions({
    String? reportDate,
    String? dateFrom,
    String? dateTo,
    String? search,
    String? status,
    String? channel,
    double? amountMin,
    double? amountMax,
    int limit = 25,
    int offset = 1,
  }) async {
    listQueries.add({
      'limit': limit,
      'offset': offset,
      'status': status,
      'search': search,
    });
    if (holdList != null) await holdList!.future;
    final List<int> ids = amounts.keys.toList()..sort((a, b) => b - a);
    final List<Map<String, dynamic>> page = ids
        .skip((offset - 1) * limit)
        .take(limit)
        .map((id) => <String, dynamic>{
              'id': id,
              'created_at': '2026-10-19T06:13:00.000000Z',
              'customer_name': '',
              'products_summary': 'Fresh Mint Tea',
              'display_method': 'cash',
              'order_amount': amounts[id],
              'order_status': 'delivered',
              'payment_status': 'paid',
              'channel_key': 'counter_pos',
            })
        .toList();
    return ApiResponseModel.withSuccess(
      _ok({'total_size': ids.length, 'orders': page}),
    );
  }

  @override
  Future<ApiResponseModel> getTransactionDetail(int id) async {
    detailCalls++;
    if (holdDetail != null) await holdDetail!.future;
    final double total = amounts[id] ?? 0;
    return ApiResponseModel.withSuccess(_ok({
      'id': id,
      'created_at': '2026-10-19T06:13:00.000000Z',
      'customer_name': '',
      'display_method': 'cash',
      'payment_method': 'cash_on_delivery',
      'payment_status': 'paid',
      'order_status': 'delivered',
      'table': null,
      'subtotal': total,
      'discount': 0,
      'tip_amount': 0,
      'total': total,
      'details': [_line()],
    }));
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _ReopenRepo implements PosReceiptReopenRepo {
  @override
  Future<ApiResponseModel> reopen({required int orderId, String? reason}) async =>
      ApiResponseModel.withSuccess(_ok({'message': 'Receipt reopened.'}));

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// Saving re-prices the order on the "server", the way save-changes does.
class _SaveRepo implements PosReceiptSaveChangesRepo {
  _SaveRepo(this.server, this.newTotal);

  final _FakeManagerRepo server;
  final double newTotal;
  int calls = 0;
  Completer<void>? hold;

  @override
  Future<ApiResponseModel> saveChanges({
    required int orderId,
    required List<CartModel> editLines,
  }) async {
    calls++;
    if (hold != null) await hold!.future;
    server.amounts[orderId] = newTotal;
    return ApiResponseModel.withSuccess(_ok({'new_total': newTotal}));
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _ProductRepo implements ProductRepo {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Future<SharedPreferences> _prefs() async {
  SharedPreferences.setMockInitialValues({
    AppConstants.languageCode: 'en',
    AppConstants.countryCode: 'NL',
  });
  return SharedPreferences.getInstance();
}

double _rowAmount(KioskManagerProvider p, int id) =>
    PosReceiptRow.fromJson(p.transactions.firstWhere((t) => t['id'] == id))
        .amount;

double? _detailTotal(KioskManagerProvider p) => p.receiptDetail == null
    ? null
    : PosReceiptDetail.fromJson(p.receiptDetail!).total;

/// The real faces: the test font's wide glyphs overflow the filter row at a
/// width the shipped Loew fits comfortably.
Future<void> _loadFonts() async {
  const Map<String, List<String>> families = {
    'Loew': [
      'assets/fonts/Loew-Regular.ttf',
      'assets/fonts/Loew-Medium.ttf',
      'assets/fonts/Loew-Bold.ttf',
      'assets/fonts/Loew-ExtraBold.ttf',
    ],
    'Swiss721': ['assets/fonts/Swiss721-Light.ttf'],
  };
  for (final entry in families.entries) {
    final loader = FontLoader(entry.key);
    for (final path in entry.value) {
      loader.addFont(File(path)
          .readAsBytes()
          .then((bytes) => ByteData.view(Uint8List.fromList(bytes).buffer)));
    }
    await loader.load();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_loadFonts);

  group('provider: live refresh swaps data in place', () {
    test('the list keeps its rows painted until the fresh window lands',
        () async {
      final repo = _FakeManagerRepo(await _prefs());
      final p = KioskManagerProvider(kioskManagerRepo: repo);
      await p.loadTransactions(replaceFilters: true);
      expect(p.transactions, hasLength(3));

      repo.amounts[_orderId] = 99;
      repo.holdList = Completer<void>();
      final Future<void> refresh = p.refreshTransactions();

      // Mid-flight: still the old rows, and nothing that draws a spinner.
      expect(p.transactions, hasLength(3));
      expect(p.transactionsLoading, isFalse);
      expect(_rowAmount(p, _orderId), 11);

      repo.holdList!.complete();
      await refresh;
      expect(p.transactions, hasLength(3));
      expect(_rowAmount(p, _orderId), 99);
    });

    test('every page already scrolled into view is re-pulled, filters kept',
        () async {
      final repo = _FakeManagerRepo(await _prefs(), rows: 60);
      final p = KioskManagerProvider(kioskManagerRepo: repo);
      await p.loadTransactions(
          search: 'mint', status: 'paid', replaceFilters: true);
      await p.loadTransactions(reset: false);
      expect(p.transactions, hasLength(50));

      await p.refreshTransactions();
      expect(repo.listQueries.last, {
        'limit': 50,
        'offset': 1,
        'status': 'paid',
        'search': 'mint',
      });
      expect(p.transactions, hasLength(50));

      // Paging carries on after the refreshed window, not from page 2 again.
      await p.loadTransactions(reset: false);
      expect(p.transactions, hasLength(60));
      final ids = p.transactions.map((t) => t['id']).toList();
      expect(ids.toSet(), hasLength(60));
    });

    test('a page asked for mid-refresh lands after the fresh window',
        () async {
      final repo = _FakeManagerRepo(await _prefs(), rows: 60);
      final p = KioskManagerProvider(kioskManagerRepo: repo);
      await p.loadTransactions(replaceFilters: true);

      repo.holdList = Completer<void>();
      final Future<void> refresh = p.refreshTransactions();
      final Future<void> more = p.loadTransactions(reset: false);
      repo.holdList!.complete();
      await Future.wait([refresh, more]);

      final ids = p.transactions.map((t) => t['id']).toList();
      expect(ids, hasLength(50));
      expect(ids.toSet(), hasLength(50));
    });

    test('the open receipt stays on screen, not loading, while it re-pulls',
        () async {
      final repo = _FakeManagerRepo(await _prefs());
      final p = KioskManagerProvider(kioskManagerRepo: repo);
      await p.loadReceiptDetail(_orderId);
      expect(_detailTotal(p), 11);

      repo.amounts[_orderId] = 42;
      repo.holdDetail = Completer<void>();
      final Future<void> refresh = p.refreshReceiptDetail(_orderId);

      expect(p.receiptDetail, isNotNull);
      expect(p.receiptDetailLoading, isFalse);
      expect(_detailTotal(p), 11);

      repo.holdDetail!.complete();
      await refresh;
      expect(_detailTotal(p), 42);
      expect(p.receiptDetailId, _orderId);
    });

    test('a refresh for a receipt that is no longer open is ignored',
        () async {
      final repo = _FakeManagerRepo(await _prefs());
      final p = KioskManagerProvider(kioskManagerRepo: repo);
      await p.loadReceiptDetail(_orderId);
      final int calls = repo.detailCalls;

      await p.refreshReceiptDetail(_orderId - 1);
      expect(repo.detailCalls, calls);
      expect(p.receiptDetailId, _orderId);
    });
  });

  group('screen', () {
    late SharedPreferences prefs;
    late _FakeManagerRepo server;
    late KioskManagerProvider manager;

    setUp(() async {
      prefs = await _prefs();
      server = _FakeManagerRepo(prefs);
      manager = KioskManagerProvider(kioskManagerRepo: server);
      if (!di.sl.isRegistered<PosReceiptReopenRepo>()) {
        di.sl.registerSingleton<PosReceiptReopenRepo>(_ReopenRepo());
      }
    });

    tearDown(() async {
      for (final unregister in [
        () => di.sl.unregister<PosReceiptReopenRepo>(),
        () => di.sl.unregister<PosReceiptSaveChangesRepo>(),
        () => di.sl.unregister<ProductRealtimeController>(),
      ]) {
        try {
          await unregister();
        } catch (_) {}
      }
    });

    Future<void> pumpScreen(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1366, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final dio = DioClient(
        'http://localhost',
        null,
        loggingInterceptor: LoggingInterceptor(),
        sharedPreferences: prefs,
      );
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<SplashProvider>(
            create: (_) => SplashProvider(
              splashRepo: SplashRepo(dioClient: dio, sharedPreferences: prefs),
            ),
          ),
          ChangeNotifierProvider<KioskManagerProvider>.value(value: manager),
          testKioskAuthProvider(prefs),
        ],
        child: const MaterialApp(
          home: Scaffold(body: PosReceiptsScreen()),
        ),
      ));
      // Initial list load, then the newest receipt auto-opens beside it.
      await tester.pump();
      await tester.pump();
      await tester.pump();
      await tester.pump();
    }

    Future<void> reopen(WidgetTester tester) async {
      await tester.tap(find.descendant(
        of: find.byType(PosReceiptHeader),
        matching: find.byType(InkWell),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reopen receipt'));
      await tester.pumpAndSettle();
      // The dialog's own CTA (its title may repeat the words).
      await tester.tap(find.text('Reopen receipt').last);
      await tester.pumpAndSettle();
    }

    testWidgets('the edit sidebar builds cleanly — no error box in the header',
        (tester) async {
      await pumpScreen(tester);
      expect(_detailTotal(manager), 11);

      await reopen(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(ErrorWidget), findsNothing);
      expect(find.text('Editing receipt'), findsOneWidget);
      expect(find.text('REOPENED'), findsOneWidget);
    });

    testWidgets('saving an edit updates the row and the receipt, no reload',
        (tester) async {
      final save = _SaveRepo(server, 14.5);
      di.sl.registerSingleton<PosReceiptSaveChangesRepo>(save);
      await pumpScreen(tester);
      await reopen(tester);

      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      // Confirm dialog's CTA (delta 0 reads "Save changes" too).
      await tester.tap(find.text('Save changes').last);
      await tester.pumpAndSettle();

      expect(save.calls, 1);
      expect(find.text('Changes saved'), findsOneWidget);
      // Behind the success card the list already carries the new amount.
      expect(_rowAmount(manager, _orderId), 14.5);
      expect(_detailTotal(manager), 14.5);

      // No button: the card fades itself out and the receipt is back in view.
      expect(find.text('BACK TO RECEIPTS'), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(find.text('Changes saved'), findsNothing);
      expect(find.text('Editing receipt'), findsNothing);
      expect(find.text('Purchase Receipt'), findsOneWidget);
      // The row's amount (the line's unit price, €11.00, rightly stays).
      final Finder table = find.byType(PosReceiptsTable);
      expect(find.descendant(of: table, matching: find.textContaining('14.50')),
          findsOneWidget);
      expect(find.descendant(of: table, matching: find.textContaining('11.00')),
          findsNothing);
      // ...and the receipt's total.
      expect(
        find.descendant(
          of: find.byType(PosReceiptSummary),
          matching: find.textContaining('14.50'),
        ),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('Save cannot be sent twice while the first save is in flight',
        (tester) async {
      final save = _SaveRepo(server, 14.5)..hold = Completer<void>();
      di.sl.registerSingleton<PosReceiptSaveChangesRepo>(save);
      await pumpScreen(tester);
      await reopen(tester);

      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save changes').last);
      // Through the confirm dialog's close transition (the first frame only
      // starts its clock) and the frame that removes its route. Not
      // pumpAndSettle: the in-flight spinner never settles.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(find.text('Save changes?'), findsNothing);

      // Request in flight: Save shows a spinner and a tap on it does nothing.
      expect(find.text('Save changes'), findsNothing);
      final Finder spinner = find.byType(CircularProgressIndicator);
      expect(spinner, findsOneWidget);
      await tester.tap(spinner, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Save changes?'), findsNothing);

      save.hold!.complete();
      await tester.pumpAndSettle();
      expect(save.calls, 1);
      expect(find.text('Changes saved'), findsOneWidget);
    });

    testWidgets(
        'an order.changed ping refreshes the row and open receipt in place',
        (tester) async {
      final controller = ProductRealtimeController(
        productRepo: _ProductRepo(),
        gateway: ProductRealtimeGateway(),
      );
      di.sl.registerSingleton<ProductRealtimeController>(controller);
      await pumpScreen(tester);
      controller.bindAuth(
        Provider.of<KioskAuthProvider>(
          tester.element(find.byType(PosReceiptsScreen)),
          listen: false,
        ),
      );
      expect(_detailTotal(manager), 11);

      server.amounts[_orderId] = 20;
      server.holdList = Completer<void>();
      server.holdDetail = Completer<void>();
      controller.gateway.onOrderEvent!(const OrderChangedEvent(
        version: 1,
        eventId: 'evt-1',
        orderId: _orderId,
        branchId: 1,
        orderStatus: 'delivered',
      ));
      await tester.pump(const Duration(milliseconds: 450));

      // In flight: the table and the receipt stay painted, no spinners.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(manager.transactions, hasLength(3));
      expect(_detailTotal(manager), 11);

      server.holdList!.complete();
      server.holdDetail!.complete();
      await tester.pumpAndSettle();

      expect(_rowAmount(manager, _orderId), 20);
      expect(_detailTotal(manager), 20);
      expect(find.textContaining('20.00'), findsWidgets);
    });

    testWidgets('a ping while editing keeps the edit sidebar and its edits',
        (tester) async {
      final controller = ProductRealtimeController(
        productRepo: _ProductRepo(),
        gateway: ProductRealtimeGateway(),
      );
      di.sl.registerSingleton<ProductRealtimeController>(controller);
      await pumpScreen(tester);
      controller.bindAuth(
        Provider.of<KioskAuthProvider>(
          tester.element(find.byType(PosReceiptsScreen)),
          listen: false,
        ),
      );
      await reopen(tester);
      expect(find.text('Editing receipt'), findsOneWidget);

      // The reopen's own echo, as Reverb would deliver it.
      controller.gateway.onOrderEvent!(const OrderChangedEvent(
        version: 1,
        eventId: 'evt-reopen',
        orderId: _orderId,
        branchId: 1,
        orderStatus: 'delivered',
      ));
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();

      expect(find.text('Editing receipt'), findsOneWidget);
      expect(find.byType(PosReceiptDetailPanel), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
