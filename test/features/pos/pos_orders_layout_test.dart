import 'package:acafe_customer/common/models/api_response_model.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/di_container.dart' as di;
import 'package:acafe_customer/features/kiosk/domain/kiosk_manager_repo.dart';
import 'package:acafe_customer/features/pos/domain/pos_orders_repo.dart';
import 'package:acafe_customer/features/pos/domain/pos_orders_spec.dart';
import 'package:acafe_customer/features/pos/screens/pos_orders_list_screen.dart';
import 'package:acafe_customer/features/pos/widgets/pos_complete_confirmation_dialog.dart';
import 'package:acafe_customer/features/pos/widgets/pos_order_card_tile.dart';
import 'package:acafe_customer/features/pos/widgets/pos_order_detail_overlay.dart';
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
        'counts': {'new': 2, 'in_progress': 1, 'finished': 1},
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
          // Grouped under FINISHED but not terminal — it must still carry the
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

void main() {
  setUp(() {
    if (!di.sl.isRegistered<KioskManagerRepo>()) {
      di.sl.registerLazySingleton<KioskManagerRepo>(() => _StubManagerRepo());
    }
  });

  tearDown(() {
    if (di.sl.isRegistered<KioskManagerRepo>()) {
      di.sl.unregister<KioskManagerRepo>();
    }
  });

  Future<void> pumpBoard(WidgetTester tester, _StubOrdersRepo repo,
      {Size size = const Size(1366, 944)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_board(repo));
    await tester.pump();
    await tester.pump();
  }

  group('the card itself opens the detail overlay', () {
    /// Figma draws no ⋮ menu on this card — the whole tile is the affordance.
    testWidgets('there is no ⋮ menu on any card', (tester) async {
      await pumpBoard(tester, _StubOrdersRepo());
      expect(find.byIcon(Icons.more_vert_rounded), findsNothing);
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

    testWidgets(
        'tapping the action button confirms and advances instead of opening '
        'the overlay', (tester) async {
      final repo = _StubOrdersRepo();
      await pumpBoard(tester, repo, size: const Size(1366, 1500));

      // The button's own tap wins over the card's — its confirmation opens,
      // not the detail overlay.
      await tester.tap(find.text('Mark as ready'));
      await tester.pumpAndSettle();

      expect(find.byType(PosOrderDetailOverlay), findsNothing);
      expect(find.text('Mark order as ready?'), findsOneWidget);
      expect(repo.statusCalls, 0, reason: 'nothing before confirming');

      await tester.tap(find.text('Ready'));
      await tester.pumpAndSettle();

      expect(repo.statusCalls, 1);
    });

    testWidgets(
        'tapping the NEW checkmark confirms and advances instead of opening '
        'it', (tester) async {
      final repo = _StubOrdersRepo();
      await pumpBoard(tester, repo, size: const Size(1366, 1500));

      await tester.tap(find.byIcon(Icons.check_rounded).first);
      await tester.pumpAndSettle();

      expect(find.byType(PosOrderDetailOverlay), findsNothing);
      expect(find.text('Accept this order?'), findsOneWidget);
      expect(repo.statusCalls, 0, reason: 'nothing before confirming');

      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();

      expect(repo.statusCalls, 1);
    });
  });

  testWidgets('the board stacks three sections vertically, not side by side',
      (tester) async {
    await pumpBoard(tester, _StubOrdersRepo());

    expect(find.text('NEW'), findsOneWidget);
    expect(find.text('IN PROGRESS'), findsOneWidget);
    expect(find.text('FINISHED'), findsOneWidget);

    final double newY = tester.getTopLeft(find.text('NEW')).dy;
    final double progressY = tester.getTopLeft(find.text('IN PROGRESS')).dy;
    final double finishedY = tester.getTopLeft(find.text('FINISHED')).dy;

    // Figma draws every section at the full content width, one under the next.
    expect(progressY, greaterThan(newY));
    expect(finishedY, greaterThan(progressY));

    final double newX = tester.getTopLeft(find.text('NEW')).dx;
    expect(tester.getTopLeft(find.text('IN PROGRESS')).dx, newX);
    expect(tester.getTopLeft(find.text('FINISHED')).dx, newX);
  });

  testWidgets('cards hold the Figma 288px width and 12px gap', (tester) async {
    await pumpBoard(tester, _StubOrdersRepo());

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

  testWidgets('section badges show the server counts', (tester) async {
    await pumpBoard(tester, _StubOrdersRepo());

    // NEW's header badge. IN PROGRESS and FINISHED both show 1, so only the
    // 2 is unambiguous as a bare badge.
    expect(find.text('2'), findsOneWidget);
    expect(find.text('1'), findsNWidgets(2));

    // The quick-pills carry the same counts; PosFilterPill uppercases them.
    expect(find.text('NEW  2'), findsOneWidget);
    expect(find.text('IN PROGRESS  1'), findsOneWidget);
    expect(find.text('FINISHED  1'), findsOneWidget);
    expect(find.text('ALL  4'), findsOneWidget);
  });

  testWidgets('each card carries the action for its own rung of the ladder',
      (tester) async {
    await pumpBoard(tester, _StubOrdersRepo());

    // preparing -> item_to_collect. Not "Mark as complete": that rung makes the
    // order ready, it does not finish it.
    expect(find.text('Mark as ready'), findsOneWidget);
    // item_to_collect -> completed, on a card drawn under FINISHED.
    expect(find.text('Mark as complete'), findsOneWidget);
    // Only the genuinely terminal card reads Done, and it has no button.
    expect(find.text('Done'), findsOneWidget);
    // Checkmarks on the two NEW cards.
    expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
  });

  group('every forward action is confirmed before it fires', () {
    const Size tall = Size(1366, 1500);

    /// One row per rung: the trigger the operator taps, the dialog heading it
    /// must raise, and the confirm button that actually sends it.
    const List<(String trigger, String heading, String confirm)> rungs = [
      ('Mark as complete', 'Mark order as complete?', 'Complete'),
      ('Mark as ready', 'Mark order as ready?', 'Ready'),
    ];

    for (final (trigger, heading, confirm) in rungs) {
      testWidgets('Cancel on "$trigger" sends nothing and leaves it alone',
          (tester) async {
        final repo = _StubOrdersRepo();
        await pumpBoard(tester, repo, size: tall);

        await tester.tap(find.text(trigger));
        await tester.pumpAndSettle();
        expect(find.text(heading), findsOneWidget);

        await tester.tap(find.text(PosCompleteConfirmationDialog.cancelLabel));
        await tester.pumpAndSettle();

        expect(repo.statusCalls, 0,
            reason: 'Cancel must not call the endpoint');
        expect(find.text(heading), findsNothing);
        // The card is still there, still offering the same action.
        expect(find.text(trigger), findsWidgets);
      });

      testWidgets('confirming "$trigger" sends the transition',
          (tester) async {
        final repo = _StubOrdersRepo();
        await pumpBoard(tester, repo, size: tall);

        await tester.tap(find.text(trigger));
        await tester.pumpAndSettle();
        expect(repo.statusCalls, 0,
            reason: 'nothing before the operator confirms');

        await tester.tap(find.text(confirm));
        await tester.pumpAndSettle();

        expect(repo.statusCalls, 1);
      });
    }

    testWidgets('accepting a NEW order via its checkmark is confirmed too',
        (tester) async {
      final repo = _StubOrdersRepo();
      await pumpBoard(tester, repo, size: tall);

      await tester.tap(find.byIcon(Icons.check_rounded).first);
      await tester.pumpAndSettle();
      expect(find.text('Accept this order?'), findsOneWidget);
      expect(repo.statusCalls, 0, reason: 'nothing before confirming');

      await tester.tap(find.text(PosCompleteConfirmationDialog.cancelLabel));
      await tester.pumpAndSettle();
      expect(repo.statusCalls, 0, reason: 'Cancel must not call the endpoint');

      await tester.tap(find.byIcon(Icons.check_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();

      expect(repo.statusCalls, 1);
    });

    testWidgets('the completion dialog carries the signed-off copy',
        (tester) async {
      final repo = _StubOrdersRepo();
      await pumpBoard(tester, repo, size: tall);

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

      await tester.tap(find.text('Resume'));
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
