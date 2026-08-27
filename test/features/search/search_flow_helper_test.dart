import 'package:acafe_customer/features/search/search_flow_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SearchFlowHelper.decodeSearchQuery', () {
    test('decodes JSON-encoded query text', () {
      expect(
        SearchFlowHelper.decodeSearchQuery('"A/Cafe Coffee Mug"'),
        'A/Cafe Coffee Mug',
      );
    });

    test('returns empty string for null or empty input', () {
      expect(SearchFlowHelper.decodeSearchQuery(null), '');
      expect(SearchFlowHelper.decodeSearchQuery(''), '');
    });

    test('falls back to URI decoding for plain strings', () {
      expect(
        SearchFlowHelper.decodeSearchQuery('hello%20world'),
        'hello world',
      );
    });
  });

  group('SearchFlowHelper.queryFromRouteSlug', () {
    test('replaces hyphens with spaces', () {
      expect(
        SearchFlowHelper.queryFromRouteSlug('A/Cafe-Coffee-Mug'),
        'A/Cafe Coffee Mug',
      );
    });
  });

  group('SearchFlowHelper.hasActiveFilters', () {
    test('is false when nothing selected', () {
      expect(
        SearchFlowHelper.hasActiveFilters(
          selectedSortByIndex: null,
          selectedPriceIndex: null,
          halalTagStatus: false,
          selectedCategoryIds: [],
        ),
        isFalse,
      );
    });

    test('is true when any filter is active', () {
      expect(
        SearchFlowHelper.hasActiveFilters(
          selectedSortByIndex: 0,
          selectedPriceIndex: null,
          halalTagStatus: false,
          selectedCategoryIds: [],
        ),
        isTrue,
      );

      expect(
        SearchFlowHelper.hasActiveFilters(
          selectedSortByIndex: null,
          selectedPriceIndex: null,
          halalTagStatus: false,
          selectedCategoryIds: [1],
        ),
        isTrue,
      );
    });
  });
}
