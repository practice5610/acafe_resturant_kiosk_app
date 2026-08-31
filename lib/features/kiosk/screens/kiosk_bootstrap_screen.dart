import 'package:flutter/material.dart';
import 'package:acafe_customer/common/enums/data_source_enum.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_intro_image.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_login_screen.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:provider/provider.dart';

/// Legacy boot route (/kiosk-start). Redirects silently with no splash UI.
class KioskBootstrapScreen extends StatefulWidget {
  const KioskBootstrapScreen({super.key});

  @override
  State<KioskBootstrapScreen> createState() => _KioskBootstrapScreenState();
}

class _KioskBootstrapScreenState extends State<KioskBootstrapScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final splashProvider = Provider.of<SplashProvider>(context, listen: false);
    final kioskAuth = Provider.of<KioskAuthProvider>(context, listen: false);

    // Make sure shared defaults + config are ready (on native the app's main
    // loader only runs for web/deep-link launches, so do it here too).
    await splashProvider.initSharedData();
    if (splashProvider.configModel == null) {
      if (!mounted) return;
      await splashProvider.initConfig(context, DataSourceEnum.local);
    }

    if (!mounted) return;

    if (!kioskAuth.isLoggedIn()) {
      RouterHelper.getKioskLoginRoute(action: RouteAction.pushReplacement);
      return;
    }

    final bool valid = await kioskAuth.validateSession();
    if (!mounted) return;

    if (valid) {
      // Login shell below already warms the intro; ensureReady is a cache hit.
      if (mounted) KioskIntroImage.warm(context);
      await RouterHelper.openKioskWelcome(
        context: mounted ? context : null,
        action: RouteAction.pushReplacement,
      );
    } else {
      RouterHelper.getKioskLoginRoute(action: RouteAction.pushReplacement);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show login immediately while bootstrap runs — never a blank screen.
    return const KioskLoginScreen();
  }
}
