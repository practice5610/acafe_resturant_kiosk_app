import 'package:acafe_customer/common/responsive/kiosk_responsive.dart';
import 'package:acafe_customer/common/responsive/kiosk_shell.dart';
import 'package:acafe_customer/features/pos/domain/pos_responsive.dart';
import 'package:acafe_customer/features/pos/widgets/pos_ui.dart';
import 'package:flutter/material.dart';

/// The kiosk shell and the POS shell as ONE widget tree whose shape never
/// changes -- only its values do (POS_KIOSK_MODE_PHASE1.md §5.6).
///
/// KioskShell and PosShell are different widget types, and a full-bleed
/// KioskShell has a different shape from a framed one. Switching between them
/// put the app's router at a new place in the tree, and Flutter's Router
/// re-parses the address whenever it is rebuilt or moved -- which mid-switch
/// GoRouter could not do (a RangeError in its parser, the red error seen when
/// a till went from kiosk back to POS). It also quietly rebuilt the router on
/// every welcome -> menu tap. Here the chain is fixed: background, centring,
/// size cap, MediaQuery, then both metrics scopes, each empty in the mode it
/// does not belong to, so every screen reads exactly what its own shell gave
/// it before.
class AppFrame extends StatelessWidget {
  final bool pos;

  /// Kiosk only: the welcome screen paints edge to edge, uncapped.
  final bool fullBleed;

  final Widget child;

  const AppFrame({super.key, required this.pos, this.fullBleed = false, required this.child});

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    final Size window = media.size;

    final KioskMetrics? kiosk = pos ? null : KioskMetrics.resolve(window, fullBleed: fullBleed);
    final PosMetrics? till = pos ? PosMetrics.resolve(window) : null;

    // As KioskShell: the kiosk caps the tree at its artboard and rewrites
    // MediaQuery.size to match; as PosShell: the till lays out against the real
    // window, unscaled.
    final MediaQueryData data = kiosk == null
        ? media.copyWith(textScaler: TextScaler.noScaling)
        : media.copyWith(
            size: kiosk.viewport,
            textScaler: TextScaler.linear(window.width < 380 ? 0.9 : 1.0),
          );
    final BoxConstraints cap = kiosk == null || fullBleed
        ? const BoxConstraints()
        : BoxConstraints(maxWidth: kiosk.contentWidth, maxHeight: window.height);

    return ColoredBox(
      color: pos ? PosUI.pageBg : kKioskPageBg,
      child: Center(
        child: ConstrainedBox(
          constraints: cap,
          child: MediaQuery(
            data: data,
            child: KioskMetricsScope(
              metrics: kiosk,
              child: PosMetricsScope(metrics: till, child: child),
            ),
          ),
        ),
      ),
    );
  }
}
