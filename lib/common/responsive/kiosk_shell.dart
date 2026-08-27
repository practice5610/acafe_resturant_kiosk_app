import 'package:acafe_customer/common/responsive/kiosk_responsive.dart';
import 'package:flutter/material.dart';

/// Matches [KioskUI.pageBg]. Kept local so the shell does not depend on the
/// widget library (and so `web/index.html` can share the same hex).
const Color kKioskPageBg = Color(0xFFF7F1DE);

/// App-level shell: one [KioskMetrics], one content cap, one [MediaQuery.size].
///
/// Replaces the raw `ConstrainedBox(maxWidth: 1440)` that used to freeze the
/// UI on every display larger than 1440 and leave descendants reading the
/// *window* width rather than the box they were actually given.
///
///  * Content is capped at [kKioskContentMaxWidth] (the 2572 artboard) and
///    centred. The beige page colour fills the surplus.
///  * [MediaQuery.size] is overridden to the capped box, so `LayoutBuilder`
///    and `MediaQuery` agree.
///  * The welcome / attract route passes [fullBleed] so the video stays
///    edge-to-edge.
class KioskShell extends StatelessWidget {
  final Widget child;
  final bool fullBleed;

  const KioskShell({
    super.key,
    required this.child,
    this.fullBleed = false,
  });

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    final Size window = media.size;
    final KioskMetrics metrics =
        KioskMetrics.resolve(window, fullBleed: fullBleed);
    final double textScale = window.width < 380 ? 0.9 : 1.0;

    final Widget content = MediaQuery(
      data: media.copyWith(
        size: metrics.viewport,
        textScaler: TextScaler.linear(textScale),
      ),
      child: KioskMetricsScope(
        metrics: metrics,
        child: child,
      ),
    );

    if (fullBleed) return content;

    return ColoredBox(
      color: kKioskPageBg,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: metrics.contentWidth,
            maxHeight: window.height,
          ),
          child: content,
        ),
      ),
    );
  }
}
