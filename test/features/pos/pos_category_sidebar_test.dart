import 'package:acafe_customer/features/category/domain/category_model.dart';
import 'package:acafe_customer/features/pos/widgets/pos_category_sidebar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

List<CategoryModel> _cats() => [
      CategoryModel(id: 1, name: 'Coffee'),
      CategoryModel(id: 2, name: 'Macha'),
    ];

Future<void> _pump(
  WidgetTester tester, {
  VoidCallback? onPunch,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PosCategorySidebar(
          categories: _cats(),
          selectedId: '1',
          onSelect: (_) {},
          onPunch: onPunch,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the Punch In / Out action when a handler is given',
      (tester) async {
    await _pump(tester, onPunch: () {});

    expect(find.byKey(const Key('pos-sidebar-punch')), findsOneWidget);
    expect(find.text('PUNCH IN / OUT'), findsOneWidget);
  });

  testWidgets('tapping the action fires the handler', (tester) async {
    var taps = 0;
    await _pump(tester, onPunch: () => taps++);

    await tester.tap(find.byKey(const Key('pos-sidebar-punch')));
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('omits the action for callers that pass no handler',
      (tester) async {
    await _pump(tester); // existing callers / tests construct it without onPunch

    expect(find.byKey(const Key('pos-sidebar-punch')), findsNothing);
    // The categories still render as before.
    expect(find.text('COFFEE'), findsOneWidget);
  });
}
