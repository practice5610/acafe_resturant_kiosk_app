import 'package:acafe_customer/features/pos/domain/pos_general_settings.dart';
import 'package:acafe_customer/features/pos/domain/pos_settings_spec.dart';
import 'package:acafe_customer/features/pos/widgets/pos_dropdown.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Settings select — a labelled field whose menu is the shared [PosDropdown]
/// (root overlay, opens below the field, checkmark for the active option).
class PosSettingsDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<PosSettingsOption> options;
  final ValueChanged<String> onChanged;

  const PosSettingsDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: loewBold.copyWith(
            fontSize: PosSettingsSpec.labelSize,
            letterSpacing: PosSettingsSpec.labelTracking,
            color: PosSettingsSpec.ink,
          ),
        ),
        const SizedBox(height: PosSettingsSpec.labelGap),
        PosDropdown<String>(
          value: value,
          onChanged: onChanged,
          options: [
            for (final PosSettingsOption o in options)
              PosDropdownOption<String>(value: o.value, label: o.label),
          ],
          triggerBuilder: (context, selected, isOpen, toggle) {
            return Material(
              color: PosSettingsSpec.fieldFill,
              borderRadius: BorderRadius.circular(PosSettingsSpec.fieldRadius),
              child: InkWell(
                onTap: toggle,
                borderRadius:
                    BorderRadius.circular(PosSettingsSpec.fieldRadius),
                child: Container(
                  width: double.infinity,
                  padding: PosSettingsSpec.fieldPadding,
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(PosSettingsSpec.fieldRadius),
                    border: Border.all(
                      color: PosSettingsSpec.fieldBorder,
                      width: PosSettingsSpec.fieldBorderWidth,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          // Unknown value (option removed server-side): show
                          // the raw value rather than a blank field.
                          selected?.label ?? value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: loewBold.copyWith(
                            fontSize: PosSettingsSpec.fieldTextSize,
                            color: PosSettingsSpec.ink,
                            height: 1.2,
                          ),
                        ),
                      ),
                      AnimatedRotation(
                        turns: isOpen ? 0.5 : 0,
                        duration: const Duration(milliseconds: 140),
                        child: SizedBox(
                          width: PosSettingsSpec.chevronSize,
                          height: PosSettingsSpec.chevronSize,
                          child: SvgPicture.asset(
                            Images.posChevronDownSvg,
                            width: PosSettingsSpec.chevronSize,
                            height: PosSettingsSpec.chevronSize,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
