import 'package:acafe_customer/features/pos/widgets/pos_add_note_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Add Note dialog shows the product's Quick Add chips, and only then.
void main() {
  Future<Future<String?>> openDialog(
      WidgetTester tester, List<String> quickAdd) async {
    tester.view.physicalSize = const Size(1366, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    late Future<String?> result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => result =
                showPosAddNoteDialog(context: context, quickAdd: quickAdd),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('suggestions render as Quick Add chips that fill the note',
      (tester) async {
    final Future<String?> result =
        await openDialog(tester, ['less ice', 'more ice', 'hot water']);

    expect(find.text('Quick Add'), findsOneWidget);
    expect(find.text('less ice'), findsOneWidget);
    expect(find.text('hot water'), findsOneWidget);

    await tester.tap(find.text('less ice'));
    await tester.tap(find.text('hot water'));
    await tester.pump();
    await tester.tap(find.widgetWithText(InkWell, 'Add Note'));
    await tester.pumpAndSettle();

    expect(await result, 'less ice, hot water');
  });

  testWidgets('no suggestions hides the Quick Add section', (tester) async {
    await openDialog(tester, const []);

    expect(find.text('Add Note'), findsWidgets);
    expect(find.text('Quick Add'), findsNothing);
  });
}
