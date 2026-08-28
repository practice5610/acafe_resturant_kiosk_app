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

  /// Field-by-field clone with a different quantity.
  ///
  /// Needed so a qty-2 line can yield a qty-1 combo component without
  /// mutating the leftover unit that stays in the cart. Do not round-trip
  /// through JSON: [CartModel.fromJson] calls `.toDouble()` on nullable
  /// fields and will throw.
  CartModel copyWithQuantity(int quantity) {
    return CartModel(
      _price,
      _discountedPrice,
      _variation == null ? <Variation>[] : List<Variation>.from(_variation!),
      _discountAmount,
      quantity,
      _taxAmount,
      _addOnIds == null
          ? <AddOn>[]
          : _addOnIds!
              .map((a) => AddOn(id: a.id, quantity: a.quantity))
              .toList(),
      _product,
      _variations == null
          ? <List<bool?>>[]
          : _variations!.map((row) => List<bool?>.from(row)).toList(),
      instruction: _instruction,
      dealId: _dealId,
      dealTitle: _dealTitle,
      dealImage: _dealImage,
      bundlePrice: _bundlePrice,
      components: _components
          ?.map((c) => c.copyWithQuantity(c.quantity ?? 1))
          .toList(),
    );
  }

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
    _price = _cartReadDouble(json['price']);
    _discountedPrice = _cartReadDouble(json['discounted_price']);
    if (json['variation'] != null) {
      _variation = [];
      json['variation'].forEach((v) {
        _variation!.add(Variation.fromJson(v));
      });
    }
    _discountAmount = _cartReadDouble(json['discount_amount']);
    _quantity = json['quantity'] is int
        ? json['quantity'] as int
        : int.tryParse('${json['quantity']}') ?? 1;
    _taxAmount = _cartReadDouble(json['tax_amount']);
    if (json['add_on_ids'] != null) {
      _addOnIds = [];
      json['add_on_ids'].forEach((v) {
        _addOnIds!.add(AddOn.fromJson(v));
      });
    }
    final rawProduct = json['product'];
    if (rawProduct is Map<String, dynamic>) {
      try {
        _product = Product.fromJson(rawProduct);
      } catch (_) {
        _product = null;
      }
    } else if (rawProduct is Map) {
      try {
        _product = Product.fromJson(Map<String, dynamic>.from(rawProduct));
      } catch (_) {
        _product = null;
      }
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
    _dealId = json['deal_id'] is int
        ? json['deal_id'] as int
        : int.tryParse('${json['deal_id']}');
    _dealTitle = json['deal_title']?.toString();
    _dealImage = json['deal_image']?.toString();
    _bundlePrice = _cartReadDouble(json['bundle_price']);
    if (json['components'] != null) {
      _components = [];
      json['components'].forEach((v) {
        try {
          if (v is Map<String, dynamic>) {
            _components!.add(CartModel.fromJson(v));
          } else if (v is Map) {
            _components!.add(CartModel.fromJson(Map<String, dynamic>.from(v)));
          }
        } catch (_) {
          // Skip a corrupt deal component rather than failing cart load.
        }
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
    _id = json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}');
    _quantity = json['quantity'] is int
        ? json['quantity'] as int
        : int.tryParse('${json['quantity']}') ?? 1;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = _id;
    data['quantity'] = _quantity;
    return data;
  }
}

double? _cartReadDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse('$value');
}

