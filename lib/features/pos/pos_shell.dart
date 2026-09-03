import 'package:acafe_customer/features/pos/domain/pos_responsive.dart';
import 'package:acafe_customer/features/pos/widgets/pos_ui.dart';
import 'package:flutter/material.dart';

/// App-level shell for POS mode — the counterpart to [KioskShell], and
/// deliberately not built on it.
///
/// What it does *not* do is the point:
///
///  * No 2572px content cap. That number is the kiosk's Figma board; a counter
///    terminal has no reason to letterbox itself.
///  * No `MediaQuery.size` override. The kiosk rewrites `size` so descendants
///    agree with its capped box; POS lays out against the real window, so
///    overriding it would only mislead `LayoutBuilder`.
///
/// What it does: publish one [PosMetrics] for the whole tree and paint the
/// brand page colour behind it.
class PosShell extends StatelessWidget {
  final Widget child;

  const PosShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    final PosMetrics metrics = PosMetrics.resolve(media.size);

    return PosMetricsScope(
      metrics: metrics,
      child: MediaQuery(
        // POS already derives its own density from PosMetrics.scale. Letting
        // an OS-level font scale compound on top of that is how a counter
        // terminal ends up with a receipt panel it cannot fit — and unlike a
        // consumer phone, this is fixed-function furniture whose text size is
        // a layout decision, not a user preference.
        data: media.copyWith(textScaler: TextScaler.noScaling),
        child: ColoredBox(
          color: PosUI.pageBg,
          child: child,
        ),
      ),
    );
  }
}
