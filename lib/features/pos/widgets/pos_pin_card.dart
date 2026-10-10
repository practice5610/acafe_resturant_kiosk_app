import 'dart:math' as math;

import 'package:acafe_customer/features/pos/widgets/pos_keypad.dart';
import 'package:acafe_customer/features/pos/widgets/pos_wordmark.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  /// The card's natural height at full scale, covering its tallest variant (a
  /// header plus a reserved message line). Used alongside [board] so the card
  /// shrinks to fit a short viewport instead of overflowing it.
  static const double boardHeight = 800;

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

  // The parameters below were added for the staff lock screen. Every one is
  // optional and defaults to the card's original behaviour, so the manager
  // step-up modal, which passes none of them, renders exactly as before.

  /// Replaces the default "Enter Manager Code" heading (e.g. the staff lock
  /// screen passes "Hi Amir, enter your PIN"). An empty string hides the heading
  /// altogether, for a surface that already captions the card from outside (the
  /// lock-screen punch flow names the action in its own header).
  final String? title;

  /// A line under the PIN boxes -- a wrong-PIN note or a lockout countdown.
  final String? message;

  /// False freezes the keypad and the keyboard, for a lockout.
  final bool enabled;

  /// Submit on the last digit instead of waiting for Confirm. A till PIN is
  /// four digits typed dozens of times a shift; the extra tap is friction.
  final bool autoSubmit;

  /// Shown above the heading -- the lock screen puts the chosen person here.
  final Widget? header;

  /// Keeps a fixed line free under the boxes for [message]. Off by default:
  /// the step-up modal has no message and must keep its original height.
  final bool reserveMessageSpace;

  /// The confirm button's label. Defaults to the sign-in wording; the punch
  /// flow passes "PUNCH IN" / "PUNCH OUT" so the button names its own action
  /// instead of "VERIFY & LOGIN" on a screen that is not a login.
  final String confirmLabel;

  const PosPinCard({
    super.key,
    required this.onSubmit,
    this.pinLength = 6,
    this.title,
    this.message,
    this.enabled = true,
    this.autoSubmit = false,
    this.header,
    this.reserveMessageSpace = false,
    this.confirmLabel = 'VERIFY & LOGIN',
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
  late final FocusNode _focus;

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
    _focus = FocusNode(debugLabel: 'pos-pin-card');
    // Desktop / browser: grab keyboard as soon as the card mounts so staff
    // can type digits without tapping the on-screen keypad first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    _shake.dispose();
    super.dispose();
  }

  bool get _complete => _code.length == widget.pinLength;

  void _onDigit(String digit) {
    if (!widget.enabled || _submitting || _code.length >= widget.pinLength) {
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _code += digit);
    if (widget.autoSubmit && _complete) {
      _submit();
    }
  }

  void _onBackspace() {
    if (!widget.enabled || _submitting || _code.isEmpty) return;
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
    _focus.requestFocus();
  }

  /// Hardware keyboard: digits 0–9, Backspace/Delete, Enter/NumpadEnter.
  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (_submitting || !widget.enabled) return KeyEventResult.ignored;

    final LogicalKeyboardKey key = event.logicalKey;

    if (key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.delete) {
      _onBackspace();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (_complete) {
        _submit();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    final String? digit = _digitFromKey(key, event.character);
    if (digit != null) {
      _onDigit(digit);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  /// Accepts top-row digits, numpad digits, and the character fallback for
  /// layouts that don't map cleanly to [LogicalKeyboardKey.digit0]–`9`.
  static String? _digitFromKey(LogicalKeyboardKey key, String? character) {
    final Map<LogicalKeyboardKey, String> keys = <LogicalKeyboardKey, String>{
      LogicalKeyboardKey.digit0: '0',
      LogicalKeyboardKey.digit1: '1',
      LogicalKeyboardKey.digit2: '2',
      LogicalKeyboardKey.digit3: '3',
      LogicalKeyboardKey.digit4: '4',
      LogicalKeyboardKey.digit5: '5',
      LogicalKeyboardKey.digit6: '6',
      LogicalKeyboardKey.digit7: '7',
      LogicalKeyboardKey.digit8: '8',
      LogicalKeyboardKey.digit9: '9',
      LogicalKeyboardKey.numpad0: '0',
      LogicalKeyboardKey.numpad1: '1',
      LogicalKeyboardKey.numpad2: '2',
      LogicalKeyboardKey.numpad3: '3',
      LogicalKeyboardKey.numpad4: '4',
      LogicalKeyboardKey.numpad5: '5',
      LogicalKeyboardKey.numpad6: '6',
      LogicalKeyboardKey.numpad7: '7',
      LogicalKeyboardKey.numpad8: '8',
      LogicalKeyboardKey.numpad9: '9',
    };
    final String? fromKey = keys[key];
    if (fromKey != null) return fromKey;

    final String? ch = character?.trim();
    if (ch != null &&
        ch.length == 1 &&
        ch.compareTo('0') >= 0 &&
        ch.compareTo('9') <= 0) {
      return ch;
    }
    return null;
  }

  /// Damped oscillation: six half-cycles decaying to nothing over the run.
  double _shakeOffset(double t) => math.sin(t * math.pi * 6) * (1 - t) * 14;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKeyEvent,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => _focus.requestFocus(),
        // The card is its own artboard, built once at the full Figma size and
        // then scaled down by a FittedBox to fit whatever box the host gives --
        // on BOTH axes, never up. Letting the FittedBox measure the real card
        // means a short or narrow window can never clip the keypad or the confirm
        // button, no matter how tall the card's content happens to be.
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: AnimatedBuilder(
              animation: _shake,
              builder: (context, child) => Transform.translate(
                offset: Offset(_shakeOffset(_shake.value), 0),
                child: child,
              ),
              child: _card(1.0, PosPinSpec.board),
            ),
          ),
        ),
      ),
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
          if (widget.header != null)
            widget.header!
          else
            PosWordmark(height: PosPinSpec.wordmarkHeight * s),
          SizedBox(height: PosPinSpec.sectionGap * s),
          _pinInstructions(s),
          SizedBox(height: PosPinSpec.sectionGap * s),
          PosKeypad(
            // Row 4 leads with a spacer. Figma keeps a `key-comma` placeholder
            // there purely so the grid stays 3 columns wide; it renders
            // invisible in the design and is not interactive here. The cash
            // pad puts a live decimal key in the same cell.
            rows: PosKeypad.digitRows(),
            style: _pinKeypadStyle,
            scale: s,
            enabled: !_submitting && widget.enabled,
            onKey: _onDigit,
            onBackspace: _onBackspace,
          ),
          SizedBox(height: PosPinSpec.sectionGap * s),
          _ConfirmButton(
            scale: s,
            enabled: _complete && !_submitting && widget.enabled,
            busy: _submitting,
            label: widget.confirmLabel,
            onTap: _submit,
          ),
        ],
      ),
    );
  }

  Widget _pinInstructions(double s) {
    final String title = widget.title ?? 'Enter Manager Code';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // An empty title hides the heading (and its gap) entirely, so a surface
        // that captions the card from outside is not captioned twice.
        if (title.isNotEmpty) ...[
          Text(
            title,
            textAlign: TextAlign.center,
            style: loewBold.copyWith(
              fontSize: PosPinSpec.pinTitleSize * s,
              color: PosPinSpec.ink,
              height: 22 / 18, // Figma line box: 22px at 18px type.
            ),
          ),
          SizedBox(height: PosPinSpec.pinBlockGap * s),
        ],
        _PinBoxes(
          scale: s,
          length: widget.pinLength,
          filled: _code.length,
        ),
        // When reserved, held even while empty, so a message appearing does not
        // push the keypad down under the operator's finger mid-entry.
        if (widget.reserveMessageSpace || widget.message != null) ...[
          SizedBox(height: 12 * s),
          SizedBox(
            height: 36 * s,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              child: widget.message == null
                  ? const SizedBox.shrink()
                  : Text(
                      widget.message!,
                      key: ValueKey<String>(widget.message!),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: loewMedium.copyWith(
                        fontSize: 13 * s,
                        height: 1.35,
                        color: const Color(0xFFB4544A),
                      ),
                    ),
            ),
          ),
        ],
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

class _ConfirmButton extends StatelessWidget {
  final double scale;
  final bool enabled;
  final bool busy;
  final String label;
  final VoidCallback onTap;

  const _ConfirmButton({
    required this.scale,
    required this.enabled,
    required this.busy,
    required this.label,
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
                  label,
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

/// Shift-PIN pad paint. Held here rather than in `pos_keypad.dart` because
/// these are PIN-card values — the keypad widget itself is style-agnostic.
final PosKeypadStyle _pinKeypadStyle = PosKeypadStyle(
  keyHeight: PosPinSpec.keyHeight,
  keyRadius: PosPinSpec.keyRadius,
  columnGap: PosPinSpec.keyGap,
  rowGap: PosPinSpec.keyGap,
  labelSize: PosPinSpec.keyLabelSize,
  labelHeight: 26 / 22, // Figma line box: 26px at 22px type.
  labelStyle: loewBold,
  fill: PosPinSpec.keyFill,
  borderColor: PosPinSpec.inkAlpha(0.09),
  borderWidth: 1,
  labelColor: PosPinSpec.ink,
  iconSize: PosPinSpec.keyIconSize,
  iconColor: PosPinSpec.ink,
  backspaceAsset: Images.kioskKeyBackspaceSvg,
  shadow: [
    BoxShadow(
      color: PosPinSpec.inkAlpha(0.04),
      offset: const Offset(0, 1),
      blurRadius: 2,
    ),
  ],
);
