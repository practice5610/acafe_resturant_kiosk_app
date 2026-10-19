import 'package:acafe_customer/features/pos/domain/pos_close_day_spec.dart';
import 'package:flutter/material.dart';

/// The Close Day modal's dismiss control, shared by both steps.
///
/// A [PosCloseDaySpec.closeButtonSize] cream disc with a drawn cross, inside a
/// [PosCloseDaySpec.closeHitSize] hit area whose right edge stays on the
/// content edge. It darkens on hover, sinks while pressed, rings in ink on
/// keyboard focus, and Enter / Space activate it.
class PosCloseDayCloseButton extends StatefulWidget {
  final VoidCallback onPressed;

  const PosCloseDayCloseButton({super.key, required this.onPressed});

  @override
  State<PosCloseDayCloseButton> createState() => _PosCloseDayCloseButtonState();
}

class _PosCloseDayCloseButtonState extends State<PosCloseDayCloseButton> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  late final Map<Type, Action<Intent>> _actions = <Type, Action<Intent>>{
    ActivateIntent: CallbackAction<ActivateIntent>(
      onInvoke: (_) {
        widget.onPressed();
        return null;
      },
    ),
  };

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final Color fill = _pressed
        ? PosCloseDaySpec.closeFillPressed
        : _hovered
            ? PosCloseDaySpec.closeFillHover
            : PosCloseDaySpec.closeFill;

    return Semantics(
      button: true,
      label: 'Close',
      child: FocusableActionDetector(
        actions: _actions,
        mouseCursor: SystemMouseCursors.click,
        onShowHoverHighlight: (bool value) => setState(() => _hovered = value),
        onShowFocusHighlight: (bool value) => setState(() => _focused = value),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          onTap: widget.onPressed,
          child: SizedBox.square(
            dimension: PosCloseDaySpec.closeHitSize,
            child: Align(
              alignment: Alignment.centerRight,
              child: AnimatedScale(
                scale: _pressed ? PosCloseDaySpec.closePressedScale : 1,
                duration: PosCloseDaySpec.closeStateDuration,
                curve: Curves.easeOut,
                child: AnimatedContainer(
                  duration: PosCloseDaySpec.closeStateDuration,
                  curve: Curves.easeOut,
                  width: PosCloseDaySpec.closeButtonSize,
                  height: PosCloseDaySpec.closeButtonSize,
                  decoration: BoxDecoration(
                    color: fill,
                    shape: BoxShape.circle,
                    border: _focused
                        ? Border.all(
                            color: PosCloseDaySpec.ink,
                            width: PosCloseDaySpec.closeFocusBorder,
                          )
                        : Border.all(color: PosCloseDaySpec.closeBorder),
                  ),
                  child: const CustomPaint(painter: _CrossPainter()),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A round-capped cross centred in the disc. Drawn rather than taken from an
/// icon font so it is crisp on the first frame on web, before fonts load.
class _CrossPainter extends CustomPainter {
  const _CrossPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const double half = PosCloseDaySpec.closeGlyphSize / 2;
    final Offset c = size.center(Offset.zero);
    final Paint stroke = Paint()
      ..color = PosCloseDaySpec.ink
      ..strokeWidth = PosCloseDaySpec.closeGlyphStroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(c.translate(-half, -half), c.translate(half, half), stroke);
    canvas.drawLine(c.translate(half, -half), c.translate(-half, half), stroke);
  }

  @override
  bool shouldRepaint(_CrossPainter oldDelegate) => false;
}
