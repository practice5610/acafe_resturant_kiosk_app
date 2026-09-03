import 'package:acafe_customer/common/models/product_model.dart';

class KioskDeal {
  /// A bundle of products at one price. Tappable; opens the detail sheet.
  static const String typeProductBundle = 'product_bundle';

  /// Banner-only promo: no products, no price, no tap target.
  static const String typeStaticImage = 'static_image';

  final int id;

  /// One of [typeProductBundle] / [typeStaticImage]. A payload from a backend
  /// that predates deal types has no `deal_type`, so it reads as a bundle —
  /// the only thing that existed then.
  final String dealType;

  final String title;
  final String? badgeText;
  final String? subtitle;
  final String? description;
  final String? image;
  final double bundlePrice;
  final double originalPrice;
  final double savings;
  final int savingsPercent;
  final bool available;
  final List<KioskDealItem> items;

  const KioskDeal({
    required this.id,
    this.dealType = typeProductBundle,
    required this.title,
    this.badgeText,
    this.subtitle,
    this.description,
    this.image,
    required this.bundlePrice,
    required this.originalPrice,
    required this.savings,
    required this.savingsPercent,
    required this.available,
    required this.items,
  });

  /// Banner artwork only — nothing to configure, nothing to add to a cart.
  bool get isStaticImage => dealType == typeStaticImage;

  /// One product slot per quantity, so two espressos become two configure rows.
  List<Product> get slots {
    final List<Product> out = [];
    for (final KioskDealItem item in items) {
      for (int i = 0; i < item.quantity; i++) {
        out.add(item.product);
      }
    }
    return out;
  }

  factory KioskDeal.fromJson(Map<String, dynamic> json) {
    final List<KioskDealItem> items = [];
    final rawItems = json['items'];
    if (rawItems is List) {
      for (final item in rawItems) {
        try {
          if (item is Map<String, dynamic>) {
            items.add(KioskDealItem.fromJson(item));
          } else if (item is Map) {
            items.add(KioskDealItem.fromJson(Map<String, dynamic>.from(item)));
          }
        } catch (_) {
          // Skip a bad item; the deal may still be usable with remaining slots.
        }
      }
    }
    final String rawType = '${json['deal_type'] ?? typeProductBundle}';
    return KioskDeal(
      id: int.tryParse('${json['id']}') ?? 0,
      dealType: rawType == typeStaticImage ? typeStaticImage : typeProductBundle,
      title: '${json['title'] ?? ''}',
      badgeText: json['badge_text']?.toString(),
      subtitle: json['subtitle']?.toString(),
      description: json['description']?.toString(),
      image: json['image']?.toString(),
      bundlePrice: _toDouble(json['bundle_price']),
      originalPrice: _toDouble(json['original_price']),
      savings: _toDouble(json['savings']),
      savingsPercent: int.tryParse('${json['savings_percent'] ?? 0}') ?? 0,
      available: json['available'] == true || json['available'] == 1,
      items: items,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deal_type': dealType,
      'title': title,
      'badge_text': badgeText,
      'subtitle': subtitle,
      'description': description,
      'image': image,
      'bundle_price': bundlePrice,
      'original_price': originalPrice,
      'savings': savings,
      'savings_percent': savingsPercent,
      'available': available,
      'items': items.map((i) => i.toJson()).toList(),
    };
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }
}

class KioskDealItem {
  final int quantity;
  final Product product;

  const KioskDealItem({required this.quantity, required this.product});

  factory KioskDealItem.fromJson(Map<String, dynamic> json) {
    final rawProduct = json['product'];
    if (rawProduct is! Map) {
      throw FormatException('Deal item missing product map');
    }
    return KioskDealItem(
      quantity: int.tryParse('${json['quantity'] ?? 1}') ?? 1,
      product: Product.fromJson(
        rawProduct is Map<String, dynamic>
            ? rawProduct
            : Map<String, dynamic>.from(rawProduct),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'quantity': quantity,
      'product': product.toJson(),
    };
  }
}

bool kioskProductHasModifiers(Product product) {
  return (product.variations ?? []).isNotEmpty ||
      (product.addOns ?? []).isNotEmpty ||
      product.effectiveAddOnGroups.isNotEmpty;
}
