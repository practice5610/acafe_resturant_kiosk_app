import 'package:acafe_customer/features/pos/domain/pos_hardware_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_settings_spec.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';

/// Multi-select pill for Settings forms — filled ink when selected, outlined
/// when not (Figma 1641:8685, "Kiosk Languages").
///
/// Deliberately not [PosFilterPill]: that one is the product-grid sub-category
/// filter, sized off `PosHomeSpec` at 32/13px with 18px padding, and it is a
/// single-select affordance. These are 36/12.5px settings pills off the
/// Settings spec. Its own header comment already argues against overloading one
/// pill widget with mode-conditional styling, so this follows that precedent.
class PosSettingsPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  /// Screen-reader / widget-test hook. Multi-select, so it reports `selected`
  /// rather than `toggled`.
  final String? semanticLabel;

  const PosSettingsPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;

    return Semantics(
      label: semanticLabel ?? label,
      button: true,
      selected: selected,
      enabled: enabled,
      child: MouseRegion(
        cursor:
            enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            height: PosHardwareSpec.pillHeight,
            padding: PosHardwareSpec.pillPadding,
            decoration: BoxDecoration(
              color: selected ? PosSettingsSpec.ink : Colors.transparent,
              borderRadius:
                  BorderRadius.circular(PosHardwareSpec.pillRadius),
              border: selected
                  ? null
                  : Border.all(
                      color: PosSettingsSpec.ink,
                      width: PosHardwareSpec.pillBorder,
                    ),
            ),
            // `widthFactor: 1` rather than the Container's own `alignment`:
            // setting `alignment` makes a Container expand to the largest size
            // its constraints allow, which stretched every pill to the full row
            // width inside the Wrap.
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: (selected ? loewBold : loewMedium).copyWith(
                  fontSize: PosHardwareSpec.pillLabelSize,
                  letterSpacing: 0.4,
                  color: selected
                      ? PosSettingsSpec.pageBg
                      : PosSettingsSpec.ink,
                  height: 1.1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
