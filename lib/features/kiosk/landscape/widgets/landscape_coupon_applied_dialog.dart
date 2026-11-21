import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:acafe_customer/features/kiosk/domain/kiosk_coupon_reward.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_translate.dart';
import 'package:acafe_customer/features/kiosk/landscape/landscape_metrics.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';

// ===========================================================================
// LANDSCAPE KIOSK — "Coupon applied!" pop-up (Option B).
// Figma TABLET Final Designs (option B), nodes:
//   2305:8856 — B-11  "Coupon applied: 10% off"
//   2305:9112 — B-11b "Coupon applied: €5 off"
// Same layout for every reward (10%, €, free item) — only the headline inside
// [reward] changes, same convention the portrait `KioskCouponAppliedScreen`
// uses. 800x600, dead-centre of the 1366x1024 canvas. Closes itself after 3 s;
// a tap on CONTINUE ORDERING or the X closes it immediately.
// ===========================================================================

const double _kCardWidth = 800;
const double _kCardHeight = 600;
const double _kCardRadius = 24;
const Color _kCardBg = Color(0xFFFBF8EF);
const Color _kInk = Color(0xFF231F20);
const Color _kSuccess = Color(0xFF357937);

const double _kCloseSize = 48;
const double _kCloseInset = 36; // 800 - 716 - 48 = 36, matches the top inset
const double _kCloseFont = 17;

const double _kContentTop = 40;
const double _kBannerPadH = 40;
const double _kBannerPadV = 15;
const double _kBannerRadius = 16;
const double _kHeadlineFont = 40;
const double _kBadgeSize = 30;
const double _kBadgeRight = -10.5;
const double _kBadgeBottom = -7.25;
const double _kCheckSize = 12.5;
const double _kStackGap = 40;
const double _kHeadingFont = 26;

const double _kButtonInset = 48;
const double _kButtonTop = 488;
const double _kButtonHeight = 64;
const double _kButtonFont = 17;
const double _kButtonGap = 14.222;
const double _kRingSize = 29.867;
const double _kRingStroke = 2.5;
const double _kRingFont = 11.2;

const int _kCountdownSeconds = 3;

/// Opens the landscape "Coupon applied!" pop-up. Resolves after it has
/// closed (by timeout, tap, or X) so the caller can then close the "Add a
/// coupon" pop-up behind it.
Future<void> showLandscapeCouponAppliedDialog(
  BuildContext context,
  KioskCouponReward reward,
) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'coupon-applied',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (ctx, __, ___) => _LandscapeCouponAppliedDialog(reward: reward),
    transitionBuilder: (ctx, animation, __, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: child,
    ),
  );
}

class _LandscapeCouponAppliedDialog extends StatefulWidget {
  final KioskCouponReward reward;
  const _LandscapeCouponAppliedDialog({required this.reward});

  @override
  State<_LandscapeCouponAppliedDialog> createState() =>
      _LandscapeCouponAppliedDialogState();
}

class _LandscapeCouponAppliedDialogState
    extends State<_LandscapeCouponAppliedDialog> {
  int _secondsLeft = _kCountdownSeconds;
  Timer? _timer;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Ticks [_secondsLeft] down once a second and leaves at zero — same
  /// convention as the portrait thank-you screen's countdown.
  void _startCountdown() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _leaving) {
        timer.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        timer.cancel();
        _leave();
        return;
      }
      setState(() => _secondsLeft -= 1);
    });
  }

  void _leave() {
    if (_leaving || !mounted) return;
    _leaving = true;
    _timer?.cancel();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.5),
      width: double.infinity,
      height: double.infinity,
      child: LayoutBuilder(
        builder: (context, c) {
          final double s = LandscapeMetrics.scaleFor(c.maxWidth, c.maxHeight);
          final double cardWidth = _kCardWidth * s;
          final double cardHeight = _kCardHeight * s;
          final double left = ((c.maxWidth - cardWidth) / 2).clamp(0.0, c.maxWidth);
          final double top = ((c.maxHeight - cardHeight) / 2).clamp(0.0, c.maxHeight);

          return Stack(
            children: [
              Positioned(
                left: left,
                top: top,
                child: _Card(
                  s: s,
                  width: cardWidth,
                  height: cardHeight,
                  headline: widget.reward.headline,
                  secondsLeft: _secondsLeft,
                  onClose: _leave,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final double s;
  final double width;
  final double height;
  final String headline;
  final int secondsLeft;
  final VoidCallback onClose;

  const _Card({
    required this.s,
    required this.width,
    required this.height,
    required this.headline,
    required this.secondsLeft,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(_kCardRadius * s),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: _kContentTop * s,
            bottom: (height - _kButtonTop * s),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PriceBanner(s: s, headline: headline),
                  SizedBox(height: _kStackGap * s),
                  Text(
                    kioskTranslate(context, 'coupon_applied_bang', 'Coupon applied!'),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: loewBold.copyWith(
                        fontSize: _kHeadingFont * s, height: 1.1, color: _kInk),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: _kCloseInset * s,
            top: _kCloseInset * s,
            child: GestureDetector(
              onTap: onClose,
              child: Container(
                width: _kCloseSize * s,
                height: _kCloseSize * s,
                decoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  'X',
                  style: loewBold.copyWith(
                      fontSize: _kCloseFont * s, height: 1.0, color: Colors.white),
                ),
              ),
            ),
          ),
          Positioned(
            left: _kButtonInset * s,
            right: _kButtonInset * s,
            top: _kButtonTop * s,
            child: _ContinueButton(
              s: s,
              secondsLeft: secondsLeft,
              onTap: onClose,
            ),
          ),
        ],
      ),
    );
  }
}

/// The green price banner with the success-check badge hanging off its
/// bottom-right corner.
class _PriceBanner extends StatelessWidget {
  final double s;
  final String headline;
  const _PriceBanner({required this.s, required this.headline});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: EdgeInsets.symmetric(
              horizontal: _kBannerPadH * s, vertical: _kBannerPadV * s),
          decoration: BoxDecoration(
            color: _kSuccess.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(_kBannerRadius * s),
          ),
          child: Text(
            headline,
            maxLines: 1,
            style: loewBold.copyWith(
                fontSize: _kHeadlineFont * s, height: 1.0, color: _kSuccess),
          ),
        ),
        Positioned(
          right: _kBadgeRight * s,
          bottom: _kBadgeBottom * s,
          child: Container(
            width: _kBadgeSize * s,
            height: _kBadgeSize * s,
            decoration: BoxDecoration(
              color: _kSuccess,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  offset: Offset(0, 3 * s),
                  blurRadius: 3 * s,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: SvgPicture.asset(
              Images.kioskCheckSvg,
              width: _kCheckSize * s,
              height: _kCheckSize * s * (50 / 60.495),
              fit: BoxFit.contain,
              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            ),
          ),
        ),
      ],
    );
  }
}

class _ContinueButton extends StatelessWidget {
  final double s;
  final int secondsLeft;
  final VoidCallback onTap;

  const _ContinueButton({
    required this.s,
    required this.secondsLeft,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double fraction =
        (secondsLeft / _kCountdownSeconds).clamp(0.0, 1.0);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(_kButtonHeight * s),
        onTap: onTap,
        child: Container(
          height: _kButtonHeight * s,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(_kButtonHeight * s),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                kioskTranslate(
                        context, 'continue_ordering', 'Continue ordering')
                    .toUpperCase(),
                maxLines: 1,
                style: loewBold.copyWith(
                    fontSize: _kButtonFont * s,
                    height: 1.0,
                    color: const Color(0xFFF7F1DE)),
              ),
              SizedBox(width: _kButtonGap * s),
              SizedBox(
                width: _kRingSize * s,
                height: _kRingSize * s,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: Size(_kRingSize * s, _kRingSize * s),
                      painter: _CountdownRingPainter(
                        remainingFraction: fraction,
                        strokeWidth: _kRingStroke * s,
                      ),
                    ),
                    Text(
                      '$secondsLeft',
                      style: loewMedium.copyWith(
                          fontSize: _kRingFont * s,
                          height: 1.0,
                          color: const Color(0xFFF7F1DE)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Track + a clockwise-emptying arc of time remaining — same convention as
/// the portrait thank-you screen's countdown ring.
class _CountdownRingPainter extends CustomPainter {
  final double remainingFraction;
  final double strokeWidth;

  const _CountdownRingPainter({
    required this.remainingFraction,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Rect bounds = Offset.zero & size;
    final Rect ring = bounds.deflate(strokeWidth / 2);

    final Paint track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = const Color(0xFFF7F1DE).withValues(alpha: 0.25);
    canvas.drawArc(ring, 0, 2 * math.pi, false, track);

    final Paint arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFF7F1DE);
    canvas.drawArc(
      ring,
      -math.pi / 2,
      2 * math.pi * remainingFraction.clamp(0.0, 1.0),
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_CountdownRingPainter oldDelegate) =>
      oldDelegate.remainingFraction != remainingFraction ||
      oldDelegate.strokeWidth != strokeWidth;
}
