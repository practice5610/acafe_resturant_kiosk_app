import 'dart:async';

import 'package:acafe_customer/common/models/api_response_model.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_manager_repo.dart';
import 'package:acafe_customer/features/pos/domain/pos_advance_outcome.dart';
import 'package:acafe_customer/features/pos/domain/pos_order_card.dart';
import 'package:acafe_customer/features/pos/domain/pos_order_detail_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_orders_repo.dart';
import 'package:acafe_customer/features/pos/widgets/pos_order_detail_overlay.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The overlay opens before the order has been fetched, so it necessarily
/// draws one frame with no content. The bug these tests pin: that frame used a
/// bare `Center`, which inside the modal's `Flexible` stretches to the whole
/// 718px budget — so a one-item order appeared at full height and then snapped
/// back down to the ~400px it actually needs. The loading frame must now be
/// placeholder-sized, and what is left must be interpolated, not jumped.

/// Answers the detail fetch only once [complete] is called, so the loading
/// frame can be measured.
class _PendingManagerRepo implements KioskManagerRepo {
  _PendingManagerRepo(this.payload);

  final Map<String, dynamic> payload;
  final List<void Function()> _waiting = <void Function()>[];

  void complete() {
    for (final void Function() resume in _waiting) {
      resume();
    }
    _waiting.clear();
  }

  @override
  Future<ApiResponseModel> getTransactionDetail(int id) {
    final Completer<ApiResponseModel> completer = Completer<ApiResponseModel>();
    _waiting.add(() => completer.complete(
          ApiResponseModel.withSuccess(Response<dynamic>(
            requestOptions: RequestOptions(path: '/'),
            statusCode: 200,
            data: payload,
          )),
        ));
    return completer.future;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _StubOrdersRepo implements PosOrdersRepo {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);

  @override
  DioClient get dioClient => throw UnimplementedError();
}

final DateTime _frozen = DateTime(2026, 9, 28, 19, 15);

/// One item — the case the report named, and the one with the largest gap
/// between an over-stretched loading frame and the real content height.
Map<String, dynamic> _singleItemPayload() => <String, dynamic>{
      'id': 1000189,
      'created_at': _frozen.toIso8601String(),
      'order_status': 'item_to_collect',
      'order_type': 'pos',
      'channel_key': 'counter_pos',
      'display_method': 'cash',
      'payment_status': 'paid',
      'table': null,
      'customer_name': 'Walk-in',
      'customer_phone': null,
      'customer_email': null,
      'order_note': 'Kiosk order',
      'items': [
        <String, dynamic>{
          'id': 1,
          'name': 'Americano_200',
          'image': null,
          'quantity': 1,
          'unit_price': 110.0,
          'prep_status': 'ready',
          'instruction': null,
          'variations': const <dynamic>[],
          'addons': const <dynamic>[],
        },
      ],
      'subtotal': 112.0,
      'discount': 0,
      'total': 112.0,
    };

PosOrderCard _card() => PosOrderCard(
      id: 1000189,
      createdAt: _frozen,
      orderStatus: 'item_to_collect',
      orderType: 'pos',
      channelKey: 'counter_pos',
      orderAmount: 112,
      customerName: 'Walk-in',
      addressLines: const <String>[],
      displayMethod: 'cash',
      branchName: 'Acafe/Amsterdam',
    );

/// The modal card itself — the Column the header, body and action bar share.
Finder _modal() => find.descendant(
      of: find.byType(PosOrderDetailOverlay),
      matching: find.byType(Column),
    );

Future<_PendingManagerRepo> _pump(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(1366, 1024)
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final _PendingManagerRepo repo =
      _PendingManagerRepo(_singleItemPayload());

  await tester.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: PosOrderDetailOverlay(
        order: _card(),
        repo: repo,
        ordersRepo: _StubOrdersRepo(),
        onAdvance: (_) async => const PosAdvanceResult.advanced(),
      ),
    ),
  ));

  return repo;
}

void main() {
  testWidgets('the loading frame is placeholder-sized, not full height',
      (tester) async {
    await _pump(tester);
    await tester.pump();

    final double height = tester.getSize(_modal().first).height;

    // The regression: a stretching Center pinned this to the full 718px
    // budget, which the loaded frame then collapsed out of.
    expect(height, lessThan(PosOrderDetailSpec.modalHeight));
    expect(
      height,
      lessThan(PosOrderDetailSpec.bodyPlaceholderHeight + 300),
      reason: 'placeholder body plus header and action bar chrome only',
    );
  });

  testWidgets('the fetch landing resizes the modal over time, not in one frame',
      (tester) async {
    final _PendingManagerRepo repo = await _pump(tester);
    await tester.pump();

    final double loadingHeight = tester.getSize(_modal().first).height;

    repo.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    final double firstFrame = tester.getSize(_modal().first).height;

    await tester.pumpAndSettle();
    final double settled = tester.getSize(_modal().first).height;

    // A one-item order is taller than the placeholder, so this is a grow —
    // and the first frame after the response must not already be there.
    expect(settled, greaterThan(loadingHeight));
    expect(
      firstFrame,
      lessThan(settled),
      reason: 'AnimatedSize interpolates the change instead of snapping',
    );
  });

  testWidgets('the settled modal holds its height across later frames',
      (tester) async {
    final _PendingManagerRepo repo = await _pump(tester);
    await tester.pump();
    repo.complete();
    await tester.pumpAndSettle();

    final double settled = tester.getSize(_modal().first).height;
    await tester.pump(const Duration(seconds: 1));

    expect(tester.getSize(_modal().first).height, settled);
  });
}
