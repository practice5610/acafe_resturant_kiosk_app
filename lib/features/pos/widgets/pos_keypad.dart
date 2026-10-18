import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_payment_spec.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Reserved key tokens. Anything else in a [PosKeypad] row is emitted verbatim
/// through `onKey`, so a decimal separator is just a one-character token.
class PosKeypadKeys {
  PosKeypadKeys._();

  /// Backspace. Routed to `onBackspace`, never to `onKey`.
  static const String backspace = '<';

  /// Occupies a grid cell and renders nothing — used to keep a row three
  /// columns wide when it only has two live keys.
  static const String spacer = '';
}

/// Everything that differs between the two keypads in the POS.
///
/// The shift-PIN pad and the cash-tender pad are the same 4x3 grid with the
/// same press feedback and the same backspace routing; they disagree only on
/// paint. Keeping the difference in a value object is what lets one widget
/// serve both without either screen inheriting the other's look.
@immutable
class PosKeypadStyle {
  final double keyHeight;
  final double keyRadius;

  /// Horizontal gap between keys, and vertical gap between rows. Figma gives
  /// the cash pad 12 across and 8 down (1641:3849); the PIN pad uses 10 both
  /// ways.
  final double columnGap;
  final double rowGap;
  final double labelSize;
  final double labelHeight;
  final TextStyle labelStyle;
  final Color fill;
  final Color borderColor;
  final double borderWidth;
  final Color labelColor;
  final double iconSize;
  final Color iconColor;
  final String backspaceAsset;
  final List<BoxShadow> shadow;

  /// Optional per-key overrides for the backspace cell. Null falls back to the
  /// shared [fill] / [borderColor], so the PIN pad and the old cash pad are
  /// unaffected; the redesigned cash pad (node 1915:10294) tints its backspace
  /// key `#F0EBD8`.
  final Color? backspaceFill;
  final Color? backspaceBorderColor;

  const PosKeypadStyle({
    required this.keyHeight,
    required this.keyRadius,
    required this.columnGap,
    required this.rowGap,
    required this.labelSize,
    required this.labelHeight,
    required this.labelStyle,
    required this.fill,
    required this.borderColor,
    required this.borderWidth,
    required this.labelColor,
    required this.iconSize,
    required this.iconColor,
    required this.backspaceAsset,
    this.shadow = const [],
    this.backspaceFill,
    this.backspaceBorderColor,
  });
}

/// A 4x3 (or any shape) tap grid.
///
/// Keys flex equally across the available width rather than carrying fixed
/// pixel widths, so the grid stays correct at any container size — which is why
/// the same widget survives both a 460px PIN card and a payment column that
/// changes width with the window.
class PosKeypad extends StatelessWidget {
  /// Row-major key tokens. See [PosKeypadKeys] for the reserved ones.
  final List<List<String>> rows;
  final PosKeypadStyle style;

  /// Design-px multiplier. 1.0 for layouts that are already responsive by flex.
  final double scale;
  final bool enabled;

  /// Fired for every non-reserved token, verbatim.
  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;

  const PosKeypad({
    super.key,
    required this.rows,
    required this.style,
    required this.onKey,
    required this.onBackspace,
    this.scale = 1.0,
    this.enabled = true,
  });

  /// The standard phone/till arrangement, with [decimal] in the bottom-left
  /// cell. Pass [PosKeypadKeys.spacer] there for a digits-only pad.
  static List<List<String>> digitRows({String decimal = PosKeypadKeys.spacer}) =>
      [
        const ['1', '2', '3'],
        const ['4', '5', '6'],
        const ['7', '8', '9'],
        [decimal, '0', PosKeypadKeys.backspace],
      ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int r = 0; r < rows.length; r++) ...[
          if (r > 0) SizedBox(height: style.rowGap * scale),
          Row(
            children: [
              for (int c = 0; c < rows[r].length; c++) ...[
                if (c > 0) SizedBox(width: style.columnGap * scale),
                Expanded(
                  child: _Key(
                    token: rows[r][c],
                    style: style,
                    scale: scale,
                    enabled: enabled,
                    onKey: onKey,
                    onBackspace: onBackspace,
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _Key extends StatefulWidget {
  final String token;
  final PosKeypadStyle style;
  final double scale;
  final bool enabled;
  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;

  const _Key({
    required this.token,
    required this.style,
    required this.scale,
    required this.enabled,
    required this.onKey,
    required this.onBackspace,
  });

  @override
  State<_Key> createState() => _KeyState();
}

class _KeyState extends State<_Key> {
  bool _pressed = false;

  bool get _isSpacer => widget.token == PosKeypadKeys.spacer;

  void _fire() {
    if (widget.token == PosKeypadKeys.backspace) {
      widget.onBackspace();
    } else {
      widget.onKey(widget.token);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double s = widget.scale;
    final PosKeypadStyle style = widget.style;

    final bool isBackspace = widget.token == PosKeypadKeys.backspace;
    final Color keyFill =
        isBackspace ? (style.backspaceFill ?? style.fill) : style.fill;
    final Color keyBorder = isBackspace
        ? (style.backspaceBorderColor ?? style.borderColor)
        : style.borderColor;

    final Widget face = AnimatedScale(
      scale: _pressed ? 0.94 : 1.0,
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOut,
      child: Container(
        height: style.keyHeight * s,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: keyFill,
          borderRadius: BorderRadius.circular(style.keyRadius * s),
          border: Border.all(
            color: keyBorder,
            width: style.borderWidth,
          ),
          // Scaled with the pad so a shadow authored in design px does not
          // stay fixed while the keys around it shrink.
          boxShadow: [
            for (final BoxShadow shadow in style.shadow)
              BoxShadow(
                color: shadow.color,
                offset: shadow.offset * s,
                blurRadius: shadow.blurRadius * s,
                spreadRadius: shadow.spreadRadius * s,
              ),
          ],
        ),
        child: widget.token == PosKeypadKeys.backspace
            ? SvgPicture.asset(
                style.backspaceAsset,
                width: style.iconSize * s,
                height: style.iconSize * s,
                fit: BoxFit.contain,
                colorFilter:
                    ColorFilter.mode(style.iconColor, BlendMode.srcIn),
                placeholderBuilder: (_) => Icon(
                  Icons.backspace_outlined,
                  size: style.iconSize * s,
                  color: style.iconColor,
                ),
              )
            : Text(
                widget.token,
                style: style.labelStyle.copyWith(
                  fontSize: style.labelSize * s,
                  color: style.labelColor,
                  height: style.labelHeight,
                ),
              ),
      ),
    );

    if (_isSpacer) {
      // Occupies the grid cell and nothing else.
      return IgnorePointer(child: Opacity(opacity: 0, child: face));
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
      onTapCancel:
          widget.enabled ? () => setState(() => _pressed = false) : null,
      onTapUp: widget.enabled ? (_) => setState(() => _pressed = false) : null,
      onTap: widget.enabled ? _fire : null,
      child: face,
    );
  }
}

/// Compact 48px pad paint — Figma `numeric-keypad` (1641:3849). Used ONLY by
/// the close-day dialog; every payment screen uses [posPaymentKeypadStyle].
PosKeypadStyle posCompactKeypadStyle({required String backspaceAsset}) =>
    PosKeypadStyle(
      keyHeight: 48,
      keyRadius: 12,
      columnGap: 12,
      rowGap: 8,
      labelSize: 24,
      labelHeight: 29 / 24,
      labelStyle: loewExtraBold,
      fill: PosHomeSpec.tileBg,
      borderColor: PosHomeSpec.hairline,
      borderWidth: 1.5,
      labelColor: PosHomeSpec.ink,
      iconSize: 24,
      iconColor: PosHomeSpec.ink,
      backspaceAsset: backspaceAsset,
    );

/// The single payment keypad — Figma `numeric-keypad` (node **1915:10266**).
/// 78px keys, r12, 12px gaps (412x348 in a 412 column), Loew Bold 24,
/// `#D8D1BE` borders; the backspace cell takes a `#F0EBD8` fill.
PosKeypadStyle posPaymentKeypadStyle({required String backspaceAsset}) =>
    PosKeypadStyle(
      keyHeight: PosPaymentSpec.keyHeight,
      keyRadius: PosPaymentSpec.v2KeypadKeyRadius,
      columnGap: PosPaymentSpec.keyGap,
      rowGap: PosPaymentSpec.keyGap,
      labelSize: PosPaymentSpec.v2KeypadLabelSize,
      // Figma's 24px Bold line box is 29 (`leading-normal`).
      labelHeight: 29 / 24,
      labelStyle: loewBold,
      fill: PosHomeSpec.tileBg,
      borderColor: PosPaymentSpec.v2KeypadKeyBorder,
      borderWidth: PosPaymentSpec.v2KeypadKeyBorderWidth,
      labelColor: PosHomeSpec.ink,
      iconSize: PosPaymentSpec.v2KeypadBackspaceIconSize,
      iconColor: PosHomeSpec.ink,
      backspaceAsset: backspaceAsset,
      backspaceFill: PosPaymentSpec.v2KeypadBackspaceFill,
    );
