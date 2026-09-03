import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipt_line_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads Cup from the selected vessel variation', () {
    final Product product = Product(
      name: 'Matcha',
      variations: [
        Variation(
          name: 'Can or cup?',
          variationValues: [
            VariationValue(level: 'Cup'),
            VariationValue(level: 'Can'),
          ],
        ),
      ],
    );
    final CartModel line = CartModel(
      5.5,
      5.5,
      const [],
      0,
      1,
      0,
      const [],
      product,
      [
        [true, false],
      ],
    );

    expect(posReceiptUnit(line), 'Cup');
    expect(posReceiptLineName(line), 'Matcha');
  });

  test('paid add-ons are plus notes; dropped defaults are minus notes', () {
    final Product product = Product(
      name: 'Mango Matcha',
      addOns: [
        AddOns(id: 1, name: 'Oat milk'),
        AddOns(id: 2, name: 'Whipped cream', isDefault: true),
      ],
    );
    final CartModel line = CartModel(
      7,
      7,
      const [],
      0,
      1,
      0,
      [AddOn(id: 1, quantity: 1)],
      product,
      const [],
    );

    final notes = posReceiptNotes(line);
    expect(notes.map((n) => '${n.included ? '+' : '-'}${n.label}').toList(),
        ['+Oat milk', '-Whipped cream']);
  });
}
