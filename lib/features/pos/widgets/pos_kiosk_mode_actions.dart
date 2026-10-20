import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/kiosk/providers/device_mode_provider.dart';
import 'package:acafe_customer/features/pos/widgets/pos_complete_confirmation_dialog.dart';
import 'package:acafe_customer/features/pos/widgets/pos_punch_actions.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// POS → Kiosk from the till (POS_KIOSK_MODE_PHASE1.md §5.3): the rail's
/// Kiosk Mode pill, its confirmation, and the switch itself.

/// The till's one-tap way into kiosk mode, beside Punch In / Out at the foot of
/// the category rail and at the end of the compact strip. Shown only where the
/// till may switch (see `pos_home_cart_screen.dart`).
class PosKioskModeEntryButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool showLabel;
  final bool expand;
  final double scale;

  static const String label = 'Kiosk Mode';
  static const Key buttonKey = Key('pos-switch-to-kiosk');

  const PosKioskModeEntryButton({
    super.key,
    required this.onTap,
    this.showLabel = true,
    this.expand = false,
    this.scale = 1,
  });

  @override
  Widget build(BuildContext context) {
    return PosRailPillButton(
      buttonKey: buttonKey,
      icon: Icons.storefront_outlined,
      label: label,
      onTap: onTap,
      showLabel: showLabel,
      expand: expand,
      scale: scale,
    );
  }
}

/// Asks before turning the till into a kiosk, and runs [onConfirmed] only on a
/// yes. Says what the switch will cost: whoever is signed in, and the open
/// ticket if there is one.
Future<void> confirmSwitchToKiosk(
  BuildContext context, {
  required Future<void> Function() onConfirmed,
  int ticketItems = 0,
}) async {
  final String ticket = ticketItems == 0
      ? ''
      : ' The $ticketItems ${ticketItems == 1 ? 'item' : 'items'} on this ticket will be cleared.';
  final bool? confirmed = await PosCompleteConfirmationDialog.show(
    context,
    heading: 'Switch this till to Kiosk?',
    subtext: 'Customers will order here by themselves. You will be signed out.'
        '$ticket A staff PIN is needed to switch back.',
    confirmLabel: 'Switch to Kiosk',
    compact: true,
  );
  if (confirmed == true) await onConfirmed();
}

/// The Kiosk Mode pill's action: confirm, ask the server, and on its yes show
/// the kiosk. On a no the till stays exactly as it was and says why.
Future<void> openSwitchToKiosk(BuildContext context) async {
  final DeviceModeProvider modes = context.read<DeviceModeProvider>();
  final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
  final int items = context.read<CartProvider>().cartList.length;

  await confirmSwitchToKiosk(
    context,
    ticketItems: items,
    onConfirmed: () async {
      final DeviceModeSwitchResult result = await modes.switchToKiosk();
      if (result.ok) {
        // Through the router helper so web history is replaced: Back cannot
        // walk a customer into the till's URLs (the guard would refuse them
        // anyway).
        await RouterHelper.openKioskWelcome(action: RouteAction.pushNamedAndRemoveUntil);
        return;
      }
      if (result.message != null) {
        messenger?.showSnackBar(SnackBar(content: Text(result.message!)));
      }
    },
  );
}
