import 'package:acafe_customer/features/kiosk/providers/device_mode_provider.dart';
import 'package:acafe_customer/features/pos/widgets/pos_ui.dart';
import 'package:acafe_customer/features/pos/widgets/pos_wordmark.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Covers the till while it switches between POS and kiosk
/// (POS_KIOSK_MODE_PHASE1.md §5.6).
///
/// A switch is a few moments where the mode, the staff session, the image
/// setting and the route all change one after another. Painted, those moments
/// are a kiosk screen re-laying itself out in the POS's settings, or the POS
/// signed out behind a closing dialog. Under the curtain the screen is offstage
/// -- built, never painted -- and the destination fades in once it has landed.
class DeviceModeCurtain extends StatefulWidget {
  final Widget child;

  const DeviceModeCurtain({super.key, required this.child});

  /// How long the curtain takes to cover the screen, and to uncover it.
  static const Duration fade = Duration(milliseconds: 160);

  static const Key faceKey = Key('device-mode-curtain');

  @override
  State<DeviceModeCurtain> createState() => _DeviceModeCurtainState();
}

class _DeviceModeCurtainState extends State<DeviceModeCurtain> with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(vsync: this, duration: DeviceModeCurtain.fade)
    ..addStatusListener((_) => setState(() {}));

  DeviceModeProvider? _modes;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Null-safe: a harness without the provider has no switches to cover.
    _modes = Provider.of<DeviceModeProvider?>(context);
    if (_modes?.curtain ?? false) {
      _fade.forward();
    } else {
      _fade.reverse();
    }
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool covering = _modes?.curtainCovering ?? false;
    final bool showFace = (_modes?.curtain ?? false) || _fade.status != AnimationStatus.dismissed;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Offstage only once the curtain is opaque, so nothing jumps while it
        // fades in or out.
        Offstage(offstage: covering, child: widget.child),
        if (showFace)
          FadeTransition(
            opacity: CurvedAnimation(parent: _fade, curve: Curves.easeOut),
            child: _CurtainFace(target: _modes?.curtainTarget),
          ),
      ],
    );
  }
}

class _CurtainFace extends StatelessWidget {
  final DeviceModeTarget? target;

  const _CurtainFace({required this.target});

  @override
  Widget build(BuildContext context) {
    final String label = target == DeviceModeTarget.kiosk ? 'Switching to Kiosk' : 'Switching to POS';

    // Opaque and hit-testable: while it is up, nothing underneath takes a tap.
    return GestureDetector(
      key: DeviceModeCurtain.faceKey,
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      // Material, not a bare ColoredBox: the curtain sits in the app's
      // builder, above the navigator, where nothing provides a text style --
      // Text there falls back to the debug yellow underline.
      child: Material(
        color: PosUI.pageBg,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const PosWordmark(height: 36),
              const SizedBox(height: 28),
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: PosUI.ink),
              ),
              const SizedBox(height: 16),
              Text(
                label,
                style: loewMedium.copyWith(fontSize: 15, color: PosUI.ink, letterSpacing: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
