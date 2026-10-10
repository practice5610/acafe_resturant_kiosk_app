import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_punch_source.dart';
import 'package:acafe_customer/features/pos/widgets/pos_pin_card.dart';
import 'package:acafe_customer/features/pos/widgets/pos_punch_actions.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';

/// Punch In / Out, inline on the staff lock screen.
///
/// The same attendance action as the full-screen [PosPunchScreen] reached from
/// the POS sidebar, but reachable WITHOUT signing in -- which is the whole point
/// of putting it here. An attendance-only staff member (an imported Planday
/// employee) can clock in and out but may never operate the till, so the lock
/// screen is the only door they have; this is it.
///
/// Drawn inline rather than in a dialog because the lock screen lives above the
/// router's navigator (see [PosStaffGate]), where `showDialog` has no Navigator
/// to attach to. So the PIN step replaces the tiles in place instead of floating
/// over them. Everything else -- the tiles, the result banner, the PIN
/// validation -- is the shared punch machinery, so the two surfaces stay one
/// design, not two.
class PosLockPunchView extends StatefulWidget {
  final PosPunchSource source;

  /// Back to the PIN login. The till's sign-in state is untouched.
  final VoidCallback onBack;

  const PosLockPunchView({
    super.key,
    required this.source,
    required this.onBack,
  });

  static const Key rootKey = Key('pos-lock-punch-view');

  @override
  State<PosLockPunchView> createState() => _PosLockPunchViewState();
}

class _PosLockPunchViewState extends State<PosLockPunchView> {
  /// Null while the tiles are showing; 'in' or 'out' once a direction is chosen
  /// and the PIN card is up.
  String? _pinFor;

  /// The last completed punch, shown under the tiles. Cleared when a new PIN
  /// entry starts so a stale banner never lingers over a fresh attempt.
  PosPunchResult? _last;

  /// The note in the PIN card (wrong PIN, lockout, or server unreachable).
  String? _message;

  /// False freezes the keypad on a lockout.
  bool _enabled = true;

  void _choose(String direction) {
    setState(() {
      _pinFor = direction;
      _message = null;
      _enabled = true;
      _last = null;
    });
  }

  void _cancelPin() {
    setState(() {
      _pinFor = null;
      _message = null;
      _enabled = true;
    });
  }

  Future<bool> _submit(String pin) async {
    final PosPunchResult result =
        await widget.source.punch(direction: _pinFor!, pin: pin);
    if (!mounted) return false;

    if (result.pinRejected) {
      setState(() {
        _message = result.message.isNotEmpty
            ? result.message
            : 'That PIN was not recognised.';
        // A lockout freezes the keypad; a plain wrong PIN lets them retry.
        _enabled = result.status != PosPunchStatus.lockedOut;
      });
      return false; // the card shakes and clears
    }

    if (result.status == PosPunchStatus.unavailable) {
      setState(() => _message = result.message.isNotEmpty
          ? result.message
          : "Couldn't reach the server. Try again.");
      return false;
    }

    // Accepted (recorded / skipped) or a Planday failure with a valid PIN:
    // return to the tiles and show the outcome.
    setState(() {
      _last = result;
      _pinFor = null;
      _message = null;
      _enabled = true;
    });
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final bool inPin = _pinFor != null;

    return Column(
      key: PosLockPunchView.rootKey,
      children: [
        // One step back: from the PIN card to the two choices; from the choices
        // to the sign-in screen.
        _TopBar(
          label: inPin ? 'Back' : 'Back to sign in',
          onBack: inPin ? _cancelPin : widget.onBack,
        ),
        // No scroll: the chooser is short, and the PIN card scales itself down
        // to fit whatever height it is given, so the whole flow always sits on
        // one screen.
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Center(
              child: inPin ? _pinEntry() : _chooser(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _chooser() {
    final bool narrow = MediaQuery.sizeOf(context).width < 760;
    final List<Widget> tiles = [
      PosPunchActionTile(
        key: const Key('pos-lock-punch-in'),
        label: 'Punch In',
        subtitle: 'Start of shift',
        icon: Icons.login_rounded,
        filled: true,
        onTap: () => _choose('in'),
      ),
      SizedBox(width: narrow ? 0 : 24, height: narrow ? 20 : 0),
      PosPunchActionTile(
        key: const Key('pos-lock-punch-out'),
        label: 'Punch Out',
        subtitle: 'End of shift',
        icon: Icons.logout_rounded,
        filled: false,
        onTap: () => _choose('out'),
      ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Punch Clock',
          style: loewBold.copyWith(fontSize: 30, color: PosHomeSpec.ink),
        ),
        const SizedBox(height: 8),
        Text(
          'Clock in or out — no sign-in needed.',
          textAlign: TextAlign.center,
          style: loewRegular.copyWith(
            fontSize: 15,
            color: PosHomeSpec.ink.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 40),
        narrow
            ? Column(mainAxisSize: MainAxisSize.min, children: tiles)
            : IntrinsicHeight(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: tiles,
                ),
              ),
        if (_last != null) ...[
          const SizedBox(height: 36),
          PosPunchResultBanner(result: _last!),
        ],
      ],
    );
  }

  Widget _pinEntry() {
    final bool out = _pinFor == 'out';
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: PosPinSpec.board),
      child: PosPinCard(
        pinLength: 4,
        autoSubmit: true,
        reserveMessageSpace: true,
        enabled: _enabled,
        // The card captions itself in place of the wordmark: a direction badge,
        // the action, then the instruction. No A/CAFÉ logo -- this is a punch
        // clock, not a sign-in.
        header: _PunchCardHeader(out: out),
        title: '',
        confirmLabel: out ? 'PUNCH OUT' : 'PUNCH IN',
        message: _message,
        onSubmit: _submit,
      ),
    );
  }
}

/// The in-card heading for the punch PIN step: a soft round badge with the
/// direction icon, the action name, and the instruction. Sits where the sign-in
/// card shows its wordmark.
class _PunchCardHeader extends StatelessWidget {
  final bool out;

  const _PunchCardHeader({required this.out});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: PosPinSpec.inkAlpha(0.06),
          ),
          child: Icon(
            out ? Icons.logout_rounded : Icons.login_rounded,
            size: 28,
            color: PosPinSpec.ink,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          out ? 'Punch Out' : 'Punch In',
          textAlign: TextAlign.center,
          style: loewBold.copyWith(
            fontSize: 24,
            color: PosPinSpec.ink,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Enter your PIN',
          textAlign: TextAlign.center,
          style: loewRegular.copyWith(
            fontSize: 14,
            color: PosPinSpec.inkAlpha(0.5),
          ),
        ),
      ],
    );
  }
}

/// A slim header with a single, obvious way back -- one step at a time.
class _TopBar extends StatelessWidget {
  final String label;
  final VoidCallback onBack;

  const _TopBar({required this.label, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          key: const Key('pos-lock-punch-back'),
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded, size: 20),
          label: Text(
            label,
            style: loewMedium.copyWith(fontSize: 15),
          ),
          style: TextButton.styleFrom(
            foregroundColor: PosHomeSpec.ink,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ),
    );
  }
}
