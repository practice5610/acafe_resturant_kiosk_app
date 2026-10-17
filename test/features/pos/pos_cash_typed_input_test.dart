import 'package:acafe_customer/features/pos/domain/pos_cash_entry.dart';
import 'package:acafe_customer/features/pos/widgets/pos_pay_cash_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Host extends StatefulWidget {
  final int totalCents;
  const _Host({required this.totalCents});

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  PosCashEntry entry = const PosCashEntry();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SizedBox(
            width: 460,
            child: PosPayCashSummaryPanel(
              total: widget.totalCents / 100,
              entry: entry,
              totalCents: widget.totalCents,
              selectedDenomination: null,
              onDenomination: (_) {},
              onKey: (t) => setState(() => entry = entry.key(t)),
              onTyped: (t) => setState(() => entry = entry.typed(t)),
              onBackspace: () => setState(() => entry = entry.backspace()),
              onClear: () => setState(() => entry = entry.clear()),
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('tapping the field focuses it and typed digits reach the entry',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const _Host(totalCents: 1950));

    await tester.tap(find.byType(TextField));
    await tester.pump();
    final EditableTextState editable =
        tester.state(find.byType(EditableText));
    expect(editable.widget.focusNode.hasFocus, isTrue);

    await tester.enterText(find.byType(TextField), '20.5');
    await tester.pump();

    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '20.5');
  });

  testWidgets('a letter typed into the field is rejected and the field stays a valid amount',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const _Host(totalCents: 1950));
    await tester.enterText(find.byType(TextField), '12a');
    await tester.pump();

    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '12');
  });

  testWidgets('keypad input re-syncs the typed field', (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const _Host(totalCents: 1950));
    await tester.tap(find.text('5').first);
    await tester.pump();

    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '€ 5.00',
        reason: 'at rest the field shows the formatted amount');
  });
}
