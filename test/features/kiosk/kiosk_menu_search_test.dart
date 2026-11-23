import 'package:flutter_test/flutter_test.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_menu_filter.dart';

Product _p(int id, String name, [String desc = '']) =>
    Product(id: id, name: name, description: desc);

void main() {
  final all = [
    _p(1, 'Iced Matcha Latte'),
    _p(2, 'Espresso', 'Strong shot'),
    _p(3, 'Café Crème', 'With matcha foam'),
    _p(1, 'Iced Matcha Latte'), // same product in a second category
  ];

  test('empty query returns nothing', () {
    expect(searchKioskProducts(all, '   '), isEmpty);
  });

  test('case/accent-insensitive, deduped, name hits first', () {
    final r = searchKioskProducts(all, 'MATCHA');
    expect(r.map((p) => p.id), [1, 3]);
  });

  test('all words must match', () {
    expect(searchKioskProducts(all, 'iced latte').map((p) => p.id), [1]);
    expect(searchKioskProducts(all, 'iced espresso'), isEmpty);
    expect(searchKioskProducts(all, 'cafe').map((p) => p.id), [3]);
  });
}
