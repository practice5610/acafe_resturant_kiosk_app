import 'package:acafe_customer/common/responsive/kiosk_responsive.dart';
import 'package:flutter/widgets.dart';

/// Breakpoint buckets for the kiosk.
///
/// Composition is chosen by **orientation**, not by a width seam. The old
/// 1100px `isWide` switch sat 20px above the production 1080×1920 kiosk and
/// swapped the Figma layout for a set of frozen pixel constants. [isWide] now
/// means landscape — the axis that actually needs a different composition.
enum DeviceSize { phone, tablet, desktop, large }

class Responsive {
  Responsive._();

  static DeviceSize of(BuildContext context) {
    final double w =
        KioskMetrics.maybeOf(context)?.contentWidth ??
            MediaQuery.sizeOf(context).width;
    if (w < KioskResponsive.compactMax) return DeviceSize.phone;
    if (w < 1500) return DeviceSize.tablet;
    if (w < KioskResponsive.largeMin) return DeviceSize.desktop;
    return DeviceSize.large;
  }

  /// True in landscape. Portrait compositions (including the 1080×1920
  /// production kiosk) always return false, regardless of width.
  static bool isWide(BuildContext context) {
    final KioskMetrics? metrics = KioskMetrics.maybeOf(context);
    if (metrics != null) return metrics.isLandscape;
    final Size size = MediaQuery.sizeOf(context);
    return size.width >= size.height;
  }

  /// Pick a value per breakpoint, falling back to the next-smaller one.
  static T value<T>(
    BuildContext context, {
    required T phone,
    T? tablet,
    T? desktop,
    T? large,
  }) {
    switch (of(context)) {
      case DeviceSize.phone:
        return phone;
      case DeviceSize.tablet:
        return tablet ?? phone;
      case DeviceSize.desktop:
        return desktop ?? tablet ?? phone;
      case DeviceSize.large:
        return large ?? desktop ?? tablet ?? phone;
    }
  }
}
