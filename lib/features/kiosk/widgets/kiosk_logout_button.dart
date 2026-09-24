import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/pos/providers/pos_session_provider.dart';
import 'package:acafe_customer/features/pos/widgets/pos_complete_confirmation_dialog.dart';
import 'package:acafe_customer/features/pos/widgets/pos_top_nav_bar.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

/// The kiosk's only way to sign the device out — the same control POS carries
/// in its nav bar ([PosAvatar] + a one-item "Logout" dropdown + the
/// "Log out this terminal?" confirmation), lifted into the kiosk menu
/// screen's top bar beside search / filter / language.
///
/// Guarded exactly as POS is: a tap opens a dropdown, and the dropdown's one
/// item opens a confirmation. Two deliberate taps, so a stray brush of the
/// avatar can never log the kiosk out — which matters more here than on the
/// till, because this bar is in front of customers while they browse.
class KioskLogoutButton extends StatefulWidget {
  /// Diameter of the avatar. Defaults to the POS nav-bar size; the kiosk
  /// menu screen passes its own top-bar circle diameter.
  final double size;

  const KioskLogoutButton({super.key, this.size = PosNavBarSpec.avatarSize});

  static const Key buttonKey = Key('kiosk-logout-button');

  @override
  State<KioskLogoutButton> createState() => _KioskLogoutButtonState();
}

class _KioskLogoutButtonState extends State<KioskLogoutButton> {
  /// Same copy as the POS terminal logout, word for word.
  Future<void> _onLogout() async {
    final bool? confirmed = await PosCompleteConfirmationDialog.show(
      context,
      heading: 'Log out this device?',
      subtext: 'You will need to sign back in to use this device.',
      confirmLabel: 'Log Out',
    );
    if (confirmed != true || !mounted) return;

    // Drop any manager step-up along with the session, the same pairing POS
    // uses: a grant outliving the sign-in it was granted under would survive
    // into whoever signs in next.
    context.read<PosSessionProvider>().lock();
    await context.read<KioskAuthProvider>().logout();
    if (!mounted) return;
    // The route guard only re-evaluates on navigation, so a signed-out
    // session would otherwise keep showing the welcome screen until the next
    // tap. Send the device to the login screen explicitly.
    context.go(RouterHelper.kioskLoginScreen);
  }

  /// The kiosk has no staff identity either — the avatar names the device or
  /// its branch, exactly as the POS nav bar does.
  String _initial(KioskAuthProvider auth) {
    final String source =
        auth.deviceName.isNotEmpty ? auth.deviceName : auth.branchName;
    return source.isEmpty ? 'A' : source.trim().characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final KioskAuthProvider auth = context.watch<KioskAuthProvider>();

    return PopupMenuButton<String>(
      key: KioskLogoutButton.buttonKey,
      tooltip: 'Account',
      // Without this the menu opens over the avatar instead of below it —
      // same anchor fix the POS nav bar needed.
      position: PopupMenuPosition.under,
      onSelected: (_) => _onLogout(),
      itemBuilder: (context) => const [
        PopupMenuItem<String>(value: 'logout', child: Text('Logout')),
      ],
      child: PosAvatar(initial: _initial(auth), size: widget.size),
    );
  }
}
