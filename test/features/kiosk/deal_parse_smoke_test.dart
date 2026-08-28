import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_deal.dart';
import 'package:acafe_customer/common/models/product_model.dart';

void main() {
  test('parse deal_payload.json', () {
    final raw = File('/Users/apple/Documents/GitHub/Acafe/deal_payload.json').readAsStringSync();
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final deal = KioskDeal.fromJson(map);
    expect(deal.items.length, 3);
    expect(deal.slots.length, greaterThanOrEqualTo(3));
  });

  test('Product.fromJson null attributes throws today', () {
    expect(
      () => Product.fromJson({
        'id': 1,
        'name': 'x',
        'price': 1,
        'tax': 0,
        'discount': 0,
        'attributes': null,
      }),
      throwsA(isA<Object>()),
    );
  });

  test('deal item with null product throws today', () {
    expect(
      () => KioskDealItem.fromJson({'quantity': 1, 'product': null}),
      throwsA(isA<Object>()),
    );
  });
}
