import 'package:acafe_customer/common/models/api_response_model.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/di_container.dart' as di;
import 'package:acafe_customer/features/kiosk/domain/kiosk_manager_repo.dart';
import 'package:acafe_customer/features/pos/domain/pos_orders_repo.dart';
import 'package:acafe_customer/features/pos/domain/pos_orders_spec.dart';
import 'package:acafe_customer/features/pos/screens/pos_orders_list_screen.dart';
import 'package:acafe_customer/features/pos/widgets/pos_complete_confirmation_dialog.dart';
import 'package:acafe_customer/features/pos/widgets/pos_dropdown.dart';
import 'package:acafe_customer/features/pos/widgets/pos_order_card_tile.dart';
import 'package:acafe_customer/features/pos/widgets/pos_order_detail_overlay.dart';
import 'package:acafe_customer/features/pos/widgets/pos_order_more_menu.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Backs the detail overlay's own fetch, so tapping a card can open the real
/// overlay instead of the tap being a silent no-op ([KioskManagerRepo] not
/// being registered is exactly how the board's `_openDetail` declines to
/// open it).
class _StubManagerRepo implements KioskManagerRepo {
  @override
  Future<ApiResponseModel> getTransactionDetail(int id) async =>
      ApiResponseModel.withSuccess(Response<dynamic>(
        requestOptions: RequestOptions(path: '/'),
        statusCode: 200,
        data: {
          'id': id,
          'created_at': DateTime.now().toIso8601String(),
          'order_status': 'new',
          'order_type': 'pos',
          'channel_key': 'counter_pos',
          'display_method': 'cash',
          'payment_status': 'paid',
          'table': null,
          'customer_name': 'Max Mustermann',
          'customer_phone': null,
          'customer_email': null,
          'order_note': null,
          'items': const <dynamic>[],
          'subtotal': 11.67,
          'discount': 0,
          'total': 11.67,
        },
      ));

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// Serves a fixed board so layout can be asserted without a network or a
/// service locator. The rows are shaped exactly like the real
/// `GET /api/v1/kiosk/manager/orders` payload, including the cases that decide
/// a card's height: a delivery order with two address lines, a counter order
/// with none, and a finished order.
class _StubOrdersRepo implements PosOrdersRepo {
  @override
  DioClient get dioClient => throw UnimplementedError();

  int statusCalls = 0;

  /// Off by default so the fixed 5-order board every other test in this file
  /// counts on stays exactly 5. Only the resume test opts in.
  bool _includeOnHold = false;
  void addOnHoldOrder() => _includeOnHold = true;

  static Map<String, dynamic> _row({
    required int id,
    required String status,
    required String channel,
    List<String> address = const [],
    String name = 'Max Mustermann',
    int minutesAgo = 1,
  }) =>
      <String, dynamic>{
        'id': id,
        'created_at': DateTime.now()
            .toUtc()
            .subtract(Duration(minutes: minutesAgo))
            .toIso8601String(),
        'order_status': status,
        'order_type': 'pos',
        'channel_key': channel,
        'order_amount': 11.67,
        'customer_name': name,
        'address_lines': address,
        'display_method': 'card',
        'branch_name': 'Acafe/Ludwigsfelde',
      };

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
    return ApiResponseModel.withSuccess(Response(
      requestOptions: RequestOptions(path: '/orders'),
      statusCode: 200,
      data: <String, dynamic>{
        'counts': {
          'new': 2,
          'preparing': 1,
          'ready_to_collect': 1,
          'on_hold': _includeOnHold ? 1 : 0,
          'completed': 1,
        },
        'limit': limit,
        'orders': [
          _row(
            id: 27364,
            status: 'new',
            channel: 'web_app',
            address: ['Potsdamer Str. 33', '14974 Ludwigsfelde'],
          ),
          // 20 minutes old and still unfinished — the urgent case, which is
          // what draws the 4px left bar.
          _row(
            id: 27365,
            status: 'new',
            channel: 'kiosk',
            minutesAgo: 20,
            name: 'A customer with a very long name indeed, truly',
          ),
          _row(id: 27363, status: 'preparing', channel: 'counter_pos'),
          // Drawn as finished but not terminal — it must still carry the
          // action that finishes it.
          _row(id: 27359, status: 'item_to_collect', channel: 'counter_pos'),
          _row(id: 27358, status: 'completed', channel: 'counter_pos'),
          if (_includeOnHold)
            _row(id: 27357, status: 'on_hold', channel: 'counter_pos'),
        ],
      },
    ));
  }

  @override
  Future<ApiResponseModel> updateStatus({
    required int orderId,
    required String orderStatus,
  }) async {
    statusCalls++;
    return ApiResponseModel.withSuccess(Response(
      requestOptions: RequestOptions(path: '/status'),
      statusCode: 200,
      data: <String, dynamic>{'message': 'Order status updated!'},
    ));
  }

  // ── Item-status endpoints ──────────────────────────────────────────────
  int itemStatusCalls = 0;
  int bulkItemStatusCalls = 0;
  String? lastItemStatus;
  int? lastItemDetailId;

  /// Swap in a non-200 to exercise the rejection paths.
  int itemStatusCode = 200;
  Map<String, dynamic>? itemStatusBody;

  @override
  Future<ApiResponseModel> updateItemStatus({
    required int orderId,
    required int orderDetailId,
    required String status,
  }) async {
    itemStatusCalls++;
    lastItemDetailId = orderDetailId;
    lastItemStatus = status;
    return _itemResponse(orderId, orderDetailId, status);
  }

  @override
  Future<ApiResponseModel> bulkUpdateItemStatus({
    required int orderId,
    required String status,
  }) async {
    bulkItemStatusCalls++;
    lastItemStatus = status;
    return _itemResponse(orderId, null, status);
  }

  ApiResponseModel _itemResponse(int orderId, int? detailId, String status) {
    return ApiResponseModel.withSuccess(Response(
      requestOptions: RequestOptions(path: '/items/status'),
      statusCode: itemStatusCode,
      data: itemStatusBody ??
          <String, dynamic>{
            'order_id': orderId,
            'order_detail_id': detailId,
            'prep_status': detailId == null ? null : status,
            'order_status': status == 'ready' ? 'item_to_collect' : 'preparing',
            'advanced_to': status == 'ready' ? 'item_to_collect' : 'preparing',
            'item_states': <Map<String, dynamic>>[],
            'items_ready': status == 'ready' ? 1 : 0,
            'items_total': 1,
            'message': 'Item status updated!',
          },
    ));
  }
}

Widget _board(_StubOrdersRepo repo) => MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFFF7F1DE),
        // Keyed to the repo: without it a second pumpWidget in the same test
        // reuses the element, so ChangeNotifierProvider.create never re-runs
        // and the board keeps talking to the *previous* stub.
        body: PosOrdersListScreen(key: ValueKey(repo), repo: repo),
      ),
    );

/// Height of the stand-in nav bar in [_shellBoard].
const double _shellHeaderHeight = 100;

/// The board as the app really hosts it: the go_router `ShellRoute` mounts the
/// nav bar once and gives the tab its own nested [Navigator] *below* it, so
/// that navigator's overlay does not start at the top of the screen. [_board]
/// hides this — its only navigator starts at (0, 0) — which is how the ⋮ menu
/// could open a whole nav-bar height under its button and still pass.
Widget _shellBoard(_StubOrdersRepo repo) => MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFFF7F1DE),
        body: Column(
          children: [
            const SizedBox(height: _shellHeaderHeight),
            Expanded(
              child: Navigator(
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    backgroundColor: const Color(0xFFF7F1DE),
                    body: PosOrdersListScreen(key: ValueKey(repo), repo: repo),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

void main() {
  setUp(() {
    if (!di.sl.isRegistered<KioskManagerRepo>()) {
      di.sl.registerLazySingleton<KioskManagerRepo>(() => _StubManagerRepo());
    }
    // The overlay writes item status through the board's own repo, so the
    // locator needs it too before a card can open its detail.
    if (!di.sl.isRegistered<PosOrdersRepo>()) {
      di.sl.registerLazySingleton<PosOrdersRepo>(() => _StubOrdersRepo());
    }
  });

  tearDown(() {
    if (di.sl.isRegistered<PosOrdersRepo>()) {
      di.sl.unregister<PosOrdersRepo>();
    }
    if (di.sl.isRegistered<KioskManagerRepo>()) {
      di.sl.unregister<KioskManagerRepo>();
    }
  });

  Future<void> pumpBoard(WidgetTester tester, _StubOrdersRepo repo,
      {Size size = const Size(1366, 944), bool inShell = false}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(inShell ? _shellBoard(repo) : _board(repo));
    await tester.pump();
    await tester.pump();
  }

  // Regression: opening a filter must never throw (the board once showed the
  // app's "Something went wrong" ErrorWidget in place of the filter row).
  testWidgets('every filter dropdown opens below its pill and picks cleanly',
      (tester) async {
    await pumpBoard(tester, _StubOrdersRepo(), size: const Size(2000, 1200));
    // Figma 1915:15802…15814 draws the dropdowns in capitals.
    for (final String label in const [
      'ALL SOURCES',
      'ALL TYPES',
      'ALL PAYMENT METHODS',
      'ANY STATUS',
    ]) {
      final Finder pill = find.text(label);
      expect(pill, findsOneWidget, reason: label);
      final Rect pillRect = tester.getRect(pill);
      await tester.tap(pill);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: label);

      final Rect menu = tester.getRect(find.byKey(PosDropdown.menuKey));
      expect(menu.top, greaterThan(pillRect.bottom), reason: label);

      // Pick the second option, then put the filter back to "all".
      await tester.tap(find.byKey(PosDropdown.itemKey(1)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: label);
      expect(find.byKey(PosDropdown.menuKey), findsNothing);
    }
    expect(find.byType(ErrorWidget), findsNothing);
  });

  /// Opens order [id]'s ⋮ menu and lets it settle.
  Future<void> openMenu(WidgetTester tester, int id) async {
    await tester.tap(find.byKey(PosOrderCardTile.menuKeyFor(id)));
    await tester.pumpAndSettle();
  }

  group('the card opens the detail; its ⋮ carries the actions', () {
    testWidgets('every card carries a ⋮, the finished one dimmed',
        (tester) async {
      await pumpBoard(tester, _StubOrdersRepo(), size: const Size(1366, 1500));
      for (final int id in [27364, 27365, 27363, 27359, 27358]) {
        expect(find.byKey(PosOrderCardTile.menuKeyFor(id)), findsOneWidget,
            reason: 'order $id');
      }

      // completed: nothing left to advance, pause or cancel.
      await openMenu(tester, 27358);
      expect(find.text('Cancel order'), findsNothing);
      expect(find.byType(PosOrderDetailOverlay), findsNothing);
    });

    testWidgets('tapping a card opens its detail overlay', (tester) async {
      final repo = _StubOrdersRepo();
      await pumpBoard(tester, repo, size: const Size(1366, 1500));

      // The customer-name block is part of the card body, not an action —
      // tapping it must fall through to the card's own tap handler.
      await tester.tap(find.text('Max Mustermann').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      expect(find.byType(PosOrderDetailOverlay), findsOneWidget);
    });

    testWidgets('the ⋮ opens its menu under the button, not the overlay',
        (tester) async {
      final repo = _StubOrdersRepo();
      await pumpBoard(tester, repo, size: const Size(1366, 1500));

      final Rect button =
          tester.getRect(find.byKey(PosOrderCardTile.menuKeyFor(27363)));
      await openMenu(tester, 27363);

      expect(find.byType(PosOrderDetailOverlay), findsNothing);
      final Rect row = tester.getRect(find.text('Mark as ready'));
      expect(row.top - button.bottom, inInclusiveRange(0, 60));
      expect(find.text('Mark on hold'), findsOneWidget);
      expect(find.text('Cancel order'), findsOneWidget);
    });

    // Regression: under the real nav bar the menu opened ~a nav-bar height
    // below the ⋮, over the next section, because it was placed with screen
    // coordinates inside the shell's nested navigator.
    testWidgets('under the POS nav bar the ⋮ menu still opens snug under it',
        (tester) async {
      await pumpBoard(tester, _StubOrdersRepo(),
          size: const Size(1366, 1500), inShell: true);

      final Rect button =
          tester.getRect(find.byKey(PosOrderCardTile.menuKeyFor(27363)));
      await openMenu(tester, 27363);

      final Rect menu = tester.getRect(find.byKey(PosOrderMoreMenu.menuKey));
      expect(menu.top - button.bottom, inInclusiveRange(0, 16));
      // Right-aligned to the ⋮, so it hangs over its own card.
      expect(menu.right, closeTo(button.right, 0.5));
      expect(find.text('Mark as ready'), findsOneWidget);
    });

    testWidgets('under the POS nav bar the detail ⋯ menu opens just above it',
        (tester) async {
      await pumpBoard(tester, _StubOrdersRepo(),
          size: const Size(1366, 1500), inShell: true);

      await tester.tap(find.text('Max Mustermann').first);
      await tester.pumpAndSettle();
      expect(find.byType(PosOrderDetailOverlay), findsOneWidget);

      final Rect button = tester.getRect(find.byType(PosOrderMoreButton));
      await tester.tap(find.byType(PosOrderMoreButton));
      await tester.pumpAndSettle();

      final Rect menu = tester.getRect(find.byKey(PosOrderMoreMenu.menuKey));
      expect(button.top - menu.bottom, inInclusiveRange(0, 16));
      expect(menu.left, closeTo(button.left, 0.5));
      expect(find.text('Mark on hold'), findsOneWidget);
    });

    testWidgets('cancelling from the ⋮ is confirmed before it is sent',
        (tester) async {
      final repo = _StubOrdersRepo();
      await pumpBoard(tester, repo, size: const Size(1366, 1500));

      await openMenu(tester, 27363);
      await tester.tap(find.text('Cancel order'));
      await tester.pumpAndSettle();

      expect(find.text('Cancel order #27363?'), findsOneWidget);
      expect(repo.statusCalls, 0, reason: 'nothing before confirming');

      await tester.tap(find.text('Keep order'));
      await tester.pumpAndSettle();
      expect(repo.statusCalls, 0);

      await openMenu(tester, 27363);
      await tester.tap(find.text('Cancel order'));
      await tester.pumpAndSettle();
      // The menu has closed, so the only "Cancel order" left is the dialog's
      // confirm button.
      await tester.tap(find.text('Cancel order'));
      await tester.pumpAndSettle();
      expect(repo.statusCalls, 1);
    });
  });

  testWidgets('the board stacks the five kitchen sections, not side by side',
      (tester) async {
    // Tall enough that the lazy board builds every section at once. On a
    // short one, a header is "found" while still in the cache area below the
    // viewport and the list then re-estimates its extent, so screen y +
    // scroll offset stops being a position.
    await pumpBoard(tester, _StubOrdersRepo(), size: const Size(1366, 2400));

    // Each card now carries its own status chip ("NEW" etc. in white, at the
    // chip's smaller size), so a bare find.text('NEW') would also catch
    // those — disambiguate by the section header's own text size.
    Finder header(String label) => find.byWidgetPredicate((widget) =>
        widget is Text &&
        widget.data == label &&
        widget.style?.fontSize == PosOrdersSpec.sectionHeaderSize);

    // The Kitchen Display's tab order, top to bottom. An empty section keeps
    // its header (with a 0) so the board's shape never shifts under the
    // operator.
    const List<String> order = [
      'NEW',
      'PREPARING',
      'READY TO COLLECT',
      'ON HOLD',
      'COMPLETED',
    ];
    final Finder board = find
        .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
        .first;
    double? lastY;
    double? newX;
    for (final String label in order) {
      await tester.scrollUntilVisible(header(label), 200, scrollable: board);
      expect(header(label), findsOneWidget, reason: label);
      final Offset at = tester.getTopLeft(header(label));
      final double y =
          at.dy + tester.state<ScrollableState>(board).position.pixels;
      // Figma draws every section at the full content width, one under the
      // next.
      if (lastY != null) expect(y, greaterThan(lastY), reason: label);
      lastY = y;
      newX ??= at.dx;
      expect(at.dx, newX, reason: label);
    }
  });

  testWidgets('cards hold the Figma 288px width and 12px gap', (tester) async {
    // Every card built at once — the lazy board leaves the lower sections'
    // cards unbuilt on a 944-tall screen now that cards carry their number.
    await pumpBoard(tester, _StubOrdersRepo(), size: const Size(1366, 2400));

    final Finder cards = find.byType(PosOrderCardTile);
    expect(cards, findsNWidgets(5));

    for (int i = 0; i < 5; i++) {
      expect(tester.getSize(cards.at(i)).width, PosOrdersSpec.cardWidth);
    }

    // The two NEW cards sit side by side on a 1366-wide board.
    final double firstRight = tester.getTopRight(cards.at(0)).dx;
    final double secondLeft = tester.getTopLeft(cards.at(1)).dx;
    expect(secondLeft - firstRight, closeTo(PosOrdersSpec.cardGap, 0.5));
  });

  testWidgets('every card leads with its own order number, no status chip',
      (tester) async {
    await pumpBoard(tester, _StubOrdersRepo(), size: const Size(1366, 2400));

    // Not in Figma 1915:15837 (clock, ⋮ and source badge only): the number is
    // a line above the name, in the name's size, on request (2026-10-19), so
    // a card can be matched to its receipt or ticket without opening it.
    // Still no status chip — the section says that.
    final Finder cards = find.byType(PosOrderCardTile);
    for (final int id in [27364, 27365, 27363, 27359, 27358]) {
      final Finder number = find.byKey(PosOrderCardTile.numberKeyFor(id));
      expect(number, findsOneWidget, reason: 'order $id');
      expect(find.ancestor(of: number, matching: cards), findsOneWidget,
          reason: 'order $id is drawn on its card');
      expect(
        find.descendant(
            of: find.ancestor(of: number, matching: cards),
            matching: find.text('NEW')),
        findsNothing,
        reason: 'order $id carries no status chip',
      );
    }
  });

  testWidgets('the modal header still spells the order number',
      (tester) async {
    await pumpBoard(tester, _StubOrdersRepo());

    await tester.tap(find.byType(PosOrderCardTile).first);
    await tester.pumpAndSettle();

    expect(find.byType(PosOrderDetailOverlay), findsOneWidget);
    expect(find.text('Order #27364'), findsOneWidget);
  });

  testWidgets('section badges show the server counts', (tester) async {
    await pumpBoard(tester, _StubOrdersRepo());

    // Each header's own badge — the Text after the label in its Row — so a
    // count can't be credited to the wrong section.
    Finder header(String label) => find.byWidgetPredicate((widget) =>
        widget is Text &&
        widget.data == label &&
        widget.style?.fontSize == PosOrdersSpec.sectionHeaderSize);
    final Finder board = find
        .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
        .first;
    const Map<String, String> expected = {
      'NEW': '2',
      'PREPARING': '1',
      'READY TO COLLECT': '1',
      'ON HOLD': '0',
      'COMPLETED': '1',
    };
    for (final MapEntry<String, String> e in expected.entries) {
      await tester.scrollUntilVisible(header(e.key), 200, scrollable: board);
      final Finder row =
          find.ancestor(of: header(e.key), matching: find.byType(Row)).first;
      final Text badge = tester
          .widgetList<Text>(
              find.descendant(of: row, matching: find.byType(Text)))
          .last;
      expect(badge.data, e.value, reason: e.key);
    }
    await tester.scrollUntilVisible(find.text('ALL'), -200, scrollable: board);

    // Figma 1915:15818: the quick-pills carry no counts — those live on the
    // section headers above.
    expect(find.text('ALL'), findsOneWidget);
    expect(find.text('NEW  2'), findsNothing);
    expect(find.text('ALL  4'), findsNothing);
  });

  testWidgets('FILTER folds the dropdown row away and back', (tester) async {
    await pumpBoard(tester, _StubOrdersRepo(), size: const Size(2000, 1200));
    expect(find.text('ALL SOURCES'), findsOneWidget);

    await tester.tap(find.text('FILTER'));
    await tester.pumpAndSettle();
    expect(find.text('ALL SOURCES'), findsNothing);
    expect(find.text('ANY STATUS'), findsNothing);

    await tester.tap(find.text('FILTER'));
    await tester.pumpAndSettle();
    expect(find.text('ALL SOURCES'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the search clear chip empties the field', (tester) async {
    final repo = _StubOrdersRepo();
    await pumpBoard(tester, repo, size: const Size(2000, 1200));

    await tester.enterText(find.byType(TextField), 'max');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump(const Duration(milliseconds: 600));

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('each card\'s ⋮ leads with its own rung of the ladder',
      (tester) async {
    await pumpBoard(tester, _StubOrdersRepo(), size: const Size(1366, 1500));

    // Nothing on the card faces any more.
    expect(find.text('Mark as ready'), findsNothing);
    expect(find.byIcon(Icons.check_rounded), findsNothing);

    // new -> preparing.
    await openMenu(tester, 27364);
    expect(find.text('Accept order'), findsOneWidget);
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();

    // preparing -> item_to_collect. Not "Mark as complete": that rung makes
    // the order ready, it does not finish it.
    await openMenu(tester, 27363);
    expect(find.text('Mark as ready'), findsOneWidget);
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();

    // item_to_collect -> completed, on a card drawn under FINISHED.
    await openMenu(tester, 27359);
    expect(find.text('Mark as complete'), findsOneWidget);
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();

    // Only the genuinely terminal card reads Done.
    expect(find.text('Done'), findsOneWidget);
  });

  group('every forward action is confirmed before it fires', () {
    const Size tall = Size(1366, 1500);

    /// One row per rung: the trigger the operator taps, the dialog heading it
    /// must raise, and the confirm button that actually sends it.
    const List<(int id, String trigger, String heading, String confirm)>
        rungs = [
      (27359, 'Mark as complete', 'Mark order as complete?', 'Complete'),
      (27363, 'Mark as ready', 'Mark order as ready?', 'Ready'),
    ];

    for (final (id, trigger, heading, confirm) in rungs) {
      testWidgets('Cancel on "$trigger" sends nothing and leaves it alone',
          (tester) async {
        final repo = _StubOrdersRepo();
        await pumpBoard(tester, repo, size: tall);

        await openMenu(tester, id);
        await tester.tap(find.text(trigger));
        await tester.pumpAndSettle();
        expect(find.text(heading), findsOneWidget);

        await tester.tap(find.text(PosCompleteConfirmationDialog.cancelLabel));
        await tester.pumpAndSettle();

        expect(repo.statusCalls, 0,
            reason: 'Cancel must not call the endpoint');
        expect(find.text(heading), findsNothing);
        // The card is still there, still offering the same action.
        await openMenu(tester, id);
        expect(find.text(trigger), findsOneWidget);
      });

      testWidgets('confirming "$trigger" sends the transition', (tester) async {
        final repo = _StubOrdersRepo();
        await pumpBoard(tester, repo, size: tall);

        await openMenu(tester, id);
        await tester.tap(find.text(trigger));
        await tester.pumpAndSettle();
        expect(repo.statusCalls, 0,
            reason: 'nothing before the operator confirms');

        await tester.tap(find.text(confirm));
        await tester.pumpAndSettle();

        expect(repo.statusCalls, 1);
      });
    }

    testWidgets('accepting a NEW order from its ⋮ is confirmed too',
        (tester) async {
      final repo = _StubOrdersRepo();
      await pumpBoard(tester, repo, size: tall);

      await openMenu(tester, 27364);
      await tester.tap(find.text('Accept order'));
      await tester.pumpAndSettle();
      expect(find.text('Accept this order?'), findsOneWidget);
      expect(repo.statusCalls, 0, reason: 'nothing before confirming');

      await tester.tap(find.text(PosCompleteConfirmationDialog.cancelLabel));
      await tester.pumpAndSettle();
      expect(repo.statusCalls, 0, reason: 'Cancel must not call the endpoint');

      await openMenu(tester, 27364);
      await tester.tap(find.text('Accept order'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();

      expect(repo.statusCalls, 1);
    });

    testWidgets('the completion dialog carries the signed-off copy',
        (tester) async {
      final repo = _StubOrdersRepo();
      await pumpBoard(tester, repo, size: tall);

      await openMenu(tester, 27359);
      await tester.tap(find.text('Mark as complete'));
      await tester.pumpAndSettle();

      expect(find.text('Mark order as complete?'), findsOneWidget);
      // Corrected from Figma: item_to_collect is already grouped under
      // FINISHED, so completing it moves the card nowhere.
      expect(find.text('This will close the order.'), findsOneWidget);
      expect(find.text('This will move the order to the Finished section.'),
          findsNothing);
    });

    testWidgets('resuming an on-hold order is not gated', (tester) async {
      // on_hold -> preparing un-pauses an already-accepted order; it is not a
      // forward step on the ladder, so nothing here should ask to confirm it.
      final repo = _StubOrdersRepo()..addOnHoldOrder();
      await pumpBoard(tester, repo, size: tall);

      // Held: no forward rung, only the side exit — the overlay's own rule.
      await openMenu(tester, 27357);
      expect(find.text('Resume'), findsNothing);
      await tester.tap(find.text('Resume order'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(PosCompleteConfirmationDialog), findsNothing);
      expect(repo.statusCalls, 1);
    });
  });

  testWidgets('no overflow at POS, tablet or narrow widths', (tester) async {
    for (final Size size in const [
      Size(1366, 944),
      Size(1024, 768),
      Size(820, 1180),
      Size(600, 900),
      Size(420, 900),
    ]) {
      await pumpBoard(tester, _StubOrdersRepo(), size: size);
      await tester.pump();

      expect(
        tester.takeException(),
        isNull,
        reason: 'the board must lay out cleanly at $size',
      );
    }
  });

  testWidgets('cards stretch rather than overflow once narrower than 288',
      (tester) async {
    await pumpBoard(tester, _StubOrdersRepo(), size: const Size(320, 900));

    final Finder cards = find.byType(PosOrderCardTile);
    final double width = tester.getSize(cards.first).width;

    // 320 - 24*2 padding = 272, below the 288 design width, so the card takes
    // what is available instead of running off the edge.
    expect(width, lessThanOrEqualTo(320 - PosOrdersSpec.pagePadding * 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('long names and addresses ellipsize instead of overflowing',
      (tester) async {
    await pumpBoard(tester, _StubOrdersRepo());

    final Text longName = tester.widget<Text>(
      find.text('A customer with a very long name indeed, truly'),
    );
    expect(longName.maxLines, 1);
    expect(longName.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);
  });
}
