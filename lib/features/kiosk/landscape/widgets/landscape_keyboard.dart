import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:acafe_customer/features/kiosk/domain/kiosk_translate.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';

/// Shared docked on-screen keyboard for the landscape kiosk (Option B).
///
/// Every landscape screen that needs text entry (the coupon pop-up, the name
/// screen, …) docks one of these at the bottom of the window. The Figma
/// artboards draw a *different* key module per screen — the coupon pop-up's
/// board is smaller than the name screen's — so every geometry number is a
/// constructor parameter rather than a constant; callers pass their own
/// screen's raw Figma pixels (already multiplied by that screen's own [s]).
/// This mirrors the portrait `KioskKeyboard`'s own per-screen scale contract.
class LandscapeKeyboard extends StatelessWidget {
  /// Design-px → logical-px scale, already resolved by the caller.
  final double s;

  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;
  final VoidCallback onSpace;
  final VoidCallback onClear;

  /// Hides the leading 1234567890 row (e.g. a name field has no use for it).
  final bool showDigitRow;

  /// Shows a caps/shift key before Z — some artboards draw one, others don't.
  final bool showShift;
  final bool shift;
  final VoidCallback? onShift;

  // --- geometry (raw Figma px at the artboard's own scale) ------------------
  final double keyWidth;
  final double keyHeight;
  final double keyGap;
  final double rowGap;
  final double keyRadius;
  final double keyBorderWidth;
  final double keyFont;
  final double iconSize;

  final double trayHeight;
  final double trayPaddingV;
  final double trayRadius;
  final double trayBorderWidth;

  final double spaceRowGap;
  final double spaceWidth;
  final double clearWidth;
  final double spaceClearGap;
  final double spaceClearFont;

  const LandscapeKeyboard({
    super.key,
    required this.s,
    required this.onKey,
    required this.onBackspace,
    required this.onSpace,
    required this.onClear,
    required this.keyWidth,
    required this.keyHeight,
    required this.keyGap,
    required this.rowGap,
    required this.keyRadius,
    required this.keyBorderWidth,
    required this.keyFont,
    required this.iconSize,
    required this.trayHeight,
    required this.trayPaddingV,
    required this.spaceRowGap,
    required this.spaceWidth,
    required this.clearWidth,
    required this.spaceClearGap,
    required this.spaceClearFont,
    this.trayRadius = 24,
    this.trayBorderWidth = 2,
    this.showDigitRow = false,
    this.showShift = false,
    this.shift = false,
    this.onShift,
  });

  static const Color trayBg = Color(0xFFF7F1DE);
  static const Color trayBorder = Color(0xFFDED8C6);
  static const Color keyFill = Color(0xFFFBF8EF);
  static const Color keyBorder = Color(0xFFB9B5A6);
  static const Color keyInk = Color(0xFF231F20);

  static const List<String> _digits = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'];
  static const List<String> _rowQ = ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'];
  static const List<String> _rowA = ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L'];
  static const List<String> _rowZ = ['Z', 'X', 'C', 'V', 'B', 'N', 'M'];

  String _cased(String letter) => shift ? letter : letter.toLowerCase();

  Widget _charKey(String letter) => _LandscapeKey(
        s: s,
        width: keyWidth * s,
        height: keyHeight * s,
        radius: keyRadius * s,
        borderWidth: keyBorderWidth * s,
        fontSize: keyFont * s,
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

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: trayHeight * s,
      padding: EdgeInsets.symmetric(vertical: trayPaddingV * s),
      decoration: BoxDecoration(
        color: trayBg,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(trayRadius * s),
          topRight: Radius.circular(trayRadius * s),
        ),
        border: Border(
          top: BorderSide(color: trayBorder, width: trayBorderWidth * s),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (showDigitRow) ...[
            _row([for (final d in _digits) _charKey(d)]),
            SizedBox(height: rowGap * s),
          ],
          _row([for (final l in _rowQ) _charKey(l)]),
          SizedBox(height: rowGap * s),
          _row([for (final l in _rowA) _charKey(l)]),
          SizedBox(height: rowGap * s),
          _row([
            if (showShift)
              _LandscapeKey(
                s: s,
                width: keyWidth * s,
                height: keyHeight * s,
                radius: keyRadius * s,
                borderWidth: keyBorderWidth * s,
                fontSize: keyFont * s,
                icon: Images.kioskKeyShiftSvg,
                iconSize: iconSize * s,
                onTap: onShift ?? () {},
              ),
            for (final l in _rowZ) _charKey(l),
            _LandscapeKey(
              s: s,
              width: keyWidth * s,
              height: keyHeight * s,
              radius: keyRadius * s,
              borderWidth: keyBorderWidth * s,
              fontSize: keyFont * s,
              filled: true,
              icon: Images.kioskKeyBackspaceSvg,
              iconSize: iconSize * s,
              onTap: onBackspace,
            ),
          ]),
          SizedBox(height: spaceRowGap * s),
          _row([
            _LandscapeKey(
              s: s,
              width: spaceWidth * s,
              height: keyHeight * s,
              radius: keyRadius * s,
              borderWidth: keyBorderWidth * s,
              label: kioskTranslate(context, 'space', 'Space'),
              fontSize: spaceClearFont * s,
              onTap: onSpace,
            ),
            _LandscapeKey(
              s: s,
              width: clearWidth * s,
              height: keyHeight * s,
              radius: keyRadius * s,
              borderWidth: keyBorderWidth * s,
              label: kioskTranslate(context, 'clear', 'Clear'),
              fontSize: spaceClearFont * s,
              onTap: onClear,
            ),
          ], gap: spaceClearGap * s),
        ],
      ),
    );
  }
}

/// One key. Presses invert the fill so the customer gets feedback on a
/// screen with no hover state, same convention as the portrait keyboard.
class _LandscapeKey extends StatefulWidget {
  final double s;
  final double width;
  final double height;
  final double radius;
  final double borderWidth;
  final double? fontSize;
  final String? label;
  final String? icon;
  final double? iconSize;
  final bool filled;
  final VoidCallback onTap;

  const _LandscapeKey({
    required this.s,
    required this.width,
    required this.height,
    required this.radius,
    required this.borderWidth,
    this.fontSize,
    this.label,
    this.icon,
    this.iconSize,
    this.filled = false,
    required this.onTap,
  });

  @override
  State<_LandscapeKey> createState() => _LandscapeKeyState();
}

class _LandscapeKeyState extends State<_LandscapeKey> {
  bool _down = false;

  void _setDown(bool value) {
    if (_down == value) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final bool dark = widget.filled || _down;
    final Color ink = dark ? LandscapeKeyboard.trayBg : LandscapeKeyboard.keyInk;

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
          height: widget.height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: dark ? Colors.black : LandscapeKeyboard.keyFill,
            borderRadius: BorderRadius.circular(widget.radius),
            border: Border.all(
              color: LandscapeKeyboard.keyBorder,
              width: widget.borderWidth.clamp(1.0, widget.borderWidth <= 0 ? 1.0 : widget.borderWidth),
            ),
          ),
          child: widget.icon != null
              ? SvgPicture.asset(
                  widget.icon!,
                  width: widget.iconSize,
                  height: widget.iconSize,
                  colorFilter: ColorFilter.mode(ink, BlendMode.srcIn),
                )
              : Text(
                  widget.label ?? '',
                  maxLines: 1,
                  style: loewMedium.copyWith(
                    fontSize: widget.fontSize,
                    height: 1.0,
                    color: ink,
                  ),
                ),
        ),
      ),
    );
  }
}
