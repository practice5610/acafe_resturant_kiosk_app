import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:acafe_customer/features/kiosk/domain/kiosk_coupon_reward.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_ui.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';

// ===========================================================================
// KIOSK — COUPON APPLIED
// ===========================================================================
// Figma POS nodes `1385:15875` ("07b – Coupon Applied: 10% Discount") and
// `1385:15897` ("coupon-applied-card", the €5 variant). The two artboards are
// the SAME layout with a different value in the banner, so this is one screen
// driven by [KioskCouponReward.headline] rather than two.
//
// The beat between CONTINUE on the coupon screen and landing back on the cart:
// the reward the customer just earned, held long enough to read, then gone.
//
// Choreography (one controller, staggered intervals — same shape as
// `kiosk_added_to_cart_screen`, which this is the sibling of):
//
//   0.00 -> 0.28   wordmark settles in
//   0.06 -> 0.52   banner lifts and scales up from 0.88
//   0.34 -> 0.74   success badge pops (overshoots), ring pulses out behind it
//   0.46 -> 0.78   "Coupon applied!" rises
//   0.58 -> 0.92   the message rises
//
// then a hold before returning. Tapping anywhere skips straight back — a
// customer who already believes us should never be made to wait.
// ===========================================================================

/// How long the whole entrance takes.
const Duration _kEnterDuration = Duration(milliseconds: 1200);

/// Hold after the entrance finishes, before returning to the cart.
const Duration _kHold = Duration(milliseconds: 1500);

/// Full-screen "Coupon applied!" confirmation.
///
/// Every string and number it paints arrives resolved in [reward]: the screen
/// reads no provider, so it cannot mutate coupon state and renders in a widget
/// test as-is. Push it with [KioskCouponAppliedScreen.route]; it pops itself
/// when the hold is over.
class KioskCouponAppliedScreen extends StatefulWidget {
  final KioskCouponReward reward;

  const KioskCouponAppliedScreen({super.key, required this.reward});

  /// Fades in over the coupon screen, which shares its cream background — a
  /// slide would read as a new page rather than as a response to CONTINUE.
  static Route<void> route(KioskCouponReward reward) {
    return PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, __, ___) => KioskCouponAppliedScreen(reward: reward),
      transitionsBuilder: (_, animation, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      ),
    );
  }

  @override
  State<KioskCouponAppliedScreen> createState() =>
      _KioskCouponAppliedScreenState();
}

class _KioskCouponAppliedScreenState extends State<KioskCouponAppliedScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _exitTimer;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _kEnterDuration)
      ..forward();
    _exitTimer = Timer(_kEnterDuration + _kHold, _leave);
  }

  @override
  void dispose() {
    _exitTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Back to whatever pushed this. Guarded so the auto-timer and a customer tap
  /// landing at the same moment cannot pop twice.
  void _leave() {
    if (_leaving || !mounted) return;
    _leaving = true;
    _exitTimer?.cancel();
    final NavigatorState navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
  }

  /// Fade + rise, on a slice of the shared controller.
  Widget _reveal({
    required double begin,
    required double end,
    required double s,

    /// Artboard px the child travels upward into place.
    double rise = 40,
    Widget? child,
    Widget Function(double t)? builder,
  }) {
    final Animation<double> t = CurvedAnimation(
      parent: _controller,
      curve: Interval(begin, end, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: t,
      builder: (context, inner) => Opacity(
        // Fade finishes ahead of the movement so nothing arrives still faint.
        opacity: Curves.easeOut.transform(t.value.clamp(0.0, 1.0)),
        child: Transform.translate(
          offset: Offset(0, (1 - t.value) * rise * s),
          child: builder != null ? builder(t.value) : inner,
        ),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kPageBg,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          // Tap anywhere to skip ahead — never trap the customer here.
          onTap: _leave,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final _AppliedMetrics m = _AppliedMetrics.resolve(
                constraints.maxWidth,
                constraints.maxHeight,
              );

              return Stack(
                children: [
                  // The artboard pins the wordmark near the top and centres the
                  // reward on the page's midline, so this is a Stack rather
                  // than one column: the gap between them is whitespace, and
                  // whitespace is what a taller screen should absorb.
                  Positioned(
                    top: m.logoTop,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: _reveal(
                        begin: 0.0,
                        end: 0.28,
                        s: m.s,
                        rise: 20,
                        child: SvgPicture.asset(
                          Images.kioskLogoWhiteSvg,
                          width: m.px(_kLogoWidth),
                          height: m.px(_kLogoHeight),
                          fit: BoxFit.contain,
                          // Artwork ships white; every light kiosk screen tints
                          // it with the page ink.
                          colorFilter: const ColorFilter.mode(
                            _kInk,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: SizedBox(
                      width: m.contentWidth,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _reveal(
                            begin: 0.06,
                            end: 0.52,
                            s: m.s,
                            rise: 56,
                            builder: (t) => Transform.scale(
                              // Settles up into place rather than popping.
                              scale: 0.88 + (0.12 * t),
                              child: _PriceBanner(
                                m: m,
                                headline: widget.reward.headline,
                                controller: _controller,
                              ),
                            ),
                          ),
                          SizedBox(height: m.px(_kStackGap)),
                          _reveal(
                            begin: 0.46,
                            end: 0.78,
                            s: m.s,
                            child: Text(
                              widget.reward.heading,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              style: loewExtraBold.copyWith(
                                fontSize: m.px(_kHeadingFont),
                                height: 1.1,
                                color: _kInk,
                              ),
                            ),
                          ),
                          SizedBox(height: m.px(_kMessageGap)),
                          _reveal(
                            begin: 0.58,
                            end: 0.92,
                            s: m.s,
                            child: Text(
                              widget.reward.message,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              style: loewMedium.copyWith(
                                fontSize: m.px(_kSubtitleFont),
                                height: 1.2,
                                color: _kSubtitleInk,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Figma metrics — every number below is a raw pixel from the 2572 x 4530
// artboard (nodes 1385:15875 / 1385:15897).
// ===========================================================================

const double _kDesignWidth = 2572;

const Color _kPageBg = KioskUI.pageBg; // #F7F1DE
const Color _kInk = Color(0xFF231F20);
const Color _kSubtitleInk = Color(0xFF6B6659);
/// The kiosk's one success green (same value as [KioskUI.popularGreen]).
const Color _kSuccess = Color(0xFF357937);

const double _kLogoTop = 200;
const double _kLogoWidth = 681;
const double _kLogoHeight = 179;

const double _kContentWidth = 1400;
const double _kContentHeight = 695;

const double _kBannerPadH = 160;
const double _kBannerPadV = 60;
const double _kBannerRadius = 64;
const double _kHeadlineFont = 256;
/// The banner is 427 tall: 60 + this + 60. Fixing the text box (rather than
/// leaning on the font's own line height) is what keeps that exact.
const double _kHeadlineBox = 307;

const double _kBadgeSize = 120;
const double _kBadgeRight = -42;
const double _kBadgeBottom = -30;
const double _kBadgeShadowY = 12;
const double _kBadgeShadowBlur = 12;
/// The exported tick is wider than it is tall (60.495 x 50).
const double _kCheckHeight = 50;
const double _kCheckWidth = 60.495;

const double _kStackGap = 80;
const double _kHeadingFont = 96;
const double _kMessageGap = 24;
const double _kSubtitleFont = 48;

/// The shortest height the design can occupy: wordmark, a tightened gap, and
/// the reward block. Sizing against this instead of the full 4530 keeps type
/// readable on a short landscape display — the artboard's remaining height is
/// whitespace, which a taller screen simply absorbs around the centred block.
const double _kMinDesignHeight =
    _kLogoTop + _kLogoHeight + 160 + _kContentHeight + 200; // 1434

/// Resolved sizing for one viewport.
class _AppliedMetrics {
  /// Figma pixel → logical pixel.
  final double s;

  /// Where the wordmark sits, already pulled up if the reward block would
  /// otherwise reach it on a very short viewport.
  final double logoTop;

  final double contentWidth;

  const _AppliedMetrics._({
    required this.s,
    required this.logoTop,
    required this.contentWidth,
  });

  factory _AppliedMetrics.resolve(double width, double height) {
    final double s = math
        .min(width / _kDesignWidth, height / _kMinDesignHeight)
        .clamp(0.16, 1.0);

    // The reward block is centred, so it owns the middle `_kContentHeight * s`
    // of the viewport; the wordmark keeps clear of it.
    final double roomAboveContent = (height - _kContentHeight * s) / 2;
    final double logoTop = math.max(
      8.0,
      math.min(_kLogoTop * s, roomAboveContent - (_kLogoHeight + 24) * s),
    );

    return _AppliedMetrics._(
      s: s,
      logoTop: logoTop,
      contentWidth: math.min(_kContentWidth * s, width),
    );
  }

  /// A designed measurement, in logical pixels.
  double px(double design) => design * s;
}

// ===========================================================================
// Sections
// ===========================================================================

/// The green banner holding the value, with the success badge on its corner.
class _PriceBanner extends StatelessWidget {
  final _AppliedMetrics m;
  final String headline;
  final AnimationController controller;

  const _PriceBanner({
    required this.m,
    required this.headline,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      // The badge hangs off the banner's corner on purpose.
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: m.px(_kBannerPadH),
            vertical: m.px(_kBannerPadV),
          ),
          decoration: BoxDecoration(
            color: _kSuccess.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(m.px(_kBannerRadius)),
          ),
          child: SizedBox(
            height: m.px(_kHeadlineBox),
            // A long value ("FREE", "€12.50", a right-positioned currency)
            // shrinks to fit rather than pushing the banner past the artboard.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                headline,
                maxLines: 1,
                style: loewExtraBold.copyWith(
                  fontSize: m.px(_kHeadlineFont),
                  height: 1.0,
                  color: _kSuccess,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: m.px(_kBadgeRight),
          bottom: m.px(_kBadgeBottom),
          child: _SuccessBadge(m: m, controller: controller),
        ),
      ],
    );
  }
}

/// The green tick that confirms the coupon landed: it overshoots into place,
/// and a ring pulses out from under it once.
class _SuccessBadge extends StatelessWidget {
  final _AppliedMetrics m;
  final AnimationController controller;

  const _SuccessBadge({required this.m, required this.controller});

  @override
  Widget build(BuildContext context) {
    final Animation<double> pop = CurvedAnimation(
      parent: controller,
      curve: const Interval(0.34, 0.74, curve: Curves.elasticOut),
    );
    final Animation<double> ring = CurvedAnimation(
      parent: controller,
      curve: const Interval(0.34, 0.74, curve: Curves.easeOutCubic),
    );
    final double size = m.px(_kBadgeSize);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: ring,
            builder: (context, _) => Transform.scale(
              scale: 1 + (ring.value * 1.1),
              child: Opacity(
                opacity: (1 - ring.value) * 0.45,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _kSuccess,
                      width: math.max(1, m.px(6)),
                    ),
                  ),
                ),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: pop,
            builder: (context, child) => Transform.scale(
              // elasticOut starts at 0 and overshoots past 1 on its way in.
              scale: pop.value.clamp(0.0, 1.25),
              child: child,
            ),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kSuccess,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    offset: Offset(0, m.px(_kBadgeShadowY)),
                    blurRadius: m.px(_kBadgeShadowBlur),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: SvgPicture.asset(
                Images.kioskCheckSvg,
                width: m.px(_kCheckWidth),
                height: m.px(_kCheckHeight),
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
