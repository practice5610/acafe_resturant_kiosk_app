import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/widgets/pos_receipt_context_menu.dart';
import 'package:acafe_customer/features/pos/widgets/pos_receipt_panel.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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

  Future<void> openMenuFromReceipt(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1366, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: PosHomeSpec.receiptWidth,
            height: 944,
            child: PosReceiptPanel(
              orderType: PosOrderType.dineIn,
              onOrderTypeChanged: (_) {},
              customerNameController: name,
              tableController: table,
              subtotal: 25,
              discount: 8.3,
              total: 16.7,
              onOptions: (anchor) {
                showPosReceiptContextMenu(
                  context: anchor,
                  anchorContext: anchor,
                );
              },
            ),
          ),
        ),
      ),
    );

    // The options control is the only 32×32 ink well in the header.
    final Finder options = find.byWidgetPredicate(
      (w) =>
          w is InkWell &&
          w.child is Container &&
          (w.child as Container).constraints?.maxWidth ==
              PosHomeSpec.optionsButtonSize,
    );
    await tester.tap(options);
    await tester.pumpAndSettle();
  }

  testWidgets('⋯ opens the Figma context menu with all sections',
      (tester) async {
    await openMenuFromReceipt(tester);

    expect(find.text('DISCOUNT ACTIONS'), findsOneWidget);
    expect(find.text('PRICE ADJUSTMENTS'), findsOneWidget);
    expect(find.text('ORDER MANAGEMENT'), findsOneWidget);
    expect(find.text('PAYMENT-RELATED'), findsOneWidget);
    expect(find.text('Apply discount'), findsOneWidget);
    expect(find.text('Apply custom discount'), findsOneWidget);
    expect(find.text('Remove discount'), findsOneWidget);
    expect(find.text('Price override'), findsOneWidget);
    expect(find.text('Tax exempt'), findsOneWidget);
    expect(find.text('Comp item'), findsOneWidget);
    expect(find.text('Move to another table...'), findsOneWidget);
    expect(find.text('Hold / Fire item'), findsOneWidget);
    expect(find.text('Send to kitchen / bar'), findsOneWidget);
    expect(find.text('Repeat item'), findsOneWidget);
    expect(find.text('Partial payment'), findsOneWidget);
    expect(find.text('Gift card apply'), findsOneWidget);
    expect(find.text('Loyalty points'), findsOneWidget);

    final Text remove = tester.widget<Text>(find.text('Remove discount'));
    expect(remove.style?.color, PosHomeSpec.contextMenuDanger);
    expect(remove.style?.fontWeight, FontWeight.w700);

    final Size menuSize = tester.getSize(
      find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color == Colors.white &&
            (w.decoration as BoxDecoration).borderRadius ==
                BorderRadius.circular(PosHomeSpec.contextMenuRadius),
      ),
    );
    expect(menuSize.width, PosHomeSpec.contextMenuWidth);
  });

  testWidgets('menu uses Figma SVG icon assets', (tester) async {
    await openMenuFromReceipt(tester);

    expect(
      find.byWidgetPredicate(
        (w) =>
            w is SvgPicture &&
            w.bytesLoader.toString().contains(Images.posMenuPercentSvg),
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is SvgPicture &&
            w.bytesLoader.toString().contains(Images.posMenuTrashSvg),
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is SvgPicture &&
            w.bytesLoader.toString().contains(Images.posMenuStarSvg),
      ),
      findsOneWidget,
    );
  });

  testWidgets('tapping Remove discount returns that action', (tester) async {
    tester.view.physicalSize = const Size(1366, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    PosReceiptMenuAction? chosen;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topRight,
            child: Builder(
              builder: (context) {
                return SizedBox(
                  width: PosHomeSpec.optionsButtonSize,
                  height: PosHomeSpec.optionsButtonSize,
                  child: GestureDetector(
                    onTap: () async {
                      chosen = await showPosReceiptContextMenu(
                        context: context,
                        anchorContext: context,
                      );
                    },
                    child: const ColoredBox(color: Colors.black),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(GestureDetector));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove discount'));
    await tester.pumpAndSettle();

    expect(chosen, PosReceiptMenuAction.removeDiscount);
  });
}
