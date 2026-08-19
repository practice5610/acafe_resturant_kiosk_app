import 'dart:async';
import 'dart:collection';

import 'package:acafe_customer/common/models/api_response_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/common/reposotories/product_repo.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/category/providers/category_provider.dart';
import 'package:acafe_customer/features/language/providers/localization_provider.dart';
import 'package:acafe_customer/features/realtime/catalog_event.dart';
import 'package:acafe_customer/features/realtime/catalog_realtime_policy.dart';
import 'package:acafe_customer/features/realtime/product_realtime_gateway.dart';
import 'package:acafe_customer/features/realtime/websocket_config.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Applies catalog socket events to the kiosk menu cache. Transport stays in
/// [ProductRealtimeGateway]; this class only decides refetch vs patch vs reload.
class ProductRealtimeController {
  ProductRealtimeController({
    required this.productRepo,
    required this.gateway,
  });

  final ProductRepo productRepo;
  final ProductRealtimeGateway gateway;

  final Map<int, Timer> _debounce = {};
  final ListQueue<String> _seenEventIds = ListQueue<String>();
  static const int _seenCap = 100;

  CategoryProvider? _categories;
  CartProvider? _cart;
  LocalizationProvider? _localization;
  WebsocketConfig? _config;

  Future<void> start({
    required WebsocketConfig config,
    required int branchId,
    required CategoryProvider categories,
    required CartProvider cart,
    required LocalizationProvider localization,
  }) async {
    _config = config;
    _categories = categories;
    _cart = cart;
    _localization = localization;

    gateway.onEvent = _onEvent;
    gateway.onReconnect = _onReconnect;
    await gateway.connect(config: config, branchId: branchId);
  }

  Future<void> stop() async {
    for (final timer in _debounce.values) {
      timer.cancel();
    }
    _debounce.clear();
    await gateway.disconnect();
  }

  void _onEvent(CatalogEvent event) {
    if (kDebugMode) {
      debugPrint(
        'ProductRealtimeController event action=${event.action} '
        'product=${event.productId} rev=${event.revision}',
      );
    }
    final categories = _categories;
    if (categories == null) {
      return;
    }

    final bool duplicate = event.eventId.isNotEmpty &&
        _seenEventIds.contains(event.eventId);
    final action = CatalogRealtimePolicy.decide(
      event: event,
      menuRevision: categories.menuRevision,
      duplicateEventId: duplicate,
    );
    if (action == CatalogClientAction.ignore) {
      return;
    }
    if (event.eventId.isNotEmpty) {
      _seenEventIds.add(event.eventId);
      while (_seenEventIds.length > _seenCap) {
        _seenEventIds.removeFirst();
      }
    }

    if (event.revision > 0) {
      categories.setMenuRevision(event.revision);
    }

    if (action == CatalogClientAction.reload) {
      _fullReload();
      return;
    }
    if (action == CatalogClientAction.remove) {
      _applyRemoved(event.productId);
      return;
    }

    _debounce[event.productId]?.cancel();
    _debounce[event.productId] = Timer(const Duration(milliseconds: 300), () {
      _debounce.remove(event.productId);
      _fetchAndApply(event);
    });
  }

  Future<void> _fetchAndApply(CatalogEvent event) async {
    final ApiResponseModel response =
        await productRepo.getProductDetails(event.productId);
    final status = response.response?.statusCode;
    final notFound = _isNotFound(response);
    if (status != 200 &&
        !CatalogRealtimePolicy.treatFetchedProductAsRemoved(
          event: event,
          statusCode: status,
          notFound: notFound,
          productStatus: null,
          isAvailable: null,
        )) {
      return;
    }
    if (status != 200) {
      _applyRemoved(event.productId);
      return;
    }
    final data = response.response?.data;
    if (data is! Map) {
      return;
    }
    try {
      final product = Product.fromJson(Map<String, dynamic>.from(data));
      _categories?.applyRealtimeUpsert(product);
      if (CatalogRealtimePolicy.treatFetchedProductAsRemoved(
        event: event,
        statusCode: status,
        notFound: false,
        productStatus: product.status,
        isAvailable: product.branchProduct?.isAvailable,
      )) {
        _applyRemoved(product.id ?? event.productId);
      }
    } catch (e) {
      debugPrint('ProductRealtimeController apply failed: $e');
    }
  }

  void _applyRemoved(int productId) {
    if (productId <= 0) {
      return;
    }
    _categories?.applyRealtimeRemove(productId);
    _cart?.removeByProductId(productId);
  }

  void _fullReload() {
    final locale = _localization?.locale.languageCode;
    if (locale == null) {
      return;
    }
    _categories?.prefetchKioskMenu(localeCode: locale, force: true);
  }

  bool _isNotFound(ApiResponseModel response) {
    final error = response.error;
    return error is DioException && error.response?.statusCode == 404;
  }

  Future<void> _onReconnect() async {
    final config = _config;
    final branchId = gateway.branchId;
    if (config == null || branchId == null) {
      _fullReload();
      return;
    }
    try {
      final ApiResponseModel response = await productRepo.syncMenu(
        sinceRevision: _categories?.menuRevision ?? 0,
      );
      if (response.response?.statusCode == 200) {
        final data = response.response?.data is Map
            ? Map<String, dynamic>.from(response.response!.data as Map)
            : null;
        final revision = CatalogRealtimePolicy.syncRevision(data);
        if (revision > 0) {
          _categories?.setMenuRevision(revision);
        }
        if (CatalogRealtimePolicy.syncNeedsReload(
          statusCode: response.response?.statusCode,
          data: data,
        )) {
          _fullReload();
        }
        return;
      }
    } catch (_) {}
    _fullReload();
  }
}
