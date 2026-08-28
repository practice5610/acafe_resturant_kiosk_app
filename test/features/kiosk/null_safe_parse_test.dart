import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_deal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Product.fromJson tolerates null price/tax/discount/attributes', () {
    final product = Product.fromJson({
      'id': 1,
      'name': 'Test',
      'price': null,
      'tax': null,
      'discount': null,
      'attributes': null,
      'status': 1,
    });
    expect(product.id, 1);
    expect(product.price, isNull);
    expect(product.tax, isNull);
    expect(product.discount, isNull);
    expect(product.attributes, isEmpty);
  });

  test('ProductModel skips corrupt products instead of failing', () {
    final model = ProductModel.fromJson({
      'products': [
        {
          'id': 1,
          'name': 'Good',
          'price': 2.5,
          'tax': 0,
          'discount': 0,
          'attributes': [],
          'status': 1,
        },
        'not-a-map',
        {
          'id': 2,
          'name': 'Also good',
          'price': '3',
          'tax': '0',
          'discount': '0',
          'attributes': [1, 'x'],
          'status': 1,
        },
      ],
    });
    expect(model.products, isNotNull);
    expect(model.products!.length, 2);
    expect(model.products!.first.name, 'Good');
    expect(model.products!.last.attributes, ['1', 'x']);
  });

  test('KioskDeal skips items with null product', () {
    final deal = KioskDeal.fromJson({
      'id': 9,
      'title': 'Broken',
      'bundle_price': 10,
      'original_price': 12,
      'savings': 2,
      'savings_percent': 16,
      'available': true,
      'items': [
        {'quantity': 1, 'product': null},
        {
          'quantity': 1,
          'product': {
            'id': 3,
            'name': 'Espresso',
            'price': 2,
            'tax': 0,
            'discount': 0,
            'attributes': [],
            'status': 1,
          },
        },
      ],
    });
    expect(deal.items.length, 1);
    expect(deal.items.first.product.name, 'Espresso');
  });

  test('CartModel.fromJson tolerates null numeric fields', () {
    final cart = CartModel.fromJson({
      'price': null,
      'discounted_price': null,
      'discount_amount': null,
      'quantity': null,
      'tax_amount': null,
      'product': {
        'id': 1,
        'name': 'Latte',
        'price': 4,
        'tax': 0,
        'discount': 0,
        'attributes': null,
        'status': 1,
      },
    });
    expect(cart.quantity, 1);
    expect(cart.product?.name, 'Latte');
    expect(cart.price, isNull);
  });
}
