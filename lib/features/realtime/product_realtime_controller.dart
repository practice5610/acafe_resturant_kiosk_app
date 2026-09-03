import 'dart:async';
import 'dart:collection';

import 'package:acafe_customer/common/models/api_response_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/common/reposotories/product_repo.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/category/providers/category_provider.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/coupon/providers/coupon_provider.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_deal_provider.dart';
import 'package:acafe_customer/features/language/providers/localization_provider.dart';
import 'package:acafe_customer/features/realtime/catalog_event.dart';
import 'package:acafe_customer/features/realtime/catalog_realtime_policy.dart';
import 'package:acafe_customer/features/realtime/device_ordering_experience_event.dart';
import 'package:acafe_customer/features/realtime/device_settings_event.dart';
import 'package:acafe_customer/features/realtime/device_settings_policy.dart';
import 'package:acafe_customer/features/realtime/product_realtime_gateway.dart';
import 'package:acafe_customer/features/realtime/websocket_config.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:acafe_customer/main.dart' show Get;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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
  Timer? _dealDebounce;
  final ListQueue<String> _seenEventIds = ListQueue<String>();
  static const int _seenCap = 100;

  CategoryProvider? _categories;
  CartProvider? _cart;
  LocalizationProvider? _localization;
  KioskDealProvider? _deals;
  CouponProvider? _coupons;
  KioskAuthProvider? _auth;
  WebsocketConfig? _config;

  Future<void> start({
    required WebsocketConfig config,
    required int branchId,
    required CategoryProvider categories,
    required CartProvider cart,
    required LocalizationProvider localization,
    required KioskDealProvider deals,
    required CouponProvider coupons,
    required KioskAuthProvider auth,
    int? deviceId,
  }) async {
    _config = config;
    _categories = categories;
    _cart = cart;
    _localization = localization;
    _deals = deals;
    _coupons = coupons;
    bindAuth(auth);

    gateway.onEvent = _onEvent;
    gateway.onDealEvent = _onDealEvent;
    gateway.onCouponEvent = _onCouponEvent;
    gateway.onDeviceOrderingExperienceEvent = _onDeviceOrderingExperience;
    gateway.onDeviceSettingsEvent = _onDeviceSettings;
    gateway.onReconnect = _onReconnect;
    await gateway.connect(
      config: config,
      branchId: branchId,
      deviceId: deviceId ?? auth.deviceId,
    );
  }

  /// Hot reload / already-connected path: keep the auth pointer fresh so
  /// Ordering Experience pushes still land on the live provider.
  void bindAuth(KioskAuthProvider auth) {
    _auth = auth;
    gateway.onDeviceOrderingExperienceEvent = _onDeviceOrderingExperience;
    gateway.onDeviceSettingsEvent = _onDeviceSettings;
  }

  /// True once for a given event id, false for every repeat. Reverb can
  /// deliver the same event twice -- the settings event is mirrored onto both
  /// the device channel and the branch channel on purpose, so a kiosk
  /// subscribed to both receives two copies of every push.
  bool _firstSighting(String eventId) {
    if (eventId.isEmpty) {
      return true;
    }
    if (_seenEventIds.contains(eventId)) {
      return false;
    }
    _seenEventIds.add(eventId);
    while (_seenEventIds.length > _seenCap) {
      _seenEventIds.removeFirst();
    }
    return true;
  }

  /// A `device.settings.changed` push: device type, status, name, branch, or
  /// ordering experience changed in the back office.
  Future<void> _onDeviceSettings(DeviceSettingsEvent event) async {
    final auth = _auth;
    if (auth == null) {
      return;
    }

    final action = DeviceSettingsPolicy.decide(
      event: event,
      currentDeviceId: auth.deviceId,
      currentBranchId: auth.branchId,
      duplicateEventId:
          event.eventId.isNotEmpty && _seenEventIds.contains(event.eventId),
    );
    if (action == DeviceSettingsClientAction.ignore) {
      return;
    }
    // Only claim the id once the policy has accepted the event, so a frame for
    // another device cannot poison the dedupe window for this one.
    if (!_firstSighting(event.eventId)) {
      return;
    }

    if (kDebugMode) {
      debugPrint(
        'ProductRealtimeController device settings $action '
        'device=${event.deviceId} category=${event.category} '
        'branch=${event.branchId} status=${event.status}',
      );
    }

    final outcome = await auth.applyDeviceSettingsFromRealtime(
      deviceId: event.deviceId,
      branchId: event.branchId,
      category: event.category,
      status: event.status,
      name: event.name,
      orderingExperience: event.orderingExperience,
      signOut: action == DeviceSettingsClientAction.signOut,
    );

    await _applyOutcome(outcome);
  }

  /// Shared tail for both push and reconnect-reconciliation paths.
  Future<void> _applyOutcome(KioskDeviceSettingsOutcome outcome) async {
    switch (outcome) {
      case KioskDeviceSettingsOutcome.signedOut:
        await _signOut();
        return;
      case KioskDeviceSettingsOutcome.reboundBranch:
        // The branch-scoped caches were dropped with the session write; the
        // cart belongs to the old branch's menu and cannot survive either.
        _cart?.clearCartList();
        _fullReload();
        // ProductRealtimeScope watches the auth provider and re-opens the
        // socket on the new branch's channel; nothing to do here for the
        // subscription itself.
        return;
      case KioskDeviceSettingsOutcome.applied:
      case KioskDeviceSettingsOutcome.ignored:
        return;
    }
  }

  /// Device deactivated or deleted: the token is already dead server-side.
  /// Drop the socket and send the kiosk back to the device login screen.
  Future<void> _signOut() async {
    await gateway.disconnect();
    _cart?.clearCartList();
    // Re-read the navigator context after the awaits above, and confirm it is
    // still mounted: a kiosk can be torn down mid-sign-out.
    final BuildContext? context = Get.context;
    if (context == null || !context.mounted) {
      return;
    }
    if (ModalRoute.of(context)?.settings.name == RouterHelper.kioskLoginScreen) {
      return;
    }
    RouterHelper.getKioskLoginRoute(
        action: RouteAction.pushNamedAndRemoveUntil);
  }

  Future<void> stop() async {
    for (final timer in _debounce.values) {
      timer.cancel();
    }
    _debounce.clear();
    _dealDebounce?.cancel();
    _dealDebounce = null;
    _auth = null;
    await gateway.disconnect();
  }

  Future<void> _onDeviceOrderingExperience(
      DeviceOrderingExperienceEvent event) async {
    final bool duplicate = event.eventId.isNotEmpty &&
        _seenEventIds.contains(event.eventId);
    if (duplicate) {
      return;
    }
    if (event.eventId.isNotEmpty) {
      _seenEventIds.add(event.eventId);
      while (_seenEventIds.length > _seenCap) {
        _seenEventIds.removeFirst();
      }
    }

    final auth = _auth;
    if (auth == null) {
      return;
    }
    final changed = await auth.applyOrderingExperienceFromRealtime(
      deviceId: event.deviceId,
      orderingExperience: event.orderingExperience,
    );
    if (kDebugMode && changed) {
      debugPrint(
        'ProductRealtimeController ordering experience -> '
        '${event.orderingExperience} (device=${event.deviceId})',
      );
    }
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

  void _onDealEvent(CatalogEvent event) {
    if (kDebugMode) {
      debugPrint(
        'ProductRealtimeController deal action=${event.action} '
        'deal=${event.dealId}',
      );
    }
    final bool duplicate = event.eventId.isNotEmpty &&
        _seenEventIds.contains(event.eventId);
    if (duplicate) {
      return;
    }
    if (event.eventId.isNotEmpty) {
      _seenEventIds.add(event.eventId);
      while (_seenEventIds.length > _seenCap) {
        _seenEventIds.removeFirst();
      }
    }

    if (event.isDelete) {
      final int id = event.dealId;
      if (id > 0) {
        _deals?.applyRealtimeRemove(id);
        _cart?.removeByDealId(id);
      }
      return;
    }

    _dealDebounce?.cancel();
    _dealDebounce = Timer(const Duration(milliseconds: 300), () {
      _dealDebounce = null;
      _deals?.fetchDeals();
    });
  }

  /// A coupon was created, edited or removed for this branch.
  ///
  /// There is no cached coupon list on the kiosk — codes are typed and checked
  /// against the server on every entry — so nothing needs refetching. What does
  /// need handling is a discount already applied to the open cart: if that
  /// coupon is the one that changed, it is dropped rather than carried into
  /// checkout at a rate head office may just have changed or revoked.
  void _onCouponEvent(CatalogEvent event) {
    if (kDebugMode) {
      debugPrint(
        'ProductRealtimeController coupon action=${event.action} '
        'coupon=${event.couponId}',
      );
    }
    final bool duplicate = event.eventId.isNotEmpty &&
        _seenEventIds.contains(event.eventId);
    if (duplicate) {
      return;
    }
    if (event.eventId.isNotEmpty) {
      _seenEventIds.add(event.eventId);
      while (_seenEventIds.length > _seenCap) {
        _seenEventIds.removeFirst();
      }
    }

    final int id = event.couponId;
    if (id <= 0) {
      return;
    }
    _coupons?.applyRealtimeChange(id);
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
    unawaited(_deals?.fetchDeals() ?? Future.value());
  }

  bool _isNotFound(ApiResponseModel response) {
    final error = response.error;
    return error is DioException && error.response?.statusCode == 404;
  }

  /// Pull the device's Ordering Experience back in step after a socket gap.
  ///
  /// The menu is reconciled on reconnect (below) precisely because pushes sent
  /// while the socket was down are lost; device settings need the same
  /// treatment. Fire-and-forget and independently guarded, so a failure here
  /// never blocks the menu sync that follows it.
  Future<void> _refreshDeviceSettings() async {
    final auth = _auth;
    if (auth == null) {
      return;
    }
    try {
      final outcome = await auth.refreshDeviceSettings();
      if (kDebugMode && outcome != KioskDeviceSettingsOutcome.ignored) {
        debugPrint(
          'ProductRealtimeController device settings reconciled on reconnect '
          '-> $outcome (category=${auth.category}, '
          'experience=${auth.orderingExperience.apiValue})',
        );
      }
      await _applyOutcome(outcome);
    } catch (e) {
      debugPrint('ProductRealtimeController device settings refresh failed: $e');
    }
  }

  /// Public entry point for the app-lifecycle observer: the socket may have
  /// died silently while the app was backgrounded, so on resume re-dial and
  /// reconcile rather than trusting the connection.
  Future<void> resume() async {
    await gateway.reconnectNow();
    await _refreshDeviceSettings();
  }

  Future<void> _onReconnect() async {
    unawaited(_refreshDeviceSettings());

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
        unawaited(_deals?.fetchDeals() ?? Future.value());
        return;
      }
    } catch (_) {}
    _fullReload();
  }
}
