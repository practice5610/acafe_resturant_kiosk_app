import 'package:acafe_customer/features/category/domain/category_model.dart';
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';

/// Left pane: the branch's top-level categories.
///
/// Selection state lives in `CategoryProvider.selectedSubCategoryId` (which,
/// despite the name, holds the *top-level* id — the kiosk rail uses it the same
/// way). This widget is presentational; the screen owns the provider wiring.
class PosCategorySidebar extends StatelessWidget {
  final List<CategoryModel> categories;
  final String? selectedId;
  final ValueChanged<CategoryModel> onSelect;

  /// Tapped to open the Punch In / Out screen. Optional: when null (every
  /// existing caller and the widget's own tests) the action is not rendered, so
  /// the sidebar is unchanged for them. The one caller that passes it is
  /// `pos_home_cart_screen.dart`.
  final VoidCallback? onPunch;

  /// Pane width. Defaults to the flat Figma value — the only width this
  /// widget ever drew before the desktop-floor refactor — so every other
  /// caller (and every existing test that constructs this widget directly)
  /// keeps working unchanged. `pos_home_cart_screen.dart` is the one caller
  /// that now passes [PosResponsive.sidebarWidth]'s continuous value above
  /// the floor.
  final double width;

  const PosCategorySidebar({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.onSelect,
    this.onPunch,
    this.width = PosHomeSpec.sidebarWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: const BoxDecoration(
        color: PosHomeSpec.pageBg,
        border: Border(
          right: BorderSide(
            color: PosHomeSpec.ink,
            width: PosHomeSpec.paneBorder,
          ),
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: ScrollConfiguration(
              behavior:
                  ScrollConfiguration.of(context).copyWith(scrollbars: false),
              child: ListView.separated(
                padding: PosHomeSpec.sidebarPadding,
                itemCount: categories.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: PosHomeSpec.sidebarItemGap),
                itemBuilder: (context, index) {
                  final category = categories[index];
                  return PosCategoryItem(
                    label: category.name ?? '',
                    selected: '${category.id}' == selectedId,
                    onTap: () => onSelect(category),
                  );
                },
              ),
            ),
          ),
          if (onPunch != null) _PosSidebarPunchAction(onTap: onPunch!),
        ],
      ),
    );
  }
}

/// The Punch In / Out entry, pinned below the categories. Styled from the same
/// sidebar tokens so it reads as part of the rail, but outlined rather than
/// filled so it is clearly an action, not another category (a filled tile is
/// how the rail draws the *selected* category).
class _PosSidebarPunchAction extends StatelessWidget {
  final VoidCallback onTap;

  const _PosSidebarPunchAction({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Opacity(
            opacity: PosHomeSpec.sidebarRuleOpacity,
            child: SizedBox(
              height: PosHomeSpec.sidebarRuleHeight,
              width: double.infinity,
              child: ColoredBox(color: PosHomeSpec.ink),
            ),
          ),
          const SizedBox(height: 16),
          Material(
            key: const Key('pos-sidebar-punch'),
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(PosHomeSpec.sidebarItemRadius),
            child: InkWell(
              onTap: onTap,
              borderRadius:
                  BorderRadius.circular(PosHomeSpec.sidebarItemRadius),
              child: Container(
                height: PosHomeSpec.sidebarItemHeight,
                decoration: BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(PosHomeSpec.sidebarItemRadius),
                  border: Border.all(
                    color: PosHomeSpec.ink,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.schedule_rounded,
                        size: 20, color: PosHomeSpec.ink),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        'Punch In / Out'.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: loewBold.copyWith(
                          fontSize: 13,
                          color: PosHomeSpec.ink,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PosCategoryItem extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const PosCategoryItem({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? PosHomeSpec.ink : Colors.transparent,
      borderRadius: BorderRadius.circular(PosHomeSpec.sidebarItemRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PosHomeSpec.sidebarItemRadius),
        child: SizedBox(
          height: PosHomeSpec.sidebarItemHeight,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: PosHomeSpec.sidebarItemPadding),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label.toUpperCase(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: loewBold.copyWith(
                      fontSize: PosHomeSpec.sidebarLabelSize,
                      color: selected ? Colors.white : PosHomeSpec.ink,
                      height: PosHomeSpec.sidebarLabelHeight,
                    ),
                  ),
                ),
              ),
              // The selected item is the one row in the design with no rule
              // under it — the fill replaces the separator.
              if (!selected)
                const Positioned(
                  left: PosHomeSpec.sidebarItemPadding,
                  right: PosHomeSpec.sidebarItemPadding,
                  bottom: 0,
                  height: PosHomeSpec.sidebarRuleHeight,
                  child: Opacity(
                    opacity: PosHomeSpec.sidebarRuleOpacity,
                    child: ColoredBox(color: PosHomeSpec.ink),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
