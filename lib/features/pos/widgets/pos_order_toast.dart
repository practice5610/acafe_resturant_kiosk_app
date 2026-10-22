import 'package:flutter/material.dart';
import 'package:acafe_customer/main.dart';
import 'package:acafe_customer/utill/dimensions.dart';
import 'package:acafe_customer/utill/styles.dart';

/// A bottom-right success toast for "order created".
///
/// Deliberately NOT a [SnackBar]: a floating snackbar sits over the bottom of
/// the screen and, while visible, swallows taps on whatever is behind it (the
/// confirm bar, the home grid) — which is the "it blocks other UI" the operator
/// hit. This instead drops an [OverlayEntry] on the **root** overlay (so it
/// rides through the navigation home) and wraps it in [IgnorePointer], so it
/// can NEVER intercept a tap: the UI underneath stays fully live while the toast
/// fades in, holds, and fades out on its own.
/// How long the toast stays fully opaque between the fade in and the fade out.
const Duration _kToastHold = Duration(seconds: 3);
const Duration _kToastFade = Duration(milliseconds: 220);

void showPosOrderToast(
  String message, {
  bool success = true,
  Duration hold = _kToastHold,
}) {
  final OverlayState? overlay = navigatorKey.currentState?.overlay;
  if (overlay == null) return;

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _PosOrderToast(
      message: message,
      success: success,
      hold: hold,
      onDone: () {
        if (entry.mounted) entry.remove();
      },
    ),
  );
  overlay.insert(entry);
}

class _PosOrderToast extends StatefulWidget {
  final String message;
  final bool success;
  final Duration hold;
  final VoidCallback onDone;

  const _PosOrderToast({
    required this.message,
    required this.success,
    required this.hold,
    required this.onDone,
  });

  @override
  State<_PosOrderToast> createState() => _PosOrderToastState();
}

class _PosOrderToastState extends State<_PosOrderToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    // One controller drives the whole life: fade in, hold, fade out. Doing it
    // this way (rather than a Future.delayed between two forward/reverse runs)
    // means the toast is nothing but a running animation, so a widget-test
    // pumpAndSettle advances it to completion and removes it cleanly -- a
    // standalone delay timer would be left pending and fail the test teardown.
    final int total =
        _kToastFade.inMilliseconds * 2 + widget.hold.inMilliseconds;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: total),
    );
    final double fadeFraction = _kToastFade.inMilliseconds / total;
    _opacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOut)),
        weight: fadeFraction,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 1 - 2 * fadeFraction),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: fadeFraction,
      ),
    ]).animate(_controller);
    _scale = Tween<double>(begin: 0.96, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: const Interval(0, 0.1, curve: Curves.easeOut)));

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onDone();
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    // IgnorePointer is the load-bearing bit: the toast paints but never takes a
    // tap, so everything behind it keeps working.
    return IgnorePointer(
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: EdgeInsets.only(
              right: Dimensions.paddingSizeLarge,
              bottom: Dimensions.paddingSizeLarge + media.padding.bottom,
            ),
            child: FadeTransition(
              opacity: _opacity,
              child: ScaleTransition(
                scale: _scale,
                alignment: Alignment.bottomRight,
                child: Material(
                  color: Colors.black,
                  elevation: 6,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 360),
                    padding: const EdgeInsets.symmetric(
                      horizontal: Dimensions.paddingSizeDefault,
                      vertical: Dimensions.paddingSizeDefault,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor:
                              widget.success ? Colors.green : Colors.red,
                          child: Icon(
                            widget.success
                                ? Icons.check
                                : Icons.close_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: Dimensions.paddingSizeSmall),
                        Flexible(
                          child: Text(
                            widget.message,
                            style: rubikBold.copyWith(
                              color: Colors.white,
                              fontSize: Dimensions.fontSizeDefault,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
