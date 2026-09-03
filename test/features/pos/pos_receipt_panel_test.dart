import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/widgets/pos_receipt_line.dart';
import 'package:acafe_customer/features/pos/widgets/pos_receipt_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late TextEditingController name;
  late TextEditingController table;

  setUp(() {
    name = TextEditingController();
    table = TextEditingController();
  });

  tearDown(() {
    name.dispose();
    table.dispose();
  });

  Future<void> pumpPanel(
    WidgetTester tester, {
    double subtotal = 0,
    double discount = 0,
    double total = 0,
    PosOrderType type = PosOrderType.dineIn,
  }) async {
    tester.view.physicalSize = const Size(1366, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 944,
            child: PosReceiptPanel(
              orderType: type,
              onOrderTypeChanged: (_) {},
              customerNameController: name,
              tableController: table,
              subtotal: subtotal,
              discount: discount,
              total: total,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('empty cart shows the Figma empty state and zero totals',
      (tester) async {
    await pumpPanel(tester);

    expect(find.text('Purchase Receipt'), findsOneWidget);
    expect(find.text('No items'), findsOneWidget);
    expect(find.text('Add items to get started'), findsOneWidget);
    expect(find.text('Discount'), findsNothing);
    expect(tester.getSize(find.byType(PosReceiptPanel)).width,
        PosHomeSpec.receiptWidth);
  });

  testWidgets('discount row appears only when a coupon is applied',
      (tester) async {
    await pumpPanel(tester, discount: 2.5, total: 10);
    expect(find.text('Discount'), findsOneWidget);
  });

  testWidgets('Dine In is the default active order type', (tester) async {
    await pumpPanel(tester);
    final dine = tester.widget<Text>(find.text('Dine In'));
    expect(dine.style?.color, PosHomeSpec.pageBg);
  });

  testWidgets('a filled cart shows lines, green discount, and PAY',
      (tester) async {
    tester.view.physicalSize = const Size(1366, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final product = Product(id: 1, name: 'Oat Milk Matcha', price: 5.5);
    final line = CartModel(
      5.5,
      5.5,
      const [],
      0,
      2,
      0,
      const [],
      product,
      const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 944,
            child: PosReceiptPanel(
              orderType: PosOrderType.dineIn,
              onOrderTypeChanged: (_) {},
              customerNameController: name,
              tableController: table,
              subtotal: 25,
              discount: 8.3,
              total: 16.7,
              orderList: PosReceiptOrderList(
                lines: [line],
                imageBaseUrl: null,
                onIncrement: (_) {},
                onDecrement: (_) {},
                onEdit: (_) {},
              ),
              onPay: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('No items'), findsNothing);
    expect(find.text('Oat Milk Matcha'), findsOneWidget);
    expect(find.text('EDIT'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.textContaining('PAY /'), findsOneWidget);

    final discount = tester.widget<Text>(find.text('Discount'));
    expect(discount.style?.color, PosHomeSpec.discountGreen);
  });

  testWidgets('long names and notes stay inside the receipt pane',
      (tester) async {
    tester.view.physicalSize = const Size(1366, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final product = Product(
      id: 1,
      name: 'White Chocolate Strawberry Matcha With Extra Long Name',
      price: 7,
      image: 'matcha.png',
      addOns: [
        AddOns(id: 1, name: 'House-made toasted coconut milk foam'),
        AddOns(id: 2, name: 'Whipped cream', isDefault: true),
      ],
    );
    final line = CartModel(
      7,
      7,
      const [],
      0,
      12,
      0,
      [AddOn(id: 1, quantity: 1)],
      product,
      const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 944,
            child: PosReceiptPanel(
              orderType: PosOrderType.dineIn,
              onOrderTypeChanged: (_) {},
              customerNameController: name,
              tableController: table,
              subtotal: 84,
              discount: 0,
              total: 84,
              orderList: PosReceiptOrderList(
                lines: [line],
                imageBaseUrl: null,
                onIncrement: (_) {},
                onDecrement: (_) {},
                onEdit: (_) {},
              ),
              onPay: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);

    final Rect panel = tester.getRect(find.byType(PosReceiptPanel));
    final Rect row = tester.getRect(find.byType(PosReceiptLine));
    expect(row.left, greaterThanOrEqualTo(panel.left));
    expect(row.right, lessThanOrEqualTo(panel.right + 0.5));

    expect(find.text('EDIT'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('qty 1 shows delete; qty > 1 shows minus; both stay tappable',
      (tester) async {
    tester.view.physicalSize = const Size(1366, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    int qty = 1;
    int increments = 0;
    int decrements = 0;

    Future<void> pumpLine() async {
      final product = Product(id: 1, name: 'Cortado', price: 5.5);
      final line = CartModel(
        5.5,
        5.5,
        const [],
        0,
        qty,
        0,
        const [],
        product,
        const [],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 944,
              child: PosReceiptPanel(
                orderType: PosOrderType.dineIn,
                onOrderTypeChanged: (_) {},
                customerNameController: name,
                tableController: table,
                subtotal: 5.5 * qty,
                discount: 0,
                total: 5.5 * qty,
                orderList: PosReceiptOrderList(
                  lines: [line],
                  imageBaseUrl: null,
                  onIncrement: (_) {
                    increments++;
                    qty++;
                  },
                  onDecrement: (_) {
                    decrements++;
                    if (qty > 1) qty--;
                  },
                  onEdit: (_) {},
                ),
                onPay: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    await pumpLine();
    expect(find.byKey(const Key('pos-qty-delete')), findsOneWidget);
    expect(find.byKey(const Key('pos-qty-minus')), findsNothing);
    expect(find.byKey(const Key('pos-qty-plus')), findsOneWidget);

    await tester.tap(find.byKey(const Key('pos-qty-plus')));
    await pumpLine();
    expect(increments, 1);
    expect(find.byKey(const Key('pos-qty-minus')), findsOneWidget);
    expect(find.byKey(const Key('pos-qty-delete')), findsNothing);
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.byKey(const Key('pos-qty-minus')));
    await pumpLine();
    expect(decrements, 1);
    expect(find.byKey(const Key('pos-qty-delete')), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });
}
