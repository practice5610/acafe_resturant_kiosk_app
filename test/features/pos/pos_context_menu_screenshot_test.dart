import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/widgets/pos_receipt_context_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('context menu panel matches Figma 240×680 geometry',
      (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: PosReceiptContextMenuPanel()),
        ),
      ),
    );
    await tester.pump();

    final Size size = tester.getSize(find.byType(PosReceiptContextMenuPanel));
    expect(size.width, PosHomeSpec.contextMenuWidth);
    expect(size.height, closeTo(PosReceiptContextMenuPanel.preferredHeight, 2));

    expect(find.text('DISCOUNT ACTIONS'), findsOneWidget);
    expect(find.text('PRICE ADJUSTMENTS'), findsOneWidget);
    expect(find.text('ORDER MANAGEMENT'), findsOneWidget);
    expect(find.text('PAYMENT-RELATED'), findsOneWidget);
    expect(find.text('Move to another table...'), findsOneWidget);

    final Text remove = tester.widget<Text>(find.text('Remove discount'));
    expect(remove.style?.color, PosHomeSpec.contextMenuDanger);
  });
}
