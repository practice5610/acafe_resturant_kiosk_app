import 'dart:async';

import 'package:acafe_customer/features/kiosk/providers/device_mode_provider.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_pin_entry_sheet.dart';
import 'package:acafe_customer/features/pos/domain/pos_routes.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// The staff way back from kiosk mode: tap the A/CAFÉ logo three times in
/// quick succession (POS_KIOSK_MODE_PHASE1.md §5.4).
///
/// Nothing on screen points at it, so the PIN pad behind it is not an
/// invitation to guess. The PIN is what actually guards the way back, checked
/// and rate-limited by the server; this only keeps it out of sight. While it
/// is live the logo takes its own taps, so tapping it never starts an order;
/// the rest of the screen still does. Inert everywhere except a POS till that
/// is serving as a kiosk: a real kiosk has no way to the POS at all.
class KioskStaffExitTrigger extends StatefulWidget {
  final Widget child;

  /// What the third tap does. Defaults to [openKioskStaffExit].
  final VoidCallback? onTriggered;

  const KioskStaffExitTrigger({super.key, required this.child, this.onTriggered});

  static const int tapsNeeded = 3;

  /// Longest pause between two taps that still counts as one sequence.
  static const Duration tapWindow = Duration(milliseconds: 700);

  @override
  State<KioskStaffExitTrigger> createState() => _KioskStaffExitTriggerState();
}

class _KioskStaffExitTriggerState extends State<KioskStaffExitTrigger> {
  int _taps = 0;

  /// Forgets the count once the pause after a tap runs past [tapWindow].
  Timer? _reset;

  void _onTap() {
    _reset?.cancel();
    _taps++;
    if (_taps >= KioskStaffExitTrigger.tapsNeeded) {
      _taps = 0;
      (widget.onTriggered ?? () => openKioskStaffExit(context))();
      return;
    }
    _reset = Timer(KioskStaffExitTrigger.tapWindow, () => _taps = 0);
  }

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Null-safe like PosStaffGate: a screen mounted without the auth provider
    // (a harness) has no kiosk mode, so the logo stays just a logo.
    final bool active =
        Provider.of<KioskAuthProvider?>(context)?.kioskModeActive ?? false;
    if (!active) return widget.child;

    // Opaque, and the innermost tap recognizer, so a tap on the logo is ours
    // rather than the welcome screen's tap-anywhere.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onTap,
      child: widget.child,
    );
  }
}

/// Opens the staff PIN pad. A PIN that holds the permission brings the till
/// back to POS, signed in as that member, and moves to the till's home.
Future<void> openKioskStaffExit(BuildContext context) async {
  final DeviceModeProvider modes = context.read<DeviceModeProvider>();

  final bool? back = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Staff access',
    barrierColor: Colors.transparent, // the sheet paints its own blurred scrim
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (context, animation, secondaryAnimation) => KioskPinEntrySheet(
      title: 'Staff access',
      prompt: 'Enter your staff PIN to switch to POS',
      submitLabel: 'Switch to POS',
      onSubmitPin: (pin) async {
        final DeviceModeSwitchResult result = await modes.switchToPos(pin);
        return result.ok ? null : (result.message ?? 'Try again');
      },
    ),
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

  // The router has no listener on the device mode, so move explicitly; the
  // global router, because the kiosk screen's own context is about to go.
  // The PIN pad is closed by now, so the navigation cannot strand it. The
  // switch's curtain is still up and lifts once the till has landed.
  if (back == true) {
    RouterHelper.goRoutes.go(PosRoutes.home);
    modes.landed();
  }
}
