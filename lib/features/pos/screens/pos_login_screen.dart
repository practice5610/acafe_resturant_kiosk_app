import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_manager_provider.dart';
import 'package:acafe_customer/features/pos/domain/pos_responsive.dart';
import 'package:acafe_customer/features/pos/domain/pos_routes.dart';
import 'package:acafe_customer/features/pos/widgets/pos_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

/// Shift unlock for a POS terminal.
///
/// The code is the device's own `configuration_code`, set by admin when the
/// device is created (Kiosk -> Add New / Edit -> Category: POS), checked by
/// [KioskManagerProvider.verifyPin] against
/// `POST /api/v1/kiosk/manager/verify-code`. No new endpoint, no new schema.
///
/// This sits *after* device login, not instead of it: the username/password
/// device login binds the terminal to a branch once and persists a token; this
/// PIN is the per-shift gate that stops a terminal left unattended from being
/// usable. A wrong code is rate limited server-side (`throttle:device-manager-pin`).
///
/// Layout here is intentionally plain — it is reconciled against the Figma
/// frame in the visual pass.
class PosLoginScreen extends StatefulWidget {
  const PosLoginScreen({super.key});

  @override
  State<PosLoginScreen> createState() => _PosLoginScreenState();
}

class _PosLoginScreenState extends State<PosLoginScreen> {
  static const int _pinLength = 4;
  String _code = '';

  void _tapDigit(String digit) {
    if (_code.length >= _pinLength) return;
    final manager = context.read<KioskManagerProvider>();
    if (manager.pinError != null) manager.clearPinError();
    setState(() => _code += digit);
    if (_code.length == _pinLength) _submit();
  }

  void _backspace() {
    if (_code.isEmpty) return;
    setState(() => _code = _code.substring(0, _code.length - 1));
  }

  Future<void> _submit() async {
    final manager = context.read<KioskManagerProvider>();
    final bool ok = await manager.verifyPin(_code);
    if (!mounted) return;
    if (ok) {
      context.go(PosRoutes.home);
    } else {
      // Clear the field so the next attempt starts fresh; the provider holds
      // the message.
      setState(() => _code = '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final double s = PosMetrics.maybeOf(context)?.scale ?? 1.0;
    final manager = context.watch<KioskManagerProvider>();
    final auth = context.watch<KioskAuthProvider>();

    return Scaffold(
      backgroundColor: PosUI.pageBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(PosUI.gutter * s),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 460 * s),
              child: PosSurface(
                padding: EdgeInsets.all(28 * s),
                radius: PosUI.radiusLarge,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      auth.branchName.isEmpty ? 'A/CAFÉ' : auth.branchName,
                      style: PosUI.text(context,
                          size: PosUI.titleSize, weight: FontWeight.w700),
                    ),
                    SizedBox(height: 4 * s),
                    Text(
                      auth.deviceName.isEmpty
                          ? 'Enter your code'
                          : '${auth.deviceName} · Enter your code',
                      style: PosUI.text(context,
                          size: PosUI.captionSize, color: PosUI.inkMuted),
                    ),
                    SizedBox(height: 24 * s),
                    _PinDots(filled: _code.length, total: _pinLength),
                    SizedBox(height: 12 * s),
                    SizedBox(
                      height: 20 * s,
                      child: manager.pinError != null
                          ? Text(
                              manager.pinError!,
                              style: PosUI.text(context,
                                  size: PosUI.captionSize,
                                  color: PosUI.danger),
                            )
                          : null,
                    ),
                    SizedBox(height: 12 * s),
                    if (manager.verifyingPin)
                      SizedBox(
                        height: 240 * s,
                        child: const Center(
                            child: CircularProgressIndicator(
                                color: PosUI.accent)),
                      )
                    else
                      _PinPad(onDigit: _tapDigit, onBackspace: _backspace),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PinDots extends StatelessWidget {
  final int filled;
  final int total;

  const _PinDots({required this.filled, required this.total});

  @override
  Widget build(BuildContext context) {
    final double s = PosMetrics.maybeOf(context)?.scale ?? 1.0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < total; i++)
          Container(
            width: 16 * s,
            height: 16 * s,
            margin: EdgeInsets.symmetric(horizontal: 8 * s),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < filled ? PosUI.ink : Colors.transparent,
              border: Border.all(color: PosUI.ink, width: 1.5),
            ),
          ),
      ],
    );
  }
}

class _PinPad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  const _PinPad({required this.onDigit, required this.onBackspace});

  @override
  Widget build(BuildContext context) {
    final double s = PosMetrics.maybeOf(context)?.scale ?? 1.0;
    const List<String> keys = [
      '1', '2', '3',
      '4', '5', '6',
      '7', '8', '9',
      '', '0', '<',
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int row = 0; row < 4; row++)
          Padding(
            padding: EdgeInsets.only(bottom: 10 * s),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int col = 0; col < 3; col++)
                  _PadKey(
                    label: keys[row * 3 + col],
                    onTap: () {
                      final String k = keys[row * 3 + col];
                      if (k.isEmpty) return;
                      if (k == '<') {
                        onBackspace();
                      } else {
                        onDigit(k);
                      }
                    },
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PadKey extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PadKey({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final double s = PosMetrics.maybeOf(context)?.scale ?? 1.0;
    if (label.isEmpty) {
      return SizedBox(width: 92 * s, height: 62 * s);
    }
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 5 * s),
      child: Material(
        color: PosUI.surfaceSunken,
        borderRadius: BorderRadius.circular(PosUI.radius * s),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(PosUI.radius * s),
          child: SizedBox(
            width: 82 * s,
            height: 62 * s,
            child: Center(
              child: label == '<'
                  ? Icon(Icons.backspace_outlined,
                      size: 22 * s, color: PosUI.ink)
                  : Text(
                      label,
                      style: PosUI.text(context,
                          size: PosUI.titleSize, weight: FontWeight.w600),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
