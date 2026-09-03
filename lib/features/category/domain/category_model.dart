
class CategoryData {
  int? totalSize;
  int? limit;
  int? offset;
  List<CategoryModel>? categories;

  CategoryData(
      {int? totalSize, int? limit, int? offset, List<CategoryModel>? products, double? productMaxPrice}) {
    totalSize = totalSize;
    limit = limit;
    offset = offset;
    products = products;
    productMaxPrice = productMaxPrice;
  }

  CategoryData.fromJson(Map<String, dynamic> json) {
    totalSize = int.tryParse('${json['total_size']}');
    limit = int.tryParse('${json['limit']}');
    offset = int.tryParse('${json['offset']}');
    if (json['categories'] != null) {
      categories = [];
      json['categories'].forEach((v) {
        categories!.add(CategoryModel.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['total_size'] = totalSize;
    data['limit'] = limit;
    data['limit'] = limit;
    if (categories!= null) {
      data['categories'] = categories!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class CategoryModel {
  int? _id;
  String? _name;
  int? _parentId;
  int? _position;
  List<CategoryModel>? _childes;
  int? _status;
  String? _createdAt;
  String? _updatedAt;
  String? _image;
  String? _bannerImage;

  CategoryModel(
      {int? id,
        String? name,
        int? parentId,
        int? position,
        int? status,
        String? createdAt,
        String? updatedAt,
        String? image,
        String? bannerImage,
      }) {
    _id = id;
    _name = name;
    _parentId = parentId;
    _position = position;
    _status = status;
    _createdAt = createdAt;
    _updatedAt = updatedAt;
    _image = image;
    _bannerImage = bannerImage;
  }

  int? get id => _id;
  String? get name => _name;
  int? get parentId => _parentId;
  int? get position => _position;
  int? get status => _status;
  String? get createdAt => _createdAt;
  String? get updatedAt => _updatedAt;
  String? get image => _image;
  String? get bannerImage => _bannerImage;

  /// Sub-categories, as returned by `Category::with('childes')`.
  ///
  /// The kiosk endpoint has always sent these; the model simply dropped them
  /// on parse. POS renders them as the filter pills above the product grid.
  /// Additive: nothing that existed before reads this, so an older cached
  /// payload without the key just yields an empty list.
  List<CategoryModel> get childes => _childes ?? const [];

  CategoryModel.fromJson(Map<String, dynamic> json) {
    _id = json['id'] ?? 0;
    _name = json['name'] ?? '';
    _parentId = json['parent_id'] ?? 0;
    _position = json['position'] ?? 0;
    _status = json['status'] ?? 0;
    _createdAt = json['created_at'];
    _updatedAt = json['updated_at'];
    _image = json['image'] ?? '';
    _bannerImage = json['banner_image'] ?? '';
    final dynamic rawChildes = json['childes'];
    if (rawChildes is List) {
      _childes = rawChildes
          .whereType<Map<String, dynamic>>()
          .map(CategoryModel.fromJson)
          .toList();
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = _id;
    data['name'] = _name;
    data['parent_id'] = _parentId;
    data['position'] = _position;
    data['status'] = _status;
    data['created_at'] = _createdAt;
    data['updated_at'] = _updatedAt;
    data['image'] = _image;
    data['banner_image'] = _bannerImage;
    if (_childes != null) {
      data['childes'] = _childes!.map((c) => c.toJson()).toList();
    }
    return data;
  }
}
