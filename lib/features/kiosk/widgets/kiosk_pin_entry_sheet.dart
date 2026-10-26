import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show KeyDownEvent, KeyEvent, KeyRepeatEvent, LogicalKeyboardKey;
import 'package:acafe_customer/features/kiosk/widgets/kiosk_scrim.dart';
import 'package:acafe_customer/common/widgets/custom_asset_image_widget.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_manager_provider.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_tap.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:acafe_customer/theme/text_legibility.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:provider/provider.dart';

// Brand palette for this modal only (not a shared kiosk theme token set).
const Color _kSurface = Color(0xFFF7F3EC);
const Color _kInk = Color(0xFF232323);
const Color _kAccent = Color(0xFFC8A97E);
const Color _kDanger = Color(0xFFC8544A);
const Color _kKeyFace = Color(0xFFFFFFFF);
const Color _kKeyPressed = Color(0xFFF0E8D9);

/// The card is authored once, in design pixels, at this size. Every child
/// below uses raw design values -- no per-element `* s`, no per-element
/// clamps. One [BoxFit.contain] at the top scales the whole card into
/// whatever window it lands in, so the proportions are identical from a
/// 390px phone preview to a 1080x1920 kiosk.
///
/// 680 wide against a ~806 tall stack is a deliberate ratio: a 620 card was
/// noticeably narrower than it was tall, which reads as a phone dialog
/// stretched onto a kiosk rather than as a designed panel.
const double _kCardWidth = 680;

/// Upper bound on that single scale. Without it the card would inflate to
/// fill a 4K panel. Kept modest on purpose: at 1.4 the card ate ~90% of a
/// 1080 kiosk's width and read as a full-screen takeover rather than a
/// modal, so it stays close to its authored size and lets the blurred menu
/// breathe around it.
const double _kMaxScale = 1.05;

/// Breathing room kept between the card and the window edge, as a fraction of
/// the window on each axis (with a floor for very small windows). The margin
/// is what keeps the card off the edges on a phone-sized preview, where the
/// width cap above is not the binding constraint.
const double _kMarginFraction = 0.07;
const double _kMinMargin = 24;

/// Opens the manager PIN modal; on a correct code, navigates to the POS
/// Manager Dashboard. Call this from the top-bar manager icon rather than
/// navigating to the dashboard route directly -- the PIN check is the gate.
///
/// A centered, blurred-scrim dialog (not a bottom sheet) so the card floats
/// as one cohesive unit with rounded corners on every side. Tapping the
/// scrim outside the card dismisses it.
Future<void> openKioskManagerAccess(BuildContext context) async {
  final unlocked = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Manager access',
    barrierColor: Colors.transparent, // the sheet paints its own blurred scrim
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (context, animation, secondaryAnimation) =>
        const KioskPinEntrySheet(),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final Animation<double> eased =
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: eased,
        child: ScaleTransition(
          scale: Tween(begin: 0.94, end: 1.0).animate(eased),
          child: child,
        ),
      );
    },
  );

  if (unlocked == true && context.mounted) {
    RouterHelper.getKioskManagerDashboardRoute();
  }
}

class KioskPinEntrySheet extends StatefulWidget {
  /// The card's heading, prompt and button. Default to the manager-code copy.
  final String title;
  final String prompt;
  final String submitLabel;

  /// Checks a typed PIN somewhere other than the manager code: returns null to
  /// close the pad with success, or a one-line reason to show and stay open.
  /// Null keeps the original manager-code flow ([KioskManagerProvider]).
  final Future<String?> Function(String pin)? onSubmitPin;

  const KioskPinEntrySheet({
    super.key,
    this.title = 'Manager access',
    this.prompt = 'Enter your 4-digit code to unlock',
    this.submitLabel = 'Unlock',
    this.onSubmitPin,
  });

  @override
  State<KioskPinEntrySheet> createState() => _KioskPinEntrySheetState();
}

class _KioskPinEntrySheetState extends State<KioskPinEntrySheet>
    with SingleTickerProviderStateMixin {
  String _code = '';
  late final AnimationController _shakeController;

  /// Lets staff type the PIN on a physical keyboard, not only the on-screen
  /// pad: a till often has a real keyboard, and typing the code is faster.
  final FocusNode _keyboardFocus = FocusNode(debugLabel: 'kiosk-pin-keyboard');

  // State for [KioskPinEntrySheet.onSubmitPin]; the manager flow keeps its own
  // on KioskManagerProvider.
  String? _error;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
  }

  @override
  void dispose() {
    _keyboardFocus.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  /// Physical-keyboard entry. Digits (top row and numpad) type the PIN,
  /// Backspace deletes, Enter submits, Escape closes -- mirroring the pad.
  static final Map<LogicalKeyboardKey, String> _digitKeys = {
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

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final LogicalKeyboardKey key = event.logicalKey;

    final String? digit = _digitKeys[key];
    if (digit != null) {
      _onDigit(digit);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace) {
      _onBackspace();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _submit();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      _close();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _close() => Navigator.of(context).pop(false);

  void _onDigit(String digit) {
    if (_code.length >= 4) return;
    if (widget.onSubmitPin == null) {
      final provider = context.read<KioskManagerProvider>();
      if (provider.pinError != null) provider.clearPinError();
    } else if (_error != null) {
      setState(() => _error = null);
    }
    setState(() => _code += digit);
    if (_code.length == 4) _submit();
  }

  void _onBackspace() {
    if (_code.isEmpty) return;
    setState(() => _code = _code.substring(0, _code.length - 1));
  }

  void _onClear() => setState(() => _code = '');

  Future<void> _submit() async {
    final code = _code;
    if (code.length != 4) return;

    final Future<String?> Function(String pin)? check = widget.onSubmitPin;
    final bool ok;
    if (check != null) {
      if (_checking) return;
      setState(() => _checking = true);
      final String? error = await check(code);
      if (!mounted) return;
      setState(() {
        _checking = false;
        _error = error;
      });
      ok = error == null;
    } else {
      ok = await context.read<KioskManagerProvider>().verifyPin(code);
    }
    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      await _shakeController.forward(from: 0);
      if (!mounted) return;
      setState(() => _code = '');
    }
  }

  double _shakeOffset(double t) {
    final double wave = sin(t * pi * 6);
    final double decay = 1 - t;
    return wave * decay * 14;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onSubmitPin != null) {
      return _buildSheet(context, error: _error, loading: _checking);
    }
    return Consumer<KioskManagerProvider>(
      builder: (context, provider, _) => _buildSheet(
        context,
        // The manager card has always shown its own fixed copy for a miss.
        error: provider.pinError == null ? null : 'Wrong code, try again',
        loading: provider.verifyingPin,
      ),
    );
  }

  Widget _buildSheet(
    BuildContext context, {
    required String? error,
    required bool loading,
  }) {
    // Focus (autofocus) catches physical-keyboard input for the whole sheet,
    // so staff can type the PIN as well as tap the pad. It wraps everything,
    // including the scrim, so a key press is caught wherever focus sits.
    //
    // Material (transparent) provides the DefaultTextStyle every Text below
    // relies on. Without it, text rendered inside showGeneralDialog falls
    // back to the framework debug style -> yellow double underline.
    // Transparency paints nothing, so the blurred scrim is untouched.
    return Focus(
      focusNode: _keyboardFocus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Shared frosted scrim. It sits under the card and is the only
          // opaque hit target on this layer, so any tap that misses the
          // card -- including inside the sizing box around it -- closes.
          KioskScrim(
            animation: ModalRoute.of(context)?.animation ??
                kAlwaysCompleteAnimation,
            onDismiss: _close,
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Margin grows with the window so the card never sits flush
                // against the edge on a large panel, and never wastes half
                // a phone screen on a small one.
                final double hMargin = max(
                    _kMinMargin, constraints.maxWidth * _kMarginFraction);
                final double vMargin = max(
                    _kMinMargin, constraints.maxHeight * _kMarginFraction);

                // The width cap enforces _kMaxScale; the box height is
                // whatever the window leaves. BoxFit.contain then takes the
                // smaller of the two ratios, so the card always fits both
                // ways -- no overflow, no scrolling, no clipped keypad.
                final double boxWidth = min(
                  max(constraints.maxWidth - hMargin * 2, 1),
                  _kCardWidth * _kMaxScale,
                );
                final double boxHeight =
                    max(constraints.maxHeight - vMargin * 2, 1);

                return Center(
                  child: SizedBox(
                    width: boxWidth,
                    height: boxHeight,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: GestureDetector(
                        // Swallows taps on the card itself so they never
                        // reach the dismissing scrim underneath.
                        onTap: () {},
                        child: AnimatedBuilder(
                          animation: _shakeController,
                          builder: (context, child) => Transform.translate(
                            offset: Offset(
                                _shakeOffset(_shakeController.value), 0),
                            child: child,
                          ),
                          child: _ManagerCard(
                            title: widget.title,
                            prompt: widget.prompt,
                            submitLabel: widget.submitLabel,
                            codeLength: _code.length,
                            error: error,
                            loading: loading,
                            onDigit: _onDigit,
                            onBackspace: _onBackspace,
                            onClear: _onClear,
                            onSubmit: _submit,
                            onClose: _close,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      ),
    );
  }
}

/// One column on every screen size -- badge, title, dots, keypad, unlock.
/// There is no side-by-side variant: a PIN pad reads as a single vertical
/// gesture, and splitting it left/right made the card wider than the windows
/// it had to fit.
class _ManagerCard extends StatelessWidget {
  final String title;
  final String prompt;
  final String submitLabel;
  final int codeLength;

  /// The one-line reason the last PIN was refused, or null.
  final String? error;
  final bool loading;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final VoidCallback onSubmit;
  final VoidCallback onClose;

  const _ManagerCard({
    required this.title,
    required this.prompt,
    required this.submitLabel,
    required this.codeLength,
    required this.error,
    required this.loading,
    required this.onDigit,
    required this.onBackspace,
    required this.onClear,
    required this.onSubmit,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasError = error != null;

    return Container(
      width: _kCardWidth,
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(36),
        // Hairline highlight along the top edge -- the detail that separates a
        // floating panel from a flat rectangle once the scrim blurs behind it.
        border: Border.all(color: Colors.white.withValues(alpha: 0.65)),
        boxShadow: [
          // Broad ambient shadow for lift. Kept light and pulled in with a
          // negative spread -- a heavy one paints a visible dark bar under
          // the card instead of reading as depth.
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 52,
            spreadRadius: -16,
            offset: const Offset(0, 24),
          ),
          // ...plus a tight contact shadow so the edge stays defined.
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(44, 40, 44, 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _LockBadge(hasError: hasError),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: loewMedium.copyWith(
                      fontSize: 38, color: _kInk, letterSpacing: -0.3),
                ),
                const SizedBox(height: 8),
                // Fixed height so swapping in the error copy never nudges the
                // keypad up or down mid-shake.
                SizedBox(
                  height: 30,
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 160),
                      style: loewRegular.copyWith(
                        fontSize: 22,
                        color: hasError ? TextTones.danger : TextTones.hint,
                      ),
                      // Scales down rather than wrapping: the row is fixed height.
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          error ?? prompt,
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                _PinDotsRow(filled: codeLength, hasError: hasError),
                const SizedBox(height: 28),
                _ManagerKeypad(
                  onDigit: onDigit,
                  onBackspace: onBackspace,
                  onClear: onClear,
                ),
                const SizedBox(height: 28),
                _UnlockButton(
                  label: submitLabel,
                  loading: loading,
                  enabled: codeLength == 4,
                  onTap: onSubmit,
                ),
              ],
            ),
          ),
          // Top-right corner of the card, not hanging off the badge.
          Positioned(top: 22, right: 22, child: _CloseButton(onTap: onClose)),
        ],
      ),
    );
  }
}

/// Lock mark: a soft accent halo, a solid inner disc, and the brand glyph.
class _LockBadge extends StatelessWidget {
  final bool hasError;
  const _LockBadge({required this.hasError});

  @override
  Widget build(BuildContext context) {
    final Color tint = hasError ? _kDanger : _kAccent;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: tint.withValues(alpha: 0.14),
      ),
      alignment: Alignment.center,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 74,
        height: 74,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              tint.withValues(alpha: 0.48),
              tint.withValues(alpha: 0.26),
            ],
          ),
        ),
        alignment: Alignment.center,
        child: CustomAssetImageWidget(
          Images.managerAccessSvg,
          width: 34,
          height: 34,
          color: hasError ? _kDanger : _kInk,
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 46,
      child: KioskTap(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          ),
          child: Icon(Icons.close_rounded,
              size: 22, color: _kInk.withValues(alpha: 0.55)),
        ),
      ),
    );
  }
}

class _PinDotsRow extends StatelessWidget {
  final int filled;
  final bool hasError;
  const _PinDotsRow({required this.filled, required this.hasError});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) {
        final bool isFilled = i < filled;
        final Color tint = hasError ? _kDanger : _kAccent;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutBack,
            width: isFilled ? 22 : 18,
            height: isFilled ? 22 : 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isFilled
                  ? (hasError ? _kDanger : _kInk)
                  : _kInk.withValues(alpha: 0.04),
              border: Border.all(
                color: isFilled ? Colors.transparent : tint.withValues(alpha: 0.75),
                width: 1.8,
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _ManagerKeypad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onClear;

  const _ManagerKeypad({
    required this.onDigit,
    required this.onBackspace,
    required this.onClear,
  });

  static const List<List<String>> _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['C', '0', '<'],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final row in _rows) ...[
          Row(
            children: [
              for (final key in row) ...[
                Expanded(child: _buildKey(key)),
                if (key != row.last) const SizedBox(width: 14),
              ],
            ],
          ),
          if (row != _rows.last) const SizedBox(height: 14),
        ],
      ],
    );
  }

  Widget _buildKey(String key) {
    if (key == 'C') {
      return _KeypadKey(label: 'C', ghost: true, onTap: onClear);
    }
    if (key == '<') {
      return _KeypadKey(
          icon: Icons.backspace_outlined, ghost: true, onTap: onBackspace);
    }
    return _KeypadKey(label: key, onTap: () => onDigit(key));
  }
}

class _KeypadKey extends StatefulWidget {
  final String? label;
  final IconData? icon;
  final bool ghost;
  final VoidCallback onTap;

  const _KeypadKey({
    this.label,
    this.icon,
    this.ghost = false,
    required this.onTap,
  });

  @override
  State<_KeypadKey> createState() => _KeypadKeyState();
}

class _KeypadKeyState extends State<_KeypadKey> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          height: 76,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _pressed
                ? _kKeyPressed
                : (widget.ghost ? Colors.transparent : _kKeyFace),
            borderRadius: BorderRadius.circular(20),
            // Keys are raised off the beige, not outlined on it -- a border
            // reads as a wireframe, a soft shadow reads as a physical key.
            boxShadow: widget.ghost || _pressed
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: widget.icon != null
              ? Icon(widget.icon, size: 30, color: TextTones.accent)
              : Text(
                  widget.label ?? '',
                  style: loewMedium.copyWith(
                    fontSize: 32,
                    color: widget.ghost ? TextTones.accent : _kInk,
                  ),
                ),
        ),
      ),
    );
  }
}

class _UnlockButton extends StatelessWidget {
  final String label;
  final bool loading;
  final bool enabled;
  final VoidCallback onTap;
  const _UnlockButton({
    required this.label,
    required this.loading,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // The button stays solid ink at every state: dimming a near-black fill
    // turns it grey against the beige and reads as broken, not disabled.
    // Readiness is signalled by its shadow lifting once four digits are in.
    final bool active = enabled && !loading;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _kInk.withValues(alpha: active ? 0.30 : 0.12),
            blurRadius: active ? 22 : 10,
            offset: Offset(0, active ? 9 : 4),
          ),
        ],
      ),
      child: Material(
        color: _kInk,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: KioskTap(
          onTap: loading ? null : onTap,
          child: SizedBox(
            width: double.infinity,
            height: 74,
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(_kSurface),
                      ),
                    )
                  : Text(label,
                      style: loewMedium.copyWith(
                          fontSize: 28,
                          color: _kSurface,
                          letterSpacing: 0.2)),
            ),
          ),
        ),
      ),
    );
  }
}
