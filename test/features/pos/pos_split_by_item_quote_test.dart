import 'package:acafe_customer/features/pos/domain/pos_split_by_item_builder.dart';
import 'package:flutter_test/flutter_test.dart';

/// What each guest is charged when a ticket is split by item.
void main() {
  // The Dylan ticket: 6 + 6 + 7 = € 19.00.
  const List<PosSplitByItemLineItem> ticket = [
    PosSplitByItemLineItem(id: 0, name: 'Oat Milk Matcha', price: 6),
    PosSplitByItemLineItem(id: 1, name: 'Vanilla Matcha Latte', price: 6),
    PosSplitByItemLineItem(id: 2, name: 'Mango Matcha', price: 7),
  ];

  PosSplitByItemQuote quote(
    Set<int> picked, {
    Set<int> paid = const {},
    double orderTotal = 19,
    double? remaining,
    List<PosSplitByItemLineItem> items = ticket,
  }) =>
      posQuoteSplitByItem(
        items: items,
        picked: picked,
        paid: paid,
        orderTotal: orderTotal,
        remaining: remaining ?? orderTotal,
      );

  test('no discount or tip: exactly the picked items', () {
    expect(quote({0, 1}).cents, 1200);
    expect(quote({0, 1}).settles, isFalse);
    expect(quote({2}, paid: {0, 1}, remaining: 7).cents, 700);
  });

  test('the guest who takes the last items pays exactly what is left', () {
    final PosSplitByItemQuote last = quote({2}, paid: {0, 1}, remaining: 7.01);
    expect(last.cents, 701);
    expect(last.settles, isTrue);
    expect(quote({0, 1, 2}).cents, 1900);
  });

  test('a coupon discount is shared in proportion, and adds up to the cent',
      () {
    // 10% off: € 17.10 for € 19.00 of items.
    final int first = quote({0, 1}, orderTotal: 17.10).cents;
    expect(first, 1080); // 12 × 0.9
    final int second =
        quote({2}, paid: {0, 1}, orderTotal: 17.10, remaining: 17.10 - 10.80)
            .cents;
    expect(second, 630);
    expect(first + second, 1710);
  });

  test('a tip added before the first payment is shared the same way', () {
    // € 2.00 tip on € 19.00: € 21.00.
    final int first = quote({0, 1}, orderTotal: 21).cents;
    expect(first, 1326); // 12 × 21 / 19 = 13.263…
    expect(quote({2}, paid: {0, 1}, orderTotal: 21, remaining: 21 - 13.26).cents,
        774);
  });

  test('three guests with a rounding share still total the order', () {
    const items = [
      PosSplitByItemLineItem(id: 0, name: 'A', price: 10),
      PosSplitByItemLineItem(id: 1, name: 'B', price: 10),
      PosSplitByItemLineItem(id: 2, name: 'C', price: 10),
    ];
    int left = 2000; // € 20.00 after a discount
    final List<int> shares = [];
    final Set<int> paid = {};
    for (final int id in [0, 1, 2]) {
      final PosSplitByItemQuote q = quote({id},
          items: items, paid: paid, orderTotal: 20, remaining: left / 100);
      shares.add(q.cents);
      left -= q.cents;
      paid.add(id);
    }
    expect(shares, [667, 667, 666]);
    expect(left, 0);
  });

  test('paid items and an empty pick charge nothing', () {
    expect(quote({}).payable, isFalse);
    expect(quote({0}, paid: {0}, remaining: 13).payable, isFalse);
    expect(quote({0}, remaining: 0).payable, isFalse);
  });

  test('a share is never more than is still owed', () {
    expect(quote({0, 1}, remaining: 5).cents, 500);
  });

  test('a line of more than one reads "× n"', () {
    expect(
        const PosSplitByItemLineItem(
                id: 0, name: 'Cappuccino', price: 7.6, quantity: 2)
            .title,
        'Cappuccino × 2');
    expect(ticket.first.title, 'Oat Milk Matcha');
  });
}
