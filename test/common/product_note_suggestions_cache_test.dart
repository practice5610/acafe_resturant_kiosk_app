import 'dart:convert';

import 'package:acafe_customer/common/models/product_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// A product's "Quick Add" note suggestions must survive the menu cache.
///
/// The POS/kiosk menu is persisted to SharedPreferences as
/// `jsonEncode(ProductModel.toJson())` and, after any reload, rebuilt with
/// `ProductModel.fromJson(jsonDecode(...))` instead of a network fetch. If
/// `toJson` drops `note_suggestions`, the Add Note dialog's Quick Add section
/// silently disappears for every product until the cache expires.
void main() {
  Map<String, dynamic> apiProduct({dynamic noteSuggestions}) => {
        'id': 378,
        'name': 'Test product',
        'price': 44.0,
        'variations': [],
        'add_ons': [],
        'add_on_groups': [],
        'category_ids': [],
        'attributes': [],
        'choice_options': [],
        'tax': 0,
        'status': 1,
        'note_suggestions': noteSuggestions,
      };

  Product throughDiskCache(Product product) {
    final ProductModel model = ProductModel.fromJson({
      'total_size': 1,
      'limit': 10,
      'offset': 1,
      'products': [product.toJson()],
    });
    final String stored = jsonEncode(model.toJson());
    final ProductModel restored =
        ProductModel.fromJson(jsonDecode(stored) as Map<String, dynamic>);
    return restored.products!.single;
  }

  test('quick-add suggestions survive the menu disk-cache round trip', () {
    final Product fresh = Product.fromJson(apiProduct(
      noteSuggestions: ['less ice', 'more ice', 'moderate', 'hot water'],
    ));
    expect(fresh.noteSuggestions,
        ['less ice', 'more ice', 'moderate', 'hot water']);

    final Product cached = throughDiskCache(fresh);

    expect(cached.noteSuggestions,
        ['less ice', 'more ice', 'moderate', 'hot water']);
  });

  test('a product without suggestions stays empty after the round trip', () {
    final Product cached =
        throughDiskCache(Product.fromJson(apiProduct(noteSuggestions: null)));

    expect(cached.noteSuggestions, isEmpty);
  });
}
