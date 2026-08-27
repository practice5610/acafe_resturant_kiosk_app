import 'package:acafe_customer/common/models/product_model.dart';

class CartModel {
  double? _price;
  double? _discountedPrice;
  List<Variation>? _variation;
  double? _discountAmount;
  int? _quantity;
  double? _taxAmount;
  List<AddOn>? _addOnIds;
  Product? _product;
  List<List<bool?>>? _variations;
  String? _instruction;
  int? _dealId;
  String? _dealTitle;
  String? _dealImage;
  double? _bundlePrice;
  List<CartModel>? _components;


  CartModel(
      double? price,
      double? discountedPrice,
      List<Variation> variation,
      double? discountAmount,
      int? quantity,
      double? taxAmount,
      List<AddOn> addOnIds,
      Product? product,
      List<List<bool?>> variations, {
      String? instruction,
      int? dealId,
      String? dealTitle,
      String? dealImage,
      double? bundlePrice,
      List<CartModel>? components,
      }) {
    _price = price;
    _discountedPrice = discountedPrice;
    _variation = variation;
    _discountAmount = discountAmount;
    _quantity = quantity;
    _taxAmount = taxAmount;
    _addOnIds = addOnIds;
    _product = product;
    _variations = variations;
    _instruction = instruction;
    _dealId = dealId;
    _dealTitle = dealTitle;
    _dealImage = dealImage;
    _bundlePrice = bundlePrice;
    _components = components;
  }

  double? get price => _price;
  double? get discountedPrice => _discountedPrice;
  List<Variation>? get variation => _variation;
  double? get discountAmount => _discountAmount;
  // ignore: unnecessary_getters_setters
  int? get quantity => _quantity;
  // ignore: unnecessary_getters_setters
  set quantity(int? qty) => _quantity = qty;
  double? get taxAmount => _taxAmount;
  List<AddOn>? get addOnIds => _addOnIds;
  Product? get product => _product;
  List<List<bool?>>? get variations => _variations;
  String? get instruction => _instruction;
  int? get dealId => _dealId;
  String? get dealTitle => _dealTitle;
  String? get dealImage => _dealImage;
  double? get bundlePrice => _bundlePrice;
  List<CartModel>? get components => _components;
  bool get isDeal => _dealId != null;

  /// One cart line for a configured promotional bundle.
  factory CartModel.deal({
    required int dealId,
    required String title,
    String? image,
    required double bundlePrice,
    required double originalPrice,
    required List<CartModel> components,
    int quantity = 1,
  }) {
    double variationExtras = 0;
    double tax = 0;
    for (final CartModel component in components) {
      final double base = component.product?.price ?? 0;
      final double full = component.price ?? 0;
      if (full > base) variationExtras += full - base;
      tax += component.taxAmount ?? 0;
    }
    return CartModel(
      originalPrice + variationExtras,
      bundlePrice + variationExtras,
      const [],
      originalPrice - bundlePrice,
      quantity,
      tax,
      const [],
      components.isNotEmpty ? components.first.product : null,
      const [],
      dealId: dealId,
      dealTitle: title,
      dealImage: image,
      bundlePrice: bundlePrice,
      components: components,
    );
  }


  CartModel.fromJson(Map<String, dynamic> json) {
    _price = json['price'].toDouble();
    _discountedPrice = json['discounted_price'].toDouble();
    if (json['variation'] != null) {
      _variation = [];
      json['variation'].forEach((v) {
        _variation!.add(Variation.fromJson(v));
      });
    }
    _discountAmount = json['discount_amount'].toDouble();
    _quantity = json['quantity'];
    _taxAmount = json['tax_amount'].toDouble();
    if (json['add_on_ids'] != null) {
      _addOnIds = [];
      json['add_on_ids'].forEach((v) {
        _addOnIds!.add(AddOn.fromJson(v));
      });
    }
    if (json['product'] != null) {
      _product = Product.fromJson(json['product']);
    }
    if (json['variations'] != null) {
      _variations = [];
      for(int index=0; index<json['variations'].length; index++) {
        _variations!.add([]);
        for(int i=0; i<json['variations'][index].length; i++) {
          _variations![index].add(json['variations'][index][i]);
        }
      }
    }
    final rawInstruction = json['instruction'];
    if (rawInstruction is String && rawInstruction.trim().isNotEmpty) {
      _instruction = rawInstruction.trim();
    }
    _dealId = json['deal_id'];
    _dealTitle = json['deal_title'];
    _dealImage = json['deal_image'];
    if (json['bundle_price'] != null) {
      _bundlePrice = json['bundle_price'].toDouble();
    }
    if (json['components'] != null) {
      _components = [];
      json['components'].forEach((v) {
        _components!.add(CartModel.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['price'] = _price;
    data['discounted_price'] = _discountedPrice;
    if (_variation != null) {
      data['variation'] = _variation!.map((v) => v.toJson()).toList();
    }
    data['discount_amount'] = _discountAmount;
    data['quantity'] = _quantity;
    data['tax_amount'] = _taxAmount;
    if (_addOnIds != null) {
      data['add_on_ids'] = _addOnIds!.map((v) => v.toJson()).toList();
    }
    if (_product != null) {
      data['product'] = _product!.toJson();
    }
    data['variations'] = _variations;
    if (_instruction != null && _instruction!.trim().isNotEmpty) {
      data['instruction'] = _instruction;
    }
    if (_dealId != null) {
      data['deal_id'] = _dealId;
      data['deal_title'] = _dealTitle;
      data['deal_image'] = _dealImage;
      data['bundle_price'] = _bundlePrice;
      if (_components != null) {
        data['components'] = _components!.map((c) => c.toJson()).toList();
      }
    }
    return data;
  }
}

class AddOn {
  int? _id;
  int? _quantity;

  AddOn({int? id, int? quantity}) {
    _id = id;
    _quantity = quantity;
  }

  int? get id => _id;
  int? get quantity => _quantity;

  AddOn.fromJson(Map<String, dynamic> json) {
    _id = json['id'];
    _quantity = json['quantity'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = _id;
    data['quantity'] = _quantity;
    return data;
  }
}
