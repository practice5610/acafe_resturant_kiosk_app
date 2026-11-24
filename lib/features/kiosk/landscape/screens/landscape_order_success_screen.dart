import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:math' as math;

import 'package:acafe_customer/features/kiosk/landscape/landscape_metrics.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';

// ===========================================================================
// LANDSCAPE KIOSK — "Thank you" (Option B), Figma node 2305:10220 "B-15 Thank
// you". Pushed directly by `LandscapeOrderSummaryScreen` after a successful
// place (not reached via GoRouter — mirrors how portrait's
// `KioskOrderSuccessScreen` is pushed with `Navigator.push`). Shows the final
// "thank you" beat only — the Figma hand-off has no landscape equivalent of
// portrait's earlier "order confirmed" beat, so this screen renders straight
// to it. Same countdown-ring convention as portrait/the other landscape
// pop-ups: ticks once a second, auto-leaves at zero or on any tap.
// ===========================================================================

const Color _kPageBg = Color(0xFFF7F1DE);
const Color _kInk = Color(0xFF0D0D0D);
const Color _kMuted = Color(0xFF73736E);

/// Default countdown length — same value portrait defaults to.
const int kLandscapeThankYouCountdownSeconds = 10;

class LandscapeOrderSuccessScreen extends StatefulWidget {
  final String orderNumber;
  final String customerName;
  final String receiptUrl;
  final String thankYouHeadline;
  final String thankYouSubtitle;
  final String nameCardLabel;
  final String receiptHeadline;
  final String receiptSubtitle;
  final String placeNewOrderLabel;
  final int countdownSeconds;

  const LandscapeOrderSuccessScreen({
    super.key,
    required this.orderNumber,
    required this.customerName,
    required this.receiptUrl,
    this.thankYouHeadline = 'Thank you!',
    this.thankYouSubtitle = "Your order is paid. We're making it now.",
    this.nameCardLabel = 'WE CALL YOUR NAME AT THE COUNTER',
    this.receiptHeadline = 'Scan for your receipt',
    this.receiptSubtitle = 'Open it on your phone and follow your order live.',
    this.placeNewOrderLabel = 'PLACE NEW ORDER',
    this.countdownSeconds = kLandscapeThankYouCountdownSeconds,
  });

  static Route<void> route({
    required String orderNumber,
    required String customerName,
    required String receiptUrl,
    String thankYouHeadline = 'Thank you!',
    String thankYouSubtitle = "Your order is paid. We're making it now.",
    String nameCardLabel = 'WE CALL YOUR NAME AT THE COUNTER',
    String receiptHeadline = 'Scan for your receipt',
    String receiptSubtitle = 'Open it on your phone and follow your order live.',
    String placeNewOrderLabel = 'PLACE NEW ORDER',
    int countdownSeconds = kLandscapeThankYouCountdownSeconds,
  }) {
    return PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (_, __, ___) => LandscapeOrderSuccessScreen(
        orderNumber: orderNumber,
        customerName: customerName,
        receiptUrl: receiptUrl,
        thankYouHeadline: thankYouHeadline,
        thankYouSubtitle: thankYouSubtitle,
        nameCardLabel: nameCardLabel,
        receiptHeadline: receiptHeadline,
        receiptSubtitle: receiptSubtitle,
        placeNewOrderLabel: placeNewOrderLabel,
        countdownSeconds: countdownSeconds,
      ),
      transitionsBuilder: (_, animation, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      ),
    );
  }

  @override
  State<LandscapeOrderSuccessScreen> createState() =>
      _LandscapeOrderSuccessScreenState();
}

class _LandscapeOrderSuccessScreenState
    extends State<LandscapeOrderSuccessScreen> {
  Timer? _countdownTimer;
  late int _secondsLeft = widget.countdownSeconds;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    if (widget.countdownSeconds <= 0) {
      _leave();
      return;
    }
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
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
    _countdownTimer?.cancel();
    final NavigatorState navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final String name = widget.customerName.trim().toUpperCase();
    final String rawOrder =
        widget.orderNumber.trim().replaceFirst(RegExp(r'^#'), '');
    final String orderLabel = rawOrder.isEmpty ? '' : 'Order /$rawOrder';

    return Scaffold(
      backgroundColor: _kPageBg,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _leave,
          child: LayoutBuilder(
            builder: (context, c) {
              final double s = LandscapeMetrics.scaleFor(c.maxWidth, c.maxHeight);
              return Stack(
                children: [
                  Positioned(
                    top: 64 * s,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Text(
                        'A/CAFÉ',
                        style: loewExtraBold.copyWith(
                            fontSize: 24 * s, height: 1, letterSpacing: 1 * s, color: _kInk),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 173 * s,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 72 * s,
                            height: 72 * s,
                            decoration: const BoxDecoration(
                              color: _kInk,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: SvgPicture.asset(
                              Images.kioskCheckSvg,
                              width: 32 * s,
                              height: 32 * s * (50 / 60.495),
                              fit: BoxFit.contain,
                              colorFilter: const ColorFilter.mode(
                                  Colors.white, BlendMode.srcIn),
                            ),
                          ),
                          SizedBox(height: 20 * s),
                          Text(
                            widget.thankYouHeadline,
                            textAlign: TextAlign.center,
                            style: loewBold.copyWith(
                                fontSize: 40 * s, height: 1.0, color: _kInk),
                          ),
                          SizedBox(height: 8 * s),
                          Text(
                            widget.thankYouSubtitle,
                            textAlign: TextAlign.center,
                            style: swiss721Light.copyWith(
                                fontSize: 18 * s, height: 1.12, color: _kMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 422 * s,
                    left: 191 * s,
                    right: 191 * s,
                    height: 380 * s,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 600,
                          child: _OrderNumberCard(
                              s: s, label: widget.nameCardLabel, name: name, orderLabel: orderLabel),
                        ),
                        SizedBox(width: 24 * s),
                        Expanded(
                          flex: 360,
                          child: _ReceiptCard(
                            s: s,
                            headline: widget.receiptHeadline,
                            subtitle: widget.receiptSubtitle,
                            receiptUrl: widget.receiptUrl,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 191 * s,
                    right: 191 * s,
                    top: 826 * s,
                    height: 80 * s,
                    child: _PlaceNewOrderButton(
                      s: s,
                      label: widget.placeNewOrderLabel,
                      secondsLeft: _secondsLeft,
                      totalSeconds: widget.countdownSeconds,
                      onTap: _leave,
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

class _OrderNumberCard extends StatelessWidget {
  final double s;
  final String label;
  final String name;
  final String orderLabel;
  const _OrderNumberCard(
      {required this.s, required this.label, required this.name, required this.orderLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 48 * s, vertical: 44 * s),
      decoration: BoxDecoration(
        color: _kInk,
        borderRadius: BorderRadius.circular(28 * s),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: loewMedium.copyWith(
                fontSize: 20 * s, height: 1.12, color: const Color(0xFFFEFFFF)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  name.isEmpty ? '—' : name,
                  maxLines: 1,
                  style: loewBold.copyWith(
                      fontSize: 120 * s,
                      height: 0.95,
                      letterSpacing: -2.4 * s,
                      color: const Color(0xFFF7F1DE)),
                ),
              ),
              if (orderLabel.isNotEmpty) ...[
                SizedBox(height: 10 * s),
                Text(
                  orderLabel,
                  maxLines: 1,
                  style: loewBold.copyWith(
                      fontSize: 22 * s, height: 1.12, color: const Color(0xFFD9D4C7)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  final double s;
  final String headline;
  final String subtitle;
  final String receiptUrl;
  const _ReceiptCard(
      {required this.s, required this.headline, required this.subtitle, required this.receiptUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(32 * s),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF8EF),
        border: Border.all(color: const Color(0xFFDED8C6), width: 2 * s),
        borderRadius: BorderRadius.circular(28 * s),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              padding: EdgeInsets.all(12 * s),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14 * s),
              ),
              child: QrImageView(
                data: receiptUrl,
                size: 152 * s,
                backgroundColor: Colors.white,
                padding: EdgeInsets.zero,
                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: _kInk),
                dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square, color: _kInk),
              ),
            ),
          ),
          SizedBox(height: 20 * s),
          Text(
            headline,
            style: loewBold.copyWith(fontSize: 22 * s, height: 1.0, color: _kInk),
          ),
          SizedBox(height: 6 * s),
          Text(
            subtitle,
            style: swiss721Light.copyWith(
                fontSize: 16 * s, height: 1.12, color: const Color(0xFF5C5952)),
          ),
        ],
      ),
    );
  }
}

class _PlaceNewOrderButton extends StatelessWidget {
  final double s;
  final String label;
  final int secondsLeft;
  final int totalSeconds;
  final VoidCallback onTap;
  const _PlaceNewOrderButton({
    required this.s,
    required this.label,
    required this.secondsLeft,
    required this.totalSeconds,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double fraction =
        totalSeconds <= 0 ? 0 : (secondsLeft / totalSeconds).clamp(0.0, 1.0);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(23 * s),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: _kInk,
            borderRadius: BorderRadius.circular(23 * s),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                style: loewBold.copyWith(
                    fontSize: 18 * s, height: 1.0, color: const Color(0xFFF7F1DE)),
              ),
              if (totalSeconds > 0) ...[
                SizedBox(width: 20 * s),
                SizedBox(
                  width: 42 * s,
                  height: 42 * s,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: Size(42 * s, 42 * s),
                        painter: _CountdownRingPainter(
                            remainingFraction: fraction, strokeWidth: 2.5 * s),
                      ),
                      Text(
                        '$secondsLeft',
                        style: loewBold.copyWith(
                            fontSize: 12.75 * s,
                            height: 1.0,
                            color: const Color(0xFFF7F1DE)),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Track + a clockwise-emptying arc of time remaining — same convention as
/// every other landscape countdown ring in this feature set.
class _CountdownRingPainter extends CustomPainter {
  final double remainingFraction;
  final double strokeWidth;
  const _CountdownRingPainter({required this.remainingFraction, required this.strokeWidth});

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
    canvas.drawArc(ring, -math.pi / 2, 2 * math.pi * remainingFraction.clamp(0.0, 1.0), false, arc);
  }

  @override
  bool shouldRepaint(_CountdownRingPainter oldDelegate) =>
      oldDelegate.remainingFraction != remainingFraction ||
      oldDelegate.strokeWidth != strokeWidth;
}
