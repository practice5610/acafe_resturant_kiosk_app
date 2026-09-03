import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
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
}
