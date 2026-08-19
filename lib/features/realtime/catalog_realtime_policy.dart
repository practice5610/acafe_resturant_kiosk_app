import 'package:acafe_customer/features/realtime/catalog_event.dart';

enum CatalogClientAction { ignore, reload, remove, fetch }

/// Pure rules for product socket events. Transport and providers stay out.
class CatalogRealtimePolicy {
  static CatalogClientAction decide({
    required CatalogEvent event,
    required int menuRevision,
    required bool duplicateEventId,
  }) {
    if (duplicateEventId) {
      return CatalogClientAction.ignore;
    }
    if (event.revision > 0 &&
        menuRevision > 0 &&
        event.revision > menuRevision + 1) {
      return CatalogClientAction.reload;
    }
    if (event.isRefresh) {
      return CatalogClientAction.reload;
    }
    if (event.isDelete || event.productId <= 0) {
      return CatalogClientAction.remove;
    }
    return CatalogClientAction.fetch;
  }

  static bool treatFetchedProductAsRemoved({
    required CatalogEvent event,
    required int? statusCode,
    required bool notFound,
    required int? productStatus,
    required bool? isAvailable,
  }) {
    if (statusCode == 404 || notFound) {
      return true;
    }
    if (statusCode != 200) {
      return false;
    }
    return event.isAvailability &&
        (productStatus != 1 || isAvailable == false);
  }

  static bool syncNeedsReload({
    required int? statusCode,
    required Map? data,
  }) {
    if (statusCode != 200 || data == null) {
      return true;
    }
    return data['full_reload'] == true;
  }

  static int syncRevision(Map? data) {
    if (data == null) return 0;
    return int.tryParse('${data['revision']}') ?? 0;
  }
}
