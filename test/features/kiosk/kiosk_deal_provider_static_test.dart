import 'dart:convert';

import 'package:acafe_customer/features/kiosk/domain/kiosk_deal.dart';
import 'package:flutter_test/flutter_test.dart';

/// The provider's parse filter, mirrored here so the rule can be tested without
/// standing up Dio + SharedPreferences. Kept identical to
/// KioskDealProvider._parseList's skip condition.
List<KioskDeal> parseDeals(String rawJson) {
  final decoded = jsonDecode(rawJson);
  final raw = decoded is Map ? decoded['deals'] : decoded;
  if (raw is! List) return [];
  final out = <KioskDeal>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final deal = KioskDeal.fromJson(Map<String, dynamic>.from(item));
    if (!deal.isStaticImage && deal.items.isEmpty) continue;
    out.add(deal);
  }
  return out;
}

void main() {
  group('deal list parsing', () {
    test('a static image survives the zero-items filter', () {
      // The exact payload the backend serves for a banner-only promo.
      const String body = '''
      {"deals":[{"id":106,"deal_type":"static_image","title":"statc Image",
      "badge_text":null,"subtitle":null,"description":"statc Image",
      "image":"2026-09-03-abc.png","available":true,"items":[]}]}''';

      final deals = parseDeals(body);
      expect(deals, hasLength(1),
          reason: 'a static image has no items by design and must not be '
              'dropped by the bundle-only guard');
      expect(deals.single.isStaticImage, isTrue);
      expect(deals.single.image, '2026-09-03-abc.png');
    });

    test('a product bundle with no items is still dropped', () {
      const String body =
          '{"deals":[{"id":1,"deal_type":"product_bundle","title":"Broken",'
          '"bundle_price":5,"available":true,"items":[]}]}';
      expect(parseDeals(body), isEmpty);
    });

    test('a legacy payload with no deal_type and no items is still dropped', () {
      const String body =
          '{"deals":[{"id":2,"title":"Legacy","bundle_price":5,"items":[]}]}';
      expect(parseDeals(body), isEmpty);
    });
  });
}
