import 'package:acafe_customer/features/kiosk/domain/kiosk_allergen.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_allergen_filter_screen.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_allergen_filter_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kiosk_layout_harness.dart';

/// The allergen entry point inside the Filter sheet.
///
/// The behaviour worth protecting is the way BACK: dismissing the once-per-order
/// popup marks it asked, and before this row that was a one-way door — the only
/// other affordance was the empty-state link, which needs a filter to already be
/// active. So the row has to open the popup whether or not anything is selected,
/// and it must not be wired into the sheet's Apply / Reset, because Reset
/// silently clearing someone's allergens would be dangerous in a way none of the
/// other filters are.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadKioskTestFonts);
  setUp(() => KioskAllergenPreferences.instance.reset());
  tearDown(() => KioskAllergenPreferences.instance.reset());

  Future<void> pumpRow(WidgetTester tester, Size size,
      {VoidCallback? onBeforeOpen}) async {
    await pumpKioskScreen(
      tester,
      size,
      Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: KioskAllergenFilterRow(onBeforeOpen: onBeforeOpen),
        ),
      ),
    );
    await settleKiosk(tester);
  }

  group('layout', () {
    for (final Size size in kioskTargetSizes) {
      testWidgets(
          'renders without overflow at ${size.width.toInt()}x${size.height.toInt()}',
          (tester) async {
        await pumpRow(tester, size);
        expectNoOverflow(tester, size);
        expect(find.text('Allergens'), findsOneWidget);
        expect(find.text('Anything to avoid?'), findsOneWidget);
      });
    }
  });

  group('summary', () {
    testWidgets('invites the customer in when nothing is selected',
        (tester) async {
      await pumpRow(tester, const Size(1080, 1920));

      expect(
        find.text('Tap to choose allergens to hide from the menu'),
        findsOneWidget,
      );
      // Neutral glyph, not a swatch stack.
      expect(find.byIcon(Icons.no_food_outlined), findsOneWidget);
    });

    testWidgets('names what is being hidden, in a stable order',
        (tester) async {
      // Applied out of enum order on purpose: the summary must not echo the
      // order the customer happened to tick them in.
      KioskAllergenPreferences.instance.applySelection(
        <KioskAllergen>{KioskAllergen.nuts, KioskAllergen.dairy},
      );
      await pumpRow(tester, const Size(1080, 1920));

      expect(find.text('Hiding: Dairy, Nuts'), findsOneWidget);
      expect(find.byIcon(Icons.no_food_outlined), findsNothing);
    });

    testWidgets('follows the preferences without being rebuilt by its parent',
        (tester) async {
      await pumpRow(tester, const Size(1080, 1920));
      expect(find.text('Tap to choose allergens to hide from the menu'),
          findsOneWidget);

      // A commit from anywhere (the popup, a reset) has to reach the row.
      KioskAllergenPreferences.instance
          .applySelection(<KioskAllergen>{KioskAllergen.egg});
      await settleKiosk(tester);
      expect(find.text('Hiding: Egg'), findsOneWidget);

      KioskAllergenPreferences.instance.reset();
      await settleKiosk(tester);
      expect(find.text('Tap to choose allergens to hide from the menu'),
          findsOneWidget);
    });
  });

  group('opening the popup', () {
    testWidgets('works after the popup was dismissed once', (tester) async {
      // Exactly the state this row exists for: asked, nothing declared.
      KioskAllergenPreferences.instance.markAsked();
      expect(KioskAllergenPreferences.instance.asked, isTrue);

      await pumpRow(tester, const Size(1080, 1920));
      await tester.tap(find.text('Anything to avoid?'));
      await settleKiosk(tester);

      expect(find.byType(KioskAllergenFilterScreen), findsOneWidget);
    });

    testWidgets('opens showing what is already avoided', (tester) async {
      KioskAllergenPreferences.instance
          .applySelection(<KioskAllergen>{KioskAllergen.gluten});

      await pumpRow(tester, const Size(1080, 1920));
      await tester.tap(find.text('Anything to avoid?'));
      await settleKiosk(tester);

      final KioskAllergenFilterScreen popup =
          tester.widget(find.byType(KioskAllergenFilterScreen));
      expect(popup.initialSelection, <KioskAllergen>{KioskAllergen.gluten});
    });

    testWidgets('closes the filter sheet first, so the popup is not stacked',
        (tester) async {
      int closed = 0;
      await pumpRow(tester, const Size(1080, 1920),
          onBeforeOpen: () => closed++);

      await tester.tap(find.text('Anything to avoid?'));
      await settleKiosk(tester);

      expect(closed, 1);
      expect(find.byType(KioskAllergenFilterScreen), findsOneWidget);
    });

    testWidgets('a selection made in the popup reaches the shared preferences',
        (tester) async {
      await pumpRow(tester, const Size(1080, 1920));
      await tester.tap(find.text('Anything to avoid?'));
      await settleKiosk(tester);

      await tester.tap(find.text('Dairy'));
      await settleKiosk(tester);
      await tester.tap(find.text('APPLY FILTERS'));
      await settleKiosk(tester);

      expect(KioskAllergenPreferences.instance.avoided,
          <KioskAllergen>{KioskAllergen.dairy});
      // …and the row it returns to now says so.
      expect(find.text('Hiding: Dairy'), findsOneWidget);
    });
  });
}
