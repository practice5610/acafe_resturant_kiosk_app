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
/// Faces first, then a PIN: a counter is shared, and "tap your name" is both
/// faster than recalling which PIN is yours and a quiet check that the right
/// person is signing in -- the server only accepts the tapped person's PIN, so
/// a colleague's PIN typed under your face is simply wrong. "Enter PIN only"
/// skips the faces for anyone who would rather just type.
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
  /// The face tapped, or null. `_pinOnly` is the alternative to choosing one.
  final ValueNotifier<PosLockScreenMember?> _selected = ValueNotifier(null);
  final ValueNotifier<bool> _pinOnly = ValueNotifier(false);
  final ValueNotifier<String?> _message = ValueNotifier(null);

  /// Bumped to remount the PIN card, which clears whatever was typed.
  final ValueNotifier<int> _cardEpoch = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    // Someone may have been hired, or the switch flipped, since the till last
    // looked. Cheap, and it is the moment the faces matter.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<PosStaffSessionProvider>().refreshRoster();
    });
  }

  @override
  void dispose() {
    _selected.dispose();
    _pinOnly.dispose();
    _message.dispose();
    _cardEpoch.dispose();
    super.dispose();
  }

  void _choose(PosLockScreenMember member) {
    _message.value = null;
    _pinOnly.value = false;
    _selected.value = member;
    _cardEpoch.value++;
  }

  void _choosePinOnly() {
    _message.value = null;
    _selected.value = null;
    _pinOnly.value = true;
    _cardEpoch.value++;
  }

  void _back() {
    _message.value = null;
    _selected.value = null;
    _pinOnly.value = false;
  }

  Future<bool> _submit(String pin) async {
    final PosStaffSessionProvider session = context.read<PosStaffSessionProvider>();
    final PosSignInResult result = await session.signIn(
      pin,
      memberId: _selected.value?.id,
    );
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool wide = constraints.maxWidth >= 1024;
            return wide ? _wide() : _narrow();
          },
        ),
      ),
    );
  }

  // Two panes side by side: who you are on the left, your PIN on the right.
  Widget _wide() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(56, 40, 56, 40),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 11,
            child: _PeoplePane(
              now: widget.now,
              selected: _selected,
              pinOnly: _pinOnly,
              onChoose: _choose,
              onPinOnly: _choosePinOnly,
            ),
          ),
          const SizedBox(width: 48),
          Expanded(
            flex: 9,
            child: Center(child: _pinPane(showPlaceholder: true)),
          ),
        ],
      ),
    );
  }

  // One pane at a time: faces, then the PIN card in their place.
  Widget _narrow() {
    return AnimatedBuilder(
      animation: Listenable.merge([_selected, _pinOnly]),
      builder: (context, _) {
        final bool entering = _selected.value != null || _pinOnly.value;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: entering
              ? Center(child: _pinPane(showPlaceholder: false))
              : _PeoplePane(
                  now: widget.now,
                  selected: _selected,
                  pinOnly: _pinOnly,
                  onChoose: _choose,
                  onPinOnly: _choosePinOnly,
                ),
        );
      },
    );
  }

  Widget _pinPane({required bool showPlaceholder}) {
    return AnimatedBuilder(
      animation: Listenable.merge([_selected, _pinOnly, _message, _cardEpoch]),
      builder: (context, _) {
        final PosLockScreenMember? member = _selected.value;
        final bool pinOnly = _pinOnly.value;

        if (member == null && !pinOnly) {
          return showPlaceholder ? const _ChooseSomeonePlaceholder() : const SizedBox.shrink();
        }

        return Consumer<PosStaffSessionProvider>(
          builder: (context, session, _) {
            final bool locked = session.isLockedOut;
            final String? message =
                locked ? _lockoutMessage(session.lockoutSecondsLeft) : _message.value;

            return ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: PosPinSpec.board),
              child: PosPinCard(
                key: ValueKey<String>('pin-${member?.id ?? 'any'}-${_cardEpoch.value}'),
                pinLength: session.pinLength,
                autoSubmit: true,
                reserveMessageSpace: true,
                enabled: !locked && !session.signingIn,
                title: member == null
                    ? 'Enter your PIN'
                    : 'Hi ${member.name.split(' ').first}, enter your PIN',
                message: message,
                header: _PinHeader(member: member, onBack: _back),
                onSubmit: _submit,
              ),
            );
          },
        );
      },
    );
  }
}

// ── People pane ────────────────────────────────────────────────────────────

class _PeoplePane extends StatelessWidget {
  final DateTime Function() now;
  final ValueNotifier<PosLockScreenMember?> selected;
  final ValueNotifier<bool> pinOnly;
  final ValueChanged<PosLockScreenMember> onChoose;
  final VoidCallback onPinOnly;

  const _PeoplePane({
    required this.now,
    required this.selected,
    required this.pinOnly,
    required this.onChoose,
    required this.onPinOnly,
  });

  @override
  Widget build(BuildContext context) {
    final PosStaffSessionProvider session = context.watch<PosStaffSessionProvider>();
    final List<PosLockScreenMember> members = session.members;

    return Column(
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
          members.isEmpty
              ? 'Nobody here can sign in yet.'
              : 'Tap your name, then enter your PIN.',
          style: loewRegular.copyWith(fontSize: 15, color: PosUI.inkMuted),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: members.isEmpty
              ? const _NobodyCanSignIn()
              : AnimatedBuilder(
                  animation: selected,
                  builder: (context, _) => _AvatarGrid(
                    members: members,
                    selectedId: selected.value?.id,
                    onChoose: onChoose,
                  ),
                ),
        ),
        if (members.isNotEmpty) ...[
          const SizedBox(height: 12),
          TextButton.icon(
            key: const Key('pos-lock-pin-only'),
            onPressed: onPinOnly,
            icon: const Icon(Icons.dialpad_rounded, size: 20),
            label: Text('Enter PIN only', style: loewBold.copyWith(fontSize: 15)),
            style: TextButton.styleFrom(
              foregroundColor: PosUI.ink,
              minimumSize: const Size(64, 48),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
        ],
      ],
    );
  }
}

class _AvatarGrid extends StatelessWidget {
  final List<PosLockScreenMember> members;
  final String? selectedId;
  final ValueChanged<PosLockScreenMember> onChoose;

  const _AvatarGrid({
    required this.members,
    required this.selectedId,
    required this.onChoose,
  });

  @override
  Widget build(BuildContext context) {
    // A scrolling region *inside* the pane, not around the screen: a large team
    // scrolls its faces while the clock and the PIN card stay put.
    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 8),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 148,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.86,
      ),
      itemCount: members.length,
      itemBuilder: (context, i) => _AvatarTile(
        member: members[i],
        selected: members[i].id == selectedId,
        onTap: () => onChoose(members[i]),
      ),
    );
  }
}

class _AvatarTile extends StatefulWidget {
  final PosLockScreenMember member;
  final bool selected;
  final VoidCallback onTap;

  const _AvatarTile({
    required this.member,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_AvatarTile> createState() => _AvatarTileState();
}

class _AvatarTileState extends State<_AvatarTile> {
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
      label: 'Sign in as ${widget.member.name}',
      child: GestureDetector(
        key: Key('pos-lock-avatar-${widget.member.id}'),
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _pressed.value = true,
        onTapUp: (_) => _pressed.value = false,
        onTapCancel: () => _pressed.value = false,
        onTap: widget.onTap,
        child: ValueListenableBuilder<bool>(
          valueListenable: _pressed,
          builder: (context, pressed, _) => AnimatedScale(
            scale: pressed ? 0.95 : 1,
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              decoration: BoxDecoration(
                color: widget.selected ? PosUI.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: widget.selected ? PosUI.ink : Colors.transparent,
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
              padding: const EdgeInsets.all(10),
              // Sized from the cell it was given rather than fixed: the grid's
              // cells shrink with the window, and a fixed 76px face plus a
              // two-line name overflowed a narrow cell.
              child: LayoutBuilder(
                builder: (context, box) {
                  final double face = (box.maxWidth * 0.66).clamp(40.0, 76.0);
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      PosStaffAvatar(
                        initials: widget.member.initials,
                        size: face,
                        emphasised: widget.selected,
                      ),
                      const SizedBox(height: 8),
                      Flexible(
                        child: Text(
                          widget.member.name,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: loewBold.copyWith(
                              fontSize: 14, height: 1.2, color: PosUI.ink),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A circle of initials. Used here, and by the signed-in chip in the top bar,
/// so the person looks the same in both places.
class PosStaffAvatar extends StatelessWidget {
  final String initials;
  final double size;
  final bool emphasised;

  const PosStaffAvatar({
    super.key,
    required this.initials,
    this.size = 40,
    this.emphasised = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: emphasised ? PosUI.ink : PosUI.surface,
        border: Border.all(color: PosUI.ink.withValues(alpha: 0.12)),
      ),
      child: Text(
        initials.isEmpty ? '?' : initials,
        style: loewExtraBold.copyWith(
          fontSize: size * 0.34,
          letterSpacing: 0.5,
          color: emphasised ? Colors.white : PosUI.ink,
        ),
      ),
    );
  }
}

// ── Small pieces ───────────────────────────────────────────────────────────

class _PinHeader extends StatelessWidget {
  final PosLockScreenMember? member;
  final VoidCallback onBack;

  const _PinHeader({required this.member, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          key: const Key('pos-lock-back'),
          tooltip: 'Back to names',
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded, color: PosUI.ink),
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        ),
        const SizedBox(width: 4),
        if (member != null) ...[
          PosStaffAvatar(initials: member!.initials, size: 40, emphasised: true),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              member!.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: loewBold.copyWith(fontSize: 16, color: PosUI.ink),
            ),
          ),
        ] else
          Expanded(
            child: Text(
              'PIN only',
              style: loewBold.copyWith(fontSize: 16, color: PosUI.ink),
            ),
          ),
      ],
    );
  }
}

class _ChooseSomeonePlaceholder extends StatelessWidget {
  const _ChooseSomeonePlaceholder();

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
            'Tap your name to sign in',
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

class _NobodyCanSignIn extends StatelessWidget {
  const _NobodyCanSignIn();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFFDF3E1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x33D4A24C)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Staff sign-in is on for this branch, but nobody has a PIN yet.',
              style: loewBold.copyWith(fontSize: 15, color: const Color(0xFF6E4F18)),
            ),
            const SizedBox(height: 6),
            Text(
              'A manager can set PINs in the admin panel under Staff & Roles.',
              style: loewRegular.copyWith(fontSize: 14, color: const Color(0xFF6E4F18)),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.read<PosStaffSessionProvider>().refreshRoster(),
              style: TextButton.styleFrom(
                foregroundColor: PosUI.ink,
                minimumSize: const Size(64, 44),
              ),
              child: Text('Check again', style: loewBold.copyWith(fontSize: 14)),
            ),
          ],
        ),
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
