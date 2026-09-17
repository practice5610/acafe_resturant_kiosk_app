import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_menu_image_helper.dart';
import 'package:flutter_test/flutter_test.dart';

/// Which size/add-on images get preloaded so the POS customize screen opens
/// with no image delay.
void main() {
  Map<String, dynamic> addon(int id, String? image) =>
      {'id': id, 'name': 'Add-on $id', 'price': 0.5, 'image': image};

  Product product(int id, {List<Map<String, dynamic>> addons = const []}) =>
      Product.fromJson({
        'id': id,
        'name': 'Drink $id',
        'price': 3.0,
        'variations': [
          {
            'name': 'Size',
            'type': 'single',
            'values': [
              {'label': 'Small', 'optionPrice': 0, 'image': 'small.png'},
              {'label': 'Large', 'optionPrice': 1, 'image': ''},
              {'label': 'Oat', 'optionPrice': 0, 'image': 'def.png'},
            ],
          }
        ],
        'add_on_groups': [
          {'id': 7, 'name': 'Extras', 'selection_type': 'multi', 'addons': addons}
        ],
        'translations': [],
        'category_ids': [],
        'attributes': [],
        'choice_options': [],
        'tags': [],
      });

  test('collects variation and add-on images, skipping empty and def.png', () {
    final urls = KioskMenuImageHelper.optionImageUrls(
      [
        product(1, addons: [addon(1, 'banana.png'), addon(2, null)])
      ],
      productImageBase: 'https://cdn/product',
      addonImageBase: 'https://cdn/addon',
    );
    expect(urls.variations, {'https://cdn/product/small.png'});
    expect(urls.addons, {'https://cdn/addon/banana.png'});
  });

  test('shared add-ons across a category are downloaded once', () {
    final urls = KioskMenuImageHelper.optionImageUrls(
      [
        product(1, addons: [addon(1, 'banana.png'), addon(2, 'mango.png')]),
        product(2, addons: [addon(1, 'banana.png'), addon(2, 'mango.png')]),
      ],
      productImageBase: 'https://cdn/product',
      addonImageBase: 'https://cdn/addon',
    );
    expect(urls.variations, hasLength(1));
    expect(urls.addons,
        {'https://cdn/addon/banana.png', 'https://cdn/addon/mango.png'});
  });

  test('no base URLs yet (config not loaded) means nothing to fetch', () {
    final urls = KioskMenuImageHelper.optionImageUrls(
      [
        product(1, addons: [addon(1, 'banana.png')])
      ],
      productImageBase: null,
      addonImageBase: null,
    );
    expect(urls.variations, isEmpty);
    expect(urls.addons, isEmpty);
  });
}
