import 'package:acafe_customer/common/responsive/kiosk_shell.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_login_screen.dart';
import 'package:acafe_customer/features/kiosk/widgets/device_mode_curtain.dart';
import 'package:acafe_customer/features/pos/domain/pos_mode.dart';
import 'package:acafe_customer/features/pos/pos_shell.dart';
import 'package:acafe_customer/features/pos/widgets/pos_staff_gate.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:flutter/material.dart';

/// Everything the app wraps around its router: the kiosk or POS shell, the
/// POS staff gate, and the POS ⇄ Kiosk curtain. `MaterialApp.router`'s builder.
class AppChrome extends StatelessWidget {
  /// The router (the app's navigator).
  final Widget? child;

  const AppChrome({super.key, required this.child});

  /// One identity for the router wherever it sits. Swapping the POS shell for
  /// the kiosk one (a POS ⇄ Kiosk switch) moves it to a new place in the tree;
  /// without a key Flutter tears it down and builds a new one, which re-parses
  /// the address mid-switch (a RangeError in GoRouter's parser) and strands
  /// any open dialog. With it, the same router simply moves.
  static final GlobalKey _routerKey = GlobalKey(debugLabel: 'app-router');

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
        final Widget content = KeyedSubtree(
          key: _routerKey,
          child: child ?? const KioskLoginScreen(),
        );

        // The one place the two interfaces diverge. POS gets its own shell
        // because the kiosk's caps the tree at the 2572px kiosk artboard
        // and rewrites MediaQuery.size to match — correct for a kiosk,
        // wrong for a counter terminal that should lay out against the
        // real window.
        final Widget shell = PosMode.of(context).isPos
            // Staff PIN sign-in lives inside the POS shell only, so a kiosk
            // can never be shown it.
            ? PosShell(child: PosStaffGate(child: content))
            : KioskShell(
                fullBleed: path == RouterHelper.kioskWelcomeScreen,
                child: content,
              );

        return DeviceModeCurtain(child: shell);
      },
    );
  }
}
