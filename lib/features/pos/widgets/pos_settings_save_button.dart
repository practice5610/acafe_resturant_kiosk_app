import 'package:acafe_customer/features/pos/domain/pos_settings_spec.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';

/// "Save Changes" button for batch-form Settings sections (Figma 1641:3920).
///
/// Lifted verbatim out of `pos_general_settings_panel.dart`, where it was
/// file-private, so General and Hardware share one button instead of drifting.
/// Behaviour is unchanged: press-scale, dimmed while clean, spinner while
/// saving. Add-ons and Payments can adopt it when they land.
class PosSettingsSaveButton extends StatefulWidget {
  final bool loading;
  final bool dirty;
  final VoidCallback onPressed;

  const PosSettingsSaveButton({
    super.key,
    required this.loading,
    required this.dirty,
    required this.onPressed,
  });

  @override
  State<PosSettingsSaveButton> createState() => _PosSettingsSaveButtonState();
}

class _PosSettingsSaveButtonState extends State<PosSettingsSaveButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.loading ? null : widget.onPressed,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1,
          duration: const Duration(milliseconds: 90),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 160),
            opacity: widget.dirty || widget.loading ? 1 : 0.72,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: PosSettingsSpec.ink,
                borderRadius:
                    BorderRadius.circular(PosSettingsSpec.saveRadius),
                boxShadow: PosSettingsSpec.saveShadow,
              ),
              child: Padding(
                padding: PosSettingsSpec.savePadding,
                child: widget.loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: PosSettingsSpec.pageBg,
                        ),
                      )
                    : Text(
                        'Save Changes',
                        style: loewBold.copyWith(
                          fontSize: PosSettingsSpec.saveLabelSize,
                          color: PosSettingsSpec.pageBg,
                          letterSpacing: 0.2,
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
