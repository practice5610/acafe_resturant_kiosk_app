import 'dart:convert';
import 'dart:io';

import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_allergen.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_allergen_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kiosk_layout_harness.dart';

Product _product({List<ProductTag> tags = const []}) =>
    Product(name: 'Brownie', price: 5, tags: tags);

ProductTag _allergenTag(String tag) =>
    ProductTag(tag: tag, isAllergen: true, isKioskFilter: false);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadKioskTestFonts);
  setUp(() => KioskAllergenPreferences.instance.reset());
  tearDown(() => KioskAllergenPreferences.instance.reset());

  group('when the strip appears', () {
    test('a product with no allergen tags renders nothing', () {
      expect(KioskAllergenNotice.maybe(s: 1, product: _product()), isNull);
    });

    test('a product with allergen tags renders the strip', () {
      final widget = KioskAllergenNotice.maybe(
        s: 1,
        product: _product(tags: [_allergenTag('Nuts')]),
      );

      expect(widget, isA<KioskAllergenNotice>());
      expect((widget! as KioskAllergenNotice).allergens, {KioskAllergen.nuts});
    });

    testWidgets('it shows even when the customer filtered nothing',
        (tester) async {
      // The whole point of the disclosure: it is information, not a gate, so
      // it must not depend on the filter having been answered.
      expect(KioskAllergenPreferences.instance.hasSelection, isFalse);

      await pumpKioskScreen(
        tester,
        const Size(1080, 1920),
        const KioskAllergenNotice(s: 0.42, allergens: {KioskAllergen.nuts}),
      );
      await settleKiosk(tester);

      expect(find.text('CONTAINS'), findsOneWidget);
    });

    testWidgets('it shows even when the customer filtered a DIFFERENT allergen',
        (tester) async {
      KioskAllergenPreferences.instance.applySelection({KioskAllergen.soy});

      await pumpKioskScreen(
        tester,
        const Size(1080, 1920),
        const KioskAllergenNotice(s: 0.42, allergens: {KioskAllergen.nuts}),
      );
      await settleKiosk(tester);

      expect(find.text('CONTAINS'), findsOneWidget);
    });
  });

  group('the info dialog', () {
    testWidgets('tapping the strip opens it and lists every allergen',
        (tester) async {
      await pumpKioskScreen(
        tester,
        const Size(1080, 1920),
        const KioskAllergenNotice(
          s: 0.42,
          allergens: {KioskAllergen.nuts, KioskAllergen.dairy},
        ),
      );
      await settleKiosk(tester);

      await tester.tap(find.text('CONTAINS'));
      await settleKiosk(tester);

      expect(find.text('CONTAINS ALLERGENS'), findsOneWidget);
      expect(find.text('Nuts'), findsOneWidget);
      expect(find.text('Dairy'), findsOneWidget);
      expect(find.text('GOT IT'), findsOneWidget);
    });

    testWidgets('it does not change what the customer is avoiding',
        (tester) async {
      // A disclosure that quietly set a filter would remove products the
      // customer never asked to hide.
      await pumpKioskScreen(
        tester,
        const Size(1080, 1920),
        const KioskAllergenNotice(s: 0.42, allergens: {KioskAllergen.nuts}),
      );
      await settleKiosk(tester);

      await tester.tap(find.text('CONTAINS'));
      await settleKiosk(tester);
      await tester.tap(find.text('GOT IT'));
      await settleKiosk(tester);

      expect(KioskAllergenPreferences.instance.avoided, isEmpty);
      expect(KioskAllergenPreferences.instance.asked, isFalse);
      expect(find.text('CONTAINS ALLERGENS'), findsNothing);
    });

    for (final Size size in kioskTargetSizes) {
      testWidgets('lays out at ${size.width.toInt()}x${size.height.toInt()}',
          (tester) async {
        await pumpKioskScreen(
          tester,
          size,
          KioskAllergenInfoDialog(
            allergens: KioskAllergen.values.toSet(),
          ),
        );
        await settleKiosk(tester);

        expectNoOverflow(tester, size);
        expect(find.text('CONTAINS ALLERGENS'), findsOneWidget);
        expect(find.text('GOT IT'), findsOneWidget);
      });
    }
  });

  group('localization', () {
    test('every notice key exists in all four language files', () {
      const keys = <String>[
        'allergen_contains',
        'allergen_info_title',
        'allergen_info_body',
        'allergen_info_dismiss',
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
  });
}
