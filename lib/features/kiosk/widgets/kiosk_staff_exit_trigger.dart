import 'package:acafe_customer/features/kiosk/providers/device_mode_provider.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_pin_entry_sheet.dart';
import 'package:acafe_customer/features/pos/domain/pos_routes.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// The staff way back from kiosk mode: hold the A/CAFÉ logo for three seconds
/// (POS_KIOSK_MODE_PHASE1.md §5.4).
///
/// Hidden on purpose -- customers see nothing to tap, so the PIN pad behind it
/// is not an invitation to guess. The PIN is what actually guards the way back,
/// checked and rate-limited by the server; this only keeps it out of sight.
/// Inert everywhere except a POS till that is serving as a kiosk: a real kiosk
/// has no way to the POS at all.
class KioskStaffExitTrigger extends StatelessWidget {
  final Widget child;

  /// What a completed hold does. Defaults to [openKioskStaffExit].
  final VoidCallback? onTriggered;

  const KioskStaffExitTrigger({super.key, required this.child, this.onTriggered});

  static const Duration holdDuration = Duration(seconds: 3);

  @override
  Widget build(BuildContext context) {
    // Null-safe like PosStaffGate: a screen mounted without the auth provider
    // (a harness) has no kiosk mode, so the logo stays just a logo.
    final bool active =
        Provider.of<KioskAuthProvider?>(context)?.kioskModeActive ?? false;
    if (!active) return child;

    return RawGestureDetector(
      // Opaque so the hold is ours, not the tap-anywhere surface behind the
      // logo; a plain tap still falls through to it once the hold is lost.
      behavior: HitTestBehavior.opaque,
      gestures: {
        LongPressGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
          () => LongPressGestureRecognizer(duration: holdDuration),
          (recognizer) => recognizer.onLongPress =
              onTriggered ?? () => openKioskStaffExit(context),
        ),
      },
      child: child,
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
  if (back == true) RouterHelper.goRoutes.go(PosRoutes.home);
}
