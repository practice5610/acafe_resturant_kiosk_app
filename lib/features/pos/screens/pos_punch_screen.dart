import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_punch_source.dart';
import 'package:acafe_customer/features/pos/domain/pos_routes.dart';
import 'package:acafe_customer/features/pos/widgets/pos_pin_card.dart';
import 'package:acafe_customer/features/pos/widgets/pos_punch_actions.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Punch In / Punch Out.
///
/// A deliberate, PIN-gated attendance action — never a side effect of signing
/// in or out of the till. Two prominent, clearly separated actions; each opens
/// the shared PIN card, validates against the existing employee PIN, and drives
/// the existing Planday punch service through [PosPunchSource]. Whoever types
/// their own PIN is punched, so one terminal serves a whole shift.
///
/// Nothing here touches the till's sale state: the POS cart, selected category
/// and session live in app-root providers, so returning restores the exact
/// screen the operator left.
class PosPunchScreen extends StatefulWidget {
  final PosPunchSource source;

  const PosPunchScreen({super.key, required this.source});

  @override
  State<PosPunchScreen> createState() => _PosPunchScreenState();
}

class _PosPunchScreenState extends State<PosPunchScreen> {
  PosPunchResult? _last;

  Future<void> _punch(String direction) async {
    final PosPunchResult? result = await _PunchPinDialog.show(
      context,
      direction: direction,
      source: widget.source,
    );
    if (result != null && mounted) {
      setState(() => _last = result);
    }
  }

  void _backToPos() {
    // The till's state is untouched, so this returns to exactly where the
    // operator was. Guarded so the back control is harmless off a GoRouter.
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go(PosRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool narrow = MediaQuery.sizeOf(context).width < 760;

    final List<Widget> tiles = [
      PosPunchActionTile(
        key: const Key('pos-punch-in-action'),
        label: 'Punch In',
        subtitle: 'Start of shift',
        icon: Icons.login_rounded,
        filled: true,
        onTap: () => _punch('in'),
      ),
      SizedBox(width: narrow ? 0 : 24, height: narrow ? 20 : 0),
      PosPunchActionTile(
        key: const Key('pos-punch-out-action'),
        label: 'Punch Out',
        subtitle: 'End of shift',
        icon: Icons.logout_rounded,
        filled: false,
        onTap: () => _punch('out'),
      ),
    ];

    return ColoredBox(
      color: PosHomeSpec.pageBg,
      child: SafeArea(
        child: Column(
          children: [
            _TopBar(onBack: _backToPos),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Punch Clock',
                        style: loewBold.copyWith(
                            fontSize: 30, color: PosHomeSpec.ink),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enter your PIN to record your attendance.',
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
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A slim header with a single, obvious way back to the till.
class _TopBar extends StatelessWidget {
  final VoidCallback onBack;

  const _TopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          key: const Key('pos-punch-back'),
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded, size: 20),
          label: Text(
            'Back to POS',
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

/// The PIN prompt for a punch. Hosts the shared [PosPinCard]; stays open and
/// shows a note when the PIN is wrong, a lockout, or the server is unreachable,
/// and pops with the [PosPunchResult] once the PIN is accepted (whether or not
/// Planday then recorded it).
class _PunchPinDialog extends StatefulWidget {
  final String direction;
  final PosPunchSource source;

  const _PunchPinDialog({required this.direction, required this.source});

  static Future<PosPunchResult?> show(
    BuildContext context, {
    required String direction,
    required PosPunchSource source,
  }) {
    return showDialog<PosPunchResult>(
      context: context,
      barrierDismissible: true,
      builder: (_) =>
          _PunchPinDialog(direction: direction, source: source),
    );
  }

  @override
  State<_PunchPinDialog> createState() => _PunchPinDialogState();
}

class _PunchPinDialogState extends State<_PunchPinDialog> {
  String? _message;
  bool _enabled = true;

  Future<bool> _submit(String pin) async {
    final PosPunchResult result =
        await widget.source.punch(direction: widget.direction, pin: pin);

    if (result.pinRejected) {
      if (mounted) {
        setState(() {
          _message = result.message.isNotEmpty
              ? result.message
              : 'That PIN was not recognised.';
          // A lockout freezes the keypad; a plain wrong PIN lets them retry.
          _enabled = result.status != PosPunchStatus.lockedOut;
        });
      }
      return false; // the card shakes and clears
    }

    if (result.status == PosPunchStatus.unavailable) {
      if (mounted) {
        setState(() => _message = result.message.isNotEmpty
            ? result.message
            : "Couldn't reach the server. Try again.");
      }
      return false;
    }

    // Accepted (recorded / skipped) or a Planday failure with a valid PIN:
    // close and let the screen show the outcome.
    if (mounted) Navigator.of(context).pop(result);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: PosPinSpec.board),
        child: PosPinCard(
          pinLength: 4,
          autoSubmit: true,
          enabled: _enabled,
          title: widget.direction == 'out'
              ? 'Enter your PIN to punch out'
              : 'Enter your PIN to punch in',
          // Not a login: name the actual action on the button.
          confirmLabel: widget.direction == 'out' ? 'PUNCH OUT' : 'PUNCH IN',
          message: _message,
          onSubmit: _submit,
        ),
      ),
    );
  }
}
