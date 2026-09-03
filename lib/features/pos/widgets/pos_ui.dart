import 'package:acafe_customer/features/pos/domain/pos_responsive.dart';
import 'package:acafe_customer/theme/brand_colors.dart';
import 'package:flutter/material.dart';

/// POS design tokens.
///
/// The counterpart to `kiosk_ui.dart`, deliberately separate from it. The two
/// interfaces share a brand, not an artboard: kiosk values are authored against
/// a 2572px portrait board and would be meaningless here.
///
/// Colour comes from [BrandColors] wherever the brand already names it — that
/// is the one layer genuinely shared between the modes. Values below are the
/// POS-only surfaces.
class PosUI {
  PosUI._();

  // ── Colour ───────────────────────────────────────────────────────────
  // Brand: #F5F1EA page, #2B2B2B ink, #C8A97E accent. No dark surfaces.

  /// Page background. The brand's warm off-white.
  static const Color pageBg = Color(0xFFF5F1EA);

  /// Raised surfaces: product tiles, the receipt panel, nav bar.
  static const Color surface = Colors.white;

  /// Recessed surfaces: input wells, the numeric pad face.
  static const Color surfaceSunken = Color(0xFFEDE7DC);

  static const Color ink = BrandColors.primary; // #2B2B2B
  static const Color inkMuted = Color(0xFF6E6A63);
  static const Color accent = BrandColors.secondary; // #C8A97E
  static const Color border = Color(0xFFDED9C7);
  static const Color onAccent = Color(0xFF2B2B2B);

  /// Status colours. Muted to sit inside a warm palette rather than shout.
  static const Color success = Color(0xFF3F7A45);
  static const Color danger = Color(0xFFB4544A);

  // ── Type scale (design px against the 1920x1080 board) ───────────────
  static const double displaySize = 44;
  static const double titleSize = 30;
  static const double headingSize = 22;
  static const double bodySize = 17;
  static const double captionSize = 14;

  // ── Metrics (design px) ──────────────────────────────────────────────
  static const double navBarHeight = 76;
  static const double radius = 14;
  static const double radiusLarge = 22;
  static const double gutter = 24;
  static const double gutterTight = 14;
  static const double buttonHeight = 58;
  static const double tileMinWidth = 190;

  /// Text style helper. [size] is a design-px constant from above; it is
  /// scaled by the current [PosMetrics] so one call site works at every window
  /// size.
  static TextStyle text(
    BuildContext context, {
    double size = bodySize,
    FontWeight weight = FontWeight.w500,
    Color color = ink,
    double? height,
  }) {
    final double s = PosMetrics.maybeOf(context)?.scale ?? 1.0;
    return TextStyle(
      fontSize: size * s,
      fontWeight: weight,
      color: color,
      height: height,
    );
  }
}

/// Scales a design-px value by the ambient [PosMetrics]. Falls back to 1.0 so
/// widgets stay renderable in tests without a [PosShell] ancestor.
double posPx(BuildContext context, double designPx) =>
    designPx * (PosMetrics.maybeOf(context)?.scale ?? 1.0);

/// A plain raised POS surface — the base for tiles, panels and cards.
class PosSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color color;
  final double? radius;
  final bool bordered;

  const PosSurface({
    super.key,
    required this.child,
    this.padding,
    this.color = PosUI.surface,
    this.radius,
    this.bordered = true,
  });

  @override
  Widget build(BuildContext context) {
    final double r = posPx(context, radius ?? PosUI.radius);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(r),
        border:
            bordered ? Border.all(color: PosUI.border, width: 1) : null,
      ),
      child: child,
    );
  }
}
