import 'package:acafe_customer/common/models/api_response_model.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/features/pos/domain/pos_orders_repo.dart';
import 'package:acafe_customer/features/pos/domain/pos_orders_spec.dart';
import 'package:acafe_customer/features/pos/screens/pos_orders_list_screen.dart';
import 'package:acafe_customer/features/pos/widgets/pos_complete_confirmation_dialog.dart';
import 'package:acafe_customer/features/pos/widgets/pos_order_card_tile.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Serves a fixed board so layout can be asserted without a network or a
/// service locator. The rows are shaped exactly like the real
/// `GET /api/v1/kiosk/manager/orders` payload, including the cases that decide
/// a card's height: a delivery order with two address lines, a counter order
/// with none, and a finished order.
class _StubOrdersRepo implements PosOrdersRepo {
  @override
  DioClient get dioClient => throw UnimplementedError();

  int statusCalls = 0;

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
  Future<void> pumpBoard(WidgetTester tester, _StubOrdersRepo repo,
      {Size size = const Size(1366, 944)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_board(repo));
    await tester.pump();
    await tester.pump();
  }

  group('the card menu opens against its own button', () {
    /// Regression: RelativeRect.fromLTRB takes insets from the overlay's edges,
    /// and the menu was being handed absolute coordinates for `right` and
    /// `bottom`. The resulting rect was wider than the screen, so the menu was
    /// laid out against a degenerate box and dropped down-and-left of the
    /// button, across the cards underneath it. Worst on the rightmost column,
    /// which is where it was reported.
    Future<Rect> openMenuOnLastCard(WidgetTester tester) async {
      final Finder buttons = find.byIcon(Icons.more_vert_rounded);
      expect(buttons, findsWidgets);

      // The last card in the first row is the rightmost one on screen.
      final Finder button = buttons.at(3);
      final Rect buttonRect = tester.getRect(button);

      await tester.tap(button);
      await tester.pumpAndSettle();

      final Finder menu = find.text('Open detail');
      expect(menu, findsOneWidget, reason: 'menu did not open');

      final Rect menuRect = tester.getRect(
        find.ancestor(of: menu, matching: find.byType(Material)).last,
      );
      // Sanity: the menu really is below its own button, not floating anywhere.
      expect(menuRect.top, greaterThanOrEqualTo(buttonRect.top));
      return menuRect;
    }

    testWidgets('stays on screen for a rightmost card', (tester) async {
      final repo = _StubOrdersRepo();
      await pumpBoard(tester, repo);

      final Rect menu = await openMenuOnLastCard(tester);
      const Size screen = Size(1366, 944);

      expect(menu.left, greaterThanOrEqualTo(0),
          reason: 'menu ran off the left edge');
      expect(menu.right, lessThanOrEqualTo(screen.width),
          reason: 'menu ran off the right edge');
    });

    testWidgets('is anchored under its own button, not over other cards',
        (tester) async {
      final repo = _StubOrdersRepo();
      await pumpBoard(tester, repo);

      final Rect buttonRect = tester.getRect(find.byIcon(Icons.more_vert_rounded).at(3));
      final Rect menu = await openMenuOnLastCard(tester);

      // Right-aligned to the button it belongs to, so it reads as that card's
      // menu rather than the menu of whatever it happens to cover.
      expect((menu.right - buttonRect.right).abs(), lessThan(24),
          reason: 'menu is not aligned to its button: '
              'menu.right=${menu.right} button.right=${buttonRect.right}');
      expect(menu.top, greaterThan(buttonRect.bottom - 1),
          reason: 'menu does not hang below its button');
    });

    testWidgets('does not stretch across the board', (tester) async {
      final repo = _StubOrdersRepo();
      await pumpBoard(tester, repo);

      final Rect menu = await openMenuOnLastCard(tester);
      // One card is 288 wide; a menu spanning several columns is the bug.
      expect(menu.width, lessThanOrEqualTo(PosOrdersSpec.cardWidth),
          reason: 'menu is wider than a card: ${menu.width}');
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

  group('completion is confirmed, and only completion', () {
    const Size tall = Size(1366, 1500);

    testWidgets('Cancel sends nothing and leaves the order alone',
        (tester) async {
      final repo = _StubOrdersRepo();
      await pumpBoard(tester, repo, size: tall);

      await tester.tap(find.text('Mark as complete'));
      await tester.pumpAndSettle();
      expect(find.text(PosCompleteConfirmationDialog.heading), findsOneWidget);

      await tester.tap(find.text(PosCompleteConfirmationDialog.cancelLabel));
      await tester.pumpAndSettle();

      expect(repo.statusCalls, 0, reason: 'Cancel must not call the endpoint');
      expect(find.text(PosCompleteConfirmationDialog.heading), findsNothing);
      // The card is still there, still offering the same action.
      expect(find.text('Mark as complete'), findsWidgets);
    });

    testWidgets('the other rungs advance without a dialog', (tester) async {
      // Figma specifies a confirmation for completion alone; adding one to a
      // recoverable rung would be friction nobody asked for.
      for (final String label in ['Mark as ready', 'Start preparing']) {
        final repo = _StubOrdersRepo();
        await pumpBoard(tester, repo, size: tall);

        if (find.text(label).evaluate().isEmpty) continue;

        await tester.tap(find.text(label).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.text(PosCompleteConfirmationDialog.heading), findsNothing,
            reason: '"$label" must not be gated');
        expect(repo.statusCalls, 1, reason: '"$label" must reach the endpoint');
      }
    });

    testWidgets('the dialog carries the signed-off copy', (tester) async {
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
  });

  testWidgets('every action on the board reaches the endpoint', (tester) async {
    // The invariant behind the section/action split: nothing may sit on the
    // board holding a button that cannot legally fire. Each is tapped against a
    // fresh board, because advancing one card re-labels it.
    // Tall enough that the FINISHED section is on screen: a tap on a card the
    // ListView has built but not laid inside the viewport lands on nothing.
    const Size tall = Size(1366, 1500);

    // 'Mark as ready' fires straight through; 'Mark as complete' is the one
    // rung gated by the confirmation dialog, so it needs the extra tap.
    for (final String label in ['Mark as ready', 'Mark as complete']) {
      final repo = _StubOrdersRepo();
      await pumpBoard(tester, repo, size: tall);

      await tester.tap(find.text(label));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      if (label == 'Mark as complete') {
        expect(find.text(PosCompleteConfirmationDialog.heading), findsOneWidget,
            reason: 'completion must be confirmed first');
        expect(repo.statusCalls, 0,
            reason: 'nothing may be sent before the operator confirms');
        await tester.tap(find.text(PosCompleteConfirmationDialog.confirmLabel));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(repo.statusCalls, 1, reason: '"$label" must call the endpoint');
    }

    final repo = _StubOrdersRepo();
    await pumpBoard(tester, repo, size: tall);
    await tester.tap(find.byIcon(Icons.check_rounded).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(repo.statusCalls, 1, reason: 'the NEW checkmark must call it too');
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
