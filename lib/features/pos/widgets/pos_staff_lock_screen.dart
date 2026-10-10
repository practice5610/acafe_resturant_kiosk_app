import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/di_container.dart' as di;
import 'package:acafe_customer/features/pos/domain/pos_punch_source.dart';
import 'package:acafe_customer/features/pos/domain/pos_staff_session.dart';
import 'package:acafe_customer/features/pos/providers/pos_staff_session_provider.dart';
import 'package:acafe_customer/features/pos/widgets/pos_lock_punch_view.dart';
import 'package:acafe_customer/features/pos/widgets/pos_pin_card.dart';
import 'package:acafe_customer/features/pos/widgets/pos_ui.dart';
import 'package:acafe_customer/utill/styles.dart';
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

  /// Swapped to true when the operator opens Punch In / Out. The punch flow
  /// does not need, and must never grant, a till sign-in -- so it is shown in
  /// place of the PIN login, not over the till.
  bool _punching = false;

  /// Device-authenticated punch source, built once the same way the Punch route
  /// does ([_PosPunchHost]). If the Dio client is somehow not registered every
  /// punch reports "unavailable", so the view shows an error rather than crashing.
  late final PosPunchSource _punchSource = di.sl.isRegistered<DioClient>()
      ? PosPunchRepo(dioClient: di.sl<DioClient>())
      : const PosPunchRepo();

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
        // Punch In / Out takes over the whole surface while it is open; the PIN
        // login is one tap away via its "Back to sign in" header.
        child: _punching
            ? PosLockPunchView(
                source: _punchSource,
                onBack: () => setState(() => _punching = false),
              )
            : Column(
                children: [
                  // Punch In / Out rides the top-right corner: a tasteful
                  // secondary action that never competes with the centred
                  // sign-in card. Open to everyone, signed in or not --
                  // attendance-only staff who may never operate the till clock
                  // in and out here, and so can anyone who just wants to.
                  _PunchTopBar(
                    onTap: () => setState(() => _punching = true),
                  ),
                  // Just the dialer, centred in the space below the bar. Scrolls
                  // on a short window so the keypad is always reachable; the card
                  // caps its own width at PosPinSpec.board and shrinks to fit a
                  // narrow tablet, so one layout serves every size.
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                              minHeight: constraints.maxHeight),
                          child: Padding(
                            padding:
                                const EdgeInsets.fromLTRB(24, 0, 24, 24),
                            child: Center(child: _pinPane()),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
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

/// The top bar on the lock screen, holding the Punch In / Out entry pinned to
/// the top-right. A thin row so the sign-in card stays centred in the space
/// below it, rather than the entry dangling under the card.
class _PunchTopBar extends StatelessWidget {
  final VoidCallback onTap;

  const _PunchTopBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Align(
        alignment: Alignment.centerRight,
        child: _PunchEntryButton(onTap: onTap),
      ),
    );
  }
}

/// The action that opens Punch In / Out. Outlined, not filled, so it reads as a
/// utility action rather than competing with the primary VERIFY & LOGIN button
/// -- and styled from the same tokens as the in-POS sidebar punch entry so the
/// two doors to the punch clock match.
class _PunchEntryButton extends StatelessWidget {
  final VoidCallback onTap;

  const _PunchEntryButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        key: const Key('pos-lock-punch-entry'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          decoration: BoxDecoration(
            color: PosPinSpec.cardFill,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: PosPinSpec.inkAlpha(0.14), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: PosPinSpec.inkAlpha(0.06),
                offset: const Offset(0, 4),
                blurRadius: 12,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.schedule_rounded,
                  size: 20, color: PosPinSpec.ink),
              const SizedBox(width: 10),
              Text(
                'Punch In / Out'.toUpperCase(),
                style: loewBold.copyWith(
                  fontSize: 13,
                  color: PosPinSpec.ink,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
