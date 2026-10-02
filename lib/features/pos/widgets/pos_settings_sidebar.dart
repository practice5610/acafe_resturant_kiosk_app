import 'package:acafe_customer/features/pos/domain/pos_settings_section.dart';
import 'package:acafe_customer/features/pos/domain/pos_settings_spec.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';

/// Left rail for Settings sections (Figma 1641:3899).
///
/// Mirrors the home category sidebar chrome so the POS feels like one product:
/// ink fill when selected, hairline rule under inactive rows.
class PosSettingsSidebar extends StatelessWidget {
  final PosSettingsSection selected;
  final ValueChanged<PosSettingsSection> onSelect;

  /// Sections to list. Defaults to all of them, which is every caller before
  /// staff sign-in and every branch that has it switched off.
  final List<PosSettingsSection> sections;

  const PosSettingsSidebar({
    super.key,
    required this.selected,
    required this.onSelect,
    this.sections = PosSettingsSection.values,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: PosSettingsSpec.sidebarWidth,
      decoration: const BoxDecoration(
        color: PosSettingsSpec.pageBg,
        border: Border(
          right: BorderSide(
            color: PosSettingsSpec.ink,
            width: PosSettingsSpec.paneBorder,
          ),
        ),
      ),
      child: ListView.separated(
        padding: PosSettingsSpec.sidebarPadding,
        itemCount: sections.length,
        separatorBuilder: (_, __) =>
            const SizedBox(height: PosSettingsSpec.sidebarItemGap),
        itemBuilder: (context, index) {
          final PosSettingsSection section = sections[index];
          return PosSettingsSidebarItem(
            label: section.label,
            selected: section == selected,
            onTap: () => onSelect(section),
          );
        },
      ),
    );
  }
}

class PosSettingsSidebarItem extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const PosSettingsSidebarItem({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? PosSettingsSpec.ink : Colors.transparent,
      borderRadius:
          BorderRadius.circular(PosSettingsSpec.sidebarItemRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(PosSettingsSpec.sidebarItemRadius),
        child: SizedBox(
          height: PosSettingsSpec.sidebarItemHeight,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: PosSettingsSpec.sidebarItemPadding,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: loewBold.copyWith(
                      fontSize: PosSettingsSpec.sidebarLabelSize,
                      letterSpacing: PosSettingsSpec.sidebarLabelTracking,
                      color: selected ? Colors.white : PosSettingsSpec.ink,
                    ),
                  ),
                ),
              ),
              if (!selected)
                const Positioned(
                  left: PosSettingsSpec.sidebarItemPadding,
                  bottom: 0,
                  width: PosSettingsSpec.sidebarRuleWidth,
                  height: PosSettingsSpec.sidebarRuleHeight,
                  child: ColoredBox(color: PosSettingsSpec.ink),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
