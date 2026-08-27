import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:acafe_customer/common/responsive/kiosk_responsive.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_ui.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';

// ===========================================================================
// KIOSK — ORDER SUCCESS
// ===========================================================================
// Two beats after a successful place, matching the confirmation frames:
//
//   1. Wordmark + drawn check + "ORDER CONFIRMED!"
//   2. Wordmark + order-number card + "THANK YOU, {NAME}!" + pickup line
//
// Every string arrives resolved so this screen holds no provider and can be
// rendered in a widget test as-is. Tap anywhere to skip the current beat.
// ===========================================================================

const Duration _kConfirmEnter = Duration(milliseconds: 900);
const Duration _kConfirmHold = Duration(milliseconds: 1100);
const Duration _kThanksEnter = Duration(milliseconds: 850);
const Duration _kThanksHold = Duration(milliseconds: 2400);

const Color _kInk = Color(0xFF231F20);
const Color _kCardBorder = Color(0xFFE6E0CE);

enum _Beat { confirmed, thankYou }

/// Full-screen confirmation after the order is placed.
class KioskOrderSuccessScreen extends StatefulWidget {
  /// Already formatted, e.g. `#832`.
  final String orderNumber;

  /// Already formatted, e.g. `THANK YOU, DYLAN!`.
  final String thankYouText;

  final String pickupMessage;

  /// Already formatted, e.g. `ORDER CONFIRMED!`.
  final String confirmedText;

  const KioskOrderSuccessScreen({
    super.key,
    required this.orderNumber,
    required this.thankYouText,
    required this.pickupMessage,
    this.confirmedText = 'ORDER CONFIRMED!',
  });

  static Route<void> route({
    required String orderNumber,
    required String thankYouText,
    required String pickupMessage,
    String confirmedText = 'ORDER CONFIRMED!',
  }) {
    return PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (_, __, ___) => KioskOrderSuccessScreen(
        orderNumber: orderNumber,
        thankYouText: thankYouText,
        pickupMessage: pickupMessage,
        confirmedText: confirmedText,
      ),
      transitionsBuilder: (_, animation, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      ),
    );
  }

  @override
  State<KioskOrderSuccessScreen> createState() =>
      _KioskOrderSuccessScreenState();
}

class _KioskOrderSuccessScreenState extends State<KioskOrderSuccessScreen>
    with TickerProviderStateMixin {
  late final AnimationController _confirm;
  late final AnimationController _thanks;
  _Beat _beat = _Beat.confirmed;
  Timer? _holdTimer;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _confirm = AnimationController(vsync: this, duration: _kConfirmEnter)
      ..forward();
    _thanks = AnimationController(vsync: this, duration: _kThanksEnter);
    _holdTimer = Timer(_kConfirmEnter + _kConfirmHold, _showThanks);
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _confirm.dispose();
    _thanks.dispose();
    super.dispose();
  }

  void _showThanks() {
    if (!mounted || _beat == _Beat.thankYou || _leaving) return;
    _holdTimer?.cancel();
    setState(() => _beat = _Beat.thankYou);
    _thanks.forward(from: 0);
    _holdTimer = Timer(_kThanksEnter + _kThanksHold, _leave);
  }

  void _leave() {
    if (_leaving || !mounted) return;
    _leaving = true;
    _holdTimer?.cancel();
    final NavigatorState navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
  }

  void _onTap() {
    if (_beat == _Beat.confirmed) {
      _showThanks();
    } else {
      _leave();
    }
  }

  Widget _reveal({
    required AnimationController controller,
    required double begin,
    required double end,
    required double s,
    double rise = 36,
    Widget? child,
    Widget Function(double t)? builder,
  }) {
    final Animation<double> t = CurvedAnimation(
      parent: controller,
      curve: Interval(begin, end, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: t,
      builder: (context, inner) => Opacity(
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
      backgroundColor: KioskUI.pageBg,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _onTap,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final m = _SuccessMetrics.resolve(
                constraints.maxWidth,
                constraints.maxHeight,
              );

              return Stack(
                children: [
                  Positioned(
                    top: m.logoTop,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: _reveal(
                        controller: _confirm,
                        begin: 0.0,
                        end: 0.28,
                        s: m.s,
                        rise: 16,
                        child: SvgPicture.asset(
                          Images.kioskLogoWhiteSvg,
                          width: m.logoWidth,
                          height: m.logoHeight,
                          fit: BoxFit.contain,
                          colorFilter: const ColorFilter.mode(
                            _kInk,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 420),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: _beat == _Beat.confirmed
                          ? KeyedSubtree(
                              key: const ValueKey('confirmed'),
                              child: _ConfirmedBeat(
                                metrics: m,
                                text: widget.confirmedText,
                                progress: _confirm,
                                reveal: _reveal,
                              ),
                            )
                          : KeyedSubtree(
                              key: const ValueKey('thanks'),
                              child: _ThanksBeat(
                                metrics: m,
                                orderNumber: widget.orderNumber,
                                thankYouText: widget.thankYouText,
                                pickupMessage: widget.pickupMessage,
                                progress: _thanks,
                                reveal: _reveal,
                              ),
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

class _ConfirmedBeat extends StatelessWidget {
  final _SuccessMetrics metrics;
  final String text;
  final AnimationController progress;
  final Widget Function({
    required AnimationController controller,
    required double begin,
    required double end,
    required double s,
    double rise,
    Widget? child,
    Widget Function(double t)? builder,
  }) reveal;

  const _ConfirmedBeat({
    required this.metrics,
    required this.text,
    required this.progress,
    required this.reveal,
  });

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        reveal(
          controller: progress,
          begin: 0.12,
          end: 0.72,
          s: m.s,
          rise: 24,
          builder: (t) {
            // Draw the Figma check, then settle the scale.
            final double scale = 0.86 + (0.14 * Curves.easeOutBack.transform(t));
            return Transform.scale(
              scale: scale,
              child: SizedBox(
                width: m.checkWidth,
                height: m.checkHeight,
                child: CustomPaint(
                  painter: _CheckPainter(progress: t.clamp(0.0, 1.0)),
                ),
              ),
            );
          },
        ),
        SizedBox(height: m.checkGap),
        reveal(
          controller: progress,
          begin: 0.48,
          end: 1.0,
          s: m.s,
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: loewExtraBold.copyWith(
              fontSize: m.confirmedSize,
              height: 1.05,
              color: _kInk,
            ),
          ),
        ),
      ],
    );
  }
}

class _ThanksBeat extends StatelessWidget {
  final _SuccessMetrics metrics;
  final String orderNumber;
  final String thankYouText;
  final String pickupMessage;
  final AnimationController progress;
  final Widget Function({
    required AnimationController controller,
    required double begin,
    required double end,
    required double s,
    double rise,
    Widget? child,
    Widget Function(double t)? builder,
  }) reveal;

  const _ThanksBeat({
    required this.metrics,
    required this.orderNumber,
    required this.thankYouText,
    required this.pickupMessage,
    required this.progress,
    required this.reveal,
  });

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: m.sidePad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          reveal(
            controller: progress,
            begin: 0.0,
            end: 0.48,
            s: m.s,
            rise: 28,
            builder: (t) => Transform.scale(
              scale: 0.94 + (0.06 * t),
              child: Container(
                width: m.numberCardWidth,
                padding: EdgeInsets.symmetric(
                  horizontal: m.numberPadH,
                  vertical: m.numberPadV,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(m.numberRadius),
                  border: Border.all(color: _kCardBorder, width: 1.5),
                ),
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    orderNumber,
                    maxLines: 1,
                    style: loewExtraBold.copyWith(
                      fontSize: m.numberSize,
                      height: 1.0,
                      color: _kInk,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: m.thanksGap),
          reveal(
            controller: progress,
            begin: 0.28,
            end: 0.72,
            s: m.s,
            child: Text(
              thankYouText,
              textAlign: TextAlign.center,
              style: loewExtraBold.copyWith(
                fontSize: m.thanksSize,
                height: 1.1,
                color: _kInk,
              ),
            ),
          ),
          SizedBox(height: m.pickupGap),
          reveal(
            controller: progress,
            begin: 0.48,
            end: 1.0,
            s: m.s,
            child: Text(
              pickupMessage,
              textAlign: TextAlign.center,
              style: loewMedium.copyWith(
                fontSize: m.pickupSize,
                height: 1.35,
                color: _kInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Stroke-draw of the Figma-exported kiosk check (`kiosk_check.svg`,
/// 60.495 × 50, 10.5px round stroke). Drawn in black on the cream page.
class _CheckPainter extends CustomPainter {
  final double progress;
  const _CheckPainter({required this.progress});

  static const double _vw = 60.495;
  static const double _vh = 50;

  @override
  void paint(Canvas canvas, Size size) {
    final double sx = size.width / _vw;
    final double sy = size.height / _vh;
    final Path source = Path()
      ..moveTo(55.245 * sx, 6.77125 * sy)
      ..lineTo(20.8734 * sx, 41.1437 * sy)
      ..lineTo(5.25 * sx, 25.5199 * sy);

    final ui.PathMetrics metrics = source.computeMetrics();
    final Paint paint = Paint()
      ..color = _kInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10.5 * sx
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    for (final ui.PathMetric metric in metrics) {
      canvas.drawPath(
        metric.extractPath(0, metric.length * progress.clamp(0.0, 1.0)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_CheckPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _SuccessMetrics {
  final double s;
  final double logoTop;
  final double logoWidth;
  final double logoHeight;
  final double checkWidth;
  final double checkHeight;
  final double checkGap;
  final double confirmedSize;
  final double sidePad;
  final double numberCardWidth;
  final double numberPadH;
  final double numberPadV;
  final double numberRadius;
  final double numberSize;
  final double thanksGap;
  final double thanksSize;
  final double pickupGap;
  final double pickupSize;

  const _SuccessMetrics({
    required this.s,
    required this.logoTop,
    required this.logoWidth,
    required this.logoHeight,
    required this.checkWidth,
    required this.checkHeight,
    required this.checkGap,
    required this.confirmedSize,
    required this.sidePad,
    required this.numberCardWidth,
    required this.numberPadH,
    required this.numberPadV,
    required this.numberRadius,
    required this.numberSize,
    required this.thanksGap,
    required this.thanksSize,
    required this.pickupGap,
    required this.pickupSize,
  });

  factory _SuccessMetrics.resolve(double width, double height) {
    // One bounded scale for the whole composition. Per-element ceilings used
    // to bottom out on different clamps and pull the layout out of proportion.
    final double s = math
        .min(KioskResponsive.scale(width), height / 1920)
        .clamp(KioskResponsive.minScale, 1.0);
    final double logoWidth = 681 * s;
    final double logoHeight = logoWidth * (179 / 681);
    final double checkWidth = 420 * s;
    final double checkHeight = checkWidth * (50 / 60.495);

    return _SuccessMetrics(
      s: s,
      logoTop: 200 * s,
      logoWidth: logoWidth,
      logoHeight: logoHeight,
      checkWidth: checkWidth,
      checkHeight: checkHeight,
      checkGap: 48 * s,
      confirmedSize: 120 * s,
      sidePad: 86 * s,
      numberCardWidth: math.min(1400 * s, math.max(0, width - 48)),
      numberPadH: 80 * s,
      numberPadV: 56 * s,
      numberRadius: 24 * s,
      numberSize: 180 * s,
      thanksGap: 40 * s,
      thanksSize: 72 * s,
      pickupGap: 20 * s,
      pickupSize: 36 * s,
    );
  }
}
