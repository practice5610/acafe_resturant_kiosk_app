import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_allergen.dart';
import 'package:flutter_test/flutter_test.dart';

/// Allergen filter domain (Figma POS node 1385:15054).
///
/// The stakes here are asymmetric: a product that wrongly SURVIVES the filter
/// is handed to someone who told the kiosk they cannot eat it, so the tag
/// resolution tests lean on the spellings a back office will actually type.
Product _product(String name, {List<ProductTag> tags = const []}) =>
    Product(name: name, tags: tags);

ProductTag _allergenTag(String tag) => ProductTag(
      tag: tag,
      isAllergen: true,
      isKioskFilter: false,
    );

ProductTag _pillTag(String tag) => ProductTag(
      tag: tag,
      isAllergen: false,
      isKioskFilter: true,
    );

void main() {
  setUp(() => KioskAllergenPreferences.instance.reset());

  group('kioskAllergenForTag', () {
    test('resolves the canonical names', () {
      expect(kioskAllergenForTag('Egg'), KioskAllergen.egg);
      expect(kioskAllergenForTag('Gluten'), KioskAllergen.gluten);
      expect(kioskAllergenForTag('Dairy'), KioskAllergen.dairy);
      expect(kioskAllergenForTag('Nuts'), KioskAllergen.nuts);
      expect(kioskAllergenForTag('Soy'), KioskAllergen.soy);
    });

    test('resolves the spellings a back office actually types', () {
      // Case, plurals, and the separator zoo — a tag typed "TREE-NUTS" has to
      // filter, not silently do nothing.
      expect(kioskAllergenForTag('eggs'), KioskAllergen.egg);
      expect(kioskAllergenForTag('WHEAT'), KioskAllergen.gluten);
      expect(kioskAllergenForTag('  Milk  '), KioskAllergen.dairy);
      expect(kioskAllergenForTag('Lactose'), KioskAllergen.dairy);
      expect(kioskAllergenForTag('Peanuts'), KioskAllergen.nuts);
      expect(kioskAllergenForTag('TREE-NUTS'), KioskAllergen.nuts);
      expect(kioskAllergenForTag('tree_nuts'), KioskAllergen.nuts);
      expect(kioskAllergenForTag('Soya'), KioskAllergen.soy);
    });

    test('leaves ordinary merchandising tags alone', () {
      expect(kioskAllergenForTag('Popular'), isNull);
      expect(kioskAllergenForTag('Ceremonial'), isNull);
      expect(kioskAllergenForTag(''), isNull);
    });
  });

  group('kioskProductAllergens', () {
    test('collects every allergen tag on a product', () {
      final product = _product('Brownie', tags: [
        _allergenTag('Nuts'),
        _allergenTag('Dairy'),
        _pillTag('Popular'),
      ]);

      expect(kioskProductAllergens(product),
          {KioskAllergen.nuts, KioskAllergen.dairy});
    });

    test('a merchandising pill never counts as an allergen', () {
      // The one that would be dangerous in reverse: a "Nuts" CATEGORY pill must
      // not hide every product in that category from someone avoiding nuts.
      final product = _product('Nut Selection', tags: [_pillTag('Nuts')]);

      expect(kioskProductAllergens(product), isEmpty);
    });

    test('honours an allergen tag even when is_allergen is missing', () {
      // A backend that has not run the migration yet sends no `is_allergen`,
      // which parses to false. The name fallback keeps the filter working.
      final product = _product('Cookie', tags: [ProductTag(tag: 'Nuts')]);

      expect(kioskProductAllergens(product), {KioskAllergen.nuts});
    });

    test('a product with no tags declares nothing', () {
      expect(kioskProductAllergens(_product('Espresso')), isEmpty);
    });
  });

  group('filterKioskProductsByAllergens', () {
    final brownie = _product('Brownie', tags: [_allergenTag('Nuts')]);
    final latte = _product('Latte', tags: [_allergenTag('Dairy')]);
    final espresso = _product('Espresso');

    test('returns the list untouched when nothing is selected', () {
      final products = [brownie, latte, espresso];

      expect(
        filterKioskProductsByAllergens(
            products: products, avoided: const <KioskAllergen>{}),
        same(products),
      );
    });

    test('drops products containing an avoided allergen', () {
      final result = filterKioskProductsByAllergens(
        products: [brownie, latte, espresso],
        avoided: {KioskAllergen.nuts},
      );

      expect(result.map((p) => p.name), ['Latte', 'Espresso']);
    });

    test('drops a product matching any one of several avoided allergens', () {
      final result = filterKioskProductsByAllergens(
        products: [brownie, latte, espresso],
        avoided: {KioskAllergen.nuts, KioskAllergen.dairy},
      );

      expect(result.map((p) => p.name), ['Espresso']);
    });

    test('a product declaring several allergens is dropped by any of them', () {
      final cake = _product('Cake',
          tags: [_allergenTag('Egg'), _allergenTag('Gluten')]);

      expect(
        filterKioskProductsByAllergens(
            products: [cake], avoided: {KioskAllergen.gluten}),
        isEmpty,
      );
    });
  });

  group('KioskAllergenPreferences', () {
    test('starts unasked with nothing selected', () {
      final prefs = KioskAllergenPreferences.instance;

      expect(prefs.asked, isFalse);
      expect(prefs.avoided, isEmpty);
      expect(prefs.hasSelection, isFalse);
    });

    test('applying a selection marks the popup asked and notifies', () {
      final prefs = KioskAllergenPreferences.instance;
      int notifications = 0;
      void listener() => notifications++;
      prefs.addListener(listener);
      addTearDown(() => prefs.removeListener(listener));

      prefs.applySelection({KioskAllergen.nuts});

      expect(prefs.asked, isTrue);
      expect(prefs.avoided, {KioskAllergen.nuts});
      expect(notifications, 1);
    });

    test('re-applying the same selection does not notify', () {
      // The grid rebuilds on every notification; a customer reopening the
      // popup and tapping APPLY unchanged should not churn it.
      final prefs = KioskAllergenPreferences.instance;
      prefs.applySelection({KioskAllergen.nuts});

      int notifications = 0;
      void listener() => notifications++;
      prefs.addListener(listener);
      addTearDown(() => prefs.removeListener(listener));

      prefs.applySelection({KioskAllergen.nuts});

      expect(notifications, 0);
    });

    test('dismissing marks asked without selecting anything', () {
      final prefs = KioskAllergenPreferences.instance;

      prefs.markAsked();

      expect(prefs.asked, isTrue);
      expect(prefs.avoided, isEmpty);
    });

    test('avoided is not mutable from outside', () {
      final prefs = KioskAllergenPreferences.instance;
      prefs.applySelection({KioskAllergen.nuts});

      expect(() => prefs.avoided.add(KioskAllergen.soy), throwsUnsupportedError);
    });

    test('reset clears the answer for the next customer', () {
      // The failure this guards is invisible to the person it hurts: a
      // customer who declared nothing silently getting the last customer's
      // filter, and never seeing the products that were removed.
      final prefs = KioskAllergenPreferences.instance;
      prefs.applySelection({KioskAllergen.nuts, KioskAllergen.soy});

      prefs.reset();

      expect(prefs.asked, isFalse);
      expect(prefs.avoided, isEmpty);
    });
  });
}
