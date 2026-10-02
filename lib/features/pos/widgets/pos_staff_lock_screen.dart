import 'package:acafe_customer/features/pos/domain/pos_staff_session.dart';
import 'package:acafe_customer/features/pos/providers/pos_staff_session_provider.dart';
import 'package:acafe_customer/features/pos/widgets/pos_pin_card.dart';
import 'package:acafe_customer/features/pos/widgets/pos_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// The till's front door when a branch has switched staff sign-in on.
///
/// Just a PIN, centred: the operator types their own PIN and signs in. There is
/// no role step and no clock or branch chrome -- the PIN alone identifies the
/// person, and the server returns their real role and permissions, which decide
/// what this till lets them do. One branch can have any number of managers and
/// employees; each signs in the same way and lands on the same till, with the
/// tabs their role allows (Report and Settings for a manager, the order screen
/// for everyone).
///
/// Built on [PosPinCard] so the keypad, PIN boxes, press states and the shake
/// on a wrong PIN are the same as the manager step-up, not a second design.
///
/// State lives in a [ValueNotifier] scoped to this screen, never in a rebuild of
/// the whole tree: the POS underneath stays mounted, so a sale in progress
/// survives a lock and a change of cashier.
class PosStaffLockScreen extends StatefulWidget {
  const PosStaffLockScreen({super.key});

  static const Key rootKey = Key('pos-staff-lock-screen');

  @override
  State<PosStaffLockScreen> createState() => _PosStaffLockScreenState();
}

class _PosStaffLockScreenState extends State<PosStaffLockScreen> {
  final ValueNotifier<String?> _message = ValueNotifier(null);

  @override
  void initState() {
    super.initState();
    // The switch may have been flipped, or someone hired, since the till last
    // looked. Cheap, and this is the moment it matters.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<PosStaffSessionProvider>().refreshRoster();
    });
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<bool> _submit(String pin) async {
    final PosStaffSessionProvider session =
        context.read<PosStaffSessionProvider>();
    // The PIN alone identifies the person. No role is sent: the server resolves
    // the staff member from the PIN and returns their real role and permissions,
    // so sign-in can never be bound to the wrong role.
    final PosSignInResult result = await session.signIn(pin);
    if (!mounted) return result.ok;

    switch (result.outcome) {
      case PosSignInOutcome.signedIn:
        _message.value = null;
        return true;
      case PosSignInOutcome.wrongPin:
        // Just the plain notice -- no attempts-remaining count.
        _message.value = 'That PIN was not recognised.';
        return false;
      case PosSignInOutcome.lockedOut:
        // The countdown takes over the message line; see [_lockoutMessage].
        _message.value = null;
        return false;
      case PosSignInOutcome.unavailable:
        _message.value = result.message ??
            'Could not reach the server. Check the connection and try again.';
        return false;
    }
  }

  static String _lockoutMessage(int seconds) {
    final int m = seconds ~/ 60;
    final int s = seconds % 60;
    return 'Too many wrong PINs. Try again in $m:${s.toString().padLeft(2, '0')}.';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      key: PosStaffLockScreen.rootKey,
      color: PosUI.pageBg,
      child: SafeArea(
        // Just the dialer, centred. Scrolls on a short window so the keypad is
        // always reachable; the card caps its own width at PosPinSpec.board and
        // shrinks to fit a narrow tablet, so one layout serves every size.
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.sizeOf(context).height -
                  MediaQuery.paddingOf(context).vertical,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Center(child: _pinPane()),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pinPane() {
    return AnimatedBuilder(
      animation: _message,
      builder: (context, _) {
        return Consumer<PosStaffSessionProvider>(
          builder: (context, session, _) {
            final bool locked = session.isLockedOut;
            final String? message = locked
                ? _lockoutMessage(session.lockoutSecondsLeft)
                : _message.value;

            return ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: PosPinSpec.board),
              child: PosPinCard(
                pinLength: session.pinLength,
                autoSubmit: true,
                reserveMessageSpace: true,
                enabled: !locked && !session.signingIn,
                title: 'Enter your PIN',
                message: message,
                onSubmit: _submit,
              ),
            );
          },
        );
      },
    );
  }
}
