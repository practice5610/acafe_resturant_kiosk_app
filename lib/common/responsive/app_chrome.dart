import 'package:acafe_customer/common/responsive/app_frame.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_login_screen.dart';
import 'package:acafe_customer/features/kiosk/widgets/device_mode_curtain.dart';
import 'package:acafe_customer/features/pos/domain/pos_mode.dart';
import 'package:acafe_customer/features/pos/widgets/pos_staff_gate.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:flutter/material.dart';

/// Everything the app wraps around its router: the kiosk or POS frame, the POS
/// staff gate, and the POS ⇄ Kiosk curtain. `MaterialApp.router`'s builder.
///
/// The router never moves: the frame and the gate keep one shape in every mode
/// and state (see [AppFrame]). A moved or rebuilt router re-parses the address,
/// which is what broke the POS ⇄ Kiosk switch.
class AppChrome extends StatelessWidget {
  /// The router (the app's navigator).
  final Widget? child;

  const AppChrome({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // Listen so the welcome-screen full-bleed exemption cannot go stale
    // across GoRouter navigations (the WidgetsApp builder does not
    // otherwise rebuild on route changes).
    return ListenableBuilder(
      listenable: RouterHelper.goRoutes.routeInformationProvider,
      builder: (context, _) {
        final String path =
            RouterHelper.goRoutes.routeInformationProvider.value.uri.path;
        // The one place the two interfaces diverge. POS lays out against the
        // real window; the kiosk caps the tree at its 2572px artboard.
        final bool pos = PosMode.of(context).isPos;

        return DeviceModeCurtain(
          child: AppFrame(
            pos: pos,
            fullBleed: !pos && path == RouterHelper.kioskWelcomeScreen,
            // Staff PIN sign-in only ever acts on the POS, so a kiosk can
            // never be shown it.
            child: PosStaffGate(
              enabled: pos,
              child: child ?? const KioskLoginScreen(),
            ),
          ),
        );
      },
    );
  }
}
