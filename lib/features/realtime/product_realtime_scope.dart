import 'dart:async';

import 'package:acafe_customer/di_container.dart' as di;
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/category/providers/category_provider.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_deal_provider.dart';
import 'package:acafe_customer/features/language/providers/localization_provider.dart';
import 'package:acafe_customer/features/realtime/product_realtime_controller.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Connects the kiosk to Reverb once config + a bound branch exist.
class ProductRealtimeScope extends StatefulWidget {
  final Widget child;
  const ProductRealtimeScope({super.key, required this.child});

  @override
  State<ProductRealtimeScope> createState() => _ProductRealtimeScopeState();
}

class _ProductRealtimeScopeState extends State<ProductRealtimeScope>
    with WidgetsBindingObserver {
  int? _startedForBranch;
  int? _startedForDevice;
  String? _startedForEndpoint;

  @override
  void initState() {
    super.initState();
    // The kiosk had no lifecycle handling at all. A tablet that sleeps, or a
    // browser tab left in the background, comes back holding a socket that is
    // dead without ever having reported an error -- so every push sent in the
    // meantime is silently lost.
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      return;
    }
    // Re-dial and reconcile rather than trusting the connection. Nothing here
    // tears the socket down on pause: a kiosk that is briefly obscured should
    // keep receiving, and a genuinely dead socket is caught by the gateway's
    // own ping deadline.
    if (_startedForBranch == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
      return;
    }
    unawaited(di.sl<ProductRealtimeController>().resume());
  }

  Future<void> _sync() async {
    if (!mounted) return;
    final splash = context.read<SplashProvider>();
    final auth = context.read<KioskAuthProvider>();
    final controller = di.sl<ProductRealtimeController>();
    final config = splash.configModel?.websocket;
    final branchId = auth.branchId;
    final deviceId = auth.deviceId;

    if (config == null || !config.isUsable || branchId == null || branchId <= 0) {
      if (kDebugMode) {
        debugPrint(
          'ProductRealtimeScope skipped: websocket='
          '${config == null ? 'null' : 'enabled=${config.enabled} usable=${config.isUsable}'} '
          'branchId=$branchId',
        );
      }
      if (_startedForBranch != null) {
        await controller.stop();
        _startedForBranch = null;
        _startedForDevice = null;
        _startedForEndpoint = null;
      }
      return;
    }

    // Config is served cache-first at boot (see DataSyncRepo), so the stale
    // cached copy can carry an old Reverb host while the fresh one lands
    // moments later. Comparing the branch alone would skip that swap and leave
    // the socket retrying a dead endpoint for the rest of the session.
    final endpoint = config.socketUri?.toString();
    if (_startedForBranch == branchId &&
        _startedForDevice == deviceId &&
        _startedForEndpoint == endpoint) {
      // Already connected — still re-bind auth so hot reload / provider swaps
      // keep Ordering Experience pushes working.
      controller.bindAuth(auth);
      return;
    }

    // Resolve providers before the await so context is not used across it.
    final categories = context.read<CategoryProvider>();
    final cart = context.read<CartProvider>();
    final localization = context.read<LocalizationProvider>();
    final deals = context.read<KioskDealProvider>();

    // Claim the slot before any await. _sync() runs from a post-frame callback
    // on every rebuild, so a concurrent call must early-return rather than open
    // a second connection.
    final bool restarting = _startedForBranch != null;
    _startedForBranch = branchId;
    _startedForDevice = deviceId;
    _startedForEndpoint = endpoint;

    if (restarting) {
      await controller.stop();
      if (!mounted) return;
    }
    if (kDebugMode) {
      debugPrint(
        'ProductRealtimeScope connecting branch=$branchId device=$deviceId '
        'host=${config.host}:${config.port} scheme=${config.scheme}',
      );
    }
    await controller.start(
      config: config,
      branchId: branchId,
      deviceId: deviceId,
      categories: categories,
      cart: cart,
      localization: localization,
      deals: deals,
      auth: auth,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<SplashProvider, KioskAuthProvider>(
      builder: (context, splash, auth, child) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
        return widget.child;
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    di.sl<ProductRealtimeController>().stop();
    super.dispose();
  }
}
