import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:acafe_customer/features/kiosk/domain/kiosk_intro_image.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_ui.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';

// ===========================================================================
// KIOSK — ORDER SUCCESS / THANK YOU
// ===========================================================================
// Two beats after a successful place (Figma POS node `2305:17116`, "14 Thank
// you"):
//
//   1. Wordmark + drawn check + "ORDER CONFIRMED!"
//   2. Wordmark + success badge + "THANK YOU!" + the customer's name in a
//      black card (biggest element — staff call it at the counter) with the
//      order number underneath, a receipt card with a QR code to the digital
//      receipt/live order status, and a PLACE NEW ORDER button with a
//      per-second countdown ring that returns to the start screen on tap or
//      at zero.
//
// Every string arrives resolved so this screen holds no provider and can be
// rendered in a widget test as-is. Tap anywhere to skip the current beat.
// ===========================================================================

const Duration _kConfirmEnter = Duration(milliseconds: 900);
const Duration _kConfirmHold = Duration(milliseconds: 1100);
const Duration _kThanksEnter = Duration(milliseconds: 850);

/// Default length of the PLACE NEW ORDER countdown. Back Office
/// configurability is a follow-up; callers may override.
const int kKioskThankYouCountdownSeconds = 10;

const Color _kInk = Color(0xFF0D0D0D);
const Color _kCardBorder = Color(0xFFDED8C6);
const Color _kMuted = Color(0xFF5C5952);

enum _Beat { confirmed, thankYou }

/// Full-screen confirmation after the order is placed.
class KioskOrderSuccessScreen extends StatefulWidget {
  /// Raw order number/token, e.g. `832` (rendered as `Order /832`).
  final String orderNumber;

  /// The name the customer entered, rendered as the biggest element on the
  /// card — staff call it at the counter.
  final String customerName;

  /// Already formatted, e.g. `ORDER CONFIRMED!`.
  final String confirmedText;

  final String thankYouHeadline;
  final String thankYouSubtitle;
  final String nameCardLabel;
  final String receiptHeadline;
  final String receiptSubtitle;
  final String noPaperLabel;
  final String placeNewOrderLabel;
  final String closesInLabel;

  /// Opens the digital receipt / live order status on the customer's phone.
  final String receiptUrl;

  /// Seconds before PLACE NEW ORDER auto-fires. Configurable in the Back
  /// Office; defaults to the Figma value.
  final int countdownSeconds;

  const KioskOrderSuccessScreen({
    super.key,
    required this.orderNumber,
    required this.customerName,
    required this.receiptUrl,
    this.confirmedText = 'ORDER CONFIRMED!',
    this.thankYouHeadline = 'THANK YOU!',
    this.thankYouSubtitle = "Your order is paid. We're making it now.",
    this.nameCardLabel = 'WE CALL YOUR NAME AT THE COUNTER',
    this.receiptHeadline = 'Scan for your receipt',
    this.receiptSubtitle = 'Open it on your phone and follow your order live.',
    this.noPaperLabel = 'No paper receipt is printed',
    this.placeNewOrderLabel = 'PLACE NEW ORDER',
    this.closesInLabel = 'Closes in',
    this.countdownSeconds = kKioskThankYouCountdownSeconds,
  });

  static Route<void> route({
    required String orderNumber,
    required String customerName,
    required String receiptUrl,
    String confirmedText = 'ORDER CONFIRMED!',
    String thankYouHeadline = 'THANK YOU!',
    String thankYouSubtitle = "Your order is paid. We're making it now.",
    String nameCardLabel = 'WE CALL YOUR NAME AT THE COUNTER',
    String receiptHeadline = 'Scan for your receipt',
    String receiptSubtitle =
        'Open it on your phone and follow your order live.',
    String noPaperLabel = 'No paper receipt is printed',
    String placeNewOrderLabel = 'PLACE NEW ORDER',
    String closesInLabel = 'Closes in',
    int countdownSeconds = kKioskThankYouCountdownSeconds,
  }) {
    return PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (_, __, ___) => KioskOrderSuccessScreen(
        orderNumber: orderNumber,
        customerName: customerName,
        receiptUrl: receiptUrl,
        confirmedText: confirmedText,
        thankYouHeadline: thankYouHeadline,
        thankYouSubtitle: thankYouSubtitle,
        nameCardLabel: nameCardLabel,
        receiptHeadline: receiptHeadline,
        receiptSubtitle: receiptSubtitle,
        noPaperLabel: noPaperLabel,
        placeNewOrderLabel: placeNewOrderLabel,
        closesInLabel: closesInLabel,
        countdownSeconds: countdownSeconds,
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
  Timer? _countdownTimer;
  late int _secondsLeft = widget.countdownSeconds;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _confirm = AnimationController(vsync: this, duration: _kConfirmEnter)
      ..forward();
    _thanks = AnimationController(vsync: this, duration: _kThanksEnter);
    _holdTimer = Timer(_kConfirmEnter + _kConfirmHold, _showThanks);
    // Re-warm intro while the thank-you beat plays so a later return to the
    // welcome screen (idle / next customer) is a cache hit — no extra RAM
    // held beyond Flutter's image cache.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) KioskIntroImage.warm(context);
    });
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _countdownTimer?.cancel();
    _confirm.dispose();
    _thanks.dispose();
    super.dispose();
  }

  void _showThanks() {
    if (!mounted || _beat == _Beat.thankYou || _leaving) return;
    _holdTimer?.cancel();
    setState(() => _beat = _Beat.thankYou);
    _thanks.forward(from: 0);
    _startCountdown();
  }

  /// Ticks [_secondsLeft] down once a second — the ring empties clockwise in
  /// lockstep — and fires [_leave] at zero, same as a customer tap.
  void _startCountdown() {
    _countdownTimer?.cancel();
    if (widget.countdownSeconds <= 0) {
      _leave();
      return;
    }
    _secondsLeft = widget.countdownSeconds;
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
    _holdTimer?.cancel();
    _countdownTimer?.cancel();
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

              // The whole screen is the Figma artboard (2572 x 4530) scaled
              // by ONE factor and centred, so every element keeps its exact
              // Figma position and proportion on any kiosk size.
              return Center(
                child: SizedBox(
                  width: m.px(_kArtboardW),
                  height: m.px(_kArtboardH),
                  child: Stack(
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
                      Positioned.fill(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 420),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          layoutBuilder: (current, previous) => Stack(
                            fit: StackFit.expand,
                            children: [
                              ...previous,
                              if (current != null) current
                            ],
                          ),
                          child: _beat == _Beat.confirmed
                              ? KeyedSubtree(
                                  key: const ValueKey('confirmed'),
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      top: m.logoTop + m.logoHeight,
                                    ),
                                    child: Center(
                                      child: _ConfirmedBeat(
                                        metrics: m,
                                        text: widget.confirmedText,
                                        progress: _confirm,
                                        reveal: _reveal,
                                      ),
                                    ),
                                  ),
                                )
                              : KeyedSubtree(
                                  key: const ValueKey('thanks'),
                                  child: _ThanksBeat(
                                    metrics: m,
                                    orderNumber: widget.orderNumber,
                                    customerName: widget.customerName,
                                    headline: widget.thankYouHeadline,
                                    subtitle: widget.thankYouSubtitle,
                                    nameCardLabel: widget.nameCardLabel,
                                    receiptHeadline: widget.receiptHeadline,
                                    receiptSubtitle: widget.receiptSubtitle,
                                    noPaperLabel: widget.noPaperLabel,
                                    receiptUrl: widget.receiptUrl,
                                    progress: _thanks,
                                    reveal: _reveal,
                                  ),
                                ),
                        ),
                      ),
                      if (_beat == _Beat.thankYou)
                        Positioned(
                          left: m.sidePad,
                          width: m.cardWidth,
                          top: m.buttonTop,
                          child: _PlaceNewOrderButton(
                            metrics: m,
                            label: widget.placeNewOrderLabel,
                            closesInLabel: widget.closesInLabel,
                            secondsLeft: _secondsLeft,
                            totalSeconds: widget.countdownSeconds,
                            onTap: _leave,
                          ),
                        ),
                    ],
                  ),
                ),
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
            final double scale =
                0.86 + (0.14 * Curves.easeOutBack.transform(t));
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

/// Beat 2 — Figma POS node `2305:17116`: success badge, "THANK YOU!", the
/// customer's name (biggest element) over the order number in a black card,
/// and the receipt card with the QR code to the digital receipt.
class _ThanksBeat extends StatelessWidget {
  final _SuccessMetrics metrics;
  final String orderNumber;
  final String customerName;
  final String headline;
  final String subtitle;
  final String nameCardLabel;
  final String receiptHeadline;
  final String receiptSubtitle;
  final String noPaperLabel;
  final String receiptUrl;
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
    required this.customerName,
    required this.headline,
    required this.subtitle,
    required this.nameCardLabel,
    required this.receiptHeadline,
    required this.receiptSubtitle,
    required this.noPaperLabel,
    required this.receiptUrl,
    required this.progress,
    required this.reveal,
  });

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    final String name = customerName.trim().toUpperCase();
    final String orderLabel = orderNumber.trim().isEmpty
        ? ''
        : 'Order /${orderNumber.trim().replaceFirst(RegExp(r'^#'), '')}';

    // Every block sits at its Figma artboard coordinate (frame 2305:17116).
    return Stack(
      children: [
        // success-badge — 220px black disc, 110px white check (2305:17137).
        Positioned(
          top: m.badgeTop,
          left: 0,
          right: 0,
          child: Center(
            child: reveal(
              controller: progress,
              begin: 0.0,
              end: 0.42,
              s: m.s,
              rise: 24,
              builder: (t) => Transform.scale(
                scale: 0.86 + (0.14 * Curves.easeOutBack.transform(t)),
                child: Container(
                  width: m.badgeSize,
                  height: m.badgeSize,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                  ),
                  child: SvgPicture.asset(
                    Images.kioskThankYouCheckSvg,
                    width: m.badgeIconSize,
                    height: m.badgeIconSize,
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: m.thankYouTop,
          left: m.sidePad,
          width: m.cardWidth,
          child: reveal(
            controller: progress,
            begin: 0.1,
            end: 0.5,
            s: m.s,
            child: Text(
              headline,
              textAlign: TextAlign.center,
              maxLines: 1,
              style: loewExtraBold.copyWith(
                fontSize: m.thankYouSize,
                height: 1.0,
                color: _kInk,
              ),
            ),
          ),
        ),
        Positioned(
          top: m.subtitleTop,
          left: m.sidePad,
          width: m.cardWidth,
          child: reveal(
            controller: progress,
            begin: 0.18,
            end: 0.58,
            s: m.s,
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: swiss721Light.copyWith(
                fontSize: m.subtitleSize,
                height: 1.12,
                color: _kMuted,
              ),
            ),
          ),
        ),
        // Order number card (2305:17142).
        Positioned(
          top: m.nameCardTop,
          left: m.sidePad,
          width: m.cardWidth,
          child: reveal(
            controller: progress,
            begin: 0.22,
            end: 0.68,
            s: m.s,
            rise: 28,
            builder: (t) => Transform.scale(
              scale: 0.96 + (0.04 * t),
              child: Container(
                width: m.cardWidth,
                padding: EdgeInsets.symmetric(
                  horizontal: m.namePadH,
                  vertical: m.namePadV,
                ),
                decoration: BoxDecoration(
                  color: _kInk,
                  borderRadius: BorderRadius.circular(m.nameRadius),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      nameCardLabel,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: loewBold.copyWith(
                        fontSize: m.nameLabelSize,
                        height: 1.12,
                        letterSpacing: m.px(7.2),
                        color: const Color(0xFFBFBAAD),
                      ),
                    ),
                    SizedBox(height: m.nameInnerGap),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        name.isEmpty ? '—' : name,
                        maxLines: 1,
                        style: loewExtraBold.copyWith(
                          fontSize: m.nameSize,
                          height: 0.95,
                          letterSpacing: -m.px(11.2),
                          color: KioskUI.pageBg,
                        ),
                      ),
                    ),
                    if (orderLabel.isNotEmpty) ...[
                      SizedBox(height: m.nameInnerGap),
                      Text(
                        orderLabel,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        style: loewBold.copyWith(
                          fontSize: m.orderLabelSize,
                          height: 1.12,
                          color: const Color(0xFFD9D4C7),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        // Receipt card (2305:17146).
        Positioned(
          top: m.receiptTop,
          left: m.sidePad,
          width: m.cardWidth,
          child: reveal(
            controller: progress,
            begin: 0.32,
            end: 0.78,
            s: m.s,
            rise: 28,
            child: _ReceiptCard(
              metrics: m,
              headline: receiptHeadline,
              subtitle: receiptSubtitle,
              noPaperLabel: noPaperLabel,
              receiptUrl: receiptUrl,
            ),
          ),
        ),
      ],
    );
  }
}

/// The white receipt card: QR code to the digital receipt/live order status,
/// plus the "no paper receipt is printed" pill.
class _ReceiptCard extends StatelessWidget {
  final _SuccessMetrics metrics;
  final String headline;
  final String subtitle;
  final String noPaperLabel;
  final String receiptUrl;

  const _ReceiptCard({
    required this.metrics,
    required this.headline,
    required this.subtitle,
    required this.noPaperLabel,
    required this.receiptUrl,
  });

  @override
  Widget build(BuildContext context) {
    final m = metrics;

    final Widget qr = Container(
      padding: EdgeInsets.all(m.qrPad),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(m.qrRadius),
      ),
      child: QrImageView(
        data: receiptUrl,
        size: m.qrSize,
        backgroundColor: Colors.white,
        padding: EdgeInsets.zero,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: _kInk,
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: _kInk,
        ),
      ),
    );

    final Widget text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          headline,
          textAlign: TextAlign.start,
          style: loewExtraBold.copyWith(
            fontSize: m.receiptHeadlineSize,
            height: 1.0,
            color: _kInk,
          ),
        ),
        SizedBox(height: m.receiptGap),
        Text(
          subtitle,
          textAlign: TextAlign.start,
          style: swiss721Light.copyWith(
            fontSize: m.receiptSubtitleSize,
            height: 1.12,
            color: _kMuted,
          ),
        ),
        SizedBox(height: m.receiptGap),
        Container(
          padding: EdgeInsets.fromLTRB(
            m.pillPadH,
            m.pillPadV,
            m.px(44),
            m.pillPadV,
          ),
          decoration: BoxDecoration(
            color: KioskUI.pageBg,
            borderRadius: BorderRadius.circular(m.pillRadius),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                Images.kioskThankYouPhoneSvg,
                width: m.pillIconSize,
                height: m.pillIconSize,
                fit: BoxFit.contain,
              ),
              SizedBox(width: m.pillGap),
              Text(
                noPaperLabel,
                maxLines: 1,
                style: loewBold.copyWith(
                  fontSize: m.pillTextSize,
                  height: 1.12,
                  color: _kInk,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return Container(
      width: m.cardWidth,
      padding: EdgeInsets.fromLTRB(
        m.receiptPadH,
        m.receiptPadV,
        m.px(90),
        m.receiptPadV,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF8EF),
        border: Border.all(color: _kCardBorder, width: m.px(4)),
        borderRadius: BorderRadius.circular(m.receiptRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          qr,
          SizedBox(width: m.receiptCardGap),
          Expanded(child: text),
        ],
      ),
    );
  }
}

/// PLACE NEW ORDER, with the "Closes in" countdown ring on its right. Tapping
/// anywhere on the screen (including this button) fires [onTap] immediately;
/// the ring is purely a readout of [secondsLeft] / [totalSeconds].
class _PlaceNewOrderButton extends StatelessWidget {
  final _SuccessMetrics metrics;
  final String label;
  final String closesInLabel;
  final int secondsLeft;
  final int totalSeconds;
  final VoidCallback onTap;

  const _PlaceNewOrderButton({
    required this.metrics,
    required this.label,
    required this.closesInLabel,
    required this.secondsLeft,
    required this.totalSeconds,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    final double remainingFraction =
        totalSeconds <= 0 ? 0 : (secondsLeft / totalSeconds).clamp(0.0, 1.0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(m.buttonHeight),
        onTap: onTap,
        child: Container(
          height: m.buttonHeight,
          padding: EdgeInsets.symmetric(horizontal: m.buttonPadH),
          decoration: BoxDecoration(
            color: _kInk,
            borderRadius: BorderRadius.circular(m.buttonHeight),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: loewExtraBold.copyWith(
                      fontSize: m.buttonLabelSize,
                      color: KioskUI.pageBg,
                    ),
                  ),
                ),
              ),
              if (totalSeconds > 0) ...[
                SizedBox(width: m.buttonGap),
                Container(
                  width: m.dividerWidth,
                  height: m.dividerHeight,
                  color: KioskUI.pageBg.withValues(alpha: 0.25),
                ),
                SizedBox(width: m.buttonGap),
                Text(
                  closesInLabel,
                  maxLines: 1,
                  style: swiss721Light.copyWith(
                    fontSize: m.closesInSize,
                    color: const Color(0xFFBFBAAD),
                  ),
                ),
                SizedBox(width: m.buttonGap),
                SizedBox(
                  width: m.ringSize,
                  height: m.ringSize,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: Size(m.ringSize, m.ringSize),
                        painter: _CountdownRingPainter(
                          remainingFraction: remainingFraction,
                          strokeWidth: m.ringStroke,
                        ),
                      ),
                      Text(
                        '$secondsLeft',
                        style: loewExtraBold.copyWith(
                          fontSize: m.ringTextSize,
                          color: KioskUI.pageBg,
                        ),
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

/// Track + a clockwise-emptying arc of time remaining.
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
      ..color = KioskUI.pageBg.withValues(alpha: 0.25);
    canvas.drawArc(ring, 0, 2 * math.pi, false, track);

    final Paint arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = KioskUI.pageBg;
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

/// Figma "14 Thank you" artboard (POS node `2305:17116`).
const double _kArtboardW = 2572;
const double _kArtboardH = 4530;

/// Every value is an artboard pixel times ONE scale [s] — no per-element
/// floors, so the composition is the Figma frame at any kiosk size.
class _SuccessMetrics {
  final double s;
  const _SuccessMetrics(this.s);

  /// The whole artboard fits the available box (width- or height-bound).
  factory _SuccessMetrics.resolve(double width, double height) {
    final double s = math.min(
      math.min(width / _kArtboardW, height / _kArtboardH),
      1.0,
    );
    return _SuccessMetrics(s);
  }

  /// A designed measurement, in logical pixels.
  double px(double design) => design * s;

  // Wordmark (2305:17118): 680.8 x 178.5 at y 136, centred.
  double get logoTop => px(136);
  double get logoWidth => px(680.803);
  double get logoHeight => px(178.5);

  // Confirmed beat (drawn check + ORDER CONFIRMED!).
  double get checkWidth => px(420);
  double get checkHeight => checkWidth * (50 / 60.495);
  double get checkGap => px(48);
  double get confirmedSize => px(120);

  // Columns: 96px side inset, 2380px content width.
  double get sidePad => px(96);
  double get cardWidth => px(2380);

  // success-badge (2305:17137).
  double get badgeTop => px(822);
  double get badgeSize => px(220);
  double get badgeIconSize => px(110);

  double get thankYouTop => px(1132);
  double get thankYouSize => px(200);
  double get subtitleTop => px(1362);
  double get subtitleSize => px(84);

  // Order number card (2305:17142).
  double get nameCardTop => px(1626);
  double get namePadH => px(120);
  double get namePadV => px(170);
  double get nameRadius => px(64);
  double get nameLabelSize => px(60);
  double get nameInnerGap => px(30);
  double get nameSize => px(560);
  double get orderLabelSize => px(96);

  // Receipt card (2305:17146).
  double get receiptTop => px(2828);
  double get receiptPadH => px(80);
  double get receiptPadV => px(80);
  double get receiptRadius => px(56);
  double get receiptCardGap => px(90);
  double get receiptGap => px(30);
  double get receiptHeadlineSize => px(110);
  double get receiptSubtitleSize => px(72);
  double get qrPad => px(44);
  double get qrRadius => px(36);
  double get qrSize => px(560);
  double get pillPadH => px(40);
  double get pillPadV => px(24);
  double get pillRadius => 999;
  double get pillIconSize => px(50);
  double get pillGap => px(20);
  double get pillTextSize => px(56);

  // btn-done (2305:17308).
  double get buttonTop => px(4158);
  double get buttonHeight => px(252);
  double get buttonPadH => px(70);
  double get buttonGap => px(56);
  double get buttonLabelSize => px(112);
  double get dividerWidth => px(5.6);
  double get dividerHeight => px(100.8);
  double get closesInSize => px(75.6);
  double get ringSize => px(156.8);
  double get ringStroke => math.max(2, px(14));
  double get ringTextSize => px(58.8);
}
