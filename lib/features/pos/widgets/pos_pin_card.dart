import 'dart:math' as math;

import 'package:acafe_customer/features/pos/widgets/pos_wordmark.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Design tokens for the POS PIN card, taken literally from the Figma frame
/// (POS file, `pin-login-column` **1641:8339**).
///
/// Deliberately local rather than routed through `PosUI` / `BrandColors`: the
/// design file names exact values for this screen, and the general brand tokens
/// differ from them (`#2B2B2B` vs `#241F20`). Matching the nearest token would
/// be a visible mismatch, so these are the literals.
class PosPinSpec {
  PosPinSpec._();

  /// The card is authored at this width. Everything below is a design-pixel
  /// value against it, and one scale factor (`cardWidth / board`) maps the
  /// whole card into whatever room it is given — so proportions are identical
  /// at every size, with no per-element clamps.
  static const double board = 460;

  static const Color pageBg = Color(0xFFF7F1DE);
  static const Color cardFill = Colors.white;
  static const Color ink = Color(0xFF241F20);
  static const Color keyFill = Color(0xFFFAFAF9);

  /// The design expresses every line and shadow as an alpha of the ink colour
  /// rather than a grey, which is what keeps them warm against the beige.
  static Color inkAlpha(double a) => ink.withValues(alpha: a);

  // Card
  static const double cardRadius = 28;
  static const double cardPadding = 40;
  static const double sectionGap = 32;

  // Wordmark — 137.305 x 36 in Figma; the shipped asset's viewBox ratio
  // (680.783 / 178.475 = 3.8144) matches 137.305 / 36 = 3.8140, i.e. it is the
  // same artwork.
  static const double wordmarkWidth = 137.305;
  static const double wordmarkHeight = 36;

  // PIN block
  static const double pinBlockGap = 24;
  static const double pinTitleSize = 18;
  static const double pinBoxHeight = 90;
  static const double pinBoxRadius = 16;
  static const double pinBoxGap = 7;
  static const double pinBoxBorder = 1.5;

  /// 11px in the design file (`pin-dot-filled-1` is 11x11, centred at x=24 in a
  /// 59-wide box — only an 11 lands dead centre).
  static const double pinDotSize = 11;

  /// Boxes are sized so that SIX would fill the content width, then however
  /// many are actually shown are centred. Keeping the box size independent of
  /// [PosPinCard.pinLength] means switching 4 <-> 6 does not resize them.
  static const int pinBoxReferenceCount = 6;

  // Keypad
  static const double keyGap = 10;
  static const double keyHeight = 64;
  static const double keyRadius = 18;
  static const double keyLabelSize = 22;
  static const double keyIconSize = 24;

  // Confirm button
  static const double confirmRadius = 999;
  static const double confirmVPadding = 18;
  static const double confirmLabelSize = 15;
  static const double confirmLetterSpacing = 1.0;

  /// Content width inside the card padding.
  static const double contentWidth = board - (cardPadding * 2); // 380
}

/// The POS shift-unlock card: wordmark, PIN boxes, numeric keypad, confirm.
///
/// Purely presentational plus its own entry state. It never calls an API,
/// reads a provider or navigates — [onSubmit] is the only way out, so the same
/// card can front the device PIN today and anything else later.
///
/// Sizing: the card is capped at [PosPinSpec.board] and shrinks to fit narrower
/// windows, with one scale factor derived from the width it actually got. That
/// is why it renders at exact Figma dimensions on any screen with room for it,
/// and degrades proportionally on a phone-width window, rather than being tied
/// to the landscape fit factor that drives the rest of POS.
class PosPinCard extends StatefulWidget {
  /// Digits required before the confirm button enables.
  ///
  /// The design draws six. The device credential this currently checks
  /// (`devices.configuration_code`) is a `varchar(4)` validated `digits:4`
  /// server-side, so a six-digit gate could never be satisfied — the host
  /// passes 4 until that changes. See POS_PIN_LOGIN_PHASE1.md.
  final int pinLength;

  /// Called with the completed PIN. Return false to reject: the card shakes and
  /// clears itself. The returned future also drives the in-button spinner, so
  /// the host does not have to plumb a loading flag back down.
  final Future<bool> Function(String pin) onSubmit;

  const PosPinCard({
    super.key,
    required this.onSubmit,
    this.pinLength = 6,
  });

  /// Identifies the painted card surface, so a test can measure the card itself
  /// rather than the box its parent handed the layout builder.
  static const Key surfaceKey = Key('pos-pin-card-surface');

  @override
  State<PosPinCard> createState() => _PosPinCardState();
}

class _PosPinCardState extends State<PosPinCard>
    with SingleTickerProviderStateMixin {
  String _code = '';
  bool _submitting = false;
  late final AnimationController _shake;

  @override
  void initState() {
    super.initState();
    // Timing and curve match the existing manager PIN modal
    // (kiosk_pin_entry_sheet.dart) so the two PIN surfaces in this product
    // reject a code the same way.
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  bool get _complete => _code.length == widget.pinLength;

  void _onDigit(String digit) {
    if (_submitting || _code.length >= widget.pinLength) return;
    HapticFeedback.selectionClick();
    setState(() => _code += digit);
  }

  void _onBackspace() {
    if (_submitting || _code.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _code = _code.substring(0, _code.length - 1));
  }

  Future<void> _submit() async {
    if (_submitting || !_complete) return;
    setState(() => _submitting = true);

    final bool accepted = await widget.onSubmit(_code);
    if (!mounted) return;

    setState(() => _submitting = false);
    if (accepted) return;

    await _shake.forward(from: 0);
    if (!mounted) return;
    setState(() => _code = '');
  }

  /// Damped oscillation: six half-cycles decaying to nothing over the run.
  double _shakeOffset(double t) => math.sin(t * math.pi * 6) * (1 - t) * 14;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // The card is its own artboard. It renders at exactly the Figma size
        // wherever there is room, and scales down proportionally where there
        // is not — never up, so it stays a card rather than becoming a page.
        final double available = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : PosPinSpec.board;
        final double cardWidth = math.min(available, PosPinSpec.board);
        final double s = cardWidth / PosPinSpec.board;

        // Centred inside whatever box the host gives, so a parent that hands
        // down a TIGHT width (an Expanded, a stretched Column child) cannot
        // override the card's own width and blow past the 460 board.
        return Center(
          child: AnimatedBuilder(
            animation: _shake,
            builder: (context, child) => Transform.translate(
              offset: Offset(_shakeOffset(_shake.value), 0),
              child: child,
            ),
            child: _card(s, cardWidth),
          ),
        );
      },
    );
  }

  Widget _card(double s, double cardWidth) {
    return Container(
      key: PosPinCard.surfaceKey,
      width: cardWidth,
      padding: EdgeInsets.all(PosPinSpec.cardPadding * s),
      decoration: BoxDecoration(
        color: PosPinSpec.cardFill,
        borderRadius: BorderRadius.circular(PosPinSpec.cardRadius * s),
        border: Border.all(color: PosPinSpec.inkAlpha(0.08)),
        boxShadow: [
          BoxShadow(
            color: PosPinSpec.inkAlpha(0.03),
            offset: Offset(0, 4 * s),
            blurRadius: 8 * s,
          ),
          BoxShadow(
            color: PosPinSpec.inkAlpha(0.08),
            offset: Offset(0, 20 * s),
            blurRadius: 30 * s,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Width is derived from the height inside PosWordmark, which is what
          // keeps the ratio right on an asset that declares
          // preserveAspectRatio="none".
          PosWordmark(height: PosPinSpec.wordmarkHeight * s),
          SizedBox(height: PosPinSpec.sectionGap * s),
          _pinInstructions(s),
          SizedBox(height: PosPinSpec.sectionGap * s),
          _Keypad(
            scale: s,
            enabled: !_submitting,
            onDigit: _onDigit,
            onBackspace: _onBackspace,
          ),
          SizedBox(height: PosPinSpec.sectionGap * s),
          _ConfirmButton(
            scale: s,
            enabled: _complete && !_submitting,
            busy: _submitting,
            onTap: _submit,
          ),
        ],
      ),
    );
  }

  Widget _pinInstructions(double s) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Enter Personal PIN',
          textAlign: TextAlign.center,
          style: loewBold.copyWith(
            fontSize: PosPinSpec.pinTitleSize * s,
            color: PosPinSpec.ink,
            height: 22 / 18, // Figma line box: 22px at 18px type.
          ),
        ),
        SizedBox(height: PosPinSpec.pinBlockGap * s),
        _PinBoxes(
          scale: s,
          length: widget.pinLength,
          filled: _code.length,
        ),
      ],
    );
  }
}

/// The row of PIN boxes. Boxes keep the design's 59x90 proportion regardless of
/// how many there are; the row is centred.
class _PinBoxes extends StatelessWidget {
  final double scale;
  final int length;
  final int filled;

  const _PinBoxes({
    required this.scale,
    required this.length,
    required this.filled,
  });

  @override
  Widget build(BuildContext context) {
    // Measured, not derived from PosPinSpec.contentWidth: the card's own 1px
    // border insets its child by 2px, so the constant is a hair wider than the
    // row actually gets and six boxes would overflow by exactly that.
    return LayoutBuilder(
      builder: (context, constraints) => _row(constraints.maxWidth),
    );
  }

  Widget _row(double rowWidth) {
    final double gap = PosPinSpec.pinBoxGap * scale;
    const int ref = PosPinSpec.pinBoxReferenceCount;
    final double boxWidth = (rowWidth - gap * (ref - 1)) / ref;

    return SizedBox(
      height: PosPinSpec.pinBoxHeight * scale,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (int i = 0; i < length; i++) ...[
            if (i > 0) SizedBox(width: gap),
            _PinBox(
              scale: scale,
              width: boxWidth,
              filled: i < filled,
            ),
          ],
        ],
      ),
    );
  }
}

class _PinBox extends StatelessWidget {
  final double scale;
  final double width;
  final bool filled;

  const _PinBox({
    required this.scale,
    required this.width,
    required this.filled,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      width: width,
      height: PosPinSpec.pinBoxHeight * scale,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(PosPinSpec.pinBoxRadius * scale),
        border: Border.all(
          color: filled ? PosPinSpec.ink : PosPinSpec.inkAlpha(0.2),
          width: PosPinSpec.pinBoxBorder * scale,
        ),
      ),
      child: Center(
        child: PosPinDot(filled: filled, size: PosPinSpec.pinDotSize * scale),
      ),
    );
  }
}

/// The filled indicator inside a PIN box.
///
/// Public so a test can assert how many digits are showing without reaching
/// for whichever animation primitive happens to implement it.
class PosPinDot extends StatelessWidget {
  final bool filled;
  final double size;

  const PosPinDot({super.key, required this.filled, required this.size});

  @override
  Widget build(BuildContext context) {
    // The dot springs in rather than hard-cutting: at a counter this is touched
    // dozens of times a shift, and the slight overshoot is what reads as "that
    // registered".
    return AnimatedScale(
      scale: filled ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 180),
      curve: filled ? Curves.easeOutBack : Curves.easeIn,
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: PosPinSpec.ink,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// 4x3 keypad. Keys flex equally across the content width rather than carrying
/// fixed pixel widths, so the grid stays correct at any card size.
class _Keypad extends StatelessWidget {
  final double scale;
  final bool enabled;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  const _Keypad({
    required this.scale,
    required this.enabled,
    required this.onDigit,
    required this.onBackspace,
  });

  @override
  Widget build(BuildContext context) {
    const List<List<String>> rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      // Row 4 leads with an invisible key. Figma keeps a `key-comma`
      // placeholder there purely so the grid stays 3 columns wide; it renders
      // invisible in the design and is not interactive here.
      ['', '0', '<'],
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int r = 0; r < rows.length; r++) ...[
          if (r > 0) SizedBox(height: PosPinSpec.keyGap * scale),
          Row(
            children: [
              for (int c = 0; c < rows[r].length; c++) ...[
                if (c > 0) SizedBox(width: PosPinSpec.keyGap * scale),
                Expanded(
                  child: _Key(
                    token: rows[r][c],
                    scale: scale,
                    enabled: enabled,
                    onDigit: onDigit,
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
  final double scale;
  final bool enabled;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  const _Key({
    required this.token,
    required this.scale,
    required this.enabled,
    required this.onDigit,
    required this.onBackspace,
  });

  @override
  State<_Key> createState() => _KeyState();
}

class _KeyState extends State<_Key> {
  bool _pressed = false;

  bool get _isSpacer => widget.token.isEmpty;

  void _fire() {
    if (widget.token == '<') {
      widget.onBackspace();
    } else {
      widget.onDigit(widget.token);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double s = widget.scale;

    final Widget face = AnimatedScale(
      scale: _pressed ? 0.94 : 1.0,
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOut,
      child: Container(
        height: PosPinSpec.keyHeight * s,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: PosPinSpec.keyFill,
          borderRadius: BorderRadius.circular(PosPinSpec.keyRadius * s),
          border: Border.all(color: PosPinSpec.inkAlpha(0.09)),
          boxShadow: [
            BoxShadow(
              color: PosPinSpec.inkAlpha(0.04),
              offset: Offset(0, 1 * s),
              blurRadius: 2 * s,
            ),
          ],
        ),
        child: widget.token == '<'
            ? SvgPicture.asset(
                Images.kioskKeyBackspaceSvg,
                width: PosPinSpec.keyIconSize * s,
                height: PosPinSpec.keyIconSize * s,
                fit: BoxFit.contain,
                colorFilter: const ColorFilter.mode(
                  PosPinSpec.ink,
                  BlendMode.srcIn,
                ),
              )
            : Text(
                widget.token,
                style: loewBold.copyWith(
                  fontSize: PosPinSpec.keyLabelSize * s,
                  color: PosPinSpec.ink,
                  height: 26 / 22, // Figma line box: 26px at 22px type.
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

class _ConfirmButton extends StatelessWidget {
  final double scale;
  final bool enabled;
  final bool busy;
  final VoidCallback onTap;

  const _ConfirmButton({
    required this.scale,
    required this.enabled,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double s = scale;
    final double labelHeight = PosPinSpec.confirmLabelSize * s * (18 / 15);

    final Widget button = Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: PosPinSpec.confirmVPadding * s),
      decoration: BoxDecoration(
        color: PosPinSpec.ink,
        borderRadius: BorderRadius.circular(PosPinSpec.confirmRadius),
        boxShadow: [
          BoxShadow(
            color: PosPinSpec.inkAlpha(0.08),
            offset: Offset(0, 2 * s),
            blurRadius: 4 * s,
          ),
          BoxShadow(
            color: PosPinSpec.inkAlpha(0.2),
            offset: Offset(0, 8 * s),
            blurRadius: 12 * s,
          ),
        ],
      ),
      child: SizedBox(
        // Pinned so swapping the label for the spinner cannot resize the
        // button mid-verify.
        height: labelHeight,
        child: Center(
          child: busy
              ? SizedBox(
                  width: labelHeight * 0.85,
                  height: labelHeight * 0.85,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  'VERIFY & LOGIN',
                  style: loewBold.copyWith(
                    fontSize: PosPinSpec.confirmLabelSize * s,
                    color: Colors.white,
                    letterSpacing: PosPinSpec.confirmLetterSpacing * s,
                    height: 1.0,
                  ),
                ),
        ),
      ),
    );

    return Opacity(
      opacity: enabled || busy ? 1.0 : 0.4,
      child: IgnorePointer(
        ignoring: !enabled,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: button,
        ),
      ),
    );
  }
}
