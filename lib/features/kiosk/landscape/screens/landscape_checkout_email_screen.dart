import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:acafe_customer/features/kiosk/domain/kiosk_session.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_translate.dart';
import 'package:acafe_customer/features/kiosk/landscape/landscape_metrics.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_ui.dart';
import 'package:acafe_customer/helper/email_checker_helper.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';

// ===========================================================================
// LANDSCAPE KIOSK — checkout step 2, "Want a receipt?" (Option B).
// Figma TABLET Final Designs (option B), file egyp8Y2o5BtoJLo8SrcWrX, nodes:
//   2305:9717 — B-12c "Your email, keyboard open" (default state)
//   2305:9841 — B-12d "Your email, invalid"        (NEXT tapped, bad address)
// Full-screen 1366x1024 artboard. The docked keyboard here is a DIFFERENT
// Figma component ("Keyboard / Email", node 2305:3246) from the name screen's
// board: a smaller key module, no digit-row/shift split the same way, and two
// rows of email shortcut chips (symbols, then full domains) sit above the
// letters — so this screen draws its own keyboard rather than reusing
// `LandscapeKeyboard`, which doesn't model the chip rows.
// Portrait equivalent (untouched): kiosk_checkout_email_screen.dart.
// ===========================================================================

const Color _kPageBg = Color(0xFFF7F1DE);
const Color _kInk = Color(0xFF0D0D0D);
const Color _kHintColor = Color(0xFFB9B5A6);
const Color _kErrorColor = Color(0xFFCC3833);

const double _kBackSize = 52.875;
const double _kBackTop = 35;
const double _kBackLeft = 50;

const double _kStepBarTop = 30;
const double _kStepCircle = 47.965;
const double _kStepConnector = 73.401;
const double _kStepGap = 28;
const double _kStepLabelGap = 12;
const double _kStepLabelFont = 12;

const double _kTitleTop = 140.128;
const double _kTitleFont = 34;
const double _kSubtitleTop = 201.628;
const double _kSubtitleFont = 17;
const double _kFieldLabelTop = 248.128;
const double _kFieldLabelFont = 26;

const double _kRowLeft = 208;
const double _kFieldWidth = 525;
const double _kFieldHeight = 75;
const double _kFieldRadius = 15;
const double _kFieldBorder = 2;
const double _kFieldBorderError = 1.5;
const double _kFieldPadH = 32;
const double _kFieldFont = 20;

const double _kSkipButtonLeft = 748;
const double _kNextButtonLeft = 958;
const double _kButtonWidth = 200;
const double _kButtonHeight = 75;
const double _kButtonRadius = 12;
const double _kButtonFont = 18;
const double _kButtonBorder = 2.5;

const double _kErrorLeft = 212;
const double _kErrorFont = 15;

// --- docked keyboard — Figma node 2305:3246 ("Keyboard / Email") ----------
const double _kTrayRadius = 24;
const double _kTrayHeight = 616;

const double _kKbLeft = 256;
const double _kKbWidth = 854.315;

const double _kKeyW = 74.072;
const double _kKeyH = 66.432;
const double _kKeyGap = 6.643;
const double _kKeyRowGap = 9.3;
const double _kKeyRadius = 5.315;
const double _kKeyBorderWidth = 1.329;
const double _kKeyFont = 24;
const double _kKeyIcon = 26.573;

const double _kKeysSectionTop = 152.79;
const double _kKeysSectionPad = 26.573;

const double _kSpaceClearTop = 499.57;
const double _kSpaceClearLeft = 22.25;
const double _kSpaceW = 380.987;
const double _kClearLeft = 438.45;
const double _kClearW = 327.177;
const double _kSpaceClearFont = 18;

const Color _kChipBg = Colors.white;
const Color _kChipBorder = Color(0xFFF0EBD8);
const double _kChipBorderWidth = 2.657;
const double _kChipHeight = 66.432;
const double _kChipRadius = 21.258;
const double _kChipFontSymbol = 24;
const double _kChipFontWord = 18;

/// Symbol chips (row 1, Figma offsets relative to the Keyboard frame).
const List<_Chip> _kSymbolChips = [
  _Chip('@', left: 71.08, width: 79.718, font: _kChipFontSymbol),
  _Chip('.', left: 158.77, width: 79.718, font: _kChipFontSymbol),
  _Chip('-', left: 246.46, width: 79.718, font: _kChipFontSymbol),
  _Chip('_', left: 334.15, width: 79.718, font: _kChipFontSymbol),
  _Chip('.com', left: 421.84, width: 132.864, font: _kChipFontWord),
  _Chip('.nl', left: 562.68, width: 106.291, font: _kChipFontWord),
  _Chip('.be', left: 676.94, width: 106.291, font: _kChipFontWord),
];

/// Full-domain chips (row 2).
const double _kDomainRowTop = 74.4;
const List<_Chip> _kDomainChips = [
  _Chip('@gmail.com', left: 39.86, width: 179.366, font: _kChipFontWord),
  _Chip('@hotmail.com', left: 227.2, width: 199.296, font: _kChipFontWord),
  _Chip('@outlook.com', left: 434.46, width: 199.296, font: _kChipFontWord),
  _Chip('@icloud.com', left: 641.73, width: 172.723, font: _kChipFontWord),
];

class _Chip {
  final String label;
  final double left;
  final double width;
  final double font;
  const _Chip(this.label, {required this.left, required this.width, required this.font});
}

const List<String> _kDigits = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'];
const List<String> _kRowQ = ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'];
const List<String> _kRowA = ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L'];
const List<String> _kRowZ = ['Z', 'X', 'C', 'V', 'B', 'N', 'M'];

class LandscapeCheckoutEmailScreen extends StatefulWidget {
  const LandscapeCheckoutEmailScreen({super.key});

  @override
  State<LandscapeCheckoutEmailScreen> createState() =>
      _LandscapeCheckoutEmailScreenState();
}

class _LandscapeCheckoutEmailScreenState
    extends State<LandscapeCheckoutEmailScreen> {
  late final TextEditingController _controller =
      TextEditingController(text: KioskSession.instance.customerEmail);
  final FocusNode _focusNode = FocusNode();
  bool _showError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // --- on-screen keyboard editing (same selection-based pattern as the
  // landscape coupon dialog / name screen) --------------------------------

  TextSelection get _emailSelection {
    final TextSelection sel = _controller.selection;
    if (!sel.isValid) {
      return TextSelection.collapsed(offset: _controller.text.length);
    }
    return sel;
  }

  void _onEmailChanged(String _) {
    if (_showError) setState(() => _showError = false);
  }

  void _insertFromKeyboard(String text) {
    final TextSelection sel = _emailSelection;
    final String next = _controller.text.replaceRange(sel.start, sel.end, text);
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: sel.start + text.length),
    );
    _onEmailChanged(next);
  }

  void _backspaceFromKeyboard() {
    final TextSelection sel = _emailSelection;
    if (sel.start != sel.end) {
      final String next = _controller.text.replaceRange(sel.start, sel.end, '');
      _controller.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: sel.start),
      );
      _onEmailChanged(next);
      return;
    }
    if (sel.start <= 0) return;
    final String next =
        _controller.text.replaceRange(sel.start - 1, sel.start, '');
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: sel.start - 1),
    );
    _onEmailChanged(next);
  }

  void _clearFromKeyboard() {
    _controller.value = const TextEditingValue(
      text: '',
      selection: TextSelection.collapsed(offset: 0),
    );
    _onEmailChanged('');
  }

  void _next() {
    final String email = _controller.text.trim();
    if (email.isNotEmpty && EmailCheckerHelper.isNotValid(email)) {
      setState(() => _showError = true);
      return;
    }
    KioskSession.instance.customerEmail = email;
    RouterHelper.getKioskConfirmRoute();
  }

  void _skip() {
    KioskSession.instance.customerEmail = '';
    RouterHelper.getKioskConfirmRoute();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kPageBg,
      body: LayoutBuilder(
        builder: (context, c) {
          final double s = LandscapeMetrics.scaleFor(c.maxWidth, c.maxHeight);
          final double canvasW = LandscapeMetrics.designWidth * s;
          final double canvasH = LandscapeMetrics.designHeight * s;
          final double left = ((c.maxWidth - canvasW) / 2).clamp(0.0, c.maxWidth);
          final double top = ((c.maxHeight - canvasH) / 2).clamp(0.0, c.maxHeight);
          final double trayTop = _showError ? 422.0 : 408.0;

          return Stack(
            children: [
              Positioned(
                left: left,
                top: top,
                width: canvasW,
                height: canvasH,
                child: _Canvas(
                  s: s,
                  controller: _controller,
                  focusNode: _focusNode,
                  hasError: _showError,
                  onChanged: _onEmailChanged,
                  onNext: _next,
                  onSkip: _skip,
                ),
              ),
              Positioned(
                left: left,
                top: top + trayTop * s,
                width: canvasW,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {}, // swallow — keep focus on the field
                  child: _EmailKeyboardTray(
                    s: s,
                    onKey: _insertFromKeyboard,
                    onBackspace: _backspaceFromKeyboard,
                    onSpace: () => _insertFromKeyboard(' '),
                    onClear: _clearFromKeyboard,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Canvas extends StatelessWidget {
  final double s;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasError;
  final ValueChanged<String> onChanged;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _Canvas({
    required this.s,
    required this.controller,
    required this.focusNode,
    required this.hasError,
    required this.onChanged,
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: _kBackLeft * s,
          top: _kBackTop * s,
          child: KioskBackButton.scaled(
            s: s,
            size: _kBackSize,
            border: 2,
            icon: 22,
            fallback: RouterHelper.getKioskCheckoutRoute,
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: _kStepBarTop * s,
          child: Center(child: _StepBar(s: s)),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: _kTitleTop * s,
          child: Text(
            kioskTranslate(context, 'want_a_receipt', 'Want a receipt?'),
            textAlign: TextAlign.center,
            style: loewBold.copyWith(
                fontSize: _kTitleFont * s, height: 1.0, color: _kInk),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: _kSubtitleTop * s,
          child: Text(
            kioskTranslate(context, 'well_send_your_receipt_to_this_address',
                "We'll send your receipt to this address."),
            textAlign: TextAlign.center,
            style: loewRegular.copyWith(
                fontSize: _kSubtitleFont * s,
                height: 1.2,
                color: _kInk.withValues(alpha: 0.75)),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: _kFieldLabelTop * s,
          child: Text(
            kioskTranslate(context, 'email_optional', 'Email (optional)'),
            textAlign: TextAlign.center,
            style: loewBold.copyWith(
                fontSize: _kFieldLabelFont * s, height: 1.0, color: _kInk),
          ),
        ),
        Positioned(
          left: _kRowLeft * s,
          top: 298 * s,
          child: _Field(
            s: s,
            hasError: hasError,
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
            onSubmit: onNext,
          ),
        ),
        Positioned(
          left: _kSkipButtonLeft * s,
          top: 298 * s,
          child: _CheckoutButton(
            s: s,
            label: kioskTranslate(context, 'skip', 'Skip'),
            filled: false,
            onTap: onSkip,
          ),
        ),
        Positioned(
          left: _kNextButtonLeft * s,
          top: 298 * s,
          child: _CheckoutButton(
            s: s,
            label: kioskTranslate(context, 'next', 'Next'),
            filled: true,
            onTap: onNext,
          ),
        ),
        if (hasError)
          Positioned(
            left: _kErrorLeft * s,
            top: 381 * s,
            child: Text(
              kioskTranslate(context, 'email_not_correct_tap_skip',
                  "This email address doesn't look right. Check it or tap SKIP."),
              style: loewMedium.copyWith(
                  fontSize: _kErrorFont * s, height: 1.0, color: _kErrorColor),
            ),
          ),
      ],
    );
  }
}

class _StepBar extends StatelessWidget {
  final double s;
  const _StepBar({required this.s});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepNode(s: s, label: 'NAME', state: _StepState.completed),
        _Connector(s: s),
        _StepNode(s: s, label: 'EMAIL', state: _StepState.active),
        _Connector(s: s),
        _StepNode(s: s, label: 'PAYMENT', state: _StepState.upcoming),
      ],
    );
  }
}

enum _StepState { completed, active, upcoming }

class _StepNode extends StatelessWidget {
  final double s;
  final String label;
  final _StepState state;
  const _StepNode({required this.s, required this.label, required this.state});

  @override
  Widget build(BuildContext context) {
    final double d = _kStepCircle * s;
    final bool filled = state != _StepState.upcoming;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: d,
          height: d,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? Colors.black : Colors.transparent,
            border:
                Border.all(color: Colors.black, width: (2 * s).clamp(1.0, 3.0)),
          ),
          child: switch (state) {
            _StepState.active => Container(
                width: d * 0.4789,
                height: d * 0.4789,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: _kPageBg)),
            _StepState.completed =>
              Icon(Icons.check, size: d * 0.6, color: Colors.white),
            _StepState.upcoming => null,
          },
        ),
        SizedBox(height: _kStepLabelGap * s),
        Text(label,
            style: loewMedium.copyWith(
                fontSize: _kStepLabelFont * s, height: 1.0, color: Colors.black)),
      ],
    );
  }
}

class _Connector extends StatelessWidget {
  final double s;
  const _Connector({required this.s});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          top: (_kStepCircle / 2) * s,
          left: _kStepGap * s,
          right: _kStepGap * s),
      child: Container(
        width: _kStepConnector * s,
        height: (1.45 * s).clamp(1.0, 3.0),
        color: Colors.black,
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final double s;
  final bool hasError;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;

  const _Field({
    required this.s,
    required this.hasError,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _kFieldWidth * s,
      height: _kFieldHeight * s,
      padding: EdgeInsets.symmetric(horizontal: _kFieldPadH * s),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: const Color(0xFFFBF8EF),
        borderRadius: BorderRadius.circular(_kFieldRadius * s),
        border: Border.all(
          color: hasError ? _kErrorColor : const Color(0xFFB9B5A6),
          width: (hasError ? _kFieldBorderError : _kFieldBorder) * s,
        ),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: true,
        showCursor: true,
        keyboardType: TextInputType.none,
        textAlignVertical: TextAlignVertical.center,
        maxLines: 1,
        textInputAction: TextInputAction.done,
        onChanged: onChanged,
        onSubmitted: (_) => onSubmit(),
        selectAllOnFocus: false,
        autocorrect: false,
        enableSuggestions: false,
        cursorColor: _kInk,
        cursorWidth: (2 * s).clamp(1.0, 4.0),
        style: loewRegular.copyWith(
            fontSize: _kFieldFont * s, height: 1.0, color: Colors.black),
        decoration: InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          hintText:
              kioskTranslate(context, 'enter_your_email', 'Enter your email'),
          hintStyle: loewRegular.copyWith(
              fontSize: _kFieldFont * s, height: 1.0, color: _kHintColor),
        ),
      ),
    );
  }
}

class _CheckoutButton extends StatelessWidget {
  final double s;
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _CheckoutButton({
    required this.s,
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double radius = _kButtonRadius * s;
    return Material(
      color: filled ? const Color(0xFF0D0D0D) : _kPageBg,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: _kButtonWidth * s,
          height: _kButtonHeight * s,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: filled
                ? null
                : Border.all(
                    color: const Color(0xFF0D0D0D),
                    width: (_kButtonBorder * s).clamp(1.0, _kButtonBorder)),
          ),
          child: Text(
            label.toUpperCase(),
            style: loewBold.copyWith(
                fontSize: _kButtonFont * s,
                height: 1.0,
                color: filled ? const Color(0xFFF7F1DE) : const Color(0xFF0D0D0D)),
          ),
        ),
      ),
    );
  }
}

/// The docked email keyboard: two rows of shortcut chips, then the letters
/// board, all laid out at this screen's OWN measured Figma geometry (node
/// 2305:3246, "Keyboard / Email") — a different module size from the name
/// screen's board, with chip rows that `LandscapeKeyboard` doesn't model.
class _EmailKeyboardTray extends StatelessWidget {
  final double s;
  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;
  final VoidCallback onSpace;
  final VoidCallback onClear;

  const _EmailKeyboardTray({
    required this.s,
    required this.onKey,
    required this.onBackspace,
    required this.onSpace,
    required this.onClear,
  });

  Widget _charKey(String letter) => _Key(
        s: s,
        width: _kKeyW * s,
        label: letter,
        onTap: () => onKey(letter),
      );

  Widget _row(List<Widget> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < keys.length; i++) ...[
          if (i > 0) SizedBox(width: _kKeyGap * s),
          keys[i],
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: _kTrayHeight * s,
      decoration: BoxDecoration(
        color: _kPageBg,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(_kTrayRadius * s),
          topRight: Radius.circular(_kTrayRadius * s),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: _kKbLeft * s,
            top: 0,
            width: _kKbWidth * s,
            height: _kChipHeight * s,
            child: Stack(
              children: [
                for (final chip in _kSymbolChips)
                  Positioned(
                    left: chip.left * s,
                    top: 0,
                    width: chip.width * s,
                    height: _kChipHeight * s,
                    child: _EmailChipButton(
                        s: s,
                        label: chip.label,
                        font: chip.font,
                        onTap: () => onKey(chip.label)),
                  ),
              ],
            ),
          ),
          Positioned(
            left: _kKbLeft * s,
            top: _kDomainRowTop * s,
            width: _kKbWidth * s,
            height: _kChipHeight * s,
            child: Stack(
              children: [
                for (final chip in _kDomainChips)
                  Positioned(
                    left: chip.left * s,
                    top: 0,
                    width: chip.width * s,
                    height: _kChipHeight * s,
                    child: _EmailChipButton(
                        s: s,
                        label: chip.label,
                        font: chip.font,
                        onTap: () => onKey(chip.label)),
                  ),
              ],
            ),
          ),
          Positioned(
            left: _kKbLeft * s,
            top: _kKeysSectionTop * s,
            width: _kKbWidth * s,
            child: Padding(
              padding: EdgeInsets.all(_kKeysSectionPad * s),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _row([for (final d in _kDigits) _charKey(d)]),
                  SizedBox(height: _kKeyRowGap * s),
                  _row([for (final l in _kRowQ) _charKey(l)]),
                  SizedBox(height: _kKeyRowGap * s),
                  _row([for (final l in _kRowA) _charKey(l)]),
                  SizedBox(height: _kKeyRowGap * s),
                  _row([
                    _Key(
                      s: s,
                      width: _kKeyW * s,
                      icon: Images.kioskKeyShiftSvg,
                      onTap: () {},
                    ),
                    for (final l in _kRowZ) _charKey(l),
                    _Key(
                      s: s,
                      width: _kKeyW * s,
                      filled: true,
                      icon: Images.kioskKeyBackspaceSvg,
                      onTap: onBackspace,
                    ),
                  ]),
                ],
              ),
            ),
          ),
          Positioned(
            left: (_kKbLeft + _kSpaceClearLeft) * s,
            top: _kSpaceClearTop * s,
            child: Row(
              children: [
                _Key(
                  s: s,
                  width: _kSpaceW * s,
                  label: kioskTranslate(context, 'space', 'Space'),
                  fontSize: _kSpaceClearFont,
                  onTap: onSpace,
                ),
                SizedBox(width: (_kClearLeft - _kSpaceClearLeft - _kSpaceW) * s),
                _Key(
                  s: s,
                  width: _kClearW * s,
                  label: kioskTranslate(context, 'clear', 'Clear'),
                  fontSize: _kSpaceClearFont,
                  onTap: onClear,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One alphanumeric/control key — same press-inverts-fill convention as
/// `LandscapeKeyboard`'s keys, at this screen's own (smaller) module size.
class _Key extends StatefulWidget {
  final double s;
  final double width;
  final String? label;
  final String? icon;
  final double? fontSize;
  final bool filled;
  final VoidCallback onTap;

  const _Key({
    required this.s,
    required this.width,
    this.label,
    this.icon,
    this.fontSize,
    this.filled = false,
    required this.onTap,
  });

  @override
  State<_Key> createState() => _KeyState();
}

class _KeyState extends State<_Key> {
  bool _down = false;

  void _setDown(bool value) {
    if (_down == value) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final double s = widget.s;
    final bool dark = widget.filled || _down;
    final Color ink = dark ? _kPageBg : const Color(0xFF231F20);

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
          height: _kKeyH * s,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: dark ? Colors.black : const Color(0xFFFBF8EF),
            borderRadius: BorderRadius.circular(_kKeyRadius * s),
            border: Border.all(
              color: const Color(0xFFB9B5A6),
              width: (_kKeyBorderWidth * s).clamp(1.0, _kKeyBorderWidth),
            ),
          ),
          child: widget.icon != null
              ? SvgPicture.asset(
                  widget.icon!,
                  width: _kKeyIcon * s,
                  height: _kKeyIcon * s,
                  colorFilter: ColorFilter.mode(ink, BlendMode.srcIn),
                )
              : Text(
                  widget.label ?? '',
                  maxLines: 1,
                  style: loewMedium.copyWith(
                    fontSize: (widget.fontSize ?? _kKeyFont) * s,
                    height: 1.0,
                    color: ink,
                  ),
                ),
        ),
      ),
    );
  }
}

/// One email shortcut pill — white fill, cream border, fully rounded, per
/// Figma (distinct styling from the letter keys above).
class _EmailChipButton extends StatefulWidget {
  final double s;
  final String label;
  final double font;
  final VoidCallback onTap;

  const _EmailChipButton({
    required this.s,
    required this.label,
    required this.font,
    required this.onTap,
  });

  @override
  State<_EmailChipButton> createState() => _ChipState();
}

class _ChipState extends State<_EmailChipButton> {
  bool _down = false;

  void _setDown(bool value) {
    if (_down == value) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final double s = widget.s;
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
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _down ? Colors.black : _kChipBg,
            borderRadius: BorderRadius.circular(_kChipRadius * s),
            border: Border.all(
              color: _kChipBorder,
              width: (_kChipBorderWidth * s).clamp(1.0, _kChipBorderWidth),
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 6 * s),
              child: Text(
                widget.label,
                maxLines: 1,
                style: loewMedium.copyWith(
                  fontSize: widget.font * s,
                  height: 1.0,
                  color: _down ? Colors.white : const Color(0xFF241F20),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
