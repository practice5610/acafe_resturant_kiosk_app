import 'dart:async';

import 'package:acafe_customer/common/models/api_response_model.dart';
import 'package:acafe_customer/common/reposotories/product_repo.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:acafe_customer/di_container.dart' as di;
import 'package:acafe_customer/features/pos/screens/pos_orders_list_screen.dart';
import 'package:acafe_customer/features/pos/widgets/pos_order_card_tile.dart';
import 'package:flutter/material.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_auth_repo.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/pos/domain/pos_live_cache.dart';
import 'package:acafe_customer/features/pos/domain/pos_order_grouping.dart';
import 'package:acafe_customer/features/pos/domain/pos_orders_repo.dart';
import 'package:acafe_customer/features/pos/providers/pos_orders_provider.dart';
import 'package:acafe_customer/features/realtime/order_changed_event.dart';
import 'package:acafe_customer/features/realtime/product_realtime_controller.dart';
import 'package:acafe_customer/features/realtime/product_realtime_gateway.dart';
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The Orders board as a store that outlives the screen: it opens on whatever
/// it last knew (memory, else disk), refreshes behind that without a spinner,
/// and keeps following the socket while another tab is up.

Map<String, dynamic> _order(int id, String status) => <String, dynamic>{
      'id': id,
      'created_at': '2026-10-19T06:12:00.000Z',
      'order_status': status,
      'order_type': 'pos',
      'channel_key': 'counter_pos',
      'order_amount': 10.0 + id,
      'customer_name': 'Walk-in',
      'address_lines': <String>[],
      'display_method': 'card',
      'branch_name': 'Acafe/Amsterdam',
    };

class _Repo implements PosOrdersRepo {
  List<Map<String, dynamic>> rows = [_order(1, 'new'), _order(2, 'preparing')];
  int getCalls = 0;
  String? lastSection;
  String? lastDateFrom;
  Completer<void>? hold;

  @override
  Future<ApiResponseModel> getOrders({
    String? dateFrom,
    String? dateTo,
    String? search,
    String? section,
    String? status,
    String? source,
    String? type,
    String? method,
    int limit = 200,
  }) async {
    getCalls++;
    lastSection = section;
    lastDateFrom = dateFrom;
    // Snapshot the rows at request time, as the server would answer.
    final List<Map<String, dynamic>> answer = section == null
        ? List<Map<String, dynamic>>.from(rows)
        : rows
            .where((r) => r['order_status'] == 'preparing')
            .toList(growable: false);
    if (hold != null) await hold!.future;
    return ApiResponseModel.withSuccess(Response<dynamic>(
      requestOptions: RequestOptions(path: '/orders'),
      statusCode: 200,
      data: <String, dynamic>{
        'counts': <String, dynamic>{
          'new': answer.where((r) => r['order_status'] == 'new').length,
          'preparing':
              answer.where((r) => r['order_status'] == 'preparing').length,
          'ready_to_collect': 0,
          'on_hold': 0,
          'completed': 0,
        },
        'orders': answer,
      },
    ));
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _ProductRepo implements ProductRepo {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  late SharedPreferences prefs;
  late _Repo repo;
  String? scope;
  bool connected = true;
  late DateTime now;

  PosOrdersProvider store() => PosOrdersProvider(
        posOrdersRepo: repo,
        cache: PosLiveCache(prefs, clock: () => now),
        scope: () => scope,
        realtimeConnected: () => connected,
        clock: () => now,
      );

  List<int> ids(PosOrdersProvider p) => p.orders.map((o) => o.id).toList();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
    repo = _Repo();
    scope = 'b1.d7';
    connected = true;
    now = DateTime(2026, 10, 19, 6, 30);
  });

  group('disk snapshot', () {
    test('a default-view load is what the next cold start paints first',
        () async {
      await store().load();

      final PosOrdersProvider cold = store()..restore();

      expect(ids(cold), [1, 2]);
      expect(cold.loaded, isTrue);
      expect(cold.initialLoading, isFalse);
      expect(cold.countOf(PosOrderSection.newOrders), 1);
      expect(repo.getCalls, 1, reason: 'painting the snapshot costs nothing');
    });

    test('a filtered board never overwrites the saved default board',
        () async {
      final PosOrdersProvider p = store();
      await p.load();
      p.setSection(PosOrderSection.preparing);
      await Future<void>.delayed(Duration.zero);
      expect(ids(p), [2]);

      expect(ids(store()..restore()), [1, 2]);
    });

    test('another branch session starts blank, with default filters',
        () async {
      final PosOrdersProvider p = store();
      await p.load();
      p.setSection(PosOrderSection.preparing);
      await Future<void>.delayed(Duration.zero);

      scope = 'b2.d7';
      p.restore();

      expect(p.orders, isEmpty);
      expect(p.loaded, isFalse);
      expect(p.section, isNull);
    });

    test('nothing is cached for a terminal with no bound branch', () async {
      scope = null;
      await store().load();
      scope = 'b1.d7';

      expect((store()..restore()).orders, isEmpty);
    });
  });

  group('showing the board', () {
    test('a restored board revalidates silently: rows stay, no spinner',
        () async {
      await store().load();
      repo.rows = [_order(3, 'new'), ..._order12()];
      repo.hold = Completer<void>();

      final PosOrdersProvider p = store();
      p.setVisible(true);

      expect(ids(p), [1, 2]);
      expect(p.initialLoading, isFalse);

      repo.hold!.complete();
      await Future<void>.delayed(Duration.zero);
      expect(ids(p), [3, 1, 2]);
    });

    test('a board synced moments ago over a live socket is not re-fetched',
        () async {
      final PosOrdersProvider p = store();
      await p.load();
      now = now.add(const Duration(seconds: 3));

      p.setVisible(true);
      expect(repo.getCalls, 1);
    });

    test('with the socket down, showing it always re-checks', () async {
      connected = false;
      final PosOrdersProvider p = store();
      await p.load();

      p.setVisible(true);
      await Future<void>.delayed(Duration.zero);
      expect(repo.getCalls, 2);
      p.setVisible(false);
    });

    test('the very first show, with nothing to paint, is the spinner load',
        () async {
      repo.hold = Completer<void>();
      final PosOrdersProvider p = store();
      p.setVisible(true);

      expect(p.initialLoading, isTrue);
      repo.hold!.complete();
      await Future<void>.delayed(Duration.zero);
      expect(ids(p), [1, 2]);
    });

    testWidgets('socket down: the visible board polls, a hidden one does not',
        (tester) async {
      connected = false;
      final PosOrdersProvider p = store();
      await p.load();
      p.setVisible(true);
      await tester.pump();
      final int afterShow = repo.getCalls;

      await tester.pump(PosOrdersProvider.fallbackPoll);
      expect(repo.getCalls, afterShow + 1);

      p.setVisible(false);
      await tester.pump(PosOrdersProvider.fallbackPoll * 3);
      expect(repo.getCalls, afterShow + 1);
      p.dispose();
    });

    testWidgets('socket up: no polling at all', (tester) async {
      final PosOrdersProvider p = store();
      await p.load();
      p.setVisible(true);
      final int calls = repo.getCalls;

      await tester.pump(PosOrdersProvider.fallbackPoll * 3);
      expect(repo.getCalls, calls);
      p.dispose();
    });
  });

  group('realtime while hidden', () {
    testWidgets('a push still refreshes the hidden board, on a slower debounce',
        (tester) async {
      final PosOrdersProvider p = store();
      await p.load();
      final int calls = repo.getCalls;

      p.onRealtimeChange();
      await tester.pump(
          PosOrdersProvider.realtimeDebounce + const Duration(milliseconds: 50));
      expect(repo.getCalls, calls, reason: 'hidden: not at the visible pace');

      await tester.pump(PosOrdersProvider.hiddenRealtimeDebounce);
      expect(repo.getCalls, calls + 1);
      p.dispose();
    });

    testWidgets('attachRealtime feeds order pings to the store, once',
        (tester) async {
      final ProductRealtimeController controller = ProductRealtimeController(
        productRepo: _ProductRepo(),
        gateway: ProductRealtimeGateway(),
      );
      // bindAuth is what routes the gateway's order frames into the
      // controller (start() does the same on a real connect).
      controller.bindAuth(KioskAuthProvider(
        kioskAuthRepo: KioskAuthRepo(
          dioClient: DioClient(
            AppConstants.baseUrl,
            null,
            loggingInterceptor: LoggingInterceptor(),
            sharedPreferences: prefs,
          ),
          sharedPreferences: prefs,
        ),
      ));
      final PosOrdersProvider p = store();
      await p.load();
      p.attachRealtime(controller);
      p.attachRealtime(controller); // idempotent: still one listener
      p.setVisible(true);
      final int calls = repo.getCalls;

      repo.rows = [_order(9, 'new'), ..._order12()];
      controller.gateway.onOrderEvent!(const OrderChangedEvent(
        version: 1,
        eventId: 'evt-1',
        orderId: 9,
        branchId: 1,
        orderStatus: 'new',
      ));
      await tester.pump(
          PosOrdersProvider.realtimeDebounce + const Duration(milliseconds: 50));

      expect(repo.getCalls, calls + 1);
      expect(ids(p), [9, 1, 2]);
      p.dispose();
    });
  });

  group('screen', () {
    tearDown(() async {
      try {
        await di.sl.unregister<PosOrdersProvider>();
      } catch (_) {}
    });

    Widget app({required bool onOrders}) => MaterialApp(
          home: Scaffold(
            body: onOrders ? const PosOrdersListScreen() : const Text('POS'),
          ),
        );

    Future<void> sizeView(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1366, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
    }

    testWidgets(
        'coming back to Orders paints the board on its first frame: '
        'no spinner, no refetch', (tester) async {
      await sizeView(tester);
      final PosOrdersProvider shared = store();
      di.sl.registerSingleton<PosOrdersProvider>(shared);

      await tester.pumpWidget(app(onOrders: true));
      await tester.pump(); // the first show: a cold store loads
      await tester.pump();
      expect(find.byType(PosOrderCardTile), findsNWidgets(2));

      await tester.pumpWidget(app(onOrders: false)); // another tab
      expect(shared.visible, isFalse);
      final int calls = repo.getCalls;

      await tester.pumpWidget(app(onOrders: true)); // back: first frame only
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(PosOrderCardTile), findsNWidgets(2));

      await tester.pump();
      expect(repo.getCalls, calls,
          reason: 'synced moments ago over a live socket: nothing to re-ask');

      await tester.pumpWidget(app(onOrders: false));
    });

    testWidgets('a reload paints the saved board on its first frame',
        (tester) async {
      await sizeView(tester);
      await store().load(); // the previous run of the app
      repo.hold = Completer<void>();

      final PosOrdersProvider fresh = store();
      di.sl.registerSingleton<PosOrdersProvider>(fresh);
      await tester.pumpWidget(app(onOrders: true));

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(PosOrderCardTile), findsNWidgets(2));

      repo.hold!.complete();
      await tester.pump();
      await tester.pumpWidget(app(onOrders: false));
    });

    testWidgets('a search survives the tab switch, and the field shows it',
        (tester) async {
      await sizeView(tester);
      final PosOrdersProvider shared = store();
      di.sl.registerSingleton<PosOrdersProvider>(shared);
      await tester.pumpWidget(app(onOrders: true));
      await tester.pump();

      await tester.enterText(find.byType(TextField).first, 'walk');
      await tester.pump(PosOrdersProvider.searchDebounce);
      await tester.pumpWidget(app(onOrders: false));
      await tester.pumpWidget(app(onOrders: true));

      expect(shared.search, 'walk');
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller?.text,
        'walk',
      );
      await tester.pumpWidget(app(onOrders: false));
    });
  });

  test('NOW mode follows the day for a store that outlives midnight',
      () async {
    final PosOrdersProvider p = store();
    await p.load();
    expect(repo.lastDateFrom, '2026-10-19 00:00:00');

    now = DateTime(2026, 10, 20, 0, 5);
    await p.load(silent: true);
    expect(repo.lastDateFrom, '2026-10-20 00:00:00');
  });
}

List<Map<String, dynamic>> _order12() =>
    [_order(1, 'new'), _order(2, 'preparing')];
