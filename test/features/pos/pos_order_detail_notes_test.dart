import 'package:acafe_customer/common/models/api_response_model.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_manager_repo.dart';
import 'package:acafe_customer/features/pos/domain/pos_advance_outcome.dart';
import 'package:acafe_customer/features/pos/domain/pos_order_card.dart';
import 'package:acafe_customer/features/pos/domain/pos_orders_repo.dart';
import 'package:acafe_customer/features/pos/widgets/pos_order_detail_overlay.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pos_test_kiosk_auth.dart';

/// A customer's note against a line is an instruction to whoever makes it.
/// The bug these tests pin: the modal drew it as one more grey `+ …` line, in
/// the same 11px style as the add-ons above it, so staff read "LESS SUGAR" as
/// an add-on — or did not see it at all. And the Order Notes box showed the
/// bare `Kiosk order` marker of a nameless counter sale as if it were a note.
///
/// Every note now sits in the Order Notes card under Total (left column),
/// headed with the line it belongs to; the line itself carries a small NOTE
/// tag so it can be matched up while scanning the items.

class _ManagerRepo implements KioskManagerRepo {
  _ManagerRepo(this.payload);

  final Map<String, dynamic> payload;

  @override
  Future<ApiResponseModel> getTransactionDetail(int id) async =>
      ApiResponseModel.withSuccess(Response<dynamic>(
        requestOptions: RequestOptions(path: '/'),
        statusCode: 200,
        data: payload,
      ));

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _StubOrdersRepo implements PosOrdersRepo {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);

  @override
  DioClient get dioClient => throw UnimplementedError();
}

final DateTime _frozen = DateTime(2026, 10, 19, 6, 13);

/// Verbatim from order_details 4506 (order #100014): two lines, as typed.
const String _note =
    'I AM UISING LESS SUGAR IN ICE \nIF PSOSIBLE USE ALERNATIV OF OTHER';

/// Order #100014 as the board fetched it: one line with four add-ons and a
/// note, placed at the counter with no customer name.
Map<String, dynamic> _payload({
  String? instruction = _note,
  String? orderNote = 'Kiosk order',
}) =>
    <String, dynamic>{
      'id': 100014,
      'created_at': _frozen.toIso8601String(),
      'order_status': 'new',
      'order_type': 'pos',
      'channel_key': 'counter_pos',
      'display_method': 'cash',
      'payment_status': 'paid',
      'table': null,
      'customer_name': 'Walk-in',
      'customer_phone': null,
      'customer_email': null,
      'order_note': orderNote,
      'items': [
        <String, dynamic>{
          'id': 7,
          'name': 'Fresh Mint Tea',
          'image': null,
          'quantity': 1,
          'unit_price': 4.5,
          'prep_status': 'pending',
          'instruction': instruction,
          'variations': const <dynamic>[],
          'addons': const <dynamic>[
            {'name': 'Blueberry', 'quantity': 1},
            {'name': 'Extra Strawberry', 'quantity': 1},
          ],
        },
      ],
      'subtotal': 6.5,
      'discount': 0,
      'total': 6.5,
    };

PosOrderCard _card() => PosOrderCard(
      id: 100014,
      createdAt: _frozen,
      orderStatus: 'new',
      orderType: 'pos',
      channelKey: 'counter_pos',
      orderAmount: 6.5,
      customerName: 'Walk-in',
      addressLines: const <String>[],
      displayMethod: 'cash',
      branchName: 'Acafe/Amsterdam',
    );

Future<void> _pump(
  WidgetTester tester, {
  required Map<String, dynamic> payload,
  Size size = const Size(1366, 1024),
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(MultiProvider(
    providers: [testKioskAuthProvider(prefs)],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: PosOrderDetailOverlay(
          order: _card(),
          repo: _ManagerRepo(payload),
          ordersRepo: _StubOrdersRepo(),
          onAdvance: (_) async => const PosAdvanceResult.advanced(),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

Finder _notesCard() => find.byKey(const ValueKey<String>('pos-order-notes'));
Finder _itemEntry() =>
    find.byKey(const ValueKey<String>('pos-order-note-item-7'));
Finder _tag() => find.byKey(const ValueKey<String>('pos-item-note-7'));

void main() {
  testWidgets('an item note is listed in Order Notes, headed with its line',
      (tester) async {
    await _pump(tester, payload: _payload());

    expect(find.text('ORDER NOTES'), findsOneWidget);
    expect(
      find.descendant(of: _itemEntry(), matching: find.text(_note)),
      findsOneWidget,
      reason: 'the note text lives in the Order Notes card',
    );
    expect(
      find.descendant(of: _itemEntry(), matching: find.text('FRESH MINT TEA')),
      findsOneWidget,
      reason: 'headed with the line it belongs to',
    );
    expect(find.text(_note), findsOneWidget,
        reason: 'drawn once — not also as a + add-on line or on the row');

    // Add-ons keep their own + lines.
    expect(find.text('Blueberry'), findsOneWidget);
    expect(find.text('Extra Strawberry'), findsOneWidget);
  });

  testWidgets('Order Notes sits on the left, under Total', (tester) async {
    await _pump(tester, payload: _payload());

    final Rect notes = tester.getRect(_notesCard());
    final Rect total = tester.getRect(find.text('Total').last);
    final Rect items = tester.getRect(find.text('ORDER ITEMS'));

    expect(notes.top, greaterThan(total.bottom),
        reason: 'below the Total card, not above it');
    expect(notes.right, lessThan(items.left),
        reason: 'in the left column, beside the items, not in them');
  });

  testWidgets('the line carries a NOTE tag under its add-ons',
      (tester) async {
    await _pump(tester, payload: _payload());

    expect(_tag(), findsOneWidget);
    expect(
      find.descendant(of: _tag(), matching: find.text('NOTE')),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(_tag()).dy,
      greaterThan(tester.getBottomLeft(find.text('Extra Strawberry')).dy),
      reason: 'below the add-ons, not between them',
    );
  });

  testWidgets('the note is readable: larger than the add-on lines',
      (tester) async {
    await _pump(tester, payload: _payload());

    final double addonSize =
        tester.widget<Text>(find.text('Blueberry')).style!.fontSize!;
    final double noteSize =
        tester.widget<Text>(find.text(_note)).style!.fontSize!;
    expect(noteSize, greaterThan(addonSize));
  });

  testWidgets('the order\'s own note comes first, as "Whole order"',
      (tester) async {
    await _pump(
      tester,
      payload: _payload(orderNote: 'Kiosk order\nAllergic to nuts'),
    );

    final Finder order =
        find.byKey(const ValueKey<String>('pos-order-note-order'));
    expect(
      find.descendant(of: order, matching: find.text('Allergic to nuts')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: order, matching: find.text('WHOLE ORDER')),
      findsOneWidget,
    );
    expect(tester.getTopLeft(order).dy,
        lessThan(tester.getTopLeft(_itemEntry()).dy));
  });

  testWidgets('no notes at all: no Order Notes card and no tag',
      (tester) async {
    await _pump(tester, payload: _payload(instruction: '   '));
    expect(_notesCard(), findsNothing);
    expect(_tag(), findsNothing);
  });

  testWidgets('the bare "Kiosk order" marker is not shown as an order note',
      (tester) async {
    await _pump(tester, payload: _payload(instruction: null));
    expect(find.text('Kiosk order'), findsNothing);
    expect(find.text('ORDER NOTES'), findsNothing);
  });

  testWidgets('phone-width modal still shows the notes without overflow',
      (tester) async {
    await _pump(tester, payload: _payload(), size: const Size(390, 844));
    expect(_itemEntry(), findsOneWidget);
    expect(_tag(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
