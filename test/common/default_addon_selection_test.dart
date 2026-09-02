import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/common/providers/product_provider.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Default add-on rule, exercised on the provider alone — no widgets, so
/// no localization delegate is involved.
///
/// A default add-on comes with the product: always selected, never chargeable,
/// not deselectable. Single-choice and max apply to the NON-default remainder
/// only, so a group of three defaults plus paid extras leaves the customer
/// three defaults + at most one extra.
void main() {
  AddOns addon(int id, {bool isDefault = false, double price = 2.50}) =>
      AddOns.fromJson({
        'id': id,
        'name': 'Add-on $id',
        'price': price,
        'tax': 0,
        'is_default': isDefault,
      });

  Product productWith(List<AddOns> addOns, {String selectionType = 'multi'}) =>
      Product.fromJson({
        'id': 1,
        'name': 'Latte',
        'price': 3.0,
        'variations': [],
        'add_ons': addOns.map((a) => a.toJson()).toList(),
        'add_on_groups': [
          {
            'id': 7,
            'name': 'Extras',
            'selection_type': selectionType,
            'addons': addOns.map((a) => a.toJson()).toList(),
          }
        ],
        'translations': [],
        'category_ids': [],
        'attributes': [],
        'choice_options': [],
        'tags': [],
      });

  /// Indexes of everything currently selected.
  List<int> selected(ProductProvider p) => [
        for (int i = 0; i < p.addOnActiveList.length; i++)
          if (p.addOnActiveList[i]) i,
      ];

  group('is_default parsing', () {
    test('accepts true, 1 and "1"; anything else is not default', () {
      expect(AddOns.fromJson({'id': 1, 'is_default': true}).isDefault, isTrue);
      expect(AddOns.fromJson({'id': 1, 'is_default': 1}).isDefault, isTrue);
      expect(AddOns.fromJson({'id': 1, 'is_default': '1'}).isDefault, isTrue);
      expect(AddOns.fromJson({'id': 1, 'is_default': false}).isDefault, isFalse);
      expect(AddOns.fromJson({'id': 1, 'is_default': 0}).isDefault, isFalse);
      expect(AddOns.fromJson({'id': 1}).isDefault, isFalse);
    });

    test('a default add-on contributes nothing to a line', () {
      expect(addon(1, isDefault: true, price: 4.0).effectivePrice, 0);
      expect(addon(1, price: 4.0).effectivePrice, 4.0);
    });
  });

  group('auto-selection', () {
    test('defaults are selected on a fresh open, others are not', () {
      final product = productWith([
        addon(1, isDefault: true),
        addon(2),
        addon(3, isDefault: true),
      ]);
      final provider = ProductProvider(productRepo: null)..initData(product, null);

      expect(selected(provider), [0, 2]);
    });

    test('a saved cart line that omits a default still shows it selected', () {
      final product = productWith([addon(1, isDefault: true), addon(2)]);
      // A line saved BEFORE add-on 1 became default: it carries only add-on 2.
      final cart = CartModel(
          3.0, 3.0, [], 0, 1, 0, [AddOn(id: 2, quantity: 1)], product, []);

      final provider = ProductProvider(productRepo: null)..initData(product, cart);

      expect(selected(provider), [0, 1],
          reason: 'the default must be re-applied, not inherited from the line');
    });
  });

  group('locking', () {
    test('tapping a default is a no-op', () {
      final product = productWith([addon(1, isDefault: true), addon(2)]);
      final provider = ProductProvider(productRepo: null)..initData(product, null);

      provider.toggleAddOnInGroup(
        index: 0,
        isSingle: false,
        groupIndexes: const [0, 1],
        isRequired: false,
        defaultIndexes: const [0],
      );

      expect(provider.addOnActiveList[0], isTrue);
    });

    test('a default survives a max that its own group would otherwise fill', () {
      final product = productWith([
        addon(1, isDefault: true),
        addon(2, isDefault: true),
        addon(3),
      ]);
      final provider = ProductProvider(productRepo: null)..initData(product, null);

      // max 2 with two defaults would leave nothing selectable if defaults
      // counted toward the cap.
      provider.toggleAddOnInGroup(
        index: 2,
        isSingle: false,
        groupIndexes: const [0, 1, 2],
        isRequired: false,
        maxSelect: 2,
        defaultIndexes: const [0, 1],
      );

      expect(selected(provider), [0, 1, 2]);
    });
  });

  group('single-choice group with defaults', () {
    test('3 defaults + 1 extra = 4 selected, and picking another swaps it', () {
      final product = productWith([
        addon(1, isDefault: true),
        addon(2, isDefault: true),
        addon(3, isDefault: true),
        addon(4),
        addon(5),
      ], selectionType: 'single');
      final provider = ProductProvider(productRepo: null)..initData(product, null);
      const groupIndexes = [0, 1, 2, 3, 4];
      const defaultIndexes = [0, 1, 2];

      expect(selected(provider), [0, 1, 2], reason: 'defaults only, to start');

      provider.toggleAddOnInGroup(
        index: 3,
        isSingle: true,
        groupIndexes: groupIndexes,
        isRequired: false,
        defaultIndexes: defaultIndexes,
      );
      expect(selected(provider), [0, 1, 2, 3],
          reason: '3 defaults + 1 extra = 4, never 5');

      // The second extra replaces the first — single choice, among the
      // remainder — and the three defaults are untouched.
      provider.toggleAddOnInGroup(
        index: 4,
        isSingle: true,
        groupIndexes: groupIndexes,
        isRequired: false,
        defaultIndexes: defaultIndexes,
      );
      expect(selected(provider), [0, 1, 2, 4]);
    });

    test('the one extra can be cleared, leaving the defaults on', () {
      final product = productWith([
        addon(1, isDefault: true),
        addon(2),
      ], selectionType: 'single');
      final provider = ProductProvider(productRepo: null)..initData(product, null);

      provider.toggleAddOnInGroup(
        index: 1,
        isSingle: true,
        groupIndexes: const [0, 1],
        isRequired: false,
        defaultIndexes: const [0],
      );
      expect(selected(provider), [0, 1]);

      provider.toggleAddOnInGroup(
        index: 1,
        isSingle: true,
        groupIndexes: const [0, 1],
        isRequired: false,
        defaultIndexes: const [0],
      );
      expect(selected(provider), [0],
          reason: 'deselecting the extra must not take the default with it');
    });
  });
}
