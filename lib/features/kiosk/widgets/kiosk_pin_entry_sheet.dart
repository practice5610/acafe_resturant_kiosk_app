import 'dart:math';

import 'package:flutter/material.dart';
import 'package:acafe_customer/common/responsive/kiosk_responsive.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_scrim.dart';
import 'package:acafe_customer/common/widgets/custom_asset_image_widget.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_manager_provider.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_checkout_widgets.dart'
    show kioskFormScale;
import 'package:acafe_customer/features/kiosk/widgets/kiosk_tap.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:provider/provider.dart';

// Brand palette for this modal only (not a shared kiosk theme token set).
const Color _kManagerSurface = Color(0xFFF5F1EA);
const Color _kManagerText = Color(0xFF2B2B2B);
const Color _kManagerAccent = Color(0xFFC8A97E);
const Color _kManagerDanger = Color(0xFFC8544A);
const Color _kManagerKeyPressed = Color(0xFFEFE7D8);

/// Opens the manager PIN modal; on a correct code, navigates to the POS
/// Manager Dashboard. Call this from the top-bar manager icon rather than
/// navigating to the dashboard route directly -- the PIN check is the gate.
///
/// A centered, blurred-scrim dialog (not a bottom sheet) so the card floats
/// as one cohesive unit with rounded corners on every side.
Future<void> openKioskManagerAccess(BuildContext context) async {
  final double s = kioskFormScale(
    KioskMetrics.maybeOf(context)?.contentWidth ??
        MediaQuery.sizeOf(context).width,
  );
  final unlocked = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Manager access',
    barrierColor: Colors.transparent, // the sheet paints its own blurred scrim
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondaryAnimation) =>
        KioskPinEntrySheet(s: s),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween(begin: 0.96, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOut)),
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
  final double s;
  const KioskPinEntrySheet({super.key, required this.s});

  @override
  State<KioskPinEntrySheet> createState() => _KioskPinEntrySheetState();
}

class _KioskPinEntrySheetState extends State<KioskPinEntrySheet>
    with SingleTickerProviderStateMixin {
  String _code = '';
  late final AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop(false);

  void _onDigit(String digit) {
    if (_code.length >= 4) return;
    final provider = context.read<KioskManagerProvider>();
    if (provider.pinError != null) provider.clearPinError();
    setState(() => _code += digit);
    if (_code.length == 4) _submit();
  }

  void _onBackspace() {
    if (_code.isEmpty) return;
    setState(() => _code = _code.substring(0, _code.length - 1));
  }

  void _onClear() => setState(() => _code = '');

  Future<void> _submit() async {
    final provider = context.read<KioskManagerProvider>();
    final code = _code;
    if (code.length != 4) return;

    final ok = await provider.verifyPin(code);
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
    return wave * decay * 14 * widget.s;
  }

  @override
  Widget build(BuildContext context) {
    final double s = widget.s;
    return Consumer<KioskManagerProvider>(
      builder: (context, provider, _) {
        // Material (transparent) provides the DefaultTextStyle every Text below
        // relies on. Without it, text rendered inside showGeneralDialog falls
        // back to the framework debug style -> yellow double underline.
        // Transparency paints nothing, so the blurred scrim is untouched.
        return Material(
          type: MaterialType.transparency,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Shared frosted scrim -- tap outside the card to dismiss.
              KioskScrim(
                animation: ModalRoute.of(context)?.animation ??
                    kAlwaysCompleteAnimation,
                onDismiss: _close,
              ),
              Center(
                child: GestureDetector(
                  onTap:
                      () {}, // absorb taps so the card itself never closes the modal
                  child: AnimatedBuilder(
                    animation: _shakeController,
                    builder: (context, child) => Transform.translate(
                      offset: Offset(_shakeOffset(_shakeController.value), 0),
                      child: child,
                    ),
                    child: _ManagerCard(
                      s: s,
                      codeLength: _code.length,
                      error: provider.pinError,
                      loading: provider.verifyingPin,
                      onDigit: _onDigit,
                      onBackspace: _onBackspace,
                      onClear: _onClear,
                      onSubmit: _submit,
                      onClose: _close,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ManagerCard extends StatelessWidget {
  final double s;
  final int codeLength;
  final String? error;
  final bool loading;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final VoidCallback onSubmit;
  final VoidCallback onClose;

  const _ManagerCard({
    required this.s,
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
      width: 620 * s,
      constraints: BoxConstraints(maxWidth: 620 * s),
      padding: EdgeInsets.fromLTRB(48 * s, 40 * s, 48 * s, 40 * s),
      decoration: BoxDecoration(
        color: _kManagerSurface,
        borderRadius: BorderRadius.circular(28 * s),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 44 * s,
            offset: Offset(0, 22 * s),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Container(
                width: 88 * s,
                height: 88 * s,
                margin: EdgeInsets.only(top: 4 * s),
                decoration: BoxDecoration(
                  color: _kManagerAccent.withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: CustomAssetImageWidget(
                  Images.managerAccessSvg,
                  width: 36 * s,
                  height: 36 * s,
                  color: _kManagerText,
                ),
              ),
              Positioned(
                right: -16 * s,
                top: -8 * s,
                child: _CloseButton(s: s, onTap: onClose),
              ),
            ],
          ),
          SizedBox(height: 22 * s),
          Text('Manager access',
              style:
                  loewMedium.copyWith(fontSize: 40 * s, color: _kManagerText)),
          SizedBox(height: 10 * s),
          Text(
            hasError
                ? 'Wrong code, try again'
                : 'Enter your 4-digit code to unlock',
            textAlign: TextAlign.center,
            style: loewRegular.copyWith(
              fontSize: 26 * s,
              color: hasError
                  ? _kManagerDanger
                  : _kManagerText.withValues(alpha: 0.55),
            ),
          ),
          SizedBox(height: 30 * s),
          _PinDotsRow(s: s, filled: codeLength, hasError: hasError),
          SizedBox(height: 34 * s),
          _ManagerKeypad(
              s: s,
              onDigit: onDigit,
              onBackspace: onBackspace,
              onClear: onClear),
          SizedBox(height: 30 * s),
          _UnlockButton(s: s, loading: loading, onTap: onSubmit),
        ],
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  final double s;
  final VoidCallback onTap;
  const _CloseButton({required this.s, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final double d = 44 * s;
    return SizedBox(
      width: d,
      height: d,
      child: KioskTap(
        onTap: onTap,
        child: Container(
          decoration: const BoxDecoration(
              color: Color(0xFFECE6D8), shape: BoxShape.circle),
          child: Icon(Icons.close,
              size: 20 * s, color: _kManagerText.withValues(alpha: 0.6)),
        ),
      ),
    );
  }
}

class _PinDotsRow extends StatelessWidget {
  final double s;
  final int filled;
  final bool hasError;
  const _PinDotsRow(
      {required this.s, required this.filled, required this.hasError});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) {
        final bool isFilled = i < filled;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 11 * s),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: (isFilled ? 22 : 18) * s,
            height: (isFilled ? 22 : 18) * s,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isFilled
                  ? (hasError ? _kManagerDanger : _kManagerText)
                  : Colors.transparent,
              border: Border.all(
                color: hasError ? _kManagerDanger : _kManagerAccent,
                width: 2 * s,
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _ManagerKeypad extends StatelessWidget {
  final double s;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onClear;

  const _ManagerKeypad({
    required this.s,
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
                if (key != row.last) SizedBox(width: 16 * s),
              ],
            ],
          ),
          if (row != _rows.last) SizedBox(height: 16 * s),
        ],
      ],
    );
  }

  Widget _buildKey(String key) {
    if (key == 'C') {
      return _KeypadKey(s: s, label: 'C', ghost: true, onTap: onClear);
    }
    if (key == '<') {
      return _KeypadKey(
          s: s,
          icon: Icons.backspace_outlined,
          ghost: true,
          onTap: onBackspace);
    }
    return _KeypadKey(s: s, label: key, onTap: () => onDigit(key));
  }
}

class _KeypadKey extends StatefulWidget {
  final double s;
  final String? label;
  final IconData? icon;
  final bool ghost;
  final VoidCallback onTap;

  const _KeypadKey({
    required this.s,
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
    final double s = widget.s;
    // Clamped so the touch target never drops below the 60px kiosk minimum,
    // even at narrow preview widths where `s` is small.
    final double height = (84 * s).clamp(60.0, 104.0);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _pressed
                ? _kManagerKeyPressed
                : (widget.ghost ? Colors.transparent : Colors.white),
            borderRadius: BorderRadius.circular(16 * s),
            border: widget.ghost
                ? null
                : Border.all(
                    color: Colors.black.withValues(alpha: 0.08),
                    width: 1.5 * s),
          ),
          child: widget.icon != null
              ? Icon(widget.icon, size: 30 * s, color: _kManagerAccent)
              : Text(
                  widget.label ?? '',
                  style: loewMedium.copyWith(
                    fontSize: 34 * s,
                    color: widget.ghost ? _kManagerAccent : _kManagerText,
                  ),
                ),
        ),
      ),
    );
  }
}

class _UnlockButton extends StatelessWidget {
  final double s;
  final bool loading;
  final VoidCallback onTap;
  const _UnlockButton(
      {required this.s, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final double height = (72 * s).clamp(56.0, 90.0);
    return Material(
      color: _kManagerText,
      borderRadius: BorderRadius.circular(16 * s),
      clipBehavior: Clip.antiAlias,
      child: KioskTap(
        onTap: loading ? null : onTap,
        child: SizedBox(
          width: double.infinity,
          height: height,
          child: Center(
            child: loading
                ? SizedBox(
                    width: 26 * s,
                    height: 26 * s,
                    child: const CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(_kManagerSurface),
                    ),
                  )
                : Text('Unlock',
                    style: loewMedium.copyWith(
                        fontSize: 30 * s, color: _kManagerSurface)),
          ),
        ),
      ),
    );
  }
}
