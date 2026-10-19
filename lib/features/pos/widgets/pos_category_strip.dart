import 'package:acafe_customer/features/category/domain/category_model.dart';
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/widgets/pos_horizontal_scroller.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';

/// The category rail for a compact window: one swipeable row of tabs across
/// the top of the product pane, with Punch In / Out pinned at its end.
///
/// Same data and callbacks as `PosCategorySidebar`, and drawn from the same
/// tokens — selected is the rail's filled ink tile, the rest plain ink labels
/// — so switching between the two compositions changes the layout, not the
/// look. Square tabs on purpose: the tag pills below are fully rounded, and
/// the two rows must not read as one control.
class PosCategoryStrip extends StatelessWidget {
  final List<CategoryModel> categories;
  final String? selectedId;
  final ValueChanged<CategoryModel> onSelect;

  /// Opens the Punch In / Out screen. Null omits the action.
  final VoidCallback? onPunch;

  const PosCategoryStrip({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.onSelect,
    this.onPunch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: PosHomeSpec.stripHeight,
      decoration: const BoxDecoration(
        color: PosHomeSpec.pageBg,
        border: Border(
          bottom: BorderSide(
            color: PosHomeSpec.ink,
            width: PosHomeSpec.paneBorder,
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool punchLabel =
              constraints.maxWidth >= PosHomeSpec.stripPunchLabelMinWidth;
          return Row(
            children: [
              Expanded(
                child: PosHorizontalScroller(
                  spacing: PosHomeSpec.stripTabGap,
                  padding: const EdgeInsets.symmetric(
                      horizontal: PosHomeSpec.compactGutter),
                  children: [
                    for (final CategoryModel category in categories)
                      PosCategoryTab(
                        label: category.name ?? '',
                        selected: '${category.id}' == selectedId,
                        onTap: () => onSelect(category),
                      ),
                  ],
                ),
              ),
              if (onPunch != null)
                Padding(
                  padding:
                      const EdgeInsets.only(right: PosHomeSpec.compactGutter),
                  child: _StripPunchAction(
                    onTap: onPunch!,
                    showLabel: punchLabel,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class PosCategoryTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const PosCategoryTab({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius =
        BorderRadius.circular(PosHomeSpec.sidebarItemRadius);
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? PosHomeSpec.ink : Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            height: PosHomeSpec.stripTabHeight,
            padding: const EdgeInsets.symmetric(
                horizontal: PosHomeSpec.stripTabPaddingH),
            child: Align(
              widthFactor: 1,
              child: Text(
                label.toUpperCase(),
                maxLines: 1,
                style: loewBold.copyWith(
                  fontSize: PosHomeSpec.stripLabelSize,
                  color: selected ? Colors.white : PosHomeSpec.ink,
                  height: PosHomeSpec.stripLabelHeight,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The rail's outlined Punch action, at strip height. Icon-only (with a
/// tooltip) once the strip is too narrow to spare the label's width from
/// the categories.
class _StripPunchAction extends StatelessWidget {
  final VoidCallback onTap;
  final bool showLabel;

  const _StripPunchAction({required this.onTap, required this.showLabel});

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius =
        BorderRadius.circular(PosHomeSpec.sidebarItemRadius);
    return Tooltip(
      message: 'Punch In / Out',
      child: Material(
        // Same key as the rail's action: one Punch control, whichever
        // composition is on screen.
        key: const Key('pos-sidebar-punch'),
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            height: PosHomeSpec.stripTabHeight,
            constraints:
                const BoxConstraints(minWidth: PosHomeSpec.stripTabHeight),
            padding: EdgeInsets.symmetric(horizontal: showLabel ? 12 : 0),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: PosHomeSpec.ink, width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.schedule_rounded,
                    size: PosHomeSpec.stripPunchIconSize,
                    color: PosHomeSpec.ink),
                if (showLabel) ...[
                  const SizedBox(width: 8),
                  Text(
                    'PUNCH IN / OUT',
                    maxLines: 1,
                    style: loewBold.copyWith(
                      fontSize: PosHomeSpec.stripPunchLabelSize,
                      color: PosHomeSpec.ink,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
