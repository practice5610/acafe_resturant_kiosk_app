import 'package:acafe_customer/di_container.dart' as di;
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/category/providers/category_provider.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
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

class _ProductRealtimeScopeState extends State<ProductRealtimeScope> {
  int? _startedForBranch;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  Future<void> _sync() async {
    if (!mounted) return;
    final splash = context.read<SplashProvider>();
    final auth = context.read<KioskAuthProvider>();
    final controller = di.sl<ProductRealtimeController>();
    final config = splash.configModel?.websocket;
    final branchId = auth.branchId;

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
      }
      return;
    }
    if (_startedForBranch == branchId) {
      return;
    }
    _startedForBranch = branchId;
    if (kDebugMode) {
      debugPrint(
        'ProductRealtimeScope connecting branch=$branchId '
        'host=${config.host}:${config.port} scheme=${config.scheme}',
      );
    }
    await controller.start(
      config: config,
      branchId: branchId,
      categories: context.read<CategoryProvider>(),
      cart: context.read<CartProvider>(),
      localization: context.read<LocalizationProvider>(),
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
    di.sl<ProductRealtimeController>().stop();
    super.dispose();
  }
}
