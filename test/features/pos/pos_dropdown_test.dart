import 'package:acafe_customer/features/pos/domain/pos_general_settings.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipt_filters.dart';
import 'package:acafe_customer/features/pos/widgets/pos_dropdown.dart';
import 'package:acafe_customer/features/pos/widgets/pos_filter_dropdown.dart';
import 'package:acafe_customer/features/pos/widgets/pos_settings_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const Key _trigger = Key('trigger');

List<PosDropdownOption<int?>> _options(int n) => [
      const PosDropdownOption<int?>(value: null, label: 'All'),
      for (int i = 1; i < n; i++)
        PosDropdownOption<int?>(value: i, label: 'Option $i'),
    ];

/// A bare dropdown placed at [top] in a 800x600 screen, with a button right
/// below it (painted later in the tree) to prove the menu sits above it.
Future<void> _pump(
  WidgetTester tester, {
  required int? value,
  required ValueChanged<int?> onChanged,
  double top = 40,
  int count = 3,
  VoidCallback? onSiblingTap,
  bool show = true,
}) async {
  tester.view.physicalSize = const Size(800, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            if (show)
              Positioned(
                left: 40,
                top: top,
                child: PosDropdown<int?>(
                  value: value,
                  onChanged: onChanged,
                  options: _options(count),
                  triggerBuilder: (context, selected, isOpen, toggle) =>
                      GestureDetector(
                    key: _trigger,
                    onTap: toggle,
                    child: SizedBox(
                      width: 200,
                      height: 48,
                      child: Text(selected?.label ?? '-'),
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 40,
              top: top + 60,
              child: ElevatedButton(
                key: const Key('sibling'),
                onPressed: onSiblingTap ?? () {},
                child: const SizedBox(width: 200, height: 80),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('opens BELOW the trigger and never covers it', (tester) async {
    await _pump(tester, value: null, onChanged: (_) {});
    await tester.tap(find.byKey(_trigger));
    await tester.pumpAndSettle();

    final Rect trigger = tester.getRect(find.byKey(_trigger));
    final Rect menu = tester.getRect(find.byKey(PosDropdown.menuKey));
    expect(menu.top, greaterThanOrEqualTo(trigger.bottom));
    expect(menu.left, trigger.left);
    expect(menu.width, greaterThanOrEqualTo(trigger.width));
    expect(menu.overlaps(trigger), isFalse);
  });

  testWidgets('menu is on top of later widgets (root overlay z-order)',
      (tester) async {
    bool siblingTapped = false;
    int? picked = -1;
    await _pump(
      tester,
      value: null,
      onChanged: (v) => picked = v,
      onSiblingTap: () => siblingTapped = true,
    );
    await tester.tap(find.byKey(_trigger));
    await tester.pumpAndSettle();

    // Row 1 is drawn right where the sibling button is.
    final Rect row = tester.getRect(find.byKey(PosDropdown.itemKey(1)));
    expect(row.overlaps(tester.getRect(find.byKey(const Key('sibling')))),
        isTrue);

    await tester.tap(find.byKey(PosDropdown.itemKey(1)));
    await tester.pumpAndSettle();
    expect(picked, 1);
    expect(siblingTapped, isFalse);
    expect(find.byKey(PosDropdown.menuKey), findsNothing);
  });

  testWidgets('a null option is a real choice, not a dismiss', (tester) async {
    int? picked = 99;
    bool called = false;
    await _pump(tester, value: 2, onChanged: (v) {
      called = true;
      picked = v;
    });
    await tester.tap(find.byKey(_trigger));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(PosDropdown.itemKey(0)));
    await tester.pumpAndSettle();
    expect(called, isTrue);
    expect(picked, isNull);
  });

  testWidgets('re-picking the current value does not fire onChanged',
      (tester) async {
    int calls = 0;
    await _pump(tester, value: 1, onChanged: (_) => calls++);
    await tester.tap(find.byKey(_trigger));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    await tester.tap(find.byKey(PosDropdown.itemKey(1)));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.byKey(PosDropdown.menuKey), findsNothing);
  });

  testWidgets('tapping outside closes without selecting or hitting beneath',
      (tester) async {
    int calls = 0;
    bool siblingTapped = false;
    await _pump(tester,
        value: null,
        onChanged: (_) => calls++,
        onSiblingTap: () => siblingTapped = true);
    await tester.tap(find.byKey(_trigger));
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(700, 500));
    await tester.pumpAndSettle();
    expect(find.byKey(PosDropdown.menuKey), findsNothing);
    expect(calls, 0);
    expect(siblingTapped, isFalse);
  });

  testWidgets('tapping the trigger again closes it', (tester) async {
    await _pump(tester, value: null, onChanged: (_) {});
    await tester.tap(find.byKey(_trigger));
    await tester.pumpAndSettle();
    expect(find.byKey(PosDropdown.menuKey), findsOneWidget);
    await tester.tap(find.byKey(_trigger), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byKey(PosDropdown.menuKey), findsNothing);
  });

  testWidgets('Escape closes the menu', (tester) async {
    await _pump(tester, value: null, onChanged: (_) {});
    await tester.tap(find.byKey(_trigger));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(PosDropdown.menuKey), findsNothing);
  });

  testWidgets('flips ABOVE the trigger when there is no room below',
      (tester) async {
    await _pump(tester, value: null, onChanged: (_) {}, top: 480, count: 5);
    await tester.tap(find.byKey(_trigger));
    await tester.pumpAndSettle();

    final Rect trigger = tester.getRect(find.byKey(_trigger));
    final Rect menu = tester.getRect(find.byKey(PosDropdown.menuKey));
    expect(menu.bottom, lessThanOrEqualTo(trigger.top));
    expect(menu.top, greaterThanOrEqualTo(0));
  });

  testWidgets('long lists stay on screen and scroll', (tester) async {
    await _pump(tester, value: 30, onChanged: (_) {}, count: 40);
    await tester.tap(find.byKey(_trigger));
    await tester.pumpAndSettle();

    final Rect menu = tester.getRect(find.byKey(PosDropdown.menuKey));
    expect(menu.height, lessThanOrEqualTo(320));
    expect(menu.bottom, lessThanOrEqualTo(600));
    // Opened scrolled to the current pick.
    expect(find.text('Option 30'), findsWidgets);
    expect(find.byKey(PosDropdown.itemKey(1)), findsNothing);
  });

  testWidgets('removing the trigger removes the menu', (tester) async {
    await _pump(tester, value: null, onChanged: (_) {});
    await tester.tap(find.byKey(_trigger));
    await tester.pumpAndSettle();
    await _pump(tester, value: null, onChanged: (_) {}, show: false);
    await tester.pumpAndSettle();
    expect(find.byKey(PosDropdown.menuKey), findsNothing);
  });

  // Regression: the Orders board rebuilds every second for its timers. A
  // parent rebuild while the menu is open used to throw "markNeedsBuild()
  // called during build" and paint the app's ErrorWidget.
  testWidgets('parent rebuilds while open are safe and refresh the menu',
      (tester) async {
    late StateSetter rebuild;
    int? value;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(builder: (context, setState) {
          rebuild = setState;
          return Align(
            alignment: Alignment.topLeft,
            child: PosDropdown<int?>(
              value: value,
              onChanged: (_) {},
              // A fresh list every build, exactly like the real wrappers.
              options: _options(3),
              triggerBuilder: (context, selected, isOpen, toggle) =>
                  GestureDetector(
                key: _trigger,
                onTap: toggle,
                child: SizedBox(width: 200, height: 48, child: Text('$isOpen')),
              ),
            ),
          );
        }),
      ),
    ));
    await tester.tap(find.byKey(_trigger));
    await tester.pumpAndSettle();

    for (int tick = 0; tick < 3; tick++) {
      rebuild(() => value = tick == 2 ? 2 : null);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    }
    expect(find.byKey(PosDropdown.menuKey), findsOneWidget);
    // The open menu reflects the new value without reopening.
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(
      find.descendant(
          of: find.byKey(PosDropdown.itemKey(2)),
          matching: find.byIcon(Icons.check_rounded)),
      findsOneWidget,
    );
  });

  testWidgets('PosSettingsDropdown opens below its field and selects',
      (tester) async {
    String? picked;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: PosSettingsDropdown(
            label: 'Default Currency',
            value: 'EUR',
            options: const [
              PosSettingsOption(value: 'EUR', label: 'Euro'),
              PosSettingsOption(value: 'USD', label: 'US Dollar'),
            ],
            onChanged: (v) => picked = v,
          ),
        ),
      ),
    ));
    final Rect field = tester.getRect(find.text('Euro'));
    await tester.tap(find.text('Euro'));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(PosDropdown.menuKey)).top,
        greaterThan(field.bottom));
    await tester.tap(find.text('US Dollar'));
    await tester.pumpAndSettle();
    expect(picked, 'USD');
  });

  testWidgets('PosFilterDropdown opens below its pill and picks the null "all"',
      (tester) async {
    String? picked = 'x';
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Align(
            alignment: Alignment.topLeft,
            child: PosFilterDropdown<String?>(
              label: 'Status',
              value: 'paid',
              options: const [
                PosReceiptFilterOption<String?>('All', null),
                PosReceiptFilterOption<String?>('Paid', 'paid'),
              ],
              onChanged: (v) => picked = v,
            ),
          ),
        ),
      ),
    ));
    final Rect pill = tester.getRect(find.text('Paid'));
    await tester.tap(find.text('Paid'));
    await tester.pumpAndSettle();
    final Rect menu = tester.getRect(find.byKey(PosDropdown.menuKey));
    expect(menu.top, greaterThan(pill.bottom));
    expect(menu.width, greaterThanOrEqualTo(180));
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(picked, isNull);
  });
}
