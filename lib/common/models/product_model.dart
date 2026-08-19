class ProductModel {
  int? totalSize;
  int? limit;
  int? offset;
  double? productMaxPrice;
  List<Product>? products;

  ProductModel(
      {int? totalSize, int? limit, int? offset, List<Product>? products, double? productMaxPrice}) {
    totalSize = totalSize;
    limit = limit;
    offset = offset;
    products = products;
    productMaxPrice = productMaxPrice;
  }

  ProductModel.fromJson(Map<String, dynamic> json) {
    totalSize = int.tryParse('${json['total_size']}');
    limit = int.tryParse('${json['limit']}');
    offset = int.tryParse('${json['offset']}');

    if(json.containsKey('product_max_price')) {
      productMaxPrice = double.tryParse('${json['product_max_price']}');

    }

    if (json['products'] != null) {
      products = [];
      json['products'].forEach((v) {
        products!.add(Product.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['total_size'] = totalSize;
    data['limit'] = limit;
    data['limit'] = limit;
    data['product_max_price'] = productMaxPrice;
    if (products != null) {
      data['products'] = products!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Product {
  int? _id;
  String? _name;
  String? _description;
  String? _image;
  double? _price;
  List<Variation>? _variations;
  List<AddOns>? _addOns;
  List<AddOnGroup>? _addOnGroups;
  double? _tax;
  int? _status;
  String? _createdAt;
  String? _updatedAt;
  List<String>? _attributes;
  List<CategoryId>? _categoryIds;
  List<ChoiceOption>? _choiceOptions;
  double? _discount;
  String? _discountType;
  String? _taxType;
  int? _setMenu;
  BranchProduct? _branchProduct;
  double? _mainPrice;
  bool? _isChanged;
  String? _changeReason;

  Product(
      {int? id,
        String? name,
        String? description,
        String? image,
        double? price,
        List<Variation>? variations,
        List<AddOns>? addOns,
        List<AddOnGroup>? addOnGroups,
        double? tax,
        int? status,
        String? createdAt,
        String? updatedAt,
        List<String>? attributes,
        List<CategoryId>? categoryIds,
        List<ChoiceOption>? choiceOptions,
        double? discount,
        String? discountType,
        String? taxType,
        int? setMenu,
        BranchProduct? branchProduct,
        double? mainPrice,
        bool? isChanged,
        String? changeReason,
        int? halalStatus,
      }) {
    _id = id;
    _name = name;
    _description = description;
    _image = image;
    _price = price;
    _variations = variations;
    _addOns = addOns;
    _addOnGroups = addOnGroups;
    _tax = tax;
    _status = status;
    _createdAt = createdAt;
    _updatedAt = updatedAt;
    _attributes = attributes;
    _categoryIds = categoryIds;
    _choiceOptions = choiceOptions;
    _discount = discount;
    _discountType = discountType;
    _taxType = taxType;
    _setMenu = setMenu;
    _branchProduct = branchProduct;
    _mainPrice = mainPrice;
    _isChanged = isChanged;
    _changeReason = changeReason;
  }

  int? get id => _id;
  String? get name => _name;
  String? get description => _description;
  String? get image => _image;
  double? get price => _price;
  List<Variation>? get variations => _variations;
  List<AddOns>? get addOns => _addOns;
  List<AddOnGroup>? get addOnGroups => _addOnGroups;
  List<AddOnGroup> get effectiveAddOnGroups {
    if (_addOnGroups != null && _addOnGroups!.isNotEmpty) {
      return _addOnGroups!;
    }
    if (_addOns != null && _addOns!.isNotEmpty) {
      return [
        AddOnGroup(
          selectionType: 'multi',
          isRequired: false,
          min: 0,
          addons: _addOns!,
        ),
      ];
    }
    return [];
  }

  int? indexOfAddOn(int? id) {
    if (id == null || _addOns == null) {
      return null;
    }
    for (int i = 0; i < _addOns!.length; i++) {
      if (_addOns![i].id == id) {
        return i;
      }
    }
    return null;
  }

  double? get tax => _tax;
  int? get status => _status;
  String? get createdAt => _createdAt;
  String? get updatedAt => _updatedAt;
  List<String>? get attributes => _attributes;
  List<CategoryId>? get categoryIds => _categoryIds;
  // List<ChoiceOption> get choiceOptions => _choiceOptions;
  double? get discount => _discount;
  String? get discountType => _discountType;
  String? get taxType => _taxType;
  int? get setMenu => _setMenu;
  String? productType;
  BranchProduct? get branchProduct => _branchProduct;
  bool? get isChanged => _isChanged;
  String? get changeReason => _changeReason;

  Product.fromJson(Map<String, dynamic> json) {
    _id = json['id'];
    _name = json['name'];
    _description = json['description'];
    _image = json['image'];
    _price = json['price'].toDouble();
    if (json['variations'] != null) {
      _variations = [];
      json['variations'].forEach((v) {
        if(!v.containsKey('price')){
          _variations!.add(Variation.fromJson(v));
        }

      });
    }
    if (json['add_ons'] != null) {
      _addOns = [];
     try{
       json['add_ons'].forEach((v) {
         _addOns!.add(AddOns.fromJson(v));
       });

     }catch(e){
       _addOns = [];
     }
    }
    if (json['add_on_groups'] != null) {
      _addOnGroups = [];
      try {
        json['add_on_groups'].forEach((v) {
          _addOnGroups!.add(AddOnGroup.fromJson(v));
        });
      } catch (e) {
        _addOnGroups = [];
      }
    }
    _tax = json['tax'].toDouble();
    _tax = json['tax'].toDouble();
    _status = json['status'] ?? 0;
    _createdAt = json['created_at'];
    _updatedAt = json['updated_at'];
    _attributes = json['attributes'].cast<String>();
    if (json['category_ids'] != null) {
      _categoryIds = [];
      json['category_ids'].forEach((v) {
        _categoryIds!.add(CategoryId.fromJson(v));
      });
    }
    if (json['choice_options'] != null) {
      _choiceOptions = [];
      json['choice_options'].forEach((v) {
        _choiceOptions!.add(ChoiceOption.fromJson(v));
      });
    }
    _discount = json['discount'].toDouble();
    _discountType = json['discount_type'];
    _taxType = json['tax_type'];
    _setMenu = json['set_menu'];
    productType=  json["product_type"];
    if(json['branch_product'] != null) {
      _branchProduct =  BranchProduct.fromJson(json['branch_product']);
      _price = _branchProduct!.price;
      _discount = _branchProduct!.discount;
      _discountType = _branchProduct!.discountType;

    }else{
      _branchProduct = null;
    }
    _mainPrice = double.tryParse('${json['price']}');

    if(json.containsKey('is_changed')){
      _isChanged = '${json['is_changed']}'.contains('1');
    }

    if(json.containsKey('change_reason')){
      _changeReason = json['change_reason'];
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = _id;
    data['name'] = _name;
    data['description'] = _description;
    data['image'] = _image;
    data['price'] = _price;
    if (_variations != null) {
      data['variations'] = _variations!.map((v) => v.toJson()).toList();
    }


    if (_addOns != null) {
      data['add_ons'] = _addOns!.map((v) => v.toJson()).toList();
    }
    if (_addOnGroups != null) {
      data['add_on_groups'] = _addOnGroups!.map((v) => v.toJson()).toList();
    }
    data['tax'] = _tax;
    data['status'] = _status;
    data['created_at'] = _createdAt;
    data['updated_at'] = _updatedAt;
    data['attributes'] = _attributes;
    if (_categoryIds != null) {
      data['category_ids'] = _categoryIds!.map((v) => v.toJson()).toList();
    }
    if (_choiceOptions != null) {
      data['choice_options'] =
          _choiceOptions!.map((v) => v.toJson()).toList();
    }
    data['discount'] = _discount;
    data['discount_type'] = _discountType;
    data['tax_type'] = _taxType;
    data['set_menu'] = _setMenu;
    data['main_price'] = _mainPrice;
    data['branch_product'] = _branchProduct;
    return data;
  }
}
class BranchProduct {
  int? id;
  int? productId;
  int? branchId;
  double? price;
  bool? isAvailable;
  List<Variation>? variations;
  double? discount;
  String? discountType;
  int? stock;
  int? soldQuantity;
  String? stockType;
  int? halalStatus;


  BranchProduct({
    this.id,
    this.productId,
    this.branchId,
    this.isAvailable,
    this.variations,
    this.price,
    this.discount,
    this.discountType,
    this.stockType,
    this.soldQuantity,
    this.stock,
    this.halalStatus
  });

  BranchProduct.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    productId = json['product_id'];
    branchId = json['branch_id'];
    price = double.tryParse('${json['price']}');
    isAvailable = ('${json['is_available']}' == '1') || '${json['is_available']}' == 'true';
    if (json['variations'] != null) {
      variations = [];
      json['variations'].forEach((v) {
        if(!v.containsKey('price')){
          variations!.add(Variation.fromJson(v));
        }

      });
    }
    discount = json['discount'].toDouble();
    discountType = json['discount_type'];
    stockType = json['stock_type'];
    stock = json['stock'];
    soldQuantity = json['sold_quantity'];
    halalStatus = int.tryParse('${json['halal_status']}');
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['product_id'] = productId;
    data['branch_id'] = branchId;
    data['is_available'] = isAvailable;
    data['variations'] = variations;
    data['price'] = price;
    data['discount'] = discount;
    data['discount_type'] = discountType;
    data['stock'] = stock;
    data['stock_type'] = stockType;
    data['sold_quantity'] = soldQuantity;
    return data;
  }
}
class VariationValue {
  String? level;
  double? optionPrice;
  String? image;

  VariationValue({this.level, this.optionPrice, this.image});

  VariationValue.fromJson(Map<String, dynamic> json) {
    level = json['label'];
    optionPrice = double.parse(json['optionPrice'].toString());
    image = json['image'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['label'] = level;
    data['optionPrice'] = optionPrice;
    if (image != null && image!.isNotEmpty) {
      data['image'] = image;
    }
    return data;
  }
}



class Variation {
  String? name;
  int? min;
  int? max;
  bool? isRequired;
  bool? isMultiSelect;
  List<VariationValue>? variationValues;


  Variation({
    this.name, this.min, this.max,
    this.isRequired, this.variationValues,
    this.isMultiSelect,
  });

  Variation.fromJson(Map<String, dynamic> json) {
    name = json['name'];
    isMultiSelect = '${json['type']}' == 'multi';
    min =  isMultiSelect! ? int.parse(json['min'].toString()) : 0;
    max = isMultiSelect! ? int.parse(json['max'].toString()) : 0;
    isRequired = '${json['required']}' == 'on';
    if (json['values'] != null) {
      variationValues = [];
      json['values'].forEach((v) {
        variationValues!.add(VariationValue.fromJson(v));
      });
    }

  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['name'] = name;
    data['type'] = isMultiSelect! ? 'multi' : 'single';
    data['min'] = min;
    data['max'] = max;
    data['required'] = isRequired! ? 'on' : 'off';
    if (variationValues != null) {
      data['values'] = variationValues!.map((v) => v.toJson()).toList();
    }

    return data;
  }
}

class AddOns {
  int? _id;
  String? _name;
  double? _price;
  String? _createdAt;
  String? _updatedAt;
  double? _tax; // percentage
  String? _image;

  AddOns({int? id, String? name, double? price, String? createdAt, String? updatedAt, double? tax, String? image}) {
    _id = id;
    _name = name;
    _price = price;
    _createdAt = createdAt;
    _updatedAt = updatedAt;
    _tax = tax;
    _image = image;
  }

  int? get id => _id;
  String? get name => _name;
  double? get price => _price;
  String? get createdAt => _createdAt;
  String? get updatedAt => _updatedAt;
  double? get tax => _tax;
  String? get image => _image;
  bool get hasImage => _image != null && _image!.isNotEmpty && _image != 'def.png';

  AddOns.fromJson(Map<String, dynamic> json) {
    _id = json['id'];
    _name = json['name'];
    _price = json['price'].toDouble();
    _createdAt = json['created_at'];
    _updatedAt = json['updated_at'];
    _tax = double.tryParse('${json['tax']}');
    _image = json['image'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = _id;
    data['name'] = _name;
    data['price'] = _price;
    data['created_at'] = _createdAt;
    data['updated_at'] = _updatedAt;
    data['tax'] = _tax;
    data['image'] = _image;
    return data;
  }
}

class AddOnGroup {
  int? id;
  String? name;
  String? selectionType;
  bool isRequired;
  int min;
  int? max;
  List<AddOns> addons;

  AddOnGroup({
    this.id,
    this.name,
    this.selectionType = 'multi',
    this.isRequired = false,
    this.min = 0,
    this.max,
    this.addons = const [],
  });

  bool get isSingle => selectionType == 'single';

  AddOnGroup.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        name = json['name'],
        selectionType = json['selection_type'] ?? 'multi',
        isRequired = json['is_required'] == true || '${json['is_required']}' == '1',
        min = int.tryParse('${json['min']}') ?? 0,
        max = json['max'] == null ? null : int.tryParse('${json['max']}'),
        addons = [] {
    if (json['addons'] != null) {
      json['addons'].forEach((v) {
        addons.add(AddOns.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'selection_type': selectionType,
      'is_required': isRequired,
      'min': min,
      'max': max,
      'addons': addons.map((v) => v.toJson()).toList(),
    };
  }
}

class CategoryId {
  String? _id;

  CategoryId({String? id}) {
    _id = id;
  }

  String? get id => _id;

  CategoryId.fromJson(Map<String, dynamic> json) {
    _id = json['id'].toString();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = _id;
    return data;
  }
}

class ChoiceOption {
  String? _name;
  String? _title;
  List<String>? _options;

  ChoiceOption({String? name, String? title, List<String>? options}) {
    _name = name;
    _title = title;
    _options = options;
  }

  String? get name => _name;
  String? get title => _title;
  List<String>? get options => _options;

  ChoiceOption.fromJson(Map<String, dynamic> json) {
    _name = json['name'];
    _title = json['title'];
    _options = json['options'].cast<String>();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['name'] = _name;
    data['title'] = _title;
    data['options'] = _options;
    return data;
  }
}



