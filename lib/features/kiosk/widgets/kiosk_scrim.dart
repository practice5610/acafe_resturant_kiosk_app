import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:acafe_customer/common/responsive/kiosk_responsive.dart';

/// The frosted scrim behind every kiosk modal.
///
/// This replaces three near-identical hand-rolled `BackdropFilter`s that had
/// drifted apart (sigma 6/6/8, alpha 0.45/0.45/0.55, none of them animated).
/// Three things were wrong with that, and this fixes all three:
///
///  * **Strength.** A blur weak enough to read the menu underneath makes a
///    modal look like it is floating on a screenshot. The design blurs the page
///    until only colour and mass survive.
///  * **Responsiveness.** A FIXED sigma is not responsive — blur is measured in
///    device pixels, so 6px is heavy on a 600px window and invisible on a
///    2572px kiosk. The sigma here is authored in artboard px and scaled by the
///    same [KioskResponsive.scale] every other kiosk dimension uses, so the
///    blur looks identical at every size.
///  * **Motion.** A scrim that snaps from clear to blurred in one frame is the
///    single most obvious "unfinished" tell. This ramps in with the route.
///
/// No package needed: `BackdropFilter` + `ImageFilter.blur` IS Flutter's
/// GPU-accelerated frosted-glass primitive, and the blur/glassmorphism packages
/// on pub.dev are thin wrappers around exactly this call.
class KioskScrim extends StatelessWidget {
  /// Drives the blur ramp — pass the route's animation. A [kAlwaysCompleteAnimation]
  /// renders it fully blurred immediately.
  final Animation<double> animation;

  /// Tapping the scrim (outside the card) dismisses. Null makes it inert, for
  /// modals that must not be dismissed by accident mid-save.
  final VoidCallback? onDismiss;

  const KioskScrim({super.key, required this.animation, this.onDismiss});

  /// Blur radius in artboard px, scaled per screen. Tuned against the design:
  /// the page behind a modal keeps its colour and layout mass, but no text
  /// remains readable.
  static const double _blurDesign = 24;

  /// Floor, so a small tablet or a resized browser window still gets a blur
  /// that reads as deliberate rather than as a rendering glitch.
  static const double _blurMin = 8;

  /// Warm near-black, matching the brand ink rather than a generic black.
  static const Color _ink = Color(0xFF1E1E1E);
  static const double _tint = 0.45;

  @override
  Widget build(BuildContext context) {
    final double s = KioskResponsive.scale(MediaQuery.sizeOf(context).width);
    final double sigma = (_blurDesign * s).clamp(_blurMin, _blurDesign);

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        // easeOut so the blur arrives quickly and settles, rather than
        // creeping in linearly.
        final double t = Curves.easeOut.transform(
          animation.value.clamp(0.0, 1.0),
        );
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onDismiss,
          child: BackdropFilter(
            // Sigma must never be exactly 0: a zero-sigma blur still allocates
            // a saveLayer but skips the filter, which flickers on the first
            // frame. Start at a hair above nothing instead.
            filter: ImageFilter.blur(
              sigmaX: (sigma * t).clamp(0.001, sigma),
              sigmaY: (sigma * t).clamp(0.001, sigma),
            ),
            child: Container(color: _ink.withValues(alpha: _tint * t)),
          ),
        );
      },
    );
  }
}
