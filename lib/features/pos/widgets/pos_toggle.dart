import 'package:acafe_customer/features/pos/domain/pos_settings_spec.dart';
import 'package:flutter/material.dart';

/// Figma toggle — 44×24 track, 16px knob, ink when on (**1641:4016**).
///
/// Shared across POS Settings sections. Same 44×24 track as the Staff panel's
/// private `_PosToggle`; the knob follows this frame's spec (16/4 rather than
/// Staff's 18/3). Staff is intentionally left untouched here and can adopt
/// this widget in a later cleanup.
class PosToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  /// Semantics label for screen readers / widget tests.
  final String? semanticLabel;

  const PosToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
  });

  static const double trackWidth = 44;
  static const double trackHeight = 24;
  static const double _thumb = 16;
  static const Color _trackOff = Color(0xFFE3DFD3);
  static const Duration _duration = Duration(milliseconds: 180);

  @override
  Widget build(BuildContext context) {
    final bool enabled = onChanged != null;

    return Semantics(
      label: semanticLabel,
      toggled: value,
      enabled: enabled,
      child: MouseRegion(
        cursor:
            enabled ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
        child: GestureDetector(
          onTap: enabled ? () => onChanged!(!value) : null,
          behavior: HitTestBehavior.opaque,
          child: Opacity(
            opacity: enabled ? 1 : 0.5,
            child: AnimatedContainer(
              duration: _duration,
              curve: Curves.easeOut,
              width: trackWidth,
              height: trackHeight,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: value ? PosSettingsSpec.ink : _trackOff,
                borderRadius: BorderRadius.circular(trackHeight / 2),
              ),
              child: AnimatedAlign(
                duration: _duration,
                curve: Curves.easeOut,
                alignment:
                    value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: _thumb,
                  height: _thumb,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
