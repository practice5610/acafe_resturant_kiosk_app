import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Constraint-based scale for the landscape kiosk (Option B).
///
/// Every landscape screen is authored against a **1366 x 1024** design base and
/// multiplies each design value by [scale]. The base is a reference, never a
/// fixed size: [scaleFor] fits it into whatever tablet the screen is given by
/// the smaller of the two axes — `min(width / 1366, height / 1024)` — so the UI
/// is responsive on any size and aspect ratio with nothing hard-coded in px.
///
/// Prefer [LandscapeMetrics.of] (fed by [LandscapeScaled] from a `LayoutBuilder`)
/// so the scale tracks the box a widget is actually given, not the raw window.
class LandscapeMetrics {
  /// Figma Option B artboard the landscape screens are designed against.
  static const double designWidth = 1366;
  static const double designHeight = 1024;

  /// Floor so a sliver of a window during a resize can't collapse type to 0.
  static const double minScale = 0.1;

  final double scale;
  final Size size;

  const LandscapeMetrics({required this.scale, required this.size});

  /// `min(width / designWidth, height / designHeight)`, guarded. A zero,
  /// negative or non-finite input (a `LayoutBuilder` can hand out an unbounded
  /// or zero box for one frame) falls back to 1.0 rather than 0, NaN or
  /// infinity, which would throw in the render tree.
  static double scaleFor(double width, double height) {
    if (!width.isFinite || !height.isFinite || width <= 0 || height <= 0) {
      return 1.0;
    }
    final double s = math.min(width / designWidth, height / designHeight);
    if (!s.isFinite || s <= 0) return 1.0;
    return math.max(s, minScale);
  }

  factory LandscapeMetrics.fromSize(Size size) =>
      LandscapeMetrics(scale: scaleFor(size.width, size.height), size: size);

  factory LandscapeMetrics.fromConstraints(BoxConstraints constraints) =>
      LandscapeMetrics.fromSize(
          Size(constraints.maxWidth, constraints.maxHeight));

  /// Design px → logical px.
  double px(double designPx) => designPx * scale;

  /// Nearest [LandscapeMetrics] from a [LandscapeScaled] ancestor, or a window
  /// fallback so a screen still renders outside one (e.g. in a test).
  static LandscapeMetrics of(BuildContext context) {
    final _LandscapeMetricsScope? scope = context
        .dependOnInheritedWidgetOfExactType<_LandscapeMetricsScope>();
    if (scope != null) return scope.metrics;
    return LandscapeMetrics.fromSize(MediaQuery.sizeOf(context));
  }
}

/// Measures its box with a [LayoutBuilder], resolves [LandscapeMetrics] from the
/// constraints, and publishes it to descendants via [LandscapeMetrics.of].
class LandscapeScaled extends StatelessWidget {
  final Widget child;

  const LandscapeScaled({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return _LandscapeMetricsScope(
          metrics: LandscapeMetrics.fromConstraints(constraints),
          child: child,
        );
      },
    );
  }
}

class _LandscapeMetricsScope extends InheritedWidget {
  final LandscapeMetrics metrics;

  const _LandscapeMetricsScope({
    required this.metrics,
    required super.child,
  });

  @override
  bool updateShouldNotify(_LandscapeMetricsScope oldWidget) =>
      metrics.scale != oldWidget.metrics.scale ||
      metrics.size != oldWidget.metrics.size;
}
