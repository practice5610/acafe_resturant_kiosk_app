import 'package:acafe_customer/common/models/api_response_model.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_manager_repo.dart';
import 'package:acafe_customer/features/pos/domain/pos_advance_outcome.dart';
import 'package:acafe_customer/features/pos/domain/pos_item_prep_status.dart';
import 'package:acafe_customer/features/pos/domain/pos_order_card.dart';
import 'package:acafe_customer/features/pos/domain/pos_order_detail.dart';
import 'package:acafe_customer/features/pos/domain/pos_orders_repo.dart';
import 'package:acafe_customer/features/pos/domain/pos_station_status.dart';
import 'package:acafe_customer/features/pos/widgets/pos_order_card_tile.dart';
import 'package:acafe_customer/features/pos/widgets/pos_order_detail_overlay.dart';
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pos_test_kiosk_auth.dart';

/// Station pills (Figma 1915:15767): the card footer, the modal header and
/// every item row, driven by the API's `stations` summary and per-line
/// `station` name.

Response<dynamic> _ok(Object data) => Response<dynamic>(
      requestOptions: RequestOptions(path: '/'),
      statusCode: 200,
      data: data,
    );

class _ManagerRepo implements KioskManagerRepo {
  @override
  Future<ApiResponseModel> getTransactionDetail(int id) async =>
      ApiResponseModel.withSuccess(_ok(<String, dynamic>{
        'id': id,
        'created_at': '2026-06-23T10:55:00',
        'order_status': 'new',
        'order_type': 'pos',
        'channel_key': 'web_app',
        'display_method': 'card',
        'payment_status': 'paid',
        'customer_name': 'Max Mustermann',
        'items': [
          {'id': 1, 'name': 'Cappuccino', 'quantity': 1, 'unit_price': 4.5,
            'prep_status': 'pending', 'station': 'Bar'},
          {'id': 2, 'name': 'Croissant', 'quantity': 1, 'unit_price': 3.2,
            'prep_status': 'pending', 'station': 'Kitchen'},
          // No station: the row shows its status alone.
          {'id': 3, 'name': 'Water', 'quantity': 1, 'unit_price': 1.0,
            'prep_status': 'pending', 'station': null},
        ],
        'stations': [
          {'name': 'Bar', 'status': 'pending'},
          {'name': 'Kitchen', 'status': 'pending'},
        ],
        'subtotal': 8.7,
        'discount': 0,
        'total': 8.7,
      }));

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _OrdersRepo implements PosOrdersRepo {
  @override
  DioClient get dioClient => throw UnimplementedError();

  @override
  Future<ApiResponseModel> updateItemStatus({
    required int orderId,
    required int orderDetailId,
    required String status,
  }) async =>
      ApiResponseModel.withSuccess(_ok(<String, dynamic>{
        'order_id': orderId,
        'order_detail_id': orderDetailId,
        'prep_status': status,
        'order_status': 'preparing',
        'item_states': [
          {'id': 1, 'prep_status': status, 'station': 'Bar'},
          {'id': 2, 'prep_status': 'pending', 'station': 'Kitchen'},
          {'id': 3, 'prep_status': 'pending', 'station': null},
        ],
        'stations': [
          {'name': 'Bar', 'status': status},
          {'name': 'Kitchen', 'status': 'pending'},
        ],
        'items_ready': 0,
        'items_total': 3,
      }));

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

PosOrderCard _card({
  List<PosStationStatus> stations = const [],
  List<PrepStatus> states = const [],
}) =>
    PosOrderCard(
      id: 27363,
      createdAt: DateTime(2026, 6, 23, 10, 50),
      orderStatus: 'preparing',
      orderType: 'pos',
      channelKey: 'web_app',
      orderAmount: 11.67,
      customerName: 'Max Mustermann',
      addressLines: const [],
      displayMethod: 'card',
      branchName: 'Ludwigsfelde',
      itemStates: states,
      stations: stations,
    );

void main() {
  group('parsing', () {
    test('stations: names and aggregate statuses, malformed rows dropped', () {
      expect(
        PosStationStatus.listFromJson([
          {'name': 'Bar', 'status': 'ready'},
          {'name': 'Kitchen', 'status': 'preparing'},
          {'name': '', 'status': 'ready'},
          'junk',
        ]),
        const [
          PosStationStatus(name: 'Bar', status: PrepStatus.ready),
          PosStationStatus(name: 'Kitchen', status: PrepStatus.preparing),
        ],
      );
      expect(PosStationStatus.listFromJson(null), isEmpty,
          reason: 'an older API without the key draws no pills');
    });

    test('card and detail carry stations; optimistic copies keep them', () {
      final PosOrderCard card = PosOrderCard.fromJson({
        'id': 1,
        'order_status': 'new',
        'stations': [
          {'name': 'Bar', 'status': 'pending'},
        ],
      });
      expect(card.stations.single.name, 'Bar');
      expect(card.withStatus('preparing').stations, card.stations);

      final PosOrderDetail detail = PosOrderDetail.fromJson({
        'id': 1,
        'items': [
          {'id': 9, 'name': 'Tea', 'station': 'Bar', 'prep_status': 'ready'},
          {'id': 10, 'name': 'Cake'},
        ],
        'stations': [
          {'name': 'Bar', 'status': 'ready'},
        ],
      });
      expect(detail.items.first.station, 'Bar');
      expect(detail.items.last.station, isNull);
      expect(detail.items.first.withPrepStatus(PrepStatus.pending).station,
          'Bar');
      expect(detail.stations.single.status, PrepStatus.ready);
    });
  });

  group('card footer', () {
    Future<void> pumpCard(WidgetTester tester, PosOrderCard card) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 288,
              child: PosOrderCardTile(
                order: card,
                now: DateTime(2026, 6, 23, 10, 55),
              ),
            ),
          ),
        ),
      ));
    }

    testWidgets('one pill per station, in place of the progress line',
        (tester) async {
      await pumpCard(
        tester,
        _card(
          stations: const [
            PosStationStatus(name: 'Bar', status: PrepStatus.ready),
            PosStationStatus(name: 'Kitchen', status: PrepStatus.preparing),
          ],
          states: const [PrepStatus.ready, PrepStatus.preparing],
        ),
      );

      expect(find.text('Bar · Ready'), findsOneWidget);
      expect(find.text('Kitchen · Preparing'), findsOneWidget);
      expect(find.text('1/2 ready'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('no stations: no pills, and the progress line stays',
        (tester) async {
      await pumpCard(
        tester,
        _card(states: const [PrepStatus.ready, PrepStatus.preparing]),
      );

      expect(find.textContaining(' · '), findsNothing);
      expect(find.text('1/2 ready'), findsOneWidget);
    });

    testWidgets('many stations wrap instead of overflowing', (tester) async {
      await pumpCard(
        tester,
        _card(stations: const [
          PosStationStatus(name: 'Bar', status: PrepStatus.ready),
          PosStationStatus(name: 'Kitchen', status: PrepStatus.preparing),
          PosStationStatus(name: 'Pastry', status: PrepStatus.pending),
          PosStationStatus(name: 'Expo', status: PrepStatus.pending),
        ]),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('detail overlay', () {
    testWidgets('header pills, per-item labels, and a write updates both',
        (tester) async {
      tester.view
        ..physicalSize = const Size(1366, 1024)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // Picture-less, so the rows need no image plumbing.
      SharedPreferences.setMockInitialValues({AppConstants.kioskShowImages: false});
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(MultiProvider(
        providers: [testKioskAuthProvider(prefs)],
        child: MaterialApp(
          home: Scaffold(
            body: PosOrderDetailOverlay(
              order: _card().withStatus('new'),
              repo: _ManagerRepo(),
              ordersRepo: _OrdersRepo(),
              onAdvance: (_) async => const PosAdvanceResult.advanced(),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Header: one per station. Rows: "Station · Status", or the status
      // alone for the line with no station.
      expect(find.text('Bar · Pending'), findsNWidgets(2));
      expect(find.text('Kitchen · Pending'), findsNWidgets(2));
      expect(find.text('Pending'), findsOneWidget);

      await tester.tap(find.text('Start').first);
      await tester.pumpAndSettle();

      // The write response's re-derived summary lands in the header.
      expect(find.text('Bar · Preparing'), findsNWidgets(2));
      expect(find.text('Bar · Pending'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
