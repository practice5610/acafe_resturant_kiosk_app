import 'package:acafe_customer/common/responsive/kiosk_responsive.dart';
import 'package:flutter/widgets.dart';

/// How every kiosk screen should read scale and orientation.
///
/// Prefer [KioskMetrics] from [KioskShell]. Fall back to [BoxConstraints] or
/// [MediaQuery] when a test or a modal has no shell ancestor.
class KioskLayout {
  KioskLayout._();

  static double scaleOf(BuildContext context, [BoxConstraints? constraints]) {
    final KioskMetrics? metrics = KioskMetrics.maybeOf(context);
    if (metrics != null) return metrics.scale;
    if (constraints != null) {
      return KioskResponsive.scale(
          constraints.maxWidth, constraints.maxHeight);
    }
    final Size size = MediaQuery.sizeOf(context);
    return KioskResponsive.scale(size.width, size.height);
  }

  static bool isLandscape(BuildContext context, [BoxConstraints? constraints]) {
    final KioskMetrics? metrics = KioskMetrics.maybeOf(context);
    if (metrics != null) return metrics.isLandscape;
    if (constraints != null) {
      return constraints.maxWidth > constraints.maxHeight;
    }
    final Size size = MediaQuery.sizeOf(context);
    return size.width >= size.height;
  }
}
