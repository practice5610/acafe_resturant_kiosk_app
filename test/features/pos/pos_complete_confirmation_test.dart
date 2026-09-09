import 'package:acafe_customer/common/models/api_response_model.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/di_container.dart' as di;
import 'package:acafe_customer/features/kiosk/domain/kiosk_manager_repo.dart';
import 'package:acafe_customer/features/pos/domain/pos_orders_repo.dart';
import 'package:acafe_customer/features/pos/screens/pos_orders_list_screen.dart';
import 'package:acafe_customer/features/pos/widgets/pos_complete_confirmation_dialog.dart';
import 'package:acafe_customer/features/pos/widgets/pos_order_detail_overlay.dart';
import 'package:acafe_customer/features/pos/widgets/pos_waiting_card.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Proves the acceptance criterion that matters most here: the board card and
/// the Order Detail overlay show the *same* confirmation, because both route
/// through the board's one gated `_advance`. The overlay is opened for real
/// (tapping the card) rather than constructed with a stub callback, so what
/// is exercised is the actual wiring, not a test double of it.
class _StubOrdersRepo implements PosOrdersRepo {
  int statusCalls = 0;
  String? lastStatus;

  @override
  DioClient get dioClient => throw UnimplementedError();

  Map<String, dynamic> _row(int id, String status) => {
        'id': id,
        'created_at':
            DateTime.now().toUtc().subtract(const Duration(minutes: 5)).toIso8601String(),
        'order_status': status,
        'order_type': 'pos',
        'channel_key': 'counter_pos',
        'order_amount': 11.67,
        'customer_name': 'Max Mustermann',
        'address_lines': const <String>[],
        'display_method': 'card',
        'branch_name': 'Ludwigsfelde',
      };

  @override
  Future<ApiResponseModel> getOrders({
    String? dateFrom, String? dateTo, String? search, String? section,
    String? status, String? source, String? type, String? method, int limit = 200,
  }) async =>
      ApiResponseModel.withSuccess(Response<dynamic>(
        requestOptions: RequestOptions(path: '/'),
        statusCode: 200,
        data: {
          // One card at the terminal rung, so its action is 'Mark as complete'.
          'orders': [_row(1234, 'item_to_collect')],
          'counts': {'new': 0, 'in_progress': 0, 'finished': 1},
        },
      ));

  @override
  Future<ApiResponseModel> updateStatus({
    required int orderId,
    required String orderStatus,
  }) async {
    statusCalls++;
    lastStatus = orderStatus;
    return ApiResponseModel.withSuccess(Response<dynamic>(
      requestOptions: RequestOptions(path: '/'),
      statusCode: 200,
      data: {'success': true},
    ));
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _StubManagerRepo implements KioskManagerRepo {
  @override
  Future<ApiResponseModel> getTransactionDetail(int id) async =>
      ApiResponseModel.withSuccess(Response<dynamic>(
        requestOptions: RequestOptions(path: '/'),
        statusCode: 200,
        data: {
          'id': id,
          'created_at': DateTime.now().toIso8601String(),
          'order_status': 'item_to_collect',
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

Widget _board(_StubOrdersRepo repo) => MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFFF7F1DE),
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

  Future<void> pump(WidgetTester tester, _StubOrdersRepo repo) async {
    tester.view.physicalSize = const Size(1366, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_board(repo));
    await tester.pump();
    await tester.pump();
  }

  /// The board keeps a periodic clock running and the overlay shows a spinner
  /// while it loads, so frames never stop being scheduled — pumpAndSettle
  /// cannot settle here. Bounded pumps, as the rest of the board's tests use.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    // Long enough for a dialog route to finish opening or popping; a fixed
    // budget rather than pumpAndSettle, which never returns here.
    for (int i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  // Figma has no ⋮ menu on this card — the whole tile opens the overlay.
  Future<void> openOverlay(WidgetTester tester) async {
    await tester.tap(find.text('Max Mustermann').first);
    await settle(tester);
    expect(find.byType(PosOrderDetailOverlay), findsOneWidget);
  }

  group('the overlay shares the board\'s confirmation', () {
    testWidgets('its CTA opens the same dialog', (tester) async {
      final repo = _StubOrdersRepo();
      await pump(tester, repo);
      await openOverlay(tester);

      // The overlay's sticky-bar CTA, at the same rung as the card's button.
      await tester.tap(find.widgetWithText(InkWell, 'Mark as complete').last);
      await settle(tester);

      expect(find.text(PosCompleteConfirmationDialog.heading), findsOneWidget,
          reason: 'the overlay must show the board\'s confirmation');
      expect(repo.statusCalls, 0, reason: 'nothing sent before confirming');
    });

    testWidgets('confirming from the overlay completes the order',
        (tester) async {
      final repo = _StubOrdersRepo();
      await pump(tester, repo);
      await openOverlay(tester);

      await tester.tap(find.widgetWithText(InkWell, 'Mark as complete').last);
      await settle(tester);
      await tester.tap(find.text(PosCompleteConfirmationDialog.confirmLabel));
      await settle(tester);

      expect(repo.statusCalls, 1);
      expect(repo.lastStatus, 'completed',
          reason: 'must use the shared ladder, not a hardcoded target');
      expect(find.byType(PosOrderDetailOverlay), findsNothing,
          reason: 'a completed order closes its overlay');
    });

    testWidgets('cancelling leaves the overlay open and sends nothing',
        (tester) async {
      final repo = _StubOrdersRepo();
      await pump(tester, repo);
      await openOverlay(tester);

      await tester.tap(find.widgetWithText(InkWell, 'Mark as complete').last);
      await settle(tester);
      await tester.tap(find.text(PosCompleteConfirmationDialog.cancelLabel));
      await settle(tester);

      expect(repo.statusCalls, 0);
      // The distinction a plain null-means-success return could not express.
      expect(find.byType(PosOrderDetailOverlay), findsOneWidget,
          reason: 'cancelling must not close the overlay');
    });
  });

  group('the shared button keeps its Payment defaults', () {
    testWidgets('an unparameterised button renders the original metrics',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: PosPaymentCardButton(label: 'Cancel', onTap: null),
            ),
          ),
        ),
      ));

      final Container box = tester.widget<Container>(
        find.descendant(
          of: find.byType(PosPaymentCardButton),
          matching: find.byType(Container),
        ),
      );
      final BoxDecoration d = box.decoration! as BoxDecoration;

      // The Payment screen's values, unchanged by the new overrides.
      expect((d.border! as Border).top.width, 1.5);
      expect(d.borderRadius, BorderRadius.circular(14));
      expect(box.padding, const EdgeInsets.symmetric(vertical: 16));

      final Text label = tester.widget<Text>(find.text('Cancel'));
      expect(label.style!.fontSize, 16);
    });

    testWidgets('the dialog opts into the larger scale', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: PosCompleteConfirmationDialog()),
      ));

      final Finder complete = find.widgetWithText(PosPaymentCardButton, 'Complete');
      final Container box = tester.widget<Container>(
        find.descendant(of: complete, matching: find.byType(Container)),
      );
      final BoxDecoration d = box.decoration! as BoxDecoration;

      expect((d.border! as Border).top.width, 3);
      expect(d.borderRadius, BorderRadius.circular(40));
      expect(tester.widget<Text>(find.text('Complete')).style!.fontSize, 26);
    });
  });
}
