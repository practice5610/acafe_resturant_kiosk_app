import 'dart:async';

import 'package:acafe_customer/features/pos/domain/pos_staff_session.dart';
import 'package:acafe_customer/features/pos/providers/pos_staff_session_provider.dart';
import 'package:acafe_customer/features/pos/widgets/pos_pin_card.dart';
import 'package:acafe_customer/features/pos/widgets/pos_ui.dart';
import 'package:acafe_customer/features/pos/widgets/pos_wordmark.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';

/// The till's front door when a branch has switched staff sign-in on.
///
/// Role first, then a PIN: the operator taps whether they are an Employee or a
/// Branch Manager, then types their own PIN. The role tap is only how the screen
/// is organised -- the PIN alone identifies the person, and the server decides
/// what they may do from their real role, so a branch can have any number of
/// managers and employees and each just taps their role and signs in.
///
/// Built on [PosPinCard] so the keypad, PIN boxes, press states and the shake
/// on a wrong PIN are the same as the manager step-up, not a second design.
///
/// State lives in [ValueNotifier]s scoped to this screen, never in a rebuild of
/// the whole tree: the POS underneath stays mounted, so a sale in progress
/// survives a lock and a change of cashier.
class PosStaffLockScreen extends StatefulWidget {
  /// Clock seam, so a test can freeze the time shown.
  final DateTime Function() now;

  const PosStaffLockScreen({super.key, this.now = DateTime.now});

  static const Key rootKey = Key('pos-staff-lock-screen');

  @override
  State<PosStaffLockScreen> createState() => _PosStaffLockScreenState();
}

class _PosStaffLockScreenState extends State<PosStaffLockScreen> {
  /// The role tapped, or null while the operator is still choosing. The roles
  /// themselves come from the roster, never a hardcoded list.
  final ValueNotifier<PosStaffRole?> _role = ValueNotifier(null);
  final ValueNotifier<String?> _message = ValueNotifier(null);

  /// Bumped to remount the PIN card, which clears whatever was typed.
  final ValueNotifier<int> _cardEpoch = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    // The switch may have been flipped since the till last looked. Cheap, and
    // this is the moment it matters.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<PosStaffSessionProvider>().refreshRoster();
    });
  }

  @override
  void dispose() {
    _role.dispose();
    _message.dispose();
    _cardEpoch.dispose();
    super.dispose();
  }

  void _choose(PosStaffRole role) {
    _message.value = null;
    _role.value = role;
    // Changing the selected role clears whatever PIN was typed under the old one.
    _cardEpoch.value++;
  }

  void _back() {
    _message.value = null;
    _role.value = null;
  }

  /// The role this sign-in is bound to. With two or more roles the operator must
  /// have tapped one (`_role`); with exactly one it is that role, implicitly;
  /// with none the branch sends no roles and sign-in falls back to the PIN alone.
  PosStaffRole? _effectiveRole(List<PosStaffRole> roles) {
    if (roles.length >= 2) return _role.value;
    if (roles.length == 1) return roles.first;
    return null;
  }

  Future<bool> _submit(String pin) async {
    final PosStaffSessionProvider session =
        context.read<PosStaffSessionProvider>();
    // The PIN identifies the person; the tapped role binds the sign-in to it, so
    // a PIN belonging to another role is rejected as a wrong PIN by the server.
    final PosSignInResult result =
        await session.signIn(pin, roleId: _effectiveRole(session.roles)?.id);
    if (!mounted) return result.ok;

    switch (result.outcome) {
      case PosSignInOutcome.signedIn:
        _message.value = null;
        return true;
      case PosSignInOutcome.wrongPin:
        final int left = result.attemptsRemaining;
        _message.value = left > 0
            ? 'That PIN was not recognised. '
                '$left ${left == 1 ? 'try' : 'tries'} left.'
            : 'That PIN was not recognised.';
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
        child: Consumer<PosStaffSessionProvider>(
          builder: (context, session, _) {
            final List<PosStaffRole> roles = session.roles;
            // The role step only earns its place when there is a real choice. One
            // role (or none) skips straight to the PIN, which sign-in still binds
            // to that single role / to no role.
            final bool hasRoleStep = roles.length >= 2;

            return LayoutBuilder(
              builder: (context, constraints) {
                if (!hasRoleStep) {
                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                    child: Center(
                      child: _pinPane(showPlaceholder: false, hasRoleStep: false),
                    ),
                  );
                }
                final bool wide = constraints.maxWidth >= 1024;
                return wide ? _wide(roles) : _narrow(roles);
              },
            );
          },
        ),
      ),
    );
  }

  // Two panes side by side: your role on the left, your PIN on the right.
  Widget _wide(List<PosStaffRole> roles) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(56, 40, 56, 40),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 11,
            child: _RolePane(
                now: widget.now,
                roles: roles,
                selected: _role,
                onChoose: _choose),
          ),
          const SizedBox(width: 48),
          Expanded(
            flex: 9,
            child: Center(
                child: _pinPane(showPlaceholder: true, hasRoleStep: true)),
          ),
        ],
      ),
    );
  }

  // One pane at a time: roles, then the PIN card in their place.
  Widget _narrow(List<PosStaffRole> roles) {
    return AnimatedBuilder(
      animation: _role,
      builder: (context, _) {
        final bool entering = _role.value != null;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: entering
              ? Center(
                  child: _pinPane(showPlaceholder: false, hasRoleStep: true))
              : _RolePane(
                  now: widget.now,
                  roles: roles,
                  selected: _role,
                  onChoose: _choose),
        );
      },
    );
  }

  Widget _pinPane({required bool showPlaceholder, required bool hasRoleStep}) {
    return AnimatedBuilder(
      animation: Listenable.merge([_role, _message, _cardEpoch]),
      builder: (context, _) {
        final PosStaffRole? role = _role.value;

        // With a role step, wait for the tap before showing the PIN.
        if (hasRoleStep && role == null) {
          return showPlaceholder
              ? const _ChooseRolePlaceholder()
              : const SizedBox.shrink();
        }

        final String cardId = role?.id.toString() ?? 'no-role';

        return Consumer<PosStaffSessionProvider>(
          builder: (context, session, _) {
            final bool locked = session.isLockedOut;
            final String? message =
                locked ? _lockoutMessage(session.lockoutSecondsLeft) : _message.value;

            return ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: PosPinSpec.board),
              child: PosPinCard(
                key: ValueKey<String>('pin-$cardId-${_cardEpoch.value}'),
                pinLength: session.pinLength,
                autoSubmit: true,
                reserveMessageSpace: true,
                enabled: !locked && !session.signingIn,
                title: 'Enter your PIN',
                message: message,
                // The back arrow only makes sense when there is a role step to
                // return to; otherwise the card keeps its default wordmark header.
                header: hasRoleStep ? _PinHeader(onBack: _back) : null,
                onSubmit: _submit,
              ),
            );
          },
        );
      },
    );
  }
}

// ── Role pane ────────────────────────────────────────────────────────────────

class _RolePane extends StatelessWidget {
  final DateTime Function() now;
  final List<PosStaffRole> roles;
  final ValueNotifier<PosStaffRole?> selected;
  final ValueChanged<PosStaffRole> onChoose;

  const _RolePane({
    required this.now,
    required this.roles,
    required this.selected,
    required this.onChoose,
  });

  @override
  Widget build(BuildContext context) {
    // Scrolls rather than overflows: on a short window the clock and the role
    // cards stay fully reachable instead of clipping at the bottom.
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const PosWordmark(height: 30),
              const Spacer(),
              _BranchBadge(),
            ],
          ),
          const SizedBox(height: 36),
          _Clock(now: now),
          const SizedBox(height: 36),
          Text(
            'Who is on the till?',
            style: loewExtraBold.copyWith(fontSize: 22, color: PosUI.ink),
          ),
          const SizedBox(height: 6),
          Text(
            'Choose your role, then enter your PIN.',
            style: loewRegular.copyWith(fontSize: 15, color: PosUI.inkMuted),
          ),
          const SizedBox(height: 24),
          AnimatedBuilder(
            animation: selected,
            builder: (context, _) => Column(
              children: [
                for (int i = 0; i < roles.length; i++) ...[
                  _RoleCard(
                    role: roles[i],
                    selected: selected.value?.id == roles[i].id,
                    onTap: () => onChoose(roles[i]),
                  ),
                  if (i != roles.length - 1) const SizedBox(height: 16),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatefulWidget {
  final PosStaffRole role;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.role,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
  final ValueNotifier<bool> _pressed = ValueNotifier(false);

  @override
  void dispose() {
    _pressed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: widget.selected,
      label: 'Sign in as ${widget.role.name}',
      child: GestureDetector(
        key: Key('pos-lock-role-${widget.role.id}'),
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _pressed.value = true,
        onTapUp: (_) => _pressed.value = false,
        onTapCancel: () => _pressed.value = false,
        onTap: widget.onTap,
        child: ValueListenableBuilder<bool>(
          valueListenable: _pressed,
          builder: (context, pressed, _) => AnimatedScale(
            scale: pressed ? 0.98 : 1,
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
              decoration: BoxDecoration(
                color: widget.selected ? PosUI.surface : PosUI.surface.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: widget.selected ? PosUI.ink : PosUI.ink.withValues(alpha: 0.10),
                  width: 2,
                ),
                boxShadow: widget.selected
                    ? const [
                        BoxShadow(
                          color: Color(0x14241F20),
                          offset: Offset(0, 8),
                          blurRadius: 18,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.selected ? PosUI.ink : PosUI.pageBg,
                      border: Border.all(color: PosUI.ink.withValues(alpha: 0.12)),
                    ),
                    child: Icon(
                      // Neutral, role-agnostic glyph: the role name is data from
                      // the server, so the card must not key its icon off a
                      // hardcoded name. Every role card reads the same.
                      Icons.badge_outlined,
                      size: 26,
                      color: widget.selected ? Colors.white : PosUI.ink,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      widget.role.name,
                      style: loewExtraBold.copyWith(fontSize: 19, color: PosUI.ink),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: PosUI.ink.withValues(alpha: 0.4)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Small pieces ───────────────────────────────────────────────────────────

class _PinHeader extends StatelessWidget {
  final VoidCallback onBack;

  const _PinHeader({required this.onBack});

  @override
  Widget build(BuildContext context) {
    // Just the Back arrow, pinned left. The role is already obvious from the
    // button the operator tapped, so repeating it here only added clutter -- and
    // a header this simple cannot overflow or throw under any constraint.
    return Align(
      alignment: Alignment.centerLeft,
      child: IconButton(
        key: const Key('pos-lock-back'),
        // No `tooltip:` here on purpose. This screen can be mounted outside a
        // Navigator/Overlay (e.g. during a LayoutBuilder pass), and a Tooltip
        // throws "No Overlay widget found" without an Overlay ancestor. It is a
        // long-press affordance with no value on a kiosk touchscreen anyway.
        onPressed: onBack,
        icon: const Icon(Icons.arrow_back_rounded, color: PosUI.ink),
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        padding: EdgeInsets.zero,
      ),
    );
  }
}

class _ChooseRolePlaceholder extends StatelessWidget {
  const _ChooseRolePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: PosPinSpec.board),
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: PosUI.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: PosUI.ink.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.touch_app_outlined, size: 40, color: PosUI.ink.withValues(alpha: 0.55)),
          const SizedBox(height: 16),
          Text(
            'Choose your role to sign in',
            textAlign: TextAlign.center,
            style: loewBold.copyWith(fontSize: 18, color: PosUI.ink),
          ),
          const SizedBox(height: 8),
          Text(
            'Your role decides what this till lets you do.',
            textAlign: TextAlign.center,
            style: loewRegular.copyWith(fontSize: 14, color: PosUI.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _BranchBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: PosUI.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: PosUI.ink.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_outline_rounded, size: 16, color: PosUI.ink),
          const SizedBox(width: 6),
          Text('Locked', style: loewBold.copyWith(fontSize: 13, color: PosUI.ink)),
        ],
      ),
    );
  }
}

/// Large live clock. Its own ticker, so the rest of the screen never rebuilds
/// for the time.
class _Clock extends StatefulWidget {
  final DateTime Function() now;

  const _Clock({required this.now});

  @override
  State<_Clock> createState() => _ClockState();
}

class _ClockState extends State<_Clock> {
  late final ValueNotifier<DateTime> _time = ValueNotifier(widget.now());
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _time.value = widget.now());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DateTime>(
      valueListenable: _time,
      builder: (context, t, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            intl.DateFormat('HH:mm').format(t),
            style: loewExtraBold.copyWith(
              fontSize: 64,
              height: 1,
              letterSpacing: -1,
              color: PosUI.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            // Default locale on purpose: this app never calls
            // initializeDateFormatting(), so any other locale would throw.
            intl.DateFormat('EEEE, d MMMM').format(t),
            style: loewMedium.copyWith(fontSize: 18, color: PosUI.inkMuted),
          ),
        ],
      ),
    );
  }
}
