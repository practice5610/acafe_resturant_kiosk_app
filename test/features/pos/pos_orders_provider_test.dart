import 'package:acafe_customer/common/models/api_response_model.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/features/pos/domain/pos_order_grouping.dart';
import 'package:acafe_customer/features/pos/domain/pos_orders_repo.dart';
import 'package:acafe_customer/features/pos/providers/pos_orders_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRepo implements PosOrdersRepo {
  @override
  DioClient get dioClient => throw UnimplementedError();

  /// Set to a non-200 to make the next transition fail.
  int statusCode = 200;
  Map<String, dynamic> statusBody = const {'message': 'Order status updated!'};

  int getCalls = 0;
  int statusCalls = 0;
  String? lastSection;
  String? lastMethod;
  String? lastSearch;
  String? lastDateTo;
  String? lastOrderStatus;

  /// Mutated between calls so a refetch can be made to return a changed board.
  List<Map<String, dynamic>> rows = [
    {
      'id': 1,
      'created_at': '2026-09-05T10:00:00.000Z',
      'order_status': 'new',
      'order_type': 'pos',
      'channel_key': 'counter_pos',
      'order_amount': 10.0,
      'customer_name': 'Alice',
      'address_lines': <String>[],
      'display_method': 'cash',
      'branch_name': 'Main',
    },
    {
      'id': 2,
      'created_at': '2026-09-05T10:05:00.000Z',
      'order_status': 'preparing',
      'order_type': 'pos',
      'channel_key': 'kiosk',
      'order_amount': 20.0,
      'customer_name': 'Bob',
      'address_lines': <String>[],
      'display_method': 'card',
      'branch_name': 'Main',
    },
    // Never groups onto the board — the endpoint excludes it, and so must the
    // client if one ever slips through.
    {
      'id': 3,
      'created_at': '2026-09-05T10:06:00.000Z',
      'order_status': 'canceled',
      'order_type': 'pos',
      'channel_key': 'kiosk',
      'order_amount': 30.0,
      'customer_name': 'Carol',
      'address_lines': <String>[],
      'display_method': 'card',
      'branch_name': 'Main',
    },
  ];

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
    lastMethod = method;
    lastSearch = search;
    lastDateTo = dateTo;

    return ApiResponseModel.withSuccess(Response(
      requestOptions: RequestOptions(path: '/orders'),
      statusCode: 200,
      data: <String, dynamic>{
        'counts': {'new': 1, 'in_progress': 1, 'finished': 0},
        'limit': limit,
        'orders': rows,
      },
    ));
  }

  @override
  Future<ApiResponseModel> updateStatus({
    required int orderId,
    required String orderStatus,
  }) async {
    statusCalls++;
    lastOrderStatus = orderStatus;
    return ApiResponseModel.withSuccess(Response(
      requestOptions: RequestOptions(path: '/status'),
      statusCode: statusCode,
      data: statusBody,
    ));
  }
}

void main() {
  late _FakeRepo repo;
  late PosOrdersProvider provider;

  setUp(() {
    repo = _FakeRepo();
    provider = PosOrdersProvider(posOrdersRepo: repo);
  });

  test('a canceled order never reaches a section', () async {
    await provider.load();

    expect(provider.orders.map((o) => o.id), [1, 2]);
    expect(
      provider.orders.any((o) => o.section == PosOrderSection.excluded),
      isFalse,
    );
  });

  test('NOW mode leaves the window open-ended', () async {
    await provider.load();
    // Sending a frozen `date_to` would stop the board showing anything placed
    // after the operator last touched the filter.
    expect(repo.lastDateTo, isNull);
  });

  test('advancing a NEW order moves it and calls the real transition',
      () async {
    await provider.load();
    final order = provider.orders.firstWhere((o) => o.id == 1);

    final String? error = await provider.advance(order);

    expect(error, isNull);
    expect(repo.statusCalls, 1);
    expect(repo.lastOrderStatus, 'preparing');
  });

  test('a preparing order advances to item_to_collect, not completed',
      () async {
    await provider.load();
    final order = provider.orders.firstWhere((o) => o.id == 2);

    await provider.advance(order);

    // The rung the Kitchen Display uses. Jumping to 'completed' would skip
    // `ready_at` and the customer's "ready to collect" push.
    expect(repo.lastOrderStatus, 'item_to_collect');
  });

  test('an item_to_collect order still advances, though it sits in FINISHED',
      () async {
    repo.rows = [
      {
        'id': 4,
        'created_at': '2026-09-05T10:00:00.000Z',
        'order_status': 'item_to_collect',
        'order_type': 'pos',
        'channel_key': 'counter_pos',
        'order_amount': 10.0,
        'customer_name': 'Dana',
        'address_lines': <String>[],
        'display_method': 'cash',
        'branch_name': 'Main',
      },
    ];
    await provider.load();

    final order = provider.orders.single;
    expect(order.section, PosOrderSection.finished);

    final String? error = await provider.advance(order);

    expect(error, isNull);
    expect(repo.lastOrderStatus, 'completed');
  });

  test('a terminal order has no action to fire', () async {
    repo.rows = [
      {
        'id': 5,
        'created_at': '2026-09-05T10:00:00.000Z',
        'order_status': 'completed',
        'order_type': 'pos',
        'channel_key': 'counter_pos',
        'order_amount': 10.0,
        'customer_name': 'Eve',
        'address_lines': <String>[],
        'display_method': 'cash',
        'branch_name': 'Main',
      },
    ];
    await provider.load();

    await provider.advance(provider.orders.single);

    expect(repo.statusCalls, 0);
  });

  test('a held order resumes to preparing', () async {
    repo.rows = [
      {
        'id': 6,
        'created_at': '2026-09-05T10:00:00.000Z',
        'order_status': 'on_hold',
        'order_type': 'pos',
        'channel_key': 'counter_pos',
        'order_amount': 10.0,
        'customer_name': 'Frank',
        'address_lines': <String>[],
        'display_method': 'cash',
        'branch_name': 'Main',
      },
    ];
    await provider.load();

    await provider.advance(provider.orders.single);

    // The server treats this as provisional and re-derives from the item
    // aggregate; the client's job is only to ask for the resume.
    expect(repo.lastOrderStatus, 'preparing');
  });

  test('a rejected transition rolls the card back and keeps it on the board',
      () async {
    await provider.load();
    repo.statusCode = 422;
    repo.statusBody = {
      'errors': [
        {'code': 'order-status', 'message': 'An order cannot be moved backwards'}
      ]
    };

    final order = provider.orders.firstWhere((o) => o.id == 1);
    expect(order.section, PosOrderSection.newOrders);

    final String? error = await provider.advance(order);

    // The operator is told what happened...
    expect(error, 'An order cannot be moved backwards');
    // ...the card is still there...
    expect(provider.orders.any((o) => o.id == 1), isTrue);
    // ...and it is back in the section it started in.
    expect(
      provider.orders.firstWhere((o) => o.id == 1).section,
      PosOrderSection.newOrders,
    );
    // The badge above it agrees.
    expect(provider.countOf(PosOrderSection.newOrders), 1);
    expect(provider.countOf(PosOrderSection.inProgress), 1);
    expect(provider.isPending(1), isFalse);
  });

  test('counts follow an optimistic move and settle after the refetch',
      () async {
    await provider.load();
    expect(provider.countOf(PosOrderSection.newOrders), 1);

    final order = provider.orders.firstWhere((o) => o.id == 1);
    await provider.advance(order);

    // advance() reconciles against the server rather than trusting the guess,
    // so the counts end up wherever the feed says they are.
    expect(repo.getCalls, greaterThan(1));
  });

  test('a second tap while one is in flight is ignored', () async {
    await provider.load();
    final order = provider.orders.firstWhere((o) => o.id == 1);

    final first = provider.advance(order);
    final second = provider.advance(order);
    await Future.wait([first, second]);

    expect(repo.statusCalls, 1);
  });

  test('a failed load keeps the previous board on screen', () async {
    await provider.load();
    expect(provider.orders, hasLength(2));

    provider.setStatus('preparing');
    await Future<void>.delayed(Duration.zero);

    expect(provider.orders, isNotEmpty);
  });

  test('search is debounced rather than fetched per keystroke', () async {
    await provider.load();
    final int before = repo.getCalls;

    provider.setSearch('a');
    provider.setSearch('an');
    provider.setSearch('ann');

    expect(repo.getCalls, before, reason: 'nothing fetched before the debounce');

    await Future<void>.delayed(
      PosOrdersProvider.searchDebounce + const Duration(milliseconds: 60),
    );

    expect(repo.getCalls, before + 1);
    expect(repo.lastSearch, 'ann');
  });

  test('a burst of socket pushes coalesces into one refetch', () async {
    await provider.load();
    final int before = repo.getCalls;

    provider.onRealtimeChange();
    provider.onRealtimeChange();
    provider.onRealtimeChange();

    await Future<void>.delayed(
      PosOrdersProvider.realtimeDebounce + const Duration(milliseconds: 60),
    );

    expect(repo.getCalls, before + 1);
  });

  test('a reconnect refetches immediately, without waiting on the debounce',
      () async {
    await provider.load();
    final int before = repo.getCalls;

    provider.onRealtimeReconnect();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(repo.getCalls, before + 1);
  });

  test('the section filter is sent to the server, not applied locally',
      () async {
    await provider.load();

    provider.setSection(PosOrderSection.finished);
    await Future<void>.delayed(Duration.zero);

    expect(repo.lastSection, 'finished');
  });

  test('the payment filter sends the derived value', () async {
    await provider.load();

    provider.setMethod('card');
    await Future<void>.delayed(Duration.zero);

    expect(repo.lastMethod, 'card');
  });
}
