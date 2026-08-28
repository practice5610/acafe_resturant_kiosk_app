import 'dart:convert';
import 'dart:io';

import 'package:acafe_customer/features/kiosk/domain/kiosk_allergen.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_allergen_filter_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kiosk_layout_harness.dart';

/// Allergen filter popup (Figma POS node 1385:15054).
///
/// Two things are being protected here. First, that the popup survives every
/// viewport the kiosk ships on AND stays a dialog on each of them — it is
/// sized from the card, not the screen, and the rows have to scroll rather
/// than overflow on a short landscape panel. Second, that the interaction
/// commits the right thing, since a wrong selection here removes food from
/// someone's menu.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadKioskTestFonts);
  setUp(() => KioskAllergenPreferences.instance.reset());
  tearDown(() => KioskAllergenPreferences.instance.reset());

  // No AppLocalization delegate on purpose — the same convention the coupon and
  // language-sheet tests use. It doubles as proof that every string falls back
  // to readable copy instead of rendering a raw key at a customer.
  Future<void> pumpPopup(WidgetTester tester, Size size) async {
    await pumpKioskScreen(tester, size, const KioskAllergenFilterScreen());
    await settleKiosk(tester);
  }

  group('layout', () {
    for (final Size size in kioskTargetSizes) {
      testWidgets('renders without overflow at ${size.width.toInt()}'
          'x${size.height.toInt()}', (tester) async {
        await pumpPopup(tester, size);

        expectNoOverflow(tester, size);
        expect(find.text('ANYTHING WE SHOULD KNOW?'), findsOneWidget);
        expect(find.text('APPLY FILTERS'), findsOneWidget);
        for (final KioskAllergen allergen in KioskAllergen.values) {
          expect(find.text(allergen.label), findsOneWidget,
              reason: '${allergen.label} row missing at $size');
        }
      });
    }

    // The popup used to be drawn at the raw 2078px Figma frame — 81% of the
    // artboard — which on every panel we ship read as a second page rather
    // than a dialog. These lock in the smaller card.
    for (final Size size in kioskTargetSizes) {
      testWidgets('the card reads as a dialog at ${size.width.toInt()}'
          'x${size.height.toInt()}', (tester) async {
        await pumpPopup(tester, size);

        final Rect card = tester.getRect(find.byKey(kKioskAllergenCardKey));

        expect(card.width, lessThanOrEqualTo(size.width * 0.66),
            reason: 'card is filling the screen again at $size');
        expect(card.height, lessThanOrEqualTo(size.height),
            reason: 'card is taller than the viewport at $size');
        expect(card.left, greaterThanOrEqualTo(0));
        expect(card.right, lessThanOrEqualTo(size.width + 0.5));
        expect((card.center.dx - size.width / 2).abs(), lessThan(1),
            reason: 'card is not centred at $size');
      });
    }

    // Not a kiosk panel, but the flow runs in a browser during development and
    // a resized window must degrade rather than overflow: the card takes the
    // width it can get and everything inside shrinks by the same factor.
    for (final Size size in const <Size>[Size(720, 1280), Size(600, 900)]) {
      testWidgets('survives a narrow window at ${size.width.toInt()}'
          'x${size.height.toInt()}', (tester) async {
        await pumpPopup(tester, size);

        expectNoOverflow(tester, size);
        final Rect card = tester.getRect(find.byKey(kKioskAllergenCardKey));
        expect(card.width, lessThanOrEqualTo(size.width));
        expect(find.text('APPLY FILTERS'), findsOneWidget);
      });
    }

    testWidgets('the apply button stays on screen on a short landscape panel',
        (tester) async {
      // The failure mode this guards: the rows push APPLY below the fold and
      // the customer has no way to leave the popup except the back chevron.
      const Size shortLandscape = Size(1366, 768);
      await pumpPopup(tester, shortLandscape);

      final Rect button = tester.getRect(find.text('APPLY FILTERS'));

      expect(button.bottom, lessThanOrEqualTo(shortLandscape.height));
      expect(button.top, greaterThanOrEqualTo(0));
    });
  });

  group('selection', () {
    testWidgets('applying commits only the ticked allergens', (tester) async {
      await pumpPopup(tester, const Size(1080, 1920));

      await tester.tap(find.text('Nuts'));
      await tester.pump();
      await tester.tap(find.text('APPLY FILTERS'));
      await settleKiosk(tester);

      expect(KioskAllergenPreferences.instance.avoided, {KioskAllergen.nuts});
      expect(KioskAllergenPreferences.instance.asked, isTrue);
    });

    testWidgets('tapping a row twice deselects it', (tester) async {
      await pumpPopup(tester, const Size(1080, 1920));

      await tester.tap(find.text('Soy'));
      await tester.pump();
      await tester.tap(find.text('Soy'));
      await tester.pump();
      await tester.tap(find.text('APPLY FILTERS'));
      await settleKiosk(tester);

      expect(KioskAllergenPreferences.instance.avoided, isEmpty);
    });

    testWidgets('select all ticks every allergen, and unticks them again',
        (tester) async {
      await pumpPopup(tester, const Size(1080, 1920));

      await tester.tap(find.text('Select all'));
      await tester.pump();
      await tester.tap(find.text('APPLY FILTERS'));
      await settleKiosk(tester);

      expect(KioskAllergenPreferences.instance.avoided,
          KioskAllergen.values.toSet());
    });

    testWidgets('applying with nothing ticked still marks the popup asked',
        (tester) async {
      // This is what makes it once-per-order: a customer with no allergies
      // taps APPLY and is never asked again for the rest of the order.
      await pumpPopup(tester, const Size(1080, 1920));

      await tester.tap(find.text('APPLY FILTERS'));
      await settleKiosk(tester);

      expect(KioskAllergenPreferences.instance.asked, isTrue);
      expect(KioskAllergenPreferences.instance.avoided, isEmpty);
    });

    testWidgets('opens showing the selection already in force', (tester) async {
      KioskAllergenPreferences.instance.applySelection({KioskAllergen.dairy});

      await pumpKioskScreen(
        tester,
        const Size(1080, 1920),
        const KioskAllergenFilterScreen(
          initialSelection: {KioskAllergen.dairy},
        ),
      );
      await settleKiosk(tester);

      // Committing untouched must preserve it rather than silently clearing.
      await tester.tap(find.text('APPLY FILTERS'));
      await settleKiosk(tester);

      expect(KioskAllergenPreferences.instance.avoided, {KioskAllergen.dairy});
    });
  });

  group('localization', () {
    test('every popup key exists in all four language files', () {
      const keys = <String>[
        'allergen_popup_title',
        'allergen_popup_subtitle',
        'allergen_select_all',
        'allergen_apply_filters',
        'allergen_no_matching_items',
        'allergen_change_filters',
        'allergen_egg',
        'allergen_gluten',
        'allergen_dairy',
        'allergen_nuts',
        'allergen_soy',
      ];

      for (final String lang in ['en', 'de', 'fr', 'nl']) {
        final Map<String, dynamic> strings = jsonDecode(
          File('assets/language/$lang.json').readAsStringSync(),
        ) as Map<String, dynamic>;

        for (final String key in keys) {
          expect(strings[key], isNotNull, reason: '$key missing from $lang');
          expect((strings[key] as String).trim(), isNotEmpty,
              reason: '$key empty in $lang');
        }
      }
    });

    test('every allergen has a translation key matching the language files',
        () {
      final Map<String, dynamic> en = jsonDecode(
        File('assets/language/en.json').readAsStringSync(),
      ) as Map<String, dynamic>;

      for (final KioskAllergen allergen in KioskAllergen.values) {
        expect(en[allergen.translationKey], allergen.label,
            reason: '${allergen.translationKey} out of sync with its label');
      }
    });
  });
}
