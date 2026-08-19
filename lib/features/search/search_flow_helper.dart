import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_navigation_helper.dart';

/// Shared helpers for kiosk search navigation and query parsing.
class SearchFlowHelper {
  SearchFlowHelper._();

  /// Pops the nearest route (modal sheet first, then page). Falls back to menu
  /// when there is nothing left to pop — avoids silent no-ops on deep links.
  static void navigateBack(BuildContext context) {
    KioskNavigationHelper.popOrNavigate(context);
  }

  /// Decode `?text=` from the search-result route (JSON-encoded string).
  static String decodeSearchQuery(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final decoded = jsonDecode(raw);
      if (decoded is String) return decoded;
    } catch (_) {
      // Fall through — legacy/plain query strings.
    }
    return Uri.decodeComponent(raw);
  }

  /// Normalise route slug back to a human-readable query.
  static String queryFromRouteSlug(String? slug) =>
      (slug ?? '').replaceAll('-', ' ').trim();

  static bool hasActiveFilters({
    required int? selectedSortByIndex,
    required int? selectedPriceIndex,
    required bool halalTagStatus,
    required List<int> selectedCategoryIds,
  }) {
    return selectedSortByIndex != null ||
        selectedPriceIndex != null ||
        halalTagStatus ||
        selectedCategoryIds.isNotEmpty;
  }
}
