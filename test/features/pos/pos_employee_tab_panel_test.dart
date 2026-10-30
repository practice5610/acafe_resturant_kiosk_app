import 'package:acafe_customer/features/pos/widgets/pos_dropdown.dart';
import 'package:acafe_customer/features/pos/widgets/pos_employee_tab_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Open Employee Tab summary pane: it replaces the keypad + tip row with a
/// staff picker and the consumed value shown as the employee's expense. Tipping
/// has no place here, so the pane must never render an "Add tip" affordance.
void main() {
  const List<PosEmployeeOption> staff = [
    PosEmployeeOption(id: 'a1', name: 'Dylan'),
    PosEmployeeOption(id: 'b2', name: 'Noor'),
  ];

  Future<void> pump(
    WidgetTester tester, {
    String? selectedId,
    String? selectedName,
    ValueChanged<String>? onSelect,
    List<PosEmployeeOption> employees = staff,
    bool loading = false,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 452,
              height: 835,
              child: PosEmployeeTabPanel(
                expense: 4.50,
                employees: employees,
                selectedId: selectedId,
                selectedName: selectedName,
                onSelect: onSelect ?? (_) {},
                loading: loading,
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows the expense and no tip affordance', (tester) async {
    await pump(tester);

    expect(find.text('EMPLOYEE TAB'), findsOneWidget);
    expect(find.text('Employee expense'), findsOneWidget);
    expect(find.text('No payment — staff comp'), findsOneWidget);
    // The consumed value is shown…
    expect(find.textContaining('4.50'), findsOneWidget);
    // …and tipping never appears on an employee tab.
    expect(find.text('Add tip'), findsNothing);
    expect(find.text('Add the tip you received here'), findsNothing);
  });

  testWidgets('placeholder until an employee is picked, then the name',
      (tester) async {
    await pump(tester);
    expect(find.text('Select employee'), findsOneWidget);
    expect(find.text('Dylan'), findsNothing);

    await pump(tester, selectedId: 'a1');
    expect(find.text('Select employee'), findsNothing);
    expect(find.text('Dylan'), findsOneWidget);
  });

  testWidgets('picking an employee reports the id', (tester) async {
    String? picked;
    await pump(tester, onSelect: (id) => picked = id);

    await tester.tap(find.byKey(PosEmployeeTabPanel.pickerKey));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
      of: find.byKey(PosDropdown.menuKey),
      matching: find.text('Noor').first.hitTestable(),
    ).first);
    await tester.pumpAndSettle();

    expect(picked, 'b2');
  });

  testWidgets('pre-selected name shows before the roster loads', (tester) async {
    // The signed-in employee is defaulted before their option is available.
    await pump(tester,
        selectedId: 'me', selectedName: 'Amir', employees: const [], loading: true);

    expect(find.text('Amir'), findsOneWidget);
    expect(find.text('Loading staff…'), findsNothing);
    expect(find.text('Select employee'), findsNothing);
  });

  testWidgets('empty roster reads as loading, then no staff', (tester) async {
    await pump(tester, employees: const [], loading: true);
    expect(find.text('Loading staff…'), findsOneWidget);

    await pump(tester, employees: const [], loading: false);
    expect(find.text('No staff available'), findsOneWidget);
  });
}
