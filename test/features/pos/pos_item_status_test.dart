import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:acafe_customer/common/models/api_response_model.dart';
import 'package:acafe_customer/common/models/config_model.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_manager_repo.dart';
import 'package:acafe_customer/features/pos/domain/pos_advance_outcome.dart';
import 'package:acafe_customer/features/pos/domain/pos_item_prep_status.dart';
import 'package:acafe_customer/features/pos/domain/pos_order_card.dart';
import 'package:acafe_customer/features/pos/domain/pos_order_detail.dart';
import 'package:acafe_customer/features/pos/domain/pos_orders_repo.dart';
import 'package:acafe_customer/features/pos/widgets/pos_item_status_widgets.dart';
import 'package:acafe_customer/features/pos/widgets/pos_order_card_tile.dart';
import 'package:acafe_customer/features/pos/widgets/pos_order_more_menu.dart';
import 'package:acafe_customer/features/pos/widgets/pos_order_detail_overlay.dart';
import 'package:acafe_customer/features/splash/domain/reposotories/splash_repo.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Per-item kitchen status in the POS Orders overlay.
///
/// The case that matters most here is the mixed one — a coffee finished while
/// a dish is still cooking — because it is the whole reason item status exists
/// separately from order status.
///
/// Also renders the goldens for the Phase 3 deliverable.

// ── Fixtures ─────────────────────────────────────────────────────────────

const int _coffeeId = 501;
const int _poffertjesId = 502;

Map<String, dynamic> _item({
  required int id,
  required String name,
  required String prepStatus,
  double price = 4.5,
  List<String> addons = const [],
}) =>
    <String, dynamic>{
      'id': id,
      'prep_status': prepStatus,
      'name': name,
      'image': null,
      'quantity': 1,
      'unit_price': price,
      'instruction': null,
      'variations': const [],
      'addons': [
        for (final String a in addons) {'name': a, 'quantity': 1},
      ],
    };

/// A two-line order whose lines can each be set independently.
Map<String, dynamic> _payload({
  required String coffee,
  required String poffertjes,
  String orderStatus = 'preparing',
}) {
  final List<Map<String, dynamic>> items = [
    _item(
      id: _coffeeId,
      name: 'Flat White',
      prepStatus: coffee,
      addons: const ['Oat Milk'],
    ),
    _item(
      id: _poffertjesId,
      name: 'Poffertjes',
      prepStatus: poffertjes,
      price: 6.9,
    ),
  ];

  final int ready =
      items.where((i) => i['prep_status'] == 'ready').length;

  return <String, dynamic>{
    'id': 4312,
    'created_at': DateTime(2026, 6, 23, 10, 40).toIso8601String(),
    'order_status': orderStatus,
    'order_type': 'pos',
    'channel_key': 'counter_pos',
    'display_method': 'card',
    'payment_status': 'paid',
    'table': null,
    'customer_name': 'Max Mustermann',
    'customer_phone': null,
    'customer_email': null,
    'order_note': null,
    'items': items,
    'items_ready': ready,
    'items_total': items.length,
    'subtotal': 11.4,
    'discount': 0,
    'total': 11.4,
  };
}

PosOrderCard _card(String status) => PosOrderCard(
      id: 4312,
      createdAt: DateTime(2026, 6, 23, 10, 40),
      orderStatus: status,
      orderType: 'pos',
      channelKey: 'counter_pos',
      orderAmount: 11.4,
      customerName: 'Max Mustermann',
      addressLines: const [],
      displayMethod: 'card',
      itemStates: const [PrepStatus.ready, PrepStatus.preparing],
    );

class _StubSplashProvider extends SplashProvider {
  _StubSplashProvider({required super.splashRepo});

  @override
  ConfigModel? get configModel => ConfigModel(
        currencySymbol: '€',
        currencySymbolPosition: 'left',
        decimalPointSettings: 2,
      );
}

class _StubManagerRepo implements KioskManagerRepo {
  Map<String, dynamic> payload;
  int detailCalls = 0;

  _StubManagerRepo(this.payload);

  @override
  Future<ApiResponseModel> getTransactionDetail(int id) async {
    detailCalls++;
    return ApiResponseModel.withSuccess(Response(
      requestOptions: RequestOptions(path: '/transactions/$id'),
      statusCode: 200,
      data: payload,
    ));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Records item writes and answers with whatever the test has queued.
class _StubOrdersRepo implements PosOrdersRepo {
  @override
  DioClient get dioClient => throw UnimplementedError();

  final List<({int? detailId, String status})> calls = [];

  int statusCode = 200;
  Map<String, dynamic>? body;

  /// Set to hold a write open so a test can observe the in-flight state.
  Completer<void>? gate;

  @override
  Future<ApiResponseModel> updateItemStatus({
    required int orderId,
    required int orderDetailId,
    required String status,
  }) async {
    calls.add((detailId: orderDetailId, status: status));
    if (gate != null) await gate!.future;
    return _respond(orderId, orderDetailId, status);
  }

  @override
  Future<ApiResponseModel> bulkUpdateItemStatus({
    required int orderId,
    required String status,
  }) async {
    calls.add((detailId: null, status: status));
    if (gate != null) await gate!.future;
    return _respond(orderId, null, status);
  }

  ApiResponseModel _respond(int orderId, int? detailId, String status) =>
      ApiResponseModel.withSuccess(Response(
        requestOptions: RequestOptions(path: '/items/status'),
        statusCode: statusCode,
        data: body ??
            <String, dynamic>{
              'order_id': orderId,
              'order_detail_id': detailId,
              'prep_status': detailId == null ? null : status,
              'order_status': 'preparing',
              'advanced_to': null,
              'item_states': [
                {'id': _coffeeId, 'prep_status': 'ready'},
                {
                  'id': _poffertjesId,
                  'prep_status': detailId == _poffertjesId ? status : 'preparing'
                },
              ],
              'items_ready': 1,
              'items_total': 2,
              'message': 'Item status updated!',
            },
      ));

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Future<void> _pump(
  WidgetTester tester, {
  required _StubManagerRepo manager,
  required _StubOrdersRepo orders,
  Size size = const Size(1366, 1024),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SplashProvider>(
          create: (_) => _StubSplashProvider(
            splashRepo: SplashRepo(
              dioClient: DioClient(
                '',
                null,
                loggingInterceptor: LoggingInterceptor(),
                sharedPreferences: prefs,
              ),
              sharedPreferences: prefs,
            ),
          ),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFFFDFBF4),
          body: PosOrderDetailOverlay(
            order: _card('preparing'),
            repo: manager,
            ordersRepo: orders,
            onAdvance: (_) async => const PosAdvanceResult.advanced(),
            onSetStatus: (_, __) async => null,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _loadFonts() async {
  const Map<String, List<String>> families = {
    'Loew': [
      'assets/fonts/Loew-Regular.ttf',
      'assets/fonts/Loew-Medium.ttf',
      'assets/fonts/Loew-Bold.ttf',
      'assets/fonts/Loew-ExtraBold.ttf',
    ],
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

  final String? flutterRoot =
      Platform.environment['FLUTTER_ROOT'] ?? _flutterRootFromDartExecutable();
  if (flutterRoot == null) return;
  final File icons = File(
    '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (!icons.existsSync()) return;
  final iconLoader = FontLoader('MaterialIcons')
    ..addFont(icons
        .readAsBytes()
        .then((bytes) => ByteData.view(Uint8List.fromList(bytes).buffer)));
  await iconLoader.load();
}

String? _flutterRootFromDartExecutable() {
  final List<String> parts = Platform.resolvedExecutable.split('/');
  final int index = parts.indexOf('bin');
  if (index <= 0) return null;
  return parts.sublist(0, index).join('/');
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await _loadFonts();
  });

  group('per-item status', () {
    testWidgets('a mixed order shows each item its own status', (tester) async {
      final manager = _StubManagerRepo(
        _payload(coffee: 'ready', poffertjes: 'preparing'),
      );
      await _pump(tester, manager: manager, orders: _StubOrdersRepo());

      // Both statuses on screen at once -- the point of the whole feature.
      expect(find.text('Ready'), findsOneWidget);
      expect(find.text('Preparing'), findsOneWidget);
      expect(find.text('1 of 2 ready'), findsOneWidget);

      // Only the valid next action per item: Undo for ready, Done for
      // preparing. Neither offers Start.
      expect(find.text('Undo'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Start'), findsNothing);
    });

    testWidgets('a ready item is struck through', (tester) async {
      final manager = _StubManagerRepo(
        _payload(coffee: 'ready', poffertjes: 'preparing'),
      );
      await _pump(tester, manager: manager, orders: _StubOrdersRepo());

      // The style is inherited from the row's AnimatedDefaultTextStyle, so the
      // assertion reads what was actually painted rather than Text.style.
      TextStyle painted(String text) => (tester
              .renderObject<RenderParagraph>(find.text(text)))
          .text
          .style!;

      expect(painted('Flat White').decoration, TextDecoration.lineThrough);
      expect(painted('Poffertjes').decoration, isNot(TextDecoration.lineThrough));
    });

    testWidgets('a pending item offers Start only', (tester) async {
      final manager = _StubManagerRepo(
        _payload(coffee: 'pending', poffertjes: 'pending', orderStatus: 'new'),
      );
      await _pump(tester, manager: manager, orders: _StubOrdersRepo());

      expect(find.text('Start'), findsNWidgets(2));
      expect(find.text('Done'), findsNothing);
      expect(find.text('Undo'), findsNothing);
      expect(find.text('0 of 2 ready'), findsOneWidget);
    });
  });

  group('writes', () {
    testWidgets('tapping Done sends the item forward one rung', (tester) async {
      final manager = _StubManagerRepo(
        _payload(coffee: 'ready', poffertjes: 'preparing'),
      );
      final orders = _StubOrdersRepo();
      await _pump(tester, manager: manager, orders: orders);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(orders.calls, hasLength(1));
      expect(orders.calls.single.detailId, _poffertjesId);
      expect(orders.calls.single.status, 'ready');
    });

    testWidgets('a second tap while one is in flight is dropped',
        (tester) async {
      final manager = _StubManagerRepo(
        _payload(coffee: 'ready', poffertjes: 'preparing'),
      );
      final orders = _StubOrdersRepo()..gate = Completer<void>();
      await _pump(tester, manager: manager, orders: orders);

      await tester.tap(find.text('Done'));
      await tester.pump();

      // The button is now a spinner, so the label is gone and a second tap
      // has nothing to hit -- but tap the button itself to be sure.
      await tester.tap(find.byType(PosItemActionButton).last);
      await tester.pump();

      expect(orders.calls, hasLength(1), reason: 'no double submit');

      orders.gate!.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    });

    testWidgets('a stale 409 lands the item on the state the server reports',
        (tester) async {
      final manager = _StubManagerRepo(
        _payload(coffee: 'ready', poffertjes: 'preparing'),
      );
      final orders = _StubOrdersRepo()
        ..statusCode = 409
        ..body = <String, dynamic>{
          'errors': [
            {
              'code': 'stale_transition',
              'message': 'This item has already been updated elsewhere',
              'prep_status': 'ready',
            }
          ],
        };

      await _pump(tester, manager: manager, orders: orders);

      await tester.tap(find.text('Done'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Corrected to the server's value, not rolled back to the stale one.
      expect(find.text('Updated elsewhere — refreshed'), findsOneWidget);
    });
  });

  group('on hold', () {
    testWidgets('a held order shows the banner and disables actions',
        (tester) async {
      final manager = _StubManagerRepo(_payload(
        coffee: 'ready',
        poffertjes: 'preparing',
        orderStatus: 'on_hold',
      ));
      final orders = _StubOrdersRepo();
      await _pump(tester, manager: manager, orders: orders);

      expect(find.byType(PosOnHoldBanner), findsOneWidget);
      expect(find.text('Order on hold — items locked'), findsOneWidget);

      // The chips stay visible, but nothing can be written.
      expect(find.text('Ready'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(orders.calls, isEmpty, reason: 'items are frozen while held');
    });
  });

  group('polling', () {
    testWidgets('re-reads every 10s and stops on dispose', (tester) async {
      final manager = _StubManagerRepo(
        _payload(coffee: 'ready', poffertjes: 'preparing'),
      );
      await _pump(tester, manager: manager, orders: _StubOrdersRepo());

      expect(manager.detailCalls, 1);

      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(manager.detailCalls, 2);

      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(manager.detailCalls, 3);

      // Tearing the overlay down must cancel the timer; a leaked one would
      // keep polling a closed modal forever.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 30));
      expect(manager.detailCalls, 3, reason: 'timer cancelled on dispose');
    });

    testWidgets('a poll does not overwrite an item mid-write', (tester) async {
      final manager = _StubManagerRepo(
        _payload(coffee: 'ready', poffertjes: 'preparing'),
      );
      final orders = _StubOrdersRepo()..gate = Completer<void>();
      await _pump(tester, manager: manager, orders: orders);

      await tester.tap(find.text('Done'));
      await tester.pump();

      // A poll lands while the write is still out, still reporting the OLD
      // value. The optimistic 'ready' must survive it.
      //
      // Discrete pumps rather than pumpAndSettle: the in-flight button is
      // showing a spinner, so the tree never goes quiet.
      await tester.pump(const Duration(seconds: 10));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // The optimistic 'ready' must survive a poll that still reports the old
      // value for that line.
      expect(
        find.descendant(
          of: find.byType(PosItemStatusChip),
          matching: find.text('Preparing'),
        ),
        findsNothing,
        reason: 'the in-flight item must not be dragged back by a poll',
      );

      orders.gate!.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    });
  });

  group('goldens', () {
    Future<void> shoot(
      WidgetTester tester,
      String file, {
      required String coffee,
      required String poffertjes,
      String orderStatus = 'preparing',
    }) async {
      await _pump(
        tester,
        manager: _StubManagerRepo(_payload(
          coffee: coffee,
          poffertjes: poffertjes,
          orderStatus: orderStatus,
        )),
        orders: _StubOrdersRepo(),
      );
      await expectLater(
        find.byType(PosOrderDetailOverlay),
        matchesGoldenFile('goldens/$file'),
      );
    }

    testWidgets('every item pending', (tester) async {
      await shoot(tester, 'pos_item_status_pending.png',
          coffee: 'pending', poffertjes: 'pending', orderStatus: 'new');
    });

    testWidgets('mixed — coffee ready, poffertjes preparing', (tester) async {
      await shoot(tester, 'pos_item_status_mixed.png',
          coffee: 'ready', poffertjes: 'preparing');
    });

    testWidgets('every item ready', (tester) async {
      await shoot(tester, 'pos_item_status_all_ready.png',
          coffee: 'ready',
          poffertjes: 'ready',
          orderStatus: 'item_to_collect');
    });

    testWidgets('on hold', (tester) async {
      await shoot(tester, 'pos_item_status_on_hold.png',
          coffee: 'ready', poffertjes: 'preparing', orderStatus: 'on_hold');
    });

    testWidgets('completed', (tester) async {
      await shoot(tester, 'pos_item_status_completed.png',
          coffee: 'ready', poffertjes: 'ready', orderStatus: 'completed');
    });
  });

  group('board card', () {
    testWidgets('a card shows its item progress', (tester) async {
      tester.view.physicalSize = const Size(980, 420);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final prefs = await SharedPreferences.getInstance();

      PosOrderCard card(String status, List<PrepStatus> states) => PosOrderCard(
            id: 4312,
            createdAt: DateTime(2026, 6, 23, 10, 40),
            orderStatus: status,
            orderType: 'pos',
            channelKey: 'counter_pos',
            orderAmount: 11.4,
            customerName: 'Max Mustermann',
            addressLines: const [],
            displayMethod: 'card',
            branchName: 'Ludwigsfelde',
            itemStates: states,
          );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SplashProvider>(
              create: (_) => _StubSplashProvider(
                splashRepo: SplashRepo(
                  dioClient: DioClient(
                    '',
                    null,
                    loggingInterceptor: LoggingInterceptor(),
                    sharedPreferences: prefs,
                  ),
                  sharedPreferences: prefs,
                ),
              ),
            ),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: const Color(0xFFFDFBF4),
              body: Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final ({String status, List<PrepStatus> states}) c in [
                      (
                        status: 'new',
                        states: [PrepStatus.pending, PrepStatus.pending]
                      ),
                      (
                        status: 'preparing',
                        states: [PrepStatus.ready, PrepStatus.preparing]
                      ),
                      (
                        status: 'item_to_collect',
                        states: [PrepStatus.ready, PrepStatus.ready]
                      ),
                    ]) ...[
                      SizedBox(
                        width: 288,
                        child: PosOrderCardTile(
                          order: card(c.status, c.states),
                          now: DateTime(2026, 6, 23, 10, 55),
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The counter can read progress without opening anything.
      expect(find.text('0/2 ready'), findsOneWidget);
      expect(find.text('1/2 ready'), findsOneWidget);
      expect(find.text('2/2 ready'), findsOneWidget);

      // And the CTA names the item move it performs.
      expect(find.text('Start all items'), findsNothing,
          reason: 'a NEW card keeps the bare checkmark');
      expect(find.text('Mark all ready'), findsOneWidget);
      expect(find.text('Mark as complete'), findsOneWidget);

      await expectLater(
        find.byType(Row).first,
        matchesGoldenFile('goldens/pos_item_status_board_cards.png'),
      );
    });
  });

  group('more menu', () {
    testWidgets('opens pause and cancel, and confirms a cancel',
        (tester) async {
      final manager = _StubManagerRepo(
        _payload(coffee: 'ready', poffertjes: 'preparing'),
      );
      final List<String> sent = [];

      tester.view.physicalSize = const Size(1366, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SplashProvider>(
              create: (_) => _StubSplashProvider(
                splashRepo: SplashRepo(
                  dioClient: DioClient('', null,
                      loggingInterceptor: LoggingInterceptor(),
                      sharedPreferences: prefs),
                  sharedPreferences: prefs,
                ),
              ),
            ),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: const Color(0xFFFDFBF4),
              body: PosOrderDetailOverlay(
                order: _card('preparing'),
                repo: manager,
                ordersRepo: _StubOrdersRepo(),
                onAdvance: (_) async => const PosAdvanceResult.advanced(),
                onSetStatus: (_, String status) async {
                  sent.add(status);
                  return null;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PosOrderMoreButton));
      await tester.pumpAndSettle();

      expect(find.text('Mark on hold'), findsOneWidget);
      expect(find.text('Cancel order'), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/pos_item_status_more_menu.png'),
      );

      await tester.tap(find.text('Cancel order'));
      await tester.pumpAndSettle();

      // Destructive, so it is confirmed before anything is sent.
      expect(find.text('Cancel order #4312?'), findsOneWidget);
      expect(sent, isEmpty);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/pos_item_status_cancel_confirm.png'),
      );

      await tester.tap(find.text('Keep order'));
      await tester.pumpAndSettle();
      expect(sent, isEmpty, reason: 'declining sends nothing');
    });
  });
}
