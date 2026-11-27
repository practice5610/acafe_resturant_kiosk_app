import 'package:acafe_customer/features/kiosk/domain/kiosk_chrome_spec.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_navigation_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:acafe_customer/features/kiosk/domain/kiosk_session.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_translate.dart';
import 'package:acafe_customer/features/kiosk/landscape/landscape_metrics.dart';
import 'package:acafe_customer/features/kiosk/landscape/widgets/landscape_keyboard.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_ui.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:acafe_customer/utill/styles.dart';

// ===========================================================================
// LANDSCAPE KIOSK — checkout step 1, "What's your name?" (Option B).
// Figma TABLET Final Designs (option B), file egyp8Y2o5BtoJLo8SrcWrX, nodes:
//   2305:9623 — B-12a "Your name, keyboard open" (default state)
//   2305:9746 — B-12b "Your name, empty error"   (NEXT tapped, name empty)
// Full-screen 1366x1024 artboard (not a pop-up like the coupon dialogs).
// Portrait equivalent (untouched): kiosk_checkout_name_screen.dart.
// ===========================================================================

const Color _kPageBg = Color(0xFFF7F1DE);
const Color _kInk = Color(0xFF0D0D0D);
const Color _kSubtitleInk = Color(0xFF231F20);
const Color _kHintColor = Color(0xFFB9B5A6);
const Color _kErrorBorder = Color(0xFFCC3833);
const Color _kErrorText = Color(0xFFCC3833);

const double _kBackSize = 52.875;
const double _kBackTop = 35;
const double _kBackLeft = 50;

const double _kStepBarTop = 30;
const double _kStepCircle = 47.965;
const double _kStepConnector = 73.401;
const double _kStepGap = 28; // approximated side gap either side of a connector
const double _kStepLabelGap = 12;
const double _kStepLabelFont = 12;

const double _kTitleTop = 140.128;
const double _kTitleFont = 34;
const double _kSubtitleTop = 201.628;
const double _kSubtitleFont = 18;
const double _kFieldLabelTop = 250.628;
const double _kFieldLabelFont = 26;

const double _kRowLeft = 208;
const double _kRowTop = 300.5;
const double _kFieldWidth = 525;
const double _kFieldHeight = 75;
const double _kFieldRadius = 15;
const double _kFieldBorder = 2;
const double _kFieldBorderError = 1.5;
const double _kFieldPadH = 32;
const double _kFieldFont = 20;

const double _kFieldButtonGap = 15; // 748 - (208 + 525)
const double _kButtonWidth = 410;
const double _kButtonHeight = 75;
const double _kButtonRadius = 12;
const double _kButtonFont = 18;

const double _kErrorTop = 383.5;
const double _kErrorLeft = 212;
const double _kErrorFont = 15;

// --- docked keyboard — Figma node 2305:9647 ("Keyboard") ------------------
const double _kKeyW = 107.586;
const double _kKeyH = 96.49;
const double _kKeyGap = 9.649;
const double _kKeyRowGap = 19.298;
const double _kKeyRadius = 7.719;
const double _kKeyBorderWidth = 1.93;
const double _kKeyFont = 24;
const double _kKeyIcon = 38.596;

const double _kTrayRadius = 24;
const double _kTrayBorderWidth = 2;
const double _kTrayHeight = 613.5;
const double _kTrayPaddingV = 57.894;

const double _kSpaceRowGap = 19.298;
const double _kSpaceW = 553.369;
const double _kClearW = 475.212;
const double _kSpaceClearGap = 12.426; // 609.814 - (43.419 + 553.369)
const double _kSpaceClearFont = 18;

const int _kMaxNameLength = 60;

class LandscapeCheckoutNameScreen extends StatefulWidget {
  const LandscapeCheckoutNameScreen({super.key});

  @override
  State<LandscapeCheckoutNameScreen> createState() =>
      _LandscapeCheckoutNameScreenState();
}

class _LandscapeCheckoutNameScreenState
    extends State<LandscapeCheckoutNameScreen> {
  late final TextEditingController _controller =
      TextEditingController(text: KioskSession.instance.customerName);
  final FocusNode _focusNode = FocusNode();
  bool _showError = false;
  bool _shift = true;

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

  // --- on-screen keyboard editing -------------------------------------------
  // Same selection-based insert/backspace/clear pattern as the landscape
  // coupon dialog and the portrait name screen.

  TextSelection get _nameSelection {
    final TextSelection sel = _controller.selection;
    if (!sel.isValid) {
      return TextSelection.collapsed(offset: _controller.text.length);
    }
    return sel;
  }

  void _onNameChanged(String _) {
    if (_showError) setState(() => _showError = false);
  }

  void _insertFromKeyboard(String text) {
    final TextSelection sel = _nameSelection;
    final String next =
        _controller.text.replaceRange(sel.start, sel.end, text);
    if (next.length > _kMaxNameLength) return;
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: sel.start + text.length),
    );
    _onNameChanged(next);
  }

  void _backspaceFromKeyboard() {
    final TextSelection sel = _nameSelection;
    if (sel.start != sel.end) {
      final String next = _controller.text.replaceRange(sel.start, sel.end, '');
      _controller.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: sel.start),
      );
      _onNameChanged(next);
      return;
    }
    if (sel.start <= 0) return;
    final String next =
        _controller.text.replaceRange(sel.start - 1, sel.start, '');
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: sel.start - 1),
    );
    _onNameChanged(next);
  }

  void _clearFromKeyboard() {
    _controller.value = const TextEditingValue(
      text: '',
      selection: TextSelection.collapsed(offset: 0),
    );
    _onNameChanged('');
  }

  void _next() {
    final String name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _showError = true);
      return;
    }
    KioskSession.instance.customerName = name;
    RouterHelper.getKioskCheckoutEmailRoute();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kPageBg,
      body: LayoutBuilder(
        builder: (context, c) {
          final double s =
              LandscapeMetrics.scaleFor(c.maxWidth, c.maxHeight);
          final double canvasW = LandscapeMetrics.designWidth * s;
          final double canvasH = LandscapeMetrics.designHeight * s;
          final double left = ((c.maxWidth - canvasW) / 2).clamp(0.0, c.maxWidth);
          final double top = ((c.maxHeight - canvasH) / 2).clamp(0.0, c.maxHeight);

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
                  onChanged: _onNameChanged,
                  onNext: _next,
                ),
              ),
              Positioned(
                left: left,
                top: top + (_kTrayTopFor(_showError) * s),
                width: canvasW,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {}, // swallow — keep focus on the field
                  child: LandscapeKeyboard(
                    s: s,
                    shift: _shift,
                    onShift: () => setState(() => _shift = !_shift),
                    showShift: true,
                    onKey: _insertFromKeyboard,
                    onBackspace: _backspaceFromKeyboard,
                    onSpace: () => _insertFromKeyboard(' '),
                    onClear: _clearFromKeyboard,
                    keyWidth: _kKeyW,
                    keyHeight: _kKeyH,
                    keyGap: _kKeyGap,
                    rowGap: _kKeyRowGap,
                    keyRadius: _kKeyRadius,
                    keyBorderWidth: _kKeyBorderWidth,
                    keyFont: _kKeyFont,
                    iconSize: _kKeyIcon,
                    trayHeight: _kTrayHeight,
                    trayPaddingV: _kTrayPaddingV,
                    trayRadius: _kTrayRadius,
                    trayBorderWidth: _kTrayBorderWidth,
                    spaceRowGap: _kSpaceRowGap,
                    spaceWidth: _kSpaceW,
                    clearWidth: _kClearW,
                    spaceClearGap: _kSpaceClearGap,
                    spaceClearFont: _kSpaceClearFont,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// The keyboard tray shifts down 14px in the error state (B-12b), matching
  /// the inline error row pushing it below the field block.
  static double _kTrayTopFor(bool hasError) => hasError ? 424.5 : 410.5;
}

class _Canvas extends StatelessWidget {
  final double s;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasError;
  final ValueChanged<String> onChanged;
  final VoidCallback onNext;

  const _Canvas({
    required this.s,
    required this.controller,
    required this.focusNode,
    required this.hasError,
    required this.onChanged,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: _kBackLeft * s,
          top: _kBackTop * s,
          child: KioskBackButton(
            // Landscape variant: never larger than it is today.
            s: KioskChrome.scaleOf(
                context, _kBackSize * s / KioskChromeSpec.backDiameter),
            onTap: () => KioskNavigationHelper.backTo(
                context, RouterHelper.kioskCartScreen),
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
            kioskTranslate(context, 'whats_your_name', "What's your name?"),
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
            kioskTranslate(context, 'well_use_your_name_pickup',
                "We'll use your name when your order is ready for pick up."),
            textAlign: TextAlign.center,
            style: swiss721Light.copyWith(
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
            kioskTranslate(context, 'name', 'Name'),
            textAlign: TextAlign.center,
            style: loewBold.copyWith(
                fontSize: _kFieldLabelFont * s, height: 1.0, color: _kInk),
          ),
        ),
        Positioned(
          left: _kRowLeft * s,
          top: _kRowTop * s,
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
          left: (_kRowLeft + _kFieldWidth + _kFieldButtonGap) * s,
          top: _kRowTop * s,
          child: _NextButton(s: s, onTap: onNext),
        ),
        if (hasError)
          Positioned(
            left: _kErrorLeft * s,
            top: _kErrorTop * s,
            child: Text(
              kioskTranslate(context, 'please_enter_your_name_to_continue',
                  'Please enter your name to continue.'),
              style: loewMedium.copyWith(
                  fontSize: _kErrorFont * s, height: 1.0, color: _kErrorText),
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
        _StepNode(s: s, label: 'NAME', state: _StepState.active),
        _Connector(s: s),
        _StepNode(s: s, label: 'EMAIL', state: _StepState.upcoming),
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
          color: hasError ? _kErrorBorder : const Color(0xFFB9B5A6),
          width: (hasError ? _kFieldBorderError : _kFieldBorder) * s,
        ),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: true,
        showCursor: true,
        // Suppresses the platform keyboard — every visible key comes from
        // the docked `LandscapeKeyboard` instead.
        keyboardType: TextInputType.none,
        textAlignVertical: TextAlignVertical.center,
        maxLines: 1,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        onChanged: onChanged,
        onSubmitted: (_) => onSubmit(),
        selectAllOnFocus: false,
        autocorrect: false,
        enableSuggestions: false,
        cursorColor: _kSubtitleInk,
        cursorWidth: (2 * s).clamp(1.0, 4.0),
        inputFormatters: [
          LengthLimitingTextInputFormatter(_kMaxNameLength),
        ],
        style: loewRegular.copyWith(
            fontSize: _kFieldFont * s, height: 1.0, color: _kSubtitleInk),
        decoration: InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          hintText: kioskTranslate(context, 'enter_your_name', 'Enter your name'),
          hintStyle: loewRegular.copyWith(
              fontSize: _kFieldFont * s, height: 1.0, color: _kHintColor),
        ),
      ),
    );
  }
}

class _NextButton extends StatelessWidget {
  final double s;
  final VoidCallback onTap;
  const _NextButton({required this.s, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF0D0D0D),
      borderRadius: BorderRadius.circular(_kButtonRadius * s),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: _kButtonWidth * s,
          height: _kButtonHeight * s,
          child: Center(
            child: Text(
              kioskTranslate(context, 'next', 'NEXT').toUpperCase(),
              style: loewBold.copyWith(
                  fontSize: _kButtonFont * s,
                  height: 1.0,
                  color: const Color(0xFFF7F1DE)),
            ),
          ),
        ),
      ),
    );
  }
}
