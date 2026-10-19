import 'dart:math' as math;

import 'package:acafe_customer/features/pos/domain/pos_settings_spec.dart';
import 'package:acafe_customer/features/pos/widgets/pos_menu_anchor.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';

/// One entry in a [PosDropdown] menu.
class PosDropdownOption<T> {
  final T value;
  final String label;

  const PosDropdownOption({required this.value, required this.label});
}

/// Builds the always-visible trigger. Wire [toggle] to the trigger's own tap
/// surface so its ink/radius match the trigger's shape.
typedef PosDropdownTriggerBuilder<T> = Widget Function(
  BuildContext context,
  PosDropdownOption<T>? selected,
  bool isOpen,
  VoidCallback toggle,
);

/// The one POS select menu — every POS dropdown (settings fields, Orders /
/// Receipts filter pills, Attendance staff filter) opens through this.
///
/// The menu itself opens through [PosMenuAnchor] (root overlay, glued to the
/// trigger, opens *below* it, flips *above* only when there is not enough
/// room below) — see there for why not [DropdownButton] / [showMenu]. This
/// adds the option list on top: it scrolls when longer than the space
/// available and marks the current pick.
class PosDropdown<T> extends StatelessWidget {
  final List<PosDropdownOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;
  final PosDropdownTriggerBuilder<T> triggerBuilder;

  /// The menu is at least as wide as the trigger, and at least this wide.
  final double menuMinWidth;
  final double menuMaxHeight;
  final double itemHeight;

  /// Space between the trigger's edge and the menu.
  final double gap;
  final bool enabled;

  const PosDropdown({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    required this.triggerBuilder,
    this.menuMinWidth = 0,
    this.menuMaxHeight = 320,
    this.itemHeight = 44,
    this.gap = 6,
    this.enabled = true,
  });

  /// Key of the open menu panel (for tests).
  static const Key menuKey = Key('pos-dropdown-menu');

  /// Key of the menu row at [index] (for tests).
  static Key itemKey(int index) => Key('pos-dropdown-item-$index');

  /// Keeps the menu off the very edge of the screen.
  static const double screenMargin = PosMenuAnchor.screenMargin;

  /// Vertical padding inside the menu panel, above the first / below the last row.
  static const double menuPadding = 6;

  PosDropdownOption<T>? get _selected {
    for (final PosDropdownOption<T> o in options) {
      if (o.value == value) return o;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final PosDropdownOption<T>? selected = _selected;

    return PosMenuAnchor(
      enabled: enabled && options.isNotEmpty,
      menuHeight: options.length * itemHeight + menuPadding * 2,
      menuMinWidth: menuMinWidth,
      menuMaxHeight: menuMaxHeight,
      // Always leave space for at least ~2 rows so the list stays usable.
      menuMinHeight: itemHeight * 2 + menuPadding * 2,
      gap: gap,
      triggerBuilder: (context, isOpen, toggle) =>
          triggerBuilder(context, selected, isOpen, toggle),
      menuBuilder: (context, layout, close) => _MenuPanel<T>(
        width: layout.width,
        maxHeight: layout.maxHeight,
        itemHeight: itemHeight,
        options: options,
        selected: selected,
        onSelect: (T picked) {
          close();
          if (picked != value) onChanged(picked);
        },
      ),
    );
  }
}

class _MenuPanel<T> extends StatefulWidget {
  final double width;
  final double maxHeight;
  final double itemHeight;
  final List<PosDropdownOption<T>> options;
  final PosDropdownOption<T>? selected;
  final ValueChanged<T> onSelect;

  const _MenuPanel({
    required this.width,
    required this.maxHeight,
    required this.itemHeight,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  @override
  State<_MenuPanel<T>> createState() => _MenuPanelState<T>();
}

class _MenuPanelState<T> extends State<_MenuPanel<T>> {
  late final ScrollController _scroll;

  int get _selectedIndex =>
      widget.selected == null ? -1 : widget.options.indexOf(widget.selected!);

  @override
  void initState() {
    super.initState();
    // Open scrolled to the current pick when the list is long.
    final int i = _selectedIndex;
    _scroll = ScrollController(
      initialScrollOffset:
          i <= 0 ? 0 : math.max(0, (i - 1) * widget.itemHeight),
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int selectedIndex = _selectedIndex;
    final List<PosDropdownOption<T>> options = widget.options;
    final double itemHeight = widget.itemHeight;

    return Material(
      key: PosDropdown.menuKey,
      color: PosSettingsSpec.fieldFill,
      elevation: 12,
      shadowColor: const Color(0x33241F20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PosSettingsSpec.fieldRadius),
        side: const BorderSide(color: PosSettingsSpec.fieldBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints.tightFor(width: widget.width)
            .copyWith(maxHeight: widget.maxHeight),
        child: ListView.builder(
          shrinkWrap: true,
          padding:
              const EdgeInsets.symmetric(vertical: PosDropdown.menuPadding),
          controller: _scroll,
          itemExtent: itemHeight,
          itemCount: options.length,
          itemBuilder: (context, i) {
            final PosDropdownOption<T> option = options[i];
            final bool isSelected = i == selectedIndex;
            return InkWell(
              key: PosDropdown.itemKey(i),
              onTap: () => widget.onSelect(option.value),
              child: Container(
                color: isSelected
                    ? PosSettingsSpec.ink.withValues(alpha: 0.05)
                    : null,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        option.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: loewBold.copyWith(
                          fontSize: PosSettingsSpec.fieldTextSize,
                          color: PosSettingsSpec.ink,
                        ),
                      ),
                    ),
                    if (isSelected)
                      const Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: PosSettingsSpec.ink,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
