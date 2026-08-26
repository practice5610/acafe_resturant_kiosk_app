import 'package:flutter/material.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_translate.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Full QWERTY on-screen keyboard for kiosk entry screens, built from the
/// Figma POS artboard (node 1385:15500 — "07 – Coupon: Enter Code").
///
/// Every measurement below is a raw Figma pixel from the 2572px-wide artboard
/// multiplied by [s], so the board keeps the designed key module, gaps and
/// corner radii at any size. The caller owns the scale (see
/// `KioskCouponScreen`), which lets the same board sit inside screens that
/// resolve their scale from width *or* height.
///
/// Layout (Figma):
///   • four key rows — digits, QWERTY, ASDFGHJKL, shift + ZXCVBNM + backspace
///   • 223 x 200 keys, 20px column gap, 28px row gap, 16px radius, 4px border
///   • an 80px gap, then the wide Space (1147) / Clear (985) pair, 43px apart
class KioskKeyboard extends StatelessWidget {
  /// Figma pixel → logical pixel scale.
  final double s;

  /// Whether letter keys currently type (and render) upper case.
  final bool shift;

  /// Receives the character to insert, already cased per [shift].
  final ValueChanged<String> onKey;

  final VoidCallback onShift;
  final VoidCallback onBackspace;
  final VoidCallback onSpace;
  final VoidCallback onClear;

  const KioskKeyboard({
    super.key,
    required this.s,
    required this.shift,
    required this.onKey,
    required this.onShift,
    required this.onBackspace,
    required this.onSpace,
    required this.onClear,
  });

  // --- Figma palette -------------------------------------------------------
  static const Color keyFill = Color(0xFFFBF8EF);
  static const Color keyBorder = Color(0xFFB9B5A6);
  static const Color keyInk = Color(0xFF231F20);
  static const Color keyInverseInk = Color(0xFFFBF8EF);

  // --- Figma geometry (2572px artboard) ------------------------------------
  static const double keyW = 223;
  static const double keyH = 200;
  static const double keyGap = 20;
  static const double rowGap = 28;
  static const double keyRadius = 16;
  static const double keyBorderWidth = 4;
  static const double keyFont = 72;
  static const double keyIcon = 80;
  static const double spaceRowGap = 80;
  static const double spaceW = 1147;
  static const double clearW = 985;
  static const double spaceClearGap = 43;

  /// Height this widget occupies at scale 1 — four rows, the gap, and the
  /// Space/Clear row. Screens use it to budget their vertical rhythm.
  static const double designHeight =
      keyH * 4 + rowGap * 3 + spaceRowGap + keyH; // 884 + 80 + 200

  static const List<String> _digits = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'];
  static const List<String> _rowQ = ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'];
  static const List<String> _rowA = ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L'];
  static const List<String> _rowZ = ['Z', 'X', 'C', 'V', 'B', 'N', 'M'];

  String _cased(String letter) => shift ? letter : letter.toLowerCase();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _row([for (final d in _digits) _charKey(d)]),
        SizedBox(height: rowGap * s),
        _row([for (final l in _rowQ) _charKey(l)]),
        SizedBox(height: rowGap * s),
        _row([for (final l in _rowA) _charKey(l)]),
        SizedBox(height: rowGap * s),
        _row([
          _KioskKey(
            s: s,
            width: keyW * s,
            asset: Images.kioskKeyShiftSvg,
            // The Figma board renders upper-case caps with a plain shift key;
            // the caps themselves are the state indicator, so the key keeps its
            // designed fill in both modes.
            onTap: onShift,
          ),
          for (final l in _rowZ) _charKey(l),
          _KioskKey(
            s: s,
            width: keyW * s,
            asset: Images.kioskKeyBackspaceSvg,
            filled: true,
            onTap: onBackspace,
          ),
        ]),
        SizedBox(height: spaceRowGap * s),
        _row([
          _KioskKey(
            s: s,
            width: spaceW * s,
            label: kioskTranslate(context, 'space', 'Space'),
            onTap: onSpace,
          ),
          _KioskKey(
            s: s,
            width: clearW * s,
            label: kioskTranslate(context, 'clear', 'Clear'),
            onTap: onClear,
          ),
        ], gap: spaceClearGap * s),
      ],
    );
  }

  Widget _charKey(String letter) => _KioskKey(
        s: s,
        width: keyW * s,
        label: _cased(letter),
        onTap: () => onKey(_cased(letter)),
      );

  Widget _row(List<Widget> keys, {double? gap}) {
    final double g = gap ?? keyGap * s;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < keys.length; i++) ...[
          if (i > 0) SizedBox(width: g),
          keys[i],
        ],
      ],
    );
  }
}

/// One key. Presses invert the fill so a 200px-tall target still gives the
/// customer feedback on a screen with no hover state.
class _KioskKey extends StatefulWidget {
  final double s;
  final double width;
  final String? label;
  final String? asset;

  /// Permanently inked key — the backspace, per Figma.
  final bool filled;
  final VoidCallback onTap;

  const _KioskKey({
    required this.s,
    required this.width,
    this.label,
    this.asset,
    this.filled = false,
    required this.onTap,
  });

  @override
  State<_KioskKey> createState() => _KioskKeyState();
}

class _KioskKeyState extends State<_KioskKey> {
  bool _down = false;

  void _setDown(bool value) {
    if (_down == value) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final double s = widget.s;
    final bool dark = widget.filled || _down;
    final Color ink = dark ? KioskKeyboard.keyInverseInk : KioskKeyboard.keyInk;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setDown(true),
        onTapUp: (_) => _setDown(false),
        onTapCancel: () => _setDown(false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          width: widget.width,
          height: KioskKeyboard.keyH * s,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: dark ? Colors.black : KioskKeyboard.keyFill,
            borderRadius: BorderRadius.circular(KioskKeyboard.keyRadius * s),
            border: Border.all(
              color: KioskKeyboard.keyBorder,
              width: (KioskKeyboard.keyBorderWidth * s).clamp(1.0, 4.0),
            ),
          ),
          child: widget.asset != null
              ? SvgPicture.asset(
                  widget.asset!,
                  width: KioskKeyboard.keyIcon * s,
                  height: KioskKeyboard.keyIcon * s,
                  colorFilter: ColorFilter.mode(ink, BlendMode.srcIn),
                )
              : Text(
                  widget.label ?? '',
                  maxLines: 1,
                  style: loewMedium.copyWith(
                    fontSize: KioskKeyboard.keyFont * s,
                    height: 1.0,
                    color: ink,
                  ),
                ),
        ),
      ),
    );
  }
}
